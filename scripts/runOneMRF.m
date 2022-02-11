%%
% Run one instance of MRF, potentially varying
% - Total number of simulations
% - Which scenario to use, e.g. base or hard
% - Falsification mode, e.g. corners+random or new algo
% - Random seed

warning('off', 'Simulink:Engine:LineWithoutSrc');
diary(['run_' matlab.lang.makeValidName(datestr(now)) '.log']);

model = 'AT_and_specifications';
thisFile = ...'all_base_v1.0.1.mat', ...
       'all_hard_v1.0.1.mat';...
       ...'all_base_artificial_v1.0.1.mat';
thisMode =  ...'corners_pseudorandom';
                         'focused_snobfit';
thisSeed = 5001;%:5;
totalMaxEval = 3000;       
%mrfResults=MRF([model '_artificial'], totalMaxEval, thisFile,thisMode, thisSeed);    
mrfResults=MRF([model '_artificial'], totalMaxEval,'ARCH_base.mat',thisMode, thisSeed);    
    
mrfResults.parallelBatchSize = 50;
%mrfResults.par_sim = 1;
%mrfResults.par_req_eval = 1;
            

%%
mrfResults = mrfResults.run();
diary off;

