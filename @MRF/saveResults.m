function saveResults(mrfResults)
%% Save results
if ~isfolder('results')
    mkdir('results');
end

fieldsToSave = {...
    'firstIdxFalsified', ... % summarizeData/getNumberOfReqs
    'allCurrentReqs', ... % summarizeData/getNumberOfReqs
    'initReqs', ... % summarizeData/getNumberOfReqs
    'hist', ... % summarizeData
    'all_res_sensi', ...
    'B', ... % Just used to get artifical param values
    'focusedReqSelectionMethod', ...
    'requirement_rankings', ...
    'sensitivityMatrix'};

try
    % Save only the fields we need
    for fieldCounter = 1:numel(fieldsToSave)
        thisField = fieldsToSave{fieldCounter};
        eval([thisField ' = mrfResults.' thisField ';']);
    end
    save(mrfResults.resultsFileName, fieldsToSave{:});
    
catch err
    disp(getReport(err));
    % Save using -v7.3 flag in case some variables are very big
    % (can be the case when running many simulations).
    
    save(mrfResults.resultsFileName, 'mrfResults', '-v7.3');
end

disp(['Results saved in ' mrfResults.resultsFileName]);
end