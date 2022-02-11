function plotFalsificationInformation(summarizer, solverIndex)

modeStrings = {'base\_', 'hard\_'};
artStrings = {'', 'artificial\_'};

if solverIndex == 1
    solverString = 'corners-PR';
elseif solverIndex == 2
    solverString = 'Foc-SNOBFIT';
else
    error('Unknown solverIndex');
end

for modeCounter = 1:size(summarizer.firstIndexFalsifiedStruct, 1)
    for artCounter = 1:size(summarizer.firstIndexFalsifiedStruct, 2)
        try
            initReqs = summarizer.allInitReqs{modeCounter, artCounter, solverIndex};
            
            % Get stored indices of reqs at sensi and at start
            reqIndicesAtStart = summarizer.allCurrentReqs{modeCounter, artCounter, solverIndex}{1};
            reqIndicesAtSensi = summarizer.allCurrentReqs{modeCounter, artCounter, solverIndex}{2};
            
            if iscell(reqIndicesAtStart)
                % Old way of storing summarizer.allCurrentReqs - storing explicit STL
                % formulas
                reqsAtStart = reqIndicesAtStart;
                reqsAtSensi = reqIndicesAtSensi;
            else
                % New way of storing summarizer.allCurrentReqs - storing indices of
                % formulas
                reqsAtStart = initReqs(reqIndicesAtStart);
                reqsAtSensi = initReqs(reqIndicesAtSensi);
            end
            
        catch
            continue
        end
        
        reqNamesAtStart = cellfun(@(C)get_id(C), reqsAtStart, ...
            'UniformOutput', false);
        reqNamesAtSensi = cellfun(@(C)get_id(C), reqsAtSensi, ...
            'UniformOutput', false);
        
        try
            resSensi = summarizer.allResSensi{modeCounter, artCounter, solverIndex};
            
            thisHist = summarizer.allHist{modeCounter, artCounter, solverIndex};
            cornersIdx = thisHist.method.corners;
            sensiIdx = thisHist.method.sensi;
            nTotalSim = numel(sensiIdx);
        catch
            continue
        end
        
        figure;
        title(['Falsification information about all specs, ' ...
            solverString ' ' ...
            modeStrings{modeCounter} artStrings{artCounter}]);
        hold on;
        
        for reqCounter = 1:numel(reqNamesAtStart)
            thisReqName = reqNamesAtStart{reqCounter};
            % Req was not part of sensitivity analysis, i.e., it was
            % falsified during corners analysis.
            
            falsifIndex = ...
                find(thisHist.rob.(thisReqName) < 0, 1);
            
            if isempty(falsifIndex)
                % Never falsified, either it was removed because it's
                % an _act spec and corresponding _req spec was
                % falsified, or it was simply never falsified
                if any(isnan(thisHist.rob.(thisReqName)))
                    % _act spec which was removed
                    
                    % Set falsifColor to blue.
                    falsifColor = [0 0 1 0.5];
                    
                    % Find falsifIndex as the first index when this spec's
                    % rob is NaN (i.e. it has been removed)
                    falsifIndex = ...
                        find(isnan(thisHist.rob.(thisReqName)), 1) - 1;
                else
                    falsifIndex = nTotalSim;
                    falsifColor = [1 0 0 0.5];
                end
                
            else
                falsifColor = [1 0 0 0.5];
            end
            
            % First a green rectangle showing simulations when not
            % falsified
            x = 0;
            y = numel(reqsAtStart) - reqCounter;
            width = falsifIndex;
            height = 1;
            rectangle('Position',[x, y, width, height], ...
                'FaceColor',[0 1 0 0.5],'LineStyle', 'None')
            
            % Then a red rectangle showing simulations after
            % falsification
            x = falsifIndex;
            y = numel(reqsAtStart) - reqCounter;
            width = nTotalSim - falsifIndex;
            height = 1;
            rectangle('Position',[x, y, width, height], ...
                'FaceColor', falsifColor,'LineStyle', 'None')
        end
        
        % Plot delimiters between corners, sensi, and each sensi iteration
        % Corners
        yMax = 1.1*numel(reqsAtStart);
        yMin = 0;
        xMin = 0;
        xMax = nTotalSim;
        lastCornerIdx = find(cornersIdx, 1, 'last');
        plot([lastCornerIdx, lastCornerIdx], [yMin, yMax], '--r');
        text(lastCornerIdx/2 - 3, 0.95*yMax, 'corners');
        currentDelimiterIndex = lastCornerIdx;
        lastDelimiterIndex = 0;
        
        % Sensi
        for sensiCounter = 1:numel(resSensi)-1
            thisResSensi = resSensi{sensiCounter};
            nSimThisSensi = numel(thisResSensi{1}.rob);
            
            lastDelimiterIndex = currentDelimiterIndex;
            currentDelimiterIndex = currentDelimiterIndex + nSimThisSensi;
            
            plot([currentDelimiterIndex, currentDelimiterIndex], ...
                [yMin, yMax], '--r');
            text((lastDelimiterIndex + currentDelimiterIndex)/2, ...
                0.95*yMax, num2str(sensiCounter));
        end
        
        if isfield(thisHist, 'focused')
            % Focused snobfit
            focusedFields = fieldnames(thisHist.focused);
            focusedFields = focusedFields(contains(focusedFields, 'phi'));
            focusedFieldStartIdx = nan(size(focusedFields));
            focusedFieldEndIdx = nan(size(focusedFields));
            for fieldCounter = 1:numel(focusedFields)
                thisField = focusedFields{fieldCounter};
                thisFieldIdx = thisHist.focused.(thisField);
                focusedFieldStartIdx(fieldCounter) = ...
                    find(thisFieldIdx, 1, 'first');
                focusedFieldEndIdx(fieldCounter) = ...
                    find(thisFieldIdx, 1, 'last');
            end
            
            % Sort the start indices
            [fieldsStartIdxSorted, fieldsSortedIdx] = sort(focusedFieldStartIdx);
            focusedFields = focusedFields(fieldsSortedIdx);
            fieldsEndIdxSorted = focusedFieldEndIdx(fieldsSortedIdx);
            
            % Loop over snobfit indices to plot delimiters
            for fieldCounter = 1:numel(fieldsStartIdxSorted)
                plot([fieldsEndIdxSorted(fieldCounter), fieldsEndIdxSorted(fieldCounter)], ...
                    [yMin, yMax], '--r');
                textToPrint = strrep(focusedFields{fieldCounter}, 'phi_', '');
                textToPrint = strrep(textToPrint, '_', '\_');
                text(fieldsStartIdxSorted(fieldCounter), ...
                    0.95*yMax, textToPrint);
            end
        end
        
        % Set correct axis and axis labels
        axis([xMin xMax yMin yMax]);
        yticks([1:numel(reqsAtStart)] - 0.5);
        escapedReqNames = strrep(reqNamesAtStart, 'phi_', '');
        escapedReqNames = strrep(escapedReqNames, '_', '\_');
        yticklabels(flip(escapedReqNames));
    end
end

end