clc;
clear;
close all;

%% =========================================================
% Search step_mats under tasks/task_0001 ... task_xxxx
% For each .mat:
%   res(:,1) = time (s)
%   res(:,2:5) = 4 input spike waveforms
%
% Count rising crossings through 0.902 V before 22.5 us.
% No per-input separation:
%   among all 4 inputs and all mat files,
%   collect one record for each target spike count.
%
% Save one .mat:
%   spike_summary_table
%
% In this table:
%   col 1 = spike count
%   col 2... = all crossing times (s), padded with NaN
%% =========================================================

%% -------------------------
% User settings
%% -------------------------
root_dir = '$PROJECT_ROOT';
root_dir2 = '$PROJECT_ROOT';
time_limit = 23.5e-6;   % 22.5 us
cross_vth  = 0.902;     % rising crossing threshold

target_counts = [1 2 3 4 5 6 7 8 9 10 11 12 14 15 16 19 20 21 22 23 24];
save_mat_name = fullfile(root_dir2, 'input_spike_crossing_summary.mat');

%% -------------------------
% Find all task folders
%% -------------------------
d = dir(fullfile(root_dir, 'task_*'));
d = d([d.isdir]);

if isempty(d)
    error('No task_* folders found under:\n%s', root_dir);
end

task_names = {d.name};
task_ids = nan(size(task_names));

for i = 1:numel(task_names)
    tok = regexp(task_names{i}, 'task_(\d+)$', 'tokens', 'once');
    if ~isempty(tok)
        task_ids(i) = str2double(tok{1});
    end
end

[~, sort_idx] = sort(task_ids);
d = d(sort_idx);

%% -------------------------
% Prepare containers
%% -------------------------
found_counts = false(size(target_counts));
saved_times  = cell(size(target_counts));
saved_file   = cell(size(target_counts));
saved_input  = nan(size(target_counts));   % which input channel found it

%% -------------------------
% Main search
%% -------------------------
fprintf('Searching tasks under:\n%s\n\n', root_dir);

stop_all = false;

for itask = 1:numel(d)
    task_name = d(itask).name;
    step_dir = fullfile(root_dir, task_name, 'step_mats');

    if ~isfolder(step_dir)
        fprintf('Skip %s (no step_mats)\n', task_name);
        continue;
    end

    mat_list = dir(fullfile(step_dir, '*.mat'));
    if isempty(mat_list)
        fprintf('Skip %s/step_mats (no .mat files)\n', task_name);
        continue;
    end

    [~, idxm] = sort({mat_list.name});
    mat_list = mat_list(idxm);

    fprintf('Processing %s (%d mat files)\n', task_name, numel(mat_list));

    for imat = 1:numel(mat_list)
        mat_path = fullfile(step_dir, mat_list(imat).name);

        try
            S = load(mat_path);
        catch ME
            warning('Failed to load %s\n%s', mat_path, ME.message);
            continue;
        end

        if ~isfield(S, 'res')
            warning('File has no variable "res": %s', mat_path);
            continue;
        end

        res = S.res;

        if size(res,2) < 5
            warning('res has fewer than 5 columns: %s', mat_path);
            continue;
        end

        t = double(res(:,1));        % seconds
        sig = double(res(:,2:5));    % 4 inputs

        idx_keep = (t <= time_limit);
        t_use = t(idx_keep);
        sig_use = sig(idx_keep, :);

        if numel(t_use) < 2
            continue;
        end

        % Search across all 4 inputs, not separately
        for ch = 1:4
            v = sig_use(:, ch);
            t_cross = find_rising_crossings(t_use, v, cross_vth);
            spike_count = numel(t_cross);

            idx_target = find(target_counts == spike_count, 1);

            if ~isempty(idx_target) && ~found_counts(idx_target)
                found_counts(idx_target) = true;
                saved_times{idx_target} = t_cross(:).';
                saved_file{idx_target} = mat_path;
                saved_input(idx_target) = ch;

                fprintf('  found count=%d from %s, input%d\n', ...
                    spike_count, mat_list(imat).name, ch);
            end
        end

        % stop when all target counts are found
        if all(found_counts)
            fprintf('\nAll target spike counts found. Stop searching.\n');
            stop_all = true;
            break;
        end
    end

    if stop_all
        break;
    end
end

%% -------------------------
% Build output matrix
% Each row:
%   col1 = spike count
%   col2... = crossing times (s)
%% -------------------------
spike_summary_table = build_spike_table(target_counts, found_counts, saved_times);

%% -------------------------
% Save one MAT
%% -------------------------
save(save_mat_name, ...
    'spike_summary_table', ...
    'target_counts', ...
    'saved_file', ...
    'saved_input');

fprintf('\nSaved summary MAT:\n%s\n', save_mat_name);

%% -------------------------
% Print summary
%% -------------------------
fprintf('\nFound %d / %d target counts\n', sum(found_counts), numel(target_counts));
fprintf('Missing counts: ');
disp(target_counts(~found_counts));

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

function T = build_spike_table(target_counts, found_mask, saved_times_cell)
    max_len = 0;

    for i = 1:numel(target_counts)
        if found_mask(i) && ~isempty(saved_times_cell{i})
            max_len = max(max_len, numel(saved_times_cell{i}));
        end
    end

    T = nan(numel(target_counts), 1 + max_len);
    T(:,1) = target_counts(:);

    for i = 1:numel(target_counts)
        if found_mask(i) && ~isempty(saved_times_cell{i})
            tt = saved_times_cell{i};
            T(i, 2:1+numel(tt)) = tt;
        end
    end
end