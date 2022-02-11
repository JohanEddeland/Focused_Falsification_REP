function mrfResults = performSensitivityAnalysis(mrfResults)
startMorrisSensiTime = tic;

%% Initialize variables needed for sensitivity analysis

num_var = numel(mrfResults.B.GetVariables());

% Current heuristic: Use approximately one third of all simulations for
% sensitivity analysis (rounded down but at least one)
num_path = 0;
num_path_max = max(2, floor((mrfResults.totalMaxEval/3)/(num_var+1))); % at least 2 path
num_path_batch = 1;
    
%% Main loop for incremental sensitivity
while num_path < num_path_max
    fprintf('\n====== SENSITIVITY ANALYSIS of %d requirements - paths %d to %d out of %d ======\n',numel(mrfResults.currentReqs), num_path+1, num_path+num_path_batch, num_path_max);
    
    %% copy B and R and compute new paths
    B0 = mrfResults.B.copy(); % make sure mrfResults.B does not store traces, which is problematic later
    R0 = mrfResults.R.copy(); % Copy R for similar reasons.
    [res_sensi, R_sensi] = ComputeMorrisSensi(R0, ...
        B0, num_path_batch, mrfResults.randomSeed+num_path);
           
    %% Checks for additive semantics requirements
    if num_path==0 % checks this after the first batch only. Might be unpredictable otherwise...
        idx_add = [];
        mrfResults.addReqs = {}; % requirements with additive semantics
        for monitorCounter = 1:numel(mrfResults.currentReqs)
            thisSemantics = get_semantics(mrfResults.currentReqs{monitorCounter});
            if strcmp(thisSemantics, 'max') && all(res_sensi{monitorCounter}.mu == 0)
                % Insensitive to max semantics
                disp(['Monitor ' mrfResults.R.req_monitors{monitorCounter}.formula_id ...
                    ' not sensitive to max.' ...
                    ' Keeping, setting phi.semantics to add ' ...
                    ' and will recompute sensitivities ...']);
                mrfResults.currentReqs{monitorCounter} = ...
                    set_semantics(mrfResults.currentReqs{monitorCounter}, 'add');
                mrfResults.addReqs{end+1} = mrfResults.currentReqs{monitorCounter};
                idx_add(end+1) = monitorCounter;
            end
        end
        
        % Recomputing add sensitivities
        if ~isempty(idx_add)
            mrfResults.R_sensi_add = BreachRequirement(mrfResults.addReqs);
            R0 = mrfResults.R_sensi_add.copy();
            [res_sensi_add, mrfResults.R_sensi_add] = ComputeMorrisSensi(R0, ...
                R_sensi.BrSet, num_path_batch, mrfResults.randomSeed);
            
            % Update res_sensi
            for monitorCounter = 1:numel(idx_add)
                res_sensi{idx_add(monitorCounter)} = res_sensi_add{monitorCounter};
            end
        end
    end
    
    %% Concat new results
    if isempty(mrfResults.res_sensi)
        mrfResults.res_sensi = res_sensi;
        mrfResults.R_sensi = {R_sensi};
        mrfResults.B_sensi = {R_sensi.BrSet};
    else
        mrfResults.res_sensi = updateSensiRes(mrfResults.res_sensi,res_sensi);
        mrfResults.R_sensi{end+1} = R_sensi; % array of BreachRequirements, combining them is going to be a bit tricky,
                                             % also the first one should likely be combined with mrfResults.R_sensi_add...
        mrfResults.B_sensi{end+1} = R_sensi.BrSet; % at least this should be correct 
    end    
            
    %% Explicitly store M, the matrix with sensitivity information
    for monitorCounter = 1:numel(mrfResults.currentReqs)
        for inputCounter = 1:numel(mrfResults.inputList)
            mrfResults.M(inputCounter, monitorCounter) = ...
                mrfResults.res_sensi{monitorCounter}.mu(inputCounter);
        end
    end
    
    %% Check if any monitors are falsified
    if isempty(mrfResults.firstIdxFalsified)
        mrfResults.firstIdxFalsified = struct();
    end
    monitorsToRemove = []; % Indices of monitors to remove
    for monitorCounter = 1:numel(mrfResults.currentReqs)        
        formula_id = mrfResults.R.req_monitors{monitorCounter}.formula_id;
        if any(res_sensi{1, monitorCounter}.rob < 0)
            disp(['Monitor ' formula_id ...
                ' falsified during sensitivity analysis! Will be removed ...']);
            monitorsToRemove(end+1) = monitorCounter; %#ok<*SAGROW>
            
            % Store in a struct which index the spec was failed for
            mrfResults.firstIdxFalsified(end+1).id = formula_id;
            mrfResults.firstIdxFalsified(end).index = ...
                find(res_sensi{1, monitorCounter}.rob < 0, 1)+mrfResults.globalIndex-1;
            mrfResults.firstIdxFalsified(end).globalIndex = ...
                find(res_sensi{1, monitorCounter}.rob < 0, 1)+mrfResults.globalIndex-1;
            mrfResults.firstIdxFalsified(end).falsification = 'sensitivity';
            
            % If it is a safety requirement, also remove all corresponding
            % activation requirements
            if contains(formula_id, '_req')
                if contains(formula_id, '_art')
                    % Artificial _req
                    formula_without_req = strrep(formula_id, '_req_art', '');
                    for monitorCounter2 = 1:numel(mrfResults.currentReqs)
                        other_formula_id = mrfResults.R.req_monitors{monitorCounter2}.formula_id;
                        if contains(other_formula_id, formula_without_req) && ...
                            contains(other_formula_id, '_act') && ...
                            contains(other_formula_id, '_art')
                            % Corresponding artificial _act
                            monitorsToRemove(end+1) = monitorCounter2;
                        end
                    end
                else
                    % Non-artifical _req
                    formula_without_req = strrep(formula_id, '_req', '');
                    for monitorCounter2 = 1:numel(mrfResults.currentReqs)
                        other_formula_id = mrfResults.R.req_monitors{monitorCounter2}.formula_id;
                        if contains(other_formula_id, formula_without_req) && ...
                            contains(other_formula_id, '_act') && ...
                            ~contains(other_formula_id, '_art')
                            % Corresponding artificial _act
                            monitorsToRemove(end+1) = monitorCounter2;
                        end
                    end
                end
            end
                                     
        end        
        %% update requirement robustness hist 
        num_samples= numel(res_sensi{1,monitorCounter}.rob);
        i0 = mrfResults.globalIndex;
        i1 = mrfResults.globalIndex+num_samples-1;        
        mrfResults.hist.rob.(formula_id)(i0:i1)= res_sensi{monitorCounter}.rob;        
                                       
    end
    
    %% Remove monitors and loop
    monitorsToRemove = unique(monitorsToRemove);
    monitorsToKeep = setdiff(1:numel(mrfResults.currentReqs), monitorsToRemove);
    mrfResults.allCurrentReqs{end+1} = mrfResults.allCurrentReqs{end}(monitorsToKeep);
    mrfResults.currentReqs = mrfResults.currentReqs(monitorsToKeep);
    mrfResults.R = BreachRequirement(mrfResults.currentReqs);
    mrfResults.M = mrfResults.M(:, monitorsToKeep); % should we keep in allM ?..
    mrfResults.res_sensi = mrfResults.res_sensi(monitorsToKeep);
    
    % Update global index and hist
    mrfResults.allB{end+1} = mrfResults.B;
    mrfResults.allR{end+1} = mrfResults.R;
    mrfResults.allM{end+1} = mrfResults.M;
    mrfResults.all_res_sensi{end+1} = res_sensi;
    
    mrfResults.hist.method.sensi(i0:i1) = 1;
    var_values = R_sensi.GetParam(mrfResults.hist.var.names);
    mrfResults.hist.var.values(:,i0:i1)= var_values;
    num_path = num_path+num_path_batch;
    mrfResults.globalIndex = i1+1;
    
end

% Store timing information
mrfResults.hist.time.morris_sensi = toc(startMorrisSensiTime);
fprintf('Morris sensitivity took %.2f seconds to run\n', ...
    mrfResults.hist.time.morris_sensi);

end