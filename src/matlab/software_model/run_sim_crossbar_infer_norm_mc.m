function [output_norm_this, spike_count] = run_sim_crossbar_infer_norm_mc(x1, x2, x3, x4, pulse_width, vth)
% =========================================================================
% Function: run_sim_crossbar_infer_norm_mc
%
% Description:
%   MATLAB-based crossbar inference with:
%   1) input spike timing shifted by mc_vout_first_rise_diff.mat
%   2) hidden/output neuron membrane drift modeled by mc slope table
%   3) per-neuron Monte Carlo case idx loaded from CSV (35 rows)
%
% Inputs:
%   x1, x2, x3, x4 : normalized inputs in [0,1]
%   pulse_width    : pulse width (s)
%   vth            : neuron threshold
%
% Outputs:
%   output_norm_this : normalized output
%   spike_count      : spike count at output neuron
% =========================================================================

%% =========================================================
% Validate inputs
%% =========================================================
x_in = [x1, x2, x3, x4];

if numel(x_in) ~= 4
    error('Input must contain exactly 4 normalized values.');
end

if any(~isfinite(x_in))
    error('Inputs must be finite.');
end

x_in = max(0, min(1, x_in));   % clamp to [0,1]

fprintf('Inputs = [%.6f %.6f %.6f %.6f]\n', x_in(1), x_in(2), x_in(3), x_in(4));

%% =========================================================
% Time axis
%% =========================================================
dt = 1e-9;
tstop = 24000e-9;
time_s = (0:dt:tstop).';
N = numel(time_s);

%% =========================================================
% Basic settings
%% =========================================================
Vrest      = 0.920;
spike_amp  = 0.95;
spike_width = pulse_width;

num_steps  = 50;
max_spikes = 25;

usable_tstop = tstop - spike_width;
if usable_tstop <= 0
    error('pulse_width is too large compared with tstop.');
end

%% =========================================================
% Load Monte Carlo neuron case indices from CSV
% CSV must contain 35 rows:
%   1~4   : input neurons
%   5~34  : hidden neurons
%   35    : output neuron
%% =========================================================
case_csv = fullfile(pwd, 'neuron_case_idx.csv');

if ~isfile(case_csv)
    error('Cannot find case index CSV: %s', case_csv);
end

case_idx_all = readmatrix(case_csv);
case_idx_all = case_idx_all(:);

if numel(case_idx_all) ~= 35
    error('Case idx CSV must contain exactly 35 values (4 input + 30 hidden + 1 output).');
end

if any(~isfinite(case_idx_all))
    error('Case idx CSV contains non-finite values.');
end

case_idx_all = round(case_idx_all);

input_case_idx  = case_idx_all(1:4);
hidden_case_idx = case_idx_all(5:34);
output_case_idx = case_idx_all(35);

%% =========================================================
% Load input spike start-time shift table: mc_vout_first_rise_diff.mat
% Expected content:
%   idx     : 51x1 case indices
%   delta_t : 51x1 time shift values (can be +/-)
%% =========================================================
diff_mat = fullfile(pwd, 'mc_vout_first_rise_diff.mat');

if ~isfile(diff_mat)
    error('Cannot find MC input timing diff MAT: %s', diff_mat);
end

Sdiff = load(diff_mat);

if ~isfield(Sdiff, 'idx') || ~isfield(Sdiff, 'delta_t')
    error('mc_vout_first_rise_diff.mat must contain variables "idx" and "delta_t".');
end

mc_idx_vec   = Sdiff.idx(:);
mc_delta_t_vec = Sdiff.delta_t(:);

if numel(mc_idx_vec) ~= numel(mc_delta_t_vec)
    error('idx and delta_t in mc_vout_first_rise_diff.mat must have the same length.');
end

%% =========================================================
% Build input layer spike waveforms
% Rule:
%   1) requested spike number = py_round(x * max_spikes)
%   2) generate actual pulse count using Python-style interval/index logic
%   3) uniformly distribute the ACTUAL pulse count in [0, usable_tstop]
%   4) add delta_t according to the input neuron's case idx
%% =========================================================
Vin1 = 0.9 * ones(N,1);
Vin2 = 0.9 * ones(N,1);
Vin3 = 0.9 * ones(N,1);
Vin4 = 0.9 * ones(N,1);

Vin_cell = {Vin1, Vin2, Vin3, Vin4};
t_spike_cell = cell(4,1);

requested_n_in    = zeros(1,4);
actual_pulses_in  = zeros(1,4);
interval_in       = NaN(1,4);
idx_cell_in       = cell(1,4);
delta_t_in        = zeros(1,4);

available_steps = max(num_steps - 1, 1);

for i = 1:4
    xi = x_in(i);
    case_i = input_case_idx(i);

    % === Step 1: requested spike number, same as Python ===
    n_req = py_round(double(xi) * double(max_spikes));
    n_req = max(0, min(max_spikes, n_req));
    requested_n_in(i) = n_req;

    % === Step 2: if n=0, no pulse ===
    if n_req == 0
        interval_in(i)      = NaN;
        actual_pulses_in(i) = 0;
        idx_cell_in{i}      = [];
        delta_t_in(i)       = lookup_delta_t_from_case(case_i, mc_idx_vec, mc_delta_t_vec);
        t_spike_cell{i}     = [];

        fprintf(['Input %d: x=%.6f, case_idx=%d, n_req=%d, ', ...
                 'interval=NaN, actual_pulses=%d, delta_t=%.4e s\n'], ...
                 i, xi, case_i, n_req, actual_pulses_in(i), delta_t_in(i));
        continue;
    end

    % === Step 3: Python-style interval ===
    raw_interval = double(available_steps) / double(n_req + 1);
    interval_i = py_round(raw_interval);
    interval_i = max(interval_i, 1);
    interval_in(i) = interval_i;

    % === Step 4: Python-style idx generation ===
    idx = interval_i:interval_i:(interval_i * n_req);
    idx = idx(idx < num_steps);

    idx_cell_in{i} = idx;

    % === Step 5: final actual pulse count ===
    Ni_actual = length(idx);
    actual_pulses_in(i) = Ni_actual;

    % === Step 6: uniformly distribute ACTUAL pulse count ===
    t_spike_i = build_uniform_spike_times(Ni_actual, usable_tstop);

    % === Step 7: add MC timing shift from case idx ===
    delta_t_i = lookup_delta_t_from_case(case_i, mc_idx_vec, mc_delta_t_vec);
    delta_t_in(i) = delta_t_i;
    t_spike_i = t_spike_i + delta_t_i;

    % === Step 8: keep only valid spike times inside simulation window ===
    t_spike_i = t_spike_i(t_spike_i >= 0 & t_spike_i <= usable_tstop);
    t_spike_cell{i} = t_spike_i;

    fprintf(['Input %d: x=%.6f, case_idx=%d, n_req=%d, interval=%g, ', ...
             'actual_pulses=%d, delta_t=%.4e s, valid_spikes=%d\n'], ...
             i, xi, case_i, n_req, interval_i, Ni_actual, delta_t_i, numel(t_spike_i));

    % === Step 9: build voltage waveform ===
    Vin_i = 0.9 * ones(N,1);
    for k = 1:numel(t_spike_i)
        t0 = t_spike_i(k);
        Vin_i(time_s >= t0 & time_s < (t0 + spike_width)) = spike_amp;
    end
    Vin_cell{i} = Vin_i;
end

Vin1 = Vin_cell{1};
Vin2 = Vin_cell{2};
Vin3 = Vin_cell{3};
Vin4 = Vin_cell{4};

X_in = [Vin1, Vin2, Vin3, Vin4];   % N x 4

%% =========================================================
% Network size
%% =========================================================
n_in = 4;
n_hidden = 30;
n_out = 1;

%% =========================================================
% Load weight matrices and map them to resistance matrices
%% =========================================================
fc1_file = fullfile(pwd, 'fc1_weight.csv');
fc2_file = fullfile(pwd, 'fc2_weight.csv');
map_file = fullfile(pwd, 'R_delta_table_41.mat');

if ~isfile(fc1_file), error('Cannot find %s', fc1_file); end
if ~isfile(fc2_file), error('Cannot find %s', fc2_file); end
if ~isfile(map_file), error('Cannot find %s', map_file); end

W1 = readmatrix(fc1_file);
W2 = readmatrix(fc2_file);

W1 = W1.';   % -> 4 x 30
W2 = W2.';   % -> 30 x 1

W1 = double(W1);
W2 = double(W2);

if ~isequal(size(W1), [n_in, n_hidden])
    error('fc1_weight size mismatch after transpose. Expected [%d x %d], got [%d x %d].', ...
        n_in, n_hidden, size(W1,1), size(W1,2));
end

if ~isequal(size(W2), [n_hidden, n_out])
    error('fc2_weight size mismatch after transpose. Expected [%d x %d], got [%d x %d].', ...
        n_hidden, n_out, size(W2,1), size(W2,2));
end

Smap = load(map_file);

if isfield(Smap, 'R_delta_table_41')
    R_delta_table_41 = double(Smap.R_delta_table_41);
elseif isfield(Smap, 'R_delta_table')
    R_delta_table_41 = double(Smap.R_delta_table);
else
    error('Cannot find "R_delta_table_41" or "R_delta_table" in %s', map_file);
end

if size(R_delta_table_41,2) < 2
    error('R_delta_table_41 must have at least 2 columns: [R, delta_Vmem].');
end

R_lookup      = abs(R_delta_table_41(:,1));
delta_lookup  = abs(R_delta_table_41(:,2));
weight_lookup = delta_lookup / 0.21;

R1 = zeros(size(W1));
for i = 1:size(W1,1)
    for j = 1:size(W1,2)
        w_target = abs(W1(i,j));
        [~, idx_best] = min(abs(weight_lookup - w_target));
        R1(i,j) = R_lookup(idx_best);
    end
end

R2 = zeros(size(W2));
for i = 1:size(W2,1)
    for j = 1:size(W2,2)
        w_target = abs(W2(i,j));
        [~, idx_best] = min(abs(weight_lookup - w_target));
        R2(i,j) = R_lookup(idx_best);
    end
end

%% =========================================================
% Load MC slope table for membrane drift
% Expected structure:
%   col1 = case idx
%   col2 = delta_v
%   col3 = slope
%% =========================================================
slope_mat = fullfile(pwd, 'mc_net6_slope_all_prints.mat');

if ~isfile(slope_mat)
    error('Cannot find slope MAT: %s', slope_mat);
end

Sslope = load(slope_mat);
mc_slope_table = get_first_numeric_matrix(Sslope);

if isempty(mc_slope_table) || size(mc_slope_table,2) < 3
    error('Cannot find valid slope matrix [case_idx, delta_v, slope] in %s', slope_mat);
end

%% =========================================================
% Neuron base config
%% =========================================================
cfg_base = struct();
cfg_base.C = 73.5e-15;
cfg_base.Vrest = Vrest;
cfg_base.Vth = vth;
cfg_base.reset_time = pulse_width;
cfg_base.Vout_hi = 0.95;
cfg_base.Vout_lo = 0.9;
cfg_base.active_eps = 1e-12;
cfg_base.clamp_to_vrest = true;
cfg_base.mc_slope_table = mc_slope_table;
cfg_base.R_delta_table = R_delta_table_41;

%% =========================================================
% Simulate hidden layer
%% =========================================================
Vhidden = zeros(N, n_hidden);
Vmem_hidden = zeros(N, n_hidden);
spike_hidden = zeros(N, n_hidden);

for j = 1:n_hidden
    Rin_vec_j = R1(:,j).';

    cfg_j = cfg_base;
    cfg_j.mc_case_idx = hidden_case_idx(j);

    out_j = simulate_IF_neuron_v2(time_s, X_in, Rin_vec_j, cfg_j);

    Vhidden(:,j) = out_j.Vout;
    Vmem_hidden(:,j) = out_j.Vmem;
    spike_hidden(:,j) = out_j.spike;
end

%% =========================================================
% Simulate output layer
%% =========================================================
Vout_final = zeros(N, n_out);
Vmem_out = zeros(N, n_out);
spike_out = zeros(N, n_out);

for j = 1:n_out
    Rin_vec_j = R2(:,j).';

    cfg_j = cfg_base;
    cfg_j.mc_case_idx = output_case_idx;

    out_j = simulate_IF_neuron_v2(time_s, Vhidden, Rin_vec_j, cfg_j);

    Vout_final(:,j) = out_j.Vout;
    Vmem_out(:,j) = out_j.Vmem;
    spike_out(:,j) = out_j.spike;
end

%% =========================================================
% Count spikes at output neuron
%% =========================================================
thresh_spike = 0.94;
norm_factor  = 25;
time_limit   = 24e-6;

mask = time_s < time_limit;
v_use = Vout_final(mask,1);

if numel(v_use) < 2
    error('Not enough waveform points before %.3f us.', time_limit * 1e6);
end

spike_count = sum(v_use(1:end-1) < thresh_spike & v_use(2:end) >= thresh_spike);
output_norm_this = spike_count / norm_factor;

fprintf('Inference done (t < %.3f us): spike_count=%d, norm=%.6f\n', ...
    time_limit * 1e6, spike_count, output_norm_this);
figure;
plot(time_s*1e6, X_in(:,1), 'LineWidth', 1);
hold on;
yline(0.94, '--r', 'thresh=0.94');
xlabel('Time (us)');
ylabel('Vout final');
title('Output neuron waveform');
grid on;
end

%% ===== Local function: mimic Python round() =====
function y = py_round(x)
    % Mimic Python 3 round(x):
    % round-half-to-even (banker's rounding)

    f = floor(x);
    frac = x - f;

    tol = 1e-12;

    if frac < 0.5 - tol
        y = f;
    elseif frac > 0.5 + tol
        y = f + 1;
    else
        % exactly .5 -> round to even
        if mod(f, 2) == 0
            y = f;
        else
            y = f + 1;
        end
    end
end

function t_spike = build_uniform_spike_times(n_spike, usable_tstop)
% Example:
%   n_spike = 1 -> t = T/2
%   n_spike = 2 -> t = T/3, 2T/3
%   n_spike = 3 -> t = T/4, 2T/4, 3T/4

    if n_spike <= 0
        t_spike = [];
        return;
    end

    t_spike = (1:n_spike).' * (usable_tstop / (n_spike + 1));
end

function delta_t = lookup_delta_t_from_case(case_idx, idx_vec, delta_t_vec)
    hit = find(idx_vec == case_idx, 1, 'first');

    if isempty(hit)
        error('Cannot find case_idx=%d in mc_vout_first_rise_diff.mat.', case_idx);
    end

    delta_t = delta_t_vec(hit);
end
function A = get_first_numeric_matrix(S)
    A = [];
    fn = fieldnames(S);

    for i = 1:numel(fn)
        val = S.(fn{i});
        if isnumeric(val) && ismatrix(val)
            A = double(val);
            return;
        end
    end
end