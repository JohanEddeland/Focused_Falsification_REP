function mrfResults = runFalsificationCorners(mrfResults)
startCornersTime = tic;
pbc = FalsificationProblem(mrfResults.B, mrfResults.R);
num_signals = numel(mrfResults.R.signals_in);
nCorners = min(10*num_signals, floor(mrfResults.totalMaxEval/3)); % bounding to a third of total number of simulation

if contains(mrfResults.falsificationMode, 'focused')
	disp(['Running ADAPTIVE CORNERS for focused falsification (' ...
        mrfResults.falsificationMode ')']);
	
	pbc.setup_adaptive_corners('num_corners', nCorners, 'relative_threshold', 0.25);
	pbc.max_obj_eval = nCorners;
	pbc.StopAtFalse = false;
	pbc.use_parallel = mrfResults.par_sim;
	pbc.parallelBatchSize = mrfResults.parallelBatchSize;
	pbc.solve();
    
    % Update nCorners to the ACTUAL number of corners run
    nCorners = pbc.nb_obj_eval;
else
	disp('Running corners falsification (not focused falsification)');
	
	pbc.setup_corners('num_corners', nCorners);
	pbc.max_obj_eval = nCorners;
	pbc.StopAtFalse = false;
	pbc.use_parallel = mrfResults.par_sim;
	pbc.parallelBatchSize = mrfResults.parallelBatchSize;
	pbc.solve();
end

%% Check monitors falsified with corners
monitorsToRemove = []; % Indices of monitors to remove
fprintf('\n====== CORNERS ANALYSIS ======\n');
objLogCorners = pbc.obj_log;

minRobAllSpecs = inf(numel(mrfResults.R.req_monitors), 1);
firstIdxFalsifiedVector = inf(numel(mrfResults.R.req_monitors), 1);

for cornerCounter = 1:nCorners
    minRobAllSpecs = min(minRobAllSpecs, objLogCorners(:, cornerCounter));
    for specCounter = 1:numel(minRobAllSpecs)
        if isinf(firstIdxFalsifiedVector(specCounter)) && minRobAllSpecs(specCounter) < 0
            firstIdxFalsifiedVector(specCounter) = cornerCounter;
        end
    end
end

for monitorCounter = 1:numel(mrfResults.currentReqs)
    if firstIdxFalsifiedVector(monitorCounter) < Inf
        formula_id = mrfResults.R.req_monitors{monitorCounter}.formula_id;
        disp(['Monitor ' formula_id ...
            ' falsified during corners analysis! Will be removed ...']);
        monitorsToRemove(end+1) = monitorCounter; %#ok<*SAGROW>
        
        % Store in a struct which index the spec was failed for
        mrfResults.firstIdxFalsified(end+1).id = formula_id;
        mrfResults.firstIdxFalsified(end).index = ...
            firstIdxFalsifiedVector(monitorCounter);
        mrfResults.firstIdxFalsified(end).globalIndex = ...
            mrfResults.globalIndex + firstIdxFalsifiedVector(monitorCounter) - 1;
        mrfResults.firstIdxFalsified(end).falsification = 'corners';
        
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
end

%% Update hist
idx_start = mrfResults.globalIndex;
idx_end =  idx_start+size(pbc.obj_log,2)-1;

mrfResults = updateHistFromFalsifPb(mrfResults, pbc, idx_start, idx_end);

for idx_req = 1:numel(mrfResults.currentReqs)       
    mrfResults.hist.rob.(get_id(mrfResults.currentReqs{idx_req}))(idx_start:idx_end)= pbc.obj_log(idx_req,:);
    mrfResults.hist.method.corners(idx_start:idx_end)=1;
end

if isempty(monitorsToRemove)
    disp('Corner analysis: No monitors removed');
    mrfResults.allCurrentReqs{end+1} = mrfResults.allCurrentReqs{end};
else
    monitorsToKeep = setdiff(1:numel(mrfResults.currentReqs), monitorsToRemove);
    mrfResults.currentReqs = mrfResults.currentReqs(monitorsToKeep);
    mrfResults.R = BreachRequirement(mrfResults.currentReqs);
    mrfResults.allCurrentReqs{end+1} = mrfResults.allCurrentReqs{end}(monitorsToKeep);
    if ~isempty(mrfResults.M)
        mrfResults.M = mrfResults.M(:, monitorsToKeep);
        %mrfResults.avgRobFromSensiAnalysis = mrfResults.avgRobFromSensiAnalysis(monitorsToKeep);
    end
end

%% Update global index
mrfResults.globalIndex = idx_end+1;

%% Store results variables
mrfResults.allB{end+1} = mrfResults.B;
mrfResults.allR{end+1} = mrfResults.R;
mrfResults.allFalsifProblems{end+1} = pbc;

% Store timing information
mrfResults.hist.time.corners = toc(startCornersTime);
fprintf('runFalsificationCorners took %.2f seconds to run\n', ...
    mrfResults.hist.time.corners);

end