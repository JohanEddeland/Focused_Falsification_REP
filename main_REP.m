%% 1. Add all necessary scripts to the MATLAB path
addpath('scripts'); % Adding path of the script adding paths
addAllPaths;

%% 2. Set variables needed to run MRF
% 2a. Total number of simulations for each scenario
% In the paper, we use 3000
totalMaxEval = 40;

% 2b. Configuration files
% Total list:
% allConfigurationFiles = {'all_base_artificial_v1.0.1.mat', ...
%     'all_hard_artificial_v1.0.1.mat', ...
%     'all_base_v1.0.1.mat', ...
%     'all_hard_v1.0.1.mat'};
allConfigurationFiles = {'all_base_v1.0.1.mat'};

% 2c. Random seeds
% Seeds used in paper: [150, 151, 152, 153, 154, 155, 156, 200, 201, 202]
allRandomSeeds = 150;

% 2d. Falsification modes
% Cell array containing either 'corners_pseudorandom', 'focused_snobfit',
% or both. 
allFalsificationModes = {'corners_pseudorandom', 'focused_snobfit'};

%% 3. Run MRF with selected variables
runManyMRF(totalMaxEval, allRandomSeeds, allConfigurationFiles, allFalsificationModes);

%% 4. Generate files presenting the data
% This generates a separate .tex file for each Table in the paper (the .tex
% files are put into the FINAL_PAPER_TABLES folder)
summarizeData(totalMaxEval);

%% 5. Generate a single .tex file with all tables in it
generateOneFileWithAllTables;
