function printDataToLatex(summarizer)
% PRINTDATATOLATEX  Print intermediate MRF data to a Latex table
%   This function prints a table with useful information to get an overview
%   of the results from one or several MRF runs. Note that these are not
%   the final tables; for those, see PRINTFINALLATEXTABLES. 
fid = fopen(summarizer.latexTableFile, 'w');

fprintf(fid, '\\begin{tabular}{cccccccccc}\n');
fprintf(fid, '\\hline\n\n');

% Header
fprintf(fid, ' & & \\multicolumn{4}{c}{Base} & \\multicolumn{4}{c}{Hard}\\\\\n');
fprintf(fid, '\\cmidrule(lr){3-6} \n');
fprintf(fid, '\\cmidrule(lr){7-10} \n');

fprintf(fid, ' & ');
for k = 1:2
    fprintf(fid, ' & \\multicolumn{2}{c}{Non-artificial} & \\multicolumn{2}{c}{Artificial}');
end
fprintf(fid, '\\\\\n');
fprintf(fid, '\\cmidrule(lr){3-4} \n');
fprintf(fid, '\\cmidrule(lr){5-6} \n');
fprintf(fid, '\\cmidrule(lr){7-8} \n');
fprintf(fid, '\\cmidrule(lr){9-10} \n');

fprintf(fid, ' & ');
for k = 1:4
    fprintf(fid, ' & Corners-PR & MRF');
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
fprintf(fid, '\\cmidrule(lr){10-10} \n');

% Get information about everything we want to show
% #falsified (avg / total)
avgFals = [];
avgFalsCountAct = [];
nMax = [];
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
for modeCounter = 1:2
    for artCounter = 1:2
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
            
            %
            
            
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
firstColToPrint = {'Overall & \\#Falsified', ...
    '\\rowcolor{gray!15} & \\#Fals (count \\_act/\\_req)', ...
    ' & Avg. \\#sim', ...
    '\\rowcolor{gray!15} & Avg. \\#sim (successful)', ...
    '\\hline\nNon-artificial & \\#Falsified', ...
    '\\rowcolor{gray!15} & Avg. \\#sim', ...
    '\\hline\nArtificial & Avg. \\#Falsified', ...
    ' & Avg. \\#sim'};

for k = 1:numel(firstColToPrint)
    fprintf(fid, firstColToPrint{k});
    for varCounter = 1:numel(avgFals)
        stringsToPrint = {sprintf(' & %.1f / %d', avgFals(varCounter), nMax(varCounter)), ...
            sprintf(' & %.1f / %d', avgFalsCountAct(varCounter), nMax(varCounter)), ...
            sprintf(' & %.1f', avgSim(varCounter)), ...
            sprintf(' & %.1f', avgSimExcludingFailed(varCounter)), ...
            sprintf(' & %.1f / %d', avgFals_nonArt(varCounter), nMax_nonArt(varCounter)), ...
            sprintf(' & %.1f', avgSim_nonArt(varCounter)), ...
            sprintf(' & %.1f / %d', avgFals_art(varCounter), nMax_art(varCounter)), ...
            sprintf(' & %.1f', avgSim_art(varCounter))};
        fprintf(fid, stringsToPrint{k});
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

allFieldsInCorrectOrder = [sort(nonArtFields); sort(artFields)];

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
    
    if mod(reqCounter, 2) == 0
        fprintf(fid, '\\rowcolor{gray!15}');
    end
    
    fprintf(fid, ' & ');
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
    
    for modeCounter = 1:2
        for artCounter = 1:2
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
                avgIndex = mean(allFalsifIndex(~isinf(allFalsifIndex)));
                
                fprintf(fid, ' & ');
                
                % Green background if req was focused by SNOBFIT
                if isfield(thisHist, 'method') && ...
                        any(thisHist.method.focused.(thisField))
                    fprintf(fid, '\\cellcolor{green!35}');
                end
                
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
                        fprintf(fid, '\\cellcolor{blue!35}%.0f/%.0f', ...
                            sum(~isinf(tmpReqIndex)), nTotal);
                    end
                else
                    % For RATE (in pecentage), use this line.
                    %fprintf(fid, '%.0f', falsifRate*100);
                    
                    % For nSuccess / nTotal, use this line.
                    fprintf(fid, '%.0f/%.0f', nSuccessful, nTotal);
                end
                
                if isnan(avgIndex)
                    
                    if isfield(thisHist, 'rob')
                        minRobTmp = num2str(min(thisHist.rob.(thisField)));
                    else
                        minRobTmp = 'inf';
                    end
                    
                    fprintf(fid, [' (\\textcolor{red}{' ...
                        minRobTmp '})']);
                else
                    nCorners = find(thisHist.method.corners, 1, 'last');
                    % Color green if falsified by corners
                    if avgIndex <= nCorners
                        fprintf(fid, ...
                            ' (\\textcolor{ForestGreen}{%.1f})', avgIndex);
                    else
                        fprintf(fid, ' (%.1f)', avgIndex);
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

fprintf(['Finished writing Latex table to ' summarizer.latexTableFile ...
    '\n']);
end