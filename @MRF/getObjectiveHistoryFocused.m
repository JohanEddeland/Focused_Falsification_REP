function [mrfResults, xHist, fHistOfFocusedReq, reqToFocus] = ...
    getObjectiveHistoryFocused(mrfResults)
% GETOBJECTIVEHISTORY  Get the total objective history of all the active
% requirements in the mrfResults object.
%   mrfResults is the MRF object
%   onlyReqWithHighestGap is a flag. If true, we will only select the
%       objective history for the requirement which has the highest
%       difference in robustness value over all simulations.
%
%   xHist is the history of parameter values for the active requirements
%   fHist is the history of objective function values for the active
%       requirements
%   reqWithLowestRob is the INDEX of the requirement with the lowest
%   robustness (of the current active requirements)
%

% First, history from sensitivity analysis
% We need to find the index from the original reqs
currentReqs = mrfResults.currentReqs;
currentReqNames = cellfun(@(x) get_id(x), currentReqs, 'UniformOutput', 0);

%% Get history for all current requirements
idx_not_nan = ~isnan(mrfResults.hist.var.values(1,:));
xHist = mrfResults.hist.var.values(:, idx_not_nan);
fHist = mrfResults.hist.rob.(currentReqNames{1})(idx_not_nan);
for idx_req = 2:numel(currentReqNames)
    fHist = ...
        [fHist ; ...
        mrfResults.hist.rob.(currentReqNames{idx_req})(idx_not_nan)]; %#ok<*AGROW>
end

% Get rankings and relevant data of all methods
[reqGaps, reqGapRankings] = getReqWithLargestGap(fHist);
[reqNumberOfRealSignals, ...
    nTimesEachSignal, ...
    reqRealSignalsRankings, ...
    proportionRealSignalsForEachReq, ...
    proportionRealSignalsRankings] = ...
    getReqNumberOfRealSignals(currentReqs, mrfResults);
[lowRobValues, lowRobRankings] = getLowestRobRankings(fHist);

% Display rankings, for information only
% displayRankingsOfAllSelectionMethods(currentReqNames, ...
%     reqGaps, reqGapRankings, reqNumberOfRealSignals, ...
%     nTimesEachSignal, reqRealSignalsRankings, ...
%     proportionRealSignalsForEachReq, proportionRealSignalsRankings, ...
%     lowRobValues, lowRobRankings);

% Store rankings
for reqCounter = 1:numel(currentReqs)
    thisReqName = currentReqNames{reqCounter};
    
    % largestGap
    thisReqGapRanking = find(reqGapRankings == reqCounter);
    mrfResults.requirement_rankings.largestGap.(thisReqName).ranking(end+1) = thisReqGapRanking;
    mrfResults.requirement_rankings.largestGap.(thisReqName).values(end+1) = reqGaps(thisReqGapRanking);
    
    % mostRealSignals
    mrfResults.requirement_rankings.mostRealSignals.(thisReqName).ranking(end+1) = find(reqRealSignalsRankings == reqCounter);
    thisReqRealSignals = reqNumberOfRealSignals{reqCounter};
    mrfResults.requirement_rankings.mostRealSignals.(thisReqName).values(end+1) = numel(thisReqRealSignals);
    
    % relativeRealSignals
    mrfResults.requirement_rankings.relativeRealSignals.(thisReqName).ranking(end+1) = find(proportionRealSignalsRankings == reqCounter);
    mrfResults.requirement_rankings.relativeRealSignals.(thisReqName).values(end+1) = proportionRealSignalsForEachReq(reqCounter);
    
    % biggestSensitivity
    % TODO
    
    % lowestRobustness
    thisReqLowRob = find(lowRobRankings == reqCounter);
    mrfResults.requirement_rankings.lowestRobustness.(thisReqName).ranking(end+1) = thisReqLowRob;
    mrfResults.requirement_rankings.lowestRobustness.(thisReqName).values(end+1) = lowRobValues(thisReqLowRob);
end

% If exclusion list is full, make sure that it is emptied
allReqsExcluded = 1;
excludedReqNames = cellfun(@(x) get_id(x), mrfResults.exclusionList, 'UniformOutput', 0);
for reqCounter = 1:numel(currentReqNames)
    if ~any(strcmp(excludedReqNames, currentReqNames{reqCounter}))
        allReqsExcluded = 0;
        break
    end
end
if allReqsExcluded
    mrfResults.exclusionList = [];
end

switch mrfResults.focusedReqSelectionMethod
    case 'largestGap'
        listToUse = reqGapRankings;
        
    case 'mostRealSignals'
        listToUse = reqRealSignalsRankings;
        
    case 'lowestRobustness'
        listToUse = lowRobRankings;
        
    otherwise
        error('Unknown method for selecting which requirement to focus');
end

% 1. Exclude all requirements in exclusion list
for reqCounter = 1:numel(mrfResults.exclusionList)
    thisReq = mrfResults.exclusionList{reqCounter};
    thisReqIndex = find(strcmp(currentReqNames, get_id(thisReq)));
    if ~isempty(thisReqIndex)
        listToUse(listToUse == thisReqIndex) = [];
    end
end

% 2. Rearrange list according to test strategy
actList = [];
reqList = [];
for reqCounter = 1:numel(listToUse)
    reqIdx = listToUse(reqCounter);
    if contains(currentReqNames(reqIdx), '_act')
        actList(end+1) = reqIdx;
    else
        reqList(end+1) = reqIdx;
    end
end

switch mrfResults.testStrategy
    case 'either'
        % We don't care whether _req or _act goes first - do nothing!
        
    case 'act'
        % Make _act reqs appear on top
        listToUse = [actList'; reqList'];
        
    case 'req'
        % Make _req reqs appear on top
        listToUse = [reqList'; actList'];
        
    otherwise
        error('Unknown test strategy');
end

% 3. Take the top ranking req remaining
reqToFocus = listToUse(1);

fprintf('\nSelecting requirement %s according to method %s and test strategy ''%s''\n', ...
    currentReqNames{reqToFocus}, mrfResults.focusedReqSelectionMethod, ...
    mrfResults.testStrategy);

% A requirement has been chosen to focus - add to the exclusion list all
% requirements that are "correlated enough" to the focused req
mrfResults.exclusionList{end+1} = mrfResults.currentReqs{reqToFocus};
rob1 = fHist(reqToFocus, :);
for reqCounter = 1:numel(mrfResults.currentReqs)
    if reqCounter == reqToFocus
        % No need to check correlation against itself
        continue
    end
    rob2 = fHist(reqCounter, :);
    
    tmpMin = min(numel(rob1), numel(rob2));
    rob1tmp = rob1(1:tmpMin);
    rob2tmp = rob2(1:tmpMin);
    
    indicesWithInf = unique([find(rob1tmp==Inf) find(rob2tmp==Inf)]);
    indicesWithNan = unique([find(isnan(rob1tmp)) find(isnan(rob2tmp))]);
    indicesToDelete = [indicesWithInf indicesWithNan];
    
    rob1tmp(indicesToDelete) = [];
    rob2tmp(indicesToDelete) = [];
    
    corrMatrix = [rob1tmp' rob2tmp'];
    
    if size(corrMatrix, 1) < 2
        % Less than 2 rows - we can't compute corrcoef
        continue
    end
    [thisCorr, P] = corrcoef(corrMatrix, 'Rows', 'complete');
    
    % We consider them "correlated enough" if the following 3 conditions 
    % are true:
    % 1. p-value < 0.05
    % 2. We removed max one third of indices (by nan or inf)
    % 3. |corrcoef| > 0.95
    cond1 = P(1,2) < 0.05;
    cond2 = numel(indicesToDelete) <= (1/3)*size(fHist, 2);
    cond3 = abs(thisCorr(1,2)) > 0.95;
    if cond1 && cond2 && cond3
        disp(['*** Requirement ' currentReqNames{reqCounter} ...
            ' is highly correlated to ' currentReqNames{reqToFocus} ...
            ' - adding to exclusion list (p=' num2str(P(1,2)) ...
            ', corrcoef=' num2str(thisCorr(1,2)) ')']);
        mrfResults.exclusionList{end+1} = mrfResults.currentReqs{reqCounter};
    elseif cond1 && cond3
        percentageRemoved = 100*numel(indicesToDelete)/size(fHist, 2);
        disp(['(Requirement ' currentReqNames{reqCounter} ...
            ' is highly correlated to ' currentReqNames{reqToFocus} ...
            ', but ' num2str(percentageRemoved) ...
            '% of data points were removed since they were Inf or NaN, so we do not exclude the requirement (p=' ...
            num2str(P(1,2)) ', corrcoef=' num2str(thisCorr(1,2)) ')']);
    end
end

% Print current exclusion list
fprintf('Current exclusion list: ');
for excludedCounter = 1:numel(mrfResults.exclusionList)
    fprintf(get_id(mrfResults.exclusionList{excludedCounter}));
    if excludedCounter < numel(mrfResults.exclusionList)
        fprintf(', ');
    end
end
fprintf('\n');

fHistOfFocusedReq = fHist(reqToFocus, :);


end

function displayRankingsOfAllSelectionMethods(currentReqNames, ...
    reqGaps, reqGapRankings, reqNumberOfRealSignals, ...
    nTimesEachSignal, reqRealSignalsRankings, ...
    proportionRealSignalsForEachReq, proportionRealSignalsRankings, ...
    lowRobValues, lowRobRankings)

% Req gap selections
fprintf('**********************************\n');
fprintf('FOCUSED FALSIFICATION SELECTION RANKINGS\n');
fprintf('**********************************\n');

fprintf('Largest gap\n');
for reqCounter = 1:numel(reqGapRankings)
    thisReq = currentReqNames{reqGapRankings(reqCounter)};
    thisGap = reqGaps(reqCounter);
    fprintf('%d. %s: %.1f\n', reqCounter, thisReq, thisGap);
end

fprintf('\nNumber of real-valued signals\n');
for reqCounter = 1:numel(reqRealSignalsRankings)
    thisIdx = reqRealSignalsRankings(reqCounter);
    thisReq = currentReqNames{thisIdx};
    thisReqRealSignals = reqNumberOfRealSignals{thisIdx};
    thisReqNTimes = nTimesEachSignal{thisIdx};
    fprintf('%d. %s: %d (', ...
        reqCounter, thisReq, numel(thisReqRealSignals));
    for signalCounter = 1:numel(thisReqRealSignals)
        thisSignal = thisReqRealSignals{signalCounter};
        thisNumberOfTimes = thisReqNTimes(signalCounter);
        fprintf('%s %d', thisSignal, thisNumberOfTimes);
        if signalCounter < numel(thisReqRealSignals)
            fprintf(', ');
        end
    end
    fprintf(')\n');
end

fprintf('\nProportion of real-valued signals\n');
for reqCounter = 1:numel(proportionRealSignalsRankings)
    thisReq = currentReqNames{proportionRealSignalsRankings(reqCounter)};
    thisProportion = ...
        proportionRealSignalsForEachReq(proportionRealSignalsRankings(reqCounter));
    fprintf('%d. %s: %.3f\n', reqCounter, thisReq, thisProportion);
end

fprintf('\nLowest robustness\n');
for reqCounter = 1:numel(lowRobRankings)
    thisReq = currentReqNames{lowRobRankings(reqCounter)};
    thisRob = lowRobValues(reqCounter);
    fprintf('%d. %s: %.4f\n', reqCounter, thisReq, thisRob);
end

end

function [reqGaps, reqRankings] = getReqWithLargestGap(fHist)

% Extract the minimum and maximum of each req's robustness history
% We want to exclude the Inf entries, otherwise any requirement with an
% Inf entry and a non-Inf entry would automatically have the largest
% gap.
tmpHist = fHist;
tmpHist(tmpHist>=1000) = -1; % Change Inf and large entries to -1
minOfAllReqs = min(fHist, [], 2);
maxOfAllReqs = max(tmpHist, [], 2);

% Find the requirement index with the highest gap
[reqGaps, reqRankings] = sort(maxOfAllReqs - minOfAllReqs, 'descend');
end

function [lowRobValues, lowRobRankings] = getLowestRobRankings(fHist)
minOfAllReqs = min(fHist, [], 2);
[lowRobValues, lowRobRankings] = sort(minOfAllReqs, 'ascend');
end

function [realSignalsForEachReq, ...
    nTimesEachSignal, ...
    reqRealSignalsRankings, ...
    proportionRealSignalsForEachReq, ...
    proportionRealSignalsRankings] = ...
    getReqNumberOfRealSignals(currentReqs, mrfResults)
% This function returns the relevant information of sorting requirements on
% how many real-valued signals they contain
% realSignalsForEachReq: A cell array with a list of signals for each
%   requirement, where each list contains all real-valued signals for that
%   requirement.
% nTimesEachSignal: A cell array of vectors, where each vector shows the
%   number of times each signal in realSignalsForEachReq occurs in the
%   given requirement (indexed in same order as realSignalsForEachReq).
% reqRealSignalsRankings: Gives the ranking as a list of requirement
%   indices, where the first index is the requirement that should be
%   focused first.

% Define which signals are real and which are discrete
realSignalsForEachReq = cell(size(currentReqs));
nTimesEachSignal = cell(size(currentReqs));
proportionRealSignalsForEachReq = nan(size(currentReqs));

for reqCounter = 1:numel(currentReqs)
    thisReq = currentReqs{reqCounter};
    thisReqString = disp(thisReq);
    signalsInThisReq = STL_ExtractSignals(thisReq);
    realSignalsForThisReq = {};
    nTimesEachSignalThisReq = [];
    discreteSignalsForThisReq = {};
    for signalCounter = 1:numel(signalsInThisReq)
        thisSignal = signalsInThisReq{signalCounter};
        
        if any(strcmp(mrfResults.discreteValuedSignals, thisSignal))
            % Discrete signal
            discreteSignalsForThisReq{end+1} = thisSignal;
        else
            realSignalsForThisReq{end+1} = thisSignal;
            strIndices = strfind(thisReqString, [thisSignal '[']);
            nTimesEachSignalThisReq(end+1) = numel(strIndices);
        end
    end
    
    realSignalsForEachReq{reqCounter} = realSignalsForThisReq;
    nTimesEachSignal{reqCounter} = nTimesEachSignalThisReq;
    
    proportionRealSignalsForEachReq(reqCounter) = ...
        numel(realSignalsForThisReq)/(numel(discreteSignalsForThisReq) + numel(realSignalsForThisReq));
end

% Now we sort reqs to get rankings
% First, sort by number of real-valued signals
% If they are equal, sort secondarily by number of total appearances of
% real-valued signals
firstIndexToSortBy = ...
    transpose(cellfun(@(c)numel(c), realSignalsForEachReq));
secondIndexToSortBy = transpose(cellfun(@(c)sum(c), nTimesEachSignal));
[~, reqRealSignalsRankings] = ...
    sortrows([firstIndexToSortBy secondIndexToSortBy], 'descend');

% Sort to get proportion of real signals rankings as well
[~, proportionRealSignalsRankings] = ...
    sort(proportionRealSignalsForEachReq, 'descend');

end


