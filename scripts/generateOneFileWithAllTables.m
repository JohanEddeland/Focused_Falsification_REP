% Open a new file which will contain all the generated tables
[fid,msg] = fopen(['FINAL_PAPER_TABLES' filesep 'fileWithAllTables.tex'],'wt');

% Initialize LaTeX document
fprintf(fid, '\\documentclass{article}\n');
fprintf(fid, '\\usepackage[english]{babel}\n');
fprintf(fid, '\\usepackage[letterpaper,top=2cm,bottom=2cm,left=3cm,right=3cm,marginparwidth=1.75cm]{geometry}\n');
fprintf(fid, '\\usepackage[dvipsnames]{xcolor}\n');
fprintf(fid, '\\usepackage{colortbl,multirow,booktabs,graphicx}\n');
fprintf(fid, '\\usepackage{pgfplots}\n');
fprintf(fid, '\\usetikzlibrary{decorations.pathreplacing}\n');
fprintf(fid, '\\pgfplotsset{compat=1.16}\n');
fprintf(fid, '\\def\\False{False}\n');
fprintf(fid, '\\def\\Cover{Cover}\n');
fprintf(fid, '\\def\\Total{HitRate}\n');

fprintf(fid, '\\title{Generated table data for HSCC 2022 Paper 27\\\\Generated at %s}\n', datestr(now));
fprintf(fid, '\\begin{document}\n');
fprintf(fid, '\\maketitle\n\n\n');

tableFilesToAdd = {['FINAL_PAPER_TABLES' filesep 'headerTable.tex'], ...
    ['FINAL_PAPER_TABLES' filesep 'summarizerTable.tex'], ...
    ['FINAL_PAPER_TABLES' filesep 'nonArtModel_standardSpecs.tex'], ...
    ['FINAL_PAPER_TABLES' filesep 'artModel_artSpecs.tex'], ...
    ['FINAL_PAPER_TABLES' filesep 'artModel_artSpecs.tex']};

% Write all tables
for fileCounter = 1:numel(tableFilesToAdd)-1
    tableString = fileread(tableFilesToAdd{fileCounter});
    % Start table environment
    fprintf(fid, '\\begin{table}[htbp!]\n');
    fprintf(fid, '\\renewcommand{\\arraystretch}{1.05}\n');
    fprintf(fid, '\\caption{Table %d from the paper}\n', fileCounter);
    fprintf(fid, '\\centering\n');
    
    % Start a resizebox to fit the table
    fprintf(fid, '\\resizebox{\\textwidth}{!}{%%\n');

    % Print actual table
    fprintf(fid, '%s\n', tableString);
    
    % End resizebox
    fprintf(fid, '}\n');
    
    % End table environment
    fprintf(fid, '\\end{table}\n\n');
end

% Write the figure
figString = fileread(['FINAL_PAPER_TABLES' filesep 'sensitivityFigure.tex']);
% Start figure environment
fprintf(fid, '\\begin{figure}[htbp!]\n');
fprintf(fid, '\\begin{center}\n');
fprintf(fid, '\\resizebox{\\textwidth}{!}{%%\n');
fprintf(fid, '%s\n', figString);
fprintf(fid, '}\n');
fprintf(fid, '\\caption{Figure 2 from the paper}\n');
fprintf(fid, '\\end{center}\n');
fprintf(fid, '\\end{figure}\n');

% End document
fprintf(fid, '\\end{document}\n');
fclose(fid);


