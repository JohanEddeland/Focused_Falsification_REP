classdef MRFRunSummarizer
    % MRFRunSummarizer A class to summarize and visualize MRF runs.
    %   When the MRF class has finished a 'run' (by invoking the run()
    %   function of an object of the MRF class), the results are stored as
    %   a set of .mat-files in a results folder. 
    %   MRFRunSummarizer will read the contents of the specified folder,
    %   and print and plot interesting information. 
    
    properties
        % Folder in which the runs are stored, e.g., 
        % 'remote_2021_09_29_add_norm'
        runFolder
        
        % LaTeX table files
        latexTableFile
        latexTableFileWithRankings
        
        % Specify whether we require only complete runs (all 8 configurations for
        % each seed printed)
        % NOTE: Set to 0 only for viewing intermediate data (to save some time).
        % For final results, we should ONLY have complete runs.
        requireCompleteRuns
        
        % Data to visualize, loaded in loadRuns
        allReqsFalsified
        allReqsStarted
        allReqsFalsified_art
        allReqsStarted_art
        allReqsFalsifiedCountAct
        allHist
        allResSensi
        allCurrentReqs
        allInitReqs
        firstIndexFalsifiedStruct
        B
        robHist
        histStruct
        allReqRankings
        allSensitivityMatrix
        nSafetyReqs
        allSafetyReqFalsified
        
        % Flags for which solvers to plot falsification information
        plotSnobfitFalsification
        plotCornersPRFalsification
        
        % Setting for how to plot sensi information
        plotSensiInformationSetting
        
        % Flag about whether to visualize rankings or not
        visualizeRankingsFlag
        
        % Indicate which rankings to visualize in ANOTHER table
        rankingsToVisualizeInTable
    end
    
    methods
        function summarizer = MRFRunSummarizer(runFolder, ...
                requireCompleteRuns)
            summarizer.runFolder = runFolder;
            summarizer.requireCompleteRuns = requireCompleteRuns;
            summarizer.latexTableFile = ['MRF_table_' runFolder '.tex'];
            summarizer.latexTableFileWithRankings = ...
                ['MRF_table_WITH_RANKINGS_' runFolder '.tex'];
            summarizer.plotSnobfitFalsification = false;
            summarizer.plotCornersPRFalsification = false;
            
            % none, cumulative, or noncumulative
            summarizer.plotSensiInformationSetting = 'none';
            
            summarizer.visualizeRankingsFlag = false;
            
            summarizer.rankingsToVisualizeInTable = {};
        end
        
        function summarizer = summarizeRuns(summarizer, nSimulations)
            % Load all the runs in runFolder
            summarizer = summarizer.loadRuns(nSimulations);
            
            % Print LaTeX table to summarizer.latexTableFile
            summarizer.printDataToLatex();
            
            % Plot falsification information
            if summarizer.plotCornersPRFalsification
                summarizer.plotFalsificationInformation(1);
            end
            if summarizer.plotSnobfitFalsification
                summarizer.plotFalsificationInformation(2);
            end
            
            % Plot sensi information
            switch summarizer.plotSensiInformationSetting
                case 'none'
                    % Do nothing
                case 'cumulative'
                    cumulative = true;
                    summarizer.plotSensiInformation(cumulative)
                case 'noncumulative'
                    cumulative = false;
                    summarizer.plotSensiInformation(cumulative)
                otherwise
                    error('Unknown value of plotSensiInformation');
            end
            
            % Visualize rankings
            if summarizer.visualizeRankingsFlag
                summarizer.visualizeRankings();
            end
            
            % Create another LateX table with rankings as well
            if ~isempty(summarizer.rankingsToVisualizeInTable)
                summarizer.printDataToLatexWithRankings();
            end
        end
        
    end
end