function summarizer = loadRuns(summarizer, nSim)

% Get the seeds of all complete runs, as well as the number of simulations
% used. NOTE: We assert in getCompleteRuns that the number of simulations
% is the same for ALL .mat files in the folder!
seeds = summarizer.getCompleteRuns(nSim);

% Display which seeds were found to have complete runs.
disp(['The following runs (.mat files) were found in folder ' ...
    summarizer.runFolder ':'])
fprintf('Seeds');
for k = 1:numel(seeds)
    fprintf(' %d', seeds(k));
end
fprintf('\n');

% The .mat files contain information in the name that we can simply "build
% up" to get the complete filename.
modeStrings = {'base_', 'hard_'};
artStrings = {'', 'artificial_'};
solverStrings = {'corners_pseudorandom_', 'focused_snobfit_'};
simString = ['sim' num2str(nSim) '_'];

% Loop over all 8 combinations for each seed.
for modeCounter = 1:numel(modeStrings)
    modeString = modeStrings{modeCounter};
    for artCounter = 1:numel(artStrings)
        artString = artStrings{artCounter};
        for solverCounter = 1:numel(solverStrings)
            solverString = solverStrings{solverCounter};
            
            % Load the corresponding file for each seed
            for seedCounter = 1:numel(seeds)
                seedString = ['seed' num2str(seeds(seedCounter))];
                completeFileName = [summarizer.runFolder '/' solverString ...
                    artString modeString simString seedString '.mat'];
                
                if exist([completeFileName], 'file')
                    fprintf(['Loading ' completeFileName ' ... ']);
                    
                    % Find out if saved the old way (mrfResults object) or
                    % new way (separate structures)
                    variableList = who('-file', completeFileName);
                    
                    if (numel(variableList) == 1 && ...
                            strcmp(variableList{1}, 'mrfResults'))
                        % Old way
                        load(completeFileName); % loads 'mrfResults' object
                    else
                        % New way
                        % Loads 'mrfResults' as just a STRUCT!
                        mrfResults = load(completeFileName);
                    end
                    
                    
                    fprintf('Done! ');
                else
                    if summarizer.requireCompleteRuns
                        error(['File ' completeFileName ' is missing']);
                    else
                        continue
                    end
                end
                
                % Display in the MATLAB command window how many reqs were
                % falsified for this scenario.
                [nReqsAtStart, nReqsFalsified, nReqsAtStart_art, ...
                    nReqsFalsified_art, nReqsFalsifiedCountAct, ...
                    nSafetyReqFalsified] = ...
                    getNumberOfReqs(mrfResults);
                fprintf('%d / %d reqs falsified (%d reqs falsified counting _act/_req relationship)\n', ...
                    nReqsFalsified, nReqsAtStart, nReqsFalsifiedCountAct);
                initReqNames = cellfun(@(x)get_id(x), mrfResults.initReqs, 'UniformOutput', false);
                nSafetyReqs = sum(contains(initReqNames, '_req'));
                fprintf('False(T, R) = %d / %d\n', nSafetyReqFalsified, nSafetyReqs);
                
                % Store the data of falsified and started reqs for this
                % scenario.
                summarizer.allReqsFalsified(modeCounter, artCounter, solverCounter, seedCounter) = nReqsFalsified; %#ok<*AGROW,*SAGROW>
                summarizer.allReqsStarted(modeCounter, artCounter, solverCounter, seedCounter) = nReqsAtStart;
                summarizer.nSafetyReqs(modeCounter, artCounter, solverCounter, seedCounter) = nSafetyReqs;
                summarizer.allReqsFalsified_art(modeCounter, artCounter, solverCounter, seedCounter) = nReqsFalsified_art;
                summarizer.allReqsStarted_art(modeCounter, artCounter, solverCounter, seedCounter) = nReqsAtStart_art;
                summarizer.allReqsFalsifiedCountAct(modeCounter, artCounter, solverCounter, seedCounter) = nReqsFalsifiedCountAct;
                summarizer.allSafetyReqFalsified(modeCounter, artCounter, solverCounter, seedCounter) = nSafetyReqFalsified;
                summarizer.allHist{modeCounter, artCounter, solverCounter, seedCounter} = mrfResults.hist;
                summarizer.allResSensi{modeCounter, artCounter, solverCounter, seedCounter} = mrfResults.all_res_sensi;
                summarizer.allCurrentReqs{modeCounter, artCounter, solverCounter, seedCounter} = mrfResults.allCurrentReqs;
                summarizer.allInitReqs{modeCounter, artCounter, solverCounter, seedCounter} = mrfResults.initReqs;
                summarizer.allReqRankings{modeCounter, artCounter, solverCounter, seedCounter} = mrfResults.requirement_rankings;
                summarizer.allSensitivityMatrix{modeCounter, artCounter, solverCounter, seedCounter} = mrfResults.sensitivityMatrix;
                
                % Store data regarding first index falsified for each
                % requirement
                firstIdxFalsified = mrfResults.firstIdxFalsified;
                for idxCounter = 1:numel(firstIdxFalsified)
                    id = firstIdxFalsified(idxCounter).id;
                    if isempty(id)
                        continue
                    else
                        summarizer.firstIndexFalsifiedStruct(modeCounter, artCounter, solverCounter, seedCounter).(id) = ...
                            firstIdxFalsified(idxCounter).globalIndex;
                    end
                    
                end
                
                summarizer.robHist = mrfResults.hist.rob;
                histFieldNames = fieldnames(summarizer.robHist);
                for idxCounter = 1:numel(histFieldNames)
                    id = histFieldNames{idxCounter};
                    summarizer.histStruct(modeCounter, artCounter, solverCounter, seedCounter).(id) = ...
                        summarizer.robHist.(id);
                end
                fprintf('\n');
            end
            
        end
    end
end

% It might be the case that firstIndexFalsifiedStruct does not have all
% reqs in it. To be sure, we load all requirements in from the mrfResults
% variable.
firstCurrentReqs = mrfResults.initReqs;
for reqCounter = 1:numel(firstCurrentReqs)
    thisReq = firstCurrentReqs{reqCounter};
    thisReqId = get_id(thisReq);
    if ~isfield(summarizer.firstIndexFalsifiedStruct, thisReqId)
        summarizer.firstIndexFalsifiedStruct(1).(thisReqId) = [];
    end
end

% This function creates the file MRF_table.tex, which can then be included
% in a LaTeX document to show a formatted table.
summarizer.B = mrfResults.B; % Doesn't matter which mrfResults we get B from, it is just used to get artificial param values

% We have now taken the time to load several .mat files and stored the
% relevant data in a few variables. Store these variables for more
% convenient re-drawing of table (and sharing of data).
save(['MRF_table_data_' summarizer.runFolder '.mat'], ...
    'summarizer');
end

function [nReqsAtStart, nReqsFalsified, ...
    nReqsAtStart_art, nReqsFalsified_art, ...
    nReqsFalsifiedCountAct, nSafetyReqFalsified] = ...
    getNumberOfReqs(mrfResults)
% The first entry in firstIdxFalsified can be empty - fix this
if isempty(mrfResults.firstIdxFalsified(1).id)
    mrfResults.firstIdxFalsified(1) = [];
end
firstIdxFalsified = [mrfResults.firstIdxFalsified.globalIndex];

nReqsAtStart = numel(mrfResults.allCurrentReqs{1});
nReqsFalsified = sum(~isinf(firstIdxFalsified));

reqNames = cellfun(@(x)get_id(x), mrfResults.initReqs, 'UniformOutput', false);
artIndex = contains({mrfResults.firstIdxFalsified.id}, '_art');
firstIdxFalsified_art = [mrfResults.firstIdxFalsified(artIndex).globalIndex];
nReqsFalsified_art = sum(~isinf(firstIdxFalsified_art));
nReqsAtStart_art = sum(contains(reqNames, '_art'));


% Finally, nReqsFalsifiedCountAct - we count nFalsified, but if _act is not
% falsified but corresponding _req is falsified, we count the _act as
% falsified anyway!
% This is because focused_snobfit handles specs this way (ignores _act if
% corresponding _req is already falsified)
nReqsFalsifiedCountAct = 0;
nSafetyReqFalsified = 0;
falsifiedReqNames = {mrfResults.firstIdxFalsified.id};
for reqCounter = 1:numel(reqNames)
    thisReq = reqNames{reqCounter};
    if any(contains(falsifiedReqNames, thisReq))
        nReqsFalsifiedCountAct = nReqsFalsifiedCountAct + 1;
        if contains(thisReq, '_req')
            % Safety req falsified
            nSafetyReqFalsified = nSafetyReqFalsified + 1;
        end
    elseif contains(thisReq, '_act')
        % _act is not falsified
        % Check if corresponding _req is falsified - if so, increase
        % nReqsFalsifiedCountAct
        correspondingReqSpec = regexprep(thisReq, '_act\d*', '_req');
        if any(contains(falsifiedReqNames, correspondingReqSpec))
            nReqsFalsifiedCountAct = nReqsFalsifiedCountAct + 1;
        end
    end
end
end