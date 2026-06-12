% =========================================================================
% Example Script: generate_spectre_crossbar_array
%
% Description:
%   This script generates and simulates a 2-layer neuron–crossbar array
%   in Cadence Spectre:
%
%       row neurons -> crossbar devices -> output neurons
%
% Main modifications from the original 3-layer version:
%   1) The original 3-layer network is simplified into a 2-layer network.
%   2) Each crosspoint cell contains only one device.
%   3) When the STF RRAM model is selected, the device initial states are
%      directly assigned by random x0/w0 values:
%        - x0 is randomly initialized in the range [0, 3 nm]
%        - w0 is fixed at 0.5 nm
%   4) Only the first input neuron is driven by an input pulse source,
%      while all other input neurons are fixed at 0.9 V.
%
% Device-model switch:
%   This script supports two crosspoint device models for array-level
%   transient simulation. The device type is selected by the variable
%   "device_switch" in the parameter section:
%
%       device_switch = 0  --> use the STF-based RRAM Verilog-A model
%       device_switch = 1  --> use the resistor-based model
%                              (resistor_rand_min.va)
%
%   The purpose of introducing this switch is that the STF RRAM model can
%   better describe device-internal switching dynamics, but may suffer from
%   convergence issues in large-scale array simulations. To improve
%   simulation robustness and efficiency during inference-level evaluation,
%   a resistor-based model is also provided as an alternative device option.
%
% STF RRAM model:
%   The Verilog-A RRAM model file used in STF mode is located at:
%
%       $PROJECT_ROOT
%
%   The model is based on the Peking University–Stanford University
%   Resistive Random Access Memory (RRAM) SPICE Model, Version 2.0Beta,
%   as shown in the reference figure.
%
%   Official model webpage:
%       http://nano.stanford.edu/models.php
%
%   In this work, the original RRAM model is further modified by adding
%   read-noise behavior, so that device conductance fluctuation during
%   read operation can be captured in circuit-level simulation.
%
% Resistor-based model:
%   The resistor-based model is implemented in:
%
%       resistor_rand_min.va
%
%   In resistor-model mode, each crosspoint is represented by an effective
%   resistance R0 instead of the full STF switching model. This simplified
%   model is mainly used to avoid convergence problems in large crossbar
%   simulations while preserving resistance-based inference behavior.
%
% Notes:
%   - This script is intended for crossbar-level transient simulation and
%     waveform observation in Spectre.
%   - The current version focuses on random device initialization rather
%     than weight-to-device mapping from trained neural-network parameters.
%   - In general, STF mode is more physically detailed, while resistor mode
%     is more simulation-friendly for large-scale inference verification.
%
% =========================================================================

clear; clc;
rng(1);   % fixed seed


%% ========== Parameters ==========
% Two-layer network:
% input neurons -> crossbar -> output neurons
n_row = 4;      % number of input neurons
n_col = 4;     % number of output neurons

% Device switch:
%   0 -> use STF RRAM Verilog-A model
%   1 -> use resistor-based model (resistor_rand_min.va)
device_switch = 0;


Rin_val = 800e3;

% Bias signals
VDD_val     = 1.8;
Vhigh_T_val = 1.8;
Vhigh_val   = 0.95;
POS_val     = 0.9;
VTH1_val    = 0.71;
VTH2_val    = 0.88;
IBIAS_val   = 6e-6;

tstop  = 6e-6;
trise  = 5e-9;
tfall  = 5e-9;
twidth = 60e-9;


%% ========== Random x0/w0 initialization for every RRAM ==========
%   x0 random in [0, 3 nm]
%   w0 fixed at 0.5 nm

x0_nm = 3.0 * rand(n_row, n_col);  
w0_nm = 0.5 * ones(n_row, n_col);     

x0 = x0_nm * 1e-9;
w0 = w0_nm * 1e-9;

fprintf('Random RRAM init generated:\n');
fprintf('  x0 range = [0, 3] nm\n');
fprintf('  w0 fixed = 0.5 nm\n');

% For resistor-based model:
% assign a random resistance to each crosspoint, for example in [30k, 2M] ohm
R0_map = 3e4 + (2e6 - 3e4) * rand(n_row, n_col);

fprintf('Random resistor model init generated:\n');
fprintf('  R0 range = [3e4, 2e6] ohm\n');

%% ========== Input setting ==========
% Only the first input neuron has pulse input.
% All others are fixed at 0.9V.

input_has_pulse = false(1, n_row);
input_has_pulse(1) = true;

% directly choose a pulse period here
tpulse_first = 1.0e-6;   % example
tdelay_first = tpulse_first - trise - tfall - twidth;

if tdelay_first <= 0
    error('tpulse_first must be > trise + tfall + twidth');
end

%% ========== Output netlist filename ==========
scs_file = 'Neuron_v35_crossbar.scs';
fid = fopen(scs_file, 'w');
if fid == -1
    error('Unable to open %s for writing', scs_file);
end

fprintf('Generating Spectre netlist: %s\n', scs_file);

%% ========== Head & include ==========
fprintf(fid, '// Automatically generated 2-layer Neuron_v35 crossbar\n');
fprintf(fid, '// input neurons -> RRAM crossbar -> output neurons\n\n');
fprintf(fid, 'simulator lang=spectre\n');
fprintf(fid, 'global 0\n\n');

fprintf(fid, 'include "$PROJECT_ROOT" section=tt\n\n');

if device_switch == 0
    % ===== Use STF RRAM model =====
    rram_va_path = '$PROJECT_ROOT';
    fprintf(fid, '// device_switch = 0 : use STF RRAM model\n');
    fprintf(fid, 'ahdl_include "%s"\n\n', rram_va_path);

elseif device_switch == 1
    % ===== Use resistor-based model =====
    res_va_path ='$PROJECT_ROOT';
    fprintf(fid, '// device_switch = 1 : use resistor-based model\n');
    fprintf(fid, 'ahdl_include "%s"\n\n', res_va_path);

else
    error('Invalid device_switch. Use 0 for STF RRAM, 1 for resistor-based model.');
end

%% ========== Subckt Definitions ==========
% -------- 7TOpamp --------
fprintf(fid, 'subckt snn1_7TOpamp_schematic Ibias VDD VSS neg out pos\n');
fprintf(fid, '    PM1 (out net21 VDD VDD) pfet_01v8 w=(1.1u) l=650n as=169.278f ad=169.278f ps=1.53u pd=1.53u m=(1)*(9)\n');
fprintf(fid, '    PM3 (net21 net18 VDD VDD) pfet_01v8 w=(1u) l=650n as=265f ad=140f ps=2.53u pd=1.28u m=(1)*(2)\n');
fprintf(fid, '    PM0 (net18 net18 VDD VDD) pfet_01v8 w=(1u) l=650n as=265f ad=140f ps=2.53u pd=1.28u m=(1)*(2)\n');
fprintf(fid, '    NM5 (out Ibias VSS VSS) nfet_01v8 w=(425n) l=650n as=86.0625f ad=59.5f ps=1.0425u pd=705n m=(1)*(4)\n');
fprintf(fid, '    NM4 (Ibias Ibias VSS VSS) nfet_01v8 w=(425n) l=650n as=112.625f ad=59.5f ps=1.38u pd=705n m=(1)*(2)\n');
fprintf(fid, '    NM3 (net17 Ibias VSS VSS) nfet_01v8 w=(425n) l=650n as=112.625f ad=59.5f ps=1.38u pd=705n m=(1)*(2)\n');
fprintf(fid, '    NM2 (net21 pos net17 VSS) nfet_01v8 w=(1u) l=650n as=202.5f ad=140f ps=1.905u pd=1.28u m=(1)*(4)\n');
fprintf(fid, '    NM1 (net18 neg net17 VSS) nfet_01v8 w=(1u) l=650n as=202.5f ad=140f ps=1.905u pd=1.28u m=(1)*(4)\n');
fprintf(fid, '    R0 (net21 net028 VSS) res_xhigh_po_0p35 r=21.8031K l=3u w=350n\n');
fprintf(fid, '    C0 (out net028) cap_mim_m3_1 l=5.5u w=5.5u m=2\n');
fprintf(fid, 'ends snn1_7TOpamp_schematic\n\n');

% -------- CMP --------
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

% -------- neuron_v35 --------
fprintf(fid, 'subckt neuron_v35 Tout ib1 ib2 neg out pos vdd vhigh vhigh_T vlow vss vth1 \\\n');
fprintf(fid, '        vth2\n');
fprintf(fid, '    I0 (ib1 vdd vss neg net6 pos) snn1_7TOpamp_schematic\n');
fprintf(fid, '    I1 (ib2 vdd vss net6 net10 net7) CMP\n');
fprintf(fid, '    PM13 (Tout net48 vhigh_T vdd) pfet_01v8 w=(550n) l=150n as=84.6389f ad=77f ps=918.889n pd=830n m=(1)*(18)\n');
fprintf(fid, '    PM12 (Tout net24 vlow vdd) pfet_01v8 w=(550n) l=150n as=84.6389f ad=77f ps=918.889n pd=830n m=(1)*(18)\n');
fprintf(fid, '    PM11 (out net48 vhigh vdd) pfet_01v8 w=(5u) l=150n as=719.531f ad=700f ps=5.44406u pd=5.28u m=(1)*(64)\n');
fprintf(fid, '    PM5 (out net24 vlow vdd) pfet_01v8 w=(5u) l=150n as=719.531f ad=700f ps=5.44406u pd=5.28u m=(1)*(64)\n');
fprintf(fid, '    PM4 (net48 net24 vdd vdd) pfet_01v8 w=(550n) l=150n as=145.75f ad=77f ps=1.63u pd=830n m=(1)*(2)\n');
fprintf(fid, '    PM10 (net22 net10 vdd vdd) pfet_01v8 w=(6.25u) l=650n as=1.26563p ad=875f ps=9.78u pd=6.53u m=(1)*(4)\n');
fprintf(fid, '    PM9 (net24 net22 vdd vdd) pfet_01v8 w=(6u) l=650n as=990f ad=840f ps=7.53u pd=6.28u m=(1)*(10)\n');
fprintf(fid, '    PM0 (vth1 net10 net7 vdd) pfet_01v8 w=(550n) l=150n as=84.6389f ad=77f ps=918.889n pd=830n m=(1)*(18)\n');
fprintf(fid, '    NM14 (vhigh_T net24 Tout vss) nfet_01v8 w=(5.5u) l=150n as=846.389f ad=770f ps=6.41889u pd=5.78u m=(1)*(18)\n');
fprintf(fid, '    NM13 (vlow net48 Tout vss) nfet_01v8 w=(5.5u) l=150n as=846.389f ad=770f ps=6.41889u pd=5.78u m=(1)*(18)\n');
fprintf(fid, '    NM12 (vhigh net24 out vss) nfet_01v8 w=(5u) l=150n as=719.531f ad=700f ps=5.44406u pd=5.28u m=(1)*(64)\n');
fprintf(fid, '    NM6 (vlow net48 out vss) nfet_01v8 w=(5u) l=150n as=719.531f ad=700f ps=5.44406u pd=5.28u m=(1)*(64)\n');
fprintf(fid, '    NM5 (net6 net10 neg vss) nfet_01v8 w=(1u) l=150n as=153.889f ad=140f ps=1.41889u pd=1.28u m=(1)*(18)\n');
fprintf(fid, '    NM4 (net48 net24 vss vss) nfet_01v8 w=(550n) l=150n as=145.75f ad=145.75f ps=1.63u pd=1.63u m=(1)*(1)\n');
fprintf(fid, '    NM11 (net22 net10 vss vss) nfet_01v8 w=(1u) l=650n as=202.5f ad=140f ps=1.905u pd=1.28u m=(1)*(4)\n');
fprintf(fid, '    NM10 (net24 net22 vss vss) nfet_01v8 w=(1u) l=650n as=165f ad=140f ps=1.53u pd=1.28u m=(1)*(10)\n');
fprintf(fid, '    NM0 (vth2 net10 net7 vss) nfet_01v8 w=(5.5u) l=150n as=846.389f ad=770f ps=6.41889u pd=5.78u m=(1)*(18)\n');
fprintf(fid, '    C0 (net6 neg) cap_mim_m3_1 l=5.9u w=5.9u m=4\n');
fprintf(fid, 'ends neuron_v35\n\n');

%% ========== Initial Conditions ==========
fprintf(fid, 'ic');

% input neurons
for i = 1:n_row
    fprintf(fid, ' Nrow%d.net6=%g', i, 0.92749);
    fprintf(fid, ' Nrow%d.net10=0', i);
    fprintf(fid, ' out1_%d=%g', i, POS_val);
    fprintf(fid, ' Tout1_%d=%g', i, POS_val);
    fprintf(fid, ' net_row_in_%d=%g', i, POS_val);
end

% output neurons
for j = 1:n_col
    fprintf(fid, ' Ncol2_%d.net6=%g', j, 0.92);
    fprintf(fid, ' Ncol2_%d.net10=0', j);
    fprintf(fid, ' out2_%d=%g', j, POS_val);
    fprintf(fid, ' Tout2_%d=%g', j, POS_val);
    fprintf(fid, ' net_col_in_%d=%g', j, POS_val);
end
fprintf(fid, '\n\n');

%% ========== Top-level supplies ==========
fprintf(fid, 'V1 (VDD 0) vsource dc=%g type=dc\n', VDD_val);
fprintf(fid, 'V5 (vhigh 0) vsource dc=%g type=dc\n', Vhigh_val);
fprintf(fid, 'V2 (pos 0) vsource dc=%g type=dc\n', POS_val);
fprintf(fid, 'V4 (vth1 0) vsource dc=%g type=dc\n', VTH1_val);
fprintf(fid, 'V3 (vth2 0) vsource dc=%g type=dc\n', VTH2_val);
fprintf(fid, 'V6 (vhigh_T 0) vsource dc=%g type=dc\n\n', Vhigh_T_val);

%% ========== Bias current sources ==========
for i = 1:n_row
    fprintf(fid, 'Irowb_%d_1 (VDD ib1_%d_1) isource dc=%gu type=dc\n', i, i, IBIAS_val*1e6);
    fprintf(fid, 'Irowb_%d_2 (VDD ib1_%d_2) isource dc=%gu type=dc\n', i, i, IBIAS_val*1e6);
end

for j = 1:n_col
    fprintf(fid, 'Icolb_%d_1 (VDD ib2_%d_1) isource dc=%gu type=dc\n', j, j, IBIAS_val*1e6);
    fprintf(fid, 'Icolb_%d_2 (VDD ib2_%d_2) isource dc=%gu type=dc\n', j, j, IBIAS_val*1e6);
end
fprintf(fid, '\n');

%% ========== Layer 1: input neurons ==========
for i = 1:n_row
    if input_has_pulse(i)
        fprintf(fid, ...
            ['Vin_row%d (in%d 0) vsource type=pulse delay=%g val0=900.0m val1=1.3 ', ...
             'period=%g rise=%g fall=%g width=%g\n'], ...
             i, i, tdelay_first, tpulse_first, trise, tfall, twidth);
    else
        fprintf(fid, 'Vin_row%d (in%d 0) vsource dc=0.9 type=dc\n', i, i);
    end

    fprintf(fid, 'Rin_row%d (in%d net_row_in_%d) resistor r=%g\n', ...
        i, i, i, Rin_val);

    fprintf(fid, ...
        'Nrow%d (Tout1_%d ib1_%d_1 ib1_%d_2 net_row_in_%d out1_%d pos VDD vhigh vhigh_T pos 0 vth1 vth2) neuron_v35\n\n', ...
        i, i, i, i, i, i);
end

%% ========== Layer 2: output neurons ==========
for j = 1:n_col
    fprintf(fid, ...
        'Ncol2_%d (Tout2_%d ib2_%d_1 ib2_%d_2 net_col_in_%d out2_%d pos VDD vhigh vhigh_T pos 0 vth1 vth2) neuron_v35\n', ...
        j, j, j, j, j, j);
end
fprintf(fid, '\n');

%% ========== Crossbar: Layer1 -> Layer2 ==========
for i = 1:n_row
    for j = 1:n_col

        if device_switch == 0
            % ===== STF RRAM model =====
            fprintf(fid, ...
                'XRR_%d_%d (out1_%d net_col_rram_%d_%d xnode_%d_%d wnode_%d_%d) RRAM_v_2_0_Beta x0=%g w0=%g\n', ...
                i, j, i, i, j, i, j, i, j, x0(i,j), w0(i,j));

        elseif device_switch == 1
            % ===== resistor-based model =====
            fprintf(fid, ...
                'RR_%d_%d (out1_%d net_col_rram_%d_%d) resistor_rand_min R0=%g\n', ...
                i, j, i, i, j, R0_map(i,j));
        end

        % Shared access transistor
        fprintf(fid, ...
            'MT_%d_%d (net_col_rram_%d_%d Tout1_%d net_col_in_%d 0) nfet_01v8 w=(420n) l=150n as=85.05f ad=58.8f ps=1.035u pd=700n m=(1)*(4)\n', ...
            i, j, i, j, i, j);

    end
end
fprintf(fid, '\n');

%% ========== Simulation Setup ==========
fprintf(fid, ['simulatorOptions options psfversion="1.1.0" ', ...
    'reltol=1e-3 vabstol=1e-6 iabstol=1e-11 temp=27 tnom=27 ', ...
    'scalem=1.0 scale=1.0 gmin=1e-12 rforce=1 maxnotes=5 maxwarns=5 ', ...
    'digits=5 cols=80 pivrel=1e-3 method=gear2only dc_pivot_check=yes ', ...
    'try_fast_op=no sensfile="../psf/sens.output" checklimitdest=psf\n']);

fprintf(fid, 'saveOptions options save=none currents=none subcktprobelvl=0\n');
fprintf(fid, 'tran tran stop=%g maxstep=1n annotate=status maxiters=100 errpreset=conservative\n\n', tstop);

fprintf(fid, 'simulator lang=spice\n\n');

nodes_of_interest = { ...
    'out1_1', ...
    'out1_2', ...
    'out1_3', ...
    'out1_4', ...
    'Ncol2_1.net6', ...
    'out2_1' ...
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
assert(status == 0, "Spectre run failed.\n%s", cmdout);
fprintf('Spectre finished.\n');

%% ========== Read .print file ==========
[net_dir, net_base, ~] = fileparts(cfg.netlist_path);
c1 = fullfile(pwd,     [net_base '.print']);
c2 = fullfile(net_dir, [net_base '.print']);

if isfile(c1)
    print_file = c1;
elseif isfile(c2)
    print_file = c2;
else
    error('Spectre did not generate .print file: %s or %s', c1, c2);
end

[res, name] = import_spectre_data(print_file);

% Time axis
time_s  = res(:,1);
time_ns = time_s * 1e9;

%% ========== Define signal names ==========
sig_names = { ...
    'v(out1_1)', ...
    'v(out1_2)', ...
    'v(out1_3)', ...
    'v(out1_4)', ...
    'v(Ncol2_1.net6)', ...
    'v(out2_1)' ...
    };

%% ========== Plot waveforms ==========
Ns = numel(sig_names);
nrows = Ns;
ncols = 1;

figure;
tiledlayout(nrows, ncols, 'TileSpacing', 'compact', 'Padding', 'compact');

for k = 1:Ns
    col_k = find(strcmpi(name, sig_names{k}), 1);
    if isempty(col_k)
        warning('Signal not found in .print: %s', sig_names{k});
        nexttile;
        axis off;
        title(sig_names{k}, 'Interpreter', 'none');
        continue;
    end

    nexttile;
    plot(time_ns, res(:, col_k), 'LineWidth', 1.2);
    grid on;
    box on;

    title(sig_names{k}, 'Interpreter', 'none');
    xlabel('Time (ns)');
    if startsWith(lower(sig_names{k}), 'i(')
        ylabel('Current (A)');
    else
        ylabel('Voltage (V)');
    end
    set(gca, 'LineWidth', 1.0, 'FontSize', 10);
end

sgtitle('Neuron\_v35 2-Layer Crossbar Waveforms');

%% ========== Save data to MAT file ==========
out = struct();
out.time_s   = time_s;
out.time_ns  = time_ns;
out.res      = res;
out.name     = name;
out.sig_list = sig_names;

mat_name = sprintf('2layer_crossbar_wave.mat');
save(mat_name, '-struct', 'out');
fprintf('Waveform data saved to: %s\n', mat_name);






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
            [tc, ia, ib] = intersect(t0, t1); %#ok<ASGLU>
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

end


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

function out = to_cellstr_any(x)
% Convert table column to cellstr robustly
    if iscell(x)
        out = cell(size(x));
        for k = 1:numel(x)
            if isstring(x{k})
                out{k} = char(x{k});
            elseif ischar(x{k})
                out{k} = x{k};
            else
                out{k} = char(string(x{k}));
            end
        end
    elseif isstring(x)
        out = cellstr(x);
    elseif ischar(x)
        out = {x};
    else
        out = cellstr(string(x));
    end
end