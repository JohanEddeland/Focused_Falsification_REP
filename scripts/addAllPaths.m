% Add all necessary paths needed to run this REP
addpath(pwd);
addpath('./scripts/matlab2tikz');
addpath('./ARCH_ATwSS');
addpath('./breach_modified');
InitBreach;
addpath('./specTransformer/');
addpath('./ARCH_ATwSS/src');
addpath('./ARCH_ATwSS/specRefModels');
addpath('./ARCH_ATwSS/specRefModelsArtificial');
addpath('./ARCH_ATwSS/STLFiles')
addpath('./ARCH_ATwSS/STLFiles_artificial')

bdclose('AT_and_specifications_breach');
bdclose('AT_and_specifications_artificial_breach');