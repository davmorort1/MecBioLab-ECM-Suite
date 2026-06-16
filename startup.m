% STARTUP Optional MATLAB startup helper for this repository.
% It adds the suite folders to the MATLAB path when the repository root is
% the current folder. To launch the application, run: run_suite

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'src'));
addpath(fullfile(repoRoot, 'src', 'tools'));
addpath(fullfile(repoRoot, 'assets'));
