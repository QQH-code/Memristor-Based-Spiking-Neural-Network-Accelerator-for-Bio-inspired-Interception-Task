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

V_in_low  = 0.0;
V_in_high = 0.05;

% ----- gate pulse for access NFET -----
V_gate_low  = 0.0;
V_gate_high = 1.8;

tstop  = 1.5e-6;
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
VTH1_val     = 0.2;
VTH2_val     = 0.88;
IBIAS_val    = 6e-6;

% ----- optional isolated output load -----
% keep light load for isolated measurement
use_output_load = false;
Rload_val = 1e5;      % very light resistive load
Cload_val = 5e-15;    % small output parasitic load

% ----- Spectre path -----
spectre_path = '$SPECTRE_BIN';
threads      = 4;

% ----- output file -----
scs_file = sprintf('plot_integration2_%s.scs', task_id_str);

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
% Subckt: baseline comparator-reset neuron
%% =========================
fprintf(fid, 'subckt neuron_cmp_reset ib1 mem out pos vdd vss\n');
fprintf(fid, '    XCMP  (ib1 vdd vss pos out mem) CMP\n');
fprintf(fid, '    Cmem  (mem 0) cap_mim_m3_1 l=5.9u w=5.9u m=4\n');
fprintf(fid, '    MREST (mem out 0 0) nfet_01v8 w=420n l=150n\n');
fprintf(fid, 'ends neuron_cmp_reset\n\n');

%% =========================
% Initial condition
%% =========================
fprintf(fid, 'ic in_mid=0 in_node=0 gate_node=0 out=0\n\n');

%% =========================
% Dedicated supplies
%% =========================
fprintf(fid, 'VVDD   (VDD 0)   vsource dc=%g type=dc\n', VDD_val);
fprintf(fid, 'VVPOS  (pos 0)   vsource dc=%g type=dc\n', VTH1_val);   % comparator reference

fprintf(fid, 'IBIAS1 (VDD ib1) isource dc=%gu type=dc\n', IBIAS_val * 1e6);

%% =========================
% Input source
%% =========================
if use_pulse_input
    % input pulse: 0.9 -> 0.95 V
    fprintf(fid, ['VIN (vin_src 0) vsource type=pulse delay=%g val0=%g val1=%g ', ...
                  'period=%g rise=%g fall=%g width=%g\n'], ...
                  tdelay, V_in_low, V_in_high, tpulse, trise, tfall, twidth);

    % gate pulse: 0 -> 1.8 V, same timing as VIN
    fprintf(fid, ['VGATE (gate_node 0) vsource type=pulse delay=%g val0=%g val1=%g ', ...
                  'period=%g rise=%g fall=%g width=%g\n'], ...
                  tdelay, V_gate_low, V_gate_high, tpulse, trise, tfall, twidth);
else
    fprintf(fid, 'VIN   (vin_src 0)   vsource dc=%g type=dc\n', V_in_low);
    fprintf(fid, 'VGATE (gate_node 0) vsource dc=%g type=dc\n', V_gate_low);
end

% resistor first
fprintf(fid, 'RIN (vin_src in_mid) resistor r=800k\n');

% access transistor between resistor and neuron input
fprintf(fid, 'M_ACC (in_node gate_node in_mid 0) nfet_01v8 w=420n l=150n\n');

%% =========================
% Single neuron instance
%% =========================
fprintf(fid, 'N1 (ib1 in_node out pos VDD 0) neuron_cmp_reset\n');

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
fprintf(fid, ' V(vin_src) V(in_mid) V(in_node) V(gate_node) V(out)');
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

idx_vin_src = find_idx('v(vin_src)');
idx_mem     = find_idx('v(in_node)');
idx_out     = find_idx('v(out)');

if isempty(idx_vin_src) || isempty(idx_mem) || isempty(idx_out)
    error('Cannot find required waveform signals for plotting.');
end

%% =========================
% Read waveforms
%% =========================
v_vin_src = res(:, idx_vin_src);
v_mem     = res(:, idx_mem);
v_out     = res(:, idx_out);

%% =========================
% Plot waveforms
%% =========================
figure;

c_green   = [0.10, 0.85, 0.20];
c_blue    = [0.00, 0.20, 0.75];
c_darkred = [0.85, 0.10, 0.10];

subplot(2,1,1);
plot(time_ns, v_vin_src, 'Color', c_green, 'LineWidth', 1.5);
ylabel('Voltage (V)');
title('Input Pulse');
ylim([0 60e-3]);   % limit to 0 ~ 60 mV
grid on;
box on;

subplot(2,1,2);
plot(time_ns, v_mem, 'Color', c_blue, 'LineWidth', 1.5);
hold on;
plot(time_ns, v_out, 'Color', c_darkred, 'LineWidth', 1.5);
hold off;
xlabel('Time (ns)');
ylabel('Voltage (V)');
title('Integration and Output Spike');
legend('v(membrane)', 'v(out)', 'Location', 'best');
grid on;
box on;

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