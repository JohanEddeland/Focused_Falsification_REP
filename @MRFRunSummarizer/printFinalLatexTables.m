function printFinalLatexTables(summarizer)
% PRINTFINALLATEXTABLE  Print final (paper-ready) tables of MRF results
%   This function prints a set of tables that can be included in the final
%   paper (HSCC 2022). In total, 5 .tex-files are created and placed in the
%   folder FINAL_PAPER_TABLES. 

finalLatexFolder = 'FINAL_PAPER_TABLES';
if ~isfolder(finalLatexFolder)
    mkdir(finalLatexFolder);
end

% Create table with only header
headerFileName = [finalLatexFolder '/headerTable.tex'];
headerStruct = createTableWithHeader(summarizer, headerFileName);

% Create table with non-artificial model, standard specs
onlyUseArtModel = 0;
onlyUseArtSpecs = 0;
fileName = [finalLatexFolder '/nonArtModel_standardSpecs.tex'];
createDetailedTable(summarizer, onlyUseArtModel, onlyUseArtSpecs, ...
    fileName, headerStruct);

% Create table with artificial model, standard specs
onlyUseArtModel = 1;
fileName = [finalLatexFolder '/artModel_standardSpecs.tex'];
createDetailedTable(summarizer, onlyUseArtModel, onlyUseArtSpecs, ...
    fileName, headerStruct);

% Create table with artificial model, artificial specs
onlyUseArtSpecs = 1;
fileName = [finalLatexFolder '/artModel_artSpecs.tex'];
createDetailedTable(summarizer, onlyUseArtModel, onlyUseArtSpecs, ...
    fileName, headerStruct);

% Display information about when SNOBFIT beats cornersPR and vice versa
printSnobfitVersusCorners(summarizer, [finalLatexFolder '/summarizerTable.tex']);

end

function headerStruct = createTableWithHeader(summarizer, fileName)
fid = fopen(fileName, 'w');

fprintf(fid, '\\begin{tabular}{ccccccccc}\n');
fprintf(fid, '\\hline\n\n');

% Header
fprintf(fid, ' & \\multicolumn{4}{c}{Non-artificial} & \\multicolumn{4}{c}{Artificial}\\\\\n');
fprintf(fid, '\\cmidrule(lr){2-5} \n');
fprintf(fid, '\\cmidrule(lr){6-9} \n');

for k = 1:2
    fprintf(fid, ' & \\multicolumn{2}{c}{Base} & \\multicolumn{2}{c}{Hard}');
end
fprintf(fid, '\\\\\n');
fprintf(fid, '\\cmidrule(lr){2-3} \n');
fprintf(fid, '\\cmidrule(lr){4-5} \n');
fprintf(fid, '\\cmidrule(lr){6-7} \n');
fprintf(fid, '\\cmidrule(lr){8-9} \n');

for k = 1:4
    fprintf(fid, ' & Corners-R & MRF');
end
fprintf(fid, '\\\\\n');
fprintf(fid, '\\cmidrule(lr){2-2} \n');
fprintf(fid, '\\cmidrule(lr){3-3} \n');
fprintf(fid, '\\cmidrule(lr){4-4} \n');
fprintf(fid, '\\cmidrule(lr){5-5} \n');
fprintf(fid, '\\cmidrule(lr){6-6} \n');
fprintf(fid, '\\cmidrule(lr){7-7} \n');
fprintf(fid, '\\cmidrule(lr){8-8} \n');
fprintf(fid, '\\cmidrule(lr){9-9} \n');


% Get information about everything we want to show
% #falsified (avg / total)
avgFals = [];
avgFalsCountAct = [];
avgSafetyFals = [];
nMax = [];
nMaxSafety = [];
% Avg. #sim (including failed falsifications)
avgSim = [];
% Avg. #sim (excluding failed falsifications)
avgSimExcludingFailed = [];
% Specific variables for _art and non-_art specs
avgFals_art = [];
nMax_art = [];
avgSim_art = [];
avgFals_nonArt = [];
avgSim_nonArt = [];
nMax_nonArt = [];


nMaxSim = 3000;
for artCounter = 1:2
    for modeCounter = 1:2
        for solverCounter = 1:2
            allFieldNames = fieldnames(summarizer.firstIndexFalsifiedStruct);
            
            % 1. Calculate the #falsified (first row)
            try
                nFalsAllSeeds = summarizer.allReqsFalsified(modeCounter, artCounter, solverCounter, :);
            catch
                nFalsAllSeeds = 0;
            end
            avgFals(end+1) = mean(nFalsAllSeeds);
            
            try
                nFalsCountActAllSeeds = summarizer.allReqsFalsifiedCountAct(modeCounter, artCounter, solverCounter, :);
            catch
                nFalsCountActAllSeeds = 0;
            end
            avgFalsCountAct(end+1) = mean(nFalsCountActAllSeeds);
            
            % Calculate average False(T, R)
            try
                nSafetyFalsAllSeeds = summarizer.allSafetyReqFalsified(modeCounter, artCounter, solverCounter, :);
            catch
                nSafetyFalsAllSeeds = 0;
            end
            avgSafetyFals(end+1) = mean(nSafetyFalsAllSeeds);
            
            try
                nMaxSafety(end+1) = summarizer.nSafetyReqs(modeCounter, artCounter, solverCounter, 1);
            catch
                nMaxSafety(end+1) = 0;
            end
            
            try
                nMaxTemp = summarizer.allReqsStarted(modeCounter, artCounter, solverCounter, :);
            catch
                nMaxTemp = 0;
            end
            
            if summarizer.requireCompleteRuns
                assert(numel(unique(nMaxTemp)) == 1); % Assert we always have same number of starting reqs
            end
            nMax(end+1) = nMaxTemp(1);
            
            %error('todo: nReqsFalsified_art');
            try
                nFalsArt = summarizer.allReqsFalsified_art(modeCounter, artCounter, solverCounter, :);
            catch
                nFalsArt = 0;
            end
            try
                nMaxTemp_art = summarizer.allReqsStarted_art(modeCounter, artCounter, solverCounter, :);
            catch
                nMaxTemp_art = 0;
            end
            avgFals_art(end+1) = mean(nFalsArt); %#ok<*AGROW>
            nMax_art(end+1) = nMaxTemp_art(1);
            
            avgFals_nonArt(end+1) = avgFals(end) - avgFals_art(end);
            nMax_nonArt(end+1) = nMax(end) - nMax_art(end);
            
            % 2. Calculate Avg #sim
            totalSim = 0;
            totalSim_art = 0;
            totalSim_nonArt = 0;
            
            
            specCounter = 0;
            specCounter_art = 0;
            specCounter_nonArt = 0;
            for k = 1:numel(fieldnames(summarizer.firstIndexFalsifiedStruct))
                isArtSpec = contains(allFieldNames{k}, '_art');
                try
                    thisNSim = summarizer.firstIndexFalsifiedStruct(modeCounter, ...
                        artCounter, solverCounter, :).(allFieldNames{k});
                catch
                    thisNSim = nMaxSim;
                end
                if artCounter == 1 && isArtSpec
                    % Artificial spec but not artificial system
                    % Don't count it
                    thisNSim = 0;
                else
                    specCounter = specCounter + 1;
                    if isArtSpec
                        specCounter_art = specCounter_art + 1;
                    else
                        specCounter_nonArt = specCounter_nonArt + 1;
                    end
                end
                if isempty(thisNSim) || isinf(thisNSim)
                    totalSim = totalSim + nMaxSim;
                    if isArtSpec
                        totalSim_art = totalSim_art + nMaxSim;
                    else
                        totalSim_nonArt = totalSim_nonArt + nMaxSim;
                    end
                else
                    totalSim = totalSim + thisNSim;
                    if isArtSpec
                        totalSim_art = totalSim_art + thisNSim;
                    else
                        totalSim_nonArt = totalSim_nonArt + thisNSim;
                    end
                end
            end
            avgSim(end+1) = totalSim / specCounter;
            avgSim_art(end+1) = totalSim_art / specCounter_art;
            avgSim_nonArt(end+1) = totalSim_nonArt / specCounter_nonArt;
            
            % 3. Calculate Avg. #sim, excluding failed falsifications
            totalSimExcludingFailed = 0;
            specCounterExcludingFailed = 0;
            for k = 1:numel(fieldnames(summarizer.firstIndexFalsifiedStruct))
                try
                    thisNSimExcludingFailed = summarizer.firstIndexFalsifiedStruct(modeCounter, ...
                        artCounter, solverCounter, :).(allFieldNames{k});
                catch
                    thisNSimExcludingFailed = 0;
                end
                if artCounter == 1 && isArtSpec
                    % Artificial spec but not artificial system
                    % Don't count it
                    thisNSimExcludingFailed = 0;
                end
                if isinf(thisNSimExcludingFailed)
                    % Did not manage to falsify - set to 0
                    thisNSimExcludingFailed = 0;
                end
                if thisNSimExcludingFailed > 0
                    totalSimExcludingFailed = ...
                        totalSimExcludingFailed + thisNSimExcludingFailed;
                    specCounterExcludingFailed = ...
                        specCounterExcludingFailed + 1;
                end
            end
            
            if specCounterExcludingFailed > 0
                avgSimExcludingFailed(end+1) = ...
                    totalSimExcludingFailed / specCounterExcludingFailed;
            else
                avgSimExcludingFailed(end+1) = 0;
            end
        end
    end
end

% Print #falsified for each solver
firstColToPrint = {' Avg. $\\False(T, R)$', ...
    '\\rowcolor{gray!15} Avg. $\\Cover(T, R)$', ...
    ' Avg. $\\Total(T, R)$', ...
    '\\rowcolor{gray!15} Avg. \\#sim', ...
    ' Avg. \\#sim (successful)'};
%     '\\hline\nNon-artificial & \\#Falsified', ...
%     '\\rowcolor{gray!15} & Avg. \\#sim', ...
%     '\\hline\nArtificial & Avg. \\#Falsified', ...
%     '\\rowcolor{gray!15} & Avg. \\#sim'};

for k = 1:numel(firstColToPrint)
    fprintf(fid, firstColToPrint{k});
    
    for varCounter = 1:numel(avgFals)
        % Avg #Fals (old first row)
        % sprintf(' & %.1f / %d', avgFals(varCounter), nMax(varCounter))
        
        % Avg #Fals (count _act/_req) (old second row)
        % sprintf(' & %.1f / %d', avgFalsCountAct(varCounter), nMax(varCounter))
        5;
        stringsToPrint = {sprintf(' %.1f / %d', avgSafetyFals(varCounter), nMaxSafety(varCounter)), ...
            sprintf(' %.1f / %d', avgFalsCountAct(varCounter) - avgSafetyFals(varCounter), nMax(varCounter) - nMaxSafety(varCounter)), ...
            sprintf(' %.1f / %d', avgFals(varCounter), nMax(varCounter)), ...
            sprintf(' %.1f', avgSim(varCounter)), ...
            sprintf(' %.1f', avgSimExcludingFailed(varCounter))};
        %             sprintf(' & %.1f / %d', avgFals_nonArt(varCounter), nMax_nonArt(varCounter)), ...
        %             sprintf(' & %.1f', avgSim_nonArt(varCounter)), ...
%             sprintf(' & %.1f / %d', avgFals_art(varCounter), nMax_art(varCounter)), ...
%             sprintf(' & %.1f', avgSim_art(varCounter))};
        stringsToPrint{k} = strrep(stringsToPrint{k}, 'NaN', '-');
        
        switch k
            case 1
                varToCheck = avgSafetyFals;
            case 2
                varToCheck = avgFalsCountAct - avgSafetyFals;
            case 3
                varToCheck = avgFals;
            case 4
                varToCheck = -avgSim; % Lower sim is better
            case 5
                varToCheck = -avgSimExcludingFailed; % Lower is better
        end
        
        useBold = 0;
        if mod(varCounter, 2) == 0
            % MRF, compare to previous number
            mrfValue = varToCheck(varCounter);
            CRValue = varToCheck(varCounter-1);
            
            if mrfValue >= CRValue
                useBold = 1;
            end
        else
            % Corners-R, compare to next number
            CRValue = varToCheck(varCounter);
            mrfValue = varToCheck(varCounter+1);
            
            if CRValue >= mrfValue
                useBold = 1;
            end
        end
        
        fprintf(fid, ' & ');
        if useBold
            fprintf(fid, '\\textbf{');
        end
        fprintf(fid, stringsToPrint{k});
        if useBold
            fprintf(fid, '}');
        end
    end
    fprintf(fid, '\\\\\n');
end

fprintf(fid, '\\hline\n');
fprintf(fid, '\\end{tabular}');

fclose(fid);

fprintf(['Finished writing Latex table to ' fileName ...
    '\n']);

headerStruct.avgFals = avgFals;
headerStruct.nMax = nMax;
headerStruct.nMax_nonArt = nMax_nonArt;
headerStruct.nMax_art = nMax_art;
headerStruct.avgFalsCountAct = avgFalsCountAct;
headerStruct.avgSim = avgSim;
headerStruct.avgSimExcludingFailed = avgSimExcludingFailed;
headerStruct.avgFals_nonArt = avgFals_nonArt;
headerStruct.avgSim_nonArt = avgSim_nonArt;
headerStruct.avgFals_art = avgFals_art;
headerStruct.avgSim_art = avgSim_art;
headerStruct.avgSafetyFals = avgSafetyFals;
headerStruct.nMaxSafety = nMaxSafety;

end

function createDetailedTable(summarizer, onlyUseArtModel, ...
    onlyUseArtSpecs, fileName, headerStruct)

if onlyUseArtModel
    artCounter = 2;
    avgFals = headerStruct.avgFals(5:end);
    nMax = headerStruct.nMax(5:end);
    nMax_nonArt = headerStruct.nMax_nonArt(5:end);
    nMax_art = headerStruct.nMax_art(5:end);
    avgFalsCountAct = headerStruct.avgFalsCountAct(5:end);
    avgSim = headerStruct.avgSim(5:end);
    avgSimExcludingFailed = headerStruct.avgSimExcludingFailed(5:end);
    avgFals_nonArt = headerStruct.avgFals_nonArt(5:end);
    avgSim_nonArt = headerStruct.avgSim_nonArt(5:end);
    avgFals_art = headerStruct.avgFals_art(5:end);
    avgSim_art = headerStruct.avgSim_art(5:end);
    avgSafetyFals = headerStruct.avgSafetyFals(5:end);
    nMaxSafety = headerStruct.nMaxSafety(5:end);
else
    artCounter = 1;
    avgFals = headerStruct.avgFals(1:4);
    nMax = headerStruct.nMax(1:4);
    nMax_nonArt = headerStruct.nMax_nonArt(1:4);
    nMax_art = headerStruct.nMax_art(1:4);
    avgFalsCountAct = headerStruct.avgFalsCountAct(1:4);
    avgSim = headerStruct.avgSim(1:4);
    avgSimExcludingFailed = headerStruct.avgSimExcludingFailed(1:4);
    avgFals_nonArt = headerStruct.avgFals_nonArt(1:4);
    avgSim_nonArt = headerStruct.avgSim_nonArt(1:4);
    avgFals_art = headerStruct.avgFals_art(1:4);
    avgSim_art = headerStruct.avgSim_art(1:4);
    avgSafetyFals = headerStruct.avgSafetyFals(1:4);
    nMaxSafety = headerStruct.nMaxSafety(1:4);
end

fid = fopen(fileName, 'w');

fprintf(fid, '\\begin{tabular}{c|cc|cc}\n');
fprintf(fid, '\\hline\n\n');

% Header
fprintf(fid, ' & \\multicolumn{2}{c}{Base} & \\multicolumn{2}{c}{Hard}\\\\\n');
fprintf(fid, '\\cmidrule(lr){2-3} \n');
fprintf(fid, '\\cmidrule(lr){4-5} \n');

for k = 1:2
    fprintf(fid, ' & Corners-R & MRF');
end
fprintf(fid, '\\\\\n');

% Print average information in header
firstColToPrint = {' Avg. $\\False(T, R)$', ...
    '\\rowcolor{gray!15} Avg. $\\Cover(T, R)$', ...
    ' Avg. $\\Total(T, R)$', ...
    '\\rowcolor{gray!15} Avg. \\#sim', ...
    ' Avg. \\#sim (successful)'};

% for k = 1:numel(firstColToPrint)
%     fprintf(fid, firstColToPrint{k});
%     for varCounter = 1:numel(avgFals)
%         stringsToPrint = {sprintf(' %.1f / %d', avgSafetyFals(varCounter), nMaxSafety(varCounter)), ...
%             sprintf(' %.1f / %d', avgFals(varCounter), nMax(varCounter)), ...
%             sprintf(' %.1f / %d', avgFalsCountAct(varCounter) - avgSafetyFals(varCounter), nMax(varCounter) - nMaxSafety(varCounter)), ...
%             sprintf(' %.1f', avgSim(varCounter)), ...
%             sprintf(' %.1f', avgSimExcludingFailed(varCounter))};
%         stringsToPrint{k} = strrep(stringsToPrint{k}, 'NaN', '-');
%         fprintf(fid, ' & ');
%         fprintf(fid, stringsToPrint{k});
%     end
%     fprintf(fid, '\\\\\n');
% end

for k = 1:numel(firstColToPrint)
    fprintf(fid, firstColToPrint{k});
    
    for varCounter = 1:numel(avgFals)
        % Avg #Fals (old first row)
        % sprintf(' & %.1f / %d', avgFals(varCounter), nMax(varCounter))
        
        % Avg #Fals (count _act/_req) (old second row)
        % sprintf(' & %.1f / %d', avgFalsCountAct(varCounter), nMax(varCounter))
        5;
        stringsToPrint = {sprintf(' %.1f / %d', avgSafetyFals(varCounter), nMaxSafety(varCounter)), ...
            sprintf(' %.1f / %d', avgFalsCountAct(varCounter) - avgSafetyFals(varCounter), nMax(varCounter) - nMaxSafety(varCounter)), ...
            sprintf(' %.1f / %d', avgFals(varCounter), nMax(varCounter)), ...
            sprintf(' %.1f', avgSim(varCounter)), ...
            sprintf(' %.1f', avgSimExcludingFailed(varCounter))};
        %             sprintf(' & %.1f / %d', avgFals_nonArt(varCounter), nMax_nonArt(varCounter)), ...
        %             sprintf(' & %.1f', avgSim_nonArt(varCounter)), ...
%             sprintf(' & %.1f / %d', avgFals_art(varCounter), nMax_art(varCounter)), ...
%             sprintf(' & %.1f', avgSim_art(varCounter))};
        stringsToPrint{k} = strrep(stringsToPrint{k}, 'NaN', '-');
        
        switch k
            case 1
                varToCheck = avgSafetyFals;
            case 2
                varToCheck = avgFalsCountAct - avgSafetyFals;
            case 3
                varToCheck = avgFals;
            case 4
                varToCheck = -avgSim; % Lower sim is better
            case 5
                varToCheck = -avgSimExcludingFailed; % Lower is better
        end
        
        useBold = 0;
        if mod(varCounter, 2) == 0
            % MRF, compare to previous number
            mrfValue = varToCheck(varCounter);
            CRValue = varToCheck(varCounter-1);
            
            if mrfValue >= CRValue
                useBold = 1;
            end
        else
            % Corners-R, compare to next number
            CRValue = varToCheck(varCounter);
            mrfValue = varToCheck(varCounter+1);
            
            if CRValue >= mrfValue
                useBold = 1;
            end
        end
        
        fprintf(fid, ' & ');
        if useBold
            fprintf(fid, '\\textbf{');
        end
        fprintf(fid, stringsToPrint{k});
        if useBold
            fprintf(fid, '}');
        end
    end
    fprintf(fid, '\\\\\n');
end

fprintf(fid, '\\hline\n');

% Display detailed information about each req
allFields = fields(summarizer.firstIndexFalsifiedStruct);

% We want to display the reqs in a specific order
% - First, all non-artificial reqs in alphabetical order
% - Then, all artificial reqs in alphabetical order
artIndex = contains(allFields, '_art');
nonArtFields = allFields(~artIndex);
artFields = allFields(artIndex);

if onlyUseArtSpecs
    allFieldsInCorrectOrder = sort(artFields);
else
    allFieldsInCorrectOrder = sort(nonArtFields);
end


% Each artificial parameter should have its own color to make it easier to
% read the table
art_parameter_array = {};
colorOrder =  {'RoyalPurple', 'Bittersweet', 'Blue', ...
    'BurntOrange', 'CadetBlue', 'TealBlue', ...
    'DarkOrchid', 'ForestGreen', 'Fuchsia', 'BrickRed', 'GreenYellow'};
for reqCounter = 1:numel(allFieldsInCorrectOrder)
    thisField = allFieldsInCorrectOrder{reqCounter};
    fieldToPrint = strrep(thisField, 'phi_', '');
    fieldToPrint = strrep(fieldToPrint, '_', '\\_');
    
    if mod(reqCounter, 2) == 1
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
                minString{k} = tmp{1};
                minVal(k) = unique(summarizer.B.GetParam(minString{k}));
                maxString{k} = strrep(minString{k}, '_min', '_max');
                maxVal(k) = unique(summarizer.B.GetParam(maxString{k}));
            end
        end
        
    end
    
    for modeCounter = 1:2
        for solverCounter = 1:2
            try
                thisHist = summarizer.allHist{modeCounter, ...
                    artCounter, ...
                    solverCounter, ...
                    :};
            catch
                % No hist for this index
                fprintf(fid, ' & ');
                continue;
            end
            if isempty(thisHist)
                % No hist for this index
                continue
            end
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
            
            % Average index for NON-INF entries!
            avgIndexOfFalsified = mean(allFalsifIndex(~isinf(allFalsifIndex)));
            
            fprintf(fid, ' & ');
            
            % Green background if req was focused by SNOBFIT
%             if isfield(thisHist, 'method') && ...
%                     any(thisHist.method.focused.(thisField))
%                 fprintf(fid, '\\cellcolor{green!35}');
%             end
            
            if isnan(falsifRate)
                fprintf(fid, '0');
            elseif nSuccessful==0 && contains(thisField, '_act')
                % Non-successful _act spec
                % Check if corresponding _req spec is falsified! Then
                % we show a special color to indicate that this is ok.
                
                try
                    tmpReqIndex = [summarizer.firstIndexFalsifiedStruct(modeCounter, ...
                        artCounter, ...
                        solverCounter, ...
                        :).(regexprep(thisField, '_act\d*', '_req'))];
                catch
                    tmpReqIndex = [];
                end
                if isempty(tmpReqIndex)
                    % Not falsified _req spec
                    fprintf(fid, '%.0f/%.0f', nSuccessful, nTotal);
                else
                    % OBS! Falsified _req spec!
                    %                     fprintf(fid, '\\cellcolor{blue!35}%.0f/%.0f', ...
                    %                         sum(~isinf(tmpReqIndex)), nTotal);
                    fprintf(fid, '%.0f/%.0f', nSuccessful, nTotal);
                end
            else
                % For RATE (in pecentage), use this line.
                %fprintf(fid, '%.0f', falsifRate*100);
                
                % For nSuccess / nTotal, use this line.
                fprintf(fid, '%.0f/%.0f', nSuccessful, nTotal);
            end
            
            
            nSeeds = size(summarizer.allHist, 4);
            allRobOfNonFalsified = [];
            for seedCounter = 1:nSeeds
                thisHist = summarizer.allHist{modeCounter, ...
                    artCounter, ...
                    solverCounter, ...
                    seedCounter};
                minRobThisSeed = min(thisHist.rob.(thisField));
                if minRobThisSeed >= 0
                    allRobOfNonFalsified(end+1) = minRobThisSeed;
                end
            end
            avgRobOfNonFalsified = mean(allRobOfNonFalsified);
            
            fprintf(fid, ' (');
            nCorners = find(thisHist.method.corners, 1, 'last');
            if isnan(avgIndexOfFalsified)
                fprintf(fid, '-');
            else
                if nSuccessful == nTotal && ...
                        all(allFalsifIndex(~isinf(allFalsifIndex)) <= nCorners)
                    % Green text if ALL falsified indices are corners!
                    fprintf(fid, ...
                        '\\textcolor{ForestGreen}{%.1f}', ...
                        avgIndexOfFalsified);
                else
                    fprintf(fid, '%.1f', avgIndexOfFalsified);
                end
                
            end
            
            fprintf(fid, ', ');
            
            if isnan(avgRobOfNonFalsified)
                fprintf(fid, '-');
            else
                fprintf(fid, ['\\textcolor{red}{' ...
                    num2str(avgRobOfNonFalsified) '}']);
            end
            fprintf(fid, ')');
            
        end
    end
    
    fprintf(fid, '\\\\');
    
    fprintf(fid, '\n');
end


fprintf(fid, '\\hline\n');
fprintf(fid, '\\end{tabular}');

fclose(fid);

fprintf(['Finished writing Latex table to ' fileName ...
    '\n']);
end

function printSnobfitVersusCorners(summarizer, fileName)


% Possible cases:
% 1. Both falsify, cornersPR faster
case1 = 0;
% 2. Both falsify, same falsification index
case2 = 0;
% 3. Both falsify, snobfit faster
case3 = 0;

% 4. Corners-PR falsifies, SNOBFIT does not
case4 = 0;
% 5. Corners-PR does not falsify, SNOBFIT does
case5 = 0;

% 6. Neither falsifies, corners-PR lower rob
case6 = 0;
% 7. Neither falsifies, same rob
case7 = 0;
% 8. Neither falsifies, SNOBFIT lower rob
case8 = 0;

% 9. SNOBFIT removes act because corresponding req was falsified, 
%    and Corners-Random ALSO falsifies/removes
case9 = 0;

% 10. SNOBFIT removes act because corresponding req was falsified, 
%     but Corners-Random does not falsify/remove
case10 = 0;

% Count number of focused reqs compared to number of falsified focused reqs
nFocusedReqs = 0;
nFocusedReqsFalsified = 0;
nFocusedReqsFalsifiedDuringFocus = 0;
nRuns = 0;

for modeCounter = 1:2
    for artCounter = 1:2
        for seedCounter = 1:size(summarizer.allHist, 4)
            try
                snobfitHist = summarizer.allHist{modeCounter, ...
                    artCounter, 2, seedCounter};
                cornersHist = summarizer.allHist{modeCounter, ...
                    artCounter, 1, seedCounter};
            catch
                % Can't read this index
                continue
            end
            if isempty(snobfitHist) || isempty(cornersHist)
                continue
            end
            
            specNames = fieldnames(snobfitHist.rob);
            nRuns = nRuns + 1;
            for specCounter = 1:numel(specNames)
                thisField = specNames{specCounter};
                snobfitRob = snobfitHist.rob.(thisField);
                cornersRob = cornersHist.rob.(thisField);
                snobfitFirstFals = find(snobfitRob < 0, 1);
                cornersFirstFals = find(cornersRob < 0, 1);
                
                if any(strcmp(fieldnames(snobfitHist.focused), thisField))
                    % We focused this requirement
                    nFocusedReqs = nFocusedReqs + 1;
                    if min(snobfitRob) < 0
                        % We falsified this requirement
                        nFocusedReqsFalsified = nFocusedReqsFalsified + 1;
                        focusedIndices = snobfitHist.focused.(thisField);
                        if numel(focusedIndices) >= snobfitFirstFals && ...
                                focusedIndices(snobfitFirstFals)==1
                            nFocusedReqsFalsifiedDuringFocus = ...
                                nFocusedReqsFalsifiedDuringFocus + 1;
                        end
                    end
                end
                
                if min(snobfitRob) >= 0 && isnan(snobfitRob(end))
                    % Snobfit removed this act spec cause corresponding req
                    % spec was falsified
                    reqField = regexprep(thisField, 'act\d*', 'req');
                    cornersReqRob = cornersHist.rob.(reqField);
                    if min(cornersRob) < 0 || min(cornersReqRob) < 0
                        % Case 9
                        % Corners-Random also falsified/removed spec
                        case9 = case9 + 1;
                    else
                        % Case 10
                        % Corners-Random did not falsify/remove spec
                        case10 = case10 + 1;
                    end
                    
                elseif min(snobfitRob) < 0 && min(cornersRob) < 0
                    % Both falsify
                    if cornersFirstFals < snobfitFirstFals
                        % Case 1
                        case1 = case1 + 1;
                    elseif cornersFirstFals == snobfitFirstFals
                        % Case 2
                        case2 = case2 + 1;
                    else
                        % Case 3
                        case3 = case3 + 1;
                    end
                    
                elseif min(snobfitRob) >= 0 && min(cornersRob) < 0
                    % Case 4
                    case4 = case4 + 1;
                    
                elseif min(snobfitRob) < 0 && min(cornersRob) >= 0
                    % Case 5
                    case5 = case5 + 1;
                    
                elseif min(snobfitRob) >= 0 && min(cornersRob) >= 0
                    % Neither falsifies
                    if min(cornersRob) < min(snobfitRob)
                        % Case 6
                        case6 = case6 + 1;
                    elseif min(cornersRob) == min(snobfitRob)
                        % Case 7
                        case7 = case7 + 1;
                    elseif min(cornersRob) > min(snobfitRob)
                        % Case 8
                        case8 = case8 + 1;
                    else
                        error('Shoudlnt happen');
                    end
                else
                    error('Unaccounted case (shouldnt be able to happen)');
                end
            end
        end
    end
end

% Print the results
disp('Classification of cases and how many times they occur');
disp('=====================================================');
% 1. Both falsify, cornersPR faster
disp(['1. Both falsify, corners-PR faster: ' num2str(case1)]);
% 2. Both falsify, same falsification index
disp(['2. Both falsify, same first falsification index: ' num2str(case2)]);
% 3. Both falsify, snobfit faster
disp(['3. Both falsify, MRF faster: ' num2str(case3)]);
disp(' ');

% 4. Corners-PR falsifies, SNOBFIT does not
disp(['4. Corners-PR falsifies, MRF does not: ' num2str(case4)]);
% 5. Corners-PR does not falsify, SNOBFIT does
disp(['5. Corners-PR does not falsify, MRF does: ' num2str(case5)]);
disp(' ');

% 6. Neither falsifies, corners-PR lower rob
disp(['6. Neither falsifies, corners-PR lower rob: ' num2str(case6)]);
% 7. Neither falsifies, same rob
disp(['7. Neither falsifies, same lowest rob: ' num2str(case7)]);
% 8. Neither falsifies, SNOBFIT lower rob
disp(['8. Neither falsifies, MRF lower rob: ' num2str(case8)]);
disp(' ');

% 9. SNOBFIT removes act because corresponding req was falsified
disp(['9. MRF removes act because corresponding req falsifies, Corners-Random also falsifies: ' num2str(case9)]);
disp(['10. MRF removes act because corresponding req falsifies, Corners-Random does NOT falsify: ' num2str(case10)]);
totalSum = case1 + case2 + case3 + case4 + case5 + case6 + case7 + case8 + case9 + case10;
disp(['Total cases: ' num2str(totalSum)]);
disp('=====================================================');

fprintf('Total number of runs: %d\n', nRuns);

fprintf('Total reqs focused: %d\n', nFocusedReqs);
fprintf('# of focused reqs falsified: %d/%d (out of these, %d were falsified during their focus period)\n', ...
    nFocusedReqsFalsified, nFocusedReqs, ...
    nFocusedReqsFalsifiedDuringFocus);

fid = fopen(fileName, 'w');
fprintf(fid, '\\begin{tabular}{c|c}\n');
fprintf(fid, '\\hline\n\n');

fprintf(fid, '\\textbf{Description} & \\textbf{Occurrences}\\\\\n\n');

fprintf(fid, '\\hline\n \\rowcolor{gray!15}Both falsify, Corners-Random faster & %d\\\\\n', case1);
fprintf(fid, 'Both falsify, same first falsification index & %d\\\\\n', case2);
fprintf(fid, '\\rowcolor{gray!15}Both falsify, MRF faster & %d\\\\\n', case3);

fprintf(fid, '\\hline\n Corners-Random falsifies, MRF does not & %d\\\\\n', case4);
fprintf(fid, '\\rowcolor{gray!15}MRF falsifies, Corners-Random does not & %d\\\\\n', case5);

fprintf(fid, '\\hline\n Neither falsifies, Corners-Random lower rob & %d\\\\\n', case6);
fprintf(fid, '\\rowcolor{gray!15}Neither falsifies, same lowest rob & %d\\\\\n', case7);
fprintf(fid, 'Neither falsifies, MRF lower rob & %d\\\\\n', case8);

fprintf(fid, '\\hline\n \\rowcolor{gray!15}MRF removes $act(\\varphi_s)$ because $\\varphi_s$ is falsified, & \\\\\n');
fprintf(fid, '\\rowcolor{gray!15}Corners-Random falsifies either $\\varphi_s$ or $act(\\varphi_s)$ & \\multirow{-2}{*}{%d}\\\\\n', case9);
fprintf(fid, 'MRF removes $act(\\varphi_s)$ because $\\varphi_s$ is falsified, & \\multirow{2}{*}{%d}\\\\\n', case10);
fprintf(fid, 'Corners-Random does not falsify either $\\varphi_s$ or $act(\\varphi_s)$ & \\\\\n');

fprintf(fid, '\\hline\n');
fprintf(fid, '\\end{tabular}');

fclose(fid);

fprintf(['Finished writing Latex table to ' fileName ...
    '\n']);

end