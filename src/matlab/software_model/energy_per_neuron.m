% =========================================================================
% Script:   measure_single_neuron_energy.m
% Purpose:
%   Isolate one neuron_v35 and measure:
%       1) total energy
%       2) average power
%       3) energy per spike
% =========================================================================

clear; clc;

%% =========================
% User settings
%% =========================
task_id_str = 'single_neuron';

% ----- manual input pulse -----
use_pulse_input = true;

V_in_low  = 0.9;
V_in_high = 1.3;

tstop  = 6e-6;
trise  = 5e-9;
tfall  = 5e-9;
twidth = 60e-9;
tpulse = 4.0e-7;   % manually set pulse period
tdelay = tpulse - trise - tfall - twidth;

if tdelay <= 0
    error('Need tpulse > trise + tfall + twidth.');
end

% ----- neuron bias / references -----
VDD_val      = 1.8;
Vhigh_T_val  = 1.8;
Vhigh_val    = 0.95;
POS_val      = 0.9;
VTH1_val     = 0.71;
VTH2_val     = 0.88;
IBIAS_val    = 6e-6;

% ----- optional isolated output load -----
% keep light load for isolated measurement
use_output_load = false;
Rload_val = 1e9;      % very light resistive load
Cload_val = 5e-15;    % small output parasitic load

% ----- Spectre path -----
spectre_path = '$SPECTRE_BIN';
threads      = 4;

% ----- output file -----
scs_file = sprintf('single_neuron_energy_%s.scs', task_id_str);

%% =========================
% Open netlist
%% =========================
fid = fopen(scs_file, 'w');
if fid == -1
    error('Cannot open %s for writing.', scs_file);
end

fprintf('Generating Spectre netlist: %s\n', scs_file);

%% =========================
% Head & includes
%% =========================
fprintf(fid, 'simulator lang=spectre\n');
fprintf(fid, 'global 0\n\n');

fprintf(fid, 'include "$PROJECT_ROOT" section=tt\n\n');

%% =========================
% Subckt: 7TOpamp
%% =========================
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

%% =========================
% Subckt: CMP
%% =========================
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

%% =========================
% Subckt: neuron_v35
%% =========================
fprintf(fid, 'subckt neuron_v35 Tout ib1 ib2 neg out pos vdd vhigh vhigh_T vlow vss vth1 vth2\n');
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

%% =========================
% Initial condition
%% =========================
fprintf(fid, 'ic N1.net6=0.92749 N1.net10=0 out=0.9 Tout=0.9 in_node=0.9\n\n');

%% =========================
% Dedicated supplies
%% =========================
fprintf(fid, 'VVDD     (VDD 0)      vsource dc=%g type=dc\n', VDD_val);
fprintf(fid, 'VVHIGH   (vhigh 0)    vsource dc=%g type=dc\n', Vhigh_val);
fprintf(fid, 'VVPOS    (pos 0)      vsource dc=%g type=dc\n', POS_val);
fprintf(fid, 'VVTH1    (vth1 0)     vsource dc=%g type=dc\n', VTH1_val);
fprintf(fid, 'VVTH2    (vth2 0)     vsource dc=%g type=dc\n', VTH2_val);
fprintf(fid, 'VVHIGHT  (vhigh_T 0)  vsource dc=%g type=dc\n', Vhigh_T_val);

fprintf(fid, 'IBIAS1 (VDD ib1) isource dc=%gu type=dc\n', IBIAS_val * 1e6);
fprintf(fid, 'IBIAS2 (VDD ib2) isource dc=%gu type=dc\n', IBIAS_val * 1e6);

%% =========================
% Input source
%% =========================
if use_pulse_input
    fprintf(fid, ['VIN (vin_src 0) vsource type=pulse delay=%g val0=%g val1=%g ', ...
                  'period=%g rise=%g fall=%g width=%g\n'], ...
                  tdelay, V_in_low, V_in_high, tpulse, trise, tfall, twidth);
else
    fprintf(fid, 'VIN (vin_src 0) vsource dc=%g type=dc\n', V_in_low);
end

fprintf(fid, 'RIN (vin_src in_node) resistor r=100k\n');

%% =========================
% Single neuron instance
%% =========================
fprintf(fid, 'N1 (Tout ib1 ib2 in_node out pos VDD vhigh vhigh_T pos 0 vth1 vth2) neuron_v35\n');

%% =========================
% Optional output load
%% =========================
if use_output_load
    fprintf(fid, 'RLOAD (out 0) resistor r=%g\n', Rload_val);
    fprintf(fid, 'CLOAD (out 0) capacitor c=%g\n', Cload_val);
end
fprintf(fid, '\n');

%% =========================
% Simulation setup
%% =========================
fprintf(fid, ['simulatorOptions options psfversion="1.1.0" ', ...
    'reltol=1e-3 vabstol=1e-6 iabstol=1e-11 temp=27 tnom=27 ', ...
    'scalem=1.0 scale=1.0 gmin=1e-10 rforce=1 maxnotes=5 maxwarns=5 ', ...
    'digits=5 cols=80 pivrel=1e-2 method=gear2only dc_pivot_check=yes ', ...
    'try_fast_op=no checklimitdest=psf\n']);

fprintf(fid, 'saveOptions options save=none currents=none subcktprobelvl=0\n');
fprintf(fid, 'tran tran stop=%g maxstep=0.2n annotate=status maxiters=100 errpreset=conservative\n\n', tstop);

fprintf(fid, 'simulator lang=spice\n');

fprintf(fid, '.print tran');
fprintf(fid, ' V(in_node) V(out) V(Tout) V(N1.net6) V(N1.net10)');
fprintf(fid, ' V(VDD) V(vhigh) V(pos) V(vth1) V(vth2) V(vhigh_T)');
fprintf(fid, ' V(ib1) V(ib2)');
fprintf(fid, ' I(VVDD) I(VVHIGH) I(VVPOS) I(VVTH1) I(VVTH2) I(VVHIGHT)');
fprintf(fid, ' I(IBIAS1) I(IBIAS2)');
fprintf(fid, '\n');

fclose(fid);
fprintf('Netlist generated: %s\n', scs_file);

%% =========================
% Run Spectre
%% =========================
cmd = sprintf('"%s" +mt=%d "%s"', spectre_path, threads, fullfile(pwd, scs_file));
fprintf('Running Spectre...\n');
[status, cmdout] = system(cmd);
assert(status == 0, 'Spectre run failed:\n%s', cmdout);
fprintf('Spectre finished.\n');

%% =========================
% Read .print file
%% =========================
[~, net_base, ~] = fileparts(scs_file);
c1 = fullfile(pwd, [net_base '.print']);
if ~isfile(c1)
    error('Cannot find print file: %s', c1);
end

[res, name] = import_spectre_data(c1);

time_s = res(:,1);
time_ns = time_s * 1e9;

%% =========================
% Helper
%% =========================
find_idx = @(s) find(strcmpi(name, s), 1);

idx_out      = find_idx('v(out)');
idx_v_vdd    = find_idx('v(VDD)');
idx_v_vhigh  = find_idx('v(vhigh)');
idx_v_vpos   = find_idx('v(pos)');
idx_v_vth1   = find_idx('v(vth1)');
idx_v_vth2   = find_idx('v(vth2)');
idx_v_vht    = find_idx('v(vhigh_T)');
idx_v_ib1    = find_idx('v(ib1)');
idx_v_ib2    = find_idx('v(ib2)');

idx_i_vvdd   = find_idx('i(VVDD)');
idx_i_vvhigh = find_idx('i(VVHIGH)');
idx_i_vvpos  = find_idx('i(VVPOS)');
idx_i_vvth1  = find_idx('i(VVTH1)');
idx_i_vvth2  = find_idx('i(VVTH2)');
idx_i_vvht   = find_idx('i(VVHIGHT)');
idx_i_ib1    = find_idx('i(IBIAS1)');
idx_i_ib2    = find_idx('i(IBIAS2)');

needed = [idx_out idx_v_vdd idx_v_vhigh idx_v_vpos idx_v_vth1 idx_v_vth2 idx_v_vht ...
          idx_v_ib1 idx_v_ib2 ...
          idx_i_vvdd idx_i_vvhigh idx_i_vvpos idx_i_vvth1 idx_i_vvth2 idx_i_vvht idx_i_ib1 idx_i_ib2];

if any(cellfun(@isempty, num2cell(needed)))
    error('Some required waveform names were not found in .print output.');
end

%% =========================
% Read waveforms
%% =========================
v_out   = res(:, idx_out);

v_vdd   = res(:, idx_v_vdd);
v_vhigh = res(:, idx_v_vhigh);
v_vpos  = res(:, idx_v_vpos);
v_vth1  = res(:, idx_v_vth1);
v_vth2  = res(:, idx_v_vth2);
v_vht   = res(:, idx_v_vht);

v_ib1   = res(:, idx_v_ib1);
v_ib2   = res(:, idx_v_ib2);

i_vvdd   = res(:, idx_i_vvdd);
i_vvhigh = res(:, idx_i_vvhigh);
i_vvpos  = res(:, idx_i_vvpos);
i_vvth1  = res(:, idx_i_vvth1);
i_vvth2  = res(:, idx_i_vvth2);
i_vvht   = res(:, idx_i_vvht);

i_ib1 = res(:, idx_i_ib1);
i_ib2 = res(:, idx_i_ib2);

%% =========================
% Power calculation
%% =========================
% voltage sources
p_vdd   = - v_vdd   .* i_vvdd;
p_vhigh = - v_vhigh .* i_vvhigh;
p_vpos  = - v_vpos  .* i_vvpos;
p_vth1  = - v_vth1  .* i_vvth1;
p_vth2  = - v_vth2  .* i_vvth2;
p_vht   = - v_vht   .* i_vvht;

% current sources: drop = VDD - ib node
p_ib1 = - (v_vdd - v_ib1) .* i_ib1;
p_ib2 = - (v_vdd - v_ib2) .* i_ib2;

p_total = p_vdd + p_vhigh + p_vpos + p_vth1 + p_vth2 + p_vht + p_ib1 + p_ib2;

%% =========================
% Energy of the first spike only
%% =========================
t1 = 370.723e-9;
t2 = 443.134e-9;

mask_spike1 = (time_s >= t1) & (time_s <= t2);

if nnz(mask_spike1) < 2
    error('Not enough sampled points inside the selected spike window.');
end

energy_spike1_J = trapz(time_s(mask_spike1), p_total(mask_spike1));
avg_power_spike1_W = energy_spike1_J / (t2 - t1);

fprintf('\n===== First spike energy result =====\n');
fprintf('Window start = %.3f ns\n', t1*1e9);
fprintf('Window end   = %.3f ns\n', t2*1e9);
fprintf('Spike-1 energy = %.6e J\n', energy_spike1_J);
fprintf('Spike-1 avg power = %.6e W\n', avg_power_spike1_W);
energy_total_J = trapz(time_s, p_total);
avg_power_W    = energy_total_J / (time_s(end) - time_s(1));

%% =========================
% Spike count and energy/spike
%% =========================
thresh_spike = 0.94;
spike_count = sum(v_out(1:end-1) < thresh_spike & v_out(2:end) >= thresh_spike);

if spike_count > 0
    energy_per_spike_J = energy_total_J / spike_count;
else
    energy_per_spike_J = NaN;
end

fprintf('\n===== Single neuron energy result =====\n');
fprintf('Total energy      = %.6e J\n', energy_total_J);
fprintf('Average power     = %.6e W\n', avg_power_W);
fprintf('Spike count       = %d\n', spike_count);
fprintf('Energy per spike  = %.6e J/spike\n', energy_per_spike_J);


%% =========================
% Plot 3 waveforms in subplots
%% =========================
idx_in_node = find_idx('v(in_node)');
idx_net6    = find_idx('v(N1.net6)');
idx_out     = find_idx('v(out)');

if isempty(idx_in_node) || isempty(idx_net6) || isempty(idx_out)
    error('Cannot find one or more waveform signals for plotting.');
end

v_in_node = res(:, idx_in_node);
v_net6    = res(:, idx_net6);
v_out     = res(:, idx_out);

figure;

subplot(3,1,1);
plot(time_ns, v_in_node, 'LineWidth', 1.5);
ylabel('Voltage (V)');
title('Input Waveform: v(in\_node)');
grid on;

subplot(3,1,2);
plot(time_ns, v_net6, 'LineWidth', 1.5);
ylabel('Voltage (V)');
title('Integration Node: v(N1.net6)');
grid on;

subplot(3,1,3);
plot(time_ns, v_out, 'LineWidth', 1.5);
xlabel('Time (ns)');
ylabel('Voltage (V)');
title('Output Waveform: v(out)');
grid on;

%% =========================================================================
% Functions
%% =========================================================================
function [res, name] = import_spectre_data(file)
fid = fopen(file,'r');
assert(fid>0, 'Cannot open file: %s', file);
C = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
L = C{1};
nL = numel(L);

anchor = 1;
for i = 1:nL
    li = strtrim(L{i});
    if strcmp(li,'y')
        anchor(end+1) = i; %#ok<AGROW>
    end
end
anchor = sort(unique(anchor));

res = [];
name = {};
for a = 1:numel(anchor)
    i0 = anchor(a);
    ix = i0 + find_next_line(L, i0, 'x');
    if isempty(ix), ix = i0; end

    ih = find_header(L, ix);
    if isempty(ih)
        ih = find_header(L, i0);
    end
    if isempty(ih)
        continue;
    end

    [block, header, ~] = parse_block(L, ih);
    if isempty(block), continue; end

    if isempty(res)
        res = block;
        name = header;
    else
        t0 = res(:,1);
        t1 = block(:,1);
        if numel(t0)==numel(t1) && all(abs(t0-t1) <= max(1e-18, 1e-12*max(1,max(abs(t0)))))
            res = [res, block(:,2:end)];
            name = [name, header(2:end)];
        else
            [~, ia, ib] = intersect(t0, t1);
            res = [res(ia,:), block(ib,2:end)];
            name = [name, header(2:end)];
        end
    end
end

if isempty(res)
    error('No valid data block found in %s.', file);
end
end

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

function ih = find_header(L, i0)
ih = [];
for i = i0+1 : numel(L)
    li = strtrim(L{i});
    if isempty(li) || startsWith(li,'*') || startsWith(li,'******')
        continue;
    end
    toks = regexp(li, '\S+', 'match');
    if ~isempty(toks) && strcmpi(toks{1}, 'time')
        ih = i;
        return;
    end
end
end

function [block, header, iend] = parse_block(L, ih)
header = regexp(strtrim(L{ih}), '\S+', 'match');
K = numel(header);

rows = {};
for i = ih+1 : numel(L)
    li = strtrim(L{i});
    if isempty(li), break; end
    if isempty(regexp(li, '^[\+\-]?\d', 'once'))
        break;
    end
    rows{end+1} = li; %#ok<AGROW>
end
iend = ih + numel(rows);

N = numel(rows);
block = nan(N, K);
for r = 1:N
    block(r,1:K) = parse_row(rows{r}, K);
end

goodCol = any(~isnan(block),1);
block = block(:,goodCol);
header = header(goodCol);

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