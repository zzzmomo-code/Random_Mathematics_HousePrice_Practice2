function generate_concise_report_figures()
% GENERATE_CONCISE_REPORT_FIGURES
% Export 4 clean, classroom-terminology, pure-white 300-DPI PNG figures
% for the concise Practice 2 report (in-course regression + Batch GD + Top-3).

clearvars; clc; close all;
rng(42, 'twister');

root_dir  = 'E:\Random_Mathematics_Project_HousePrice';
data_csv  = fullfile(root_dir, '01_Data', '聚合数据用于学习训练', '数据样本.csv');
model_dir = fullfile(root_dir, '02_MATLAB_Modeling');
fig_dir   = fullfile(root_dir, '03_Figures');
res_json  = fullfile(model_dir, 'results_summary.json');

addpath(model_dir);
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

opts = detectImportOptions(data_csv, 'Encoding', 'UTF-8');
opts.VariableNamingRule = 'preserve';
T = readtable(data_csv, opts);

feature_names = {'OverallQual', 'GrLivArea', 'GarageCars', 'TotalBsmtSF', ...
                 'YearBuilt', 'FullBath', 'BedroomAbvGr', 'LotArea'};
feature_cn    = {'综合质量', '地上居住面积', '车库容量', '地下室面积', ...
                 '建造年份', '全卫生间数', '地上卧室数', '地块面积'};
target_name   = 'SalePrice';
p = numel(feature_names);

X = T{:, feature_names};
y = T{:, target_name};
N = size(X, 1);

% Load authoritative JSON results (for CV / feature importance numbers)
res_txt = fileread(res_json);
res = jsondecode(res_txt);
m_map = containers.Map();
for i = 1:numel(res.models)
    if iscell(res.models)
        item = res.models{i};
    else
        item = res.models(i);
    end
    m_map(item.id) = item;
end
rec_lin1 = m_map('T1_Single_Linear');
rec_quad1 = m_map('T1_Single_Parabolic');
rec_ols = m_map('T2_OLS_fitlm');

% Reproduce exact 80/20 split (rng(42, 'twister') matches main script)
cv_hold = cvpartition(N, 'HoldOut', 0.20);
idx_tr = training(cv_hold);
idx_te = test(cv_hold);
X_tr = X(idx_tr, :); y_tr = y(idx_tr);
X_te = X(idx_te, :); y_te = y(idx_te);

% Extract Top-1 single feature (GrLivArea) and fit poly1/poly2 + OLS + GD
top1_idx = 2; % GrLivArea
x1_tr = X_tr(:, top1_idx);
x1_te = X_te(:, top1_idx);
mdl_poly1 = fitlm(x1_tr, y_tr, 'poly1');
mdl_poly2 = fitlm(x1_tr, y_tr, 'poly2');

mdl_ols = fitlm(X_tr, y_tr);
pred_ols_tr = predict(mdl_ols, X_tr);
pred_ols_te = predict(mdl_ols, X_te);

X_tr_aug = [ones(size(X_tr, 1), 1), X_tr];
beta_ne = (X_tr_aug' * X_tr_aug) \ (X_tr_aug' * y_tr);
ne_train_mse = mean((X_tr_aug * beta_ne - y_tr).^2);

gd = fit_ols_gd(X_tr, y_tr, 0.05, 2500, 1e-11);

% Styling setup
font_name = 'Microsoft YaHei';
c_navy    = [0.106, 0.310, 0.447];
c_crimson = [0.753, 0.224, 0.169];
c_amber   = [0.851, 0.447, 0.000];
c_teal    = [0.086, 0.569, 0.478];
c_slate   = [0.520, 0.575, 0.605];
c_axis    = [0.10,  0.10,  0.10];

set(0, 'DefaultFigureVisible', 'off');
set(0, 'DefaultLegendTextColor', c_axis);

%% ========================================================================
%  FIG 1: Concise EDA (Correlation Heatmap + SalePrice Histogram)
%% ========================================================================
f1 = figure('Units', 'inches', 'Position', [0.5, 0.5, 11.4, 4.6], 'Color', 'w');
tl1 = tiledlayout(f1, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Panel (a)
ax1 = nexttile(tl1, 1);
eda_vars = [feature_names, {target_name}];
R = corr([X, y]);
n_vars = size(R, 1);
imagesc(ax1, R, [-1, 1]);
axis(ax1, 'square');

n_half = 128;
r_neg = [linspace(0.12, 1.0, n_half)', linspace(0.32, 1.0, n_half)', linspace(0.62, 1.0, n_half)'];
r_pos = [linspace(1.0, 0.76, n_half)', linspace(1.0, 0.18, n_half)', linspace(1.0, 0.16, n_half)'];
colormap(ax1, [r_neg; r_pos]);

cb = colorbar(ax1);
cb.Label.String = '相关系数 r';
cb.Label.FontName = font_name;
cb.Label.FontSize = 9.5;
cb.Color = c_axis;

xticks(ax1, 1:n_vars); yticks(ax1, 1:n_vars);
xticklabels(ax1, eda_vars); yticklabels(ax1, eda_vars);
xtickangle(ax1, 35);
set(ax1, 'FontName', font_name, 'FontSize', 8.5, 'XColor', c_axis, 'YColor', c_axis, ...
    'TickLength', [0 0], 'LineWidth', 1.0, 'Box', 'on');

hold(ax1, 'on');
for i = 0.5:(n_vars + 0.5)
    plot(ax1, [0.5, n_vars + 0.5], [i, i], 'Color', [0.82 0.82 0.82], 'LineWidth', 0.5);
    plot(ax1, [i, i], [0.5, n_vars + 0.5], 'Color', [0.82 0.82 0.82], 'LineWidth', 0.5);
end
for r_i = 1:n_vars
    for c_i = 1:n_vars
        val = R(r_i, c_i);
        if abs(val) >= 0.52
            txt_c = [1 1 1]; fw = 'bold';
        else
            txt_c = [0.12 0.12 0.12]; fw = 'normal';
        end
        text(ax1, c_i, r_i, sprintf('%.2f', val), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontName', font_name, 'FontSize', 7.6, 'Color', txt_c, 'FontWeight', fw);
    end
end
title(ax1, '(a) 8 个特征与房价的相关系数矩阵', ...
    'FontName', font_name, 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', c_axis);

% Panel (b)
ax2 = nexttile(tl1, 2);
yk = y / 1e3;
histogram(ax2, yk, 16, 'Normalization', 'pdf', ...
    'FaceColor', c_navy, 'FaceAlpha', 0.32, 'EdgeColor', c_navy, 'LineWidth', 0.9);
hold(ax2, 'on');
mu_y = mean(yk); sd_y = std(yk, 0);
x_norm = linspace(min(yk) - 20, max(yk) + 20, 200);
h_norm = plot(ax2, x_norm, normpdf(x_norm, mu_y, sd_y), '--', 'Color', c_crimson, 'LineWidth', 2.0);
h_mean = xline(ax2, mu_y, '-', 'Color', c_teal, 'LineWidth', 1.8);

grid(ax2, 'on'); ax2.GridAlpha = 0.22;
set(ax2, 'FontName', font_name, 'FontSize', 9.0, 'Color', 'w', ...
    'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax2, '房屋销售价格 SalePrice (千美元, $k)', 'FontName', font_name, 'FontSize', 9.8);
ylabel(ax2, '频率密度', 'FontName', font_name, 'FontSize', 9.8);
title(ax2, '(b) 房价 SalePrice 分布直方图', ...
    'FontName', font_name, 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', c_axis);
yl2 = ylim(ax2);
ylim(ax2, [0, yl2(2) * 1.24]);
xlim(ax2, [55, 465]);

legend(ax2, [h_norm, h_mean], ...
    {'正态分布参考曲线', sprintf('样本均值 = $%.1fk', mu_y)}, ...
    'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.4, ...
    'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

stats_str = sprintf('样本数 N = %d\n均值 = $%.1fk\n标准差 = $%.1fk\n范围 = [$%.1fk, $%.1fk]', ...
    numel(yk), mu_y, sd_y, min(yk), max(yk));
text(ax2, 0.97, 0.95, stats_str, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontName', font_name, 'FontSize', 8.3, 'Color', c_axis, ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 5);

exportgraphics(f1, fullfile(fig_dir, 'fig1_concise_eda.png'), 'Resolution', 300, 'BackgroundColor', 'white');
close(f1);

%% ========================================================================
%  FIG 2: Concise Single Feature Line vs Parabola
%% ========================================================================
f2 = figure('Units', 'inches', 'Position', [0.5, 0.5, 11.4, 4.6], 'Color', 'w');
tl2 = tiledlayout(f2, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

x_grid = linspace(min([x1_tr; x1_te]) - 50, max([x1_tr; x1_te]) + 50, 250)';
[yhat1, yci1] = predict(mdl_poly1, x_grid, 'Prediction', 'curve');
[yhat2, ~]    = predict(mdl_poly2, x_grid, 'Prediction', 'curve');

ax1 = nexttile(tl2, 1);
hold(ax1, 'on');
fill(ax1, [x_grid; flipud(x_grid)], [yci1(:,1); flipud(yci1(:,2))]/1e3, ...
    c_navy, 'FaceAlpha', 0.14, 'EdgeColor', 'none', 'DisplayName', '一次直线 95% 置信带');
scatter(ax1, x1_tr, y_tr/1e3, 24, c_navy, 'o', 'filled', 'MarkerFaceAlpha', 0.45, 'DisplayName', '训练集 (N=240)');
scatter(ax1, x1_te, y_te/1e3, 34, c_amber, '^', 'filled', 'MarkerEdgeColor', [0.4 0.2 0], 'LineWidth', 0.5, 'DisplayName', '测试集 (N=60)');
plot(ax1, x_grid, yhat1/1e3, '-', 'Color', c_navy, 'LineWidth', 2.3, 'DisplayName', '一次直线拟合');
plot(ax1, x_grid, yhat2/1e3, '--', 'Color', c_crimson, 'LineWidth', 2.3, 'DisplayName', '二次抛物线拟合');

grid(ax1, 'on'); ax1.GridAlpha = 0.22;
set(ax1, 'FontName', font_name, 'FontSize', 9.0, 'Color', 'w', 'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax1, '地上居住面积 GrLivArea (平方英尺)', 'FontName', font_name, 'FontSize', 9.8);
ylabel(ax1, '房屋销售价格 SalePrice (千美元, $k)', 'FontName', font_name, 'FontSize', 9.8);
title(ax1, '(a) 单特征 GrLivArea 一次直线与二次抛物线拟合', ...
    'FontName', font_name, 'FontSize', 10.3, 'FontWeight', 'bold', 'Color', c_axis);
ylim(ax1, [50, 480]); xlim(ax1, [400, 4150]);
legend(ax1, 'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.2, 'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

fit_box = sprintf('直线: 测试 R^2=%.3f, RMSE=$%.1fk\n抛物线: 测试 R^2=%.3f, RMSE=$%.1fk', ...
    rec_lin1.test.r2, rec_lin1.test.rmse/1e3, rec_quad1.test.r2, rec_quad1.test.rmse/1e3);
text(ax1, 0.97, 0.04, fit_box, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontName', font_name, 'FontSize', 8.1, 'Color', c_axis, 'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 5);

ax2 = nexttile(tl2, 2);
hold(ax2, 'on');
res1_tr = (y_tr - predict(mdl_poly1, x1_tr)) / 1e3;
res1_te = (y_te - predict(mdl_poly1, x1_te)) / 1e3;
scatter(ax2, x1_tr, res1_tr, 24, c_navy, 'o', 'filled', 'MarkerFaceAlpha', 0.45, 'DisplayName', '训练集残差');
scatter(ax2, x1_te, res1_te, 34, c_amber, '^', 'filled', 'MarkerEdgeColor', [0.4 0.2 0], 'LineWidth', 0.5, 'DisplayName', '测试集残差');
yline(ax2, 0, '-', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.3, 'HandleVisibility', 'off');
plot(ax2, x_grid, (yhat2 - yhat1)/1e3, '--', 'Color', c_crimson, 'LineWidth', 2.2, 'DisplayName', '抛物线与直线差值');

grid(ax2, 'on'); ax2.GridAlpha = 0.22;
set(ax2, 'FontName', font_name, 'FontSize', 9.0, 'Color', 'w', 'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax2, '地上居住面积 GrLivArea (平方英尺)', 'FontName', font_name, 'FontSize', 9.8);
ylabel(ax2, '拟合残差 (千美元, $k)', 'FontName', font_name, 'FontSize', 9.8);
title(ax2, '(b) 单特征一次拟合残差分布', ...
    'FontName', font_name, 'FontSize', 10.3, 'FontWeight', 'bold', 'Color', c_axis);
xlim(ax2, [400, 4150]);
ylim(ax2, [-140, 195]);
legend(ax2, 'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.2, 'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

exportgraphics(f2, fullfile(fig_dir, 'fig2_concise_line_vs_parabola.png'), 'Resolution', 300, 'BackgroundColor', 'white');
close(f2);

%% ========================================================================
%  FIG 3: Multivariate OLS Fit + Manual Batch Gradient Descent Convergence
%% ========================================================================
f3 = figure('Units', 'inches', 'Position', [0.5, 0.5, 11.4, 4.6], 'Color', 'w');
tl3 = tiledlayout(f3, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Panel (a): Predicted vs Actual SalePrice
ax1 = nexttile(tl3, 1);
hold(ax1, 'on');
ytr_k = y_tr/1e3; ptr_k = pred_ols_tr/1e3;
yte_k = y_te/1e3; pte_k = pred_ols_te/1e3;
min_v = min([ytr_k; yte_k; ptr_k; pte_k]) - 15;
max_v = max([ytr_k; yte_k; ptr_k; pte_k]) + 15;

plot(ax1, [min_v, max_v], [min_v, max_v], '--', 'Color', c_crimson, 'LineWidth', 1.9, 'DisplayName', '理想参考线 y = x');
scatter(ax1, ytr_k, ptr_k, 22, c_navy, 'o', 'filled', 'MarkerFaceAlpha', 0.48, 'DisplayName', '训练集 (N=240)');
scatter(ax1, yte_k, pte_k, 38, c_amber, 'd', 'filled', 'MarkerEdgeColor', [0.35 0.15 0], 'LineWidth', 0.6, 'DisplayName', '测试集 (N=60)');

grid(ax1, 'on'); ax1.GridAlpha = 0.22;
axis(ax1, 'square');
xlim(ax1, [min_v, max_v]); ylim(ax1, [min_v, max_v]);
set(ax1, 'FontName', font_name, 'FontSize', 9.0, 'Color', 'w', 'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax1, '实际房价 SalePrice ($k)', 'FontName', font_name, 'FontSize', 9.8);
ylabel(ax1, '预测房价 Predicted ($k)', 'FontName', font_name, 'FontSize', 9.8);
title(ax1, '(a) 多元线性回归：预测房价与真实房价对比', ...
    'FontName', font_name, 'FontSize', 10.3, 'FontWeight', 'bold', 'Color', c_axis);
legend(ax1, 'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.2, 'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

ols_box = sprintf('5折交叉验证 RMSE = $%.2fk (R^2=%.3f)\n测试集 RMSE = $%.2fk (R^2=%.3f)', ...
    rec_ols.cv_rmse_mean/1e3, rec_ols.cv_r2_mean, rec_ols.test.rmse/1e3, rec_ols.test.r2);
text(ax1, 0.96, 0.04, ols_box, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontName', font_name, 'FontSize', 8.1, 'Color', c_axis, 'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 4.5);

% Panel (b): Batch GD MSE Convergence
ax2 = nexttile(tl3, 2);
n_show = min(250, gd.iterations);
iters = (1:n_show)';
semilogy(ax2, iters, gd.mse_history(1:n_show)/1e8, '-', 'Color', c_navy, 'LineWidth', 2.3, ...
    'DisplayName', '手动梯度下降均方误差');
hold(ax2, 'on');
yline(ax2, ne_train_mse/1e8, '--', 'Color', c_crimson, 'LineWidth', 1.8, ...
    'DisplayName', sprintf('正规方程解析解 MSE = %.3f\\times10^8', ne_train_mse/1e8));

grid(ax2, 'on'); ax2.GridAlpha = 0.25;
set(ax2, 'FontName', font_name, 'FontSize', 9.0, 'Color', 'w', 'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax2, '迭代次数（展示前 250 步）', 'FontName', font_name, 'FontSize', 9.8);
ylabel(ax2, '训练集均方误差 MSE (10^8 美元^2)', 'FontName', font_name, 'FontSize', 9.8);
title(ax2, '(b) 梯度下降法均方误差收敛曲线', ...
    'FontName', font_name, 'FontSize', 10.3, 'FontWeight', 'bold', 'Color', c_axis);
xlim(ax2, [1, n_show]);
legend(ax2, 'Location', 'northeast', 'FontName', font_name, 'FontSize', 8.2, 'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

gd_box = sprintf('学习率 \\alpha = 0.05\n约 120 步收敛（共 %d 步）\n与正规方程预测最大差 %.2e', ...
    gd.iterations, res.ols_equivalence_check.max_test_pred_diff_NE_vs_GD);
text(ax2, 0.96, 0.62, gd_box, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontName', font_name, 'FontSize', 8.1, 'Color', c_axis, 'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 5);

exportgraphics(f3, fullfile(fig_dir, 'fig3_ols_fit_and_gd.png'), 'Resolution', 300, 'BackgroundColor', 'white');
close(f3);

%% ========================================================================
%  FIG 4: Two In-Course Feature Importance Methods (Top 3 Highlighted)
%% ========================================================================
ranked = res.feature_importance.ranked_table;
n_f = numel(ranked);
lbls = cell(n_f, 1);
std_vals = zeros(n_f, 1);
drop_vals = zeros(n_f, 1);
is_top3 = false(n_f, 1);

for i = 1:n_f
    if iscell(ranked)
        rk_i = ranked{i};
    else
        rk_i = ranked(i);
    end
    lbls{i} = sprintf('%s (%s)', rk_i.feature, rk_i.feature_cn);
    std_vals(i) = rk_i.ols_std_abs_beta / 1e3;
    drop_vals(i) = rk_i.delta_cv_rmse / 1e3;
    is_top3(i) = (rk_i.consensus_rank <= 3);
end

f4 = figure('Units', 'inches', 'Position', [0.5, 0.5, 11.4, 4.6], 'Color', 'w');
tl4 = tiledlayout(f4, 1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

specs = {
    struct('vals', std_vals, 'title', '(a) 方法 1：标准化回归系数 |\beta_j^*|', ...
           'xlabel', '每增加 1 个标准差引起的房价变化 ($k)', 'is_delta', false), ...
    struct('vals', drop_vals, 'title', '(b) 方法 2：去掉单个特征后的误差增幅', ...
           'xlabel', '去掉该特征后 5 折交叉验证 RMSE 增幅 ($k)', 'is_delta', true)
};

for pi = 1:2
    ax = nexttile(tl4, pi);
    sp = specs{pi};
    b_h = barh(ax, 1:n_f, sp.vals, 0.64, 'FaceColor', 'flat', 'EdgeColor', 'none');
    for k = 1:n_f
        if is_top3(k)
            b_h.CData(k, :) = c_crimson;
        else
            b_h.CData(k, :) = c_slate;
        end
    end
    set(ax, 'YDir', 'reverse');
    yticks(ax, 1:n_f);
    yticklabels(ax, lbls);

    max_v = max(sp.vals);
    min_v = min(0, min(sp.vals));
    xlim(ax, [min_v - max_v * 0.03, max_v * 1.28]);

    hold(ax, 'on');
    xline(ax, 0, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.8);
    for k = 1:n_f
        v = sp.vals(k);
        if sp.is_delta
            if v >= 0
                lstr = sprintf('+$%.2fk', v);
            else
                lstr = sprintf('-$%.2fk', abs(v));
            end
        else
            lstr = sprintf('$%.2fk', v);
        end
        if is_top3(k)
            tc = c_crimson; fw = 'bold';
        else
            tc = [0.25 0.25 0.25]; fw = 'normal';
        end
        text(ax, max(v, 0) + max_v * 0.02, k, lstr, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
            'FontName', font_name, 'FontSize', 8.2, 'Color', tc, 'FontWeight', fw);
    end

    grid(ax, 'on'); ax.GridAlpha = 0.22;
    set(ax, 'FontName', font_name, 'FontSize', 8.6, 'Color', 'w', ...
        'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
    xlabel(ax, sp.xlabel, 'FontName', font_name, 'FontSize', 9.2);
    title(ax, sp.title, 'FontName', font_name, 'FontSize', 10.3, 'FontWeight', 'bold', 'Color', c_axis);
end

exportgraphics(f4, fullfile(fig_dir, 'fig4_feature_importance_top3.png'), 'Resolution', 300, 'BackgroundColor', 'white');
close(f4);

set(0, 'DefaultFigureVisible', 'on');
fprintf('[OK] Exported 4 concise figures cleanly.\n');
end
