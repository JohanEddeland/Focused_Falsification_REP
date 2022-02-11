function stochasticParams = ...
    getStochasticParameters(mrfResults, reqToFalsify)

if mrfResults.useStructuralSensitivity
    stochasticParams = getStochParamsStructural(mrfResults, reqToFalsify);
    
    % Check which stochastic params Morris would've found, in order to see
    % if structural sensitivity found more
    morrisStochParams = getStochParamsMorris(mrfResults, reqToFalsify);
    diffParams = setdiff(morrisStochParams, stochasticParams);
    if ~isempty(diffParams)
        fprintf('*** Structural sens found the following sensitive params that Morris did NOT find: ');
        for k = 1:numel(diffParams)
            thisParam = diffParams{k};
            fprintf(thisParam);
            fprintf(' ');
        end
        fprintf('\n');
    end
    
else
    stochasticParams = getStochParamsMorris(mrfResults, reqToFalsify);
end

end

function stochasticParams = ...
    getStochParamsStructural(mrfResults, reqToFalsify)
% Return the stochastic (i.e. non-sensitive) parameters based on structural
% sensitivity analysis performed in performSensitivityAnalysis.m

initReqNames = cellfun(@(x)get_id(x), mrfResults.initReqs, ...
    'UniformOutput', false);
reqIndexToFalsify = strcmp(initReqNames, get_id(reqToFalsify));
stochParamsIndex = mrfResults.sensitivityMatrix(:, reqIndexToFalsify) == 0;
stochasticParams = mrfResults.inputList(stochParamsIndex);

fprintf('Stochastic parameters (using STRUCTURAL sensitivity): ');
for k = 1:numel(stochasticParams)
    thisParam = stochasticParams{k};
    fprintf(thisParam);
    fprintf(' ');
end
fprintf('\n');

end

function stochasticParams = ...
    getStochParamsMorris(mrfResults, reqToFalsify)
% Return the stochastic (i.e. non-sensitive) parameters based on Morris
% sensitivity analysis performed in performSensitivityAnalysis.m

% Set insensitive parameters to stochastic
allParamsFromStart = mrfResults.inputList;
allMu = zeros(numel(allParamsFromStart), numel(mrfResults.allM));
cumulativeNonZeroMu = zeros(numel(allParamsFromStart), 1);

for mCounter = 1:numel(mrfResults.allM)
    thisM = mrfResults.allM{mCounter};
    
    % The index for mrfResults.allCurrentReqs is offset by 2 because
    % allM starts recording after first sensi iteration, and the first
    % 2 entries of allCurrentReqs are in:
    % 1. Constructor of MRF.m
    % 2. End of runFalsificationCorners.m
    allReqIndicesThisIteration = ...
        mrfResults.allCurrentReqs{2 + mCounter};
    allReqsThisIteration = ...
        mrfResults.initReqs(allReqIndicesThisIteration);
    allReqNamesThisIteration = ...
        cellfun(@(c)get_id(c), allReqsThisIteration, 'UniformOutput', false);
    focusedReqIndexThisIteration = ...
        strcmp(allReqNamesThisIteration, get_id(reqToFalsify));
    thisMu = thisM(:, focusedReqIndexThisIteration);
    allMu(:, mCounter) = thisMu;
    
    % Keep track of cumulative non-zero
    cumulativeNonZeroMu = ...
        or(cumulativeNonZeroMu, thisMu ~= 0);
end

stochasticParams = {};
fprintf('Stochastic parameters (using MORRIS sensitivity): ');
for k = 1:numel(allParamsFromStart)
    if cumulativeNonZeroMu(k) == 0
        % This requirement is not sensitive to the given parameter
        thisParam = allParamsFromStart{k};
        stochasticParams{end+1} = thisParam; %#ok<*AGROW>
        fprintf(thisParam);
        fprintf(' ');
    end
end
fprintf('\n');

end