clc; clear; close all;

%% ===================== 0) User settings =====================
csv_path   = 'prey_trajectories_500x50.csv';   % prey trajectory file
Va         = 1.3;                              % predator step length per step
catch_dist = 1.0;                              % capture threshold
pulse_width= 55e-9;
vth        = 0.71;
%% ===================== 1) Read prey trajectory =====================
T_prey = readtable(csv_path);
T_prey = sortrows(T_prey, 'point_index');
% prey coordinates
Bx = T_prey.x;
By = T_prey.y;

N = length(Bx);
if N < 2
    error('Prey trajectory must contain at least 2 points.');
end

log_file = 'closed_loop_log.txt';
fid_log = fopen(log_file, 'w');

if fid_log == -1
    error('Cannot open log file: %s', log_file);
end

fprintf(fid_log, 'Closed-loop run started.\n');
fprintf(fid_log, 'csv_path = %s\n', csv_path);
fprintf(fid_log, 'Va = %.4f, catch_dist = %.4f\n', Va, catch_dist);
fprintf(fid_log, 'pulse_width = %.3e, vth = %.4f\n', pulse_width, vth);
fprintf(fid_log, 'Total prey points = %d\n\n', N);


%% ===================== 2) Initialize predator =====================
% predator starts at origin
Ax = zeros(N,1);
Ay = zeros(N,1);

% record arrays
deg_AC_hist   = nan(N,1);   % predator heading
deg_AB_hist   = nan(N,1);   % line-of-sight angle
theta1_hist   = nan(N,1);
theta2_hist   = nan(N,1);
S1_hist       = nan(N,1);
S2_hist       = nan(N,1);
x_in_hist     = nan(N,4);
output_hist   = nan(N,1);
spike_hist    = nan(N,1);
dist_hist     = nan(N,1);

% initial predator heading:
% point from predator initial position A(0,0) to prey first point B1
deg_AC = atan2d(By(1) - Ay(1), Bx(1) - Ax(1));
deg_AC_hist(1) = deg_AC;

% initial theta1
theta1_prev = 0;

% initial distance
dist_hist(1) = sqrt((Bx(1)-Ax(1))^2 + (By(1)-Ay(1))^2);

%% ===================== 3) Closed-loop step-by-step inference =====================
% We use prey point k as the "current prey position"
% predator position A(k-1) -> update to A(k)

captured = false;
capture_step = NaN;

for k = 2:N
    
    % -------------------------------------------------------------
    % Step A: current prey position is B(k)
    % current predator position is A(k)
    % -------------------------------------------------------------
    B_prev = [Bx(k-1), By(k-1)];
    B_curr = [Bx(k),   By(k)];
	
    Ax(k) = Ax(k-1) + Va * cosd(deg_AC);
    Ay(k) = Ay(k-1) + Va * sind(deg_AC);
	
    A_prev = [Ax(k-1), Ay(k-1)];
    A_curr = [Ax(k),   Ay(k)];	
    
    % line-of-sight angle from current predator position to current prey position
    deg_AB = atan2d(B_curr(2) - A_curr(2), B_curr(1) - A_curr(1));
    deg_AB_hist(k) = deg_AB;
	
	% previous distance S1
    S1 = sqrt((B_prev(1) - A_prev(1))^2 + (B_prev(2) - A_prev(2))^2); 
    % current distance S2
    S2 = sqrt((B_curr(1)-A_curr(1))^2 + (B_curr(2)-A_curr(2))^2);
    
	S1_hist(k) = S1;
    S2_hist(k) = S2;
    
    % theta2 = old predator heading - current AB direction
    theta2 = deg_AC - deg_AB;
    theta2_hist(k) = theta2;
    
    % theta1 uses previous updated value
    theta1 = theta1_prev;
    theta1_hist(k) = theta1;
    
    % -------------------------------------------------------------
    % Step B: normalize 4 inputs
    % -------------------------------------------------------------
    x1 = S1 / 10;
    x2 = S2 / 10;
    x3 = (theta1 + 60) / 120;
    x4 = (theta2 + 100) / 200;
    
    % optional clamp to [0,1]
    x1 = max(0, min(1, x1));
    x2 = max(0, min(1, x2));
    x3 = max(0, min(1, x3));
    x4 = max(0, min(1, x4));
    
    x_in_hist(k,:) = [x1, x2, x3, x4];
    
    % -------------------------------------------------------------
    % Step C: circuit-level SNN inference
    % -------------------------------------------------------------
    [output_norm_this, spike_count] = run_sim_crossbar_infer_norm_mc(x1, x2, x3, x4, pulse_width, vth);
    
    output_hist(k) = output_norm_this;
    spike_hist(k)  = spike_count;
    
    % predicted CAB in degree
    CAB_pred = output_norm_this * 120 - 60;
    
    % -------------------------------------------------------------
    % Step D: update predator heading and position
    % deg_AC = deg_AB + CAB_pred
    % -------------------------------------------------------------
    deg_AC = deg_AB + CAB_pred;
    deg_AC_hist(k) = deg_AC;
    
    % update theta1 for next step
    theta1_prev = deg_AC - deg_AB;
    
    % -------------------------------------------------------------
    % Step E: check capture condition
    % -------------------------------------------------------------
    curr_dist = S2;
    dist_hist(k) = curr_dist;
    
    msg = sprintf('Step %2d | S1=%.4f S2=%.4f | theta1=%.4f theta2=%.4f | out=%.4f | spike=%d | dist=%.4f\n', ...
    k, S1, S2, theta1, theta2, output_norm_this, spike_count, curr_dist);

	fprintf('%s', msg);
	fprintf(fid_log, '%s', msg);
    
    if curr_dist <= catch_dist
        captured = true;
        capture_step = k;
        msg = sprintf('\nCaptured at step %d, distance = %.4f\n', k, curr_dist);
		fprintf('%s', msg);
		fprintf(fid_log, '%s', msg);
        break;
    end
end

%% ===================== 4) Trim valid data =====================
if captured
    last_idx = capture_step;
else
    last_idx = N;
end

Ax_valid = Ax(1:last_idx);
Ay_valid = Ay(1:last_idx);
Bx_valid = Bx(1:last_idx);
By_valid = By(1:last_idx);

deg_AC_hist = deg_AC_hist(1:last_idx);
deg_AB_hist = deg_AB_hist(1:last_idx);
theta1_hist = theta1_hist(1:last_idx);
theta2_hist = theta2_hist(1:last_idx);
S1_hist     = S1_hist(1:last_idx);
S2_hist     = S2_hist(1:last_idx);
x_in_hist   = x_in_hist(1:last_idx,:);
output_hist = output_hist(1:last_idx);
spike_hist  = spike_hist(1:last_idx);
dist_hist   = dist_hist(1:last_idx);

%% ===================== 5) Save results table =====================
T_result = table( ...
    (1:last_idx)', ...
    Ax_valid, Ay_valid, ...
    Bx_valid, By_valid, ...
    deg_AC_hist, deg_AB_hist, ...
    theta1_hist, theta2_hist, ...
    S1_hist, S2_hist, ...
    x_in_hist(:,1), x_in_hist(:,2), x_in_hist(:,3), x_in_hist(:,4), ...
    output_hist, spike_hist, dist_hist, ...
    'VariableNames', { ...
    'step', ...
    'pred_x', 'pred_y', ...
    'prey_x', 'prey_y', ...
    'deg_AC', 'deg_AB', ...
    'theta1', 'theta2', ...
    'S1', 'S2', ...
    'x1_norm', 'x2_norm', 'x3_norm', 'x4_norm', ...
    'output_norm', 'spike_count', 'distance'} ...
    );

writetable(T_result, 'closed_loop_result.csv');

fprintf(fid_log, '\nRun finished.\n');
fprintf(fid_log, 'captured = %d\n', captured);
fprintf(fid_log, 'last_idx = %d\n', last_idx);
fprintf(fid_log, 'Result table saved to closed_loop_result.csv\n');

fclose(fid_log);