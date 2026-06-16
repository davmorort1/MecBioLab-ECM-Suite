function run_suite()
% RUN_SUITE Launches MecBioLab ECM Suite from the repository root.
%
% Usage:
%   1. Open MATLAB.
%   2. Set the current folder to the repository root.
%   3. Run: run_suite

    repoRoot = fileparts(mfilename('fullpath'));
    addpath(fullfile(repoRoot, 'src'));
    addpath(fullfile(repoRoot, 'src', 'tools'));
    addpath(fullfile(repoRoot, 'assets'));

    if exist('bfGetReader', 'file') == 0
        warning(['Bio-Formats/bfmatlab was not found on the MATLAB path. ', ...
                 'The dashboard will open, but .lif loading will fail until bfmatlab is installed and added to the path.']);
    end

    app_main();
end
