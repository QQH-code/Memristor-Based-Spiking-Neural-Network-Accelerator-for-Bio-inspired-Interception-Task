% =========================================================================
% Script:   test_4pre_1post_with_optional_nfet.m
% Purpose:
%   Build a 4-input-neuron -> 1-postsynaptic-neuron Spectre testbench.
%   - Only input neuron #1 has pulse input
%   - Other 3 input neurons stay at 0.9V
%   - All 4 synaptic resistors = 200k Ohm
%   - Optional access NFET between resistor and postsynaptic neuron
%   - Plot:
%       1) postsynaptic membrane voltage v(NPOST.net6)
%       2) first-layer output spikes v(out1_1~4)
% =========================================================================

clear; clc; close all;

%% =========================
% User settings
%% =========================
task_id_str = '4pre_1post';

% ----- switch: 1 => with nfet, 0 => no nfet -----
use_access_nfet = 1;

% ----- input pulse settings -----
V_in_low  = 0.9;
V_in_high = 1.3;

tstop  = 20e-6;
trise  = 5e-9;
tfall  = 5e-9;
twidth = 55e-9;
tpulse = 100e-7;
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

% ----- synapse setting -----
Rsyn_val = 200e3;   % 200 kohm

% ----- access transistor size -----
acc_w = '1680n';
acc_l = '150n';

% ----- Spectre path -----
spectre_path = '$SPECTRE_BIN';
threads      = 4;

% ----- output file -----
scs_file = sprintf('test_4pre_1post_%s.scs', task_id_str);

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

fprintf(fid, ...
    'include "$PROJECT_ROOT" section=tt\n\n');

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
fprintf(fid, 'subckt neuron_v35 Tout ib1 ib2 neg out pos vdd vhigh vhigh_T vlow vlow2 vss vth1 vth2\n');
fprintf(fid, '    I0 (ib1 vdd vss neg net6 pos) snn1_7TOpamp_schematic\n');
fprintf(fid, '    I1 (ib2 vdd vss net6 net10 net7) CMP\n');
fprintf(fid, '    PM13 (Tout net48 vhigh_T vdd) pfet_01v8 w=(550n) l=150n as=84.6389f ad=77f ps=918.889n pd=830n m=(1)*(18)\n');
fprintf(fid, '    PM12 (Tout net24 vlow2 vdd) pfet_01v8 w=(550n) l=150n as=84.6389f ad=77f ps=918.889n pd=830n m=(1)*(18)\n');
fprintf(fid, '    PM11 (out net48 vhigh vdd) pfet_01v8 w=(5u) l=150n as=719.531f ad=700f ps=5.44406u pd=5.28u m=(1)*(64)\n');
fprintf(fid, '    PM5 (out net24 vlow vdd) pfet_01v8 w=(5u) l=150n as=719.531f ad=700f ps=5.44406u pd=5.28u m=(1)*(64)\n');
fprintf(fid, '    PM4 (net48 net24 vdd vdd) pfet_01v8 w=(550n) l=150n as=145.75f ad=77f ps=1.63u pd=830n m=(1)*(2)\n');
fprintf(fid, '    PM10 (net22 net10 vdd vdd) pfet_01v8 w=(6.25u) l=650n as=1.26563p ad=875f ps=9.78u pd=6.53u m=(1)*(4)\n');
fprintf(fid, '    PM9 (net24 net22 vdd vdd) pfet_01v8 w=(6u) l=650n as=990f ad=840f ps=7.53u pd=6.28u m=(1)*(10)\n');
fprintf(fid, '    PM0 (vth1 net10 net7 vdd) pfet_01v8 w=(550n) l=150n as=84.6389f ad=77f ps=918.889n pd=830n m=(1)*(18)\n');
fprintf(fid, '    NM14 (vhigh_T net24 Tout vss) nfet_01v8 w=(5.5u) l=150n as=846.389f ad=770f ps=6.41889u pd=5.78u m=(1)*(18)\n');
fprintf(fid, '    NM13 (vlow2 net48 Tout vss) nfet_01v8 w=(5.5u) l=150n as=846.389f ad=770f ps=6.41889u pd=5.78u m=(1)*(18)\n');
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
% Initial conditions
%% =========================
% fprintf(fid, ...
    % ['ic N1_1.net6=0.92749 N1_1.net10=0 out1_1=0.9 Tout1_1=0 in_node1=0.9 ', ...
     % 'N1_2.net6=0.92749 N1_2.net10=0 out1_2=0.9 Tout1_2=0 in_node2=0.9 ', ...
     % 'N1_3.net6=0.92749 N1_3.net10=0 out1_3=0.9 Tout1_3=0 in_node3=0.9 ', ...
     % 'N1_4.net6=0.92749 N1_4.net10=0 out1_4=0.9 Tout1_4=0 in_node4=0.9 ', ...
     % 'NPOST.net6=0.92749 NPOST.net10=0 out2_1=0.9 Tout2_1=0 post_in=0.9\n\n']);

%% =========================
% Dedicated supplies
%% =========================
fprintf(fid, 'VVDD     (VDD 0)      vsource dc=%g type=dc\n', VDD_val);
fprintf(fid, 'VVHIGH   (vhigh 0)    vsource dc=%g type=dc\n', Vhigh_val);
fprintf(fid, 'VVPOS    (pos 0)      vsource dc=%g type=dc\n', POS_val);
fprintf(fid, 'VVTH1    (vth1 0)     vsource dc=%g type=dc\n', VTH1_val);
fprintf(fid, 'VVTH2    (vth2 0)     vsource dc=%g type=dc\n', VTH2_val);
fprintf(fid, 'VVHIGHT  (vhigh_T 0)  vsource dc=%g type=dc\n', Vhigh_T_val);

for i = 1:4
    fprintf(fid, 'IBIAS1_%d (VDD ib1_%d) isource dc=%gu type=dc\n', i, i, IBIAS_val * 1e6);
    fprintf(fid, 'IBIAS2_%d (VDD ib2_%d) isource dc=%gu type=dc\n', i, i, IBIAS_val * 1e6);
end
fprintf(fid, 'IBIAS1_P (VDD ib1_p) isource dc=%gu type=dc\n', IBIAS_val * 1e6);
fprintf(fid, 'IBIAS2_P (VDD ib2_p) isource dc=%gu type=dc\n\n', IBIAS_val * 1e6);

%% =========================
% Input sources
%% =========================
% neuron 1: pulse input
fprintf(fid, ['VIN1 (vin_src1 0) vsource type=pulse delay=%g val0=%g val1=%g ', ...
              'period=%g rise=%g fall=%g width=%g\n'], ...
              tdelay, V_in_low, V_in_high, tpulse, trise, tfall, twidth);
fprintf(fid, 'RIN1 (vin_src1 in_node1) resistor r=100k\n');

% neuron 2~4: dc 0.9V
fprintf(fid, 'VIN2 (vin_src2 0) vsource dc=%g type=dc\n', V_in_low);
fprintf(fid, 'RIN2 (vin_src2 in_node2) resistor r=100k\n');
fprintf(fid, 'VIN3 (vin_src3 0) vsource dc=%g type=dc\n', V_in_low);
fprintf(fid, 'RIN3 (vin_src3 in_node3) resistor r=100k\n');
fprintf(fid, 'VIN4 (vin_src4 0) vsource dc=%g type=dc\n\n', V_in_low);
fprintf(fid, 'RIN4 (vin_src4 in_node4) resistor r=100k\n');

%% =========================
% First-layer neuron instances
%% =========================
fprintf(fid, 'N1_1 (Tout1_1 ib1_1 ib2_1 in_node1 out1_1 pos VDD vhigh vhigh_T pos VDD 0 vth1 vth2) neuron_v35\n');
fprintf(fid, 'N1_2 (Tout1_2 ib1_2 ib2_2 in_node2 out1_2 pos VDD vhigh vhigh_T pos VDD 0 vth1 vth2) neuron_v35\n');
fprintf(fid, 'N1_3 (Tout1_3 ib1_3 ib2_3 in_node3 out1_3 pos VDD vhigh vhigh_T pos VDD 0 vth1 vth2) neuron_v35\n');
fprintf(fid, 'N1_4 (Tout1_4 ib1_4 ib2_4 in_node4 out1_4 pos VDD vhigh vhigh_T pos VDD 0 vth1 vth2) neuron_v35\n\n');

%% =========================
% Synapse connections
%% =========================
if use_access_nfet
    % with access nfet:
    % out1_i -> Rsyn -> syn_mid_i -> nfet -> post_in
    % gate = Tout1_i
    for i = 1:4
        fprintf(fid, 'RSYN_%d (out1_%d syn_mid_%d) resistor r=%g\n', i, i, i, Rsyn_val);
        fprintf(fid, ...
            'MACC_%d (syn_mid_%d Tout1_%d post_in 0) nfet_01v8 w=(420n) l=150n as=85.05f ad=58.8f ps=1.035u pd=700n m=(1)*(4)\n\n', ...
            i, i, i);
    end
else
    % without access nfet:
    % out1_i -> Rsyn -> post_in
    for i = 1:4
        fprintf(fid, 'RSYN_%d (out1_%d post_in) resistor r=%g\n', i, i, Rsyn_val);
    end
end
fprintf(fid, '\n');

%% =========================
% Postsynaptic neuron instance
%% =========================
fprintf(fid, 'NPOST (Tout2_1 ib1_p ib2_p post_in out2_1 pos VDD vhigh vhigh_T pos pos 0 vth1 vth2) neuron_v35\n\n');

%% =========================
% Simulation setup
%% =========================
fprintf(fid, ['simulatorOptions options psfversion="1.1.0" ', ...
    'reltol=1e-3 vabstol=1e-6 iabstol=1e-11 temp=27 tnom=27 ', ...
    'scalem=1.0 scale=1.0 gmin=1e-10 rforce=1 maxnotes=5 maxwarns=5 ', ...
    'digits=5 cols=80 pivrel=1e-2 method=gear2only dc_pivot_check=yes ', ...
    'try_fast_op=no checklimitdest=psf\n']);

fprintf(fid, 'saveOptions options save=none currents=none subcktprobelvl=0\n');
fprintf(fid, 'tran tran stop=%g maxstep=3n annotate=status maxiters=100 errpreset=conservative\n\n', tstop);

fprintf(fid, 'simulator lang=spice\n');

fprintf(fid, '.print tran');
fprintf(fid, ' V(in_node1) V(in_node2) V(in_node3) V(in_node4)');
fprintf(fid, ' V(out1_1) V(out1_2) V(out1_3) V(out1_4)');
fprintf(fid, ' V(Tout1_1) V(Tout1_2) V(Tout1_3) V(Tout1_4)');
fprintf(fid, ' V(post_in) V(out2_1) V(Tout2_1)');
fprintf(fid, ' V(N1_1.net6) V(N1_2.net6) V(N1_3.net6) V(N1_4.net6)');
fprintf(fid, ' V(NPOST.net6) V(NPOST.net10)');
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
print_file = fullfile(pwd, [net_base '.print']);
if ~isfile(print_file)
    error('Cannot find print file: %s', print_file);
end

[res, name] = import_spectre_data(print_file);

time_s  = res(:,1);
time_ns = time_s * 1e9;

%% =========================
% Helper
%% =========================
find_idx = @(s) find(strcmpi(name, s), 1);

idx_out1_1  = find_idx('v(out1_1)');
idx_out1_2  = find_idx('v(out1_2)');
idx_out1_3  = find_idx('v(out1_3)');
idx_out1_4  = find_idx('v(out1_4)');
idx_tout1_1 = find_idx('v(Tout1_1)');
idx_post_m  = find_idx('v(NPOST.net6)');

if isempty(idx_out1_1) || isempty(idx_out1_2) || isempty(idx_out1_3) || ...
   isempty(idx_out1_4) || isempty(idx_tout1_1) || isempty(idx_post_m)
    error('Cannot find one or more required waveform names in .print output.');
end

v_out1_1  = res(:, idx_out1_1);
v_out1_2  = res(:, idx_out1_2);
v_out1_3  = res(:, idx_out1_3);
v_out1_4  = res(:, idx_out1_4);
v_tout1_1 = res(:, idx_tout1_1);
v_post_m  = res(:, idx_post_m);

%% =========================
% Plot
%% =========================
figure('Color','w');

subplot(3,1,1);
plot(time_ns, v_post_m, 'LineWidth', 1.5);
xlabel('Time (ns)');
ylabel('Voltage (V)');
title('Postsynaptic Membrane Voltage: v(NPOST.net6)');
grid on;

subplot(3,1,2);
plot(time_ns, v_tout1_1, 'LineWidth', 1.5);
xlabel('Time (ns)');
ylabel('Voltage (V)');
title('Control Signal: v(Tout1_1)');
grid on;

subplot(3,1,3);
plot(time_ns, v_out1_1, 'LineWidth', 1.2); hold on;
plot(time_ns, v_out1_2, 'LineWidth', 1.2);
plot(time_ns, v_out1_3, 'LineWidth', 1.2);
plot(time_ns, v_out1_4, 'LineWidth', 1.2);
xlabel('Time (ns)');
ylabel('Voltage (V)');
title('First-Layer Output Spikes');
legend('v(out1\_1)','v(out1\_2)','v(out1\_3)','v(out1\_4)','Location','best');
grid on;
hold off;

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