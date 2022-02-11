function plotSensiInformation(summarizer, cumulative)
% This function is used to get an overview of how fast in the sensitivity
% process each requirement achieves its "end state" of sensitivity
% analysis, i.e., we try to illustrate the earliest simulation such that
% each requirement shows sensitivity to all the parameters that it is
% sensitive to at the end of the complete sensitivity analysis.

modeStrings = {'base\_', 'hard\_'};
artStrings = {'', 'artificial\_'};
for modeCounter = 1:size(summarizer.firstIndexFalsifiedStruct, 1)
    for artCounter = 1:size(summarizer.firstIndexFalsifiedStruct, 2)
        try
            initReqs = summarizer.allInitReqs{modeCounter, artCounter, 2};
            
            % Get stored indices of reqs at sensi and at start
            reqIndicesAtStart = summarizer.allCurrentReqs{modeCounter, artCounter, 2}{1};
            reqIndicesAtSensi = summarizer.allCurrentReqs{modeCounter, artCounter, 2}{2};
            
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
            resSensi = summarizer.allResSensi{modeCounter, artCounter, 2};
            
            thisHist = summarizer.allHist{modeCounter, artCounter, 2};
            cornersIdx = thisHist.method.corners;
            sensiIdx = thisHist.method.sensi;
            nTotalSensiSim = numel(find(sensiIdx));
        catch
            continue
        end
        
%         figure;
        titleToPrint = ['Sensitivity information about sensi specs, ' ...
            modeStrings{modeCounter} artStrings{artCounter}];
        if cumulative
            titleToPrint = [titleToPrint ', CUMULATIVE']; %#ok<*AGROW>
        end
        
%         title(titleToPrint);
%         hold on;
        cumulativeMuMatrix = ...
            zeros(numel(resSensi{1}{1}.params), numel(reqNamesAtSensi));
        
        for reqCounter = 1:numel(reqNamesAtSensi)
            thisReqName = reqNamesAtSensi{reqCounter};
            
            % For each req, we need to loop over all sensi iterations, and
            % find out how many mu are non-zero in each (non-zero mu <=>
            % sensitive to that parameter)
            nMuNonZero = [];
            currentIdx = find(cornersIdx, 1, 'last');
            
            % Find correct offset between summarizer.allCurrentReqs and resSensi
            offsetToUse = -1;
            resSensiElements = cellfun(@(c)numel(c), resSensi);
            currentReqsElements = cellfun(@(c)numel(c), summarizer.allCurrentReqs{modeCounter, artCounter, 2});
            for potentialOffset = 1:(numel(currentReqsElements) - numel(resSensiElements) - 1)
                if all(resSensiElements == currentReqsElements(1 + potentialOffset: potentialOffset + numel(resSensiElements)))
                    offsetToUse = potentialOffset;
                end
            end
            
            if offsetToUse == -1
                error('Did not find correct offset between resSensi and summarizer.allCurrentReqs');
            end
            
            for sensiCounter = 1:numel(resSensi)
                
                reqIndicesNow = ...
                    summarizer.allCurrentReqs{modeCounter, artCounter, 2}{offsetToUse + sensiCounter};
                
                % Assert that we have picked the correct iteration
                assert(numel(resSensi{sensiCounter}) == numel(reqIndicesNow));
                
                if iscell(reqIndicesNow)
                    % Old way of storing summarizer.allCurrentReqs
                    reqsNow = reqIndicesNow;
                else
                    % New way
                    reqsNow = initReqs(reqIndicesNow);
                end
                
                reqNamesNow = cellfun(@(C)get_id(C), reqsNow, ...
                    'UniformOutput', false);
                
                if ~any(strcmp(reqNamesNow, thisReqName))
                    % The spec does not exist in the current list
                    break
                else
                    % This req is part of the sensi iteration
                    thisReqSensiIdx = ...
                        strcmp(reqNamesNow, thisReqName);
                    thisMu = resSensi{sensiCounter}{thisReqSensiIdx}.mu;
                    if cumulative
                        tmpNonZeroMu = (thisMu ~= 0) & (~isnan(thisMu));
                        if sensiCounter == 1
                            % First iteration for cumulative - just check
                            % non-zero entries in thisMu
                            cumulativeMu = tmpNonZeroMu;
                        else
                            cumulativeMu = ...
                                or((cumulativeMu), tmpNonZeroMu);
                        end
                        nMuNonZero(end+1) = sum(cumulativeMu);
                    else
                        nMuNonZero(end+1) = sum(tmpNonZeroMu);
                    end
                    
                    currentIdx = currentIdx + ...
                        numel(resSensi{sensiCounter}{thisReqSensiIdx}.rob);
                end
            end
            
            % nMuNonZero is now a vector that for each sensi iteration
            % shows the number of sensitive parameters for it. We plot this
            % using rectangles
            if cumulative
                % We check cumulative non-zero mu - compare to end
                maxMuNonZero = nMuNonZero(end);
            else
                % Otherwise, we compare to maximum
                maxMuNonZero = max(nMuNonZero);
            end
            previousNSimulations = 0;
            for muCounter = 1:numel(nMuNonZero)
                x = previousNSimulations;
                y = numel(reqNamesAtSensi) - reqCounter;
                width = numel(resSensi{muCounter}{1}.rob);
                height = 1;
                
                % Decide FaceColor of rectangle
                if nMuNonZero(muCounter) < maxMuNonZero
                    % Have not reached final number of sensitive params
                    redColor = [0.8 0 0];
                    proportionRedToUse = ...
                        nMuNonZero(muCounter)/maxMuNonZero;
                    faceColor = proportionRedToUse*redColor;
                else
                    faceColor = [0.2 0.6 0 0.8];
                end
                
%                 % Draw rectangle
%                 rectangle('Position',[x, y, width, height], ...
%                     'FaceColor', faceColor, ...
%                     'LineStyle', 'None')
%                 
%                 % Draw text on rectangle
%                 text(x + width/2, y + 0.5, ...
%                     num2str(nMuNonZero(muCounter)));
                
                previousNSimulations = previousNSimulations + width;
            end
            
            cumulativeMuMatrix(:, reqCounter) = cumulativeMu;
        end
        
        % Plot delimiters between each sensi iteration
        % Corners
%         yMax = 1.1*numel(reqsAtSensi);
%         yMin = 0;
%         xMin = 0;
%         xMax = nTotalSensiSim;
%         
%         currentDelimiterIndex = 0;
        
%         for sensiCounter = 1:numel(resSensi)
%             thisResSensi = resSensi{sensiCounter};
%             nSimThisSensi = numel(thisResSensi{1}.rob);
%             
%             lastDelimiterIndex = currentDelimiterIndex;
%             currentDelimiterIndex = currentDelimiterIndex + nSimThisSensi;
%             
%             plot([currentDelimiterIndex, currentDelimiterIndex], ...
%                 [yMin, yMax], '--r');
%             text((lastDelimiterIndex + currentDelimiterIndex)/2, ...
%                 0.95*yMax, num2str(sensiCounter));
%         end
        
        % Set correct axis and axis labels
%         axis([xMin xMax yMin yMax]);
%         yticks([1:numel(reqNamesAtSensi)] - 0.5);
%         escapedReqNames = strrep(reqNamesAtSensi, 'phi_', '');
%         escapedReqNames = strrep(escapedReqNames, '_', '\_');
%         yticklabels(flip(escapedReqNames));
%         
        % Now time to plot total sensitivity results at the end of
        % sensitivity analysis
        % We extract the requirement indices at end of sensi, based on the
        % requirements at start
        reqIndicesAtEndOfSensi = ...
            summarizer.allCurrentReqs{modeCounter, artCounter, 2}{offsetToUse + numel(resSensi) + 1};
        reqNamesAtEndOfSensi = reqNamesAtStart(reqIndicesAtEndOfSensi);
        
        % Now we need to compare this to req names at start of sensitivity
        % analysis, which is how cumulativeMuMatrix is indexed
        reqIndicesForCumulativeMuMatrix = [];
        for tmpCounter = 1:numel(reqNamesAtEndOfSensi)
            thisName = reqNamesAtEndOfSensi{tmpCounter};
            reqIndicesForCumulativeMuMatrix(end+1) = ...
                find(strcmp(reqNamesAtSensi, thisName));
        end
        
       
        
        % Extract the correct values of cumulativeMuMatrix and
        % sensitivityMatrix
        % cumulativeMuMatrix - sensitivity according to ComputeMorrisSensi
        % sensitivityMatrix - structural sensitivity
        morrisSensi = cumulativeMuMatrix(:, reqIndicesForCumulativeMuMatrix);
        
        figure;
        title(titleToPrint);
        
        for reqCounter = 1:size(morrisSensi, 2)
            for paramCounter = 1:size(morrisSensi, 1)
                x = reqCounter;
                y = paramCounter;
                width = 1;
                height = 1;
                
                % Create color of rectangle
                if morrisSensi(paramCounter, reqCounter)
                    faceColor = [0.2 0.6 0 0.8]; % green
                    
                else
                    
                    faceColor = [0.8 0 0 0.8]; % red
                end
                
                %                 rectangle('Position',[x, y, width, height], ...
                %                     'FaceColor', faceColor, ...
                %                     'LineStyle', 'None')
                rectangle('Position',[x, y, width, height], ...
                    'FaceColor', faceColor, ...
                    'LineWidth', 0.3)
            end
        end
        
        paramNames = thisHist.var.names;
        %yticks([1:numel(paramNames)] + 0.5);
        escapedParamNames = strrep(paramNames, '_', '\_');
        %yticklabels(escapedParamNames);
        
        %xticks([1:numel(reqNamesAtEndOfSensi)] + 0.5);
        escapedReqNames = strrep(reqNamesAtEndOfSensi, '_', '\_');
        escapedReqNames = strrep(escapedReqNames, 'phi_', '');
        %xticklabels(escapedReqNames);
        %xtickangle(90);
        xlabel('Requirements');
        ylabel('Input parameters');
        
        % Save figure
        matlab2tikz('FINAL_PAPER_TABLES/sensitivityFigure.tex');
        close(gcf);
        
        % We have now printed one figure, return
        return
        
    end
end

end