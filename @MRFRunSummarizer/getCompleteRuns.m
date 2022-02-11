function seeds = getCompleteRuns(summarizer, nSim)
% This function will return a vector of seeds that contain COMPLETE runs
% A complete run will contain 8 .mat files with each combination of:
% - solver (corners_pseudorandom or new_algo)
% - artificial or not
% - base or hard

allFiles = dir([summarizer.runFolder '/*.mat']);

% simString is e.g. 'sim3000'. We load it becuase we want to assert that
% the number of simulations is exactly the same for all .mat files.
simString = ['sim' num2str(nSim)];

seedStruct = struct();
for fileCounter = 1:numel(allFiles)
    thisName = allFiles(fileCounter).name;
    if ~contains(thisName, [simString '_'])
        % Not the nSim we are considering right now
        continue
    end
    seed = regexp(thisName, 'seed\d+', 'match', 'once');
    
    if isfield(seedStruct, seed)
        seedStruct.(seed) = seedStruct.(seed) + 1;
    else
        seedStruct.(seed) = 1;
    end
end

% We have built seedStruct, a struct, which contains information of how
% many times each seed is available
% We deem a seed to be COMPLETE if it is available 8 times (see above)
allFields = fields(seedStruct);
seeds = [];
for k = 1:numel(allFields)
    thisField = allFields{k};
    if ~summarizer.requireCompleteRuns || ...
            (summarizer.requireCompleteRuns && seedStruct.(thisField) == 8)
        % There are 8 different scenarios available for the given seed
        % Add the given seed to the 'seeds' list which is returned.
        seeds(end+1) = str2double(regexp(thisField, '\d+', 'match', 'once')); %#ok<*AGROW>
    end
end

end