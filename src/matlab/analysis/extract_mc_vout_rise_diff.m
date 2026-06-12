% =========================================================================
% Script:   extract_mc_vout_rise_diff.m
% Purpose:
%   Parse Spectre Monte Carlo .print file.
%   Use case0 as reference.
%   Find first upward crossing of v(out) at 0.901 V.
%   Save only idx and delta_t into .mat.
% =========================================================================

clear; clc;

%% =========================
% User settings
%% =========================
print_dir  = '$PROJECT_ROOT';
print_file = fullfile(print_dir, 'mc_single_neuron_50_0.08.print');

vth = 0.901;
save_mat_name = fullfile(print_dir, 'mc_vout_first_rise_diff.mat');

%% =========================
% Read file
%% =========================
if ~isfile(print_file)
    error('Cannot find file: %s', print_file);
end

fid = fopen(print_file, 'r');
if fid < 0
    error('Cannot open file: %s', print_file);
end

C = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
lines = C{1};

%% =========================
% Find all Monte Carlo blocks
%% =========================
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
    error('No Monte Carlo blocks found in file.');
end

nCases = numel(mc_line_idx);

%% =========================
% Parse each case
%% =========================
cross_time_s_all = NaN(nCases,1);

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
        if contains(s, 'time') && contains(s, 'v(out)')
            header_idx = j;
            break;
        end
    end

    if isempty(header_idx)
        warning('Case %d: header not found.', k-1);
        continue;
    end

    time_s = [];
    vout_V = [];

    % -------- parse data lines after header --------
    for j = header_idx+1:numel(block_lines)
        s = strtrim(block_lines{j});

        if isempty(s)
            continue;
        end

        % next MC block
        if contains(s, 'montecarlo_iteration')
            break;
        end

        % skip obvious non-data lines
        if strcmp(s, 'x')
            continue;
        end

        % try to parse one row:
        % expected format like:
        % 200 p     900.312 m     900 m     927.825 m     14.5681 u
        vals = parse_spectre_row_unitsplit(s);

        if numel(vals) < 5
            continue;
        end

        time_s(end+1,1) = vals(1); %#ok<SAGROW>
        vout_V(end+1,1) = vals(3); %#ok<SAGROW>
    end

    if isempty(time_s)
        warning('Case %d: parsed data is empty.', k-1);
        continue;
    end

    cross_time_s_all(k) = find_first_up_crossing(time_s, vout_V, vth);
end

%% =========================
% Reference = case0
%% =========================
ref_idx = 1;

if isnan(cross_time_s_all(ref_idx))
    error('case0 crossing time not found.');
end

t0 = cross_time_s_all(ref_idx);

%% =========================
% Build outputs
%% =========================
idx = (0:nCases-1).';
delta_t = NaN(nCases,1);

for k = 1:nCases
    if k == ref_idx
        delta_t(k) = 0;
    else
        if ~isnan(cross_time_s_all(k))
            delta_t(k) = cross_time_s_all(k) - t0;
        end
    end
end

%% =========================
% Save MAT
%% =========================
save(save_mat_name, 'idx', 'delta_t');

fprintf('Done.\n');
fprintf('case0 crossing time = %.12e s\n', t0);
fprintf('Saved: %s\n', save_mat_name);

%% =========================
% Local functions
%% =========================
function vals = parse_spectre_row_unitsplit(s)
% Parse Spectre row like:
% "200 p 900.312 m 900 m 927.825 m 14.5681 u"
% into SI values:
% [200e-12, 900.312e-3, 900e-3, 927.825e-3, 14.5681e-6]

    vals = [];

    % match pairs: number + optional suffix
    toks = regexp(s, '([+-]?\d*\.?\d+(?:[eE][+-]?\d+)?)\s*([fpnumkKMGT]?)', 'tokens');
    if isempty(toks)
        return;
    end

    out = [];
    for ii = 1:numel(toks)
        num_str = toks{ii}{1};
        suf_str = toks{ii}{2};

        if isempty(num_str)
            continue;
        end

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

function t_cross = find_first_up_crossing(t, v, vth)
    t_cross = NaN;

    if numel(t) < 2 || numel(v) < 2
        return;
    end

    idx0 = find(v(1:end-1) < vth & v(2:end) >= vth, 1, 'first');
    if isempty(idx0)
        return;
    end

    t1 = t(idx0);
    t2 = t(idx0+1);
    v1 = v(idx0);
    v2 = v(idx0+1);

    if v2 == v1
        t_cross = t1;
    else
        t_cross = t1 + (vth - v1) * (t2 - t1) / (v2 - v1);
    end
end