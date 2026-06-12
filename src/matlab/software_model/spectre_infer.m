clc;
clear;
close all;

%% =========================================================
% Test one inference sample: input = [1 0 0 0]
%% =========================================================
x1 = 0.12;
x2 = 0;
x3 = 0;
x4 = 0;

fprintf('Running inference for input = [%.0f %.0f %.0f %.0f]\n', x1, x2, x3, x4);

%% =========================================================
% Run Spectre-based inference
%% =========================================================
[output_norm_this, spike_count] = run_spectre_crossbar_infer_norm(x1, x2, x3, x4);

fprintf('Returned output_norm = %.6f\n', output_norm_this);
fprintf('Returned spike_count = %d\n', spike_count);

%% =========================================================
% Read the generated .print file
%% =========================================================
print_file = fullfile(pwd, 'Neuron_v35_crossbar_test_run.print');

if ~isfile(print_file)
    error('Cannot find .print file: %s', print_file);
end

[res, name] = import_spectre_data_local(print_file);

time_s  = res(:,1);
time_ns = time_s * 1e9;

%% =========================================================
% Find interested signals
%% =========================================================
find_idx = @(s) find(strcmpi(name, s), 1);

idx_out1_1    = find_idx('v(out1_1)');
idx_out1_2    = find_idx('v(out1_2)');
idx_out1_3    = find_idx('v(out1_3)');
idx_out1_4    = find_idx('v(out1_4)');
idx_col_net6  = find_idx('v(Ncol2_6.net6)');
idx_out2_1    = find_idx('v(out2_6)');
idx_out3_net6 = find_idx('v(Nout3_1.net6)');
idx_out3_1    = find_idx('v(out3_1)');

%% =========================================================
% Plot
%% =========================================================
figure;

subplot(4,1,1);
hold on;
if ~isempty(idx_out1_1), plot(time_ns, res(:,idx_out1_1), 'LineWidth', 1.2); end
if ~isempty(idx_out1_2), plot(time_ns, res(:,idx_out1_2), 'LineWidth', 1.2); end
if ~isempty(idx_out1_3), plot(time_ns, res(:,idx_out1_3), 'LineWidth', 1.2); end
if ~isempty(idx_out1_4), plot(time_ns, res(:,idx_out1_4), 'LineWidth', 1.2); end
xlabel('Time (ns)');
ylabel('Voltage (V)');
title('Input-layer neuron outputs');
grid on;
legend({'out1\_1','out1\_2','out1\_3','out1\_4'}, 'Location', 'best');

subplot(4,1,2);
hold on;
if ~isempty(idx_col_net6)
    plot(time_ns, res(:,idx_col_net6), 'LineWidth', 1.5);
end
if ~isempty(idx_out2_1)
    plot(time_ns, res(:,idx_out2_1), 'LineWidth', 1.5);
end
xlabel('Time (ns)');
ylabel('Voltage (V)');
title('Hidden-layer neuron #1');
grid on;
legend({'Ncol2\_1.net6','out2\_1'}, 'Location', 'best');

subplot(4,1,3);
if ~isempty(idx_out3_net6)
    plot(time_ns, res(:,idx_out3_net6), 'LineWidth', 1.5);
end
xlabel('Time (ns)');
ylabel('Voltage (V)');
title('Output neuron membrane node: Nout3\_1.net6');
grid on;

subplot(4,1,4);
if ~isempty(idx_out3_1)
    plot(time_ns, res(:,idx_out3_1), 'LineWidth', 1.5);
end
xlabel('Time (ns)');
ylabel('Voltage (V)');
title(sprintf('Final output: out3_1, spike count = %d, norm = %.4f', spike_count, output_norm_this));
grid on;

fprintf('Done. Waveforms loaded from:\n%s\n', print_file);

%% =========================================================
% Local function: import Spectre .print
%% =========================================================
function [res, name] = import_spectre_data_local(file)

fid = fopen(file,'r');
assert(fid > 0, 'Cannot open file: %s', file);
C = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);

L  = C{1};
nL = numel(L);

anchor = 1;
for i = 1:nL
    li = strtrim(L{i});
    if strcmp(li, 'y')
        anchor(end+1) = i; %#ok<AGROW>
    end
end
anchor = sort(unique(anchor));

res  = [];
name = {};

for a = 1:numel(anchor)
    i0 = anchor(a);

    ix = i0 + find_next_line_local(L, i0, 'x');
    if isempty(ix)
        ix = i0;
    end

    ih = find_header_local(L, ix);
    if isempty(ih)
        ih = find_header_local(L, i0);
    end
    if isempty(ih)
        continue;
    end

    [block, header] = parse_block_local(L, ih);

    if isempty(block)
        continue;
    end

    if isempty(res)
        res  = block;
        name = header;
    else
        t0 = res(:,1);
        t1 = block(:,1);

        if numel(t0) == numel(t1) && all(abs(t0-t1) <= max(1e-18, 1e-12*max(1,max(abs(t0)))))
            res  = [res, block(:,2:end)]; %#ok<AGROW>
            name = [name, header(2:end)]; %#ok<AGROW>
        else
            [~, ia, ib] = intersect(t0, t1);
            res  = [res(ia,:), block(ib,2:end)];
            name = [name, header(2:end)];
        end
    end
end

if isempty(res)
    error('No valid data block found in %s.', file);
end
end

function off = find_next_line_local(L, i0, key)
off = [];
for i = i0+1:numel(L)
    li = strtrim(L{i});
    if strcmp(li, key)
        off = i - i0;
        return;
    end
end
end

function ih = find_header_local(L, i0)
ih = [];
for i = i0+1:numel(L)
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

function [block, header] = parse_block_local(L, ih)
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

N = numel(rows);
block = nan(N, K);

for r = 1:N
    block(r,1:K) = parse_row_local(rows{r}, K);
end

goodCol = any(~isnan(block),1);
block   = block(:,goodCol);
header  = header(goodCol);

[block(:,1), ord] = sort(block(:,1));
block = block(ord,:);
[~, iu] = unique(block(:,1), 'stable');
block = block(iu,:);
end

function vals = parse_row_local(line, K)
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
    if isKey(scale, u)
        s = scale(u);
    end
    vals(c) = v * s;
end
end