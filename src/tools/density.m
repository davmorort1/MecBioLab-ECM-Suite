function module2B_ecm_raw_colormap_fullfield_v2(fig_launcher, forcedOutputDir)
% MODULE 2B - ECM RAW COLORMAP FULL FIELD
% Continuous full-field ECM intensity map.
% Visual scale: minimum = 0; maximum = real maximum for each position.
%
% Optional call forms:
%   module2B_ecm_raw_colormap_fullfield_v2
%   module2B_ecm_raw_colormap_fullfield_v2(appMainFigureOrApp)
%   module2B_ecm_raw_colormap_fullfield_v2(appMainFigureOrApp, outputDir)
%   module2B_ecm_raw_colormap_fullfield_v2(outputDir)

    if nargin < 1
        fig_launcher = [];
    end
    if nargin < 2
        forcedOutputDir = '';
    end

    %% State
    appState = struct();
    appState.fileLIF = '';
    appState.fileName = '';
    appState.basePath = '';
    appState.outDir = '';
    appState.results = table();
    appState.errors = table();
    appState.pxX = 1;
    appState.pxY = 1;
    appState.pxZ = 1;

    %% UI
    fig_mod = uifigure('Name', 'Module 2B v2: ECM Raw Colormap Full Field', ...
        'Color', 'k', 'Position', [100 100 1400 800]);
    fig_mod.WindowState = 'maximized';
    fig_mod.CloseRequestFcn = @closeModule;

    gl = uigridlayout(fig_mod, [1 2]);
    gl.ColumnWidth = {390, '1x'};
    gl.BackgroundColor = 'k';
    gl.Padding = [6 6 6 6];

    pnl_ctrl = uipanel(gl, 'Title', 'Batch Process Control', ...
        'BackgroundColor', [0.10 0.10 0.10], 'ForegroundColor', 'w');
    gl_ctrl = uigridlayout(pnl_ctrl, [14 1]);
    gl_ctrl.RowHeight = {44, 28, 300, 38, 44, '1x', 26, 40, 1, 1, 1, 1, 1, 1};
    gl_ctrl.BackgroundColor = [0.10 0.10 0.10];

    btn_load = uibutton(gl_ctrl, 'push', 'Text', '1. Load .LIF File', ...
        'BackgroundColor', [0.20 0.42 0.65], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @loadFile);
    lbl_file = uilabel(gl_ctrl, 'Text', 'Waiting for file...', 'FontColor', [0.85 0.85 0.85]);

    pnl_params = uipanel(gl_ctrl, 'Title', 'Raw Colormap Parameters', ...
        'BackgroundColor', [0.14 0.14 0.14], 'ForegroundColor', 'w');
    gp = uigridlayout(pnl_params, [12 2]);
    gp.ColumnWidth = {'1x', 130};
    gp.RowHeight = repmat({24}, 1, 12);
    gp.BackgroundColor = [0.14 0.14 0.14];

    addLbl(gp, 'ECM / fibers channel:');
    ui_ch = uieditfield(gp, 'numeric', 'Value', 2, 'Limits', [1 Inf], 'RoundFractionalValues', 'on');

    addLbl(gp, 'Projection through Z:');
    ui_proj = uidropdown(gp, 'Items', {'Mean signal', 'Median signal', 'Integrated signal'}, 'Value', 'Mean signal');

    addLbl(gp, 'Max XY side (0 = full):');
    ui_maxXY = uieditfield(gp, 'numeric', 'Value', 0, 'Limits', [0 Inf], 'RoundFractionalValues', 'on');

    addLbl(gp, 'Z step:');
    ui_zstep = uieditfield(gp, 'numeric', 'Value', 1, 'Limits', [1 Inf], 'RoundFractionalValues', 'on');

    addLbl(gp, 'Background subtract pct:');
    ui_bgPct = uieditfield(gp, 'numeric', 'Value', 1, 'Limits', [0 20]);

    addLbl(gp, 'Denoise sigma px:');
    ui_denoise = uieditfield(gp, 'numeric', 'Value', 0.8, 'Limits', [0 Inf]);

    addLbl(gp, 'Final smooth sigma px:');
    ui_smooth = uieditfield(gp, 'numeric', 'Value', 3, 'Limits', [0 Inf]);

    addLbl(gp, 'Raw display low pct:');
    ui_rawLow = uieditfield(gp, 'numeric', 'Value', 0.5, 'Limits', [0 20]);

    addLbl(gp, 'Raw display high pct:');
    ui_rawHigh = uieditfield(gp, 'numeric', 'Value', 99.7, 'Limits', [50 100]);

    addLbl(gp, 'Colormap:');
    ui_cmap = uidropdown(gp, 'Items', {'turbo', 'parula', 'hot', 'jet'}, 'Value', 'turbo');

    addLbl(gp, 'Save editable .fig:');
    ui_saveFig = uicheckbox(gp, 'Text', '', 'Value', false, 'FontColor', 'w');

    addLbl(gp, 'Save MAT maps:');
    ui_saveMat = uicheckbox(gp, 'Text', '', 'Value', false, 'FontColor', 'w');

    btn_help = uibutton(gl_ctrl, 'push', 'Text', 'Parameter Guide', ...
        'BackgroundColor', [0.30 0.30 0.30], 'FontColor', 'y', 'ButtonPushedFcn', @showHelpGuide);

    btn_run = uibutton(gl_ctrl, 'push', 'Text', '2. RUN RAW COLORMAP BATCH', ...
        'BackgroundColor', [0.10 0.55 0.20], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'Enable', 'off', 'ButtonPushedFcn', @runBatch);

    txt_log = uitextarea(gl_ctrl, 'Editable', 'off', 'FontName', 'Consolas', ...
        'FontSize', 11, 'BackgroundColor', 'k', 'FontColor', [0 1 0], ...
        'Value', {'[Module 2 - Raw ECM Colormap] Ready.', ...
                  'This version uses continuous ECM signal only.', ...
                  'Heatmap scale: minimum = 0; maximum = real maximum of each position.'});
    lbl_progress = uilabel(gl_ctrl, 'Text', 'Progress: 0%', 'FontColor', 'c', ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    btn_back = uibutton(gl_ctrl, 'push', 'Text', '< Back to Main Menu', ...
        'BackgroundColor', [0.45 0.10 0.10], 'FontColor', 'w', 'ButtonPushedFcn', @closeModule);

    tg = uitabgroup(gl);
    tab_table = uitab(tg, 'Title', 'Live Registry', 'BackgroundColor', 'w');
    gl_table = uigridlayout(tab_table, [1 1]);
    uit_results = uitable(gl_table, 'Data', table());

    tab_preview = uitab(tg, 'Title', 'Preview', 'BackgroundColor', 'w');
    gl_prev = uigridlayout(tab_preview, [1 1]);
    ax_preview = uiaxes(gl_prev);
    axis(ax_preview, 'off');
    title(ax_preview, 'Raw colormap preview will appear during batch');

    %% UI helpers
    function addLbl(parent, text)
        uilabel(parent, 'Text', text, 'FontColor', 'w', 'FontSize', 11);
    end

    function logMessage(msg)
        try
            txt_log.Value = [txt_log.Value; {char(msg)}];
            if numel(txt_log.Value) > 300
                txt_log.Value = txt_log.Value(end-299:end);
            end
            try
                scroll(txt_log, 'bottom');
            catch
            end
            drawnow limitrate;
        catch
        end
    end

    function closeModule(~, ~)
        try
            if isvalid(fig_mod)
                delete(fig_mod);
            end
        catch
        end
        try
            if ~isempty(fig_launcher) && isvalid(fig_launcher)
                fig_launcher.Visible = 'on';
            end
        catch
        end
    end

    function loadFile(~, ~)
        if exist('bfGetReader', 'file') == 0 || exist('bfGetPlane', 'file') == 0
            uialert(fig_mod, 'Bio-Formats is missing from MATLAB path.', 'Bio-Formats missing');
            return;
        end
        [file, path] = uigetfile({'*.lif','Leica LIF (*.lif)'}, 'Select .LIF file');
        if isequal(file, 0)
            return;
        end
        appState.fileLIF = fullfile(path, file);
        appState.basePath = path;
        appState.fileName = file;
        lbl_file.Text = file;
        btn_run.Enable = 'on';
        logMessage(['Loaded: ' file]);
    end

    function showHelpGuide(~, ~)
        msg = sprintf(['This module intentionally does not segment fibers.\n\n' ...
            'Map calculation:\n' ...
            '1. Read the ECM/fiber channel through Z.\n' ...
            '2. Subtract a low global background percentile.\n' ...
            '3. Apply mild denoising only.\n' ...
            '4. Project continuous signal through Z.\n' ...
            '5. Smooth the final map lightly.\n' ...
            '6. Shift map so min = 0; color limit max = true map maximum.\n\n' ...
            'Max XY side = 0 keeps the full original resolution.\n' ...
            'If Max XY side > 0, the whole field is resized; it is never cropped.']);
        uialert(fig_mod, msg, 'Raw Colormap Guide', 'Icon', 'info');
    end

    %% Batch
    function runBatch(~, ~)
        if isempty(appState.fileLIF)
            uialert(fig_mod, 'Load a .LIF file first.', 'No file');
            return;
        end

        [globalOutDir, outSource] = resolveOutputRoot();
        if isempty(globalOutDir)
            globalOutDir = uigetdir(appState.basePath, 'Select output folder');
            if isequal(globalOutDir, 0)
                logMessage('Output selection cancelled.');
                return;
            end
            outSource = 'manual folder selection';
        end

        if ~exist(globalOutDir, 'dir')
            try
                mkdir(globalOutDir);
            catch MEdir
                uialert(fig_mod, ['Cannot create output root folder: ' globalOutDir newline MEdir.message], 'Output folder error');
                return;
            end
        end

        logMessage(['Output root source: ' outSource]);
        logMessage(['Output root: ' globalOutDir]);

        rootDir = fullfile(globalOutDir, 'Module_2B_ECM_RawColormap');
        if ~exist(rootDir, 'dir'), mkdir(rootDir); end
        appState.outDir = makeRunFolder(rootDir);
        dirs = createOutputDirs(appState.outDir);
        logMessage(['Output folder: ' appState.outDir]);

        param = readParams();
        appState.results = table();
        appState.errors = table();
        uit_results.Data = table();

        btn_run.Enable = 'off';
        btn_load.Enable = 'off';

        d = [];
        reader = [];
        try
            d = uiprogressdlg(fig_mod, 'Title', 'Raw ECM colormap', ...
                'Message', 'Opening LIF...', 'Cancelable', 'on');

            reader = bfGetReader(appState.fileLIF);
            nSeries = reader.getSeriesCount();
            omeMeta = reader.getMetadataStore();
            [~, cleanName, ~] = fileparts(appState.fileName);
            cleanName = cleanFileName(cleanName);
            logMessage(sprintf('Detected %d positions.', nSeries));

            for s = 1:nSeries
                if ~isempty(d) && d.CancelRequested
                    logMessage('Batch cancelled by user.');
                    break;
                end
                try
                    reader.setSeries(s-1);
                    w0 = reader.getSizeX();
                    h0 = reader.getSizeY();
                    nZ = reader.getSizeZ();
                    nC = reader.getSizeC();

                    if param.ch > nC
                        error('Selected channel %d but this series has only %d channel(s).', param.ch, nC);
                    end

                    appState.pxX = getPhysicalPixel(omeMeta, s-1, 'X');
                    appState.pxY = getPhysicalPixel(omeMeta, s-1, 'Y');
                    appState.pxZ = getPhysicalPixel(omeMeta, s-1, 'Z');

                    logMessage(sprintf('--- Position %d/%d | %dx%dx%d | ch %d ---', s, nSeries, w0, h0, nZ, param.ch));
                    updateProgress(d, (s-1)/max(nSeries,1), sprintf('Position %d/%d: estimating background...', s, nSeries));

                    res = processOnePosition(reader, s, cleanName, param, dirs, d, nSeries);
                    appState.results = [appState.results; res]; %#ok<AGROW>
                    uit_results.Data = appState.results;
                    updateLivePreview(res);
                    lbl_progress.Text = sprintf('Progress: %d / %d (%.1f%%)', s, nSeries, 100*s/nSeries);
                    drawnow limitrate;
                catch MEp
                    logMessage(sprintf('Position %d ERROR: %s', s, MEp.message));
                    errRow = table(s, string(MEp.message), 'VariableNames', {'Position','Error'});
                    appState.errors = [appState.errors; errRow]; %#ok<AGROW>
                end
            end

            updateProgress(d, 1, 'Saving results tables...');
            saveResultTables(dirs);
            logMessage('>>> BATCH COMPLETE.');
            uialert(fig_mod, sprintf('Raw ECM colormap complete.\n%s', appState.outDir), 'Completed');
        catch ME
            logMessage(['CRITICAL ERROR: ' ME.message]);
            uialert(fig_mod, ME.message, 'Batch Execution Failed');
        end

        try
            if ~isempty(reader), reader.close(); end
        catch
        end
        try
            if ~isempty(d) && isvalid(d), close(d); end
        catch
        end
        btn_run.Enable = 'on';
        btn_load.Enable = 'on';
        lbl_progress.Text = 'Completed.';
    end

    function param = readParams()
        param = struct();
        param.ch = max(1, round(ui_ch.Value));
        param.projection = ui_proj.Value;
        param.maxXY = max(0, round(ui_maxXY.Value));
        param.zStep = max(1, round(ui_zstep.Value));
        param.bgPct = min(max(ui_bgPct.Value, 0), 20);
        param.denoiseSigma = max(0, ui_denoise.Value);
        param.smoothSigma = max(0, ui_smooth.Value);
        param.rawLowPct = min(max(ui_rawLow.Value, 0), 20);
        param.rawHighPct = min(max(ui_rawHigh.Value, 50), 100);
        if param.rawHighPct <= param.rawLowPct
            param.rawHighPct = min(100, param.rawLowPct + 1);
        end
        param.cmap = ui_cmap.Value;
        param.saveFig = ui_saveFig.Value;
        param.saveMat = ui_saveMat.Value;
    end


    function [outRoot, sourceLabel] = resolveOutputRoot()
        % Tries to inherit the results folder configured in AppMain.
        % This is intentionally permissive because different AppMain versions
        % store the folder under different names or inside UserData/appdata.
        outRoot = '';
        sourceLabel = '';

        candidateNames = {'GlobalOutputDir','OutputDir','ResultsDir','ResultDir', ...
            'ResultsPath','OutputPath','SaveDir','SavePath','BaseOutputDir', ...
            'SelectedOutputDir','MainOutputDir','RootOutputDir','ExportDir', ...
            'ResultsFolder','OutputFolder','FolderResults','AppResultsDir', ...
            'MecBioLabResultsDir','globalResultsPath','appResultsPath'};

        % 1) Explicit second argument has priority.
        [outRoot, sourceLabel] = tryPathCandidate(forcedOutputDir, 'forcedOutputDir');
        if ~isempty(outRoot), return; end

        % 2) If first input is directly a folder path.
        [outRoot, sourceLabel] = tryPathCandidate(fig_launcher, 'first input path');
        if ~isempty(outRoot), return; end

        % 3) Input object/figure/struct itself.
        [outRoot, sourceLabel] = searchInThing(fig_launcher, 'fig_launcher/app input', candidateNames, 0);
        if ~isempty(outRoot), return; end

        % 4) UserData of launcher figure/app.
        try
            if ~isempty(fig_launcher) && isvalid(fig_launcher)
                ud = fig_launcher.UserData;
                [outRoot, sourceLabel] = searchInThing(ud, 'fig_launcher.UserData', candidateNames, 0);
                if ~isempty(outRoot), return; end
            end
        catch
        end

        % 5) Appdata in the launcher and root graphics object.
        for ii = 1:numel(candidateNames)
            nm = candidateNames{ii};
            try
                if ~isempty(fig_launcher) && isvalid(fig_launcher) && isappdata(fig_launcher, nm)
                    [outRoot, sourceLabel] = tryPathCandidate(getappdata(fig_launcher, nm), ['appdata launcher.' nm]);
                    if ~isempty(outRoot), return; end
                end
            catch
            end
            try
                if isappdata(0, nm)
                    [outRoot, sourceLabel] = tryPathCandidate(getappdata(0, nm), ['root appdata.' nm]);
                    if ~isempty(outRoot), return; end
                end
            catch
            end
        end

        % 6) Base workspace variables, useful when AppMain stores a global path.
        for ii = 1:numel(candidateNames)
            nm = candidateNames{ii};
            try
                existsVar = evalin('base', sprintf('exist(''%s'',''var'')', nm));
                if existsVar
                    val = evalin('base', nm);
                    [outRoot, sourceLabel] = tryPathCandidate(val, ['base workspace.' nm]);
                    if ~isempty(outRoot), return; end
                end
            catch
            end
        end

        % 7) MATLAB preferences, if the suite uses setpref.
        prefGroups = {'MecBioLab','MecBioSuite','RemodelingECM','SuiteApp','AppMain'};
        for gg = 1:numel(prefGroups)
            for ii = 1:numel(candidateNames)
                try
                    if ispref(prefGroups{gg}, candidateNames{ii})
                        val = getpref(prefGroups{gg}, candidateNames{ii});
                        [outRoot, sourceLabel] = tryPathCandidate(val, ['pref.' prefGroups{gg} '.' candidateNames{ii}]);
                        if ~isempty(outRoot), return; end
                    end
                catch
                end
            end
        end
    end

    function [outPath, sourceLabel] = searchInThing(x, sourcePrefix, candidateNames, depth)
        outPath = '';
        sourceLabel = '';
        if depth > 3 || isempty(x)
            return;
        end

        % Direct path candidate.
        [outPath, sourceLabel] = tryPathCandidate(x, sourcePrefix);
        if ~isempty(outPath), return; end

        % containers.Map support.
        try
            if isa(x, 'containers.Map')
                k = keys(x);
                for ii = 1:numel(candidateNames)
                    hit = find(strcmpi(k, candidateNames{ii}), 1);
                    if ~isempty(hit)
                        [outPath, sourceLabel] = tryPathCandidate(x(k{hit}), [sourcePrefix '.' k{hit}]);
                        if ~isempty(outPath), return; end
                    end
                end
            end
        catch
        end

        % Struct support.
        try
            if isstruct(x)
                f = fieldnames(x);
                for ii = 1:numel(candidateNames)
                    hit = find(strcmpi(f, candidateNames{ii}), 1);
                    if ~isempty(hit)
                        [outPath, sourceLabel] = tryPathCandidate(x.(f{hit}), [sourcePrefix '.' f{hit}]);
                        if ~isempty(outPath), return; end
                    end
                end
                nestedNames = {'UserData','Settings','Config','Paths','State','AppState','Options'};
                for jj = 1:numel(nestedNames)
                    hit = find(strcmpi(f, nestedNames{jj}), 1);
                    if ~isempty(hit)
                        [outPath, sourceLabel] = searchInThing(x.(f{hit}), [sourcePrefix '.' f{hit}], candidateNames, depth+1);
                        if ~isempty(outPath), return; end
                    end
                end
            end
        catch
        end

        % Object/App support.
        try
            if isobject(x)
                p = properties(x);
                for ii = 1:numel(candidateNames)
                    hit = find(strcmpi(p, candidateNames{ii}), 1);
                    if ~isempty(hit)
                        val = x.(p{hit});
                        [outPath, sourceLabel] = tryPathCandidate(val, [sourcePrefix '.' p{hit}]);
                        if ~isempty(outPath), return; end
                    end
                end
                nestedNames = {'UserData','Settings','Config','Paths','State','AppState','Options'};
                for jj = 1:numel(nestedNames)
                    hit = find(strcmpi(p, nestedNames{jj}), 1);
                    if ~isempty(hit)
                        val = x.(p{hit});
                        [outPath, sourceLabel] = searchInThing(val, [sourcePrefix '.' p{hit}], candidateNames, depth+1);
                        if ~isempty(outPath), return; end
                    end
                end
            end
        catch
        end
    end

    function [outPath, sourceLabel] = tryPathCandidate(x, sourceLabelIn)
        outPath = '';
        sourceLabel = '';
        try
            if isempty(x)
                return;
            end
            if isstring(x)
                if numel(x) ~= 1
                    return;
                end
                x = char(x);
            end
            if ~ischar(x)
                return;
            end
            x = strtrim(x);
            if isempty(x)
                return;
            end

            % If someone passes a file path by mistake, use its parent folder.
            [parentDir, ~, ext] = fileparts(x);
            if ~isempty(ext) && exist(x, 'file')
                x = parentDir;
            end

            % Expand relative paths against current folder.
            if ~isfolder(x)
                try
                    mkdir(x);
                catch
                    return;
                end
            end
            if isfolder(x)
                outPath = char(x);
                sourceLabel = sourceLabelIn;
            end
        catch
            outPath = '';
            sourceLabel = '';
        end
    end

    function dirs = createOutputDirs(outDir)
        dirs = struct();
        dirs.rawVsHeat = fullfile(outDir, '01_Raw_vs_Colormap');
        dirs.heatOnly = fullfile(outDir, '02_Heatmap_only');
        dirs.rawOnly = fullfile(outDir, '03_Raw_only');
        dirs.overlay = fullfile(outDir, '04_Overlay');
        dirs.zSummary = fullfile(outDir, '05_Z_Profile_Summary');
        dirs.fig = fullfile(outDir, '06_Editable_FIG_optional');
        dirs.mat = fullfile(outDir, '07_MAT_maps_optional');
        dirs.tables = fullfile(outDir, '08_Tables');
        names = fieldnames(dirs);
        for ii = 1:numel(names)
            if ~exist(dirs.(names{ii}), 'dir'), mkdir(dirs.(names{ii})); end
        end
    end

    function outDir = makeRunFolder(rootDir)
        listing = dir(fullfile(rootDir, 'Run_*'));
        n = 1;
        if ~isempty(listing)
            nums = [];
            for ii = 1:numel(listing)
                tok = regexp(listing(ii).name, 'Run_(\d+)', 'tokens');
                if ~isempty(tok)
                    nums(end+1) = str2double(tok{1}{1}); %#ok<AGROW>
                end
            end
            if ~isempty(nums)
                n = max(nums) + 1;
            end
        end
        outDir = fullfile(rootDir, sprintf('Run_%03d', n));
        mkdir(outDir);
    end

    %% Position processing
    function res = processOnePosition(reader, posIndex, cleanName, param, dirs, progDlg, nSeries)
        w0 = reader.getSizeX();
        h0 = reader.getSizeY();
        nZ = reader.getSizeZ();
        zList = 1:param.zStep:nZ;
        if isempty(zList), zList = 1; end

        scale = 1;
        if param.maxXY > 0 && max(w0, h0) > param.maxXY
            scale = param.maxXY / max(w0, h0);
        end
        outH = max(1, round(h0 * scale));
        outW = max(1, round(w0 * scale));

        bg = estimateBackground(reader, param.ch, zList, scale, param.bgPct);
        logMessage(sprintf('Position %d: background %.4g subtracted; scale %.3f.', posIndex, bg, scale));

        useMedian = strcmp(param.projection, 'Median signal');
        if useMedian
            stack = zeros(outH, outW, numel(zList), 'single');
        else
            accum = zeros(outH, outW, 'single');
        end

        centralRaw = [];
        zMean = zeros(numel(zList), 1);
        zMax = zeros(numel(zList), 1);
        centralZ = zList(round(numel(zList)/2));

        for zi = 1:numel(zList)
            z = zList(zi);
            updateProgress(progDlg, ((posIndex-1) + 0.15 + 0.55*(zi/numel(zList))) / max(nSeries,1), ...
                sprintf('Position %d/%d: reading Z %d/%d...', posIndex, nSeries, z, nZ));
            sl = readPlaneAsDouble(reader, z, param.ch);
            sl = resizeIfNeeded(sl, scale);
            sig = sl - bg;
            sig(sig < 0) = 0;
            if param.denoiseSigma > 0
                sig = smooth2D(sig, param.denoiseSigma);
                sig(sig < 0) = 0;
            end
            sig = single(sig);
            zMean(zi) = mean(sig(:), 'omitnan');
            zMax(zi) = max(sig(:));
            if z == centralZ
                centralRaw = sig;
            end
            if useMedian
                stack(:,:,zi) = sig;
            else
                accum = accum + sig;
            end
        end

        if useMedian
            rawMap = median(stack, 3, 'omitnan');
            clear stack;
        elseif strcmp(param.projection, 'Integrated signal')
            rawMap = accum;
        else
            rawMap = accum ./ max(numel(zList), 1);
        end

        rawMap = double(rawMap);
        if isempty(centralRaw)
            centralRaw = rawMap;
        end
        if param.smoothSigma > 0
            heatMap = smooth2D(rawMap, param.smoothSigma);
        else
            heatMap = rawMap;
        end
        heatMap = double(heatMap);
        heatMap = heatMap - min(heatMap(:), [], 'omitnan');
        heatMap(~isfinite(heatMap)) = 0;
        heatMax = max(heatMap(:));
        if heatMax <= 0 || ~isfinite(heatMax)
            heatMax = eps;
        end

        rawDisplay = rawMap - min(rawMap(:), [], 'omitnan');
        rawDisplay(~isfinite(rawDisplay)) = 0;

        metrics = computeMetrics(heatMap, rawMap, zMean, zMax, w0, h0, nZ, outW, outH, scale, param, posIndex);
        res = struct2table(metrics, 'AsArray', true);

        base = sprintf('%s_Pos%02d', cleanName, posIndex);
        updateProgress(progDlg, ((posIndex-1) + 0.78) / max(nSeries,1), sprintf('Position %d/%d: exporting figures...', posIndex, nSeries));
        exportRawVsHeatmap(rawDisplay, heatMap, heatMax, base, dirs, param, metrics);
        exportHeatmapOnly(heatMap, heatMax, base, dirs, param, metrics);
        exportRawOnly(rawDisplay, base, dirs, param);
        exportOverlay(rawDisplay, heatMap, heatMax, base, dirs, param);
        exportZSummary(centralRaw, heatMap, heatMax, zList, zMean, zMax, base, dirs, param, metrics);

        if param.saveMat
            map_min0 = heatMap; %#ok<NASGU>
            raw_projected = rawMap; %#ok<NASGU>
            z_profile_mean = zMean; %#ok<NASGU>
            z_profile_max = zMax; %#ok<NASGU>
            save(fullfile(dirs.mat, [base '_RawColormapMaps.mat']), ...
                'map_min0', 'raw_projected', 'z_profile_mean', 'z_profile_max', 'param', 'metrics', '-v7.3');
        end
        logMessage(sprintf('Position %d complete | map max %.4g | remodeling contrast %.3f.', ...
            posIndex, metrics.Max_Map_Signal_AU, metrics.ECM_Remodeling_Contrast_Index));
    end

    function bg = estimateBackground(reader, ch, zList, scale, pct)
        vals = [];
        maxVals = 1500000;
        for ii = 1:numel(zList)
            sl = readPlaneAsDouble(reader, zList(ii), ch);
            sl = resizeIfNeeded(sl, scale);
            stride = max(1, ceil(sqrt(numel(sl) / 50000)));
            sample = sl(1:stride:end);
            vals = [vals; sample(:)]; %#ok<AGROW>
            if numel(vals) > maxVals
                vals = vals(1:max(1,floor(numel(vals)/maxVals)):end);
                vals = vals(1:min(numel(vals), maxVals));
            end
        end
        vals = vals(isfinite(vals));
        if isempty(vals)
            bg = 0;
        else
            bg = prctile(double(vals), pct);
        end
    end

    function sl = readPlaneAsDouble(reader, z, ch)
        idx = reader.getIndex(z-1, ch-1, 0) + 1;
        plane = bfGetPlane(reader, idx);
        sl = double(plane);
    end

    function out = resizeIfNeeded(img, scale)
        if abs(scale - 1) < 1e-9
            out = img;
        else
            out = imresize(img, scale, 'bilinear');
        end
    end

    %% Metrics
    function metrics = computeMetrics(map, rawMap, zMean, zMax, w0, h0, nZ, outW, outH, scale, param, posIndex)
        m = map(:);
        m = m(isfinite(m));
        if isempty(m)
            m = 0;
        end
        mapMax = max(m);
        mapMean = mean(m, 'omitnan');
        mapMedian = median(m, 'omitnan');
        mapStd = std(m, 'omitnan');
        p = prctile(m, [1 5 10 25 50 75 90 95 99]);
        top10 = m(m >= prctile(m, 90));
        rest90 = m(m < prctile(m, 90));
        if isempty(top10), top10 = 0; end
        if isempty(rest90), rest90 = 0; end
        top10Mean = mean(top10, 'omitnan');
        rest90Mean = mean(rest90, 'omitnan');
        areaLow10 = mean(m <= 0.10 * mapMax, 'omitnan');
        areaLow25 = mean(m <= 0.25 * mapMax, 'omitnan');
        areaHigh50 = mean(m >= 0.50 * mapMax, 'omitnan');
        areaHigh75 = mean(m >= 0.75 * mapMax, 'omitnan');
        areaHigh90 = mean(m >= 0.90 * mapMax, 'omitnan');
        [gx, gy] = gradient(double(map));
        grad = sqrt(gx.^2 + gy.^2);
        gradVals = grad(:);
        gradMean = mean(gradVals, 'omitnan');
        gradP95 = prctile(gradVals, 95);

        pxArea = appState.pxX * appState.pxY;
        if scale ~= 1
            pxArea = pxArea / (scale^2);
        end

        densityIndex = safeDivide(top10Mean, rest90Mean);
        p95p50 = safeDivide(p(8), p(5));
        depletionIndex = 1 - safeDivide(mean(m(m <= p(3)), 'omitnan'), mapMedian);
        if ~isfinite(depletionIndex), depletionIndex = 0; end
        remodelingContrast = p95p50 * (1 + areaLow25) * (1 + safeDivide(gradMean, mapMean));

        metrics = struct();
        metrics.Position = posIndex;
        metrics.File = string(appState.fileName);
        metrics.Original_Width_px = w0;
        metrics.Original_Height_px = h0;
        metrics.Processed_Width_px = outW;
        metrics.Processed_Height_px = outH;
        metrics.Z_Planes = nZ;
        metrics.Z_Step = param.zStep;
        metrics.Scale_Whole_Field = scale;
        metrics.ECM_Channel = param.ch;
        metrics.Projection = string(param.projection);
        metrics.Background_Subtracted_Pct = param.bgPct;
        metrics.Denoise_Sigma_px = param.denoiseSigma;
        metrics.Final_Smooth_Sigma_px = param.smoothSigma;
        metrics.Pixel_Size_X_um = appState.pxX;
        metrics.Pixel_Size_Y_um = appState.pxY;
        metrics.Pixel_Size_Z_um = appState.pxZ;
        metrics.Mean_Map_Signal_AU = mapMean;
        metrics.Median_Map_Signal_AU = mapMedian;
        metrics.Max_Map_Signal_AU = mapMax;
        metrics.Std_Map_Signal_AU = mapStd;
        metrics.CV_Map_Signal = safeDivide(mapStd, mapMean);
        metrics.P01_Map_Signal_AU = p(1);
        metrics.P05_Map_Signal_AU = p(2);
        metrics.P10_Map_Signal_AU = p(3);
        metrics.P25_Map_Signal_AU = p(4);
        metrics.P50_Map_Signal_AU = p(5);
        metrics.P75_Map_Signal_AU = p(6);
        metrics.P90_Map_Signal_AU = p(7);
        metrics.P95_Map_Signal_AU = p(8);
        metrics.P99_Map_Signal_AU = p(9);
        metrics.IQR_P75_minus_P25_AU = p(6) - p(4);
        metrics.P95_to_P50 = p95p50;
        metrics.Gini_Density = giniCoefficient(m);
        metrics.Densification_Index_Top10_vs_Rest = densityIndex;
        metrics.Top10_Mean_Signal_AU = top10Mean;
        metrics.Rest90_Mean_Signal_AU = rest90Mean;
        metrics.Low_Density_Area_Fraction_0p10Max = areaLow10;
        metrics.Low_Density_Area_Fraction_0p25Max = areaLow25;
        metrics.High_Density_Area_Fraction_0p50Max = areaHigh50;
        metrics.High_Density_Area_Fraction_0p75Max = areaHigh75;
        metrics.High_Density_Area_Fraction_0p90Max = areaHigh90;
        metrics.Matrix_Continuity_Fraction_Above_0p25Max = 1 - areaLow25;
        metrics.Depletion_Index_Low10_vs_Median = depletionIndex;
        metrics.Gradient_Mean_AU_per_px = gradMean;
        metrics.Gradient_P95_AU_per_px = gradP95;
        metrics.Integrated_ECM_Signal_AU_px = sum(m, 'omitnan');
        metrics.Integrated_ECM_Signal_AU_um2 = sum(m, 'omitnan') * pxArea;
        metrics.Z_Profile_Mean_CV = safeDivide(std(zMean, 'omitnan'), mean(zMean, 'omitnan'));
        metrics.Z_Profile_Max_CV = safeDivide(std(zMax, 'omitnan'), mean(zMax, 'omitnan'));
        metrics.ECM_Remodeling_Contrast_Index = remodelingContrast;
    end

    %% Export figures
    function exportRawVsHeatmap(rawMap, heatMap, heatMax, base, dirs, param, metrics)
        f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1800 800]);
        tl = tiledlayout(f, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
        title(tl, sprintf('ECM raw signal and min-zero colormap - %s', base), 'Interpreter', 'none', 'FontWeight', 'bold');
        ax1 = nexttile(tl);
        showRaw(ax1, rawMap, param);
        title(ax1, 'Raw ECM signal projection');
        ax2 = nexttile(tl);
        showHeat(ax2, heatMap, heatMax, param);
        title(ax2, sprintf('Colormap: min = 0, max = %.4g AU', metrics.Max_Map_Signal_AU));
        safeExportFigure(f, fullfile(dirs.rawVsHeat, [base '_Raw_vs_Colormap.png']));
        if param.saveFig
            safeSaveFig(f, fullfile(dirs.fig, [base '_Raw_vs_Colormap.fig']));
        end
        close(f);
    end

    function exportHeatmapOnly(heatMap, heatMax, base, dirs, param, metrics)
        f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 850]);
        ax = axes(f);
        showHeat(ax, heatMap, heatMax, param);
        title(ax, sprintf('%s | min = 0 | max = %.4g AU', base, metrics.Max_Map_Signal_AU), 'Interpreter', 'none');
        safeExportFigure(f, fullfile(dirs.heatOnly, [base '_Heatmap_Min0_TrueMax.png']));
        close(f);
    end

    function exportRawOnly(rawMap, base, dirs, param)
        f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 850]);
        ax = axes(f);
        showRaw(ax, rawMap, param);
        title(ax, [base ' | raw ECM signal projection'], 'Interpreter', 'none');
        safeExportFigure(f, fullfile(dirs.rawOnly, [base '_RawProjection.png']));
        close(f);
    end

    function exportOverlay(rawMap, heatMap, heatMax, base, dirs, param)
        f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 850]);
        ax = axes(f);
        raw01 = normalizeDisplay(rawMap, param.rawLowPct, param.rawHighPct);
        imshow(raw01, 'Parent', ax); hold(ax, 'on');
        hm01 = heatMap ./ max(heatMax, eps);
        rgb = ind2rgb(gray2ind(mat2gray(hm01), 256), feval(param.cmap, 256));
        h = imshow(rgb, 'Parent', ax);
        set(h, 'AlphaData', 0.50 * mat2gray(hm01));
        axis(ax, 'image'); axis(ax, 'off');
        title(ax, [base ' | raw + colormap overlay'], 'Interpreter', 'none');
        safeExportFigure(f, fullfile(dirs.overlay, [base '_Overlay.png']));
        close(f);
    end

    function exportZSummary(centralRaw, heatMap, heatMax, zList, zMean, zMax, base, dirs, param, metrics)
        f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1600 900]);
        tl = tiledlayout(f, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
        title(tl, sprintf('Continuous ECM signal depth summary - %s', base), 'Interpreter', 'none', 'FontWeight', 'bold');
        ax1 = nexttile(tl);
        showRaw(ax1, centralRaw, param);
        title(ax1, 'Central Z raw ECM signal');
        ax2 = nexttile(tl);
        showHeat(ax2, heatMap, heatMax, param);
        title(ax2, sprintf('Projected colormap | max %.4g AU', metrics.Max_Map_Signal_AU));
        ax3 = nexttile(tl);
        plot(ax3, zList, zMean, '-o', 'LineWidth', 1);
        grid(ax3, 'on'); xlabel(ax3, 'Z plane'); ylabel(ax3, 'Mean signal above background');
        title(ax3, 'Mean signal by Z');
        ax4 = nexttile(tl);
        plot(ax4, zList, zMax, '-o', 'LineWidth', 1);
        grid(ax4, 'on'); xlabel(ax4, 'Z plane'); ylabel(ax4, 'Max signal above background');
        title(ax4, 'Max signal by Z');
        safeExportFigure(f, fullfile(dirs.zSummary, [base '_Z_Profile_Summary.png']));
        close(f);
    end

    function showRaw(ax, rawMap, param)
        imagesc(ax, rawMap);
        axis(ax, 'image'); axis(ax, 'off');
        colormap(ax, gray(256));
        vals = rawMap(:); vals = vals(isfinite(vals));
        if isempty(vals)
            caxis(ax, [0 1]);
        else
            lo = prctile(vals, param.rawLowPct);
            hi = prctile(vals, param.rawHighPct);
            if hi <= lo, hi = max(vals); lo = min(vals); end
            if hi <= lo, hi = lo + eps; end
            caxis(ax, [lo hi]);
        end
        cb = colorbar(ax);
        cb.Label.String = 'Raw projected ECM signal (AU)';
    end

    function showHeat(ax, heatMap, heatMax, param)
        imagesc(ax, heatMap);
        axis(ax, 'image'); axis(ax, 'off');
        colormap(ax, feval(param.cmap, 256));
        caxis(ax, [0 heatMax]);
        cb = colorbar(ax);
        cb.Label.String = 'ECM signal map (AU, min shifted to 0)';
    end

    function updateLivePreview(res)
        try
            cla(ax_preview);
            bar(ax_preview, categorical({'Mean','Median','Max','P95/P50','Top10/Rest'}), ...
                [res.Mean_Map_Signal_AU, res.Median_Map_Signal_AU, res.Max_Map_Signal_AU, res.P95_to_P50, res.Densification_Index_Top10_vs_Rest]);
            title(ax_preview, sprintf('Position %d metrics preview', res.Position));
            grid(ax_preview, 'on');
        catch
        end
    end

    %% Tables
    function saveResultTables(dirs)
        if isempty(appState.results) || height(appState.results) == 0
            return;
        end
        excelFile = fullfile(dirs.tables, 'ECM_RawColormap_Metrics.xlsx');
        csvFile = fullfile(dirs.tables, 'ECM_RawColormap_Metrics.csv');
        try
            writetable(appState.results, excelFile, 'Sheet', 'Metrics');
            if ~isempty(appState.errors) && height(appState.errors) > 0
                writetable(appState.errors, excelFile, 'Sheet', 'Errors');
            end
        catch ME
            logMessage(['Excel write failed, writing CSV only: ' ME.message]);
        end
        try
            writetable(appState.results, csvFile);
            if ~isempty(appState.errors) && height(appState.errors) > 0
                writetable(appState.errors, fullfile(dirs.tables, 'ECM_RawColormap_Errors.csv'));
            end
        catch ME
            logMessage(['CSV write failed: ' ME.message]);
        end
    end

    %% Utility functions
    function updateProgress(d, value, msg)
        try
            if ~isempty(d) && isvalid(d)
                d.Value = min(max(value, 0), 1);
                d.Message = msg;
            end
            drawnow limitrate;
        catch
        end
    end

    function px = getPhysicalPixel(meta, series0, dim)
        px = 1;
        try
            switch upper(dim)
                case 'X'
                    obj = meta.getPixelsPhysicalSizeX(series0);
                case 'Y'
                    obj = meta.getPixelsPhysicalSizeY(series0);
                case 'Z'
                    obj = meta.getPixelsPhysicalSizeZ(series0);
                otherwise
                    obj = [];
            end
            if ~isempty(obj)
                px = double(obj.value());
                if isempty(px) || isnan(px) || px <= 0
                    px = 1;
                end
            end
        catch
            px = 1;
        end
    end

    function y = safeDivide(a, b)
        if isempty(b) || ~isfinite(b) || abs(b) < eps
            y = NaN;
        else
            y = a ./ b;
        end
    end

    function g = giniCoefficient(x)
        x = x(:);
        x = x(isfinite(x));
        x = x - min(x);
        if isempty(x) || sum(x) <= 0
            g = 0;
            return;
        end
        x = sort(x);
        n = numel(x);
        g = (2 * sum((1:n)' .* x) / (n * sum(x))) - (n + 1) / n;
    end

    function out = smooth2D(img, sigma)
        if sigma <= 0
            out = img;
            return;
        end
        try
            out = imgaussfilt(img, sigma, 'Padding', 'replicate');
        catch
            k = gaussianKernel2D(sigma);
            out = conv2(double(img), k, 'same');
        end
    end

    function k = gaussianKernel2D(sigma)
        rad = max(1, ceil(3 * sigma));
        [x, y] = meshgrid(-rad:rad, -rad:rad);
        k = exp(-(x.^2 + y.^2) ./ (2 * sigma^2));
        k = k ./ sum(k(:));
    end

    function img01 = normalizeDisplay(img, lowPct, highPct)
        vals = img(:);
        vals = vals(isfinite(vals));
        if isempty(vals)
            img01 = zeros(size(img));
            return;
        end
        lo = prctile(vals, lowPct);
        hi = prctile(vals, highPct);
        if hi <= lo
            lo = min(vals); hi = max(vals);
        end
        if hi <= lo
            img01 = zeros(size(img));
        else
            img01 = (double(img) - lo) ./ (hi - lo);
            img01 = min(max(img01, 0), 1);
        end
    end

    function safeExportFigure(f, outPath)
        [folder, name, ext] = fileparts(outPath);
        if ~exist(folder, 'dir'), mkdir(folder); end
        tmp = fullfile(tempdir, [name '_' char(java.util.UUID.randomUUID) ext]);
        try
            exportgraphics(f, tmp, 'Resolution', 220);
        catch
            try
                print(f, tmp, '-dpng', '-r220');
            catch ME
                logMessage(['Figure export failed: ' ME.message]);
                return;
            end
        end
        try
            movefile(tmp, outPath, 'f');
        catch
            copyfile(tmp, outPath, 'f');
            try, delete(tmp); catch, end
        end
    end

    function safeSaveFig(f, outPath)
        [folder, name, ext] = fileparts(outPath);
        if ~exist(folder, 'dir'), mkdir(folder); end
        tmp = fullfile(tempdir, [name '_' char(java.util.UUID.randomUUID) ext]);
        try
            savefig(f, tmp);
            movefile(tmp, outPath, 'f');
        catch ME
            logMessage(['Editable .fig save failed, PNGs are unaffected: ' ME.message]);
            try, delete(tmp); catch, end
        end
    end

    function clean = cleanFileName(name)
        clean = regexprep(name, '[^a-zA-Z0-9_\-]', '_');
        clean = regexprep(clean, '_+', '_');
    end
end
