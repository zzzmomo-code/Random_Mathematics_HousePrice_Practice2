function fig_paths = generate_figures(pd)
% GENERATE_FIGURES Export 5 publication-grade 300-DPI PNG figures on pure white backgrounds.
%   All figures use Microsoft YaHei for clean Chinese + English typography,
%   high-contrast black axes, colorblind-friendly palette, and zero text overlap.

fig_dir = pd.fig_dir;
font_name = 'Microsoft YaHei';

% Colorblind-friendly academic palette
c_navy    = [0.106, 0.310, 0.447]; % #1B4F72
c_crimson = [0.753, 0.224, 0.169]; % #C0392B (Top-3 accent / parabolic)
c_amber   = [0.851, 0.447, 0.000]; % #D97200
c_teal    = [0.086, 0.569, 0.478]; % #16917A
c_slate   = [0.520, 0.575, 0.605]; % #85939A (non-Top-3)
c_light   = [0.780, 0.835, 0.875];
c_axis    = [0.10,  0.10,  0.10];

set(0, 'DefaultFigureVisible', 'off');
set(0, 'DefaultLegendTextColor', c_axis);

fig_paths = cell(5, 1);

%% ========================================================================
%  FIGURE 1: EDA Correlation Matrix Heatmap + SalePrice Distribution
%% ========================================================================
f1 = figure('Units', 'inches', 'Position', [0.5, 0.5, 12.2, 5.2], 'Color', 'w');
tl1 = tiledlayout(f1, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel (a): 9x9 Pearson Correlation Heatmap ---
ax1 = nexttile(tl1, 1);
R = pd.R_full;
n_vars = size(R, 1);
imagesc(ax1, R, [-1, 1]);
axis(ax1, 'square');

% Smooth diverging Blue-White-Red colormap
n_half = 128;
r_neg = [linspace(0.12, 1.0, n_half)', linspace(0.32, 1.0, n_half)', linspace(0.62, 1.0, n_half)'];
r_pos = [linspace(1.0, 0.76, n_half)', linspace(1.0, 0.18, n_half)', linspace(1.0, 0.16, n_half)'];
cmap_bwr = [r_neg; r_pos];
colormap(ax1, cmap_bwr);

cb = colorbar(ax1);
cb.Label.String = 'Pearson 相关系数 r';
cb.Label.FontName = font_name;
cb.Label.FontSize = 9.5;
cb.Color = c_axis;

xticks(ax1, 1:n_vars);
yticks(ax1, 1:n_vars);
xticklabels(ax1, pd.eda_vars);
yticklabels(ax1, pd.eda_vars);
xtickangle(ax1, 35);
set(ax1, 'FontName', font_name, 'FontSize', 8.8, 'XColor', c_axis, 'YColor', c_axis, ...
    'TickLength', [0 0], 'LineWidth', 1.0, 'Box', 'on');

% Draw subtle cell grid & numeric annotations
hold(ax1, 'on');
for i = 0.5:(n_vars + 0.5)
    plot(ax1, [0.5, n_vars + 0.5], [i, i], 'Color', [0.82 0.82 0.82], 'LineWidth', 0.5);
    plot(ax1, [i, i], [0.5, n_vars + 0.5], 'Color', [0.82 0.82 0.82], 'LineWidth', 0.5);
end
for r_i = 1:n_vars
    for c_i = 1:n_vars
        val = R(r_i, c_i);
        if abs(val) >= 0.52
            txt_c = [1 1 1];
            fw = 'bold';
        else
            txt_c = [0.12 0.12 0.12];
            fw = 'normal';
        end
        text(ax1, c_i, r_i, sprintf('%.2f', val), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontName', font_name, 'FontSize', 7.8, 'Color', txt_c, 'FontWeight', fw);
    end
end
title(ax1, '(a) 8个物理特征与房价 SalePrice 的 Pearson 相关系数矩阵', ...
    'FontName', font_name, 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', c_axis);

% --- Panel (b): SalePrice Distribution Histogram + KDE + Normal Fit ---
ax2 = nexttile(tl1, 2);
yk = pd.y / 1e3; % scale to $k for clean axis ticks
histogram(ax2, yk, 16, 'Normalization', 'pdf', ...
    'FaceColor', c_navy, 'FaceAlpha', 0.30, 'EdgeColor', c_navy, 'LineWidth', 0.9);
hold(ax2, 'on');

% KDE curve
[f_kde, xi_kde] = ksdensity(yk);
h_kde = plot(ax2, xi_kde, f_kde, '-', 'Color', c_crimson, 'LineWidth', 2.2);

% Normal reference curve
mu_y = mean(yk); sd_y = std(yk, 0); med_y = median(yk);
x_norm = linspace(min(yk) - 20, max(yk) + 20, 200);
y_norm = normpdf(x_norm, mu_y, sd_y);
h_norm = plot(ax2, x_norm, y_norm, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.6);

% Mean vertical line (since mean ~ 252.3k and median ~ 251.3k are very close, annotate neatly!)
h_mean = xline(ax2, mu_y, '-', 'Color', c_teal, 'LineWidth', 1.8);
h_med  = xline(ax2, med_y, ':', 'Color', c_amber, 'LineWidth', 1.8);

grid(ax2, 'on');
ax2.GridAlpha = 0.22;
set(ax2, 'FontName', font_name, 'FontSize', 9.2, 'Color', 'w', ...
    'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax2, '房屋销售价格 SalePrice (千美元, $k)', 'FontName', font_name, 'FontSize', 10);
ylabel(ax2, '概率密度 (Probability Density)', 'FontName', font_name, 'FontSize', 10);
title(ax2, '(b) 目标变量 SalePrice 分布直方图与核密度估计', ...
    'FontName', font_name, 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', c_axis);

yl2 = ylim(ax2);
ylim(ax2, [0, yl2(2) * 1.24]);
xlim(ax2, [55, 465]);

legend(ax2, [h_kde, h_norm, h_mean, h_med], ...
    {'核密度估计 (KDE)', '正态分布拟合', ...
     sprintf('均值 = $%.1fk', mu_y), sprintf('中位数 = $%.1fk', med_y)}, ...
    'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.4, ...
    'Box', 'on', 'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

stats_str = sprintf(['样本量 N = %d\n均值 = $%.1fk\n标准差 = $%.1fk\n' ...
    '范围 = [$%.1fk, $%.1fk]\n偏度 = %.3f'], ...
    numel(yk), mu_y, sd_y, min(yk), max(yk), skewness(yk, 0));
text(ax2, 0.97, 0.95, stats_str, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontName', font_name, 'FontSize', 8.4, 'Color', c_axis, ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 5);

fig_paths{1} = fullfile(fig_dir, 'fig1_eda_correlation_heatmap.png');
exportgraphics(f1, fig_paths{1}, 'Resolution', 300, 'BackgroundColor', 'white');
close(f1);

%% ========================================================================
%  FIGURE 2: Single-Variable Curve Fitting (Line vs Parabola on GrLivArea)
%% ========================================================================
f2 = figure('Units', 'inches', 'Position', [0.5, 0.5, 11.4, 4.9], 'Color', 'w');
tl2 = tiledlayout(f2, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

x_tr = pd.X_train(:, pd.top1_idx);
x_te = pd.X_test(:, pd.top1_idx);
y_tr_k = pd.y_train / 1e3;
y_te_k = pd.y_test / 1e3;

x_grid = linspace(min([x_tr; x_te]) - 50, max([x_tr; x_te]) + 50, 250)';
[yhat1, yci1] = predict(pd.mdl_poly1, x_grid, 'Prediction', 'curve');
[yhat2, ~]    = predict(pd.mdl_poly2, x_grid, 'Prediction', 'curve');

% --- Panel (a): Curve Fit + 95% CI ---
ax1 = nexttile(tl2, 1);
hold(ax1, 'on');
% 95% CI shaded band for linear fit
fill(ax1, [x_grid; flipud(x_grid)], [yci1(:,1); flipud(yci1(:,2))]/1e3, ...
    c_navy, 'FaceAlpha', 0.14, 'EdgeColor', 'none', 'DisplayName', '一次线性 95% 置信带');
scatter(ax1, x_tr, y_tr_k, 24, c_navy, 'o', 'filled', 'MarkerFaceAlpha', 0.45, ...
    'DisplayName', '训练集样本 (N=240)');
scatter(ax1, x_te, y_te_k, 34, c_amber, '^', 'filled', 'MarkerEdgeColor', [0.4 0.2 0], ...
    'LineWidth', 0.5, 'DisplayName', '测试集样本 (N=60)');
plot(ax1, x_grid, yhat1/1e3, '-', 'Color', c_navy, 'LineWidth', 2.3, ...
    'DisplayName', '一次线性拟合 (poly1)');
plot(ax1, x_grid, yhat2/1e3, '--', 'Color', c_crimson, 'LineWidth', 2.3, ...
    'DisplayName', '二次抛物线拟合 (poly2)');

grid(ax1, 'on'); ax1.GridAlpha = 0.22;
set(ax1, 'FontName', font_name, 'FontSize', 9.2, 'Color', 'w', ...
    'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax1, '地上居住面积 GrLivArea (平方英尺)', 'FontName', font_name, 'FontSize', 10);
ylabel(ax1, '房屋销售价格 SalePrice (千美元, $k)', 'FontName', font_name, 'FontSize', 10);
title(ax1, '(a) 单特征 GrLivArea 一次直线 vs 二次抛物线拟合', ...
    'FontName', font_name, 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', c_axis);
ylim(ax1, [50, 480]);
xlim(ax1, [400, 4150]);

legend(ax1, 'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.2, ...
    'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

fit_box = sprintf(['poly1: CV R^2=%.4f, RMSE=$%.1fk\n' ...
                   '       Test R^2=%.4f, RMSE=$%.1fk\n' ...
                   'poly2: CV R^2=%.4f, RMSE=$%.1fk\n' ...
                   '       Test R^2=%.4f, RMSE=$%.1fk\n' ...
                   '二次项显著性检验: p = %.4f (不显著)'], ...
    pd.rec_1a.cv_r2_mean, pd.rec_1a.cv_rmse_mean/1e3, pd.rec_1a.test.r2, pd.rec_1a.test.rmse/1e3, ...
    pd.rec_1b.cv_r2_mean, pd.rec_1b.cv_rmse_mean/1e3, pd.rec_1b.test.r2, pd.rec_1b.test.rmse/1e3, ...
    pd.rec_1b.quad_term_p_value);
text(ax1, 0.97, 0.04, fit_box, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontName', font_name, 'FontSize', 8.0, 'Color', c_axis, ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 5);

% --- Panel (b): Single-Feature Fit Residuals vs GrLivArea ---
ax2 = nexttile(tl2, 2);
hold(ax2, 'on');
res1_tr = (pd.y_train - predict(pd.mdl_poly1, x_tr)) / 1e3;
res1_te = (pd.y_test  - predict(pd.mdl_poly1, x_te)) / 1e3;
diff_curve = (yhat2 - yhat1) / 1e3; % difference poly2 - poly1

scatter(ax2, x_tr, res1_tr, 24, c_navy, 'o', 'filled', 'MarkerFaceAlpha', 0.45, ...
    'DisplayName', 'poly1 训练集残差');
scatter(ax2, x_te, res1_te, 34, c_amber, '^', 'filled', 'MarkerEdgeColor', [0.4 0.2 0], ...
    'LineWidth', 0.5, 'DisplayName', 'poly1 测试集残差');
yline(ax2, 0, '-', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.3, 'HandleVisibility', 'off');
plot(ax2, x_grid, diff_curve, '--', 'Color', c_crimson, 'LineWidth', 2.2, ...
    'DisplayName', '二次项修正量 (poly2 - poly1)');

grid(ax2, 'on'); ax2.GridAlpha = 0.22;
set(ax2, 'FontName', font_name, 'FontSize', 9.2, 'Color', 'w', ...
    'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax2, '地上居住面积 GrLivArea (平方英尺)', 'FontName', font_name, 'FontSize', 10);
ylabel(ax2, '拟合残差 Residual (千美元, $k)', 'FontName', font_name, 'FontSize', 10);
title(ax2, '(b) 单特征残差分布：无明显曲率，但遗漏特征致残差高达 ±$100k', ...
    'FontName', font_name, 'FontSize', 10.0, 'FontWeight', 'bold', 'Color', c_axis);
xlim(ax2, [400, 4150]);
ylim(ax2, [-140, 155]);

legend(ax2, 'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.2, ...
    'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

fig_paths{2} = fullfile(fig_dir, 'fig2_single_feature_line_vs_parabola.png');
exportgraphics(f2, fig_paths{2}, 'Resolution', 300, 'BackgroundColor', 'white');
close(f2);

%% ========================================================================
%  FIGURE 3: Model Progression (Simple->Complex) + Best Model Diagnostics
%% ========================================================================
f3 = figure('Units', 'inches', 'Position', [0.5, 0.5, 11.6, 8.2], 'Color', 'w');
tl3 = tiledlayout(f3, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel (a): Top-Row Full-Width Progression Bar Chart ---
ax1 = nexttile(tl3, [1, 2]);
% Select 10 distinct models (combining 3 equivalent OLS solvers cleanly into 1 labeled bar!)
keep_ids = {'T1_Single_Linear', 'T1_Single_Parabolic', 'T2_OLS_fitlm', ...
            'T2_PureQuadratic', 'T2_FullQuadratic', 'T3_Ridge_L2', ...
            'T3_Lasso_L1', 'T4_DecisionTree', 'T4_RandomForest', 'T4_GBDT_LSBoost'};
short_labels = {'1D Linear', '1D Parabolic', 'OLS (3 Solvers*)', ...
                'Pure Quad (16)', 'Full Quad (44)', 'Ridge (L2)', ...
                'Lasso (L1)', 'Decision Tree', 'Random Forest', 'GBDT (LSBoost)'};

n_m = numel(keep_ids);
cv_rmse_arr = zeros(n_m, 1);
cv_std_arr  = zeros(n_m, 1);
te_rmse_arr = zeros(n_m, 1);
cv_r2_arr   = zeros(n_m, 1);

for i = 1:n_m
    idx = find(cellfun(@(r) strcmp(r.id, keep_ids{i}), pd.model_records), 1);
    rec = pd.model_records{idx};
    cv_rmse_arr(i) = rec.cv_rmse_mean / 1e3;
    cv_std_arr(i)  = rec.cv_rmse_std  / 1e3;
    te_rmse_arr(i) = rec.test.rmse    / 1e3;
    cv_r2_arr(i)   = rec.cv_r2_mean;
end

x_pos = 1:n_m;
b = bar(ax1, x_pos, [cv_rmse_arr, te_rmse_arr], 'grouped', 'BarWidth', 0.78);
b(1).FaceColor = c_navy;    b(1).EdgeColor = 'none';
b(2).FaceColor = c_amber;   b(2).EdgeColor = 'none';
hold(ax1, 'on');

% Error bars on 5-fold CV RMSE (1 SD across 5 folds)
x_cv = b(1).XEndPoints;
x_te = b(2).XEndPoints;
errorbar(ax1, x_cv, cv_rmse_arr, cv_std_arr, 'k', 'LineStyle', 'none', ...
    'LineWidth', 1.0, 'CapSize', 3.5, 'HandleVisibility', 'off');

% Highlight tier dividers subtly
tier_splits = [2.5, 5.5, 7.5];
for ts = tier_splits
    xline(ax1, ts, ':', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.0, 'HandleVisibility', 'off');
end

% Annotate CV RMSE and R^2 cleanly above each model pair
max_bar_h = max([cv_rmse_arr + cv_std_arr; te_rmse_arr]);
for i = 1:n_m
    top_y = max(cv_rmse_arr(i) + cv_std_arr(i), te_rmse_arr(i));
    text(ax1, i, top_y + max_bar_h * 0.025, ...
        sprintf('$%.1fk\n(R^2=%.3f)', cv_rmse_arr(i), cv_r2_arr(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontName', font_name, 'FontSize', 7.6, 'Color', c_axis);
end

% Tier labels at top
y_top_lim = max_bar_h * 1.28;
ylim(ax1, [0, y_top_lim]);
xlim(ax1, [0.4, n_m + 0.6]);
tier_x = [1.5, 4.0, 6.5, 9.0];
tier_txt = {'Tier 1: 单特征拟合', 'Tier 2: 多元线性与多项式', 'Tier 3: 正则化', 'Tier 4: 树与集成'};
for ti = 1:4
    text(ax1, tier_x(ti), y_top_lim * 0.94, tier_txt{ti}, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontName', font_name, 'FontSize', 8.5, 'FontWeight', 'bold', ...
        'Color', [0.30 0.30 0.30], 'BackgroundColor', [0.95 0.96 0.97], 'Margin', 2.5);
end

xticks(ax1, x_pos);
xticklabels(ax1, short_labels);
xtickangle(ax1, 18);
grid(ax1, 'on'); ax1.GridAlpha = 0.22;
set(ax1, 'FontName', font_name, 'FontSize', 8.8, 'Color', 'w', ...
    'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
ylabel(ax1, '预测误差 RMSE (千美元, $k)', 'FontName', font_name, 'FontSize', 9.8);
title(ax1, '(a) 简单到复杂 4 阶层 10 模型性能对比（*OLS 3 种求解器结果一致，差异 < 10^{-8}）', ...
    'FontName', font_name, 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', c_axis);
legend(ax1, {'5折交叉验证 RMSE (±1 SD)', '独立测试集 RMSE (N=60)'}, ...
    'Position', [0.36, 0.77, 0.24, 0.08], ...
    'FontName', font_name, 'FontSize', 8.6, 'Color', 'w', 'TextColor', c_axis, ...
    'EdgeColor', [0.75 0.75 0.75]);

% --- Panel (b): Best Model Predicted vs Actual ---
ax2 = nexttile(tl3, 3);
hold(ax2, 'on');
ytr_k = pd.y_train / 1e3; ptr_k = pd.best_pred_tr / 1e3;
yte_k = pd.y_test  / 1e3; pte_k = pd.best_pred_te / 1e3;

min_v = min([ytr_k; yte_k; ptr_k; pte_k]) - 15;
max_v = max([ytr_k; yte_k; ptr_k; pte_k]) + 15;

plot(ax2, [min_v, max_v], [min_v, max_v], '--', 'Color', c_crimson, 'LineWidth', 1.8, ...
    'DisplayName', '理想预测线 y = x');
scatter(ax2, ytr_k, ptr_k, 22, c_navy, 'o', 'filled', 'MarkerFaceAlpha', 0.48, ...
    'DisplayName', '训练集 (N=240)');
scatter(ax2, yte_k, pte_k, 38, c_amber, 'd', 'filled', 'MarkerEdgeColor', [0.35 0.15 0], ...
    'LineWidth', 0.6, 'DisplayName', '独立测试集 (N=60)');

grid(ax2, 'on'); ax2.GridAlpha = 0.22;
axis(ax2, 'equal');
xlim(ax2, [min_v, max_v]); ylim(ax2, [min_v, max_v]);
set(ax2, 'FontName', font_name, 'FontSize', 9.0, 'Color', 'w', ...
    'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax2, '实际房价 SalePrice ($k)', 'FontName', font_name, 'FontSize', 9.8);
ylabel(ax2, '模型预测房价 Predicted ($k)', 'FontName', font_name, 'FontSize', 9.8);
title(ax2, sprintf('(b) 最优模型 [%s] 预测值 vs 真实值', pd.best_rec.display_name), ...
    'FontName', font_name, 'FontSize', 10.0, 'FontWeight', 'bold', 'Color', c_axis);
legend(ax2, 'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.2, ...
    'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

best_box = sprintf(['CV RMSE = $%.2fk (R^2 = %.4f)\n' ...
                    'Test RMSE = $%.2fk (R^2 = %.4f)\n' ...
                    'Test MAE = $%.2fk (MAPE = %.2f%%)'], ...
    pd.best_rec.cv_rmse_mean/1e3, pd.best_rec.cv_r2_mean, ...
    pd.best_rec.test.rmse/1e3, pd.best_rec.test.r2, ...
    pd.best_rec.test.mae/1e3, pd.best_rec.test.mape_pct);
text(ax2, 0.96, 0.05, best_box, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontName', font_name, 'FontSize', 8.2, 'Color', c_axis, ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 4.5);

% --- Panel (c): Best Model Residual Diagnostic Plot ---
ax3 = nexttile(tl3, 4);
hold(ax3, 'on');
res_tr_k = ytr_k - ptr_k;
res_te_k = yte_k - pte_k;
sig_res = std(res_tr_k, 0);

yline(ax3, 0, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.3, 'HandleVisibility', 'off');
yline(ax3,  2*sig_res, '--', 'Color', c_crimson, 'LineWidth', 1.2, 'DisplayName', sprintf('±2\\sigma (±$%.1fk)', 2*sig_res));
yline(ax3, -2*sig_res, '--', 'Color', c_crimson, 'LineWidth', 1.2, 'HandleVisibility', 'off');

scatter(ax3, ptr_k, res_tr_k, 22, c_navy, 'o', 'filled', 'MarkerFaceAlpha', 0.48, ...
    'DisplayName', '训练集残差');
scatter(ax3, pte_k, res_te_k, 38, c_amber, 'd', 'filled', 'MarkerEdgeColor', [0.35 0.15 0], ...
    'LineWidth', 0.6, 'DisplayName', '测试集残差');

grid(ax3, 'on'); ax3.GridAlpha = 0.22;
xlim(ax3, [min_v, max_v]);
max_r = max(abs([res_tr_k; res_te_k])) * 1.28;
ylim(ax3, [-max_r, max_r]);
set(ax3, 'FontName', font_name, 'FontSize', 9.0, 'Color', 'w', ...
    'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax3, '模型预测房价 Predicted ($k)', 'FontName', font_name, 'FontSize', 9.8);
ylabel(ax3, '残差 y - y_{pred} ($k)', 'FontName', font_name, 'FontSize', 9.8);
title(ax3, '(c) 最优模型残差诊断图（同方差性与正态性检验）', ...
    'FontName', font_name, 'FontSize', 10.0, 'FontWeight', 'bold', 'Color', c_axis);
legend(ax3, 'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.2, ...
    'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

jb_txt = sprintf('残差均值 = $%.2fk, SD = $%.2fk\nJarque-Bera 正态检验: p = %.4f', ...
    pd.diag_info.test_resid_mean/1e3, pd.diag_info.test_resid_std/1e3, pd.diag_info.jarque_bera_p);
text(ax3, 0.96, 0.05, jb_txt, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontName', font_name, 'FontSize', 8.1, 'Color', c_axis, ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 4.5);

fig_paths{3} = fullfile(fig_dir, 'fig3_models_progression_and_diagnostics.png');
exportgraphics(f3, fig_paths{3}, 'Resolution', 300, 'BackgroundColor', 'white');
close(f3);

%% ========================================================================
%  FIGURE 4: Manual Gradient Descent Convergence + Lasso Regularization Path
%% ========================================================================
f4 = figure('Units', 'inches', 'Position', [0.5, 0.5, 11.8, 5.1], 'Color', 'w');
tl4 = tiledlayout(f4, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel (a): Manual Batch Gradient Descent Convergence Curve ---
ax1 = nexttile(tl4, 1);
n_show = min(250, pd.gd_full.iterations);
iters = (1:n_show)';
mse_scaled = pd.gd_full.mse_history(1:n_show) / 1e8; % units: 10^8 $^2
ne_mse_scaled = pd.ols_ne_train_mse / 1e8;

semilogy(ax1, iters, mse_scaled, '-', 'Color', c_navy, 'LineWidth', 2.3, ...
    'DisplayName', sprintf('手动梯度下降 MSE (\\alpha = %.2f)', pd.gd_full.lr));
hold(ax1, 'on');
yline(ax1, ne_mse_scaled, '--', 'Color', c_crimson, 'LineWidth', 1.8, ...
    'DisplayName', sprintf('正规方程解析解 MSE = %.3f\\times10^8', ne_mse_scaled));

grid(ax1, 'on'); ax1.GridAlpha = 0.25;
set(ax1, 'FontName', font_name, 'FontSize', 9.2, 'Color', 'w', ...
    'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax1, '迭代次数 Iteration', 'FontName', font_name, 'FontSize', 10);
ylabel(ax1, '训练集均方误差 MSE (10^8 美元^2，对数坐标)', 'FontName', font_name, 'FontSize', 9.8);
title(ax1, '(a) 标准化特征批量梯度下降 (Batch GD) 收敛曲线', ...
    'FontName', font_name, 'FontSize', 10.3, 'FontWeight', 'bold', 'Color', c_axis);
xlim(ax1, [1, n_show]);
legend(ax1, 'Location', 'northeast', 'FontName', font_name, 'FontSize', 8.4, ...
    'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

gd_note = sprintf(['总迭代步数: %d 步 (tol = 10^{-11})\n' ...
                   '最终训练 RMSE = $%.2f\n' ...
                   '与正规方程预测最大差值 = %.2e\n' ...
                   '与 fitlm 系数最大差值 = %.2e'], ...
    pd.gd_full.iterations, pd.gd_full.final_rmse, ...
    pd.ols_equiv.max_test_pred_diff_NE_vs_GD, pd.ols_equiv.max_beta_diff_GD_vs_fitlm);
text(ax1, 0.96, 0.62, gd_note, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontName', font_name, 'FontSize', 8.1, 'Color', c_axis, ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 5);

% --- Panel (b): Lasso Regularization Path (High Lambda -> Low Lambda) ---
ax2 = nexttile(tl4, 2);
hold(ax2, 'on');
log_lam = log10(pd.lasso_lambdas);
B_k = pd.B_lasso_path / 1e3; % standardized coefficients in $k

% Distinct colors for Top 3; muted styles for remaining 5
top3 = pd.top3_indices;
top3_colors = [c_crimson; c_navy; c_teal];
other_colors = [0.55 0.55 0.55; 0.65 0.52 0.35; 0.45 0.55 0.62; 0.62 0.48 0.58; 0.70 0.70 0.70];
other_styles = {'--', '-.', ':', '--', '-.'};

p_cnt = numel(pd.feature_names);
o_i = 1;
h_top = gobjects(3, 1);

% Plot non-top-3 first so top-3 stay crisp on top
for j = 1:p_cnt
    if ~ismember(j, top3)
        plot(ax2, log_lam, B_k(j, :), other_styles{o_i}, ...
            'Color', other_colors(o_i, :), 'LineWidth', 1.35, 'HandleVisibility', 'off');
        o_i = o_i + 1;
    end
end

% Plot Top 3 in vivid thick lines + mark entry points
for k = 1:3
    j = top3(k);
    h_top(k) = plot(ax2, log_lam, B_k(j, :), '-', ...
        'Color', top3_colors(k, :), 'LineWidth', 2.5, ...
        'DisplayName', sprintf('Top #%d: %s', k, pd.feature_names{j}));
    % Mark entry threshold
    if pd.lasso_entry_lambda(j) > 0
        lx = log10(pd.lasso_entry_lambda(j));
        scatter(ax2, lx, 0, 52, top3_colors(k, :), 'filled', 'MarkerEdgeColor', 'w', ...
            'LineWidth', 0.8, 'HandleVisibility', 'off');
    end
end

yline(ax2, 0, '-', 'Color', [0.25 0.25 0.25], 'LineWidth', 0.9, 'HandleVisibility', 'off');
h_lmin = xline(ax2, log10(pd.lam_min), '--', 'Color', [0.15 0.15 0.15], 'LineWidth', 1.3, ...
    'DisplayName', sprintf('\\lambda_{min} = %.0f', pd.lam_min));
h_l1se = xline(ax2, log10(pd.lam_1se), ':', 'Color', c_amber, 'LineWidth', 1.8, ...
    'DisplayName', sprintf('\\lambda_{1SE} = %.0f', pd.lam_1se));

% Reverse X-axis so left = high penalty (0 features), right = low penalty (all features)
set(ax2, 'XDir', 'reverse');
x_right = min(log_lam);
x_left  = max(log_lam);
% Leave right margin for direct feature labels, keep ticks on data range only
xlim(ax2, [x_right - 1.35, x_left + 0.15]);
xticks(ax2, 0:4);
ylim(ax2, [-6, max(B_k(:)) * 1.12]);

% Smart non-overlapping direct labels on the right end (small lambda)
end_vals = B_k(:, end);
[sorted_y, s_idx] = sort(end_vals, 'ascend');
min_gap = 3.2; % $k minimum vertical separation
adj_y = sorted_y;
for i = 2:p_cnt
    if adj_y(i) - adj_y(i - 1) < min_gap
        adj_y(i) = adj_y(i - 1) + min_gap;
    end
end
for i = 1:p_cnt
    j = s_idx(i);
    if ismember(j, top3)
        k_pos = find(top3 == j, 1);
        tc = top3_colors(k_pos, :);
        fw = 'bold';
        lbl = sprintf('#%d %s', k_pos, pd.feature_names{j});
    else
        tc = [0.38 0.38 0.38];
        fw = 'normal';
        lbl = pd.feature_names{j};
    end
    text(ax2, x_right - 0.08, adj_y(i), lbl, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'FontName', font_name, 'FontSize', 7.8, 'Color', tc, 'FontWeight', fw);
end

grid(ax2, 'on'); ax2.GridAlpha = 0.22;
set(ax2, 'FontName', font_name, 'FontSize', 9.2, 'Color', 'w', ...
    'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax2, 'log_{10}(\lambda)  [左: 强惩罚稀疏模型  \rightarrow  右: 弱惩罚完整模型]', ...
    'FontName', font_name, 'FontSize', 9.5);
ylabel(ax2, '标准化回归系数 \beta_j^* (千美元, $k)', 'FontName', font_name, 'FontSize', 9.8);
title(ax2, '(b) Lasso 正则化路径：Top 3 核心特征最先进入模型', ...
    'FontName', font_name, 'FontSize', 10.3, 'FontWeight', 'bold', 'Color', c_axis);
legend(ax2, [h_top; h_lmin; h_l1se], 'Location', 'northwest', ...
    'FontName', font_name, 'FontSize', 8.0, 'Color', 'w', 'TextColor', c_axis, ...
    'EdgeColor', [0.75 0.75 0.75]);

fig_paths{4} = fullfile(fig_dir, 'fig4_gd_convergence_and_lasso_path.png');
exportgraphics(f4, fig_paths{4}, 'Resolution', 300, 'BackgroundColor', 'white');
close(f4);

%% ========================================================================
%  FIGURE 5: 4-Method Feature Contribution Horizontal Bar Comparison
%% ========================================================================
f5 = figure('Units', 'inches', 'Position', [0.5, 0.5, 11.6, 8.5], 'Color', 'w');
tl5 = tiledlayout(f5, 2, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

top3 = pd.top3_indices;

% Helper inline specs for 4 subplots
panels = {
    struct('vals', pd.abs_beta_std / 1e3, ...
           'title', '(a) 方法 A：标准化 OLS 回归系数 |\beta_j^*|', ...
           'xlabel', '每增加 1 SD 带来的房价变化 ($k)', ...
           'fmt', '$%.2fk', 'extra', []), ...
    struct('vals', pd.delta_cv_rmse / 1e3, ...
           'title', '(b) 方法 B1：留一特征法 (Drop-Column) \DeltaRMSE_{CV}', ...
           'xlabel', '剔除该特征后 5折 CV RMSE 增幅 ($k)', ...
           'fmt', '+$%.2fk', 'extra', []), ...
    struct('vals', pd.r2_uni_all, ...
           'title', '(c) 方法 B2：单变量可决系数 R^2 (= r^2)', ...
           'xlabel', '单特征 Pearson 可决系数 R^2', ...
           'fmt', '%.3f', 'extra', abs(pd.R_pearson_y)), ...
    struct('vals', pd.rf_oob_imp, ...
           'title', '(d) 方法 D：随机森林 OOB 置换重要性 (非线性验证)', ...
           'xlabel', 'OOB 置换误差增量 (Permuted Delta Error)', ...
           'fmt', '%.3f', 'extra', [])
};

for pi = 1:4
    ax = nexttile(tl5, pi);
    spec = panels{pi};
    [s_vals, s_ord] = sort(spec.vals, 'descend');
    n_f = numel(s_vals);

    b_h = barh(ax, 1:n_f, s_vals, 0.66, 'FaceColor', 'flat', 'EdgeColor', 'none');
    for k = 1:n_f
        orig_j = s_ord(k);
        if ismember(orig_j, top3)
            b_h.CData(k, :) = c_crimson;
        else
            b_h.CData(k, :) = c_slate;
        end
    end

    set(ax, 'YDir', 'reverse');
    yticks(ax, 1:n_f);
    y_lbls = cell(n_f, 1);
    for k = 1:n_f
        orig_j = s_ord(k);
        y_lbls{k} = sprintf('%s (%s)', pd.feature_names{orig_j}, pd.feature_cn{orig_j});
    end
    yticklabels(ax, y_lbls);

    % Expand x-axis right margin cleanly so value labels never clip
    max_v = max(s_vals);
    min_v = min(0, min(s_vals));
    if pi == 3
        x_pad_r = max_v * 0.45;
    else
        x_pad_r = max_v * 0.26;
    end
    xlim(ax, [min_v - max_v * 0.03, max_v + x_pad_r]);

    hold(ax, 'on');
    xline(ax, 0, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.8);
    for k = 1:n_f
        orig_j = s_ord(k);
        v = s_vals(k);
        if ~isempty(spec.extra)
            lbl_str = sprintf('%.3f (|r|=%.2f)', v, spec.extra(orig_j));
        elseif pi == 2 && v < 0
            lbl_str = sprintf('-$%.2fk', abs(v));
        else
            lbl_str = sprintf(spec.fmt, v);
        end
        if ismember(orig_j, top3)
            tc = c_crimson; fw = 'bold';
        else
            tc = [0.25 0.25 0.25]; fw = 'normal';
        end
        x_txt = max(v, 0) + max_v * 0.02;
        text(ax, x_txt, k, lbl_str, 'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle', 'FontName', font_name, ...
            'FontSize', 8.2, 'Color', tc, 'FontWeight', fw);
    end

    grid(ax, 'on'); ax.GridAlpha = 0.22;
    set(ax, 'FontName', font_name, 'FontSize', 8.6, 'Color', 'w', ...
        'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
    xlabel(ax, spec.xlabel, 'FontName', font_name, 'FontSize', 9.2);
    title(ax, spec.title, 'FontName', font_name, 'FontSize', 10.0, ...
        'FontWeight', 'bold', 'Color', c_axis);
end

sgtitle(f5, '四种互补特征贡献度评估方法对比（红色柱 = 一致确认的 Top 3 核心特征：GrLivArea、OverallQual、GarageCars）', ...
    'FontName', font_name, 'FontSize', 11.2, 'FontWeight', 'bold', 'Color', c_axis);

fig_paths{5} = fullfile(fig_dir, 'fig5_feature_importance_4methods.png');
exportgraphics(f5, fig_paths{5}, 'Resolution', 300, 'BackgroundColor', 'white');
close(f5);

set(0, 'DefaultFigureVisible', 'on');
end
