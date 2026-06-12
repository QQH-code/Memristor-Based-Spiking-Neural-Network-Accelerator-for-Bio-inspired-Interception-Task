clc;
clear;
close all;

%% =========================================================
% Sweep synapse resistance for 41-level delta_v matching
%% =========================================================
ref_mat_file = 'sweep_membrane_delta_results.mat';

% ---- resistance sweep range (edit if needed) ----
R_sweep = linspace(2e4, 7e6, 4000).';   % Ohm

% ---- time settings ----
dt = 1e-9;
tstop = 500e-9;
time_s = (0:dt:tstop).';
N = numel(time_s);

% ---- one input pulse settings ----
pulse_t0    = 350e-9;
pulse_width = 55e-9;
Vin_base    = 0.9;
Vin_high    = 0.95;

% ---- neuron config ----
cfg = struct();
cfg.C          = 73.5e-15;
cfg.Vrest      = 0.920;
cfg.Vth        = 0.709;
cfg.reset_time = 55e-9;
cfg.Vout_hi    = 0.95;
cfg.Vout_lo    = 0.9;

% measurement window after pulse starts
measure_t1 = pulse_t0;
measure_t2 = pulse_t0 + 60e-9;

%% =========================================================
% Build one-pulse input waveform
%% =========================================================
Vin = Vin_base * ones(N,1);
Vin(time_s >= pulse_t0 & time_s < (pulse_t0 + pulse_width)) = Vin_high;

%% =========================================================
% Load reference delta_v table
%% =========================================================
Sref = load(ref_mat_file);
fn_ref = fieldnames(Sref);

T_ref = [];
for k = 1:numel(fn_ref)
    if istable(Sref.(fn_ref{k}))
        T_ref = Sref.(fn_ref{k});
        break;
    end
end

if isempty(T_ref)
    error('No table variable found in %s', ref_mat_file);
end

if ~all(ismember({'case_idx','delta_v'}, T_ref.Properties.VariableNames))
    error('Reference table must contain columns: case_idx, delta_v');
end

case_idx_ref = T_ref.case_idx(:);
delta_ref    = T_ref.delta_v(:);

if numel(delta_ref) ~= 41
    warning('Reference table has %d rows, not 41. Code will still run.', numel(delta_ref));
end

%% =========================================================
% Sweep R and record delta_v
%% =========================================================
num_R = numel(R_sweep);

delta_all  = zeros(num_R, 1);
Vpre_all   = zeros(num_R, 1);
Vmin_all   = zeros(num_R, 1);

fprintf('Sweeping %d resistance points...\n', num_R);

for i = 1:num_R
    R_syn = R_sweep(i);

    Vin_mat = Vin;
    Rin_vec = R_syn;
    out = simulate_IF_neuron(time_s, Vin_mat, Rin_vec, cfg);

    Vmem = out.Vmem;

    idx_pre = find(time_s < pulse_t0, 1, 'last');
    if isempty(idx_pre)
        error('Cannot find pre-pulse sample.');
    end

    idx_win = (time_s >= measure_t1) & (time_s <= measure_t2);
    if ~any(idx_win)
        error('Measurement window is empty.');
    end

    Vpre = Vmem(idx_pre);
    Vmin = min(Vmem(idx_win));

    delta_v = Vmin - Vpre;   % negative drop

    Vpre_all(i)  = Vpre;
    Vmin_all(i)  = Vmin;
    delta_all(i) = delta_v;
end

%% =========================================================
% Match reference delta_v to nearest swept delta_v
%% =========================================================
num_ref = numel(delta_ref);

matched_case_idx   = zeros(num_ref,1);
target_delta_v     = zeros(num_ref,1);
matched_delta_v    = zeros(num_ref,1);
matched_R_ohm      = zeros(num_ref,1);
abs_error          = zeros(num_ref,1);
matched_sweep_idx  = zeros(num_ref,1);

for k = 1:num_ref
    dv_target = delta_ref(k);

    [err_min, idx_best] = min(abs(delta_all - dv_target));

    matched_case_idx(k)  = case_idx_ref(k);
    target_delta_v(k)    = dv_target;
    matched_delta_v(k)   = delta_all(idx_best);
    matched_R_ohm(k)     = R_sweep(idx_best);
    abs_error(k)         = err_min;
    matched_sweep_idx(k) = idx_best;
end

%% =========================================================
% Save only one MAT:
%   col 1 = matched resistance
%   col 2 = matched delta_v
%% =========================================================
R_delta_table_41 = [matched_R_ohm, matched_delta_v];
save('R_delta_table_41.mat', 'R_delta_table_41');

fprintf('\nDone.\n');
fprintf('Saved:\n');
fprintf('  R_delta_table_41.mat\n');

%% =========================================================
% Plot only one figure
%% =========================================================
figure;
plot(R_delta_table_41(:,1), R_delta_table_41(:,2), 'o-', 'LineWidth', 1.5);
xlabel('Resistance (Ohm)');
ylabel('\DeltaV_{mem} (V)');
title('Matched 41 Levels: Resistance vs \DeltaV_{mem}');
grid on;