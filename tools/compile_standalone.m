
function compile_standalone(bioformatsJar)
% COMPILE_STANDALONE Builds a standalone MATLAB executable of the suite.
%
% Requirements:
%   - MATLAB Compiler
%   - A valid Bio-Formats JAR path, e.g. bioformats_package.jar
%
% Usage:
%   compile_standalone('C:\path\to\bioformats_package.jar')
%
% Note: The degradation/tunnel annotation workflow requires a Python/SAM2 runtime. For compiled deployment,
% validate Python/SAM2 paths on the target machine before distribution.

    if nargin < 1 || isempty(bioformatsJar) || ~isfile(bioformatsJar)
        error('Provide a valid path to bioformats_package.jar.');
    end

    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    mainFile = fullfile(repoRoot, 'run_suite.m');
    addFiles = {
        fullfile(repoRoot, 'src'), ...
        fullfile(repoRoot, 'assets'), ...
        bioformatsJar
    };

    if ~license('test','Compiler')
        error('MATLAB Compiler license is not available.');
    end

    outDir = fullfile(repoRoot, 'build', 'standalone');
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    buildResults = compiler.build.standaloneApplication(mainFile, ...
        'AdditionalFiles', addFiles, ...
        'ExecutableName', 'MecBioLab_ECM_Suite', ...
        'OutputDir', outDir);

    disp(buildResults);
    fprintf('Standalone build written to: %s\n', outDir);
end
