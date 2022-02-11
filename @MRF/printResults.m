function printResults(mrfResults)
%% Print results from the MRF object

% Print first falsification indices, as stored in the property
% firstIdxFalsified. 
fprintf('\nMRF finished! First falsification index for each spec:\n');
for k = 1:numel(mrfResults.firstIdxFalsified)
    disp([mrfResults.firstIdxFalsified(k).id ': fals ' ...
        num2str(mrfResults.firstIdxFalsified(k).falsification) ...
        ', index ' num2str(mrfResults.firstIdxFalsified(k).index) ...
        ' (global index ' num2str(mrfResults.firstIdxFalsified(k).globalIndex) ')']);
end

% Close all Simulink diagrams
bdclose all;

end