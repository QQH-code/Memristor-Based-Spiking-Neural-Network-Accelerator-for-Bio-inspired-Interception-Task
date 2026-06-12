% =========================================================================
% Script:   collect_net6_slope_all_prints.m
% Purpose:
%   Scan all mc_single_neuron_50_*.print files, parse each Monte Carlo case,
%   compute slope of v(N1.net6) between 4.1e-7 s and 6.1e-7 s,
%   and save results into a .mat file.
%
% Output MAT columns:
%   col 1: case idx
%   col 2: xxx value from filename mc_single_neuron_50_xxx.print
%   col 3: slope = (V(t2)-V(t1)) / (t2-t1)
% =========================================================================

clear; clc;

%% =========================
% User settings
%% =========================
work_dir = '$PROJECT_ROOT';
file_pattern = fullfile(work_dir, 'mc_single_neuron_50_*.print');

t1 = 5.2e-7;
t2 = 7.0e-7;

save_mat_name = fullfile(work_dir, 'mc_net6_slope_all_prints.mat');

%% =========================
% Find all print files
%% =========================
files = dir(file_pattern);

if isempty(files)
    error('No files found matching: %s', file_pattern);
end

fprintf('Found %d print files.\n', numel(files));

%% =========================
% Collect results
%% =========================
all_idx   = [];
all_xxx   = [];
all_slope = [];

for f = 1:numel(files)
    file_name = files(f).name;
    file_path = fullfile(files(f).folder, files(f).name);

    fprintf('\nProcessing file: %s\n', file_name);

    % -------------------------------------------------
    % Extract xxx from filename: mc_single_neuron_50_xxx.print
    % -------------------------------------------------
    tok_name = regexp(file_name, '^mc_single_neuron_50_(.+)\.print$', 'tokens', 'once');
    if isempty(tok_name)
        warning('Cannot parse xxx from file name: %s. Skipped.', file_name);
        continue;
    end

    xxx_value = str2double(tok_name{1});
    if isnan(xxx_value)
        warning('xxx is not numeric in file: %s. Skipped.', file_name);
        continue;
    end

    % -------------------------------------------------
    % Read file lines
    % -------------------------------------------------
    fid = fopen(file_path, 'r');
    if fid < 0
        warning('Cannot open file: %s. Skipped.', file_path);
        continue;
    end

    C = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
    fclose(fid);
    lines = C{1};

    % -------------------------------------------------
    % Find all Monte Carlo block starts
    % -------------------------------------------------
    mc_pat = 'montecarlo_iteration\s*=\s*([^\s]+)';
    mc_line_idx = [];
    mc_iter_vals = [];

    for i = 1:numel(lines)
        tok = regexp(lines{i}, mc_pat, 'tokens', 'once');
        if ~isempty(tok)
            mc_line_idx(end+1) = i; %#ok<SAGROW>
            mc_iter_vals(end+1) = str2double(tok{1}); %#ok<SAGROW>
        end
    end

    if isempty(mc_line_idx)
        warning('No Monte Carlo blocks found in file: %s', file_name);
        continue;
    end

    nCases = numel(mc_line_idx);

    % -------------------------------------------------
    % Parse each case
    % -------------------------------------------------
    for k = 1:nCases
        start_line = mc_line_idx(k);

        if k < nCases
            end_line = mc_line_idx(k+1) - 1;
        else
            end_line = numel(lines);
        end

        block_lines = lines(start_line:end_line);

        % -------- find header line --------
        header_idx = [];
        for j = 1:numel(block_lines)
            s = strtrim(block_lines{j});
            if contains(s, 'time') && contains(s, 'v(N1.net6)')
                header_idx = j;
                break;
            end
        end

        if isempty(header_idx)
            warning('File %s, case %d: header not found.', file_name, k-1);
            continue;
        end

        time_s = [];
        vnet6_V = [];

        % -------- parse data lines --------
        for j = header_idx+1:numel(block_lines)
            s = strtrim(block_lines{j});

            if isempty(s)
                continue;
            end

            if contains(s, 'montecarlo_iteration')
                break;
            end

            if strcmp(s, 'x')
                continue;
            end

            vals = parse_spectre_row_unitsplit(s);

            % Expected columns:
            % time, v(in_node), v(out), v(N1.net6), v(N1.net10)
            if numel(vals) < 5
                continue;
            end

            time_s(end+1,1)  = vals(1); %#ok<SAGROW>
            vnet6_V(end+1,1) = vals(4); %#ok<SAGROW>
        end

        if numel(time_s) < 2
            warning('File %s, case %d: insufficient data.', file_name, k-1);
            continue;
        end

		[time_s_unique, ia] = unique(time_s, 'last');
		vnet6_unique = vnet6_V(ia);

		if numel(time_s_unique) < 2
			warning('File %s, case %d: insufficient unique time points.', file_name, k-1);
			continue;
		end

		if t1 < time_s_unique(1) || t1 > time_s_unique(end) || ...
		   t2 < time_s_unique(1) || t2 > time_s_unique(end)
			warning('File %s, case %d: t1/t2 out of range.', file_name, k-1);
			continue;
		end

		v1 = interp1(time_s_unique, vnet6_unique, t1, 'linear');
		v2 = interp1(time_s_unique, vnet6_unique, t2, 'linear');



        slope_this = (v2 - v1) / (t2 - t1);

        all_idx(end+1,1)   = k - 1;       %#ok<SAGROW>
        all_xxx(end+1,1)   = xxx_value;   %#ok<SAGROW>
        all_slope(end+1,1) = slope_this;  %#ok<SAGROW>
    end
end

%% =========================
% Save MAT
%% =========================
result_mat = [all_idx, all_xxx, all_slope];

save(save_mat_name, 'result_mat');

fprintf('\nDone.\n');
fprintf('Saved MAT file:\n%s\n', save_mat_name);
fprintf('Total rows saved: %d\n', size(result_mat, 1));

%% =========================
% Local function
%% =========================
function vals = parse_spectre_row_unitsplit(s)
% Parse Spectre row like:
% "200 p 900.312 m 900 m 927.825 m 14.5681 u"
% into SI values:
% [200e-12, 900.312e-3, 900e-3, 927.825e-3, 14.5681e-6]

    vals = [];

    toks = regexp(s, '([+-]?\d*\.?\d+(?:[eE][+-]?\d+)?)\s*([fpnumkKMGT]?)', 'tokens');
    if isempty(toks)
        return;
    end

    out = [];
    for ii = 1:numel(toks)
        num_str = toks{ii}{1};
        suf_str = toks{ii}{2};

        x = str2double(num_str);
        if isnan(x)
            continue;
        end

        switch suf_str
            case 'f'
                scale = 1e-15;
            case 'p'
                scale = 1e-12;
            case 'n'
                scale = 1e-9;
            case 'u'
                scale = 1e-6;
            case 'm'
                scale = 1e-3;
            case 'k'
                scale = 1e3;
            case 'K'
                scale = 1e3;
            case 'M'
                scale = 1e6;
            case 'G'
                scale = 1e9;
            case 'T'
                scale = 1e12;
            otherwise
                scale = 1;
        end

        out(end+1) = x * scale; %#ok<AGROW>
    end

    vals = out;
end