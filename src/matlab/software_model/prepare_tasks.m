clc;
clear;
close all;

%% =========================
% User settings
%% =========================
num_tasks = 200;   % number of random task folders: task_0001 ~ task_0200

% Source directory containing all template files
source_dir = pwd;
% 例如：
% source_dir = '$PROJECT_ROOT';

% Destination root folder
tasks_root = fullfile(source_dir, 'tasks');

% Base seed for per-task neuron_case_idx generation
base_seed = 1;

% case idx range
case_min = 0;
case_max = 50;

% neuron counts
num_input  = 4;
num_hidden = 30;
num_output = 1;
num_total  = num_input + num_hidden + num_output;   % 35

%% =========================
% Files to copy into each task
%% =========================
file_list = { ...
    'whole_system_run.m', ...
    'R_delta_table_41.mat', ...
    'prey_trajectories_500x50.csv', ...
    'simulate_IF_neuron_v2.m', ...
    'run_sim_crossbar_infer_norm_mc.m', ...
    'fc1_weight.csv', ...
    'fc2_weight.csv', ...
    'mc_net6_slope_all_prints.mat', ...
    'mc_vout_first_rise_diff.mat' ...
    };

%% =========================
% Check source files exist
%% =========================
fprintf('Checking source files in:\n%s\n\n', source_dir);

for i = 1:numel(file_list)
    src_file = fullfile(source_dir, file_list{i});
    if ~isfile(src_file)
        error('Cannot find source file: %s', src_file);
    end
    fprintf('Found: %s\n', file_list{i});
end

%% =========================
% Create tasks root folder
%% =========================
if ~exist(tasks_root, 'dir')
    mkdir(tasks_root);
    fprintf('\nCreated tasks root folder:\n%s\n', tasks_root);
else
    fprintf('\nTasks root folder already exists:\n%s\n', tasks_root);
end

%% =========================
% First create task_0000 (nominal task)
%% =========================
task_name = 'task_0000';
task_dir  = fullfile(tasks_root, task_name);

if ~exist(task_dir, 'dir')
    mkdir(task_dir);
end

% Copy each required file
for i = 1:numel(file_list)
    src_file = fullfile(source_dir, file_list{i});
    dst_file = fullfile(task_dir, file_list{i});
    copyfile(src_file, dst_file);
end

% neuron_case_idx.csv for nominal task: all zeros
case_idx_all = zeros(num_total, 1);

csv_out = fullfile(task_dir, 'neuron_case_idx.csv');
writematrix(case_idx_all, csv_out);

fprintf('Prepared %s | nominal task | neuron_case_idx.csv = all zeros\n', task_name);

%% =========================
% Create random tasks: task_0001 ~ task_0200
%% =========================
fprintf('\nPreparing %d random task folders...\n', num_tasks);

for k = 1:num_tasks
    task_name = sprintf('task_%04d', k);
    task_dir  = fullfile(tasks_root, task_name);

    % Create task folder
    if ~exist(task_dir, 'dir')
        mkdir(task_dir);
    end

    % Copy each required file
    for i = 1:numel(file_list)
        src_file = fullfile(source_dir, file_list{i});
        dst_file = fullfile(task_dir, file_list{i});
        copyfile(src_file, dst_file);
    end

    % -------------------------------------------------
    % Generate a unique neuron_case_idx.csv for this task
    % -------------------------------------------------
    task_seed = base_seed + (k - 1);
    rng(task_seed, 'twister');

    case_idx_all = randi([case_min, case_max], num_total, 1);

    csv_out = fullfile(task_dir, 'neuron_case_idx.csv');
    writematrix(case_idx_all, csv_out);

    fprintf('Prepared %s | seed=%d | neuron_case_idx.csv generated\n', ...
        task_name, task_seed);
end

%% =========================
% Summary
%% =========================
fprintf('\nAll done.\n');
fprintf('Created 1 nominal task + %d random tasks under:\n%s\n', num_tasks, tasks_root);
fprintf('Nominal task : task_0000 (all zeros in neuron_case_idx.csv)\n');
fprintf('Random tasks : task_0001 ~ task_%04d\n', num_tasks);
fprintf('Random task seed rule: seed = base_seed + task_id - 1\n');