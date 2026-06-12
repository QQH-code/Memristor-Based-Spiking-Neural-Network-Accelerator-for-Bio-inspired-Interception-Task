function [output_norm_this, spike_count] = run_spectre_crossbar_infer_norm(x1, x2, x3, x4)
% =========================================================================
% Function: run_spectre_crossbar_infer_norm
%
% Description:
%   Run Spectre-based SNN memristor crossbar inference for one sample.
%
% Inputs:
%   x1, x2, x3, x4 : normalized inputs in [0,1]
%
% Outputs:
%   output_norm_this : normalized output
%   spike_count      : spike count at out3_1
% =========================================================================

%% ========== Validate direct normalized inputs ==========
x_in = [x1, x2, x3, x4];

if numel(x_in) ~= 4
    error('Input must contain exactly 4 normalized values.');
end

if any(~isfinite(x_in))
    error('Inputs must be finite.');
end

x_in = max(0, min(1, x_in));   % clamp to [0,1]
run_name = 'test_run';

%% ========== Parameters ==========

% col, row
n_row = 4;       % the number of input layer neurons
n_col = 30;       % the number of hidden layer neurons
n_out = 1;    % number of output layer neurons

% Input series resistor at each row.
Rin_val = 800e3;   % 800 kΩ

% Bias signals
VDD_val   = 1.8;
Vhigh_T_val  = 1.8;
Vhigh_val  = 0.95;
POS_val   = 0.9;
VTH1_val  = 0.71;   % V
VTH2_val  = 0.88;   % V
IBIAS_val = 6e-6;  % A


tstop = 24e-6; % 24us

trise = 5e-9;
tfall = 5e-9;
twidth = 60e-9;

%% ========== Weight-to-RRAM mapping from CSV and MAT tables ==========

% ---------- File paths ----------
fc1_csv_path   = fullfile(pwd, 'fc1_weight.csv');
delta_mat_path = fullfile(pwd, 'sweep_membrane_delta_results.mat');
res_mat_path = fullfile(pwd, 'sweep_rram_resistance_results.mat');

% ---------- 1) Read fc1 weight CSV and transpose ----------
T_fc1 = readtable(fc1_csv_path, 'VariableNamingRule', 'preserve');
W_raw = table2array(T_fc1);      % expected size: 30 x 4
W_map = W_raw.';                 % now: 4 x 30


fc2_csv_path = fullfile(pwd, 'fc2_weight.csv');

T_fc2 = readtable(fc2_csv_path, 'VariableNamingRule', 'preserve');
W2_raw = table2array(T_fc2);      % expected size: 1 x 30
W2_map = W2_raw.';                % now: 30 x 1

if size(W_map,1) ~= n_row || size(W_map,2) ~= n_col
	error('Transposed fc1 weight size is %dx%d, but crossbar size is %dx%d.', ...
		size(W_map,1), size(W_map,2), n_row, n_col);
end

if size(W2_map,1) ~= n_col || size(W2_map,2) ~= n_out
	error('Transposed fc2 weight size is %dx%d, but expected %dx%d.', ...
		size(W2_map,1), size(W2_map,2), n_col, n_out);
end

fprintf('Loaded fc2_weight.csv and transposed to %dx%d.\n', size(W2_map,1), size(W2_map,2));

fprintf('Loaded fc1_weight.csv and transposed to %dx%d.\n', size(W_map,1), size(W_map,2));

% ---------- 2) Load sweep_membrane_delta_results.mat ----------
S_delta = load(delta_mat_path);
fn_delta = fieldnames(S_delta);
delta_table = S_delta.(fn_delta{1});   % assume the first variable is the table

if ~istable(delta_table)
	error('The variable loaded from %s is not a table.', delta_mat_path);
end

% Need columns: case_idx, delta_v
if ~all(ismember({'case_idx','delta_v'}, delta_table.Properties.VariableNames))
	error('delta_table must contain columns: case_idx and delta_v.');
end

delta_metric = abs(delta_table.delta_v) ./ 0.21;
case_idx_list = delta_table.case_idx;

% ---------- 3) Load sweep_rram_resistance_results.mat ----------
S_res = load(res_mat_path);
fn_res = fieldnames(S_res);
T_res = S_res.(fn_res{1});   % assume first variable is the table

if ~istable(T_res)
    error('The variable loaded from %s is not a table.', res_mat_path);
end

needed_cols_res = {'case_idx','R_A_ohm','R_B_ohm'};
if ~all(ismember(needed_cols_res, T_res.Properties.VariableNames))
    error('Resistance table must contain columns: case_idx, R_A_ohm, R_B_ohm.');
end


RA_map = zeros(n_row, n_col);
RB_map = zeros(n_row, n_col);
case_map = zeros(n_row, n_col);

for i = 1:n_row
    for j = 1:n_col
        w_target = W_map(i,j);

        % Find nearest delta metric
        [~, idx_nearest] = min(abs(delta_metric - w_target));
        case_id = case_idx_list(idx_nearest);
        case_map(i,j) = case_id;

        % Find corresponding row in resistance table
        idx_res = find(T_res.case_idx == case_id, 1, 'first');
        if isempty(idx_res)
            error('Cannot find case_idx=%d in resistance table.', case_id);
        end

        RA_map(i,j) = T_res.R_A_ohm(idx_res);
        RB_map(i,j) = T_res.R_B_ohm(idx_res);
    end
end

RA_map2 = zeros(n_col, n_out);
RB_map2 = zeros(n_col, n_out);
case_map2 = zeros(n_col, n_out);

for i = 1:n_col
    for j = 1:n_out
        w_target = W2_map(i,j);

        [~, idx_nearest] = min(abs(delta_metric - w_target));
        case_id = case_idx_list(idx_nearest);
        case_map2(i,j) = case_id;

        idx_res = find(T_res.case_idx == case_id, 1, 'first');
        if isempty(idx_res)
            error('Cannot find case_idx=%d in resistance table.', case_id);
        end

        RA_map2(i,j) = T_res.R_A_ohm(idx_res);
        RB_map2(i,j) = T_res.R_B_ohm(idx_res);
    end
end



fprintf('Completed weight-to-RRAM A/B initialization mapping for all cells.\n');

%% ========== Compute parallel equivalent resistance ==========
Req_map  = (RA_map .* RB_map) ./ (RA_map + RB_map);
Req_map2 = (RA_map2 .* RB_map2) ./ (RA_map2 + RB_map2);

fprintf('Computed parallel equivalent resistance maps.\n');

%% ========== Save only parallel equivalent resistance results ==========
map_save_name = sprintf('mapped_parallel_rram_%s.mat', run_name);

save(map_save_name, ...
    'Req_map', 'Req_map2');

fprintf('Saved parallel equivalent resistance results to: %s\n', map_save_name);

%% ========== Apply read noise to all RRAM cells ==========
fprintf('Inputs = [%.6f %.6f %.6f %.6f]\n', x_in(1), x_in(2), x_in(3), x_in(4));

if numel(x_in) ~= n_row
	error('Number of normalized inputs must equal n_row.');
end

% Output netlist filename

scs_file = sprintf('Neuron_v35_crossbar_%s.scs', run_name);




%% ========== Load tpulse lookup table ==========
tpulse_mat_path = fullfile(pwd, 'tpulse_scan_results_1to24.mat');

S_tp = load(tpulse_mat_path);
fn_tp = fieldnames(S_tp);

if isempty(fn_tp)
    error('No variable found in %s.', tpulse_mat_path);
end

tpulse_table = S_tp.(fn_tp{1});   % e.g. scan_results

if ~istable(tpulse_table)
	error('Loaded variable from %s is not a table.', tpulse_mat_path);
end

% New scan_results table format
needed_cols_tp = {'target_pulses','best_tpulse_ns'};
if ~all(ismember(needed_cols_tp, tpulse_table.Properties.VariableNames))
	error(['tpulse scan table must contain at least these columns: ', ...
           'target_pulses, best_tpulse_ns']);
end

% Keep only valid rows
valid_tp = ~isnan(tpulse_table.target_pulses) & ~isnan(tpulse_table.best_tpulse_ns);
tpulse_table = tpulse_table(valid_tp, :);

% Sort by target_pulses for robust nearest matching
tpulse_table = sortrows(tpulse_table, 'target_pulses');
%% ========== Map normalized inputs -> requested n -> actual pulse count -> tpulse ==========
num_steps  = 50;
max_spikes = 25;

available_steps = max(num_steps - 1, 1);

requested_n_in     = zeros(1, n_row);   % n = round(x * max_spikes)
actual_pulses_in   = zeros(1, n_row);   % final actual pulse count after idx filtering
interval_in        = zeros(1, n_row);   % interval used by deterministic coding
idx_cell_in        = cell(1, n_row);    % optional: save pulse indices

tpulse_in_ns = zeros(1, n_row);
tpulse_in_s  = zeros(1, n_row);

for i = 1:n_row
    xi = x_in(i);

    % === Step 1: requested spike number, same as Python ===
    n_req = py_round(double(xi) * double(max_spikes));
    n_req = max(0, min(max_spikes, n_req));
    requested_n_in(i) = n_req;

    % === Step 2: if n=0, no pulse ===
    if n_req == 0
        interval_in(i)      = NaN;
        actual_pulses_in(i) = 0;
        idx_cell_in{i}      = [];
        tpulse_in_ns(i)     = NaN;
        tpulse_in_s(i)      = NaN;
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

    % === Step 6: use actual pulse count to look up tpulse ===
    pulse_candidates = tpulse_table.target_pulses;
    [~, idx_tp] = min(abs(pulse_candidates - Ni_actual));

    matched_pulses = tpulse_table.target_pulses(idx_tp);
    tpulse_in_ns(i) = tpulse_table.best_tpulse_ns(idx_tp);
    tpulse_in_s(i)  = tpulse_in_ns(i) * 1e-9;

    if matched_pulses ~= Ni_actual
        warning('Row %d: actual_pulses=%d not found exactly in tpulse table, using nearest target_pulses=%d.', ...
            i, Ni_actual, matched_pulses);
    end
end

disp(table((1:n_row)', x_in(:), requested_n_in(:), interval_in(:), ...
    actual_pulses_in(:), tpulse_in_ns(:), ...
    'VariableNames', {'row_idx','x_norm','requested_n','interval','actual_pulses','tpulse_ns'}));


%% ========== Open the .scs file ==========

fid = fopen(scs_file, 'w');
if fid == -1
	error('Unable to open %s for writing', scs_file);
end

fprintf('Generating Spectre netlist: %s\n', scs_file);

%% ========== Head & include ==========

fprintf(fid, '// Automatically generated n x m Neuron_v35 crossbar\n');
fprintf(fid, '// n_row = %d, n_col = %d\n\n', n_row, n_col);
fprintf(fid, 'simulator lang=spectre\n');
fprintf(fid, 'global 0\n\n');

fprintf(fid, 'include "$PROJECT_ROOT" section=tt\n\n');
va_file_path = fullfile(pwd, 'resistor_rand_min.va');
fprintf(fid, 'ahdl_include "%s"\n\n', va_file_path);
%% ========== Subckt Definitions ==========

% -------- 7TOpamp --------
fprintf(fid, '// Library name: snn1\n');
fprintf(fid, '// Cell name: 7TOpamp\n');
fprintf(fid, '// View name: schematic\n');
fprintf(fid, 'subckt snn1_7TOpamp_schematic Ibias VDD VSS neg out pos\n');
fprintf(fid, '    PM1 (out net21 VDD VDD) pfet_01v8 w=(1.1u) l=650n as=169.278f ad=169.278f ps=1.53u pd=1.53u m=(1)*(9)\n');
fprintf(fid, '    PM3 (net21 net18 VDD VDD) pfet_01v8 w=(1u) l=650n as=265f ad=140f ps=2.53u pd=1.28u m=(1)*(2)\n');
fprintf(fid, '    PM0 (net18 net18 VDD VDD) pfet_01v8 w=(1u) l=650n as=265f ad=140f  ps=2.53u pd=1.28u m=(1)*(2)\n');
fprintf(fid, '    NM5 (out Ibias VSS VSS) nfet_01v8 w=(425n) l=650n as=86.0625f ad=59.5f ps=1.0425u pd=705n m=(1)*(4)\n');
fprintf(fid, '    NM4 (Ibias Ibias VSS VSS) nfet_01v8 w=(425n) l=650n as=112.625f ad=59.5f ps=1.38u pd=705n m=(1)*(2)\n');
fprintf(fid, '    NM3 (net17 Ibias VSS VSS) nfet_01v8 w=(425n) l=650n as=112.625f ad=59.5f ps=1.38u pd=705n m=(1)*(2)\n');
fprintf(fid, '    NM2 (net21 pos net17 VSS) nfet_01v8 w=(1u) l=650n as=202.5f ad=140f ps=1.905u pd=1.28u m=(1)*(4)\n');
fprintf(fid, '    NM1 (net18 neg net17 VSS) nfet_01v8 w=(1u) l=650n as=202.5f ad=140f ps=1.905u pd=1.28u m=(1)*(4)\n');
fprintf(fid, '    R0 (net21 net028 VSS) res_xhigh_po_0p35 r=21.8031K l=3u w=350n\n');
fprintf(fid, '    C0 (out net028) cap_mim_m3_1 l=5.5u w=5.5u m=2\n');
fprintf(fid, 'ends snn1_7TOpamp_schematic\n\n');

% -------- CMP --------
fprintf(fid, '// Library name: snn1\n');
fprintf(fid, '// Cell name: CMP\n');
fprintf(fid, '// View name: schematic\n');
fprintf(fid, 'subckt CMP Ibias VDD VSS neg out pos\n');
fprintf(fid, '    NM4 (Ibias Ibias VSS VSS) nfet_01v8 w=(425n) l=650n as=112.625f ad=59.5f ps=1.38u pd=705n m=(1)*(2)\n');
fprintf(fid, '    NM3 (net17 Ibias VSS VSS) nfet_01v8 w=(425n) l=650n as=112.625f ad=59.5f ps=1.38u pd=705n m=(1)*(2)\n');
fprintf(fid, '    NM2 (out Ibias VSS VSS) nfet_01v8 w=(425n) l=650n as=86.0625f ad=59.5f ps=1.0425u pd=705n m=(1)*(4)\n');
fprintf(fid, '    NM1 (net20 pos net17 net17) nfet_01v8 w=(1u) l=650n as=202.5f ad=140f ps=1.905u pd=1.28u m=(1)*(4)\n');
fprintf(fid, '    NM0 (net18 neg net17 net17) nfet_01v8 w=(1u) l=650n as=202.5f ad=140f ps=1.905u pd=1.28u m=(1)*(4)\n');
fprintf(fid, '    PM2 (out net20 VDD VDD) pfet_01v8 w=(1.1u) l=650n as=169.278f ad=169.278f ps=1.53u pd=1.53u m=(1)*(9)\n');
fprintf(fid, '    PM1 (net20 net18 VDD VDD) pfet_01v8 w=(1u) l=650n as=265f ad=140f ps=2.53u pd=1.28u m=(1)*(2)\n');
fprintf(fid, '    PM0 (net18 net18 VDD VDD) pfet_01v8 w=(1u) l=650n as=265f ad=140f ps=2.53u pd=1.28u m=(1)*(2)\n');
fprintf(fid, 'ends CMP\n\n');


% -------- Neuron_v35 --------
fprintf(fid, '// Library name: snn1\n');
fprintf(fid, '// Cell name: neuron_v35\n');
fprintf(fid, '// View name: schematic\n');
fprintf(fid, 'subckt neuron_v35 Tout ib1 ib2 neg out pos vdd vhigh vhigh_T vlow vss vth1 \\\n');
fprintf(fid, '        vth2\n');
fprintf(fid, '    I0 (ib1 vdd vss neg net6 pos) snn1_7TOpamp_schematic\n');
fprintf(fid, '    I1 (ib2 vdd vss net6 net10 net7) CMP\n');
fprintf(fid, '    PM13 (Tout net48 vhigh_T vdd) pfet_01v8 w=(550n) l=150n as=84.6389f \\\n');
fprintf(fid, '        ad=77f ps=918.889n pd=830n m=(1)*(18)\n');
fprintf(fid, '    PM12 (Tout net24 vlow vdd) pfet_01v8 w=(550n) l=150n as=84.6389f \\\n');
fprintf(fid, '        ad=77f ps=918.889n pd=830n m=(1)*(18)\n');
fprintf(fid, '    PM11 (out net48 vhigh vdd) pfet_01v8 w=(5u) l=150n as=719.531f ad=700f \\\n');
fprintf(fid, '        ps=5.44406u pd=5.28u m=(1)*(64)\n');
fprintf(fid, '    PM5 (out net24 vlow vdd) pfet_01v8 w=(5u) l=150n as=719.531f ad=700f \\\n');
fprintf(fid, '        ps=5.44406u pd=5.28u m=(1)*(64)\n');
fprintf(fid, '    PM4 (net48 net24 vdd vdd) pfet_01v8 w=(550n) l=150n as=145.75f ad=77f \\\n');
fprintf(fid, '        ps=1.63u pd=830n m=(1)*(2)\n');
fprintf(fid, '    PM10 (net22 net10 vdd vdd) pfet_01v8 w=(6.25u) l=650n as=1.26563p \\\n');
fprintf(fid, '        ad=875f ps=9.78u pd=6.53u m=(1)*(4)\n');
fprintf(fid, '    PM9 (net24 net22 vdd vdd) pfet_01v8 w=(6u) l=650n as=990f ad=840f \\\n');
fprintf(fid, '        ps=7.53u pd=6.28u m=(1)*(10)\n');
fprintf(fid, '    PM0 (vth1 net10 net7 vdd) pfet_01v8 w=(550n) l=150n as=84.6389f ad=77f \\\n');
fprintf(fid, '        ps=918.889n pd=830n m=(1)*(18)\n');
fprintf(fid, '    NM14 (vhigh_T net24 Tout vss) nfet_01v8 w=(5.5u) l=150n as=846.389f \\\n');
fprintf(fid, '        ad=770f ps=6.41889u pd=5.78u m=(1)*(18)\n');
fprintf(fid, '    NM13 (vlow net48 Tout vss) nfet_01v8 w=(5.5u) l=150n as=846.389f \\\n');
fprintf(fid, '        ad=770f ps=6.41889u pd=5.78u m=(1)*(18)\n');
fprintf(fid, '    NM12 (vhigh net24 out vss) nfet_01v8 w=(5u) l=150n as=719.531f ad=700f \\\n');
fprintf(fid, '        ps=5.44406u pd=5.28u m=(1)*(64)\n');
fprintf(fid, '    NM6 (vlow net48 out vss) nfet_01v8 w=(5u) l=150n as=719.531f ad=700f \\\n');
fprintf(fid, '        ps=5.44406u pd=5.28u m=(1)*(64)\n');
fprintf(fid, '    NM5 (net6 net10 neg vss) nfet_01v8 w=(1u) l=150n as=153.889f ad=140f \\\n');
fprintf(fid, '        ps=1.41889u pd=1.28u m=(1)*(18)\n');
fprintf(fid, '    NM4 (net48 net24 vss vss) nfet_01v8 w=(550n) l=150n as=145.75f \\\n');
fprintf(fid, '        ad=145.75f ps=1.63u pd=1.63u m=(1)*(1)\n');
fprintf(fid, '    NM11 (net22 net10 vss vss) nfet_01v8 w=(1u) l=650n as=202.5f ad=140f \\\n');
fprintf(fid, '        ps=1.905u pd=1.28u m=(1)*(4)\n');
fprintf(fid, '    NM10 (net24 net22 vss vss) nfet_01v8 w=(1u) l=650n as=165f ad=140f \\\n');
fprintf(fid, '        ps=1.53u pd=1.28u m=(1)*(10)\n');
fprintf(fid, '    NM0 (vth2 net10 net7 vss) nfet_01v8 w=(5.5u) l=150n as=846.389f \\\n');
fprintf(fid, '        ad=770f ps=6.41889u pd=5.78u m=(1)*(18)\n');
fprintf(fid, '    C0 (net6 neg) cap_mim_m3_1 l=5.9u w=5.9u m=4\n');
fprintf(fid, 'ends neuron_v35\n\n');


% ===== Initial Conditions (Spectre) =====
fprintf(fid, '\n// ===== Initial conditions (all neurons) =====\n');
fprintf(fid, 'ic');

% --- Row neurons: Nrow1..NrowN ---
for i = 1:n_row
	% Neuron_v3 
	fprintf(fid, ' Nrow%d.net6=%g', i, 0.92749); %internal integrate node
	fprintf(fid, ' Nrow%d.net10=0', i);      % CMP output
	fprintf(fid, ' out1_%d=%g', i, POS_val);
	fprintf(fid, ' Tout1_%d=%g', i, POS_val);
	fprintf(fid, ' net_row_in_%d=%g', i, POS_val);
end

% --- Column neurons: Ncol1..NcolM ---
for j = 1:n_col
	fprintf(fid, ' Ncol2_%d.net6=%g', j, 0.92); %internal integrate node
	fprintf(fid, ' Ncol2_%d.net10=0', j);      % CMP output
	fprintf(fid, ' out2_%d=%g', j, POS_val);
	fprintf(fid, ' Tout2_%d=%g', j, POS_val);
	fprintf(fid, ' net_col_in_%d=%g', j, POS_val);
end



% --- Output neurons: Nout3_1..Nout3_n_out ---
for k = 1:n_out
	fprintf(fid, ' Nout3_%d.net6=%g', k, 0.92);
	fprintf(fid, ' Nout3_%d.net10=0', k);
	fprintf(fid, ' out3_%d=%g', k, POS_val);
	fprintf(fid, ' Tout3_%d=%g', k, POS_val);
	fprintf(fid, ' net_out3_in_%d=%g', k, POS_val);
end

fprintf(fid, '\n\n');
%% ========== Top-level Crossbar: Supplies ==========

fprintf(fid, '// ========= Top-level crossbar =========\n\n');

fprintf(fid, 'V1 (VDD 0) vsource dc=%g type=dc\n', VDD_val);
fprintf(fid, 'V5 (vhigh 0) vsource dc=%g type=dc\n', Vhigh_val);
fprintf(fid, 'V2 (pos 0) vsource dc=%g type=dc\n', POS_val);
fprintf(fid, 'V4 (vth1 0) vsource dc=%g type=dc\n', VTH1_val);
fprintf(fid, 'V3 (vth2 0) vsource dc=%g type=dc\n', VTH2_val);
fprintf(fid, 'V6 (vhigh_T 0) vsource dc=%g type=dc\n', Vhigh_T_val);


%% ========== Per-neuron bias current sources (2 per neuron) ==========

% Row neurons: ib1_i_1 and ib1_i_2
for i = 1:n_row
	fprintf(fid, 'Irowb_%d_1 (VDD ib1_%d_1) isource dc=%gu type=dc\n', i, i, IBIAS_val*1e6);
	fprintf(fid, 'Irowb_%d_2 (VDD ib1_%d_2) isource dc=%gu type=dc\n', i, i, IBIAS_val*1e6);
end

% Column neurons: ib2_j_1 and ib2_j_2
for j = 1:n_col
	fprintf(fid, 'Icolb_%d_1 (VDD ib2_%d_1) isource dc=%gu type=dc\n', j, j, IBIAS_val*1e6);
	fprintf(fid, 'Icolb_%d_2 (VDD ib2_%d_2) isource dc=%gu type=dc\n', j, j, IBIAS_val*1e6);
end

for k = 1:n_out
	fprintf(fid, 'Ioutb_%d_1 (VDD ib3_%d_1) isource dc=%gu type=dc\n', k, k, IBIAS_val*1e6);
	fprintf(fid, 'Ioutb_%d_2 (VDD ib3_%d_2) isource dc=%gu type=dc\n', k, k, IBIAS_val*1e6);
end

fprintf(fid, '\n');

%% ========== Layer 1: Row Inputs & Neurons ==========

for i = 1:n_row

	if actual_pulses_in(i) == 0
		% x_i = 0 -> no pulse, keep baseline DC
		fprintf(fid, 'Vin_row%d (in%d 0) vsource dc=0.9 type=dc\n', i, i);
	else
		tpulse_i = tpulse_in_s(i);
		tdelay_i = tpulse_i - trise - tfall - twidth;

		if tdelay_i <= 0
			error('Row %d: tpulse is too small. Need tpulse > trise+tfall+twidth.', i);
		end

		fprintf(fid, ...
			['Vin_row%d (in%d 0) vsource type=pulse delay=%g val0=900.0m val1=1.3 ', ...
			 'period=%g rise=%g fall=%g width=%g\n'], ...
			 i, i, tdelay_i, tpulse_i, trise, tfall, twidth);
	end

	% Input series resistor
	fprintf(fid, 'Rin_row%d (in%d net_row_in_%d) resistor r=%g\n', ...
		i, i, i, Rin_val);

	% Row Neuron
	fprintf(fid, ...
		'Nrow%d (Tout1_%d ib1_%d_1 ib1_%d_2 net_row_in_%d out1_%d pos VDD vhigh vhigh_T pos 0 vth1 vth2) neuron_v35\n\n', ...
		i, i, i, i, i, i);
end

%% ========== Layer 2: Column Neurons ==========
for j = 1:n_col
	fprintf(fid, 'Ncol2_%d (Tout2_%d ib2_%d_1 ib2_%d_2 net_col_in_%d out2_%d pos VDD vhigh vhigh_T pos 0 vth1 vth2) neuron_v35\n', ...
		j, j, j, j, j, j);
    % Bleed resistor: layer-2 neuron input -> 0.95 V (vhigh)
    fprintf(fid, 'Rbleed_col_%d (net_col_in_%d vhigh) resistor r=%g\n', ...
        j, j, 9e7);
end
fprintf(fid, '\n');
%% ========== Layer 3 ==========
for k = 1:n_out
	fprintf(fid, ...
		'Nout3_%d (Tout3_%d ib3_%d_1 ib3_%d_2 net_out3_in_%d out3_%d pos VDD vhigh vhigh_T pos 0 vth1 vth2) neuron_v35\n', ...
		k, k, k, k, k, k);
    % Bleed resistor: layer-3 neuron input -> 0.95 V (vhigh)
    fprintf(fid, ...
        'Rbleed_out_%d (net_out3_in_%d vhigh) resistor r=%g\n', ...
        k, k, 9e6);		

end
fprintf(fid, '\n');

%% ========== Crossbar Resistance Matrix: Layer1 -> Layer2 ==========

for i = 1:n_row
    for j = 1:n_col

		fprintf(fid, ...
			'RRA_%d_%d (out1_%d net_colA_rram_%d_%d) resistor_rand_min R0=%g\n', ...
			i, j, i, i, j, RA_map(i,j));

		fprintf(fid, ...
			'RRB_%d_%d (out1_%d net_colB_rram_%d_%d) resistor_rand_min R0=%g\n', ...
			i, j, i, i, j, RB_map(i,j));

        fprintf(fid, ...
            'MTA_%d_%d (net_colA_rram_%d_%d Tout1_%d net_col_in_%d 0) nfet_01v8 w=(420n) l=150n as=85.05f ad=58.8f ps=1.035u pd=700n m=(1)*(4)\n', ...
            i, j, i, j, i, j);

        fprintf(fid, ...
            'MTB_%d_%d (net_colB_rram_%d_%d Tout1_%d net_col_in_%d 0) nfet_01v8 w=(420n) l=150n as=85.05f ad=58.8f ps=1.035u pd=700n m=(1)*(4)\n', ...
            i, j, i, j, i, j);
    end
end
fprintf(fid, '\n');

%% ========== Crossbar Resistance Matrix: Layer2 -> Layer3 ==========
for i = 1:n_col
    for j = 1:n_out

		fprintf(fid, ...
			'RRA2_%d_%d (out2_%d net_out3A_rram_%d_%d) resistor_rand_min R0=%g\n', ...
			i, j, i, i, j, RA_map2(i,j));

		fprintf(fid, ...
			'RRB2_%d_%d (out2_%d net_out3B_rram_%d_%d) resistor_rand_min R0=%g\n', ...
			i, j, i, i, j, RB_map2(i,j));

        fprintf(fid, ...
            'MTA2_%d_%d (net_out3A_rram_%d_%d Tout2_%d net_out3_in_%d 0) nfet_01v8 w=(420n) l=150n as=85.05f ad=58.8f ps=1.035u pd=700n m=(1)*(4)\n', ...
            i, j, i, j, i, j);

        fprintf(fid, ...
            'MTB2_%d_%d (net_out3B_rram_%d_%d Tout2_%d net_out3_in_%d 0) nfet_01v8 w=(420n) l=150n as=85.05f ad=58.8f ps=1.035u pd=700n m=(1)*(4)\n', ...
            i, j, i, j, i, j);
    end
end
fprintf(fid, '\n');

%% ========== Simulation Setup ==========

fprintf(fid, ['simulatorOptions options psfversion="1.1.0" ', ...
    'reltol=1e-3 vabstol=1e-6 iabstol=1e-11 ', ...
    'temp=27 tnom=27 scalem=1.0 scale=1.0 ', ...
    'gmin=1e-10 rforce=1 ', ...
    'maxnotes=5 maxwarns=5 digits=5 cols=80 pivrel=1e-2 ', ...
    'method=gear2only dc_pivot_check=yes try_fast_op=no ', ...
    'sensfile="../psf/sens.output" checklimitdest=psf\n']);

fprintf(fid, 'saveOptions options save=none currents=none subcktprobelvl=0\n');
fprintf(fid, 'tran tran stop=%g maxstep=0.2n annotate=status maxiters=100 errpreset=conservative\n\n', tstop);

fprintf(fid, 'simulator lang=spice\n\n');


nodes_of_interest = { ...
	'out1_1', ...
	'out1_2', ...
	'out1_3', ...
	'out1_4', ...
	'Ncol2_6.net6', ...
	'out2_6', ...
	'Nout3_1.net6', ...
	'out3_1'
};

fprintf(fid, '.print tran ');
for k = 1:numel(nodes_of_interest)
	fprintf(fid, ' V(%s)', nodes_of_interest{k});
end  
fprintf(fid, '\n');   
fclose(fid);
fprintf('Generation completed: %s\n', scs_file);



%% ========== Run Spectre ==========

cfg.netlist_path = fullfile(pwd, scs_file);
cfg.spectre_path = '$SPECTRE_BIN'; 
cfg.threads      = 4;                          

cmd = sprintf('"%s" +mt=%d "%s"', ...
			  cfg.spectre_path, cfg.threads, cfg.netlist_path);
fprintf('Running Spectre...\n');
[status, cmdout] = system(cmd);
assert(status==0, "Spectre run failed.\n%s", cmdout);
fprintf('Spectre finished.\n');

%% ========== Read .print file & analyze ==========
% Infer the .print filename based on the netlist name
[net_dir, net_base, ~] = fileparts(cfg.netlist_path);
c1 = fullfile(pwd,     [net_base '.print']);   % Common location: current working directory
c2 = fullfile(net_dir, [net_base '.print']);   % Alternative location: directory where the netlist resides

if isfile(c1)
	print_file = c1;
elseif isfile(c2)
	print_file = c2;
else
	error('Spectre did not generate .print file: %s or %s', c1, c2);
end

[res, name] = import_spectre_data(print_file);

% Time axis (seconds & nanoseconds)
time_s  = res(:,1);
time_ns = time_s * 1e9;
sig_names = { ...
	'v(out1_1)', ... 
	'v(out1_2)', ...
	'v(out1_3)', ...
	'v(out1_4)', ...
	'v(Ncol2_6.net6)',...
	'v(out2_6)', ...
	'v(Nout3_1.net6)', ...	
	'v(out3_1)'
};
%% Save waveform data for this step
out = struct();
out.time_s   = time_s;
out.time_ns  = time_ns;
out.res      = res;
out.name     = name;
out.sig_list = sig_names;

save_dir = fullfile(pwd, 'step_mats');
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

timestamp_str = datestr(now, 'yyyymmdd_HHMMSS_FFF');
mat_name = fullfile(save_dir, ...
    sprintf('crossbar_wave_%s_%s.mat', run_name, timestamp_str));

save(mat_name, '-struct', 'out');
fprintf('Waveform data saved to: %s\n', mat_name);

%% ========== Count spikes at out3_1 within 22.5 us ==========
time_limit   = 22.5e-6;   % 22.5 us
thresh_spike = 0.94;
norm_factor  = 25;

% find time column
idx_time = find(strcmpi(name, 'time'), 1);
if isempty(idx_time)
    error('Signal "time" not found in imported waveform.');
end

% find out3_1 column
idx_out3 = find(strcmpi(name, 'v(out3_1)'), 1);
if isempty(idx_out3)
    error('Signal v(out3_1) not found.');
end

t = res(:, idx_time);
v_out3 = res(:, idx_out3);

% only use waveform before 22.5 us
mask = t < time_limit;
t_use = t(mask);
v_use = v_out3(mask);

if numel(t_use) < 2
    error('Not enough waveform points before %.3f us.', time_limit * 1e6);
end

% count rising crossings
spike_count = sum(v_use(1:end-1) < thresh_spike & v_use(2:end) >= thresh_spike);
output_norm_this = spike_count / norm_factor;

fprintf('Inference done (t < %.3f us): spike_count=%d, norm=%.6f\n', ...
    time_limit * 1e6, spike_count, output_norm_this);
end

function [res, name] = import_spectre_data(file)
% IMPORT_DATA  读取 Cadence Spectre 的 .print 文件（含多段输出）
%  [res, name] = import_data('<path>/SNN_netlist.print')
%  - res  : [N x K] 数组；第1列是 time(秒)，其余是各信号
%  - name : 1xK 列名 cell；例如 {'time','v(n1)','v(n2)',...}

%% 读整文件为行
fid = fopen(file,'r');
assert(fid>0, '无法打开文件: %s', file);
C  = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
L  = C{1};
nL = numel(L);

%% 找到每一段的起点：文件开头 & 每个单独一行的 'y'
anchor = 1;                                % 第一段从文件开头开始找
for i = 1:nL
    li = strtrim(L{i});
    if strcmp(li,'y')
        anchor(end+1) = i; %#ok<AGROW>
    end
end
anchor = sort(unique(anchor));

%% 解析每一段
res  = [];
name = {};
for a = 1:numel(anchor)
    i0 = anchor(a);
    % 从锚点往下找下一个独立的 'x'
    ix = i0 + find_next_line(L, i0, 'x');
    if isempty(ix),  ix = i0; end

    % 从 x 往下找表头（第一列为 time 的那一行）
    ih = find_header(L, ix);
    if isempty(ih)
        % 兼容：有些文件 x 之后若没有 header，就从锚点后继续找
        ih = find_header(L, i0);
    end
    if isempty(ih)
        continue; % 这一段没有数据，跳过
    end

    % 解析当前段的数据块
    [block, header, iend] = parse_block(L, ih); %#ok<ASGLU>

    if isempty(block), continue; end

    if isempty(res)
        % 第一段：保留 time + 所有信号
        res  = block;
        name = header;
    else
        % 后续段：只追加信号列，必要时对齐时间
        t0 = res(:,1);
        t1 = block(:,1);

        if numel(t0)==numel(t1) && all(abs(t0 - t1) <= max(1e-18, 1e-12*max(1, max(abs(t0)))))
            res  = [res, block(:,2:end)];                 %#ok<AGROW>
            name = [name, header(2:end)];                %#ok<AGROW>
        else
            % 时间不完全一致——取交集对齐
            [tc, ia, ib] = intersect(t0, t1);
            warning('第 %d 段的时间轴与第一段不完全一致，按时间交集 (%d 点) 对齐。', a, numel(tc));
            res  = [res(ia,:), block(ib,2:end)];
            name = [name, header(2:end)];
        end
    end
end

%% 若完全没读到，给个友好提示
if isempty(res)
    error('没有在文件里找到任何包含 "time" 表头的数据段。');
end

end % ===== 主函数结束 =====


% ---------- 工具函数：从行 i0 起往下找“恰好等于 key 的一行”，返回偏移 ----------
function off = find_next_line(L, i0, key)
off = [];
for i = i0+1 : numel(L)
    li = strtrim(L{i});
    if strcmp(li, key)
        off = i - i0;
        return;
    end
end
end

% ---------- 工具函数：从行 i0 起往下找表头（第一列是 time） ----------
function ih = find_header(L, i0)
ih = [];
for i = i0+1 : numel(L)
    li = strtrim(L{i});
    if isempty(li) || startsWith(li,'*') || startsWith(li,'******'), continue; end
    toks = regexp(li, '\S+', 'match');
    if ~isempty(toks) && strcmpi(toks{1}, 'time')
        ih = i;
        return;
    end
end
end

% ---------- 工具函数：解析一个数据块 ----------
function [block, header, iend] = parse_block(L, ih)
% 读列名
header = regexp(strtrim(L{ih}), '\S+', 'match');
K = numel(header);

% 从下一行开始读取数值，直到遇到非数据行
rows = {};
for i = ih+1 : numel(L)
    li = strtrim(L{i});
    if isempty(li), break; end
    % 数据行以数字/正负号开头（时间可能写成 "100 f" 这种格式）
    if isempty(regexp(li, '^[\+\-]?\d', 'once'))
        % 不是数值开头，认为数据块结束
        break;
    end
    rows{end+1} = li; %#ok<AGROW>
end
iend = ih + numel(rows);

% 把行解析成数值（支持单位后缀）
N = numel(rows);
block = nan(N, K);
for r = 1:N
    block(r,1:K) = parse_row(rows{r}, K);
end

% 清理：剔除全 NaN 行/列；按 time 排序并去重
goodCol = any(~isnan(block),1);
block   = block(:,goodCol);
header  = header(goodCol);

[block(:,1), ord] = sort(block(:,1));
block = block(ord,:);
[~, iu] = unique(block(:,1),'stable');
block = block(iu,:);
end

% ---------- 把一行 "数字+单位" 解析成 K 个数 ----------
function vals = parse_row(line, K)
% 单位倍率
scale = containers.Map( ...
    {'f','p','n','u','m','', 'k','K','M','G','T'}, ...
    [1e-15 1e-12 1e-9 1e-6 1e-3 1   1e3  1e3 1e6 1e9 1e12]);

% 捕获形如 "1.234e-3 u" 或 "100 n" 或 "0.7" 的片段
tok = regexp(line, '([+\-]?\d*\.?\d+(?:[eE][+\-]?\d+)?)\s*([fpnumkKMGＴTG]?)', 'tokens'); % 兼容全角T
if isempty(tok)
    error('无法解析数值：%s', line);
end

vals = nan(1, K);
take = min(K, numel(tok));
for c = 1:take
    v = str2double(tok{c}{1});
    u = tok{c}{2};
    if ~isKey(scale,u)
        u = lower(u); % 统一小写再查一次
    end
    s = 1;
    if isKey(scale,u), s = scale(u); end
    vals(c) = v * s;
end
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