% =========================================================================
% Script:   monte_carlo_neuron.m
% Purpose:
%   Isolate one neuron_v35, run Spectre Monte Carlo simulation, and plot
%   V(out) waveforms of all Monte Carlo samples on one figure.
% =========================================================================

clear; clc;

%% =========================
% User settings
%% =========================
task_id_str = 'single_neuron';

%% ----- Spectre Monte Carlo settings -----
mc_enable      = true;
mc_numruns     = 50;          % number of Monte Carlo samples
mc_seed        = 12345;
mc_variations  = 'mismatch';       % 'process', 'mismatch', or 'all'
mc_donominal   = true;       % false => do not run nominal point

% ----- manual input pulse -----
use_pulse_input = true;

V_in_low  = 0.9;
V_in_high = 0.95;

tstop  = 7e-6;
trise  = 2e-9;
tfall  = 2e-9;
twidth = 55e-9;
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
run_dir = fullfile(pwd, sprintf('mc_run_%s', task_id_str));
if ~exist(run_dir, 'dir')
    mkdir(run_dir);
end

scs_file = fullfile(run_dir, sprintf('mc_%s.scs', task_id_str));

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
fprintf(fid, 'parameters VDD_mc=%g VHIGH_mc=%g POS_mc=%g VTH1_mc=%g VTH2_mc=%g VHIGHT_mc=%g\n', ...
    VDD_val, Vhigh_val, POS_val, VTH1_val, VTH2_val, Vhigh_T_val);

fprintf(fid, 'parameters IBIAS1_mc=%g IBIAS2_mc=%g RIN_mc=%g\n\n', ...
    IBIAS_val, IBIAS_val, 50e3);

fprintf(fid, 'VVDD     (VDD 0)      vsource dc=VDD_mc type=dc\n');
fprintf(fid, 'VVHIGH   (vhigh 0)    vsource dc=VHIGH_mc type=dc\n');
fprintf(fid, 'VVPOS    (pos 0)      vsource dc=POS_mc type=dc\n');
fprintf(fid, 'VVTH1    (vth1 0)     vsource dc=VTH1_mc type=dc\n');
fprintf(fid, 'VVTH2    (vth2 0)     vsource dc=VTH2_mc type=dc\n');
fprintf(fid, 'VVHIGHT  (vhigh_T 0)  vsource dc=VHIGHT_mc type=dc\n');

fprintf(fid, 'IBIAS1 (VDD ib1) isource dc=IBIAS1_mc type=dc\n');
fprintf(fid, 'IBIAS2 (VDD ib2) isource dc=IBIAS2_mc type=dc\n');


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

fprintf(fid, 'RIN (vin_src in_node) resistor r=700k\n');

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

if mc_enable
	fprintf(fid, 'statistics {\n');
	fprintf(fid, '  process {\n');
	fprintf(fid, '    vary VTH1_mc   dist=gauss std=0.001v\n');      % 2 mV
	fprintf(fid, '    vary VTH2_mc   dist=gauss std=0.001v\n');      % 2 mV
	fprintf(fid, '    vary IBIAS1_mc dist=gauss std=0.01u\n');      % 0.2 uA
	fprintf(fid, '    vary IBIAS2_mc dist=gauss std=0.01u\n');      % 0.2 uA
	fprintf(fid, '  }\n');
	
    % ---- PFET model mismatch from SKY130 ----
    fprintf(fid, '  mismatch {\n');
    fprintf(fid, '    vary sky130_fd_pr__pfet_01v8__toxe_slope_spectre    dist=gauss std=0.3e-7\n');
    fprintf(fid, '    vary sky130_fd_pr__pfet_01v8__vth0_slope_spectre    dist=gauss std=0.03e-7\n');
    fprintf(fid, '    vary sky130_fd_pr__pfet_01v8__nfactor_slope_spectre dist=gauss std=0.03e-9\n');

	
    % ---- NFET model mismatch from SKY130 ----
    fprintf(fid, '    vary sky130_fd_pr__nfet_01v8__toxe_slope_spectre    dist=gauss std=0.3e-7\n');
    fprintf(fid, '    vary sky130_fd_pr__nfet_01v8__vth0_slope_spectre    dist=gauss std=0.03e-7\n');
    fprintf(fid, '    vary sky130_fd_pr__nfet_01v8__voff_slope_spectre    dist=gauss std=0.03e-11\n');
    fprintf(fid, '  }\n');	
	fprintf(fid, '}\n\n');
    fprintf(fid, ['mc1 montecarlo numruns=%d variations=%s seed=%d ', ...
                  'donominal=%s savefamilyplots=yes savedatainseparatedir=yes {\n'], ...
                  mc_numruns, mc_variations, mc_seed, ternary_str(mc_donominal, 'yes', 'no'));

    fprintf(fid, '    tran tran stop=%g maxstep=0.2n annotate=status maxiters=100 errpreset=conservative\n', tstop);
    fprintf(fid, '}\n\n');
else
    fprintf(fid, 'tran tran stop=%g maxstep=0.2n annotate=status maxiters=100 errpreset=conservative\n\n', tstop);
end

fprintf(fid, 'simulator lang=spice\n');

fprintf(fid, '.print tran');
fprintf(fid, ' V(in_node) V(out) V(N1.net6) V(N1.net10)');
fprintf(fid, '\n');

fclose(fid);
fprintf('Netlist generated: %s\n', scs_file);

%% =========================
% Run Spectre
%% =========================
% cmd = sprintf('cd "%s" && "%s" +mt=%d "%s"', ...
%     run_dir, spectre_path, threads, scs_file);
% 
% fprintf('Running Spectre...\n');
% [status, cmdout] = system(cmd);
% assert(status == 0, 'Spectre run failed:\n%s', cmdout);
% fprintf('Spectre finished.\n');

%% =========================
% Read Monte Carlo .print files and plot all V(out)
%% =========================
[~, net_base, ~] = fileparts(scs_file);

if mc_enable
    print_file = fullfile(run_dir, sprintf('mc_%s.print', task_id_str));
    if ~isfile(print_file)
        error('Cannot find Monte Carlo print file: %s', print_file);
    end

    fprintf('Reading Monte Carlo print file: %s\n', print_file);

    mc_runs = import_spectre_mc_print(print_file);

    %% =========================
    %  Find case 0 reference crossing time
    %% =========================
    thresh_cross = 0.902;   % threshold for first upward crossing

    ref_idx = [];
    for k = 1:numel(mc_runs)
        if mc_runs(k).iter == 0
            ref_idx = k;
            break;
        end
    end

    if isempty(ref_idx)
        error('Cannot find nominal case (iter = 0).');
    end

    % helper: find first upward crossing time by linear interpolation
    get_first_cross_time = @(time_s, v, th) local_first_cross_time(time_s, v, th);

    name_ref = mc_runs(ref_idx).name;
    res_ref  = mc_runs(ref_idx).res;
    idx_out_ref = find(strcmpi(name_ref, 'v(out)'), 1);

    if isempty(idx_out_ref)
        error('Cannot find v(out) in nominal case.');
    end

    t_ref = get_first_cross_time(res_ref(:,1), res_ref(:,idx_out_ref), thresh_cross);

    if isnan(t_ref)
        error('Nominal case (iter=0) does not cross %.3f V upward.', thresh_cross);
    end

    fprintf('Reference case = iter 0, first upward crossing at %.3f ns\n', t_ref*1e9);

    %% =========================
    %  Compute delta-t for all cases
    %% =========================
    dt_list   = nan(1, numel(mc_runs));   % dt = t_i - t_ref
    t_crosses = nan(1, numel(mc_runs));
    valid_cross = false(1, numel(mc_runs));

    for k = 1:numel(mc_runs)
        name_k = mc_runs(k).name;
        res_k  = mc_runs(k).res;

        idx_out_k = find(strcmpi(name_k, 'v(out)'), 1);
        if isempty(idx_out_k)
            continue;
        end

        t_cross_k = get_first_cross_time(res_k(:,1), res_k(:,idx_out_k), thresh_cross);
        if isnan(t_cross_k)
            continue;
        end

        t_crosses(k) = t_cross_k;
        dt_list(k)   = t_cross_k - t_ref;
        valid_cross(k) = true;
    end

	%% =========================
	%  Compute sigma from non-reference cases
	%% =========================
	nonref_mask = valid_cross & ([mc_runs.iter] ~= 0);

	if ~any(nonref_mask)
		error('No valid Monte Carlo cases other than case 0.');
	end

	sigma_dt = std(dt_list(nonref_mask), 0);   % sample std
	fprintf('Sigma of delta-t = %.3f ns\n', sigma_dt*1e9);

	if sigma_dt == 0
		warning('Computed sigma_dt = 0. All valid cases will be kept.');
	end

	%% =========================
	%  Keep only cases within 3 sigma
	%% =========================
	keep_mask = false(1, numel(mc_runs));

	for k = 1:numel(mc_runs)
		if ~valid_cross(k)
			continue;
		end

		if mc_runs(k).iter == 0
			keep_mask(k) = true;   % always keep nominal
		else
			keep_mask(k) = abs(dt_list(k)) <= 3*sigma_dt;
		end
	end
    fprintf('Total valid crossing cases = %d\n', sum(valid_cross));
    fprintf('Kept within 3 sigma        = %d\n', sum(keep_mask));
    fprintf('Removed beyond 3 sigma     = %d\n', sum(valid_cross) - sum(keep_mask));

    %% =========================
    %  Plot only kept cases
    %% =========================
    figure;

    subplot(2,1,1);
    hold on; grid on;
    title(sprintf('Monte Carlo V(out), keep within 3\\sigma (%.3f ns)', sigma_dt*1e9));
    xlabel('Time (ns)');
    ylabel('V(out) (V)');

    subplot(2,1,2);
    hold on; grid on;
    title(sprintf('Monte Carlo V(N1.net6), keep within 3\\sigma (%.3f ns)', sigma_dt*1e9));
    xlabel('Time (ns)');
    ylabel('V(N1.net6) (V)');

    valid_count = 0;
    legend_entries = {};

    for k = 1:numel(mc_runs)
        if ~keep_mask(k)
            continue;
        end

        name = mc_runs(k).name;
        res  = mc_runs(k).res;

        idx_out  = find(strcmpi(name, 'v(out)'), 1);
        idx_net6 = find(strcmpi(name, 'v(N1.net6)'), 1);

        if isempty(idx_out) || isempty(idx_net6)
            continue;
        end

        time_s   = res(:,1);
        time_ns  = time_s * 1e9;
        v_out    = res(:, idx_out);
        v_net6   = res(:, idx_net6);

        if mc_runs(k).iter == 0
            % case 0: nominal, highlight it
            subplot(2,1,1);
            plot(time_ns, v_out, 'k', 'LineWidth', 2.5);

            subplot(2,1,2);
            plot(time_ns, v_net6, 'k', 'LineWidth', 2.5);

            legend_entries{end+1} = sprintf('Case %d (nominal)', mc_runs(k).iter); %#ok<AGROW>
        else
            subplot(2,1,1);
            plot(time_ns, v_out, 'LineWidth', 1.2);

            subplot(2,1,2);
            plot(time_ns, v_net6, 'LineWidth', 1.2);

            legend_entries{end+1} = sprintf('Case %d, \\Deltat = %.2f ns', ...
                mc_runs(k).iter, dt_list(k)*1e9); %#ok<AGROW>
        end

        valid_count = valid_count + 1;
    end

    subplot(2,1,1);
    title(sprintf('Monte Carlo V(out): %d kept cases', valid_count));
    if valid_count <= 20
        legend(legend_entries, 'Location', 'best');
    end
    hold off;

    subplot(2,1,2);
    title(sprintf('Monte Carlo V(N1.net6): %d kept cases', valid_count));
    if valid_count <= 10
        legend(legend_entries, 'Location', 'best');
    end
    hold off;

	subplot(2,1,1);
	title(sprintf('Monte Carlo V(out): %d valid runs', valid_count));
	if valid_count <= 20
		legend(legend_entries, 'Location', 'best');
	end
	hold off;

	subplot(2,1,2);
	title(sprintf('Monte Carlo V(N1.net6): %d valid runs', valid_count));
	if valid_count <= 10
		legend(legend_entries, 'Location', 'best');
	end
	hold off;
else
    % ---------- single-run path ----------
    c1 = fullfile(run_dir, [net_base '.print']);
    if ~isfile(c1)
        error('Cannot find print file: %s', c1);
    end

    [res, name] = import_spectre_data(c1);

    find_idx = @(s) find(strcmpi(name, s), 1);
    idx_out = find_idx('v(out)');

    if isempty(idx_out)
        error('Cannot find v(out) in .print output.');
    end

    time_s  = res(:,1);
    time_ns = time_s * 1e9;
    v_out   = res(:, idx_out);

    figure;
    plot(time_ns, v_out, 'LineWidth', 1.5);
    xlabel('Time (ns)');
    ylabel('V(out) (V)');
    title('Single-Run Output Waveform: V(out)');
    grid on;
end

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

function s = ternary_str(cond, s_true, s_false)
if cond
    s = s_true;
else
    s = s_false;
end
end

function mc_runs = import_spectre_mc_print(file)
fid = fopen(file, 'r');
assert(fid > 0, 'Cannot open file: %s', file);
C = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);

L = C{1};
nL = numel(L);

% 找到每个 Monte Carlo iteration 的起始行
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

    % 在当前 block 里找 header：time ...
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

function t_cross = local_first_cross_time(time_s, v, thresh)
t_cross = nan;

idx = find(v(1:end-1) < thresh & v(2:end) >= thresh, 1, 'first');
if isempty(idx)
    return;
end

t1 = time_s(idx);
t2 = time_s(idx+1);
v1 = v(idx);
v2 = v(idx+1);

if v2 == v1
    t_cross = t2;
else
    % linear interpolation
    t_cross = t1 + (thresh - v1) * (t2 - t1) / (v2 - v1);
end
end