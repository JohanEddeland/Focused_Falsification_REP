function runManyMRF(totalMaxEval, allRandomSeeds, allConfigurationFiles, allFalsificationModes)
% Run many experiments with the Multi-Requirement Falsification (MRF)
% algorithm presented in the paper. 
%
% Args:
%       totalMaxEval (integer): Number of maximum simulations for each
%           combination of random seed, configuration file, and 
%           optimization solver.
%       allRandomSeeds (list): A list containing all the seeds to run. 
%       allConfigurationFiles (cell of strings): A cell array containing
%           strings. Each string is the name of one configuration file,
%           e.g. 'all_base_v1.0.1.mat' (this file loads parameters with the
%           base scenario). 
%       allFalsificationModes (cell of strings): A cell containing strings.
%           Each string is the name of an accepted solver. 
%
% Returns:
%    

% record algorithms outputs
diary(['run_' datestr(now, 'yyyy_mm_dd_HHMMSS') '.log']);

% Normalize all predicates from now on
global BreachGlobOpt;
BreachGlobOpt.NormalizePredicates = 1;

model = 'AT_and_specifications';

for seedCounter = 1:numel(allRandomSeeds)
    thisSeed = allRandomSeeds(seedCounter);
    for fileCounter = 1:numel(allConfigurationFiles)
        thisFile = allConfigurationFiles{fileCounter};
        for modeCounter = 1:numel(allFalsificationModes)
            thisMode = allFalsificationModes{modeCounter};
            
            if contains(thisFile, '_artificial')
                % The parameters we load include "artificial" specs
                % We tell MRF to use the model with "artificial" in the
                % name (AT_and_specifications_artificial)
                modelToUse = [model '_artificial'];
            else
                modelToUse = model;
            end
            useIOSTL = false;
            [B, R, currentReqs, discreteValuedSignals] = ...
                setupAndLoadParamsMRF(modelToUse, thisFile, useIOSTL);
            mrfResults = MRF(modelToUse, totalMaxEval, B, R, ...
                currentReqs, thisFile, thisMode, thisSeed);
            
            mrfResults.discreteValuedSignals = discreteValuedSignals;
            mrfResults.parallelBatchSize = 50;
            mrfResults.par_sim = false;
            mrfResults.par_req_eval = false;
            mrfResults.focusedReqSelectionMethod = 'lowestRobustness';
            mrfResults.testStrategy = 'either';
            
            if exist(mrfResults.resultsFileName, 'file')
                disp([mrfResults.resultsFileName ' already exists! Skipping this scenario.']);
            else
                mrfResults = mrfResults.run(); 
            end
                        
        end
    end
end
diary off;

end
