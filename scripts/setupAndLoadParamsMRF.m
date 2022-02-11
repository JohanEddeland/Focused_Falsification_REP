function [B, R, currentReqs, discreteValuedSignals] = ...
    setupAndLoadParamsMRF(model, configurationFile, useIOSTL)

%Initialize benchmarks and tools (Breach, specTransformer)
init_ATwSS;

% Start timing of this function
startTime = tic;

%% Load configuration
if isfile(['scripts' filesep configurationFile])
    % If configurationFile exists, load it
    disp(['Loading setup from ' configurationFile]);
    load(['scripts' filesep configurationFile], 'B', 'R', 'currentReqs');
elseif contains(model, '_artificial')
    % If configurationFile does not exist, use interactive initialization
    disp('Setting up model with artificial inputs');
    [B, R, currentReqs, params]= setup_ATwSS_artificial();
else
    % If configurationFile does not exist, use interactive initialization
    disp('Setting up model without artificial inputs');
    [B, R, currentReqs, params]= setup_ATwSS();
end

% If the BreachSimulinkSystem has not been created, create it here!
if ~exist(B.Sys.name, 'file')
    % Remove _breach from the end of B.Sys.name
    BreachSimulinkSystem(B.Sys.name(1:end-7));
end

% For each spec, we want to extract the signals and ONLY set the
% non-discrete signals as outputs.
% For the discrete-valued signals, we do nothing (they will be ignored
% in robustness computations).

% Step 1: Find out which signals are discrete-valued
% We start with the ones we KNOW are discrete-valued
discreteValuedSignals = ...
    {'gear', 'gearSelectionState', 'downThreshold', 'upThreshold'};
eval([model '([], [], [], ''compile'')']); 
loggedSignals = find_in_models(model, 'FindAll', 'on', 'DataLogging', 'on');
for signalCounter = 1:numel(loggedSignals)
    thisName = get(loggedSignals(signalCounter), 'Name');
    thisType = get(loggedSignals(signalCounter), 'CompiledPortDataType');
    
    switch thisType
        case 'double'
            % Do nothing
        case 'boolean'
            % Add to discreteValuedSignals
            discreteValuedSignals{end+1} = thisName; %#ok<*AGROW>
        otherwise
            error('Unhandled case of signal dataType - add to switch statement');
    end
end
discreteValuedSignals = unique(discreteValuedSignals);
eval([model '([], [], [], ''term'')']); 

% Step 2: Display the found discrete-valued signals
fprintf('setupAndLoadParamsMRF.m: The following signals were found to be discrete-valued: ');
for signalCounter = 1:numel(discreteValuedSignals)
    fprintf(discreteValuedSignals{signalCounter});
    if signalCounter < numel(discreteValuedSignals)
        fprintf(', ');
    end
end
fprintf('\n');

% Step 3: Set discrete-valued signals as outputs (if enabled)
if useIOSTL
    for reqCounter = 1:numel(currentReqs)
        thisReq = currentReqs{reqCounter};
        signalsInThisReq = STL_ExtractSignals(thisReq);
        outputSignals = setdiff(signalsInThisReq, ...
            discreteValuedSignals);
        currentReqs{reqCounter} = set_out_signal_names(thisReq, outputSignals);
    end
end

for monitorCounter = 1:numel(currentReqs)
    currentReqs{monitorCounter} = ...
        set_semantics(currentReqs{monitorCounter}, 'add');
end

% Make sure R contains the new requirements (i.e. with output signals
% correctly set)
R = BreachRequirement(currentReqs);

% We need to fix root folders for the BreachSimulinkSystem
% object
breachPath = which('InitBreach');
breachPath = regexp(breachPath, ['.*\' filesep 'breach_modified'], 'match');
breachPath = breachPath{1};
diskCachingRoot = [breachPath filesep 'Ext' filesep 'ModelsData' filesep 'Cache'];
parallelTempRoot = [breachPath filesep 'Ext' filesep 'ModelsData' filesep 'ParallelTemp'];

B.DiskCachingRoot = diskCachingRoot;
B.ParallelTempRoot = parallelTempRoot;
R.ParallelTempRoot = parallelTempRoot;

if isempty(B)
    return;
end

end