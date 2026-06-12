% =========================================================================
% Script: compare_two_print_membrane_shift_to_0p9.m
% Purpose:
%   Read two Spectre .print files, extract membrane voltage waveform,
%   shift each waveform so that its initial point becomes 0.9 V,
%   and plot them together.
% =========================================================================

clear; clc; close all;

%% =========================
% User settings
%% =========================
file1 = 'test_4pre_1post_4pre_1post_1.print';   % with nfet
file2 = 'test_4pre_1post_4pre_1post_2.print';   % without nfet

target_mem_name = 'v(NPOST.net6)';   % postsynaptic membrane node
target_start_v  = 0.9;               % shift initial point to 0.9 V

%% =========================
% Read print files
%% =========================
[res1, name1] = import_spectre_data(file1);
[res2, name2] = import_spectre_data(file2);

time1_s  = res1(:,1);
time2_s  = res2(:,1);
time1_ns = time1_s * 1e9;
time2_ns = time2_s * 1e9;

%% =========================
% Find membrane waveform
%% =========================
idx_mem1 = find(strcmpi(name1, target_mem_name), 1);
idx_mem2 = find(strcmpi(name2, target_mem_name), 1);

if isempty(idx_mem1)
    error('Cannot find %s in %s', target_mem_name, file1);
end
if isempty(idx_mem2)
    error('Cannot find %s in %s', target_mem_name, file2);
end

v_mem1 = res1(:, idx_mem1);
v_mem2 = res2(:, idx_mem2);

%% =========================
% Shift initial point to 0.9 V
%% =========================
v_mem1_shift = v_mem1 - v_mem1(1) + target_start_v;
v_mem2_shift = v_mem2 - v_mem2(1) + target_start_v;

fprintf('File 1 initial membrane voltage = %.6f V, shifted by %.6f V\n', ...
    v_mem1(1), target_start_v - v_mem1(1));
fprintf('File 2 initial membrane voltage = %.6f V, shifted by %.6f V\n', ...
    v_mem2(1), target_start_v - v_mem2(1));

%% =========================
% Plot
%% =========================
figure('Color','w');
plot(time1_ns, v_mem1_shift, 'LineWidth', 1.5); hold on;
plot(time2_ns, v_mem2_shift, 'LineWidth', 1.5);
grid on;
box on;

xlabel('Time (ns)');
ylabel('Membrane Voltage (V)');
title('Shifted Membrane Voltage Comparison');
legend('with nfet', 'without nfet', 'Location', 'best');

%% =========================================================================
% Functions
%% =========================================================================
function [res, name] = import_spectre_data(file)
fid = fopen(file,'r');
assert(fid > 0, 'Cannot open file: %s', file);

C = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);

L = C{1};
nL = numel(L);

anchor = 1;
for i = 1:nL
    li = strtrim(L{i});
    if strcmp(li, 'y')
        anchor(end+1) = i; %#ok<AGROW>
    end
end
anchor = sort(unique(anchor));

res = [];
name = {};

for a = 1:numel(anchor)
    i0 = anchor(a);
    ix = i0 + find_next_line(L, i0, 'x');
    if isempty(ix)
        ix = i0;
    end

    ih = find_header(L, ix);
    if isempty(ih)
        ih = find_header(L, i0);
    end
    if isempty(ih)
        continue;
    end

    [block, header, ~] = parse_block(L, ih);
    if isempty(block)
        continue;
    end

    if isempty(res)
        res = block;
        name = header;
    else
        t0 = res(:,1);
        t1 = block(:,1);

        if numel(t0) == numel(t1) && ...
           all(abs(t0 - t1) <= max(1e-18, 1e-12 * max(1, max(abs(t0)))))
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
for i = i0+1:numel(L)
    li = strtrim(L{i});
    if strcmp(li, key)
        off = i - i0;
        return;
    end
end
end

function ih = find_header(L, i0)
ih = [];
for i = i0+1:numel(L)
    li = strtrim(L{i});
    if isempty(li) || startsWith(li, '*') || startsWith(li, '******')
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
for i = ih+1:numel(L)
    li = strtrim(L{i});
    if isempty(li)
        break;
    end
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

goodCol = any(~isnan(block), 1);
block = block(:, goodCol);
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

tok = regexp(line, ...
    '([+\-]?\d*\.?\d+(?:[eE][+\-]?\d+)?)\s*([fpnumkKMGＴTG]?)', ...
    'tokens');

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
    if isKey(scale, u)
        s = scale(u);
    end

    vals(c) = v * s;
end
end