% =========================================================================
% Script: compare_membrane_shifted.m
% Purpose:
%   Read two Spectre .print files:
%     1) proposed neuron_v35 design
%     2) baseline comparison design
%   Extract membrane-voltage waveforms, transform them from
%   "integrating upward from 0" to an equivalent waveform
%   "integrating downward from 0.92749", then plot together.
% =========================================================================

clear; clc; close all;

%% =========================
% User settings
%% =========================
print_proposed = 'plot_integration1_single_neuron.print';   % your proposed-design .print file
print_baseline = 'plot_integration2_single_neuron.print';   % your baseline-design .print file

V_start_eq = 0.92749;        % equivalent starting voltage

% optional display range (ns)
tmin_ns = 0;
tmax_ns = inf;

%% =========================
% Read print files
%% =========================
[res_p, name_p] = import_spectre_data(print_proposed);
[res_b, name_b] = import_spectre_data(print_baseline);

time_p_s  = res_p(:,1);
time_b_s  = res_b(:,1);
time_p_ns = time_p_s * 1e9;
time_b_ns = time_b_s * 1e9;

%% =========================
% Find membrane nodes
%% =========================
find_idx_p = @(s) find(strcmpi(name_p, s), 1);
find_idx_b = @(s) find(strcmpi(name_b, s), 1);

% Proposed design: membrane is v(N1.net6)
idx_mem_p = find_idx_p('v(N1.net6)');
if isempty(idx_mem_p)
    error('Cannot find membrane node v(N1.net6) in proposed print file.');
end

% Baseline design: membrane is v(in_node)
idx_mem_b = find_idx_b('v(in_node)');
if isempty(idx_mem_b)
    error('Cannot find membrane node v(in_node) in baseline print file.');
end

v_mem_p_up = res_p(:, idx_mem_p);
v_mem_b_up = res_b(:, idx_mem_b);

%% =========================
% Transform to equivalent downward integration
%% =========================
% upward from 0  --> downward from 0.92749
v_mem_p_eq = v_mem_p_up;
v_mem_b_eq = V_start_eq - v_mem_b_up;

%% =========================
% Apply time window
%% =========================
mask_p = (time_p_ns >= tmin_ns) & (time_p_ns <= tmax_ns);
mask_b = (time_b_ns >= tmin_ns) & (time_b_ns <= tmax_ns);

%% =========================
% Plot
%% =========================
figure('Position', [100, 100, 300, 280]);

c_blue  = [0.00, 0.20, 0.75];
c_red   = [0.85, 0.10, 0.10];

plot(time_p_ns(mask_p), v_mem_p_eq(mask_p), 'Color', c_blue, 'LineWidth', 1.6);
hold on;
plot(time_b_ns(mask_b), v_mem_b_eq(mask_b), 'Color', c_red, 'LineWidth', 1.6);
hold off;

xlabel('Time (ns)');
ylabel('Equivalent Membrane Voltage (V)');
legend('Proposed design', 'Baseline design', 'Location', 'best');
grid on;
box on;

%% =========================
% Optional: print final values
%% =========================
fprintf('Proposed design: initial upward membrane = %.6g V, equivalent start = %.6g V\n', ...
    v_mem_p_up(1), v_mem_p_eq(1));
fprintf('Baseline design: initial upward membrane = %.6g V, equivalent start = %.6g V\n', ...
    v_mem_b_up(1), v_mem_b_eq(1));

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