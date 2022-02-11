function printDataToLatexWithRankings(summarizer)
% PRINTDATATOLATEXWITHRANKINGS   Visualizes MRF rankings in a Latex table.
%   This function prints a table that indicates how different requirements
%   are ranked based on the different available rankings in the MRF object.
%   These rankings are supposed to be used for intermediate analysis of
%   results. For final results, i.e. paper-ready results, see
%   PRINTFINALLATEXTABLES. 
fid = fopen(summarizer.latexTableFileWithRankings, 'w');

colorOrder =  {'RoyalPurple', 'Bittersweet', 'ForestGreen', 'GreenYellow', ...
    'Blue', 'BurntOrange', 'CadetBlue', 'TealBlue', ...
    'DarkOrchid', 'Fuchsia', 'BrickRed', };

% Total number of columns:
% 1 for req names
% Base/Hard, Non-art/Art, then CPR + SNOBFIT + 1 for each ranking
% Total: 1 + (2*2*(2+nRankings))
nModes = size(summarizer.allReqRankings, 1);
nArt = size(summarizer.allReqRankings, 2);
nSolvers = 2 + numel(summarizer.rankingsToVisualizeInTable);

nColumns = 1 + (nModes*nArt*nSolvers);


fprintf(fid, '\\begin{tabular}{');
% Insert the actual columns
fprintf(fid, 'c|');
for k = 1:nColumns-1
    if mod(k, nSolvers)==0
        fprintf(fid, 'c|');
    else
        fprintf(fid, 'c');
    end
end

fprintf(fid, '}\n');
fprintf(fid, '\\hline\n\n');

% Header
alphabet = 'abcdefghijkl';

fprintf(fid, ['\\multicolumn{' ...
    num2str(nColumns) '}{c}{']);

for rankingCounter = 1:numel(summarizer.rankingsToVisualizeInTable)
    thisString = summarizer.rankingsToVisualizeInTable{rankingCounter};
    fprintf(fid, ['\\textcolor{' ...
        colorOrder{rankingCounter} '}{' ...
        alphabet(rankingCounter) ': ' thisString '}']);
    if rankingCounter < numel(summarizer.rankingsToVisualizeInTable)
        fprintf(fid, ', ');
    end
end
fprintf(fid, '}');
fprintf(fid, '\\\\\n');

topLevelWidth = (nColumns - 1)/2;
fprintf(fid, [' & \\multicolumn{' ...
    num2str(topLevelWidth) '}{c}{Base} & \\multicolumn{' ...
    num2str(topLevelWidth) '}{c}{Hard}\\\\\n']);
fprintf(fid, ['\\cmidrule(lr){2-' num2str(2+topLevelWidth-1) '} \n']);
fprintf(fid, ['\\cmidrule(lr){' num2str(2+topLevelWidth) '-' ...
    num2str(2+2*topLevelWidth-1) '} \n']);

nextLevelWidth = topLevelWidth/2;
for k = 1:2
    fprintf(fid, [' & \\multicolumn{' ...
        num2str(nextLevelWidth) ...
        '}{c}{Non-artificial} & \\multicolumn{' ...
        num2str(nextLevelWidth) '}{c}{Artificial}']);
end
fprintf(fid, '\\\\\n');
for k = 1:4
    fprintf(fid, ['\\cmidrule(lr){' ...
        num2str(2+(k-1)*nextLevelWidth) '-' ...
        num2str(2+k*nextLevelWidth - 1) '} \n']);
end

for k = 1:4
    fprintf(fid, ' & CPR & SF');
    for rankingCounter = 1:numel(summarizer.rankingsToVisualizeInTable)
        fprintf(fid, [' & ' '\\textcolor{' ...
        colorOrder{rankingCounter} '}{' alphabet(rankingCounter) '}']);
    end
end
fprintf(fid, '\\\\\n');

for k = 2:nColumns
    fprintf(fid, ['\\cmidrule(lr){' ...
        num2str(k) '-' num2str(k) '} \n']);
end

fprintf(fid, '\\hline\n');

% Manually calculate the order in which requirements would be chosen for
% different rankings
reqOrderWithAllRankings = cell(nModes, nArt, nSolvers - 1);
for modeCounter = 1:nModes
    for artCounter = 1:nArt
        for solverCounter = 3:nSolvers
            thisReqRanking = summarizer.allReqRankings{modeCounter, ...
                artCounter, ...
                min(solverCounter, 2), ...
                :};
            if isempty(thisReqRanking)
                continue
            end
            
            rankingCounter = solverCounter - 2;
            thisRankString = ...
                summarizer.rankingsToVisualizeInTable{rankingCounter};
            
            if isfield(thisReqRanking, thisRankString)
                reqRankingsTmp = thisReqRanking.(thisRankString);
                maxIter = -1;
                reqNames = fieldnames(reqRankingsTmp);
                for reqCounter = 1:numel(reqNames)
                    thisReqName = reqNames{reqCounter};
                    nIter = numel(reqRankingsTmp.(thisReqName).ranking);
                    if nIter > maxIter
                        maxIter = nIter;
                    end
                end
                
                % In each iteration, find out which one req would win
                for iterCounter = 1:maxIter
                    lowestRank = inf;
                    bestReq = 'NONE';
                    for reqCounter = 1:numel(reqNames)
                        thisReqName = reqNames{reqCounter};
                        nIter = numel(reqRankingsTmp.(thisReqName).ranking);
                        if nIter >= iterCounter
                            % This req has a ranking at the given iteration
                            thisReqsRanking = ...
                                reqRankingsTmp.(thisReqName).ranking(iterCounter);
                            if thisReqsRanking < lowestRank
                                lowestRank = thisReqsRanking;
                                bestReq = thisReqName;
                            end
                        end
                    end
                    
                    % Now we know the best req this iteration
                    % Store the order in reqOrderWithAllRankings
                    reqOrderWithAllRankings{modeCounter, artCounter, ...
                        rankingCounter}.(bestReq) = iterCounter;
                    
                    % Remove this req name from contention (like exclusion
                    % list)
                    reqNames(strcmp(reqNames, bestReq)) = [];
                end
            else
                % Temporary fix for lowestRobustness
                if strcmp(thisRankString, 'lowestRobustness')
                    thisRobHist = summarizer.allHist{modeCounter, artCounter, 2}.rob;
                    reqNames = fieldnames(thisRobHist);
                    reqIdx = summarizer.allHist{1,2,2}.focused.req_idx;
                    idxWhereFocusedIterationsStart = find(ischange(reqIdx));
                    for idxCounter = 1:numel(idxWhereFocusedIterationsStart)
                        simulationIdx = idxWhereFocusedIterationsStart(idxCounter);
                        
                        lowestPositiveRob = inf;
                        bestReq = 'NONE';
                        % Find which req has lowest non-negative robustness
                        % up until this point
                        for reqCounter = 1:numel(reqNames)
                            thisReqName = reqNames{reqCounter};
                            minRob = min(thisRobHist.(thisReqName)(1:simulationIdx));
                            if minRob > 0 && ...
                                    minRob < lowestPositiveRob && ...
                                    ~isnan(thisRobHist.(thisReqName)(simulationIdx))
                                lowestPositiveRob = minRob;
                                bestReq = thisReqName;
                            end
                        end
                        
                        % Now we know lowest rob
                        reqOrderWithAllRankings{modeCounter, artCounter, ...
                            rankingCounter}.(bestReq) = idxCounter;
                        
                        % Remove this req name from contention (like exclusion
                        % list)
                        reqNames(strcmp(reqNames, bestReq)) = [];
                    end
                else
                    error('Unrecognized rank string');
                end
            end
        end
        
    end
    
end

% Display detailed information about each req
allFields = fields(summarizer.firstIndexFalsifiedStruct);

% We want to display the reqs in a specific order
% - First, all non-artificial reqs in alphabetical order
% - Then, all artificial reqs in alphabetical order
artIndex = contains(allFields, '_art');
nonArtFields = allFields(~artIndex);
artFields = allFields(artIndex);

allFieldsInCorrectOrder = [sort(nonArtFields); sort(artFields)];

% Each artificial parameter should have its own color to make it easier to
% read the table
art_parameter_array = {};

for reqCounter = 1:numel(allFieldsInCorrectOrder)
    thisField = allFieldsInCorrectOrder{reqCounter};
    fieldToPrint = strrep(thisField, 'phi_', '');
    fieldToPrint = strrep(fieldToPrint, '_', '\\_');
    
    if mod(reqCounter, 2) == 0
        fprintf(fid, '\\rowcolor{gray!15}');
    end
    
    fprintf(fid, fieldToPrint);
    if contains(fieldToPrint, '_art')
        % Find the ranges of the artificial variable (min and max)
        % This is different for ARCH specs and Volvo-inspired specs
        if contains(fieldToPrint, 'ARCH')
            % ARCH spec
            matches = regexp(thisField, 'ARCH_AT\d', 'match');
            identifier = matches{1}; % e.g. 'ARCH_AT1' or 'ARCH_AT5'
            minString = {['artificial_' identifier '_min']};
            minVal = unique(summarizer.B.GetParam(['artificial_' identifier '_min']));
            maxVal = unique(summarizer.B.GetParam(['artificial_' identifier '_max']));
        else
            % Volvo-inspired spec
            paramList = summarizer.B.GetParamList;
            
            identifier = fieldToPrint(1:3); % e.g. 'ADA' or 'RFC'
            
            % We need to find all artificial params containing this
            % identifier
            % e.g. for 'AFE', we need to find both of these params:
            % - 'artificial_AFE_RFC_min
            % - 'artificial_AFE_min
            % This is done with a simple regex (of course)
            matches = regexp(paramList, ['artificial_.*' identifier '.*_min'], 'match');
            idxOfMatches = find(cellfun(@(x)~isempty(x), matches));
            minString = {};
            minVal = [];
            for k = 1:numel(idxOfMatches)
                tmp = matches{idxOfMatches(k)};
                minString{k} = tmp{1}; %#ok<*AGROW>
                minVal(k) = unique(summarizer.B.GetParam(minString{k}));
                maxString{k} = strrep(minString{k}, '_min', '_max');
                maxVal(k) = unique(summarizer.B.GetParam(maxString{k}));
            end
        end
        
        % Print the ranges stored in minVal and maxVal
        for k = 1:numel(minVal)
            % Print with a specific color
            art_idx = find(contains(art_parameter_array, minString{k}), 1);
            if isempty(art_idx)
                art_parameter_array{end+1} = minString{k};
                art_idx = numel(art_parameter_array);
            else
                5;
            end
            fprintf(fid, ['\\textcolor{' colorOrder{art_idx} '}{']);
            fprintf(fid, [' [' num2str(minVal(k)) ', ' ...
                num2str(maxVal(k)) ']']);
            fprintf(fid, '}');
        end
        
    end
    
    for modeCounter = 1:nModes
        for artCounter = 1:nArt
            for solverCounter = 1:nSolvers
                
                if contains(fieldToPrint, '_art') && artCounter == 1
                    % Artificial spec, but not artificial system used
                    % Nothing to print
                    fprintf(fid, ' & ');
                    continue;
                end
                try
                    allFalsifIndex = [summarizer.firstIndexFalsifiedStruct(modeCounter, ...
                        artCounter, ...
                        solverCounter, ...
                        :).(thisField)];
                catch
                    allFalsifIndex = Inf;
                end
                
                % Successful falsifications: Each non-inf element
                nSuccessful = sum(~isinf(allFalsifIndex));
                nTotal = size(summarizer.firstIndexFalsifiedStruct, 4);
                falsifRate = nSuccessful/nTotal;
                
                fprintf(fid, ' & ');
                
                if solverCounter <= 2
                    % Corners-PR and SNOBFIT
                    if isnan(falsifRate)
                        fprintf(fid, '0');
                    else
                        % For nSuccess / nTotal, use this line.
                        if nSuccessful == 0
                            fprintf(fid, '\\textcolor{BrickRed}{');
                        else
                            fprintf(fid, '\\textcolor{ForestGreen}{');
                        end
                        fprintf(fid, '%.0f/%.0f', nSuccessful, nTotal);
                        fprintf(fid, '}');
                    end
                else
                    thisReqOrderWithAllRankings = reqOrderWithAllRankings{modeCounter, ...
                        artCounter, ...
                        solverCounter - 2, ...
                        :};
                    
                    if ~isempty(thisReqOrderWithAllRankings) && ...
                            isfield(thisReqOrderWithAllRankings, thisField)
                        fprintf(fid, ['\\cellcolor{' ...
                            colorOrder{solverCounter-2} ...
                            '!50}' num2str(thisReqOrderWithAllRankings.(thisField))]);
                    end
                end
                
            end
        end
    end
    
    fprintf(fid, '\\\\');
    
    fprintf(fid, '\n');
end


fprintf(fid, '\\hline\n');
fprintf(fid, '\\end{tabular}');

fclose(fid);

fprintf(['Finished writing Latex table to ' ...
    summarizer.latexTableFileWithRankings ...
    '\n']);
end