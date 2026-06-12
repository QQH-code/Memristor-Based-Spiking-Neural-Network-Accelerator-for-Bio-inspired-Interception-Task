function out = simulate_IF_neuron_v2(time_s, Vin_mat, Rin_vec, cfg)
% =========================================================
% Network-ready IF neuron model with post-pulse drift
%
% New behavior:
%   1) At Vrest, no slope drift is applied.
%   2) During input pulse, membrane is updated only by synaptic current.
%   3) After a pulse ends, use:
%        Rin -> R_delta_table -> |delta_v|
%        (mc_case_idx, |delta_v|) -> mc_slope_table -> slope
%      then start drift from current Vmem until:
%        - next input pulse arrives, or
%        - Vmem reaches Vrest
%
% Inputs:
%   time_s  : Nx1 time vector
%   Vin_mat : NxM input voltage matrix
%   Rin_vec : 1xM or Mx1 input resistance vector
%   cfg     : struct with fields
%       .C
%       .Vrest
%       .Vth
%       .reset_time
%       .Vout_hi
%       .Vout_lo
%       .mc_case_idx        : scalar case idx for this neuron
%       .mc_slope_table     : [case_idx, delta_v, slope]
%       .R_delta_table      : [R, delta_v]
%       .active_eps         : threshold to detect input pulse
%       .clamp_to_vrest     : true/false
%
% Output:
%   out.time_s
%   out.Vin_mat
%   out.Rin_vec
%   out.Iin
%   out.Vmem
%   out.Vout
%   out.spike
%   out.spike_times
%   out.drift_slope_trace
%   out.drift_active_trace
% =========================================================

    % -------------------------
    % Default parameters
    % -------------------------
    if nargin < 4
        cfg = struct();
    end
    if ~isfield(cfg, 'C'),               cfg.C = 1e-12;          end
    if ~isfield(cfg, 'Vrest'),           cfg.Vrest = 0.9;        end
    if ~isfield(cfg, 'Vth'),             cfg.Vth = 0.71;         end
    if ~isfield(cfg, 'reset_time'),      cfg.reset_time = 60e-9; end
    if ~isfield(cfg, 'Vout_hi'),         cfg.Vout_hi = 0.95;     end
    if ~isfield(cfg, 'Vout_lo'),         cfg.Vout_lo = 0.9;      end
    if ~isfield(cfg, 'active_eps'),      cfg.active_eps = 1e-12; end
    if ~isfield(cfg, 'clamp_to_vrest'),  cfg.clamp_to_vrest = true; end

    if ~isfield(cfg, 'mc_case_idx')
        error('cfg.mc_case_idx is required.');
    end
    if ~isfield(cfg, 'mc_slope_table')
        error('cfg.mc_slope_table is required. Format: [case_idx, delta_v, slope].');
    end
    if ~isfield(cfg, 'R_delta_table')
        error('cfg.R_delta_table is required. Format: [R, delta_v].');
    end

    % -------------------------
    % Shape check
    % -------------------------
    time_s = time_s(:);
    [N, M] = size(Vin_mat);
    Rin_vec = Rin_vec(:).';

    if numel(time_s) ~= N
        error('time_s length must match number of rows in Vin_mat.');
    end
    if numel(Rin_vec) ~= M
        error('Length of Rin_vec must match number of columns in Vin_mat.');
    end
    if any(Rin_vec <= 0)
        error('All Rin values must be positive.');
    end
    if N < 2
        error('time_s must contain at least 2 points.');
    end

    dt = diff(time_s);
    if any(dt <= 0)
        error('time_s must be strictly increasing.');
    end

    % -------------------------
    % Tables
    % -------------------------
    mc_slope_table = cfg.mc_slope_table;
    R_delta_table  = cfg.R_delta_table;

    if size(mc_slope_table,2) < 3
        error('cfg.mc_slope_table must have at least 3 columns: [case_idx, delta_v, slope].');
    end
    if size(R_delta_table,2) < 2
        error('cfg.R_delta_table must have at least 2 columns: [R, delta_v].');
    end

    % -------------------------
    % Preallocate
    % -------------------------
    Vmem = cfg.Vrest * ones(N,1);
    Vout = cfg.Vout_lo * ones(N,1);
    spike = zeros(N,1);
    Iin = zeros(N,1);

    drift_slope_trace  = zeros(N,1);
    drift_active_trace = zeros(N,1);

    reset_until_time = -inf;
    reset_start_time = -inf;
    spike_times = [];

    % Drift state
    drift_active = false;
    current_slope = 0;

    % For pulse-end detection
    active_prev = false(1,M);

    % -------------------------
    % Main loop
    % -------------------------
    for k = 2:N
        t_prev = time_s(k-1);
        t_now  = time_s(k);
        dt_k   = t_now - t_prev;

        Vin_prev = Vin_mat(k-1,:);
        Vin_now  = Vin_mat(k,:);

        active_now = abs(Vin_now - 0.9) > cfg.active_eps;

        % -----------------------------------
        % During reset
        % -----------------------------------
        if t_prev < reset_until_time
            alpha = (t_now - reset_start_time) / cfg.reset_time;
            alpha = min(max(alpha, 0), 1);

            Vmem(k) = cfg.Vth + alpha * (cfg.Vrest - cfg.Vth);
            Vout(k) = cfg.Vout_hi;
            spike(k) = 1;

            drift_active = false;
            current_slope = 0;
            active_prev = active_now;
            continue;
        end

        % -----------------------------------
        % If new pulse arrives, stop drift
        % -----------------------------------
        if any(active_now)
            drift_active = false;
            current_slope = 0;
        end

        % -----------------------------------
        % Synaptic current integration
        % only when input pulse is present
        % -----------------------------------
        if any(abs(Vin_prev - 0.9) > cfg.active_eps)
            Iin_k = sum((Vin_prev - 0.9) ./ Rin_vec);
            Iin(k) = Iin_k;

            dV = -(1 / cfg.C) * Iin_k * dt_k;
            Vmem(k) = Vmem(k-1) + dV;
        else
            Iin(k) = 0;

            % No input pulse: apply drift only if not at Vrest
            if drift_active && abs(Vmem(k-1) - cfg.Vrest) > cfg.active_eps
                Vmem_candidate = Vmem(k-1) + current_slope * dt_k;

                if cfg.clamp_to_vrest
                    % Prevent overshoot across Vrest
                    if (Vmem(k-1) < cfg.Vrest && Vmem_candidate > cfg.Vrest) || ...
                       (Vmem(k-1) > cfg.Vrest && Vmem_candidate < cfg.Vrest)
                        Vmem(k) = cfg.Vrest;
                        drift_active = false;
                        current_slope = 0;
                    else
                        Vmem(k) = Vmem_candidate;
                    end
                else
                    Vmem(k) = Vmem_candidate;
                end
            else
                Vmem(k) = Vmem(k-1);

                % At exact rest, no drift
                if abs(Vmem(k) - cfg.Vrest) <= cfg.active_eps
                    Vmem(k) = cfg.Vrest;
                    drift_active = false;
                    current_slope = 0;
                end
            end
        end

        % -----------------------------------
        % Detect pulse end:
        % previous step active -> current step inactive
        % Then start drift using Rin -> delta_v -> slope
        % -----------------------------------
        ended_mask = active_prev & (~active_now);
        if any(ended_mask)
            ended_idx = find(ended_mask, 1, 'first');  % use first ended branch
            R_this = Rin_vec(ended_idx);

            delta_v_abs = lookup_abs_delta_v_from_R(R_this, R_delta_table);
            slope_this  = lookup_slope_from_case_and_delta( ...
                            cfg.mc_case_idx, delta_v_abs, mc_slope_table);

            % Start drift only if neuron is not at rest
            if abs(Vmem(k) - cfg.Vrest) > cfg.active_eps
                drift_active = true;
                current_slope = slope_this;
            else
                drift_active = false;
                current_slope = 0;
            end
        end

        drift_slope_trace(k)  = current_slope;
        drift_active_trace(k) = drift_active;

        % -----------------------------------
        % Threshold crossing
        % -----------------------------------
        if Vmem(k) <= cfg.Vth
            spike_times(end+1,1) = t_now; %#ok<AGROW>

            reset_start_time = t_now;
            reset_until_time = t_now + cfg.reset_time;

            Vmem(k) = cfg.Vth;
            Vout(k) = cfg.Vout_hi;
            spike(k) = 1;

            drift_active = false;
            current_slope = 0;
        else
            Vout(k) = cfg.Vout_lo;
            spike(k) = 0;
        end

        active_prev = active_now;
    end

    % -------------------------
    % Post-process spike waveform
    % -------------------------
    for i = 1:numel(spike_times)
        t0 = spike_times(i);
        t1 = t0 + cfg.reset_time;
        idx = (time_s >= t0) & (time_s < t1);

        Vout(idx) = cfg.Vout_hi;
        spike(idx) = 1;

        alpha = (time_s(idx) - t0) / cfg.reset_time;
        alpha = min(max(alpha, 0), 1);
        Vmem(idx) = cfg.Vth + alpha .* (cfg.Vrest - cfg.Vth);

        drift_slope_trace(idx)  = 0;
        drift_active_trace(idx) = 0;
    end

    % -------------------------
    % Output
    % -------------------------
    out = struct();
    out.time_s = time_s;
    out.Vin_mat = Vin_mat;
    out.Rin_vec = Rin_vec;
    out.Iin = Iin;
    out.Vmem = Vmem;
    out.Vout = Vout;
    out.spike = spike;
    out.spike_times = spike_times;
    out.drift_slope_trace = drift_slope_trace;
    out.drift_active_trace = drift_active_trace;
end

% =========================================================
% Helper: lookup |delta_v| from R
% R_delta_table: [R, delta_v]
% =========================================================
function delta_v_abs = lookup_abs_delta_v_from_R(Rval, R_delta_table)
    R_col = R_delta_table(:,1);
    d_col = R_delta_table(:,2);

    [~, idx] = min(abs(R_col - Rval));
    delta_v_abs = abs(d_col(idx));
end

% =========================================================
% Helper: lookup slope from case_idx and |delta_v|
% mc_slope_table: [case_idx, delta_v, slope]
% =========================================================
function slope_val = lookup_slope_from_case_and_delta(case_idx, delta_v_abs, mc_slope_table)
    case_col  = mc_slope_table(:,1);
    delta_col = mc_slope_table(:,2);
    slope_col = mc_slope_table(:,3);

    rows_case = (case_col == case_idx);

    if ~any(rows_case)
        error('Cannot find case_idx=%d in mc_slope_table.', case_idx);
    end

    delta_case = delta_col(rows_case);
    slope_case = slope_col(rows_case);

    [~, idx_local] = min(abs(delta_case - delta_v_abs));
    slope_val = slope_case(idx_local);
end