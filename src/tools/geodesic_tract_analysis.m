function geodesic_tract_analysis(fig_launcher)
    % Geodesic Tract Analysis
    % Standardized: English UI, robust .fig export, and dynamic tab generation per position.
    % WITH AUTOMATIC HIERARCHICAL FOLDER SAVING
    
    %% 1. ANALYSIS STATE
    appState.fileLIF = '';
    appState.fileName = '';
    appState.basePath = '';
    appState.outDir = '';
    
    appState.results = []; 
    appState.pxX = 1; appState.pxY = 1; appState.pxZ = 1;
    
    % Fixed processing parameters
    OPTS.ch_fibers = 1;
    OPTS.ch_cells  = 2;
    OPTS.max_cells_per_fov = 15;  
    OPTS.colormap_name = 'hsv';   
    OPTS.mesh_smooth_iter = 3; 
    
    %% 2. UI CONSTRUCTION (ENGLISH)
    fig_mod = uifigure('Name', 'Geodesic Tract Analysis', 'Color', 'k');
    fig_mod.WindowState = 'maximized'; 
    fig_mod.CloseRequestFcn = @closeModule;
    
    gl = uigridlayout(fig_mod, [1 2]);
    gl.ColumnWidth = {360, '1x'};
    gl.BackgroundColor = 'k';
    
    pnl_ctrl = uipanel(gl, 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', 'w', 'Title', 'Batch Process Control');
    gl_ctrl = uigridlayout(pnl_ctrl, [8 1]);
    gl_ctrl.RowHeight = {40, 50, 160, 30, 40, '1x', 40, 40}; 
    gl_ctrl.BackgroundColor = [0.1 0.1 0.1];
    
    btn_load = uibutton(gl_ctrl, 'Text', '1. Load .LIF File', 'BackgroundColor', [0.2 0.4 0.6], 'FontColor', 'w', 'ButtonPushedFcn', @loadFile);
    lbl_file = uilabel(gl_ctrl, 'Text', 'Waiting for file...', 'WordWrap', 'on', 'FontColor', [0.7 0.7 0.7]);
    
    % --- DYNAMIC PARAMETERS PANEL ---
    pnl_params = uipanel(gl_ctrl, 'Title', 'Global Filter Parameters', 'BackgroundColor', [0.15 0.15 0.15], 'ForegroundColor', 'w');
    gl_params = uigridlayout(pnl_params, [4 2]);
    gl_params.ColumnWidth = {'1x', 60}; gl_params.RowHeight = {25, 25, 25, 25};
    gl_params.BackgroundColor = [0.15 0.15 0.15];
    
    uilabel(gl_params, 'Text', 'Downsample Factor:', 'FontColor', 'w');
    ui_down = uieditfield(gl_params, 'numeric', 'Value', 2, 'Limits', [1 10], 'RoundFractionalValues', 'on');
    
    uilabel(gl_params, 'Text', 'Min. Cell Vol (\mum^3):', 'FontColor', 'w');
    ui_vol = uieditfield(gl_params, 'numeric', 'Value', 500, 'Limits', [1 10000]);
    
    uilabel(gl_params, 'Text', 'Fibers Sigma:', 'FontColor', 'w');
    ui_sigma = uieditfield(gl_params, 'numeric', 'Value', 3, 'Limits', [0.1 10]);
    
    uilabel(gl_params, 'Text', 'Path Thickness (Mult):', 'FontColor', 'w');
    ui_thick = uieditfield(gl_params, 'numeric', 'Value', 1.05, 'Limits', [1.0 3.0]);
    % ---------------------------------------

    % --- HELP BUTTON FOR TUNING ---
    uibutton(gl_ctrl, 'Text', 'Parameter Tuning Guide', 'BackgroundColor', [0.3 0.3 0.3], 'FontColor', 'y', 'ButtonPushedFcn', @showHelpGuide);

    btn_run  = uibutton(gl_ctrl, 'Text', '2. RUN TOTAL BATCH', 'Enable', 'off', 'BackgroundColor', [0.1 0.6 0.2], 'FontColor', 'w', 'FontSize', 14, 'FontWeight', 'bold', 'ButtonPushedFcn', @runBatchAnalysis);
    
    txt_log = uitextarea(gl_ctrl, 'Editable', 'off', 'BackgroundColor', 'k', 'FontColor', [0 0.8 0], 'FontName', 'Consolas');
    txt_log.Value = {'[Geodesic Tract Analysis] Ready.', 'Automatic Hierarchical Saving Enabled.'};
    
    lbl_progress = uilabel(gl_ctrl, 'Text', 'Progress: 0%', 'FontColor', 'c', 'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    
    uibutton(gl_ctrl, 'Text', '< Back to Main Menu', 'BackgroundColor', [0.4 0.1 0.1], 'FontColor', 'w', 'ButtonPushedFcn', @(btn,event) close(fig_mod));
    
    % Right Viewers
    tg_view = uitabgroup(gl);
    
    tab_table = uitab(tg_view, 'Title', 'Live Registry', 'BackgroundColor', 'k');
    gl_table = uigridlayout(tab_table, [1 1]); gl_table.Padding = [0 0 0 0];
    uit_results = uitable(gl_table, 'Data', [], 'BackgroundColor', [0.9 0.9 0.9]);
    
    %% 3. CONTROL FUNCTIONS
    function logMessage(msg)
        txt_log.Value = [txt_log.Value; {['> ' msg]}]; scroll(txt_log, 'bottom'); drawnow;
    end

    function closeModule(~, ~)
        delete(fig_mod);
        if exist('fig_launcher', 'var') && isvalid(fig_launcher)
            fig_launcher.Visible = 'on'; 
        end
    end

    function loadFile(~, ~)
        if exist('bfGetReader','file') == 0, uialert(fig_mod, 'Bio-Formats missing from MATLAB Path.', 'Error'); return; end
        [file, path] = uigetfile('*.lif', 'Select .LIF file');
        if isequal(file, 0), return; end
        
        appState.fileLIF = fullfile(path, file);
        appState.basePath = path;
        appState.fileName = file;
        lbl_file.Text = file;
        logMessage(['Loaded: ' file]);
        btn_run.Enable = 'on';
    end

    function showHelpGuide(~, ~)
        msg = ["CALIBRATION HEURISTICS:", ...
               "", ...
               "1. Downsample Factor", ...
               "- Reduces 3D resolution to drastically speed up processing.", ...
               "- 2 is standard. Increase to 3 or 4 for massive datasets or if RAM crashes.", ...
               "", ...
               "2. Min. Cell Vol (\mum^3)", ...
               "- Destroys noise and tiny floating debris. 500 is the standard threshold.", ...
               "- If the algorithm hallucinates cell-to-cell paths with dead debris, INCREASE this value.", ...
               "", ...
               "3. Fibers Sigma", ...
               "- Smooths the fiber signal to calculate the geodesic 'cost map'.", ...
               "- If fibers are very patchy and paths look unnatural, INCREASE value (e.g., 5.0).", ...
               "", ...
               "4. Path Thickness (Mult)", ...
               "- Expands the mathematical width of the detected geodesic tract.", ...
               "- 1.05 captures the precise thin core. Increase to 1.5 if you want to capture the whole thick bundle."];
        uialert(fig_mod, sprintf('%s\n', msg), 'Parameter Tuning Guide', 'Icon', 'info');
    end

    %% 4. BATCH ENGINE (WITH AUTO FOLDERS)
    function runBatchAnalysis(~, ~)
        
        % AUTOMATIC FOLDER LOGIC
        globalOutDir = '';
        if exist('fig_launcher', 'var') && isvalid(fig_launcher)
            if isstruct(fig_launcher.UserData) && isfield(fig_launcher.UserData, 'GlobalOutputDir')
                globalOutDir = fig_launcher.UserData.GlobalOutputDir;
            end
        end
        
        % Fallback if opened without launcher
        if isempty(globalOutDir)
            globalOutDir = uigetdir(appState.basePath, 'Select Root Global Destination Folder');
            if globalOutDir == 0
                logMessage('Operation cancelled by user.');
                return; 
            end
        end
        
        % 1. Analysis folder
        modDir = fullfile(globalOutDir, 'Geodesic_Tract_Analysis');
        if ~exist(modDir, 'dir'), mkdir(modDir); end
        
        % 2. Scan for existing "Run_" folders to determine the next number
        existingRuns = dir(fullfile(modDir, 'Run_*'));
        runNum = 1;
        if ~isempty(existingRuns)
            nums = zeros(1, length(existingRuns));
            for i = 1:length(existingRuns)
                if existingRuns(i).isdir
                    token = regexp(existingRuns(i).name, 'Run_(\d+)', 'tokens');
                    if ~isempty(token)
                        nums(i) = str2double(token{1}{1});
                    end
                end
            end
            if any(nums > 0)
                runNum = max(nums) + 1;
            end
        end
        
        % 3. Create current Run folder and subfolders
        appState.outDir = fullfile(modDir, sprintf('Run_%d', runNum));
        mkdir(appState.outDir);
        
        excelPath = fullfile(appState.outDir, 'Inertia_Excel');
        imgPath = fullfile(appState.outDir, 'Inertia_Images_3D');
        figPath = fullfile(appState.outDir, 'Inertia_FIG_Editable');
        mkdir(excelPath); mkdir(imgPath); mkdir(figPath);
        
        logMessage(sprintf('Outputs will be saved automatically to: %s', appState.outDir));
        
        [~, cleanName, ~] = fileparts(appState.fileName);
        cleanName = regexprep(cleanName, '[\\/*?:"<>| ]', '_');
        
        btn_run.Enable = 'off'; btn_load.Enable = 'off';
        
        % Clean up previous render tabs if running again
        all_tabs = tg_view.Children;
        for t = 1:length(all_tabs)
            if contains(all_tabs(t).Title, 'Render Pos')
                delete(all_tabs(t));
            end
        end
        
        OPTS.downsample_factor = ui_down.Value;
        OPTS.min_cell_vol_um3  = ui_vol.Value;
        OPTS.sigma_smooth_fibers = ui_sigma.Value;
        OPTS.path_thickness    = ui_thick.Value;
        
        logMessage('Starting Batch Processing...');
        appState.results = []; 
        
        try
            reader = bfGetReader(appState.fileLIF);
            numSeries = reader.getSeriesCount();
            omeMeta = reader.getMetadataStore();
            
            logMessage(sprintf('Detected %d positions. Starting sweep...', numSeries));
            
            for s = 1:numSeries
                logMessage(sprintf('--- Analyzing Position %d of %d ---', s, numSeries));
                lbl_progress.Text = sprintf('Progress: %d / %d (%.1f%%)', s, numSeries, (s/numSeries)*100);
                drawnow; 
                
                reader.setSeries(s-1);
                
                try appState.pxX = omeMeta.getPixelsPhysicalSizeX(s-1).value().doubleValue(); catch, appState.pxX = 1; end
                try appState.pxY = omeMeta.getPixelsPhysicalSizeY(s-1).value().doubleValue(); catch, appState.pxY = 1; end
                try appState.pxZ = omeMeta.getPixelsPhysicalSizeZ(s-1).value().doubleValue(); catch, appState.pxZ = 1; end
                voxVol_um3 = appState.pxX * appState.pxY * appState.pxZ;
                
                nZ = reader.getSizeZ(); [nY, nX] = size(bfGetPlane(reader, 1));
                
                if nZ < 2
                    logMessage(sprintf('Position %d skipped (Insufficient Z-volume).', s)); 
                    continue;
                end
                
                vol_fib = zeros(nY, nX, nZ, 'single');
                vol_cel = zeros(nY, nX, nZ, 'single');
                for z = 1:nZ
                    vol_fib(:,:,z) = single(bfGetPlane(reader, reader.getIndex(z-1, OPTS.ch_fibers-1, 0) + 1));
                    vol_cel(:,:,z) = single(bfGetPlane(reader, reader.getIndex(z-1, OPTS.ch_cells-1,  0) + 1));
                end
                maxFib = max(vol_fib(:)); if maxFib > 0, vol_fib = vol_fib / maxFib; end
                maxCel = max(vol_cel(:)); if maxCel > 0, vol_cel = vol_cel / maxCel; end
                
                vol_fib_down = imresize3(vol_fib, 1/OPTS.downsample_factor);
                vol_cel_down = imresize3(vol_cel, 1/OPTS.downsample_factor);
                
                cellVals = vol_cel_down(vol_cel_down > 0);
                if isempty(cellVals)
                    logMessage(sprintf('Position %d skipped: empty cell channel.', s));
                    continue;
                end
                mask_cel_down = vol_cel_down > graythresh(cellVals);
                min_vox_cell = round(OPTS.min_cell_vol_um3 / (voxVol_um3 * OPTS.downsample_factor^3));
                mask_cel_down = bwareaopen(mask_cel_down, max(1, min_vox_cell));
                
                [L_cel, numCells] = bwlabeln(mask_cel_down, 26);
                
                if numCells < 2 
                    logMessage(sprintf('Position %d: Not enough cells detected.', s));
                    continue;
                elseif numCells > OPTS.max_cells_per_fov
                    logMessage(sprintf('Position %d: Too many cells (Possible noise).', s));
                    continue;
                end
                
                vol_fib_masked = vol_fib_down; vol_fib_masked(mask_cel_down) = 0; 
                fib_smooth = imgaussfilt3(vol_fib_masked, OPTS.sigma_smooth_fibers / OPTS.downsample_factor);
                maxSmooth = max(fib_smooth(:)); if maxSmooth > 0, fib_smooth = fib_smooth / maxSmooth; end
                cost_map = 1 - fib_smooth + 0.01; 
                
                D_cells = cell(numCells, 1);
                for i = 1:numCells, D_cells{i} = graydist(cost_map, L_cel == i); end
                
                ruta_id = 1;
                renderDataLocal = {}; 
                
                for i = 1:numCells
                    for j = i+1:numCells
                        D_total = D_cells{i} + D_cells{j};
                        min_cost = min(D_total(:));
                        path_mask = D_total <= (min_cost * OPTS.path_thickness);
                        
                        if sum(path_mask(:)) > 10
                            maskA = (L_cel == i); maskB = (L_cel == j);
                            res = extract_contact_metrics(path_mask, maskA, maskB, s, i, j, vol_fib_down, appState.pxX, appState.pxY, appState.pxZ, OPTS.downsample_factor, ruta_id);
                            
                            % Standardized English Excel fields
                            tabla_pub.Filename = appState.fileName;
                            tabla_pub.Position = s;
                            tabla_pub.Path_ID = ruta_id;
                            tabla_pub.Connected_Cells = sprintf('%d <-> %d', i, j);
                            tabla_pub.Matrix_Intensity = res.data_table.Mean_Intensity;
                            tabla_pub.Physical_Length_um = res.data_table.PCA_Length_um;
                            tabla_pub.Fractional_Anisotropy_FA = res.data_table.Fractional_Anisotropy;
                            tabla_pub.Linearity_Index = res.data_table.Linearity;
                            tabla_pub.Planarity_Index = res.data_table.Planarity;
                            tabla_pub.Sphericity_Index = res.data_table.Sphericity;
                            
                            appState.results = [appState.results; tabla_pub];
                            renderDataLocal{end+1} = struct('mask', path_mask, 'angle', res.data_table.Azimuth_XY_deg_Norm, 'vectors', res.vectors);
                            ruta_id = ruta_id + 1;
                        end
                    end
                end
                
                % Update Live Table
                if ~isempty(appState.results)
                    uit_results.Data = struct2table(appState.results);
                end

                % 5. 3D RENDERING & EXPORT (Dynamic Tabs Implementation)
                if ~isempty(renderDataLocal)
                    % A) Create NEW UI Live View Tab dynamically
                    tab_name = sprintf('Render Pos %d', s);
                    new_tab = uitab(tg_view, 'Title', tab_name, 'BackgroundColor', 'k');
                    gl_new = uigridlayout(new_tab, [1 1]); gl_new.BackgroundColor = 'k'; gl_new.Padding = [0 0 0 0];
                    ax_ui_render = uiaxes(gl_new);
                    
                    axis(ax_ui_render, 'equal', 'tight'); box(ax_ui_render, 'on'); grid(ax_ui_render, 'on'); hold(ax_ui_render, 'on');
                    set(ax_ui_render, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'ZColor', 'w');
                    xlabel(ax_ui_render, 'X (\mu m)'); ylabel(ax_ui_render, 'Y (\mu m)'); zlabel(ax_ui_render, 'Z (\mu m)');
                    title(ax_ui_render, sprintf('Live Tensor Analysis - Position %d', s), 'Color', 'w', 'FontSize', 14);
                    
                    draw3DScene(ax_ui_render, OPTS, size(vol_fib), mask_cel_down, renderDataLocal);
                    tg_view.SelectedTab = new_tab;
                    drawnow;
                    
                    % B) Off-screen figure for clean export (.png and .fig in light mode)
                    figExport = figure('Visible', 'off', 'Position', [100 100 1000 800], 'Color', 'w');
                    ax_exp = axes('Parent', figExport);
                    axis(ax_exp, 'equal', 'tight'); box(ax_exp, 'on'); grid(ax_exp, 'on'); hold(ax_exp, 'on');
                    set(ax_exp, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'ZColor', 'k');
                    xlabel(ax_exp, 'X (\mu m)'); ylabel(ax_exp, 'Y (\mu m)'); zlabel(ax_exp, 'Z (\mu m)');
                    title(ax_exp, sprintf('Tensor Analysis - %s (Pos %d)', cleanName, s), 'Color', 'k', 'FontSize', 14);
                    
                    draw3DScene(ax_exp, OPTS, size(vol_fib), mask_cel_down, renderDataLocal);
                    
                    % Export PNG
                    pngName = fullfile(imgPath, sprintf('%s_Pos%02d_Inertia_3D.png', cleanName, s));
                    exportgraphics(figExport, pngName, 'Resolution', 300);
                    
                    % Export editable MATLAB FIG robustly.
                    % Important: figures created with Visible='off' may reopen invisible.
                    % Before saving, force normal visibility and add a CreateFcn that
                    % makes the figure visible when reopened with openfig/open.
                    figName = fullfile(figPath, sprintf('%s_Pos%02d_Inertia_3D.fig', cleanName, s));
                    set(figExport, 'Visible', 'on');
                    set(figExport, 'CreateFcn', 'set(gcf,''Visible'',''on'')');
                    drawnow;
                    try
                        savefig(figExport, figName, 'compact');
                    catch
                        savefig(figExport, figName);
                    end
                    
                    % Secondary backup as .fig in the PNG folder for compatibility
                    figNameBackup = fullfile(imgPath, sprintf('%s_Pos%02d_Inertia_3D.fig', cleanName, s));
                    try
                        savefig(figExport, figNameBackup, 'compact');
                    catch
                        savefig(figExport, figNameBackup);
                    end
                    
                    close(figExport); % CRITICAL: Prevent memory leaks
                end
                
            end % End Batch Loop
            
            % 6. GLOBAL EXCEL SAVE
            if ~isempty(appState.results)
                excelFile = fullfile(excelPath, 'Batch_Tensor_Results.xlsx');
                T = struct2table(appState.results);
                if ~isfile(excelFile)
                    writetable(T, excelFile, 'Sheet', 'Inertia');
                else
                    T_existing = readtable(excelFile, 'Sheet', 'Inertia');
                    T_final = [T_existing; T];
                    writetable(T_final, excelFile, 'Sheet', 'Inertia');
                end
                logMessage('>>> BATCH COMPLETE. GLOBAL EXCEL SAVED.');
                uialert(fig_mod, sprintf('Batch Processing Successful.\nOutputs saved to:\n%s', appState.outDir), 'Completed');
            else
                logMessage('Batch finished with no valid results to save.');
            end
            
            reader.close();
            
        catch ME
            logMessage(['CRITICAL ERROR: ' ME.message]); uialert(fig_mod, ME.message, 'Batch Execution Failed');
        end
        
        btn_run.Enable = 'on'; btn_load.Enable = 'on';
        lbl_progress.Text = 'Completed.';
    end

    %% 5. VISUAL RENDERING (Agnostic to UI/Off-screen)
    function draw3DScene(ax_target, opt, vol_size, mask_cel, render_data)
        nX_orig = vol_size(2); nY_orig = vol_size(1); nZ_orig = vol_size(3);
        [Xg, Yg, Zg] = meshgrid((0:nX_orig-1)*appState.pxX, (0:nY_orig-1)*appState.pxY, (0:nZ_orig-1)*appState.pxZ);
        
        cel_high = imresize3(double(mask_cel), vol_size, 'nearest');
        cel_sm = smooth3(cel_high, 'box', 5); 
        fv_cel = isosurface(Xg, Yg, Zg, cel_sm, 0.4); 
        
        if ~isempty(fv_cel.vertices)
            fv_cel = laplacian_smooth(fv_cel, opt.mesh_smooth_iter, false);
            patch(ax_target, 'Vertices', fv_cel.vertices, 'Faces', fv_cel.faces, 'FaceColor', [0.4 0.4 0.4], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'SpecularStrength', 0.6, 'DiffuseStrength', 0.8);
        end
        
        cmap = colormap(ax_target, opt.colormap_name);
        for r = 1:length(render_data)
            rut_high = imresize3(double(render_data{r}.mask), vol_size, 'nearest');
            rut_sm = smooth3(rut_high, 'box', 3); 
            fv_rut = isosurface(Xg, Yg, Zg, rut_sm, 0.3); 
            
            ang = render_data{r}.angle; 
            color_idx = max(1, min(round((ang / 180) * size(cmap, 1)), size(cmap, 1)));
            
            if ~isempty(fv_rut.vertices)
                fv_rut = laplacian_smooth(fv_rut, opt.mesh_smooth_iter, false);
                patch(ax_target, 'Vertices', fv_rut.vertices, 'Faces', fv_rut.faces, 'FaceColor', cmap(color_idx, :), 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'SpecularStrength', 0.9, 'DiffuseStrength', 0.9);
                fv_core = isosurface(Xg, Yg, Zg, rut_sm, 0.7); 
                if ~isempty(fv_core.vertices)
                    fv_core = laplacian_smooth(fv_core, 2, false);
                    patch(ax_target, 'Vertices', fv_core.vertices, 'Faces', fv_core.faces, 'FaceColor', [1 1 1], 'EdgeColor', 'none', 'FaceAlpha', 0.9);
                end
            end
            
            V = render_data{r}.vectors;
            plot3(ax_target, [V.ContactA(1), V.ContactB(1)], [V.ContactA(2), V.ContactB(2)], [V.ContactA(3), V.ContactB(3)], '--c', 'LineWidth', 2);
            scale_1 = V.Length / 2; scale_2 = scale_1 * 0.5;
            quiver3(ax_target, V.C_fib(1)-(V.V1(1)*scale_1/2), V.C_fib(2)-(V.V1(2)*scale_1/2), V.C_fib(3)-(V.V1(3)*scale_1/2), V.V1(1)*scale_1, V.V1(2)*scale_1, V.V1(3)*scale_1, 0, 'm', 'LineWidth', 3, 'MaxHeadSize', 0.5);
            quiver3(ax_target, V.C_fib(1)-(V.V2(1)*scale_2/2), V.C_fib(2)-(V.V2(2)*scale_2/2), V.C_fib(3)-(V.V2(3)*scale_2/2), V.V2(1)*scale_2, V.V2(2)*scale_2, V.V2(3)*scale_2, 0, 'g', 'LineWidth', 2, 'MaxHeadSize', 0.5);
        end
        
        camlight(ax_target, 'headlight'); camlight(ax_target, 'right'); 
        lighting(ax_target, 'gouraud'); material(ax_target, 'shiny'); view(ax_target, 45, 30);
    end

    %% 6. MATH FUNCTIONS
    function res = extract_contact_metrics(mask_path, maskA, maskB, serie_id, idA, idB, vol_int, pX, pY, pZ, sf, r_id)
        idx_path = find(mask_path); D_A = bwdist(maskA); D_B = bwdist(maskB);
        [~, min_idx_A] = min(D_A(idx_path)); [pyA, pxA, pzA] = ind2sub(size(mask_path), idx_path(min_idx_A));
        ContactA = [pxA * pX * sf, pyA * pY * sf, pzA * pZ * sf];
        [~, min_idx_B] = min(D_B(idx_path)); [pyB, pxB, pzB] = ind2sub(size(mask_path), idx_path(min_idx_B));
        ContactB = [pxB * pX * sf, pyB * pY * sf, pzB * pZ * sf];
        V_cp = (ContactB - ContactA); norm_cp = norm(V_cp); if norm_cp > 0, V_cp = V_cp / norm_cp; else, V_cp = [0 0 0]; end
        [py, px, pz] = ind2sub(size(mask_path), idx_path); X = px * pX * sf; Y = py * pY * sf; Z = pz * pZ * sf; C_fib = mean([X, Y, Z], 1); 
        table_data.Mean_Intensity = mean(vol_int(idx_path));
        
        if length(X) > 5
            P = [X, Y, Z]; P_centered = P - C_fib; C = (P_centered' * P_centered) / (size(P, 1) - 1); [V, D] = eig(C);
            eigenvalues = diag(D); [eigenvalues_sorted, sort_idx] = sort(eigenvalues, 'descend'); V_sorted = V(:, sort_idx);
            v1_pca = V_sorted(:, 1)'; v2_pca = V_sorted(:, 2)'; v3_pca = V_sorted(:, 3)'; 
            if dot(v1_pca, V_cp) < 0, v1_pca = -v1_pca; end
            score = P_centered * V_sorted; pca_length = max(score(:,1)) - min(score(:,1));
            
            azimuth_raw = atan2d(v1_pca(2), v1_pca(1)); r_xy = sqrt(v1_pca(1)^2 + v1_pca(2)^2);
            table_data.Azimuth_XY_deg_Norm = mod(azimuth_raw, 180); 
            table_data.PCA_Length_um = pca_length; 
            L1 = eigenvalues_sorted(1); L2 = eigenvalues_sorted(2); L3 = eigenvalues_sorted(3);
            
            table_data.Linearity = (L1 - L2) / L1; 
            table_data.Planarity = 2 * (L2 - L3) / L1; 
            table_data.Sphericity = 3 * L3 / L1;
            table_data.Fractional_Anisotropy = sqrt(0.5) * sqrt((L1-L2)^2 + (L2-L3)^2 + (L3-L1)^2) / sqrt(L1^2 + L2^2 + L3^2);
            res.vectors.V1 = v1_pca; res.vectors.V2 = v2_pca; res.vectors.V3 = v3_pca;
        else
            table_data.Azimuth_XY_deg_Norm = NaN; table_data.PCA_Length_um = NaN; 
            table_data.Linearity = NaN; table_data.Planarity = NaN; 
            table_data.Sphericity = NaN; table_data.Fractional_Anisotropy = NaN;
            res.vectors.V1 = [0 0 0]; res.vectors.V2 = [0 0 0]; res.vectors.V3 = [0 0 0]; pca_length = 0;
        end
        res.data_table = table_data; res.vectors.ContactA = ContactA; res.vectors.ContactB = ContactB;
        res.vectors.C_fib = C_fib; res.vectors.V_cp = V_cp; res.vectors.Length = pca_length;
    end

    function mesh_out = laplacian_smooth(mesh_in, n_iter, use_median)
        mesh_out = mesh_in; V = mesh_out.vertices; F = mesh_out.faces; adj = vertex_adjacency(F, size(V,1));
        for k = 1:n_iter
            Vnew = V;
            for vi = 1:size(V,1)
                nbrs = adj{vi}; if isempty(nbrs), continue; end
                if use_median, Vnew(vi,:) = median(V(nbrs,:),1); else, Vnew(vi,:) = mean(V(nbrs,:),1); end
            end
            V = Vnew;
        end
        mesh_out.vertices = V;
    end

    function adj = vertex_adjacency(F, nV)
        adj = cell(nV,1);
        for i = 1:size(F,1)
            for j = 1:3
                vi = F(i,j); next_j = mod(j,3) + 1; prev_j = mod(j+1,3) + 1; adj{vi} = unique([adj{vi}, F(i,next_j), F(i,prev_j)]);
            end
        end
    end
end