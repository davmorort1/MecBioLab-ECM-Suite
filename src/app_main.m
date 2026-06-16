function app_main()
% APP_MAIN - MecBioLab ECM Suite dashboard.
%
% The public release exposes two focused workflows:
%   1) Geodesic Tract Analysis
%   2) SAM2-assisted Degradation/Tunnel Annotation

    clc; close all;

    suiteRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(suiteRoot, 'src', 'tools'));
    addpath(fullfile(suiteRoot, 'assets'));

    c_bg      = [0.07 0.07 0.08];
    c_panel   = [0.11 0.11 0.13];
    c_text_H1 = [0.95 0.95 0.95];
    c_text_p  = [0.65 0.65 0.70];
    c_btnBase = [0.16 0.20 0.25];
    c_btnAcc  = [0.18 0.28 0.35];

    appData = struct('GlobalOutputDir', '');

    fig_main = uifigure('Name', 'MecBioLab ECM Suite', ...
                        'Position', [220 120 850 520], ...
                        'Color', c_bg);
    fig_main.UserData = appData;

    gl_main = uigridlayout(fig_main, [4 1]);
    gl_main.RowHeight = {135, 60, '1x', 50};
    gl_main.BackgroundColor = c_bg;

    pnl_header = uipanel(gl_main, 'BorderType', 'none', 'BackgroundColor', c_bg);
    gl_header = uigridlayout(pnl_header, [2 2]);
    gl_header.ColumnWidth = {135, '1x'};
    gl_header.RowHeight = {'1x', '1x'};
    gl_header.BackgroundColor = c_bg;

    logo_filename = fullfile(suiteRoot, 'assets', 'logo.png');
    try
        img_logo = uiimage(gl_header, 'ImageSource', logo_filename);
        img_logo.Layout.Row = [1 2];
        img_logo.Layout.Column = 1;
    catch
        lbl_logo = uilabel(gl_header, 'Text', 'MecBioLab', ...
            'FontColor', c_text_H1, 'FontSize', 20, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center');
        lbl_logo.Layout.Row = [1 2];
        lbl_logo.Layout.Column = 1;
    end

    lbl_title = uilabel(gl_header, 'Text', 'MecBioLab ECM Suite', ...
        'FontColor', c_text_H1, 'FontSize', 24, 'FontName', 'Helvetica', ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'bottom');
    lbl_title.Layout.Row = 1;
    lbl_title.Layout.Column = 2;

    lbl_subtitle = uilabel(gl_header, 'Text', ...
        '3D geodesic ECM tract analysis and SAM2-assisted degradation annotation', ...
        'FontColor', c_text_p, 'FontSize', 14, 'FontName', 'Helvetica', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
    lbl_subtitle.Layout.Row = 2;
    lbl_subtitle.Layout.Column = 2;

    pnl_config = uipanel(gl_main, 'BorderType', 'none', 'BackgroundColor', c_panel);
    gl_conf = uigridlayout(pnl_config, [1 2]);
    gl_conf.ColumnWidth = {'1x', 250};
    gl_conf.Padding = [20 5 20 5];
    gl_conf.BackgroundColor = c_panel;

    lbl_dir = uilabel(gl_conf, 'Text', 'Global Output Directory: Not Selected', ...
        'FontColor', [0.8 0.8 0.2], 'FontSize', 14, 'WordWrap', 'on');

    uibutton(gl_conf, 'Text', 'Select Root Folder', ...
        'BackgroundColor', c_btnAcc, 'FontColor', 'w', ...
        'FontSize', 14, 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @selectGlobalDir);

    pnl_body = uipanel(gl_main, 'BorderType', 'none', 'BackgroundColor', c_panel);
    gl_body = uigridlayout(pnl_body, [1 2]);
    gl_body.RowSpacing = 15;
    gl_body.ColumnSpacing = 20;
    gl_body.Padding = [40 35 40 35];
    gl_body.BackgroundColor = c_panel;

    uibutton(gl_body, 'Text', sprintf('Geodesic Tract Analysis\n3D ECM paths and tensor descriptors'), ...
        'BackgroundColor', c_btnBase, 'FontColor', 'w', 'FontSize', 16, ...
        'FontWeight', 'bold', 'ButtonPushedFcn', @(btn,event) launchTool('geodesic'));

    uibutton(gl_body, 'Text', sprintf('Degradation/Tunnel Annotation\nSAM2-assisted masks and metrics'), ...
        'BackgroundColor', c_btnBase, 'FontColor', 'w', 'FontSize', 16, ...
        'FontWeight', 'bold', 'ButtonPushedFcn', @(btn,event) launchTool('annotation'));

    pnl_footer = uipanel(gl_main, 'BorderType', 'none', 'BackgroundColor', c_bg);
    gl_footer = uigridlayout(pnl_footer, [1 1]);
    gl_footer.BackgroundColor = c_bg;
    uilabel(gl_footer, 'Text', ...
        'Developed by David Morón Ortega | MecBioLab Research Group - Universidad de Sevilla | v1.0.0', ...
        'FontColor', c_text_p, 'FontSize', 11, 'HorizontalAlignment', 'center');

    function selectGlobalDir(~, ~)
        selpath = uigetdir('', 'Select the root folder to save all results');
        if selpath ~= 0
            fig_main.UserData.GlobalOutputDir = selpath;
            lbl_dir.Text = ['Global Output Directory: ' selpath];
            lbl_dir.FontColor = [0.2 0.8 0.2];
        end
    end

    function launchTool(toolName)
        fig_main.Visible = 'off';
        switch toolName
            case 'geodesic'
                geodesic_tract_analysis(fig_main);
            case 'annotation'
                degradation_tunnel_annotation(fig_main);
            otherwise
                fig_main.Visible = 'on';
                uialert(fig_main, 'Unknown workflow request.', 'Application error');
        end
    end
end
