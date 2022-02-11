function reqResults = compareToOtherSummarizer(summarizer, summarizer2)
% Current functionality: Compare two implementation of solvers against each
% other (ignore corners-PR data here)

% Create a struct where we store requirement-wise results
% Case 1: Both falsified, solver1 faster
% Case 2: Both falsified, solver2 faster
% Case 3: Both falsified, same first index
% Case 4: Solver 1 falsified, solver 2 did not falsify
% Case 5: Solver 1 did not falsify, solver 2 falsified
% Case 6: Neither falsified, solver 1 lower rob
% Case 7: Neither falsified, solver 2 lower rob
% Case 8: Neither falsified, same lowest rob
reqResults = struct();

solverIndex = 2; % Focused falsification
for modeCounter = 1:size(summarizer.firstIndexFalsifiedStruct, 1)
    for artCounter = 1:size(summarizer.firstIndexFalsifiedStruct, 2)
        for seedCounter = 1:size(summarizer.firstIndexFalsifiedStruct, 4)
            hist1 = summarizer.allHist{modeCounter, ...
                artCounter, solverIndex, seedCounter};
            hist2 = summarizer2.allHist{modeCounter, ...
                artCounter, solverIndex, seedCounter};
            firstIdx1 = summarizer.firstIndexFalsifiedStruct(modeCounter, ...
                    artCounter, solverIndex, seedCounter);
                firstIdx2 = summarizer.firstIndexFalsifiedStruct(modeCounter, ...
                    artCounter, solverIndex, seedCounter);
            for req = fieldnames(hist1.rob)'
                % Initialize req in reqResults if it's not there before
                if ~isfield(reqResults, req{1})
                    for k = 1:8
                        fname = ['case' num2str(k)];
                        reqResults.(req{1}).(fname) = 0;
                    end
                end
                
                rob1 = hist1.rob.(req{1});
                rob2 = hist2.rob.(req{1});
                
                if min(rob1) < 0 && min(rob2) < 0
                    idx1 = firstIdx1.(req{1});
                    idx2 = firstIdx2.(req{1});
                    if idx1 < idx2
                        % Case 1
                        reqResults.(req{1}).case1 = reqResults.(req{1}).case1 + 1;
                    elseif idx1 > idx2
                        % Case 2
                        reqResults.(req{1}).case2 = reqResults.(req{1}).case2 + 1;
                    else
                        % Case 3
                        reqResults.(req{1}).case3 = reqResults.(req{1}).case3 + 1;
                    end
                elseif min(rob1) < 0 && min(rob2) >= 0
                    % Case 4
                    reqResults.(req{1}).case4 = reqResults.(req{1}).case4 + 1;
                elseif min(rob1) >= 0 && min(rob2) < 0
                    % Case 5
                    reqResults.(req{1}).case5 = reqResults.(req{1}).case5 + 1;
                elseif min(rob1) >= 0 && min(rob2) >= 0
                    if min(rob1) < min(rob2)
                        % Case 6
                        reqResults.(req{1}).case6 = reqResults.(req{1}).case6 + 1;
                    elseif min(rob2) < min(rob1)
                        % Case 7
                        reqResults.(req{1}).case7 = reqResults.(req{1}).case7 + 1;
                    else
                        % Case 8
                        reqResults.(req{1}).case8 = reqResults.(req{1}).case8 + 1;
                    end
                else
                    error('Unexpected'); 
                end
                
            end
        end
    end
end



end