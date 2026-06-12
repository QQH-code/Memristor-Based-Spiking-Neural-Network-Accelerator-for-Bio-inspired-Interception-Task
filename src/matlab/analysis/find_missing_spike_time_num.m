clc;
clear;
close all;

%% =========================================================
% User settings
%% =========================================================
summary_mat = '$PROJECT_ROOT';
print_file  = '$PROJECT_ROOT';

time_limit = 24e-6;   % 23.5 us
cross_vth  = 0.902;     % rising threshold

target_count = 3;      % this time only fill row 24

%% =========================================================
% Load existing summary table
%% =========================================================
S = load(summary_mat);

if ~isfield(S, 'spike_summary_table')
    error('Cannot find spike_summary_table in %s', summary_mat);
end

spike_summary_table = S.spike_summary_table;

%% =========================================================
% Read 4 input waveforms from .print
%% =========================================================
wave1 = read_wave_from_print(print_file, 'v(out1_1)');
wave2 = read_wave_from_print(print_file, 'v(out1_2)');
wave3 = read_wave_from_print(print_file, 'v(out1_3)');
wave4 = read_wave_from_print(print_file, 'v(out1_4)');

waves = {wave1, wave2, wave3, wave4};

%% =========================================================
% Find which input has exactly 24 spikes before 22.5 us
%% =========================================================
found = false;
best_t_cross = [];
best_input = NaN;

for ch = 1:4
    if isempty(waves{ch})
        continue;
    end

    t = waves{ch}.time_s(:);
    v = waves{ch}.value(:);

    idx_keep = (t <= time_limit);
    t = t(idx_keep);
    v = v(idx_keep);

    t_cross = find_rising_crossings(t, v, cross_vth);
    spike_count = numel(t_cross);

    fprintf('Input %d: spike_count = %d\n', ch, spike_count);

    if spike_count == target_count
        found = true;
        best_t_cross = t_cross(:).';
        best_input = ch;
        break;
    end
end

if ~found
    error('No input waveform in %s has exactly %d spikes before %.2f us.', ...
        print_file, target_count, time_limit*1e6);
end

fprintf('Use input %d to fill row %d.\n', best_input, target_count);

%% =========================================================
% Write into the row whose first column == 24
%% =========================================================
row_idx = find(spike_summary_table(:,1) == target_count, 1);

if isempty(row_idx)
    error('Cannot find row with first column = %d in spike_summary_table.', target_count);
end

need_cols = 1 + numel(best_t_cross);

% expand table width if needed
if size(spike_summary_table,2) < need_cols
    spike_summary_table(:, end+1:need_cols) = NaN;
end

% clear old contents in that row except first col
spike_summary_table(row_idx, 2:end) = NaN;

% fill new crossing times
spike_summary_table(row_idx, 2:1+numel(best_t_cross)) = best_t_cross;

%% =========================================================
% Save back
%% =========================================================
save(summary_mat, 'spike_summary_table', '-append');

fprintf('Updated row for spike count = %d and saved back to:\n%s\n', ...
    target_count, summary_mat);

%% =========================================================
% Local functions
%% =========================================================
function t_cross = find_rising_crossings(t, v, vth)
    idx = find(v(1:end-1) < vth & v(2:end) >= vth);

    t_cross = zeros(numel(idx),1);
    for k = 1:numel(idx)
        i1 = idx(k);
        t1 = t(i1);
        t2 = t(i1+1);
        v1 = v(i1);
        v2 = v(i1+1);

        if abs(v2 - v1) < eps
            t_cross(k) = t1;
        else
            t_cross(k) = t1 + (vth - v1) * (t2 - t1) / (v2 - v1);
        end
    end
end

function wave = read_wave_from_print(print_file, target_col_name)

    wave = [];

    if ~isfile(print_file)
        error('Cannot find file: %s', print_file);
    end

    lines = readlines(print_file);
    lines = string(lines);
    lines_trim = strtrim(lines);

    header_idx_all = [];
    for i = 1:numel(lines_trim)
        li = lines_trim(i);
        if li == ""
            continue;
        end
        if contains(li, "time") && contains(li, target_col_name)
            header_idx_all(end+1) = i; %#ok<AGROW>
        end
    end

    if isempty(header_idx_all)
        warning('Cannot find header containing "%s" in %s', target_col_name, print_file);
        return;
    end

    t_all = [];
    v_all = [];

    for ib = 1:numel(header_idx_all)
        header_idx = header_idx_all(ib);
        header_line = char(lines_trim(header_idx));

        header_tokens = regexp(header_line, '\s+', 'split');
        n_cols = numel(header_tokens);

        time_col = find(strcmp(header_tokens, 'time'), 1);
        sig_col  = find(strcmp(header_tokens, target_col_name), 1);

        if isempty(time_col) || isempty(sig_col)
            continue;
        end

        t_block = [];
        v_block = [];

        for i = header_idx + 1 : numel(lines_trim)
            li = lines_trim(i);

            if li == "" || li == "x" || li == "y" || startsWith(li, "*") || contains(li, "Transient Analysis")
                continue;
            end

            if contains(li, "time") && contains(li, target_col_name)
                break;
            end

            fields = regexp(char(li), ...
                '([+-]?\d*\.?\d+(?:[eE][+-]?\d+)?(?:\s*[fpnumkKMGT])?)', ...
                'match');

            if numel(fields) ~= n_cols
                continue;
            end

            try
                t_now = parse_spice_num(fields{time_col});
                v_now = parse_spice_num(fields{sig_col});

                t_block(end+1,1) = t_now; %#ok<AGROW>
                v_block(end+1,1) = v_now; %#ok<AGROW>
            catch
            end
        end

        if isempty(t_block)
            continue;
        end

        [t_block, idx_sort] = sort(t_block);
        v_block = v_block(idx_sort);

        [t_block, idx_unique] = unique(t_block, 'stable');
        v_block = v_block(idx_unique);

        good = isfinite(t_block) & isfinite(v_block);
        t_block = t_block(good);
        v_block = v_block(good);

        t_all = [t_all; t_block]; %#ok<AGROW>
        v_all = [v_all; v_block]; %#ok<AGROW>
    end

    if isempty(t_all)
        warning('No data parsed for %s from %s', target_col_name, print_file);
        return;
    end

    [t_all, idx_sort] = sort(t_all);
    v_all = v_all(idx_sort);

    [t_vec, idx_unique] = unique(t_all, 'stable');
    v_vec = v_all(idx_unique);

    wave.time_s = t_vec;
    wave.value  = v_vec;
    wave.name   = target_col_name;
end

function val = parse_spice_num(tok)
    tok = strtrim(tok);
    tok = regexprep(tok, '\s+', '');

    x = str2double(tok);
    if ~isnan(x)
        val = x;
        return;
    end

    suffix_map = struct( ...
        'f', 1e-15, ...
        'p', 1e-12, ...
        'n', 1e-9, ...
        'u', 1e-6, ...
        'm', 1e-3, ...
        'k', 1e3, ...
        'K', 1e3, ...
        'M', 1e6, ...
        'G', 1e9, ...
        'T', 1e12);

    suffix = tok(end);
    base_str = tok(1:end-1);
    base_val = str2double(base_str);

    if isnan(base_val) || ~isfield(suffix_map, suffix)
        error('Cannot parse token: %s', tok);
    end

    val = base_val * suffix_map.(suffix);
end