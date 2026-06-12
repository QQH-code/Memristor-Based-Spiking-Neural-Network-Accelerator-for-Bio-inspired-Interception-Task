% =========================================================================
% Script:   collect_mc_pulse_metrics_simple.m
% Purpose:
%   Read Spectre Monte Carlo .print results, use case 0 as reference,
%   and save only:
%       1) iter
%       2) signed start-time difference relative to case 0
%       3) pulse-width ratio relative to case 0
%
% Definitions:
%   - start time  = first upward crossing time of v(out) through thresh_cross
%   - pulse width = first downward crossing time - first upward crossing time
%
% Special rule:
%   - case 0 is included
%   - case 0 has:
%         delta_t_start_vs_case0_s = 0
%         width_ratio_vs_case0     = 1
% =========================================================================

clear; clc;

%% =========================
% User settings
%% =========================
task_id_str   = 'single_neuron';
run_dir       = fullfile(pwd, sprintf('mc_run_%s', task_id_str));
print_file    = fullfile(run_dir, sprintf('mc_%s.print', task_id_str));

thresh_cross  = 0.902;

save_mat_name = fullfile(run_dir, 'mc_pulse_metrics_simple.mat');
save_csv_name = fullfile(run_dir, 'mc_pulse_metrics_simple.csv');

%% =========================
% Check file
%% =========================
if ~isfile(print_file)
    error('Cannot find Monte Carlo print file:\n%s', print_file);
end

fprintf('Reading Monte Carlo print file:\n%s\n', print_file);

%% =========================
% Import all MC runs
%% =========================
mc_runs = import_spectre_mc_print(print_file);

if isempty(mc_runs)
    error('No Monte Carlo cases were parsed from %s', print_file);
end

%% =========================
% Find reference case 0
%% =========================
ref_idx = find([mc_runs.iter] == 0, 1, 'first');
if isempty(ref_idx)
    error('Cannot find nominal case (iter = 0).');
end

name_ref = mc_runs(ref_idx).name;
res_ref  = mc_runs(ref_idx).res;

idx_out_ref = find(strcmpi(name_ref, 'v(out)'), 1);
if isempty(idx_out_ref)
    error('Cannot find v(out) in nominal case.');
end

time_ref = res_ref(:,1);
vout_ref = res_ref(:,idx_out_ref);

[t_up_ref, ~, width_ref] = local_first_pulse_metrics(time_ref, vout_ref, thresh_cross);

if isnan(t_up_ref)
    error('Nominal case 0 does not have a valid first upward crossing.');
end
if isnan(width_ref) || width_ref <= 0
    error('Nominal case 0 does not have a valid pulse width.');
end

%% =========================
% Collect only required metrics
%% =========================
iter_list          = [];
delta_t_start_list = [];
width_ratio_list   = [];

for k = 1:numel(mc_runs)
    name_k = mc_runs(k).name;
    res_k  = mc_runs(k).res;

    idx_out_k = find(strcmpi(name_k, 'v(out)'), 1);
    if isempty(idx_out_k)
        continue;
    end

    time_k = res_k(:,1);
    vout_k = res_k(:,idx_out_k);

    [t_up_k, ~, width_k] = local_first_pulse_metrics(time_k, vout_k, thresh_cross);

    if isnan(t_up_k) || isnan(width_k) || width_k <= 0
        continue;
    end

    iter_list(end+1,1) = mc_runs(k).iter; %#ok<AGROW>

    if mc_runs(k).iter == 0
        delta_t_start_list(end+1,1) = 0; %#ok<AGROW>
        width_ratio_list(end+1,1)   = 1; %#ok<AGROW>
    else
        delta_t_start_list(end+1,1) = t_up_k - t_up_ref; %#ok<AGROW>
        width_ratio_list(end+1,1)   = width_k / width_ref; %#ok<AGROW>
    end
end

%% =========================
% Build result table
%% =========================
T_metrics = table( ...
    iter_list, ...
    delta_t_start_list, ...
    width_ratio_list, ...
    'VariableNames', { ...
    'iter', ...
    'delta_t_start_vs_case0_s', ...
    'width_ratio_vs_case0'} ...
    );

T_metrics = sortrows(T_metrics, 'iter');

%% =========================
% Save results
%% =========================
save(save_mat_name, 'T_metrics');
writetable(T_metrics, save_csv_name);

fprintf('\nSaved:\n');
fprintf('  %s\n', save_mat_name);
fprintf('  %s\n', save_csv_name);

%% =========================================================================
% Functions
%% =========================================================================
function mc_runs = import_spectre_mc_print(file)
fid = fopen(file, 'r');
assert(fid > 0, 'Cannot open file: %s', file);
C = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);

L = C{1};
nL = numel(L);

iter_lines = [];
iter_nums  = [];

for i = 1:nL
    li = strtrim(L{i});
    tok = regexp(li, '\*\*\*\s*montecarlo_iteration\s*=\s*([+\-]?\d*\.?\d+)', 'tokens', 'once');
    if ~isempty(tok)
        iter_lines(end+1) = i; %#ok<AGROW>
        iter_nums(end+1)  = round(str2double(tok{1})); %#ok<AGROW>
    end
end

if isempty(iter_lines)
    error('No montecarlo_iteration blocks found in %s', file);
end

mc_runs = struct('iter', {}, 'name', {}, 'res', {});

for b = 1:numel(iter_lines)
    i_start = iter_lines(b);
    if b < numel(iter_lines)
        i_end = iter_lines(b+1) - 1;
    else
        i_end = nL;
    end

    block_lines = L(i_start:i_end);

    ih_local = [];
    for j = 1:numel(block_lines)
        li = strtrim(block_lines{j});
        if isempty(li) || startsWith(li, '*')
            continue;
        end
        toks = regexp(li, '\S+', 'match');
        if ~isempty(toks) && strcmpi(toks{1}, 'time')
            ih_local = j;
            break;
        end
    end

    if isempty(ih_local)
        warning('Skip MC iteration %d because header was not found.', iter_nums(b));
        continue;
    end

    [res, name] = parse_single_block(block_lines, ih_local);

    mc_runs(end+1).iter = iter_nums(b); %#ok<AGROW>
    mc_runs(end).name   = name;
    mc_runs(end).res    = res;
end
end

function [block, header] = parse_single_block(L, ih)
header = regexp(strtrim(L{ih}), '\S+', 'match');
K = numel(header);

rows = {};
for i = ih+1:numel(L)
    li = strtrim(L{i});
    if isempty(li)
        break;
    end
    if isempty(regexp(li, '^[+\-]?\d', 'once'))
        break;
    end
    rows{end+1} = li; %#ok<AGROW>
end

N = numel(rows);
block = nan(N, K);

for r = 1:N
    block(r,1:K) = parse_row(rows{r}, K);
end

goodCol = any(~isnan(block), 1);
block   = block(:, goodCol);
header  = header(goodCol);

[block(:,1), ord] = sort(block(:,1));
block = block(ord,:);
[~, iu] = unique(block(:,1), 'stable');
block = block(iu,:);
end

function vals = parse_row(line, K)
scale = containers.Map( ...
    {'f','p','n','u','m','','k','K','M','G','T'}, ...
    [1e-15 1e-12 1e-9 1e-6 1e-3 1 1e3 1e3 1e6 1e9 1e12]);

tok = regexp(line, '([+\-]?\d*\.?\d+(?:[eE][+\-]?\d+)?)\s*([fpnumkKMGＴTG]?)', 'tokens');
if isempty(tok)
    error('Cannot parse numeric line: %s', line);
end

vals = nan(1, K);
take = min(K, numel(tok));
for c = 1:take
    v = str2double(tok{c}{1});
    u = tok{c}{2};
    if ~isKey(scale, u)
        u = lower(u);
    end
    s = 1;
    if isKey(scale, u), s = scale(u); end
    vals(c) = v * s;
end
end

function [t_up, t_dn, pulse_width] = local_first_pulse_metrics(time_s, v, thresh)
t_up = nan;
t_dn = nan;
pulse_width = nan;

idx_up = find(v(1:end-1) < thresh & v(2:end) >= thresh, 1, 'first');
if isempty(idx_up)
    return;
end

t1 = time_s(idx_up);
t2 = time_s(idx_up+1);
v1 = v(idx_up);
v2 = v(idx_up+1);

if v2 == v1
    t_up = t2;
else
    t_up = t1 + (thresh - v1) * (t2 - t1) / (v2 - v1);
end

idx_dn_rel = find(v(idx_up+1:end-1) >= thresh & v(idx_up+2:end) < thresh, 1, 'first');
if isempty(idx_dn_rel)
    return;
end

idx_dn = idx_up + idx_dn_rel;

t1 = time_s(idx_dn);
t2 = time_s(idx_dn+1);
v1 = v(idx_dn);
v2 = v(idx_dn+1);

if v2 == v1
    t_dn = t2;
else
    t_dn = t1 + (thresh - v1) * (t2 - t1) / (v2 - v1);
end

pulse_width = t_dn - t_up;
end