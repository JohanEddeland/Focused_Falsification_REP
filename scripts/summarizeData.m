function summarizeData(totalMaxEval)
% Summarize all the data created in runManyMRF by creating Latex Tables
% that summarize the data. 
%
% Args:
%       totalMaxEval (integer): Number of maximum simulations for each
%           combination of random seed, configuration file, and 
%           optimization solver.


runFolder = 'results';
requireCompleteRuns = false; 

summarizer = MRFRunSummarizer(runFolder, requireCompleteRuns);

% Plot Corners-PR falsification information or not
summarizer.plotCornersPRFalsification = false;

% Plot SNOBFIT falsification information or not
summarizer.plotSnobfitFalsification = false;

% Plot Sensi information? Possible settings:
% none
% cumulative
% noncumulative
summarizer.plotSensiInformationSetting = 'cumulative';

% Visualize rankings?
summarizer.visualizeRankingsFlag = false;

% Print another MRF table with rankings visualized as well
rankingsToVisualizeInTable = {};
% rankingsToVisualizeInTable = {'largestGap', ...
%     'mostRealSignals', ...
%     'relativeRealSignals', ...
%     'biggestSensitivity', ...
%     'lowestRobustness'};
summarizer.rankingsToVisualizeInTable = rankingsToVisualizeInTable;

summarizer = summarizer.summarizeRuns(totalMaxEval);
summarizer.printFinalLatexTables();

end