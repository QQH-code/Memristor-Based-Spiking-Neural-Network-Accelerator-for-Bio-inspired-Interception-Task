function out = simulate_IF_neuron(time_s, Vin_mat, Rin_vec, cfg)
% =========================================================
% Network-ready IF neuron model
%
% Membrane update:
%   Iin(t) = sum_j (Vin_j(t) - Vrest) / Rin_j
%   dVmem  = -(1/C) * Iin(t) * dt
%
% Behavior:
%   - Resting membrane voltage: Vrest
%   - Fire when Vmem <= Vth
%   - Spike starts at threshold crossing time
%   - Reset duration = reset_time
%   - Output spike width = reset_time
%   - During reset, Vmem ramps linearly from Vth to Vrest
%
% Inputs:
%   time_s  : Nx1 time vector (s)
%   Vin_mat : NxM input voltage matrix
%   Rin_vec : 1xM or Mx1 input resistance vector (Ohm)
%   cfg     : struct
%             .C
%             .Vrest
%             .Vth
%             .reset_time
%             .Vout_hi
%             .Vout_lo
%
% Output:
%   out.time_s
%   out.Vin_mat
%   out.Iin
%   out.Vmem
%   out.Vout
%   out.spike
%   out.spike_times
% =========================================================

    % -------------------------
    % Default parameters
    % -------------------------
    if nargin < 4
        cfg = struct();
    end
    if ~isfield(cfg, 'C'),          cfg.C = 1e-12;      end
    if ~isfield(cfg, 'Vrest'),      cfg.Vrest = 0.9;    end
    if ~isfield(cfg, 'Vth'),        cfg.Vth = 0.71;     end
    if ~isfield(cfg, 'reset_time'), cfg.reset_time = 60e-9; end
    if ~isfield(cfg, 'Vout_hi'),    cfg.Vout_hi = 0.95; end
    if ~isfield(cfg, 'Vout_lo'),    cfg.Vout_lo = 0.9;  end

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
    % Preallocate
    % -------------------------
    Vmem = cfg.Vrest * ones(N,1);
    Vout = cfg.Vout_lo * ones(N,1);
    spike = zeros(N,1);
    Iin = zeros(N,1);

    reset_until_time = -inf;
    reset_start_time = -inf;
    spike_times = [];

    % -------------------------
    % Main loop
    % -------------------------
    for k = 2:N
        t_prev = time_s(k-1);
        t_now  = time_s(k);
        dt_k   = t_now - t_prev;

        % During reset: Vmem ramps linearly from Vth to Vrest
        if t_prev < reset_until_time
            alpha = (t_now - reset_start_time) / cfg.reset_time;
            alpha = min(max(alpha, 0), 1);

            Vmem(k) = cfg.Vth + alpha * (cfg.Vrest - cfg.Vth);
            Vout(k) = cfg.Vout_hi;
            spike(k) = 1;
            continue;
        end

        % Sum current from all input branches
        Iin_k = sum((Vin_mat(k-1,:) - 0.9) ./ Rin_vec);
        Iin(k) = Iin_k;

        % Membrane integration
        dV = -(1 / cfg.C) * Iin_k * dt_k;
        Vmem(k) = Vmem(k-1) + dV;

        % Threshold crossing
        if Vmem(k) <= cfg.Vth
            spike_times(end+1,1) = t_now; %#ok<AGROW>

            reset_start_time = t_now;
            reset_until_time = t_now + cfg.reset_time;

            Vmem(k) = cfg.Vth;
            Vout(k) = cfg.Vout_hi;
            spike(k) = 1;
        else
            Vout(k) = cfg.Vout_lo;
            spike(k) = 0;
        end
    end

    % -------------------------
    % Post-process reset window
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
end
