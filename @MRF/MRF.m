classdef MRF
    % MRF  A class to run Multi-Requirement Falsification, MRF
    %   This class is used to run falsification of a set of multiple
    %   requirements, for example using a baseline corners-random
    %   algorithm, or a focused falsification. 
    properties
        model
        totalMaxEval
        
        configurationFile
        falsificationMode
        randomSeed
        B
        R
        currentReqs
        addReqs
        initReqs
        initReqsNames
        inputList
        res_sensi
        R_sensi
        R_sensi_add
        B_sensi
        M
        firstIdxFalsified
        globalIndex
        avgRobFromSensiAnalysis
        resultsFileName
        
        % actual log stuff
        allB
        allR
        allM
        all_res_sensi
        allCurrentReqs
        allFalsifProblems
        
        % Sensitivity matrix - contains a 0 or 1 for each combination of
        % specification and input parameter
        % 1 if sensitive, 0 of not
        % Filled in performSensitivityAnalysis.m
        sensitivityMatrix
        
        % For focused falsification, we keep track of specific
        % BreachRequirement object that calculate robustness for all
        % remaining specs after the focused falsification has finished. 
        % allFocusedHistory is a cell array of BreachRequirement objects
        % with evaluated specifications. 
        allFocusedHistory
        
        % For focused falsification, keep track of all requirements that have
        % been focused so far (so we don't focus them twice)
        focusedRequirements = {}
        
        % Parallel settings
        par_sim =false
        par_req_eval = false
        parallelBatchSize
        
        % Concise run history
        hist
        
        % Store rankings used by focused falsification to select req to 
        % falsify
        focusedReqSelectionMethod
        requirement_rankings
        
        % Store an exclusion list which removes requirements we should not
        % focus
        exclusionList
        
        % A cell array of discrete-valued signals
        discreteValuedSignals = {};
        
        % Test strategy, do we care about act/req first or not?
        testStrategy
        
        % Boolean flag, do we want to use structural sensitivity or not?
        useStructuralSensitivity = false
    end
    
    methods
        function mrfResults = MRF(model, totalMaxEval, B, R, ...
                currentReqs, configurationFile, ...
                falsificationMode, randomSeed)
            % MRF  Perform Multi-Requirement Falsification
            %   model is a Simulink model, e.g., 'myModel'
            %   totalMaxEval is the total simulation budget, e.g., 3000
            %   B is a BreachSimulinkSystem
            %   R is a BreachRequirement
            %   currentReqs is a cell array of STL formulas
            %   configurationFile is a file with parameter values, among
            %     other things
            %   falsificationMode is e.g. 'focused_snobfit'
            %   randomSeed is an optional seed. Standard value is 1. 
            
            mrfResults.model = model;
            mrfResults.totalMaxEval = totalMaxEval;
            mrfResults.globalIndex = 1;
            mrfResults.configurationFile = configurationFile;
            mrfResults.falsificationMode = falsificationMode;
            acceptedSolvers = {'corners_pseudorandom', ...
                'focused_snobfit', ...
                'focused_turbo'};
            assert(any(strcmp(mrfResults.falsificationMode, acceptedSolvers)), ...
                ['Accepted solvers: ' sprintf('%s ', acceptedSolvers{:})]);
            if nargin < 8
                disp('MRF.m: Setting randomSeed = 1 (got no seed as input)');
                mrfResults.randomSeed = 1;
            else
                mrfResults.randomSeed = randomSeed;
            end
            
            % Note that "difficulty" is only interpreted based on the name of the input
            % file name.
            difficulty = '';
            if contains(mrfResults.configurationFile, 'artificial')
                difficulty = [difficulty '_artificial'];
            end
            
            if contains(mrfResults.configurationFile, 'base')
                difficulty = [difficulty '_base'];
            elseif contains(mrfResults.configurationFile, 'hard')
                difficulty = [difficulty '_hard'];
            else
                difficulty = [difficulty 'unknown'];
            end
            
            mrfResults.resultsFileName  = ['results/' mrfResults.falsificationMode ...
                '' difficulty ...
                '_sim' num2str(mrfResults.totalMaxEval) ...
                '_seed' num2str(mrfResults.randomSeed) ...
                '.mat'];
            
            % Add folders to path, initialize variables
            mrfResults.B = B;
            mrfResults.R = R;
            mrfResults.currentReqs = currentReqs;
            mrfResults.allB{end+1} = mrfResults.B;
            mrfResults.allR{end+1} = mrfResults.R;
            
            mrfResults.inputList = mrfResults.B.GetInputParamList;

            % Store initial set of requirements
            mrfResults.initReqs = mrfResults.currentReqs;        
            
            % New way of storing allCurrentReqs: Indices of reqs as stored
            % in initReqs
            mrfResults.allCurrentReqs{end+1} = 1:numel(mrfResults.initReqs);
            
            % init history 
            mrfResults.hist.var.names = mrfResults.B.GetVariables(); % initial variables
            mrfResults.hist.var.values = nan(numel(mrfResults.hist.var.names),mrfResults.totalMaxEval); % initial variables            
            mrfResults.hist.method = struct;
            mrfResults.hist.time = struct;
            init_bool_method = zeros(1,mrfResults.totalMaxEval);
            mrfResults.hist.method.corners = init_bool_method;
            mrfResults.hist.method.pseudorandom = init_bool_method;
            mrfResults.hist.method.sensi = init_bool_method;
            mrfResults.hist.method.snobfitforall = init_bool_method; % "new algo"
            mrfResults.hist.method.focused.req_idx = init_bool_method;            
            
            mrfResults.hist.rob = struct;
            for idx_req = 1:numel(mrfResults.currentReqs)
                name = get_id(mrfResults.currentReqs{idx_req});
                mrfResults.initReqsNames{idx_req} = name;
                mrfResults.hist.rob.(name) = nan(1, mrfResults.totalMaxEval);
                mrfResults.hist.method.focused.(name) = init_bool_method;               
            end     
            
            % init rankings
            % Used in getObjectiveHistoryFocused.m
            mrfResults.focusedReqSelectionMethod = 'largestGap';
            rankingMethods = ...
                {'largestGap', ...
                'mostRealSignals', ...
                'relativeRealSignals', ...
                'biggestSensitivity', ...
                'lowestRobustness'};
            
            for rankingCounter = 1:numel(rankingMethods)
                thisRankingMethod = rankingMethods{rankingCounter};
                mrfResults.requirement_rankings.(thisRankingMethod) = struct();
                for reqCounter = 1:numel(mrfResults.currentReqs)
                    % Initialize ranking and values for each requirement
                    thisReqName = get_id(mrfResults.currentReqs{reqCounter});
                    mrfResults.requirement_rankings.(thisRankingMethod).(thisReqName).ranking = [];
                    mrfResults.requirement_rankings.(thisRankingMethod).(thisReqName).values = [];
                end
            end
            
            mrfResults.exclusionList = {};
            
            % Possible test strategies:
            % - either (don't prioritize either req or act)
            % - req (focus req first, bugfinding)
            % - act (focus act first, test coverage)
            mrfResults.testStrategy = 'either';
            
        end
        
        function mrfResults = run(mrfResults, skipSensi)
            % Main algorithm 
            if nargin<2
                skipSensi=false;
            end
            
            % Init parallel computation
            if mrfResults.par_sim==1
                mrfResults.B.SetupParallel(); % all cores
            elseif isnumeric(mrfResults.par_sim)
                mrfResults.B.SetupParallel(mrfResults.par_sim); % par_sim  is number of cores
            end
            
            if mrfResults.par_req_eval==1
                mrfResults.R.SetupParallel(); % all cores
            elseif isnumeric(mrfResults.par_req_eval)
                mrfResults.R.SetupParallel(mrfResults.par_sim); % par_sim  is number of cores
            end
            
            if mrfResults.par_sim || mrfResults.par_req_eval
                % See % https://www.mathworks.com/matlabcentral/answers/446894-why-is-my-variable-undefined-when-using-parsim
                parfevalOnAll(@() (evalin('base','initializeReqParameters;')),0);
            end
                        
            % Perform sensitivity analysis and print results (remove falsified
            % monitors)
            if strcmp(mrfResults.falsificationMode, 'focused_snobfit')
                mrfResults = runFalsificationCorners(mrfResults);
                mrfResults = performSensitivityAnalysis(mrfResults);                
                
                % Finally run main loop of focused snobfit
                mrfResults = ...
                    runFalsificationsFocused(mrfResults, 'snobfit');
            elseif strcmp(mrfResults.falsificationMode, 'corners_pseudorandom')
                mrfResults = runFalsificationCorners(mrfResults);
                if ~isempty(mrfResults.currentReqs)
                    mrfResults = runFalsificationsRandom(mrfResults);
                end
            elseif strcmp(mrfResults.falsificationMode, 'focused_turbo')
                mrfResults = runFalsificationCorners(mrfResults);
                mrfResults = performSensitivityAnalysis(mrfResults);      
                
                mrfResults = ...
                    runFalsificationsFocused(mrfResults, 'turbo');
            end
            
            % Print results
            printResults(mrfResults);
            
            % Save results
            saveResults(mrfResults);
            
        end
        
        function plotReqHist(mrfResults, expr)
        % plotReqHist(mrfResult, req_expr) plots robustness for requirement matching req_expr on the current
        % axes. 
            req_names = fieldnames(mrfResults.hist.rob);
            % search for expr in req_names
            hold on;
            req_to_plot= req_names(~cell2mat(cellfun(@isempty, regexp(req_names, expr), 'UniformOutput', false)));
            for idx_req = 1:numel(req_to_plot)
                rob = mrfResults.hist.rob.(req_to_plot{idx_req});                
                y = normalize(rob, 'scale');
                plot(1:numel(rob), y);                
            end
            grid on;            
            plot(mrfResults.hist.method.corners-1)
            plot(mrfResults.hist.method.sensi-3)
            legend([req_to_plot ;{'corners'; 'sensi'}], 'Interpreter', 'None');
            
        end
        
        function plotAllHist(mrfResults)

            % one figure with ARCH            
            figure;
            subplot(7,1,1);
            plotReqHist(mrfResults,'ARCH_AT1');
            subplot(7,1,2);
            plotReqHist(mrfResults,'ARCH_AT2');
            subplot(7,1,3);
            plotReqHist(mrfResults,'ARCH_AT51');
            subplot(7,1,4);
            plotReqHist(mrfResults,'ARCH_AT52');
            subplot(7,1,5);
            plotReqHist(mrfResults,'ARCH_AT53');            
            subplot(7,1,6);
            plotReqHist(mrfResults,'ARCH_AT6a');
            subplot(7,1,7);
            plotReqHist(mrfResults,'ARCH_AT6b');
            
                                    
            % one figure with the rest
            figure;
            subplot(7,1,1);
            plotReqHist(mrfResults,'ADA');
            subplot(7,1,2);
            plotReqHist(mrfResults,'ADI');
            subplot(7,1,3);
            plotReqHist(mrfResults,'AFE');
            subplot(7,1,4);
            plotReqHist(mrfResults,'AOT');
            subplot(7,1,5);
            plotReqHist(mrfResults,'ASL');
            subplot(7,1,6);
            plotReqHist(mrfResults,'BTL');
            subplot(7,1,7);
            plotReqHist(mrfResults,'RFC');
            
        end
    
        function plotCurrentReqsHist(mrfResults)
           num_reqs =numel(mrfResults.currentReqs);
           figure;
           for idx_req = 1:num_reqs
               name_req = get_id(mrfResults.currentReqs{idx_req});
               ax(idx_req) = subplot(num_reqs, 1, idx_req);
               mrfResults.plotReqHist(name_req);               
           end
           linkaxes(ax);           
        end
        
        function plotFocusedReqsHist(mrfResults)
           num_reqs =numel(mrfResults.focusedRequirements);
           figure;
           for idx_req = 1:num_reqs
               name_req = mrfResults.focusedRequirements{idx_req};
               idx_init_req = find(strcmp(name_req,mrfResults.initReqsNames),1);
               ax(idx_req) = subplot(num_reqs, 1, idx_req);
               hold on;
               rob = normalize(mrfResults.hist.rob.(name_req), 'scale');                               
               focused = mrfResults.hist.focused.req_idx==idx_init_req;                               
               plot(1:numel(rob), rob);                                             
               plot(1:numel(rob), focused);                                             
               legend({name_req 'focused'}, 'Interpreter', 'None');
           end
           
           linkaxes(ax);           
        end
        
        function mrfResults = updateHistFromFalsifPb(mrfResults, pb, idx_start, idx_end)
        % reads log from pb and update hist with correct matching of param names (hopefully) 
            var_pb = [pb.params pb.stochastic_params];
            values_pb = [pb.X_log ; pb.X_stochastic_log];
            for idx_var_pb =1:numel(var_pb)                
                idx_var_hist = find(strcmp(var_pb{idx_var_pb}, mrfResults.hist.var.names),1);
                mrfResults.hist.var.values(idx_var_hist, idx_start:idx_end) = values_pb(idx_var_pb,:); 
            end                        
        end
        
        
    end
end