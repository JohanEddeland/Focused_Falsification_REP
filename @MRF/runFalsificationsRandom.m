function mrfResults = runFalsificationsRandom(mrfResults, nRandom)
startRandomTime = tic;
pbr = FalsificationProblem(mrfResults.B, mrfResults.R);

if nargin<2
    nRandom = mrfResults.totalMaxEval-mrfResults.globalIndex + 1; % finishes budget by default
end
pbr.setup_random('num_rand_samples', nRandom,...
    'rand_seed', mrfResults.randomSeed);
pbr.max_obj_eval = nRandom;
pbr.StopAtFalse = false;
pbr.use_parallel = mrfResults.par_sim;
pbr.parallelBatchSize = mrfResults.parallelBatchSize;
pbr.solve();

%% Check monitors falsified with random
monitorsToRemove = []; % Indices of monitors to remove
fprintf('\n====== RANDOM ANALYSIS ======\n');
objLogRandom = pbr.obj_log;

minRobAllSpecs = inf(numel(mrfResults.R.req_monitors), 1);
firstIdxFalsifiedVector = inf(numel(mrfResults.R.req_monitors), 1);

for cornerCounter = 1:nRandom
    minRobAllSpecs = min(minRobAllSpecs, objLogRandom(:, cornerCounter));
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
            ' falsified during random analysis! Will be removed ...']);
        monitorsToRemove(end+1) = monitorCounter; %#ok<*SAGROW>
        
        % Store in a struct which index the spec was failed for
        mrfResults.firstIdxFalsified(end+1).id = formula_id;
        mrfResults.firstIdxFalsified(end).index = ...
            firstIdxFalsifiedVector(monitorCounter);
        mrfResults.firstIdxFalsified(end).globalIndex = ...
            mrfResults.globalIndex + firstIdxFalsifiedVector(monitorCounter);
        mrfResults.firstIdxFalsified(end).falsification = 'random';
                
        % If it is a safety requirement, also remove all corresponding
        % activation requirements
        if contains(formula_id, '_req')
            formula_without_req = strrep(formula_id, '_req', '');
            for monitorCounter2 = 1:numel(mrfResults.currentReqs)
                other_formula_id = mrfResults.R.req_monitors{monitorCounter2}.formula_id;
                if contains(other_formula_id, formula_without_req) && ...
                        contains(other_formula_id, '_act')                    
                    disp([' --- Also removing ' other_formula_id ...
                        ' (corresponding activation requirement)']);
                    monitorsToRemove(end+1) = monitorCounter2;
                end
            end
        end
        
    end
end

%% Update hist
idx_start = mrfResults.globalIndex;
idx_end =  idx_start+size(pbr.obj_log,2)-1;
for idx_req = 1:numel(mrfResults.currentReqs)   
    mrfResults.hist.rob.(get_id(mrfResults.currentReqs{idx_req}))(idx_start:idx_end)= pbr.obj_log(idx_req,:);
    mrfResults.hist.method.random(idx_start:idx_end)=1;
end

if isempty(monitorsToRemove)
    disp('Random analysis: No monitors removed');
    mrfResults.allCurrentReqs{end+1} = mrfResults.allCurrentReqs{end};
else
    monitorsToKeep = setdiff(1:numel(mrfResults.currentReqs), monitorsToRemove);
    mrfResults.allCurrentReqs{end+1} = mrfResults.allCurrentReqs{end}(monitorsToKeep);
    mrfResults.currentReqs = mrfResults.currentReqs(monitorsToKeep);
    mrfResults.R = BreachRequirement(mrfResults.currentReqs);
    if ~isempty(mrfResults.M)
        mrfResults.M = mrfResults.M(:, monitorsToKeep);
        mrfResults.avgRobFromSensiAnalysis = mrfResults.avgRobFromSensiAnalysis(monitorsToKeep);
    end
end

%% Update global index
mrfResults.globalIndex = mrfResults.globalIndex+size(objLogRandom,2)+1;

%% Store results variables
mrfResults.allB{end+1} = mrfResults.B;
mrfResults.allR{end+1} = mrfResults.R;
mrfResults.allM{end+1} = mrfResults.M;

mrfResults.allFalsifProblems{end+1} = pbr;

% Store timing information
mrfResults.hist.time.random = toc(startRandomTime);
fprintf('runFalsificationRandom took %.2f seconds to run\n', ...
    mrfResults.hist.time.random);


end