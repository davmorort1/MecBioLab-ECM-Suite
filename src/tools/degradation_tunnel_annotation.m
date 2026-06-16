function degradation_tunnel_annotation(fig_launcher)
% SAM2-ASSISTED ECM DEGRADATION/TUNNEL ANNOTATION
% Single-file annotation tool for the suite.
%
% Intended workflow:
%   1) Load the .lif once from the suite.
%   2) Open a fast CVAT-like plane-by-plane annotation workspace.
%   3) Left click = SAM2 selects/adds the degradation/tunnel at that point.
%   4) Right click = isolate/replace the selected degradation; if clicked on an
%      existing red mask it isolates that connected component without calling SAM.
%   5) Accept plane / No tunnel -> saves image, degradation mask, cell mask,
%      multiclass mask and metrics. Then it advances to the next Z plane.
%
% SAM2 is still required, but the click path is optimized: the Python model is
% loaded once and kept alive through MATLAB's persistent Python runtime. The
% annotation tool no longer launches a new Python process for every click.

    %% STATE
    app = struct();
    app.moduleDir = fileparts(mfilename('fullpath'));
    app.fileLIFs = discoverLauncherLIFs(fig_launcher);
    app.basePath = '';
    app.globalOutDir = discoverGlobalOutputDir(fig_launcher);
    app.outDir = '';
    app.seriesCounts = [];
    app.seriesNames = {};
    app.results = table();
    % One interactive session should keep all analysed positions of the same
    % file inside the same run folder. The run root is created lazily when the
    % first position is started.
    app.sessionRunDir = '';
    app.sessionRunStamp = datestr(now,'yyyymmdd_HHMMSS');
    app.fileRunDirs = containers.Map('KeyType','char','ValueType','char');

    SAM = loadSamPrefs(app.moduleDir);
    SAM.fastBridge = ensureFastSamBridge();
    SAM.validated = false;

    %% UI
    fig = uifigure('Name','SAM2-assisted Degradation/Tunnel Annotator','Color','k');
    fig.WindowState = 'maximized';
    fig.CloseRequestFcn = @closeModule;

    scrMain = get(groot,'ScreenSize');
    mainLeftWidth = min(340,max(270,round(scrMain(3)*0.24)));
    root = uigridlayout(fig,[1 2]);
    root.ColumnWidth = {mainLeftWidth,'1x'};
    root.BackgroundColor = 'k';

    pnl = uipanel(root,'Title','Annotation controls','BackgroundColor',[0.10 0.10 0.10],'ForegroundColor','w');
    makePanelScrollable(pnl);
    gl = uigridlayout(pnl,[19 2]);
    gl.ColumnWidth = {'1x','1x'};
    gl.RowHeight = {30,24,30,24,30,30,30,30,30,30,30,30,24,30,30,'1x',30,30,30};
    gl.BackgroundColor = [0.10 0.10 0.10];

    lblInput = uilabel(gl,'Text','Input .LIF','FontColor',[0.55 1 1],'FontWeight','bold'); lblInput.Layout.Column = [1 2];
    btnLoad = uibutton(gl,'Text','Load .LIF file(s)','BackgroundColor',[0.20 0.38 0.62],'FontColor','w','FontWeight','bold','ButtonPushedFcn',@loadFiles);
    btnRefresh = uibutton(gl,'Text','Refresh loaded info','BackgroundColor',[0.22 0.22 0.22],'FontColor','w','ButtonPushedFcn',@refreshInputInfo);
    lblFiles = uilabel(gl,'Text','No files loaded.','FontColor',[0.78 0.78 0.78],'WordWrap','on'); lblFiles.Layout.Column = [1 2];

    uilabel(gl,'Text','File:','FontColor','w');
    ddFile = uidropdown(gl,'Items',{'No file'},'Value','No file','ValueChangedFcn',@fileSelectionChanged);
    uilabel(gl,'Text','Position / series:','FontColor','w');
    ddSeries = uidropdown(gl,'Items',{'1'},'Value','1');
    uilabel(gl,'Text','Degradation/fiber channel:','FontColor','w');
    ddDegCh = uidropdown(gl,'Items',{'1','2','3','4'},'Value','1');
    uilabel(gl,'Text','Cell channel:','FontColor','w');
    ddCellCh = uidropdown(gl,'Items',{'None','1','2','3','4'},'Value','2');
    uilabel(gl,'Text','Min cell volume (\mum^3):','FontColor','w');
    edMinCellVol = uieditfield(gl,'numeric','Value',500,'Limits',[1 100000]);
    uilabel(gl,'Text','Max SAM mask % plane:','FontColor','w');
    edMaxMaskFrac = uieditfield(gl,'numeric','Value',0.18,'Limits',[0.005 1]);
    uilabel(gl,'Text','Min tunnel area px:','FontColor','w');
    edMinArea = uieditfield(gl,'numeric','Value',25,'Limits',[1 100000]);
    cbFilter = uicheckbox(gl,'Text','reject huge/bright SAM blobs','FontColor','w','Value',true); cbFilter.Layout.Column=[1 2];

    lblRuntime = uilabel(gl,'Text','SAM2 runtime','FontColor',[1 0.75 0.25],'FontWeight','bold'); lblRuntime.Layout.Column = [1 2];
    btnValidate = uibutton(gl,'Text','Validate/load SAM2 once','BackgroundColor',[0.55 0.30 0.05],'FontColor','w','FontWeight','bold','ButtonPushedFcn',@validateSamButton);
    btnSettings = uibutton(gl,'Text','SAM2 settings','BackgroundColor',[0.25 0.25 0.25],'FontColor','w','ButtonPushedFcn',@samSettingsDialog);
    btnStudio = uibutton(gl,'Text','Start annotation workspace','BackgroundColor',[0.05 0.45 0.45],'FontColor','w','FontWeight','bold','ButtonPushedFcn',@startAnnotationWorkspace); btnStudio.Layout.Column=[1 2];
    btnHelp = uibutton(gl,'Text','Workflow / shortcuts','BackgroundColor',[0.25 0.25 0.25],'FontColor','y','ButtonPushedFcn',@showHelp); btnHelp.Layout.Column=[1 2];

    txtLog = uitextarea(gl,'Editable','off','BackgroundColor','k','FontColor',[0.2 1 0.2],'FontName','Consolas');
    txtLog.Layout.Column = [1 2];
    txtLog.Value = {'[SAM2 annotation] Degradation/tunnel annotator ready.', ...
                    'Load the .lif once. Start annotation. Left click adds; right click isolates/replaces.', ...
                    'Accept / No tunnel saves image + masks + metrics and advances to the next Z plane.'};

    btnOpenOut = uibutton(gl,'Text','Open output folder','BackgroundColor',[0.25 0.25 0.25],'FontColor','w','ButtonPushedFcn',@openOutputFolder);
    btnBack = uibutton(gl,'Text','< Back','BackgroundColor',[0.40 0.10 0.10],'FontColor','w','ButtonPushedFcn',@(s,e)close(fig));

    tabs = uitabgroup(root);
    tabReg = uitab(tabs,'Title','Saved plane metrics','BackgroundColor','k');
    gReg = uigridlayout(tabReg,[1 1]);
    uit = uitable(gReg,'Data',table(),'BackgroundColor',[0.92 0.92 0.92]);
    tabGuide = uitab(tabs,'Title','Workflow','BackgroundColor','k');
    gGuide = uigridlayout(tabGuide,[1 1]);
    guideText = uitextarea(gGuide,'Editable','off','BackgroundColor','k','FontColor','w','FontName','Consolas');
    guideText.Value = workflowText();

    refreshInputInfo();

    %% UI CALLBACKS
    function logMsg(msg)
        txtLog.Value = [txtLog.Value; {char(msg)}];
        scroll(txtLog,'bottom');
        drawnow limitrate;
    end

    function closeModule(~,~)
        try delete(fig); catch, end
        if exist('fig_launcher','var') && isvalid(fig_launcher)
            fig_launcher.Visible = 'on';
        end
    end

    function loadFiles(~,~)
        if exist('bfGetReader','file') == 0
            uialert(fig,'Bio-Formats is missing from the MATLAB path.','Missing dependency');
            return;
        end
        [files,path] = uigetfile('*.lif','Select .LIF file(s)','MultiSelect','on');
        if isequal(files,0), return; end
        if ischar(files), files = {files}; end
        app.fileLIFs = fullfile(path,files);
        app.basePath = path;
        refreshInputInfo();
        logMsg(sprintf('Loaded %d .LIF file(s).',numel(app.fileLIFs)));
    end

    function refreshInputInfo(varargin)
        if isempty(app.fileLIFs)
            ddFile.Items = {'No file'}; ddFile.Value = 'No file';
            ddSeries.Items = {'1'}; ddSeries.Value = '1';
            lblFiles.Text = 'No files loaded.';
            return;
        end
        names = cellfun(@getFileName,app.fileLIFs,'UniformOutput',false);
        ddFile.Items = names;
        if ~ismember(ddFile.Value,names), ddFile.Value = names{1}; end
        lblFiles.Text = sprintf('%d file(s) loaded. Current: %s',numel(app.fileLIFs),ddFile.Value);
        fileSelectionChanged();
    end

    function fileSelectionChanged(varargin)
        if isempty(app.fileLIFs) || strcmp(ddFile.Value,'No file'), return; end
        idx = find(strcmp(cellfun(@getFileName,app.fileLIFs,'UniformOutput',false),ddFile.Value),1,'first');
        if isempty(idx), idx = 1; end
        lif = app.fileLIFs{idx};
        nSeries = 1;
        try
            r = bfGetReader(lif); nSeries = r.getSeriesCount(); r.close();
        catch ME
            logMsg(['Could not read series count: ' ME.message]);
        end
        items = arrayfun(@(k)sprintf('%d',k),1:nSeries,'UniformOutput',false);
        ddSeries.Items = items;
        if ~ismember(ddSeries.Value,items), ddSeries.Value = items{1}; end
    end

    function validateSamButton(~,~)
        try
            SAM = loadSamPrefs(app.moduleDir);
            SAM.fastBridge = ensureFastSamBridge();
            validateFastSamRuntime(SAM);
            SAM.validated = true;
            saveSamPrefs(SAM,app.moduleDir);
            logMsg('SAM2 loaded and validated. First load may take time; clicks should now be faster.');
            uialert(fig,'SAM2 model is loaded in the persistent Python runtime.','SAM2 ready','Icon','info');
        catch ME
            SAM.validated = false;
            logMsg(['SAM2 validation failed: ' ME.message]);
            uialert(fig,ME.message,'SAM2 validation failed');
        end
    end

    function samSettingsDialog(~,~)
        SAM = loadSamPrefs(app.moduleDir);
        defaults = {SAM.pythonExe,SAM.repoRoot,SAM.checkpoint,SAM.config};
        answer = inputdlg({'Python executable:', 'SAM2 repository root:', 'SAM2 checkpoint .pt:', 'SAM2 config yaml:'}, ...
                          'SAM2 settings',[1 105],defaults);
        if isempty(answer), return; end
        SAM.pythonExe = strtrim(answer{1});
        SAM.repoRoot = strtrim(answer{2});
        SAM.checkpoint = strtrim(answer{3});
        SAM.config = strtrim(answer{4});
        SAM.fastBridge = ensureFastSamBridge();
        saveSamPrefs(SAM,app.moduleDir);
        logMsg('SAM2 settings saved. Press Validate/load SAM2 once.');
    end

    function startAnnotationWorkspace(~,~)
        if isempty(app.fileLIFs)
            uialert(fig,'Load a .lif file first. The workspace will reuse that file; it will not ask again.','No input');
            return;
        end
        try
            SAM = loadSamPrefs(app.moduleDir);
            SAM.fastBridge = ensureFastSamBridge();
            if ~SAM.validated
                logMsg('Loading SAM2 model once. This can take time on the first call...');
                validateFastSamRuntime(SAM);
                SAM.validated = true;
            end
        catch ME
            uialert(fig,ME.message,'SAM2 required'); logMsg(['SAM2 ERROR: ' ME.message]); return;
        end

        idx = find(strcmp(cellfun(@getFileName,app.fileLIFs,'UniformOutput',false),ddFile.Value),1,'first');
        if isempty(idx), idx = 1; end
        lif = app.fileLIFs{idx};
        seriesIdx = max(1,round(str2double(ddSeries.Value)));
        degCh = max(1,round(str2double(ddDegCh.Value)));
        if strcmp(ddCellCh.Value,'None'), cellCh = NaN; else, cellCh = max(1,round(str2double(ddCellCh.Value))); end
        p = struct('maxMaskFraction',edMaxMaskFrac.Value, ...
                   'minArea',round(edMinArea.Value), ...
                   'filterSAM',cbFilter.Value, ...
                   'minCellVolUm3',edMinCellVol.Value, ...
                   'cellDownsampleFactor',2);
        fileRunDir = getOrCreateFileRunDir(lif);
        preload = struct('lif',lif,'series',seriesIdx,'degCh',degCh,'cellCh',cellCh, ...
                         'outputRoot',app.globalOutDir,'fileRunDir',fileRunDir, ...
                         'sessionRunDir',app.sessionRunDir,'params',p);
        try
            [resultTable,nextRequested] = degradation_annotation_workspace(SAM,preload,fig,@logMsg);
            if ~isempty(resultTable)
                app.results = mergePlaneTables(app.results,resultTable);
                uit.Data = app.results;
                logMsg(sprintf('Workspace returned %d saved plane rows. Session registry now has %d rows.',height(resultTable),height(app.results)));
            end
            if nextRequested
                if advanceToNextPositionSelection()
                    logMsg('Advanced to next position. Starting annotation workspace directly...');
                    drawnow;
                    startAnnotationWorkspace([],[]);
                else
                    logMsg('No next position/file available. Current position is finished.');
                    uialert(fig,'No hay siguiente posición disponible en los .LIF cargados.','Fin del archivo','Icon','info');
                end
            end
        catch ME
            uialert(fig,ME.message,'Annotation workspace failed'); logMsg(['Workspace ERROR: ' ME.message]);
        end
    end

    function ok = advanceToNextPositionSelection()
        ok = false;
        try
            seriesItems = ddSeries.Items;
            curSeries = find(strcmp(seriesItems,ddSeries.Value),1,'first');
            if isempty(curSeries), curSeries = 1; end
            if curSeries < numel(seriesItems)
                ddSeries.Value = seriesItems{curSeries+1};
                ok = true;
                return;
            end
            fileItems = ddFile.Items;
            curFile = find(strcmp(fileItems,ddFile.Value),1,'first');
            if isempty(curFile), curFile = 1; end
            if curFile < numel(fileItems)
                ddFile.Value = fileItems{curFile+1};
                fileSelectionChanged();
                if ~isempty(ddSeries.Items), ddSeries.Value = ddSeries.Items{1}; end
                ok = true;
            end
        catch ME
            logMsg(['Could not advance to next position: ' ME.message]);
            ok = false;
        end
    end

    function fileRunDir = getOrCreateFileRunDir(lifPath)
        % All positions analysed during this MATLAB annotation session are grouped
        % under a single Run_YYYYMMDD_HHMMSS folder, with one subfolder per LIF.
        % This avoids the previous behaviour where each position silently created
        % a separate Run_### directory.
        lifKey = char(lifPath);
        if isKey(app.fileRunDirs,lifKey)
            fileRunDir = app.fileRunDirs(lifKey);
            app.outDir = app.sessionRunDir;
            return;
        end
        rootOut = app.globalOutDir;
        if isempty(rootOut) || ~exist(rootOut,'dir')
            rootOut = fileparts(lifPath);
        end
        if isempty(rootOut) || ~exist(rootOut,'dir')
            rootOut = app.moduleDir;
        end
        modDir = fullfile(rootOut,'Degradation_Tunnel_Annotation');
        mkdirIfNeeded(modDir);
        if isempty(app.sessionRunDir)
            candidate = fullfile(modDir,['Run_' app.sessionRunStamp]);
            if exist(candidate,'dir')
                suffix = 2;
                while exist(sprintf('%s_%02d',candidate,suffix),'dir')
                    suffix = suffix + 1;
                end
                candidate = sprintf('%s_%02d',candidate,suffix);
            end
            app.sessionRunDir = candidate;
            mkdirIfNeeded(app.sessionRunDir);
            app.outDir = app.sessionRunDir;
            logMsg(['Created annotation session run: ' app.sessionRunDir]);
        end
        fileName = safeName(eraseExt(getFileName(lifPath)));
        fileRunDir = fullfile(app.sessionRunDir,fileName);
        mkdirIfNeeded(fileRunDir);
        mkdirIfNeeded(fullfile(fileRunDir,'aggregate_metrics'));
        app.fileRunDirs(lifKey) = fileRunDir;
        logMsg(['File run folder: ' fileRunDir]);
    end

    function showHelp(~,~)
        uialert(fig,sprintf('%s\n',workflowText()),'Annotation workflow','Icon','info');
    end

    function openOutputFolder(~,~)
        out = app.outDir;
        if isempty(out) && ~isempty(app.sessionRunDir)
            out = app.sessionRunDir;
        end
        if isempty(out)
            cfg = loadSamPrefs(app.moduleDir); %#ok<NASGU>
            rootOut = app.globalOutDir;
            if isempty(rootOut), rootOut = app.basePath; end
            if isempty(rootOut), rootOut = app.moduleDir; end
            out = fullfile(rootOut,'Degradation_Tunnel_Annotation');
        end
        if ~exist(out,'dir')
            uialert(fig,'No output folder exists yet. Accept or skip at least one plane first.','No output'); return;
        end
        if ispc, winopen(out); elseif ismac, system(sprintf('open %s',shellQuote(out))); else, system(sprintf('xdg-open %s',shellQuote(out))); end
    end
end

function makePanelScrollable(pnl)
    % Keeps all controls reachable on laptop screens. Older MATLAB releases may
    % not expose the Scrollable property, so fail silently.
    try
        pnl.Scrollable = 'on';
    catch
    end
end

function val = getParamField(S,fieldName,defaultVal)
    if isstruct(S) && isfield(S,fieldName) && ~isempty(S.(fieldName))
        val = S.(fieldName);
    else
        val = defaultVal;
    end
end

%% ========================================================================
%  MANUAL CVAT-LIKE WORKSPACE
%  ========================================================================
function [resultTable,nextPositionRequested] = degradation_annotation_workspace(SAM,preload,parentFig,parentLogger)
    W = struct();
    W.lif = preload.lif;
    W.series = preload.series;
    W.degCh = preload.degCh;
    W.cellCh = preload.cellCh;
    W.params = preload.params;
    W.outputRoot = preload.outputRoot;
    W.fileRunDir = '';
    W.sessionRunDir = '';
    if isfield(preload,'fileRunDir'), W.fileRunDir = preload.fileRunDir; end
    if isfield(preload,'sessionRunDir'), W.sessionRunDir = preload.sessionRunDir; end
    W.stackDeg = [];
    W.stackCell = [];
    W.cellMask = [];
    W.cellObjects2D = [];
    W.cellArea2D = [];
    W.cellEdge = [];
    W.degMask = [];
    W.z = 1;
    W.nZ = 1;
    % Short identifier for non-image outputs. Avoids path-length/Excel issues.
    W.fileBase = safeName(sprintf('pos%d',W.series));
    % Full identifier for image/mask filenames. These are useful for dataset
    % traceability and do not cause workbook/sheet-name limitations.
    W.imageBase = safeName(sprintf('%s_pos_%d',eraseExt(getFileName(W.lif)),W.series));
    W.px = struct('x',1,'y',1,'z',1);
    W.saved = false(1,1);
    W.noTunnel = false(1,1);
    W.planeStatus = strings(1,1);
    W.planeRows = table();
    W.outDir = '';
    W.opacity = 0.45;
    W.undoMask = [];
    W.busy = false;
    W.lastSamTime = NaN;
    W.nextPositionRequested = false;
    W.minCellVolUm3 = getParamField(W.params,'minCellVolUm3',500);
    W.cellDownsampleFactor = getParamField(W.params,'cellDownsampleFactor',2);


    log('Reading selected .lif series once into memory...');
    [W.stackDeg,W.stackCell,W.px] = readSelectedLifStacks(W.lif,W.series,W.degCh,W.cellCh);
    W.nZ = size(W.stackDeg,3);
    W.degMask = false(size(W.stackDeg));
    W.cellMask = segmentCellStack(W.stackCell,W.px,W.minCellVolUm3,W.cellDownsampleFactor);
    W.cellEdge = precomputeCellEdges(W.cellMask);
    [W.cellObjects2D,W.cellArea2D] = precomputeCellPlaneStats(W.cellMask);
    if isnan(W.cellCh)
        log('Cell channel disabled; cell masks will be empty.');
    else
        log(sprintf('Cell mask computed from CELL channel %d using 3D Otsu + volume filtering: %d 3D cell object(s), %d total voxels.',W.cellCh,countTrackedObjects3D(W.cellMask),nnz(W.cellMask)));
    end
    W.saved = false(1,W.nZ);
    W.noTunnel = false(1,W.nZ);
    W.planeStatus = repmat("unreviewed",1,W.nZ);

    resultTable = table();
    nextPositionRequested = false;

    fig = uifigure('Name',sprintf('SAM2 Degradation Annotation | %s',W.fileBase),'Color','k');
    fig.WindowState = 'maximized';
    fig.CloseRequestFcn = @onClose;
    fig.WindowKeyPressFcn = @onKey;

    scr = get(groot,'ScreenSize');
    leftWidth = min(330,max(270,round(scr(3)*0.24)));
    root = uigridlayout(fig,[1 2]); root.ColumnWidth={leftWidth,'1x'}; root.BackgroundColor='k';
    pnl = uipanel(root,'Title','Fast plane workflow','BackgroundColor',[0.1 0.1 0.1],'ForegroundColor','w');

    % Laptop-safe layout: controls are split across tabs instead of one tall
    % column. This prevents the lower buttons from being clipped on small screens.
    ctrlTabs = uitabgroup(pnl,'Units','normalized','Position',[0 0 1 1]);
    tabMain   = uitab(ctrlTabs,'Title','Plane','BackgroundColor',[0.1 0.1 0.1]);
    tabTools  = uitab(ctrlTabs,'Title','Tools','BackgroundColor',[0.1 0.1 0.1]);
    tabExport = uitab(ctrlTabs,'Title','Export','BackgroundColor',[0.1 0.1 0.1]);
    tabLog    = uitab(ctrlTabs,'Title','Log','BackgroundColor','k');
    tabTable  = uitab(ctrlTabs,'Title','Metrics','BackgroundColor','k');

    gl = uigridlayout(tabMain,[14 2]);
    gl.ColumnWidth = {'1x','1x'};
    gl.RowHeight = {34,26,30,30,30,30,30,30,24,30,30,30,'1x',6};
    gl.Padding = [6 6 6 6];
    gl.RowSpacing = 4;
    gl.BackgroundColor = [0.1 0.1 0.1];

    lblTitle = uilabel(gl,'Text',sprintf('%s | position %d | Z=%d',getFileName(W.lif),W.series,W.nZ),'FontColor',[0.55 1 1],'FontWeight','bold','WordWrap','on'); lblTitle.Layout.Column=[1 2];
    lblZ = uilabel(gl,'Text','','FontColor','w','FontWeight','bold'); lblZ.Layout.Column=[1 2];
    btnPrev = uibutton(gl,'Text','← Previous plane','BackgroundColor',[0.22 0.22 0.22],'FontColor','w','ButtonPushedFcn',@(s,e)goPlane(W.z-1));
    btnNext = uibutton(gl,'Text','Next plane →','BackgroundColor',[0.22 0.22 0.22],'FontColor','w','ButtonPushedFcn',@(s,e)goPlane(W.z+1));
    btnAccept = uibutton(gl,'Text','ACCEPT tunnel + next','BackgroundColor',[0.05 0.55 0.20],'FontColor','w','FontWeight','bold','ButtonPushedFcn',@acceptPlaneAndNext); btnAccept.Layout.Column=[1 2];
    btnNoTunnel = uibutton(gl,'Text','NO TUNNEL: save cell + next','BackgroundColor',[0.50 0.25 0.05],'FontColor','w','FontWeight','bold','ButtonPushedFcn',@noTunnelAndNext); btnNoTunnel.Layout.Column=[1 2];
    btnUndo = uibutton(gl,'Text','Undo mask','BackgroundColor',[0.22 0.22 0.22],'FontColor','w','ButtonPushedFcn',@undoMask);
    btnClear = uibutton(gl,'Text','Clear tunnel mask','BackgroundColor',[0.45 0.12 0.12],'FontColor','w','ButtonPushedFcn',@clearMask);
    btnAdd = uibutton(gl,'Text','Brush add','BackgroundColor',[0.10 0.40 0.18],'FontColor','w','ButtonPushedFcn',@brushAdd);
    btnErase = uibutton(gl,'Text','Brush erase','BackgroundColor',[0.40 0.12 0.10],'FontColor','w','ButtonPushedFcn',@brushErase);
    cbShowCell = uicheckbox(gl,'Text','show cell edge','FontColor','w','Value',true);
    cbShowSaved = uicheckbox(gl,'Text','auto-save project','FontColor','w','Value',false);
    uilabel(gl,'Text','Tunnel overlay opacity','FontColor','w');
    slOpacity = uislider(gl,'Limits',[0 1],'Value',W.opacity,'ValueChangedFcn',@changeOpacity);

    glTools = uigridlayout(tabTools,[10 2]);
    glTools.ColumnWidth = {'1x','1x'};
    glTools.RowHeight = {30,58,30,30,30,30,30,30,'1x',6};
    glTools.Padding = [6 6 6 6];
    glTools.RowSpacing = 4;
    glTools.BackgroundColor = [0.1 0.1 0.1];
    lblClickBehavior = uilabel(glTools,'Text','SAM/click behavior','FontColor',[1 0.75 0.2],'FontWeight','bold'); lblClickBehavior.Layout.Column=[1 2];
    lblClick = uilabel(glTools,'Text','Left click: add SAM mask. Right click: isolate existing CC or replace with SAM mask.','FontColor','w','WordWrap','on'); lblClick.Layout.Column=[1 2];
    cbFilter = uicheckbox(glTools,'Text','filter huge/bright SAM blobs','FontColor','w','Value',W.params.filterSAM); cbFilter.Layout.Column=[1 2];
    btnValidate = uibutton(glTools,'Text','Reload/validate SAM2','BackgroundColor',[0.55 0.30 0.05],'FontColor','w','ButtonPushedFcn',@validateAgain); btnValidate.Layout.Column=[1 2];
    btnSetOut = uibutton(glTools,'Text','Choose output folder','BackgroundColor',[0.25 0.25 0.25],'FontColor','w','ButtonPushedFcn',@chooseOutput); btnSetOut.Layout.Column=[1 2];
    btnOpen = uibutton(glTools,'Text','Open output folder','BackgroundColor',[0.25 0.25 0.25],'FontColor','w','ButtonPushedFcn',@openOut); btnOpen.Layout.Column=[1 2];
    btnSave = uibutton(glTools,'Text','Save project now','BackgroundColor',[0.25 0.25 0.25],'FontColor','w','ButtonPushedFcn',@saveProjectNow); btnSave.Layout.Column=[1 2];
    btnClose = uibutton(glTools,'Text','Close workspace','BackgroundColor',[0.40 0.10 0.10],'FontColor','w','ButtonPushedFcn',@(s,e)onClose()); btnClose.Layout.Column=[1 2];

    glExport = uigridlayout(tabExport,[8 1]);
    glExport.RowHeight = {34,42,42,42,42,'1x',24,6};
    glExport.Padding = [6 6 6 6];
    glExport.RowSpacing = 6;
    glExport.BackgroundColor = [0.1 0.1 0.1];
    uilabel(glExport,'Text','Save/export','FontColor',[0.55 1 1],'FontWeight','bold');
    btnExcel = uibutton(glExport,'Text','Finish + Excel + 3D','BackgroundColor',[0.10 0.45 0.55],'FontColor','w','FontWeight','bold','ButtonPushedFcn',@finishAndExport);
    btn3D = uibutton(glExport,'Text','Recreate 3D from masks','BackgroundColor',[0.25 0.25 0.25],'FontColor','w','ButtonPushedFcn',@recreate3DNow);
    btnNextPos = uibutton(glExport,'Text','Finish + 3D + next position','BackgroundColor',[0.10 0.40 0.65],'FontColor','w','FontWeight','bold','ButtonPushedFcn',@finish3DAndNextPosition);
    uilabel(glExport,'Text','Excel failures no longer stop 3D; fallback CSV/XLSX files are created if needed.','FontColor',[0.8 0.8 0.8],'WordWrap','on');

    glLog = uigridlayout(tabLog,[1 1]); glLog.Padding=[4 4 4 4]; glLog.BackgroundColor='k';
    txt = uitextarea(glLog,'Editable','off','BackgroundColor','k','FontColor',[0.2 1 0.2],'FontName','Consolas');
    txt.Value = {'Workspace ready. SAM2 model is kept alive; the first click or first plane may be slower.'};
    glTable = uigridlayout(tabTable,[1 1]); glTable.Padding=[4 4 4 4]; glTable.BackgroundColor='k';
    tbl = uitable(glTable,'Data',table(),'BackgroundColor',[0.92 0.92 0.92]);

    view = uigridlayout(root,[2 1]); view.RowHeight={'1x',44}; view.BackgroundColor='k';
    ax = uiaxes(view,'BackgroundColor','k','XColor','w','YColor','w'); ax.Toolbar.Visible='on';
    nav = uigridlayout(view,[1 3]); nav.ColumnWidth={90,'1x',90}; nav.BackgroundColor='k';
    uibutton(nav,'Text','←','FontSize',18,'ButtonPushedFcn',@(s,e)goPlane(W.z-1));
    slZ = uislider(nav,'Limits',[1 max(1,W.nZ)],'Value',1,'MajorTicks',unique(round(linspace(1,W.nZ,min(W.nZ,10)))),'ValueChangingFcn',@zChanging,'ValueChangedFcn',@zChanged);
    uibutton(nav,'Text','→','FontSize',18,'ButtonPushedFcn',@(s,e)goPlane(W.z+1));

    try
        validateFastSamRuntime(SAM);
        logLocal('SAM2 already loaded/validated.');
    catch ME
        logLocal(['SAM2 validation warning: ' ME.message]);
    end
    render();
    uiwait(fig);
    if isvalidTable(W.planeRows), resultTable = W.planeRows; else, resultTable = table(); end
    nextPositionRequested = W.nextPositionRequested;

    %% workspace nested callbacks
    function log(msg)
        if isa(parentLogger,'function_handle')
            try parentLogger(msg); catch, end
        end
    end
    function logLocal(msg)
        txt.Value = [txt.Value; {char(msg)}]; scroll(txt,'bottom'); drawnow limitrate;
        log(msg);
    end

    function render()
        if ~isvalid(fig), return; end
        raw = W.stackDeg(:,:,W.z);
        m = W.degMask(:,:,W.z);
        cm = W.cellMask(:,:,W.z);
        rgb = repmat(double(raw)./255,1,1,3);
        if cbShowCell.Value && any(cm(:))
            if ~isempty(W.cellEdge) && size(W.cellEdge,3) >= W.z
                ce = W.cellEdge(:,:,W.z);
            else
                ce = bwperim(cm);
            end
            rgb(:,:,2) = max(rgb(:,:,2),0.75*double(ce));
            rgb(:,:,3) = max(rgb(:,:,3),0.75*double(ce));
        end
        if any(m(:))
            mm = repmat(m,1,1,3);
            red = cat(3,ones(size(m)),zeros(size(m)),zeros(size(m)));
            rgb = rgb.*(1-W.opacity*mm) + red.*(W.opacity*mm);
            edge = bwperim(m);
            rgb(:,:,1)=max(rgb(:,:,1),double(edge));
            rgb(:,:,2)=rgb(:,:,2).*(1-0.4*double(edge));
            rgb(:,:,3)=rgb(:,:,3).*(1-0.4*double(edge));
        end
        cla(ax);
        h = imshow(rgb,'Parent',ax);
        h.ButtonDownFcn = @imageClicked;
        h.PickableParts = 'all';
        axis(ax,'image'); ax.XTick=[]; ax.YTick=[];
        status = W.planeStatus(W.z);
        if isempty(W.cellObjects2D)
            tmpCC = bwconncomp(cm,8);
            cellObjs = tmpCC.NumObjects;
            cellPxNow = nnz(cm);
        else
            cellObjs = W.cellObjects2D(W.z);
            cellPxNow = W.cellArea2D(W.z);
        end
        lblZ.Text = sprintf('Z %d/%d | status=%s | tunnel=%d px | cell=%d px (%d cells) | last SAM %.2fs',W.z,W.nZ,status,nnz(m),cellPxNow,cellObjs,W.lastSamTime);
        title(ax,sprintf('Z %d/%d | left add, right isolate/replace | A accept, N no tunnel, arrows navigate',W.z,W.nZ),'Color','w');
        drawnow limitrate;
    end

    function imageClicked(~,~)
        if W.busy, return; end
        cp = ax.CurrentPoint;
        x = round(cp(1,1)); y = round(cp(1,2));
        if x < 1 || y < 1 || x > size(W.stackDeg,2) || y > size(W.stackDeg,1), return; end
        sel = fig.SelectionType;
        switch sel
            case 'normal'
                runSamClick(x,y,false);
            case 'alt'
                % If right-click is inside an existing mask, isolate the connected component instantly.
                if W.degMask(y,x,W.z)
                    W.undoMask = W.degMask(:,:,W.z);
                    W.degMask(:,:,W.z) = isolateConnectedComponentAtPoint(W.degMask(:,:,W.z),x,y);
                    W.planeStatus(W.z) = "edited";
                    logLocal(sprintf('Right click isolated existing connected component at Z=%d.',W.z));
                    render();
                else
                    runSamClick(x,y,true);
                end
        end
    end

    function runSamClick(x,y,replaceMode)
        raw = W.stackDeg(:,:,W.z);
        W.busy = true;
        W.undoMask = W.degMask(:,:,W.z);
        lblZ.Text = sprintf('Z %d/%d | SAM2 running at (%d,%d)...',W.z,W.nZ,x,y);
        drawnow limitrate;
        t0 = tic;
        try
            key = sprintf('%s_z%03d',W.fileBase,W.z);
            mask = fastSamPromptMask(raw,[x y 1],[],SAM,key);
            mask = logical(imresize(mask,size(raw),'nearest'));
            if cbFilter.Value
                mask = filterClickedMask(raw,mask,W.params);
            end
            if ~any(mask(:))
                logLocal('SAM returned empty/filtered mask. Try another click or disable filtering.');
            else
                if replaceMode
                    W.degMask(:,:,W.z) = mask;
                    logLocal(sprintf('Right click replace: Z=%d, %d px.',W.z,nnz(mask)));
                else
                    W.degMask(:,:,W.z) = W.degMask(:,:,W.z) | mask;
                    logLocal(sprintf('Left click add: Z=%d, +%d px.',W.z,nnz(mask)));
                end
                W.planeStatus(W.z) = "edited";
            end
        catch ME
            logLocal(['SAM click ERROR: ' ME.message]);
        end
        W.lastSamTime = toc(t0);
        W.busy = false;
        render();
    end

    function m = filterClickedMask(raw,m,params)
        if ~any(m(:)), return; end
        if nnz(m) < params.minArea
            m = false(size(m)); return;
        end
        if nnz(m) > params.maxMaskFraction*numel(m)
            % Reject whole-cell/background blobs unless clearly darker than surroundings.
            I = mat2gray(raw);
            ring = imdilate(m,strel('disk',10)) & ~imdilate(m,strel('disk',2));
            if nnz(ring) < 20, ring = ~m; end
            inside = mean(I(m),'omitnan'); surround = median(I(ring),'omitnan');
            if (surround-inside)/max(surround,eps) < 0.03
                m = false(size(m)); return;
            end
        end
        m = imfill(m,'holes');
        m = bwareaopen(m,params.minArea);
    end

    function goPlane(newZ)
        if isempty(W.stackDeg), return; end
        W.z = max(1,min(W.nZ,round(newZ)));
        slZ.Value = W.z;
        render();
    end
    function zChanging(~,event), W.z = max(1,min(W.nZ,round(event.Value))); render(); end
    function zChanged(src,~), W.z = max(1,min(W.nZ,round(src.Value))); src.Value=W.z; render(); end
    function changeOpacity(src,~), W.opacity = src.Value; render(); end

    function acceptPlaneAndNext(varargin)
        if nnz(W.degMask(:,:,W.z)) == 0
            logLocal(sprintf('ACCEPT pressed at Z=%d with 0 tunnel pixels. Saved as NO TUNNEL.',W.z));
            noTunnelAndNext();
            return;
        end
        W.noTunnel(W.z) = false;
        savePlane('accepted_tunnel');
        if W.z < W.nZ
            goPlane(W.z+1);
        else
            positionCompletePrompt();
        end
    end
    function noTunnelAndNext(varargin)
        W.undoMask = W.degMask(:,:,W.z);
        W.degMask(:,:,W.z) = false(size(W.degMask(:,:,W.z)));
        W.noTunnel(W.z) = true;
        savePlane('no_tunnel');
        if W.z < W.nZ
            goPlane(W.z+1);
        else
            positionCompletePrompt();
        end
    end
    function undoMask(varargin)
        if ~isempty(W.undoMask)
            W.degMask(:,:,W.z) = W.undoMask;
            W.planeStatus(W.z) = "edited";
            render();
        end
    end
    function clearMask(varargin)
        W.undoMask = W.degMask(:,:,W.z);
        W.degMask(:,:,W.z) = false(size(W.degMask(:,:,W.z)));
        W.planeStatus(W.z) = "edited";
        render();
    end
    function brushAdd(~,~)
        try
            W.undoMask = W.degMask(:,:,W.z);
            r = drawfreehand(ax,'Color','g'); m = createMask(r); delete(r);
            W.degMask(:,:,W.z) = W.degMask(:,:,W.z) | m;
            W.planeStatus(W.z) = "edited"; render();
        catch ME, logLocal(['Brush add ERROR: ' ME.message]); end
    end
    function brushErase(~,~)
        try
            W.undoMask = W.degMask(:,:,W.z);
            r = drawfreehand(ax,'Color','r'); m = createMask(r); delete(r);
            W.degMask(:,:,W.z) = W.degMask(:,:,W.z) & ~m;
            W.planeStatus(W.z) = "edited"; render();
        catch ME, logLocal(['Brush erase ERROR: ' ME.message]); end
    end

    function validateAgain(~,~)
        try validateFastSamRuntime(SAM); logLocal('SAM2 validated/reloaded.'); catch ME, logLocal(['SAM2 ERROR: ' ME.message]); end
    end

    function chooseOutput(~,~)
        root0 = W.outputRoot;
        if isempty(root0), root0 = fileparts(W.lif); end
        p = uigetdir(root0,'Choose annotation output folder root');
        if isequal(p,0), return; end
        W.outputRoot = p;
        ensureOutDir();
        logLocal(['Output folder: ' W.outDir]);
    end

    function ensureOutDir()
        if ~isempty(W.outDir) && exist(W.outDir,'dir'), return; end

        % Preferred layout: one session run contains all positions analysed from
        % each file. Each position gets its own subfolder, but aggregate metrics
        % are continuously updated at the file-run level.
        if isfield(W,'fileRunDir') && ~isempty(W.fileRunDir)
            mkdirIfNeeded(W.fileRunDir);
            W.outDir = fullfile(W.fileRunDir,sprintf('pos%d',W.series));
        else
            root0 = W.outputRoot;
            if isempty(root0) || ~exist(root0,'dir'), root0 = fileparts(W.lif); end
            modDir = fullfile(root0,'Degradation_Tunnel_Annotation');
            mkdirIfNeeded(modDir);
            W.outDir = nextRunDir(modDir);
        end

        mkdirIfNeeded(W.outDir);
        mkdirIfNeeded(fullfile(W.outDir,'images'));
        mkdirIfNeeded(fullfile(W.outDir,'masks_degradation'));
        mkdirIfNeeded(fullfile(W.outDir,'masks_cell'));
        mkdirIfNeeded(fullfile(W.outDir,'masks_multiclass'));
        mkdirIfNeeded(fullfile(W.outDir,'projects'));
        mkdirIfNeeded(fullfile(W.outDir,'metrics'));
        mkdirIfNeeded(fullfile(W.outDir,'renders_3d'));
    end

    function savePlane(status)
        ensureOutDir();
        z = W.z;
        raw = W.stackDeg(:,:,z);
        dm = W.degMask(:,:,z);
        cm = W.cellMask(:,:,z);
        % Cell context comes from the precomputed 3-D cell-channel mask.
        % Do not restore local 2-D puncta here: that was the source of the cyan
        % artefact blobs. If this is empty, either the real cell is absent in this
        % Z-plane or the selected Cell channel / Min cell volume setting should be checked.
        if ~isnan(W.cellCh) && nnz(cm) == 0 && ~isempty(W.stackCell) && any(W.stackCell(:,:,z),'all')
            logLocal(sprintf('Z=%d saved with empty cell mask. Cell-channel 3D segmentation found no valid cell in this plane.',z));
        end
        % Keep full, traceable filenames for the actual training images/masks.
        % Other outputs remain short, e.g. pos1_*.xlsx, pos1_*.fig.
        base = sprintf('%s_z%03d.png',W.imageBase,z);
        imwrite(raw,fullfile(W.outDir,'images',base));
        imwrite(uint8(dm)*255,fullfile(W.outDir,'masks_degradation',base));
        imwrite(uint8(cm)*255,fullfile(W.outDir,'masks_cell',base));
        multi = zeros(size(raw),'uint8');
        multi(cm) = 1; multi(dm) = 2;
        imwrite(multi,fullfile(W.outDir,'masks_multiclass',base));
        row = computePlaneMetrics(W.fileBase,W.series,z,status,raw,cm,dm,W.px);
        W.planeRows = upsertPlaneRow(W.planeRows,row);
        W.saved(z) = true;
        W.planeStatus(z) = string(status);
        tbl.Data = W.planeRows;
        if cbShowSaved.Value
            saveProjectSilently();
        end
        safeWriteTable(W.planeRows,fullfile(W.outDir,'metrics','plane_metrics.csv'),'plane metrics CSV',@logLocal);
        writeDatasetManifest(W.outDir,W.fileBase,W.nZ,W.px,W.imageBase);
        logLocal(sprintf('Saved Z=%d as %s. Tunnel px=%d | cell px=%d.',z,status,nnz(dm),nnz(cm)));
        render();
    end

    function saveProjectNow(varargin)
        ensureOutDir();
        saveProjectSilently();
        logLocal(['Project saved: ' fullfile(W.outDir,'projects',[W.fileBase '_manual_project.mat'])]);
    end
    function saveProjectSilently()
        % Robust project save. The masks/images/metrics are already written
        % plane-by-plane; the MAT project is only a recovery convenience and must
        % never block Excel/3D export. Save atomically to a temporary file first
        % so a previous corrupt/locked OneDrive MAT cannot stop finalization.
        project = struct();
        project.lif = W.lif;
        project.series = W.series;
        project.degCh = W.degCh;
        project.cellCh = W.cellCh;
        project.params = W.params;
        project.outputRoot = W.outputRoot;
        project.outDir = W.outDir;
        project.fileRunDir = W.fileRunDir;
        project.fileBase = W.fileBase;
        project.imageBase = W.imageBase;
        project.px = W.px;
        project.nZ = W.nZ;
        project.currentZ = W.z;
        project.saved = W.saved;
        project.noTunnel = W.noTunnel;
        project.planeStatus = W.planeStatus;
        project.planeRows = W.planeRows;
        project.degMask = logical(W.degMask);
        project.cellMask = logical(W.cellMask);
        project.cellObjects2D = W.cellObjects2D;
        project.cellArea2D = W.cellArea2D;
        project.maskFolders = struct( ...
            'images',fullfile(W.outDir,'images'), ...
            'degradation',fullfile(W.outDir,'masks_degradation'), ...
            'cell',fullfile(W.outDir,'masks_cell'), ...
            'multiclass',fullfile(W.outDir,'masks_multiclass'));
        project.savedTime = datetime('now');
        dest = fullfile(W.outDir,'projects',[W.fileBase '_manual_project.mat']);
        try
            savedPath = robustSaveProjectMat(dest,project);
            if ~strcmp(savedPath,dest)
                logLocal(['Project saved to fallback MAT because the default file was locked/corrupt: ' savedPath]);
            end
        catch ME
            logLocal(['WARNING: project MAT save failed, but masks/metrics remain saved. Export will continue. ' ME.message]);
        end
    end

    function finishAndExport(~,~)
        finishAndExportInternal(true);
    end

    function finishAndExportInternal(showAlert)
        if nargin < 1, showAlert = true; end
        ensureOutDir();
        try
            saveProjectSilently();
        catch ME
            % A project MAT is useful but non-essential. Continue with metrics,
            % masks, Excel and 3D even if OneDrive/MATLAB refuses to overwrite it.
            logLocal(['WARNING: project save failed during finish; continuing export. ' ME.message]);
        end
        summary = computeStackSummary(W.fileBase,W.series,W.stackDeg,W.cellMask,W.degMask,W.saved,W.px);
        objT = computeObjectMetrics(W.fileBase,W.series,W.degMask,W.px);
        excelPath = fullfile(W.outDir,'metrics',[W.fileBase '_manual_degradation_metrics.xlsx']);
        excelPath = robustWritePositionWorkbook(excelPath,W.planeRows,summary,objT,W.outDir,W.fileBase,@logLocal);
        summaryText = formatPositionSummary(summary,objT);
        writeTextFile(fullfile(W.outDir,'metrics',[W.fileBase '_position_summary.txt']),summaryText);
        writeDatasetManifest(W.outDir,W.fileBase,W.nZ,W.px,W.imageBase);
        try
            updateFileRunAggregate(W.fileRunDir,W.outDir,W.fileBase,summary,objT,W.planeRows);
        catch ME
            logLocal(['WARNING: aggregate file summary failed, but position metrics and 3D continue. ' ME.message]);
        end
        logLocal('Starting 3D reconstruction from saved masks...');
        drawnow limitrate;
        try
            [pngPath,figPath] = create3DReconstructionFromMasks(W.fileBase,W.series,W.cellMask,W.degMask,W.saved,W.px,W.outDir);
        catch ME
            pngPath = '3D reconstruction failed';
            figPath = '3D reconstruction failed';
            logLocal(['WARNING: 3D reconstruction failed after metrics export. ' ME.message]);
        end
        logLocal(['Finished. Metrics workbook: ' excelPath]);
        logLocal(['3D reconstruction: ' pngPath]);
        logLocal(summaryText);
        if showAlert
            uialert(fig,sprintf('%s\n\nOutput:\n%s\n\nEditable FIG:\n%s',summaryText,W.outDir,figPath),'Position summary','Icon','info');
        end
    end

    function recreate3DNow(varargin)
        ensureOutDir();
        try
            saveProjectSilently();
        catch ME
            logLocal(['WARNING: project save failed before 3D; continuing render. ' ME.message]);
        end
        try
            [pngPath,figPath] = create3DReconstructionFromMasks(W.fileBase,W.series,W.cellMask,W.degMask,W.saved,W.px,W.outDir);
            logLocal(['3D reconstruction refreshed: ' pngPath]);
            try
                uialert(fig,sprintf('3D reconstruction saved:\n%s\n\nEditable FIG:\n%s',pngPath,figPath),'3D reconstruction','Icon','info');
            catch
            end
        catch ME
            logLocal(['3D reconstruction ERROR: ' ME.message]);
            try uialert(fig,ME.message,'3D reconstruction failed'); catch, end
        end
    end

    function finish3DAndNextPosition(varargin)
        finishAndExportInternal(false);
        W.nextPositionRequested = true;
        logLocal('Position finished. Closing workspace and requesting the next position...');
        onClose();
    end

    function positionCompletePrompt()
        try
            choice = uiconfirm(fig, sprintf('Position %d reached the last plane. What do you want to do?',W.series), ...
                'Position complete', ...
                'Options', {'3D + next position','3D only','Continue here'}, ...
                'DefaultOption', 1, 'CancelOption', 3);
            switch choice
                case '3D + next position'
                    finish3DAndNextPosition();
                case '3D only'
                    recreate3DNow();
            end
        catch
            logLocal('Position completed. Use Recreate 3D or Finish + 3D + next position.');
        end
    end

    function openOut(~,~)
        ensureOutDir();
        if ispc, winopen(W.outDir); elseif ismac, system(sprintf('open %s',shellQuote(W.outDir))); else, system(sprintf('xdg-open %s',shellQuote(W.outDir))); end
    end

    function onKey(~,event)
        switch lower(event.Key)
            case {'rightarrow','d'}
                goPlane(W.z+1);
            case {'leftarrow','a'}
                goPlane(W.z-1);
            case {'space','return'}
                acceptPlaneAndNext();
            case {'n'}
                noTunnelAndNext();
            case {'c'}
                clearMask();
            case {'s'}
                saveProjectNow();
            case {'z'}
                undoMask();
        end
    end

    function onClose(varargin)
        try
            if any(W.saved)
                ensureOutDir(); saveProjectSilently();
                resultTable = W.planeRows;
            end
            nextPositionRequested = W.nextPositionRequested;
        catch
        end
        try uiresume(fig); catch, end
        try delete(fig); catch, end
    end
end

%% ========================================================================
%  FAST PERSISTENT SAM2 BRIDGE CALLS
%  ========================================================================
function validateFastSamRuntime(SAM)
    requireSamConfigured(SAM);
    setupMatlabPython(SAM.pythonExe);
    mod = getFastSamModule(SAM,true);
    out = string(mod.configure(SAM.repoRoot,SAM.checkpoint,SAM.config)); %#ok<NASGU>
end

function mask = fastSamPromptMask(img,points,box,SAM,cacheKey)
    requireSamConfigured(SAM);
    setupMatlabPython(SAM.pythonExe);
    mod = getFastSamModule(SAM,false);
    tempDir = fullfile(tempdir,'degradation_sam2_fast_runtime');
    mkdirIfNeeded(tempDir);
    safeKey = safeName(cacheKey);
    imagePath = fullfile(tempDir,[safeKey '.png']);
    promptPath = fullfile(tempDir,[safeKey '_prompt.json']);
    outPath = fullfile(tempDir,[safeKey '_mask.png']);
    % Avoid exist(...,'file') inside the SAM click callback; in some MATLAB
    % callback contexts that path has produced an unresolved variable 'file'.
    if ~isfile(imagePath)
        imwrite(im2uint8(mat2gray(img)),imagePath);
    end
    P = struct();
    P.points = points;
    if isempty(box), P.box = []; else, P.box = box; end
    writeTextFile(promptPath,jsonencode(P));
    mod.predict_prompt(imagePath,promptPath,outPath);
    if ~isfile(outPath), error('SAM2 did not write a mask.'); end
    mask = imread(outPath) > 0;
end

function mod = getFastSamModule(SAM,forceReload)
    persistent cachedMod cachedKey
    if nargin < 2, forceReload = false; end
    bridgePath = ensureFastSamBridge();
    bridgeDir = fileparts(bridgePath);
    key = strjoin({char(SAM.repoRoot),char(SAM.checkpoint),char(SAM.config),char(bridgePath)},'|');
    if forceReload || isempty(cachedMod) || ~strcmp(cachedKey,key)
        addPythonPath(bridgeDir);
        addPythonPath(SAM.repoRoot);
        m = py.importlib.import_module('degradation_sam2_fast_bridge');
        m = py.importlib.reload(m);
        m.configure(SAM.repoRoot,SAM.checkpoint,SAM.config);
        cachedMod = m;
        cachedKey = key;
    end
    mod = cachedMod;
end

function addPythonPath(pathStr)
    pathStr = char(pathStr);
    if isempty(pathStr), return; end
    % Newer MATLAB releases require parentheses when dot-indexing a Python
    % object returned by a function call: py.sys.path().insert(...)
    try
        py.sys.path().insert(int32(0),pathStr);
    catch firstME
        try
            py.sys.path.insert(int32(0),pathStr);
        catch secondME
            error('Could not add Python path %s. New syntax error: %s | Old syntax error: %s',pathStr,firstME.message,secondME.message);
        end
    end
end

function setupMatlabPython(pythonExe)
    if isempty(strtrim(pythonExe)), return; end
    if ~exist(pythonExe,'file'), error('Python executable not found: %s',pythonExe); end
    try
        pe = pyenv;
        if strcmpi(char(pe.Status),'NotLoaded')
            pyenv('Version',pythonExe,'ExecutionMode','OutOfProcess');
        else
            current = char(pe.Executable);
            if ~strcmpi(current,pythonExe)
                % Do not attempt to switch after Python is loaded; MATLAB requires restart.
                warning('DegradationAnnotation:PythonAlreadyLoaded','MATLAB Python is already loaded from %s, not %s. Restart MATLAB if SAM2 imports fail.',current,pythonExe);
            end
        end
    catch ME
        error('Could not initialize MATLAB Python runtime: %s',ME.message);
    end
end

function requireSamConfigured(SAM)
    if ~isfield(SAM,'pythonExe'), SAM.pythonExe = ''; end
    if ~isfield(SAM,'repoRoot') || isempty(SAM.repoRoot) || ~exist(SAM.repoRoot,'dir')
        error('SAM2 repo root is not configured or does not exist.');
    end
    if ~isfield(SAM,'checkpoint') || isempty(SAM.checkpoint) || ~exist(SAM.checkpoint,'file')
        error('SAM2 checkpoint is not configured or does not exist.');
    end
    if ~isfield(SAM,'config') || isempty(SAM.config)
        error('SAM2 config yaml is not configured.');
    end
end

function bridgePath = ensureFastSamBridge()
    bridgeDir = fullfile(tempdir,'degradation_sam2_fast_runtime');
    mkdirIfNeeded(bridgeDir);
    bridgePath = fullfile(bridgeDir,'degradation_sam2_fast_bridge.py');
    code = fastBridgeCode();
    rewrite = true;
    if exist(bridgePath,'file')
        try rewrite = ~strcmp(fileread(bridgePath),code); catch, rewrite = true; end
    end
    if rewrite, writeTextFile(bridgePath,code); end
end

function code = fastBridgeCode()
    lines = {
'"""Persistent SAM2 bridge for degradation/tunnel annotation. Generated by MATLAB."""'
'import os, sys, json'
'import numpy as np'
'from PIL import Image'
'_predictor = None'
'_image_path = None'
'_device = None'
'_key = None'
''
'def _add_repo(repo_root):'
'    if repo_root:'
'        repo_root = os.path.abspath(repo_root)'
'        if repo_root not in sys.path:'
'            sys.path.insert(0, repo_root)'
'        try:'
'            os.chdir(repo_root)'
'        except Exception:'
'            pass'
''
'def configure(repo_root, checkpoint, config):'
'    global _predictor, _device, _key, _image_path'
'    repo_root = os.path.abspath(str(repo_root))'
'    checkpoint = os.path.abspath(str(checkpoint))'
'    config = str(config)'
'    key = repo_root + "|" + checkpoint + "|" + config'
'    if _predictor is not None and _key == key:'
'        return "SAM2 already loaded on " + str(_device)'
'    _add_repo(repo_root)'
'    if not os.path.exists(checkpoint):'
'        raise RuntimeError("Checkpoint not found: " + checkpoint)'
'    import torch'
'    from sam2.build_sam import build_sam2'
'    from sam2.sam2_image_predictor import SAM2ImagePredictor'
'    _device = "cuda" if torch.cuda.is_available() else "cpu"'
'    model = build_sam2(config, checkpoint, device=_device)'
'    _predictor = SAM2ImagePredictor(model)'
'    _key = key'
'    _image_path = None'
'    return "SAM2 loaded on " + str(_device)'
''
'def _load_rgb(path):'
'    arr = np.asarray(Image.open(path).convert("RGB"))'
'    return arr'
''
'def set_image(image_path):'
'    global _image_path'
'    if _predictor is None:'
'        raise RuntimeError("SAM2 is not configured. Call configure first.")'
'    image_path = os.path.abspath(str(image_path))'
'    if _image_path == image_path:'
'        return "image already set"'
'    image = _load_rgb(image_path)'
'    _predictor.set_image(image)'
'    _image_path = image_path'
'    return "image set"'
''
'def _save_binary(mask, out_path):'
'    Image.fromarray((np.asarray(mask).astype(bool).astype(np.uint8)*255)).save(out_path)'
''
'def _load_prompt(prompt_path):'
'    with open(prompt_path, "r", encoding="utf-8") as f:'
'        data = json.load(f)'
'    pts = np.asarray(data.get("points", []), dtype=np.float32)'
'    point_coords = None; point_labels = None'
'    if pts.size:'
'        pts = np.atleast_2d(pts)'
'        point_coords = pts[:, :2].astype(np.float32)'
'        point_labels = pts[:, 2].astype(np.int32)'
'    box = data.get("box", None)'
'    box_arr = None'
'    if box not in (None, []):'
'        x, y, w, h = [float(v) for v in box]'
'        box_arr = np.asarray([x, y, x+w, y+h], dtype=np.float32)'
'    return point_coords, point_labels, box_arr'
''
'def predict_prompt(image_path, prompt_path, out_path):'
'    if _predictor is None:'
'        raise RuntimeError("SAM2 not configured")'
'    set_image(image_path)'
'    point_coords, point_labels, box = _load_prompt(prompt_path)'
'    if point_coords is None and box is None:'
'        raise RuntimeError("No point or box prompt was provided")'
'    masks, scores, _ = _predictor.predict(point_coords=point_coords, point_labels=point_labels, box=box, multimask_output=True)'
'    if masks is None or len(masks) == 0:'
'        raise RuntimeError("SAM2 returned no masks")'
'    best = int(np.argmax(scores)) if scores is not None and len(scores) else 0'
'    _save_binary(masks[best], str(out_path))'
'    return "saved"'
    };
    code = strjoin(lines,newline);
end

%% ========================================================================
%  IMAGE I/O
%  ========================================================================
function [degStack,cellStack,px] = readSelectedLifStacks(lifPath,seriesIdx,degCh,cellCh)
    if exist('bfGetReader','file') == 0
        error('Bio-Formats bfGetReader is missing from MATLAB path.');
    end
    reader = [];
    try
        reader = bfGetReader(lifPath);
        nSeries = reader.getSeriesCount();
        seriesIdx = max(1,min(nSeries,seriesIdx));
        reader.setSeries(seriesIdx-1);
        nC = reader.getSizeC();
        degCh = max(1,min(nC,degCh));
        hasCellChannel = ~isnan(cellCh);
        if hasCellChannel, cellCh = max(1,min(nC,cellCh)); end
        sx = reader.getSizeX(); sy = reader.getSizeY(); sz = reader.getSizeZ();
        degStack = zeros(sy,sx,sz,'uint8');
        cellStack = zeros(sy,sx,sz,'uint8');
        for z=1:sz
            degStack(:,:,z) = im2uint8(mat2gray(bfGetPlane(reader,reader.getIndex(z-1,degCh-1,0)+1)));
            if ~hasCellChannel
                cellStack(:,:,z) = zeros(sy,sx,'uint8');
            else
                cellStack(:,:,z) = im2uint8(mat2gray(bfGetPlane(reader,reader.getIndex(z-1,cellCh-1,0)+1)));
            end
        end
        px = struct('x',1,'y',1,'z',1);
        try
            omeMeta = reader.getMetadataStore();
            px.x = omeMeta.getPixelsPhysicalSizeX(seriesIdx-1).value().doubleValue();
            px.y = omeMeta.getPixelsPhysicalSizeY(seriesIdx-1).value().doubleValue();
            px.z = omeMeta.getPixelsPhysicalSizeZ(seriesIdx-1).value().doubleValue();
        catch
        end
        reader.close();
    catch ME
        if ~isempty(reader), try reader.close(); catch, end, end
        rethrow(ME);
    end
end

function mask3 = segmentCellStack(cellStack,px,minCellVolUm3,downsampleFactor)
    % 3-D Otsu-based cell segmentation from the selected CELL channel.
    %
    % This intentionally mirrors geodesic_tract_analysis.m:
    %   cell channel -> max normalization -> optional downsample -> Otsu over
    %   non-zero cell voxels -> 3-D bwareaopen by physical cell volume.
    %
    % The previous annotation workflow implementation used many 2-D fallback/shape gates;
    % those could recover bright vesicles and matrix speckles as many cyan
    % "cells". Here, a component must survive a true 3-D volume threshold.
    if nargin < 2 || isempty(px), px = struct('x',1,'y',1,'z',1); end
    if nargin < 3 || isempty(minCellVolUm3), minCellVolUm3 = 500; end
    if nargin < 4 || isempty(downsampleFactor), downsampleFactor = 2; end
    downsampleFactor = max(1,round(double(downsampleFactor)));

    mask3 = false(size(cellStack));
    if isempty(cellStack) || max(cellStack(:)) == 0, return; end

    vol = single(cellStack);
    vol(~isfinite(vol)) = 0;
    mx = max(vol(:));
    if mx <= 0, return; end
    vol = vol ./ mx;

    if downsampleFactor > 1
        volD = imresize3(vol,1/downsampleFactor,'linear');
    else
        volD = vol;
    end

    cellVals = volD(volD > 0);
    if isempty(cellVals), return; end
    try
        thr = graythresh(cellVals);
    catch
        thr = prctile(cellVals,75);
    end
    maskD = volD > thr;

    voxVol = safeVoxelVolume(px);
    minVoxD = max(1,round(double(minCellVolUm3) / max(voxVol * downsampleFactor^3,eps)));
    maskD = bwareaopen(maskD,minVoxD,26);

    % Mild 3-D cleanup only. Keep it conservative so the result remains close to
    % The 3D segmentation avoids hallucinating local 2-D objects.
    if any(maskD(:))
        try
            maskD = imclose(maskD,strel('sphere',1));
        catch
        end
        maskD = bwareaopen(maskD,minVoxD,26);
    end

    if downsampleFactor > 1
        mask3 = imresize3(double(maskD),size(cellStack),'nearest') > 0.5;
    else
        mask3 = maskD;
    end

    % Final full-resolution physical volume filter.
    minVoxFull = max(1,round(double(minCellVolUm3) / max(voxVol,eps)));
    mask3 = bwareaopen(mask3,minVoxFull,26);

    % Fill only inside already-surviving 3-D objects, plane by plane.
    for z = 1:size(mask3,3)
        if any(mask3(:,:,z),'all')
            mask3(:,:,z) = imfill(mask3(:,:,z),'holes');
        end
    end
    mask3 = bwareaopen(mask3,minVoxFull,26);
end

function v = safeVoxelVolume(px)
    try
        v = double(px.x) * double(px.y) * double(px.z);
    catch
        v = 1;
    end
    if ~isfinite(v) || v <= 0, v = 1; end
end

function xyROI = estimateCellXYFootprints(cellStack,pLow,pHigh,minCellAreaPx,maxCellAreaPx)
    [H,Wd,nZ] = size(cellStack);
    xyROI = false(H,Wd);
    if nZ == 0, return; end

    normStack = zeros(size(cellStack),'single');
    for z = 1:nZ
        I = (double(cellStack(:,:,z)) - pLow) ./ max(pHigh-pLow,eps);
        I = min(max(I,0),1);
        normStack(:,:,z) = single(imgaussfilt(I,3.0));
    end

    maxProj = max(normStack,[],3);
    meanProj = mean(normStack,3);
    strong = normStack >= prctile(normStack(:),98.4);
    persistence = sum(strong,3) ./ max(1,nZ);
    score = 0.55*mat2gray(maxProj) + 0.30*mat2gray(meanProj) + 0.15*mat2gray(imgaussfilt(persistence,2.0));
    score = imgaussfilt(score,2.0);

    vals = score(:);
    try, ots = graythresh(score); catch, ots = prctile(vals,96); end
    thr = max([prctile(vals,96.0), 0.85*ots, 0.06]);
    roi = score > thr;
    roi = imclose(roi,strel('disk',8,0));
    roi = imfill(roi,'holes');
    roi = bwareaopen(roi,max(minCellAreaPx,round(numel(roi)*0.0006)));
    roi = removeBorderBackgroundObjects(roi,maxCellAreaPx*1.6);

    % If thresholding fragmented the cell, use regional maxima around the most
    % persistent/bright areas and keep only components with real footprint size.
    if ~any(roi(:))
        roi = score > prctile(vals,98.2);
        roi = imclose(roi,strel('disk',10,0));
        roi = imfill(roi,'holes');
        roi = bwareaopen(roi,max(minCellAreaPx,round(numel(roi)*0.0006)));
    end

    if any(roi(:))
        CC = bwconncomp(roi,8);
        S = regionprops(CC,score,'Area','MeanIntensity','PixelIdxList','BoundingBox');
        keep = false(numel(S),1);
        areas = [S.Area];
        maxArea = max(areas);
        scores = zeros(numel(S),1);
        for k=1:numel(S)
            bb = S(k).BoundingBox;
            aspect = max(bb(3),bb(4)) / max(1,min(bb(3),bb(4)));
            scores(k) = S(k).MeanIntensity * sqrt(max(S(k).Area,1));
            keep(k) = S(k).Area >= max(minCellAreaPx,0.08*maxArea) && aspect < 9.0;
        end
        % In noisy files, many tiny components may pass. Keep dominant projected
        % objects; this still allows multiple cells when they are sizeable.
        [~,ord] = sort(scores,'descend');
        dominant = false(size(keep));
        for ii=1:min(numel(ord),12)
            k = ord(ii);
            if keep(k)
                dominant(k) = true;
            end
        end
        roi2 = false(size(roi));
        for k=find(dominant)'
            roi2(S(k).PixelIdxList) = true;
        end
        roi = roi2;
    end

    xyROI = roi;
end

function mask3 = filterCell3DByDominantFootprints(mask3,cellStack,pLow,pHigh,minCellAreaPx,xyROI)
    if ~any(mask3(:)), return; end
    planePixels = size(mask3,1)*size(mask3,2);
    minProjArea = max(minCellAreaPx,round(planePixels*0.00065));
    minVol = max(round(2.2*minCellAreaPx),900);

    CC = bwconncomp(mask3,26);
    if CC.NumObjects == 0, return; end
    S = regionprops3(CC,'Volume','VoxelIdxList','BoundingBox');
    score = zeros(height(S),1);
    projAreas = zeros(height(S),1);
    zSpans = zeros(height(S),1);
    keep0 = false(height(S),1);

    for k=1:height(S)
        idx = S.VoxelIdxList{k};
        [yy,xx,zz] = ind2sub(size(mask3),idx);
        proj = false(size(mask3,1),size(mask3,2));
        proj(sub2ind(size(proj),yy,xx)) = true;
        projArea = nnz(proj);
        zSpan = numel(unique(zz));
        vol = S.Volume(k);
        if nargin >= 6 && any(xyROI(:))
            overlapFrac = nnz(proj & xyROI) / max(1,projArea);
        else
            overlapFrac = 1;
        end
        projAreas(k) = projArea;
        zSpans(k) = zSpan;
        keep0(k) = vol >= minVol && projArea >= minProjArea && zSpan >= 2 && overlapFrac >= 0.35;
        score(k) = double(vol) * sqrt(double(max(projArea,1))) * max(0.05,overlapFrac);
    end

    if ~any(keep0)
        [~,best] = max(score);
        keep0(best) = score(best) > 0;
    end

    maxScore = max(score(keep0));
    keep = keep0 & (score >= maxScore*0.10 | projAreas >= max(minProjArea*2,0.06*max(projAreas)));

    % Cap only after ranking, to avoid showing dozens of small noisy cell objects.
    [~,ord] = sort(score,'descend');
    keepRanked = false(size(keep));
    kept = 0;
    for ii=1:numel(ord)
        k = ord(ii);
        if keep(k)
            keepRanked(k) = true;
            kept = kept + 1;
            if kept >= 12, break; end
        end
    end

    out = false(size(mask3));
    for k=find(keepRanked)'
        out(S.VoxelIdxList{k}) = true;
    end

    % Smooth per-plane edges but do not create new objects.
    for z=1:size(out,3)
        if any(out(:,:,z),'all')
            plane = imclose(out(:,:,z),strel('disk',3,0));
            plane = imfill(plane,'holes');
            plane = bwareaopen(plane,minCellAreaPx);
            out(:,:,z) = plane;
        end
    end
    mask3 = out;
end

function cand = removeBorderBackgroundObjects(cand,maxCellAreaPx)
    if ~any(cand(:)), return; end
    CC = bwconncomp(cand,8);
    if CC.NumObjects == 0, return; end
    [H,W] = size(cand);
    remove = false(CC.NumObjects,1);
    for k=1:CC.NumObjects
        idx = CC.PixelIdxList{k};
        area = numel(idx);
        [yy,xx] = ind2sub([H W],idx);
        touches = any(yy==1 | yy==H | xx==1 | xx==W);
        if (touches && area > 0.015*numel(cand)) || area > maxCellAreaPx
            remove(k) = true;
        end
    end
    if any(remove)
        for k=find(remove)'
            cand(CC.PixelIdxList{k}) = false;
        end
    end
end

function mOut = keepPlausibleCellComponents2D(m,I,minCellAreaPx,maxCellAreaPx,vesicleAreaPx)
    mOut = false(size(m));
    CC = bwconncomp(m,8);
    if CC.NumObjects == 0, return; end
    S = regionprops(CC,I,'Area','Perimeter','Eccentricity','Solidity','MeanIntensity','PixelIdxList','BoundingBox');
    globalMed = median(I(:),'omitnan');
    globalP75 = prctile(I(:),75);
    for k=1:numel(S)
        area = S(k).Area;
        if area < minCellAreaPx || area > maxCellAreaPx
            continue;
        end
        per = max(S(k).Perimeter,eps);
        circularity = 4*pi*area/(per^2);
        bb = S(k).BoundingBox;
        longSide = max(bb(3),bb(4));
        shortSide = max(1,min(bb(3),bb(4)));
        aspect = longSide/shortSide;

        % Vesicles/puncta: small, round, solid, high-intensity dots. Larger or
        % elongated cellular regions are retained.
        isSmallRoundVesicle = area <= max(vesicleAreaPx,round(0.75*minCellAreaPx)) && ...
            circularity > 0.62 && S(k).Solidity > 0.82 && S(k).Eccentricity < 0.82;
        isThinFiberLike = area < 3.5*minCellAreaPx && aspect > 8.5 && S(k).Solidity < 0.62;
        isTooDim = S(k).MeanIntensity < max(globalMed + 0.015, globalP75*0.65);
        if isSmallRoundVesicle || isThinFiberLike || isTooDim
            continue;
        end
        mOut(S(k).PixelIdxList) = true;
    end
    if any(mOut(:))
        mOut = imclose(mOut,strel('disk',4));
        mOut = imfill(mOut,'holes');
        mOut = bwareaopen(mOut,minCellAreaPx);
    end
end

function mask3 = enforceCell3DConsistency(cand3,seed3,minCellAreaPx)
    mask3 = false(size(cand3));
    if ~any(cand3(:)), return; end
    CC = bwconncomp(cand3,26);
    minVol = max(round(2.0*minCellAreaPx),900);
    for k=1:CC.NumObjects
        idx = CC.PixelIdxList{k};
        [~,~,zz] = ind2sub(size(cand3),idx);
        zSpan = numel(unique(zz));
        hasSeed = any(seed3(idx));
        vol = numel(idx);
        % Require persistence or a much larger volume. This removes the scattered
        % one-/two-plane cyan blobs caused by vesicles and bright noise.
        if (vol >= minVol && zSpan >= 3 && hasSeed) || (vol >= 4*minVol && zSpan >= 2)
            mask3(idx) = true;
        end
    end
end

function mOut = keepBrightestCellComponents(m,I,maxPixels)
    mOut = false(size(m));
    CC = bwconncomp(m,8);
    if CC.NumObjects == 0, return; end
    S = regionprops(CC,I,'Area','MeanIntensity','PixelIdxList');
    score = zeros(numel(S),1);
    for k=1:numel(S)
        score(k) = S(k).MeanIntensity * sqrt(max(S(k).Area,1));
    end
    [~,ord] = sort(score,'descend');
    used = 0;
    for ii=1:numel(ord)
        k = ord(ii);
        if used + S(k).Area > maxPixels && used > 0
            continue;
        end
        mOut(S(k).PixelIdxList) = true;
        used = used + S(k).Area;
        if used >= maxPixels, break; end
    end
end


function m = segmentCellPlaneFallback(Iraw)
    % Strict last-resort single-plane cell mask from the CELL channel only.
    % It is deliberately conservative: if the plane contains only vesicles/puncta
    % or matrix texture, it returns an empty cell mask instead of drawing many
    % misleading cyan blobs.
    m = false(size(Iraw));
    if isempty(Iraw) || max(Iraw(:)) == 0, return; end
    I = double(Iraw);
    vals = I(isfinite(I));
    if isempty(vals) || max(vals)==min(vals), return; end
    pLow = prctile(vals,2);
    pHigh = prctile(vals,99.85);
    I = (I - pLow) ./ max(pHigh-pLow,eps);
    I = min(max(I,0),1);
    H = size(I,1); Wd = size(I,2); planePixels = H*Wd;

    minArea = max(500,round(planePixels*0.00050));
    maxArea = round(planePixels*0.20);
    vesArea = max(260,round(planePixels*0.00028));

    Is = imgaussfilt(I,3.2);
    try
        bg = imopen(Is,strel('disk',max(22,round(min(H,Wd)/22))));
        J = mat2gray(Is-bg);
    catch
        J = mat2gray(Is);
    end
    J = imgaussfilt(J,1.4);
    valsJ = J(:);
    try, ots = graythresh(J); catch, ots = prctile(valsJ,97); end
    thr = max([prctile(valsJ,97.0),0.85*ots,0.06]);

    cand = J > thr;
    cand = imopen(cand,strel('disk',3,0));
    cand = imclose(cand,strel('disk',7,0));
    cand = imfill(cand,'holes');
    cand = bwareaopen(cand,minArea);
    cand = removeBorderBackgroundObjects(cand,maxArea);
    cand = keepPlausibleCellComponents2D(cand,J,minArea,maxArea,vesArea);

    if any(cand(:))
        cand = keepBrightestCellComponents(cand,J,round(0.09*numel(cand)));
    end
    m = cand;
end

function edge3 = precomputeCellEdges(cellMask)
    edge3 = false(size(cellMask));
    if isempty(cellMask), return; end
    for z=1:size(cellMask,3)
        if any(reshape(cellMask(:,:,z),[],1))
            edge3(:,:,z) = bwperim(cellMask(:,:,z));
        end
    end
end

function [nObjects,areaPx] = precomputeCellPlaneStats(cellMask)
    nZ = size(cellMask,3);
    nObjects = zeros(1,nZ);
    areaPx = zeros(1,nZ);
    for z=1:nZ
        cm = cellMask(:,:,z);
        areaPx(z) = nnz(cm);
        if areaPx(z) > 0
            tmpCC = bwconncomp(cm,8);
            nObjects(z) = tmpCC.NumObjects;
        end
    end
end

function n = countTrackedObjects3D(mask3)
    if isempty(mask3) || ~any(mask3(:))
        n = 0; return;
    end
    L = trackObjectsByPreviousPlaneOverlap(mask3);
    ids = unique(L(:)); ids(ids==0) = [];
    n = numel(ids);
end

%% ========================================================================
%  METRICS / DATASET
%  ========================================================================
function row = computePlaneMetrics(fileBase,series,z,status,raw,cellMask,degMask,px)
    rawD = double(raw);
    cellPx = nnz(cellMask);
    degPx = nnz(degMask);
    pxArea = px.x * px.y;
    ring = false(size(degMask));
    if any(degMask(:))
        ring = imdilate(degMask,strel('disk',12)) & ~imdilate(degMask,strel('disk',2));
    end
    if any(degMask(:)), meanDeg = mean(rawD(degMask),'omitnan'); else, meanDeg = NaN; end
    if any(ring(:)), meanRing = mean(rawD(ring),'omitnan'); else, meanRing = NaN; end
    drop = meanRing - meanDeg;
    if isnan(drop), dropRatio = NaN; else, dropRatio = drop/max(meanRing,eps); end
    CC = bwconncomp(degMask,8);
    cellCC = bwconncomp(cellMask,8);
    occupancy = 0;
    if cellPx > 0, occupancy = 100 * degPx / cellPx; end
    row = table(string(fileBase),series,z,string(status),true,cellCC.NumObjects,cellPx,cellPx*pxArea,degPx>0,degPx,degPx*pxArea,CC.NumObjects,occupancy,meanDeg,meanRing,drop,dropRatio,datetime('now'), ...
        'VariableNames',{'File','Position','Z','Status','Saved','Cell_Objects_2D','Cell_Area_px','Cell_Area_um2','Degradation_Present','Degradation_Area_px','Degradation_Area_um2','Degradation_Objects_2D','Degradation_Cell_Occupancy_pct','Mean_Intensity_Degradation','Mean_Intensity_Peridegradation','Local_Matrix_Drop','Local_Matrix_Drop_Ratio','Saved_Time'});
end

function T = upsertPlaneRow(T,row)
    if isempty(T) || height(T)==0
        T = row; return;
    end
    idx = find(T.Position == row.Position & T.Z == row.Z & T.File == row.File,1,'first');
    if isempty(idx)
        T = [T; row];
    else
        T(idx,:) = row;
    end
end

function T = computeStackSummary(fileBase,series,rawStack,cellMask,degMask,saved,px)
    useZ = saved(:)';
    totalPlanes = size(rawStack,3);
    if ~any(useZ), useZ = true(1,totalPlanes); end
    dm = degMask(:,:,useZ);
    cm = cellMask(:,:,useZ);
    if ndims(dm) < 3, dm = reshape(dm,size(dm,1),size(dm,2),1); end
    if ndims(cm) < 3, cm = reshape(cm,size(cm,1),size(cm,2),1); end
    voxelVol = px.x*px.y*px.z;
    pxArea = px.x*px.y;
    degVox = nnz(dm);
    cellVox = nnz(cm);
    planesWithDeg = squeeze(sum(sum(dm,1),2)) > 0;
    planesWithCell = squeeze(sum(sum(cm,1),2)) > 0;
    zLength = sum(planesWithDeg) * px.z;
    occ = 0;
    if cellVox > 0, occ = 100*degVox/cellVox; end
    projDeg = any(dm,3);
    projCell = any(cm,3);
    L = trackObjectsByPreviousPlaneOverlap(dm);
    objIDs = unique(L(:)); objIDs(objIDs==0) = [];
    cellL = trackObjectsByPreviousPlaneOverlap(cm);
    cellIDs = unique(cellL(:)); cellIDs(cellIDs==0) = [];
    areaByPlane = squeeze(sum(sum(dm,1),2)) * pxArea;
    cellAreaByPlane = squeeze(sum(sum(cm,1),2)) * pxArea;
    meanDegArea = mean(areaByPlane(planesWithDeg),'omitnan');
    if isempty(meanDegArea) || isnan(meanDegArea), meanDegArea = 0; end
    maxDegArea = max([0; areaByPlane(:)]);
    meanCellArea = mean(cellAreaByPlane(planesWithCell),'omitnan');
    if isempty(meanCellArea) || isnan(meanCellArea), meanCellArea = 0; end
    reviewedPlanes = nnz(useZ);
    noTunnelPlanes = reviewedPlanes - sum(planesWithDeg);
    reviewedPct = 100 * reviewedPlanes / max(totalPlanes,1);

    T = table(string(fileBase),series,totalPlanes,reviewedPlanes,reviewedPct,noTunnelPlanes,sum(planesWithDeg),sum(planesWithCell), ...
        degVox,degVox*voxelVol,cellVox,cellVox*voxelVol,numel(cellIDs),numel(objIDs),occ, ...
        nnz(projDeg)*pxArea,nnz(projCell)*pxArea,zLength,meanDegArea,maxDegArea,meanCellArea,datetime('now'), ...
        'VariableNames',{'File','Position','Total_Planes','Reviewed_Planes','Reviewed_pct','Planes_No_Degradation','Planes_With_Degradation','Planes_With_Cell', ...
        'Degradation_Voxels','Degradation_Volume_um3','Cell_Voxels','Cell_Volume_um3','Cell_Objects_3D','Degradation_Objects_3D_OverlapTracked','Degradation_Cell_Occupancy_pct', ...
        'Projected_Degradation_Area_um2','Projected_Cell_Area_um2','Degradation_Z_Length_um','Mean_Degradation_Area_Per_Positive_Plane_um2','Max_Degradation_Area_Per_Plane_um2','Mean_Cell_Area_Per_Cell_Plane_um2','Export_Time'});
end

function txt = formatPositionSummary(summary,objT)
    if isempty(summary) || height(summary)==0
        txt = 'Position summary unavailable.'; return;
    end
    s = summary(1,:);
    largestObj = 0;
    meanObj = 0;
    if ~isempty(objT) && height(objT)>0 && any(strcmp(objT.Properties.VariableNames,'Volume_um3'))
        largestObj = max(objT.Volume_um3);
        meanObj = mean(objT.Volume_um3,'omitnan');
    end
    lines = strings(0,1);
    lines(end+1) = sprintf('POSITION SUMMARY | %s | Position %d',char(s.File),s.Position);
    lines(end+1) = sprintf('Reviewed planes: %d/%d (%.1f%%)',s.Reviewed_Planes,s.Total_Planes,s.Reviewed_pct);
    lines(end+1) = sprintf('Cells 3D: %d | Cell volume: %.2f um^3 | Projected cell area: %.2f um^2',s.Cell_Objects_3D,s.Cell_Volume_um3,s.Projected_Cell_Area_um2);
    lines(end+1) = sprintf('Degradation/tunnel objects 3D: %d | Positive planes: %d | No-degradation planes: %d',s.Degradation_Objects_3D_OverlapTracked,s.Planes_With_Degradation,s.Planes_No_Degradation);
    lines(end+1) = sprintf('Degradation volume: %.2f um^3 | Occupancy vs cell: %.3f%% | Z length: %.2f um',s.Degradation_Volume_um3,s.Degradation_Cell_Occupancy_pct,s.Degradation_Z_Length_um);
    lines(end+1) = sprintf('Projected degradation area: %.2f um^2 | Mean positive-plane area: %.2f um^2 | Max plane area: %.2f um^2',s.Projected_Degradation_Area_um2,s.Mean_Degradation_Area_Per_Positive_Plane_um2,s.Max_Degradation_Area_Per_Plane_um2);
    lines(end+1) = sprintf('Largest degradation object: %.2f um^3 | Mean object volume: %.2f um^3',largestObj,meanObj);
    txt = strjoin(cellstr(lines),newline);
end

function T = computeObjectMetrics(fileBase,series,mask3,px)
    L = trackObjectsByPreviousPlaneOverlap(mask3);
    objIDs = unique(L(:));
    objIDs(objIDs==0) = [];
    if isempty(objIDs)
        T = table(); return;
    end
    n = numel(objIDs);
    objectID = objIDs(:);
    volumeVox = zeros(n,1);
    volumeUm3 = zeros(n,1);
    centroidX = zeros(n,1); centroidY = zeros(n,1); centroidZ = zeros(n,1);
    extentX = zeros(n,1); extentY = zeros(n,1); extentZ = zeros(n,1);
    firstZ = zeros(n,1); lastZ = zeros(n,1); planes = zeros(n,1);
    projectedArea = zeros(n,1);
    for ii = 1:n
        id = objIDs(ii);
        idx = find(L == id);
        [yy,xx,zz] = ind2sub(size(L),idx);
        volumeVox(ii) = numel(idx);
        volumeUm3(ii) = volumeVox(ii) * px.x * px.y * px.z;
        centroidX(ii) = mean(xx) * px.x;
        centroidY(ii) = mean(yy) * px.y;
        centroidZ(ii) = mean(zz) * px.z;
        extentX(ii) = (max(xx)-min(xx)+1) * px.x;
        extentY(ii) = (max(yy)-min(yy)+1) * px.y;
        extentZ(ii) = (max(zz)-min(zz)+1) * px.z;
        firstZ(ii) = min(zz);
        lastZ(ii) = max(zz);
        planes(ii) = numel(unique(zz));
        tmp = false(size(L,1),size(L,2)); tmp(sub2ind(size(tmp),yy,xx)) = true;
        projectedArea(ii) = nnz(tmp) * px.x * px.y;
    end
    T = table(repmat(string(fileBase),n,1),repmat(series,n,1),objectID,volumeVox,volumeUm3,centroidX,centroidY,centroidZ,extentX,extentY,extentZ,firstZ,lastZ,planes,projectedArea, ...
        'VariableNames',{'File','Position','Object_ID','Volume_vox','Volume_um3','Centroid_X_um','Centroid_Y_um','Centroid_Z_um','Extent_X_um','Extent_Y_um','Extent_Z_um','First_Z','Last_Z','Planes_With_Object','Projected_Area_um2'});
end

function L = trackObjectsByPreviousPlaneOverlap(mask3)
    % Track objects plane-by-plane.
    % A component in Z=k is assigned to an existing object when it overlaps
    % the previous plane. A 1-pixel tolerance is used so a slightly shifted
    % manual/SAM mask is still counted as the same tunnel/degradation.
    mask3 = logical(mask3);
    L = zeros(size(mask3),'uint16');
    nextID = uint16(1);
    if isempty(mask3) || ~any(mask3(:)), return; end
    overlapRadius = 1;
    for z = 1:size(mask3,3)
        CC = bwconncomp(mask3(:,:,z),8);
        prevLabels = [];
        prevDilated = [];
        if z > 1
            prevLabels = L(:,:,z-1);
            prevDilated = dilateLabelImage(prevLabels,overlapRadius);
        end
        for k = 1:CC.NumObjects
            pix = CC.PixelIdxList{k};
            assigned = uint16(0);
            if ~isempty(prevLabels)
                ids = unique(prevLabels(pix));
                ids(ids==0) = [];
                if isempty(ids) && ~isempty(prevDilated)
                    ids = unique(prevDilated(pix));
                    ids(ids==0) = [];
                end
                if ~isempty(ids)
                    counts = zeros(numel(ids),1);
                    for ii = 1:numel(ids)
                        counts(ii) = nnz(prevLabels(pix) == ids(ii));
                        if counts(ii) == 0 && ~isempty(prevDilated)
                            counts(ii) = nnz(prevDilated(pix) == ids(ii));
                        end
                    end
                    [~,mx] = max(counts);
                    assigned = uint16(ids(mx));
                    mergeIds = uint16(ids(ids ~= assigned));
                    for ii = 1:numel(mergeIds)
                        L(L == mergeIds(ii)) = assigned;
                    end
                end
            end
            if assigned == 0
                assigned = nextID;
                if nextID < intmax('uint16')
                    nextID = nextID + 1;
                end
            end
            plane = L(:,:,z);
            plane(pix) = assigned;
            L(:,:,z) = plane;
        end
    end
end

function out = dilateLabelImage(labelImg,radius)
    out = labelImg;
    ids = unique(labelImg(:)); ids(ids==0) = [];
    if isempty(ids) || radius <= 0, return; end
    se = strel('disk',radius);
    for ii = 1:numel(ids)
        id = ids(ii);
        region = imdilate(labelImg == id,se);
        out(region & out==0) = id;
    end
end

function [pngPath,figPath] = create3DReconstructionFromMasks(fileBase,series,cellMask,degMask,saved,px,outDir)
    % High-quality 3D reconstruction from the reviewed masks.
    % Cell mask is shown as a faint context surface; each tracked degradation
    % object gets its own color in the same figure. The MATLAB figure remains
    % open and is also saved as an editable .fig.
    renderDir = fullfile(outDir,'renders_3d');
    mkdirIfNeeded(renderDir);
    useZ = saved(:)';
    if ~any(useZ), useZ = true(1,size(degMask,3)); end
    cm = logical(cellMask(:,:,useZ));
    dm = logical(degMask(:,:,useZ));
    if ndims(cm) < 3, cm = reshape(cm,size(cm,1),size(cm,2),1); end
    if ndims(dm) < 3, dm = reshape(dm,size(dm,1),size(dm,2),1); end
    tag = sprintf('%s_3D_masks',safeName(fileBase));
    pngPath = fullfile(renderDir,[tag '.png']);
    figPath = fullfile(renderDir,[tag '.fig']);

    % Reuse an already-open QC figure for this position instead of creating a
    % hidden, closed figure that the user cannot inspect.
    figName = [fileBase ' | 3D mask QC'];
    old = findall(groot,'Type','figure','Name',figName);
    if ~isempty(old)
        f = old(1); clf(f); set(f,'Visible','on','Color','w','Position',[70 70 1180 900]);
    else
        f = figure('Visible','on','Color','w','Name',figName,'Position',[70 70 1180 900]);
    end
    ax = axes('Parent',f); hold(ax,'on'); grid(ax,'on'); view(ax,3);
    axis(ax,'vis3d'); axis(ax,'equal'); box(ax,'on');
    xlabel(ax,'X (\mum)'); ylabel(ax,'Y (\mum)'); zlabel(ax,'Z (\mum)');
    title(ax,sprintf('%s - 3D degradation objects',fileBase),'Interpreter','none','FontWeight','bold');

    plotted = false;
    legendHandles = gobjects(0);
    legendLabels = strings(0,1);

    % Moderate downsampling keeps the render usable without turning each object
    % into a crude column. Z is downsampled less aggressively than XY.
    [cmR,scaleCell] = renderVolumeFor3D(cm,280,4e5,1.0);
    [dmR,scaleDeg] = renderVolumeFor3D(dm,310,6e5,0.8);

    if any(cmR(:))
        try
            fv = isosurface(padVolumeForIso(cmR),0.5);
            fv = scaleIsoVertices(fv,px,scaleCell);
            if size(fv.faces,1) > 90000
                fv = reducepatch(fv,90000/size(fv.faces,1));
            end
            pCell = patch(ax,'Faces',fv.faces,'Vertices',fv.vertices, ...
                'FaceColor',[0.78 0.84 0.88],'EdgeColor','none','FaceAlpha',0.12, ...
                'DisplayName','Cell mask');
            try, isonormals(padVolumeForIso(cmR),pCell); catch, end
            plotted = plotted || isvalid(pCell);
            legendHandles(end+1) = pCell; %#ok<AGROW>
            legendLabels(end+1) = "Cell mask"; %#ok<AGROW>
        catch ME
            warning('DegradationAnnotation:Cell3DRender','Cell 3D render failed: %s',ME.message);
        end
    end

    L = trackObjectsByPreviousPlaneOverlap(dm);
    objIDs = unique(L(:)); objIDs(objIDs==0) = [];
    if ~isempty(objIDs)
        C = objectColorMap(numel(objIDs));
        for ii=1:numel(objIDs)
            id = objIDs(ii);
            obj = (L == id);
            if nnz(obj) < 5, continue; end
            [objR,scaleObj] = renderVolumeFor3D(obj,320,3e5,0.65);
            if ~any(objR(:)), continue; end
            try
                fv = isosurface(padVolumeForIso(objR),0.5);
                fv = scaleIsoVertices(fv,px,scaleObj);
                if size(fv.faces,1) > 65000
                    fv = reducepatch(fv,65000/size(fv.faces,1));
                end
                pObj = patch(ax,'Faces',fv.faces,'Vertices',fv.vertices, ...
                    'FaceColor',C(ii,:),'EdgeColor','none','FaceAlpha',0.82, ...
                    'DisplayName',sprintf('Degradation %d',ii));
                try, isonormals(padVolumeForIso(objR),pObj); catch, end
                plotted = plotted || isvalid(pObj);
                if numel(objIDs) <= 20
                    legendHandles(end+1) = pObj; %#ok<AGROW>
                    legendLabels(end+1) = sprintf('Deg %d',ii); %#ok<AGROW>
                end
            catch ME
                warning('DegradationAnnotation:Deg3DRender','Degradation object %d render failed: %s',ii,ME.message);
            end
        end
    end

    if ~plotted
        text(ax,0.5,0.5,0.5,'No saved masks to render','Units','normalized','HorizontalAlignment','center');
    end
    camlight(ax,'headlight'); camlight(ax,'right'); lighting(ax,'gouraud'); material(ax,'dull');
    rotate3d(f,'on');
    if ~isempty(legendHandles)
        legend(ax,legendHandles,cellstr(legendLabels),'Location','northeastoutside');
    end
    drawnow;
    try savefig(f,figPath,'compact'); catch, try savefig(f,figPath); catch, end, end
    try exportgraphics(f,pngPath,'Resolution',200); catch, saveas(f,pngPath); end
    try openfig(figPath,'reuse','visible'); catch, figure(f); end
end


function excelPath = robustWritePositionWorkbook(excelPath,planeRows,summary,objT,outDir,fileBase,logger)
    % Write the position workbook without blocking 3D rendering. Excel files in
    % OneDrive folders are often temporarily locked or left in a corrupt state.
    % This writes first to a temporary workbook, then moves it into place. If the
    % requested name is locked, a timestamped fallback workbook is used; if Excel
    % writing fails completely, CSV fallbacks are still written.
    if nargin < 7, logger = []; end
    metricsDir = fileparts(excelPath);
    mkdirIfNeeded(metricsDir);
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    tmpXlsx = fullfile(metricsDir,[safeName(fileBase) '_tmp_' stamp '.xlsx']);
    cleanupTmp = onCleanup(@()deleteIfExists(tmpXlsx)); %#ok<NASGU>
    try
        if ~isempty(planeRows), writetable(planeRows,tmpXlsx,'Sheet','Planes'); end
        writetable(summary,tmpXlsx,'Sheet','Stack_Summary');
        if ~isempty(objT), writetable(objT,tmpXlsx,'Sheet','Objects_3D'); end
        excelPath = moveWorkbookIntoPlace(tmpXlsx,excelPath,logger);
    catch ME
        callLogger(logger,['WARNING: Excel workbook could not be written. CSV fallbacks will be used. ' ME.message]);
        fallbackDir = fullfile(outDir,'metrics','excel_write_fallback_csv');
        mkdirIfNeeded(fallbackDir);
        if ~isempty(planeRows), safeWriteTable(planeRows,fullfile(fallbackDir,[safeName(fileBase) '_planes.csv']),'Planes CSV',logger); end
        safeWriteTable(summary,fullfile(fallbackDir,[safeName(fileBase) '_stack_summary.csv']),'Stack summary CSV',logger);
        if ~isempty(objT), safeWriteTable(objT,fullfile(fallbackDir,[safeName(fileBase) '_objects_3d.csv']),'Objects 3D CSV',logger); end
        excelPath = fullfile(fallbackDir,[safeName(fileBase) '_CSV_FALLBACK_USED.txt']);
        writeTextFile(excelPath,'Excel workbook could not be written. Use the CSV files in this folder.');
    end
end

function robustWriteAggregateWorkbook(aggXlsx,overview,allSummary,allPlanes,allObjects)
    aggDir = fileparts(aggXlsx);
    mkdirIfNeeded(aggDir);
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    tmpXlsx = fullfile(aggDir,['file_run_summary_tmp_' stamp '.xlsx']);
    cleanupTmp = onCleanup(@()deleteIfExists(tmpXlsx)); %#ok<NASGU>
    writetable(overview,tmpXlsx,'Sheet','File_Overview');
    if ~isempty(allSummary), writetable(allSummary,tmpXlsx,'Sheet','Position_Summaries'); end
    if ~isempty(allPlanes),  writetable(allPlanes, tmpXlsx,'Sheet','All_Planes'); end
    if ~isempty(allObjects), writetable(allObjects,tmpXlsx,'Sheet','All_Degradation_Objects'); end
    moveWorkbookIntoPlace(tmpXlsx,aggXlsx,[]);
end

function finalPath = moveWorkbookIntoPlace(tmpXlsx,dest,logger)
    folder = fileparts(dest);
    mkdirIfNeeded(folder);
    [~,base,ext] = fileparts(dest);
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    finalPath = dest;
    if exist(dest,'file') == 2
        try
            delete(dest);
        catch
            finalPath = fullfile(folder,[base '_fallback_' stamp ext]);
            callLogger(logger,['Target workbook is locked; using fallback name: ' finalPath]);
        end
    end
    try
        movefile(tmpXlsx,finalPath,'f');
    catch ME
        finalPath = fullfile(folder,[base '_fallback_' stamp ext]);
        try
            movefile(tmpXlsx,finalPath,'f');
        catch ME2
            error('Could not move workbook into place. Primary: %s | Fallback: %s',ME.message,ME2.message);
        end
    end
end

function ok = safeWriteTable(T,pathOut,description,logger)
    ok = false;
    if nargin < 4, logger = []; end
    if isempty(T), ok = true; return; end
    mkdirIfNeeded(fileparts(pathOut));
    try
        writetable(T,pathOut);
        ok = true;
    catch ME
        [folder,base,ext] = fileparts(pathOut);
        if isempty(ext), ext = '.csv'; end
        fallback = fullfile(folder,[base '_fallback_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) ext]);
        try
            writetable(T,fallback);
            ok = true;
            callLogger(logger,[description ' locked/unwritable; saved fallback: ' fallback]);
        catch ME2
            callLogger(logger,['WARNING: could not write ' description '. ' ME.message ' | fallback failed: ' ME2.message]);
        end
    end
end

function callLogger(logger,msg)
    if isa(logger,'function_handle')
        try logger(msg); catch, end
    end
end

function savedPath = robustSaveProjectMat(dest,project)
    folder = fileparts(dest);
    mkdirIfNeeded(folder);
    [~,base] = fileparts(dest);
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    tmp = [tempname(folder) '.mat'];
    savedPath = dest;
    cleanupTmp = onCleanup(@()deleteIfExists(tmp)); %#ok<NASGU>
    try
        save(tmp,'project','-v7');
    catch
        deleteIfExists(tmp);
        save(tmp,'project','-v7.3');
    end
    if exist(dest,'file') == 2
        backup = fullfile(folder,[base '_previous_' stamp '.mat']);
        try
            movefile(dest,backup,'f');
        catch
            try
                delete(dest);
            catch
                % Keep the corrupt/locked destination and fall back to a timestamped file.
            end
        end
    end
    try
        movefile(tmp,dest,'f');
        savedPath = dest;
    catch
        fallback = fullfile(folder,[base '_saved_' stamp '.mat']);
        movefile(tmp,fallback,'f');
        savedPath = fallback;
    end
end

function deleteIfExists(p)
    try
        if exist(p,'file') == 2, delete(p); end
    catch
    end
end

function [V,scale] = renderVolumeFor3D(V,maxDim,maxVoxels,smoothSigma)
    V = logical(V);
    scale = [1 1 1];
    if isempty(V) || ~any(V(:)), return; end
    sz = size(V);
    if numel(sz)<3, sz(3)=1; end
    stepXY = max(1,ceil(max(sz(1:2))/maxDim));
    stepZ = max(1,ceil((numel(V)/maxVoxels)/(stepXY^2)));
    % Preserve Z continuity better than the old quick render.
    stepZ = min(stepZ, max(1,ceil(size(V,3)/90)));
    V = V(1:stepXY:end,1:stepXY:end,1:stepZ:end);
    scale = [stepXY stepXY stepZ];
    if any(V(:)) && smoothSigma > 0
        try
            Vd = smooth3(double(V),'gaussian',[5 5 3],smoothSigma);
            V = Vd > 0.22;
        catch
        end
    end
end

function fv = scaleIsoVertices(fv,px,scale)
    % isosurface vertices are in [row col z] order for array dimensions.
    % Display as X=columns, Y=rows, Z=planes.
    if isempty(fv.vertices), return; end
    v = fv.vertices;
    fv.vertices(:,1) = v(:,2) * px.x * scale(2);
    fv.vertices(:,2) = v(:,1) * px.y * scale(1);
    fv.vertices(:,3) = v(:,3) * px.z * scale(3);
end

function C = objectColorMap(n)
    if n <= 0, C = zeros(0,3); return; end
    try
        C = lines(n);
    catch
        h = linspace(0,1,n+1)'; h(end)=[];
        C = hsv2rgb([h 0.78*ones(n,1) 0.92*ones(n,1)]);
    end
    if n > 7
        h = linspace(0,1,n+1)'; h(end)=[];
        C = hsv2rgb([h 0.78*ones(n,1) 0.90*ones(n,1)]);
    end
end

function V = padVolumeForIso(V)
    V = logical(V);
    if size(V,3) < 2
        V = cat(3,false(size(V,1),size(V,2)),V,false(size(V,1),size(V,2)));
    else
        V = padarray(V,[1 1 1],false,'both');
    end
end

function writeDatasetManifest(outDir,fileBase,nZ,px,imageBase)
    if nargin < 5 || isempty(imageBase), imageBase = fileBase; end
    M = struct();
    M.fileBase = fileBase;
    M.imageBase = imageBase;
    M.numPlanes = nZ;
    M.pixelSize_um = px;
    M.images = 'images/*.png';
    M.masks_degradation = 'masks_degradation/*.png';
    M.masks_cell = 'masks_cell/*.png';
    M.masks_multiclass = 'masks_multiclass/*.png';
    M.multiclass_encoding = struct('background',0,'cell',1,'degradation_tunnel',2);
    writeTextFile(fullfile(outDir,'dataset_manifest.json'),jsonencode(M,'PrettyPrint',true));
end

%% ========================================================================
%  SAM SETTINGS
%  ========================================================================
function SAM = loadSamPrefs(moduleDir)
    SAM = struct('pythonExe','','repoRoot','','checkpoint','','config','','fastBridge','','validated',false);
    try
        if ispref('DegradationSAM2','settings')
            S = getpref('DegradationSAM2','settings');
            f = fieldnames(S);
            for k=1:numel(f), SAM.(f{k}) = S.(f{k}); end
        end
    catch
    end
    jsonPath = fullfile(moduleDir,'sam2_config.json');
    if exist(jsonPath,'file')
        try
            J = jsondecode(fileread(jsonPath));
            f = fieldnames(J);
            for k=1:numel(f)
                if isfield(SAM,f{k}) && isempty(SAM.(f{k}))
                    SAM.(f{k}) = char(J.(f{k}));
                end
            end
        catch
        end
    end
    SAM.fastBridge = ensureFastSamBridge();
end

function saveSamPrefs(SAM,moduleDir)
    try setpref('DegradationSAM2','settings',SAM); catch, end
    try
        J = struct('pythonExe',SAM.pythonExe,'repoRoot',SAM.repoRoot,'checkpoint',SAM.checkpoint,'config',SAM.config);
        writeTextFile(fullfile(moduleDir,'sam2_config.json'),jsonencode(J,'PrettyPrint',true));
    catch
    end
end

%% ========================================================================
%  GENERAL HELPERS
%  ========================================================================
function files = discoverLauncherLIFs(fig_launcher)
    files = {};
    try
        if exist('fig_launcher','var') && isvalid(fig_launcher) && isstruct(fig_launcher.UserData)
            U = fig_launcher.UserData;
            candidates = {'fileLIFs','SelectedLIFs','LoadedLIFs','InputLIFs','InputFiles','Files'};
            for i=1:numel(candidates)
                if isfield(U,candidates{i})
                    v = U.(candidates{i});
                    if ischar(v) || isstring(v), v = cellstr(v); end
                    if iscell(v)
                        lifs = v(endsWith(lower(string(v)),'.lif'));
                        if ~isempty(lifs), files = cellstr(lifs); return; end
                    end
                end
            end
        end
    catch
    end
end

function out = discoverGlobalOutputDir(fig_launcher)
    out = '';
    try
        if exist('fig_launcher','var') && isvalid(fig_launcher) && isstruct(fig_launcher.UserData) && isfield(fig_launcher.UserData,'GlobalOutputDir')
            out = fig_launcher.UserData.GlobalOutputDir;
        end
    catch
    end
end

function tf = isvalidTable(T)
    tf = istable(T) && height(T) >= 0;
end

function m = isolateConnectedComponentAtPoint(mask,x,y)
    m = false(size(mask));
    if x<1 || y<1 || x>size(mask,2) || y>size(mask,1) || ~mask(y,x), return; end
    CC = bwconncomp(mask,8);
    lin = sub2ind(size(mask),y,x);
    for k=1:CC.NumObjects
        if any(CC.PixelIdxList{k} == lin)
            m(CC.PixelIdxList{k}) = true;
            return;
        end
    end
end


function T = mergePlaneTables(Told,Tnew)
    if isempty(Told) || ~istable(Told) || height(Told)==0
        T = Tnew; return;
    end
    if isempty(Tnew) || ~istable(Tnew) || height(Tnew)==0
        T = Told; return;
    end
    T = Told;
    for i=1:height(Tnew)
        row = Tnew(i,:);
        try
            idx = find(T.File == row.File & T.Position == row.Position & T.Z == row.Z,1,'first');
        catch
            idx = [];
        end
        if isempty(idx)
            T = [T; row]; %#ok<AGROW>
        else
            T(idx,:) = row;
        end
    end
end

function updateFileRunAggregate(fileRunDir,posOutDir,fileBase,summary,objT,planeRows)
    % Writes a file-level Excel that accumulates every position reviewed in the
    % current run. It is deliberately rebuilt on each finish so re-finishing a
    % position replaces its old rows instead of duplicating them.
    if isempty(fileRunDir) || ~exist(fileRunDir,'dir'), return; end
    aggDir = fullfile(fileRunDir,'aggregate_metrics');
    mkdirIfNeeded(aggDir);
    aggXlsx = fullfile(aggDir,'file_run_summary.xlsx');

    oldSummary = readTableSheetIfExists(aggXlsx,'Position_Summaries');
    oldPlanes  = readTableSheetIfExists(aggXlsx,'All_Planes');
    oldObjects = readTableSheetIfExists(aggXlsx,'All_Degradation_Objects');

    pos = NaN;
    if ~isempty(summary) && istable(summary) && height(summary)>0 && any(strcmp(summary.Properties.VariableNames,'Position'))
        pos = summary.Position(1);
    elseif ~isempty(planeRows) && istable(planeRows) && height(planeRows)>0 && any(strcmp(planeRows.Properties.VariableNames,'Position'))
        pos = planeRows.Position(1);
    end

    if ~isempty(oldSummary) && istable(oldSummary) && ~isnan(pos) && any(strcmp(oldSummary.Properties.VariableNames,'Position'))
        oldSummary(oldSummary.Position == pos,:) = [];
    end
    if ~isempty(summary) && istable(summary) && height(summary)>0
        summary.Position_Output_Folder = repmat(string(posOutDir),height(summary),1);
        if isempty(oldSummary), allSummary = summary; else, allSummary = [oldSummary; summary]; end
    else
        allSummary = oldSummary;
    end

    if ~isempty(oldPlanes) && istable(oldPlanes) && ~isnan(pos) && any(strcmp(oldPlanes.Properties.VariableNames,'Position'))
        oldPlanes(oldPlanes.Position == pos,:) = [];
    end
    if ~isempty(planeRows) && istable(planeRows) && height(planeRows)>0
        if isempty(oldPlanes), allPlanes = planeRows; else, allPlanes = [oldPlanes; planeRows]; end
    else
        allPlanes = oldPlanes;
    end

    if ~isempty(oldObjects) && istable(oldObjects) && ~isnan(pos) && any(strcmp(oldObjects.Properties.VariableNames,'Position'))
        oldObjects(oldObjects.Position == pos,:) = [];
    end
    if ~isempty(objT) && istable(objT) && height(objT)>0
        if isempty(oldObjects), allObjects = objT; else, allObjects = [oldObjects; objT]; end
    else
        allObjects = oldObjects;
    end

    overview = buildFileRunOverview(fileBase,fileRunDir,allSummary,allObjects,allPlanes);
    try
        robustWriteAggregateWorkbook(aggXlsx,overview,allSummary,allPlanes,allObjects);
    catch ME
        % Never let an aggregate workbook locked by Excel/OneDrive stop the
        % position export. Keep CSV fallbacks next to the aggregate folder.
        safeWriteTable(overview,fullfile(aggDir,'file_overview.csv'),'aggregate overview CSV',[]);
        safeWriteTable(allSummary,fullfile(aggDir,'position_summaries.csv'),'aggregate position CSV',[]);
        safeWriteTable(allPlanes,fullfile(aggDir,'all_planes.csv'),'aggregate planes CSV',[]);
        safeWriteTable(allObjects,fullfile(aggDir,'all_degradation_objects.csv'),'aggregate objects CSV',[]);
        warning('DegradationAnnotation:AggregateWorkbook','Aggregate workbook failed: %s',ME.message);
    end
    writeTextFile(fullfile(aggDir,'file_run_summary.txt'),formatFileRunOverview(overview));
end

function T = readTableSheetIfExists(xlsxPath,sheetName)
    T = table();
    if ~exist(xlsxPath,'file'), return; end
    try
        T = readtable(xlsxPath,'Sheet',sheetName,'VariableNamingRule','preserve');
    catch
        T = table();
    end
end

function overview = buildFileRunOverview(fileBase,fileRunDir,S,O,P)
    if nargin < 4, O = table(); end
    if nargin < 5, P = table(); end
    positionsAnalysed = 0;
    reviewedPlanes = 0;
    totalPlanes = 0;
    cellObjects = 0;
    degObjects = 0;
    cellVolume = 0;
    degVolume = 0;
    projectedCellArea = 0;
    projectedDegArea = 0;
    meanOcc = NaN;
    positivePlanes = 0;
    noDegPlanes = 0;
    if ~isempty(S) && istable(S) && height(S)>0
        if any(strcmp(S.Properties.VariableNames,'Position')), positionsAnalysed = numel(unique(S.Position)); else, positionsAnalysed = height(S); end
        reviewedPlanes = sumColumnIfExists(S,'Reviewed_Planes');
        totalPlanes = sumColumnIfExists(S,'Total_Planes');
        cellObjects = sumColumnIfExists(S,'Cell_Objects_3D');
        degObjects = sumColumnIfExists(S,'Degradation_Objects_3D_OverlapTracked');
        cellVolume = sumColumnIfExists(S,'Cell_Volume_um3');
        degVolume = sumColumnIfExists(S,'Degradation_Volume_um3');
        projectedCellArea = sumColumnIfExists(S,'Projected_Cell_Area_um2');
        projectedDegArea = sumColumnIfExists(S,'Projected_Degradation_Area_um2');
        positivePlanes = sumColumnIfExists(S,'Planes_With_Degradation');
        noDegPlanes = sumColumnIfExists(S,'Planes_No_Degradation');
        if any(strcmp(S.Properties.VariableNames,'Degradation_Cell_Occupancy_pct'))
            meanOcc = mean(S.Degradation_Cell_Occupancy_pct,'omitnan');
        end
    end
    objectRows = 0;
    meanObjVol = NaN;
    maxObjVol = 0;
    if ~isempty(O) && istable(O) && height(O)>0
        objectRows = height(O);
        if any(strcmp(O.Properties.VariableNames,'Volume_um3'))
            meanObjVol = mean(O.Volume_um3,'omitnan');
            maxObjVol = max([0; O.Volume_um3(:)]);
        end
    end
    savedPlaneRows = 0;
    if ~isempty(P) && istable(P), savedPlaneRows = height(P); end
    [~,fileFolderName] = fileparts(fileRunDir);
    if isempty(fileFolderName), fileFolderName = erasePosSuffix(fileBase); end
    overview = table(string(fileFolderName),string(fileRunDir),positionsAnalysed,totalPlanes,reviewedPlanes,savedPlaneRows, ...
        cellObjects,cellVolume,projectedCellArea,degObjects,objectRows,degVolume,projectedDegArea,positivePlanes,noDegPlanes,meanOcc,meanObjVol,maxObjVol,datetime('now'), ...
        'VariableNames',{'File','File_Run_Folder','Positions_Analysed','Total_Planes','Reviewed_Planes','Saved_Plane_Rows', ...
        'Cell_Objects_3D_Total','Cell_Volume_um3_Total','Projected_Cell_Area_um2_Total','Degradation_Objects_3D_Total','Degradation_Object_Rows','Degradation_Volume_um3_Total','Projected_Degradation_Area_um2_Total','Positive_Planes_Total','No_Degradation_Planes_Total','Mean_Position_Occupancy_pct','Mean_Degradation_Object_Volume_um3','Largest_Degradation_Object_um3','Updated_Time'});
end

function v = sumColumnIfExists(T,varName)
    if any(strcmp(T.Properties.VariableNames,varName))
        v = sum(T.(varName),'omitnan');
    else
        v = 0;
    end
end

function txt = formatFileRunOverview(T)
    if isempty(T) || height(T)==0
        txt = 'File run overview unavailable.'; return;
    end
    t = T(1,:);
    lines = strings(0,1);
    lines(end+1) = sprintf('FILE RUN SUMMARY | %s',char(t.File));
    lines(end+1) = sprintf('Positions analysed: %d | Reviewed planes: %d/%d',t.Positions_Analysed,t.Reviewed_Planes,t.Total_Planes);
    lines(end+1) = sprintf('Cells 3D total: %d | Cell volume total: %.2f um^3 | Projected cell area total: %.2f um^2',t.Cell_Objects_3D_Total,t.Cell_Volume_um3_Total,t.Projected_Cell_Area_um2_Total);
    lines(end+1) = sprintf('Degradation/tunnel objects 3D total: %d | Positive planes total: %d | No-degradation planes total: %d',t.Degradation_Objects_3D_Total,t.Positive_Planes_Total,t.No_Degradation_Planes_Total);
    lines(end+1) = sprintf('Degradation volume total: %.2f um^3 | Mean position occupancy: %.3f%%',t.Degradation_Volume_um3_Total,t.Mean_Position_Occupancy_pct);
    lines(end+1) = sprintf('Mean degradation object volume: %.2f um^3 | Largest degradation object: %.2f um^3',t.Mean_Degradation_Object_Volume_um3,t.Largest_Degradation_Object_um3);
    lines(end+1) = sprintf('Folder: %s',char(t.File_Run_Folder));
    txt = strjoin(cellstr(lines),newline);
end

function s = erasePosSuffix(fileBase)
    s = regexprep(char(fileBase),'_pos_\d+$','');
end

function dirOut = nextRunDir(rootDir)
    mkdirIfNeeded(rootDir);
    d = dir(fullfile(rootDir,'Run_*'));
    nums = [];
    for i=1:numel(d)
        if d(i).isdir
            tok = regexp(d(i).name,'Run_(\d+)','tokens','once');
            if ~isempty(tok), nums(end+1) = str2double(tok{1}); end %#ok<AGROW>
        end
    end
    if isempty(nums), n=1; else, n=max(nums)+1; end
    dirOut = fullfile(rootDir,sprintf('Run_%03d',n));
    mkdirIfNeeded(dirOut);
end

function mkdirIfNeeded(p)
    if ~exist(p,'dir'), mkdir(p); end
end

function writeTextFile(path,txt)
    fid = fopen(path,'w');
    if fid<0, error('Cannot write file: %s',path); end
    cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
    fwrite(fid,txt,'char');
end

function n = getFileName(p)
    [~,name,ext] = fileparts(char(p)); n = [name ext];
end

function b = eraseExt(p)
    [~,b] = fileparts(char(p));
end

function s = safeName(s)
    s = char(s);
    s = regexprep(s,'[\\/:*?"<>|\s]+','_');
    if isempty(s), s='degradation_annotation'; end
    if numel(s)>90, s=s(1:90); end
end

function q = shellQuote(s)
    s = char(s);
    q = ['"' s '"'];
end

function txt = workflowText()
    txt = { ...
        'SAM2-ASSISTED DEGRADATION/TUNNEL ANNOTATION WORKFLOW', ...
        '', ...
        'Goal: annotate degradations/tunnels plane-by-plane with one-click SAM2 help, while saving metrics and training masks.', ...
        '', ...
        'Main controls:', ...
        '  Load .LIF file(s) once in the application. The annotation workspace reuses that file; it should not ask again.', ...
        '  Choose file, position/series, degradation channel and cell channel.', ...
        '  Press Validate/load SAM2 once. The first load can be slow; clicks should then be much faster.', ...
        '  Press Start annotation workspace.', ...
        '', ...
        'Workspace controls:', ...
        '  Left click on image       = SAM2 adds the clicked degradation/tunnel region.', ...
        '  Right click on red mask   = instant isolate of that connected component.', ...
        '  Right click outside mask  = SAM2 replaces current plane mask with clicked region.', ...
        '  ACCEPT tunnel + next      = saves image, tunnel mask, cell mask, multiclass mask and metrics, then next Z. If tunnel mask has 0 px, it is automatically saved as NO TUNNEL.', ...
        '  NO TUNNEL + next          = saves image + cell mask + empty tunnel mask, then next Z.', ...
        '  Brush add/erase           = manual correction without SAM.', ...
        '', ...
        'Keyboard shortcuts:', ...
        '  Right arrow / D = next plane', ...
        '  Left arrow / A  = previous plane', ...
        '  Space / Enter   = accept current plane and next', ...
        '  N               = no tunnel, save cell and next', ...
        '  C               = clear tunnel mask', ...
        '  Z               = undo current plane mask', ...
        '  S               = save project', ...
        '', ...
        'Saved dataset:', ...
        '  images/*.png', ...
        '  masks_degradation/*.png', ...
        '  masks_cell/*.png', ...
        '  masks_multiclass/*.png     0=background, 1=cell, 2=degradation/tunnel', ...
        '  metrics/plane_metrics.csv', ...
        '  metrics/*_manual_degradation_metrics.xlsx + renders_3d/*.png/*.fig after Finish + Excel + 3D', ...
        '  One session run groups all analysed positions from the same .LIF under Run_YYYYMMDD_HHMMSS/<file>/posX, with short filenames such as pos1_z001.png.', ...
        '  The file-level aggregate is updated at <file>/aggregate_metrics/file_run_summary.xlsx.' ...
        }';
end
