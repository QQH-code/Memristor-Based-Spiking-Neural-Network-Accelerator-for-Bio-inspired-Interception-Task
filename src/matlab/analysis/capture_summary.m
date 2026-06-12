clc;
clear;
close all;

%% =========================
%  User setting
%% =========================
root_dir = '$PROJECT_ROOT';
task_pattern = 'task_*';

%% =========================
%  Find all task folders
%% =========================
D = dir(fullfile(root_dir, task_pattern));
D = D([D.isdir]);

if isempty(D)
    error('No task folders found under:\n%s', root_dir);
end

fprintf('Found %d task folders.\n', numel(D));

%% =========================
%  Prepare result containers
%% =========================
task_name_list   = strings(0,1);
log_found_list   = false(0,1);
captured_list    = nan(0,1);   % 1 = captured, 0 = not captured, NaN = unknown
last_idx_list    = nan(0,1);

%% =========================
%  Loop over all tasks
%% =========================
for i = 1:numel(D)
    task_name = D(i).name;
    task_dir  = fullfile(root_dir, task_name);
    log_path  = fullfile(task_dir, 'closed_loop_log.txt');

    fprintf('Checking %s ...\n', task_name);

    task_name_list(end+1,1) = string(task_name);

    if ~isfile(log_path)
        log_found_list(end+1,1) = false;
        captured_list(end+1,1)  = NaN;
        last_idx_list(end+1,1)  = NaN;
        fprintf('  Log file not found.\n');
        continue;
    end

    log_found_list(end+1,1) = true;

    % read whole text
    txt = fileread(log_path);

    % -------- parse captured --------
    tok_cap = regexp(txt, 'captured\s*=\s*([01])', 'tokens', 'once');
    if ~isempty(tok_cap)
        captured_val = str2double(tok_cap{1});
    else
        captured_val = NaN;
    end

    % -------- parse last idx --------
    tok_idx = regexp(txt, 'last_idx\s*=\s*(\d+)', 'tokens', 'once');
    if ~isempty(tok_idx)
        last_idx_val = str2double(tok_idx{1});
    else
        last_idx_val = NaN;
    end

    captured_list(end+1,1) = captured_val;
    last_idx_list(end+1,1) = last_idx_val;

    if isequal(captured_val, 1)
        fprintf('  Captured.\n');
    elseif isequal(captured_val, 0)
        fprintf('  Not captured.\n');
    else
        fprintf('  Capture status unknown.\n');
    end
end

%% =========================
%  Build summary table
%% =========================
T_summary = table( ...
    task_name_list, ...
    log_found_list, ...
    captured_list, ...
    last_idx_list, ...
    'VariableNames', {'task_name','log_found','captured','last_idx'});

%% =========================
%  Statistics
%% =========================
valid_mask = ~isnan(T_summary.captured);
num_valid  = sum(valid_mask);
num_cap    = sum(T_summary.captured(valid_mask) == 1);
num_fail   = sum(T_summary.captured(valid_mask) == 0);
capture_rate = num_cap / max(num_valid,1);

fprintf('\n================ Summary ================\n');
fprintf('Total task folders   : %d\n', height(T_summary));
fprintf('Valid log parsed     : %d\n', num_valid);
fprintf('Captured             : %d\n', num_cap);
fprintf('Not captured         : %d\n', num_fail);
fprintf('Capture rate         : %.2f%%\n', 100*capture_rate);

%% =========================
%  Print task lists
%% =========================
captured_tasks = T_summary.task_name(T_summary.captured == 1);
failed_tasks   = T_summary.task_name(T_summary.captured == 0);
unknown_tasks  = T_summary.task_name(isnan(T_summary.captured));

fprintf('\nCaptured tasks:\n');
disp(captured_tasks);

fprintf('Not captured tasks:\n');
disp(failed_tasks);

if ~isempty(unknown_tasks)
    fprintf('Unknown-status tasks:\n');
    disp(unknown_tasks);
end

%% =========================
%  Save CSV
%% =========================
out_csv = fullfile(root_dir, 'closed_loop_capture_summary.csv');
writetable(T_summary, out_csv);

fprintf('Summary table saved to:\n%s\n', out_csv);