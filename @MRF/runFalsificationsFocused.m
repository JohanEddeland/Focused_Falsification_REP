function mrfResults = runFalsificationsFocused(mrfResults, solver)
% Run focused falsification using a specified solver
% We require that the solver can take previous history of the objective
% function when creating an optimization problem, meaning that it should be
% possible to set 'start_sample' and 'start_function_values'

iterationCounter = 1;

nTotalSimulationsPerformed = mrfResults.globalIndex-1;
startingNumberOfMonitors = numel(mrfResults.initReqs);

% Maximum number of function evaluations for each falsification problem
% Current heuristic: Use approximately one third of all evaluations as
% maximum (rounded down)
falsificationMaxEval = floor(mrfResults.totalMaxEval/10);

while (numel(mrfResults.currentReqs) > 0) && ...
        nTotalSimulationsPerformed < mrfResults.totalMaxEval-1
    
    startFocusedIterationTime = tic;
    
    % Display header for this iteration
    fprintf('\n===================================\n');
    disp(['Starting iteration ' num2str(iterationCounter) ...
        ' (simulation budget ' num2str(nTotalSimulationsPerformed) ...
        '/' num2str(mrfResults.totalMaxEval) ')']);
    disp(['Running falsification for ' ...
        num2str(numel(mrfResults.currentReqs)) ...
        ' monitors (started with ' num2str(startingNumberOfMonitors) ')']);
    
    % Initialize inputs for the monitors we have:
    % For each input, if there is no monitor that is sensitive to it, we
    % set it to 0
    for inputCounter = 1:numel(mrfResults.inputList)
        if all(mrfResults.M(inputCounter, :) == 0)
            % No monitor is sensitive to this input
            thisInput = mrfResults.inputList{inputCounter};
        end
    end
    
    % NOTE: We actually always set simulation time to 30s, since that is
    % what is always should be for ARCH benchmarks.
    mrfResults.B.SetTime(30);
    
    % Get the history of objective function values, ONLY for the given
    % requirements that are left.
    % TODO: Implement different ways of choosing focused req, rather than
    % just looking at "biggest gap"
    [mrfResults, xHist, fHist, reqIndexToFocus] = ...
        getObjectiveHistoryFocused(mrfResults);
    
    % Create the FalsificationProblem
    reqToFalsify = mrfResults.currentReqs{reqIndexToFocus};
    disp(['Focusing on ' get_id(reqToFalsify)]);
        
    % Get the stochastic (non-sensitive) parameters
    stochasticParams = getStochasticParameters(mrfResults, reqToFalsify);
    stochasticDomains = mrfResults.B.GetDomain(stochasticParams);
    
    % Create the problem
    falsif_pb = FalsificationProblem(mrfResults.B, reqToFalsify);
    
    % Set basic parameters
    falsif_pb.max_obj_eval = min(falsificationMaxEval, ...
        mrfResults.totalMaxEval - nTotalSimulationsPerformed);
    falsif_pb.freq_update = ceil(falsif_pb.max_obj_eval / 50);
        
    % Use parallel calculations
    falsif_pb.use_parallel = mrfResults.par_sim;
    
    % Set stochastic parameters
    % NOTE: We can only do this if there is at least one NON-stochastic
    % parameter. 
    allParamsFromStart = mrfResults.inputList;
    if numel(stochasticParams) < numel(allParamsFromStart) && ...
            numel(stochasticParams) > 0
        falsif_pb.set_stochastic_params(stochasticParams, stochasticDomains);
    end
    
    % We now have the stochastic parameters - extract the xHist for the
    % NON-stochastic parameters.
    % Find how the indices in falsif_pb.params correspond to the parameters
    % in mrfResults.B (we get xHist from mrfResults.b in
    % getObjectiveHistory). Then extract the history for only those
    % variables. 
    % We need to extract xHist in this way because it is used in
    % the setup of the solver
    paramsInB = mrfResults.B.GetVariables;
    indexOfParamsInB = cellfun(@(x)find(strcmp(paramsInB, x), 1), falsif_pb.params);
    xHist = xHist(indexOfParamsInB, :);
    
    % Use the given xHist and fHist as history when setting up solver
    setup_function_to_eval = ...
        sprintf('falsif_pb.setup_%s(''start_sample'', xHist, ''start_function_values'', fHist);', ...
        solver);
    eval(setup_function_to_eval);
    
    % Parallel pool might have timed out - we must make sure
    % each worker has fixedStepSize defined in their base
    % workspace (see details in comment in setup function of
    % MRF.m).
    if mrfResults.par_sim || mrfResults.par_req_eval
        parfevalOnAll(@() (evalin('base','initializeReqParameters;')),0);
    end
    
    % Solve the falsificationProblem
    falsif_pb.solve();
    nTotalSimulationsPerformed = nTotalSimulationsPerformed + ...
        falsif_pb.nb_obj_eval;
    
    % Record this requirement as focused (so we don't focus it again)
    mrfResults.focusedRequirements{end+1} = get_id(reqToFalsify);
    
    % After falsification, we need to specifically calculate the history of
    % all other requirements (that were NOT the focus of the
    % falsification). 
    Rlog = falsif_pb.GetLog();
    BrLog = Rlog.BrSet;
    Rcurrent = BreachRequirement(mrfResults.currentReqs);
    Rcurrent.Eval(BrLog); % Get robustness values
    
    % Store the Rcurrent in the "focused history" variable
    mrfResults.allFocusedHistory{end+1} = Rcurrent;
    
    % Store results variables
    mrfResults.allB{end+1} = mrfResults.B;
    mrfResults.allR{end+1} = mrfResults.R;
    mrfResults.allM{end+1} = mrfResults.M;
    mrfResults.allFalsifProblems{end+1} = falsif_pb;
    
    %% Eval rob for other requirements
    
    num_samples =  size(Rcurrent.traces_vals, 1);    
    idx_start = mrfResults.globalIndex;
    idx_end = mrfResults.globalIndex+num_samples-1;
        
    for monitorCounter = 1:numel(mrfResults.currentReqs)
        formula_id = mrfResults.R.req_monitors{monitorCounter}.formula_id;
        thisRob = Rcurrent.traces_vals(:,monitorCounter)';                
        mrfResults.hist.rob.(formula_id)(idx_start:idx_end)= thisRob;        
    end
    var_values = Rcurrent.GetParam(mrfResults.hist.var.names);
    mrfResults.hist.var.values(:,idx_start:idx_end)= var_values;
    
    mrfResults.hist.focused.(get_id(reqToFalsify))(idx_start:idx_end) = 1;
    mrfResults.hist.focused.req_idx(idx_start:idx_end) = find(strcmp(mrfResults.initReqsNames, get_id(reqToFalsify)),1);       
    mrfResults.hist.method.focused.(get_id(reqToFalsify))(idx_start:idx_end) = 1;
    mrfResults.hist.method.focused.req_idx(idx_start:idx_end) = find(strcmp(mrfResults.initReqsNames, get_id(reqToFalsify)),1);     
    
    monitorsToRemove = []; % Indices of monitors to remove
    for monitorCounter = 1:numel(mrfResults.currentReqs)
        [minRob, minIdx] = min(Rcurrent.traces_vals(:, monitorCounter));
        formula_id = mrfResults.R.req_monitors{monitorCounter}.formula_id;
        fprintf([formula_id ...
            ' min rob: ' num2str(minRob) ' at traj ' num2str(minIdx)]);
        if minRob < 0
            fprintf('. FALSIFIED! Removing ...');
            monitorsToRemove(end+1) = monitorCounter;
            
            % Store in a struct which index the spec was failed for
            firstNegativeRobIdx = find(Rcurrent.traces_vals(:, monitorCounter) < 0, 1);
            mrfResults.firstIdxFalsified(end+1).id = formula_id;
            mrfResults.firstIdxFalsified(end).index = firstNegativeRobIdx;
            mrfResults.firstIdxFalsified(end).globalIndex = ...
                nTotalSimulationsPerformed - falsif_pb.nb_obj_eval + firstNegativeRobIdx;
            mrfResults.firstIdxFalsified(end).falsification = ...
                ['falsification ' num2str(iterationCounter)];
        end
        fprintf('\n');
    end
    
    if isempty(monitorsToRemove)
        disp(['Iteration ' num2str(iterationCounter) ...
            ': No monitors removed. ']);
        
        mrfResults.allCurrentReqs{end+1} = mrfResults.allCurrentReqs{end};
    else
        monitorsToKeep = setdiff(1:numel(mrfResults.currentReqs), monitorsToRemove);
        mrfResults.currentReqs = mrfResults.currentReqs(monitorsToKeep);
        mrfResults.allCurrentReqs{end+1} = mrfResults.allCurrentReqs{end}(monitorsToKeep);
        mrfResults.R = BreachRequirement(mrfResults.currentReqs);
        mrfResults.M = mrfResults.M(:, monitorsToKeep);
    end
    
    % Store timing information
    specnameAndIteration = [get_id(reqToFalsify) '_' ...
        num2str(iterationCounter)];
    mrfResults.hist.time.(specnameAndIteration) = ...
        toc(startFocusedIterationTime);
    fprintf('Focused iteration of %s (iteration %d) took %.2f seconds to run\n', ...
        get_id(reqToFalsify), iterationCounter, ...
        mrfResults.hist.time.(specnameAndIteration));
    
    iterationCounter = iterationCounter + 1;
    
    %% Update global index
    mrfResults.globalIndex = idx_end+1;
    
    
    
end
end