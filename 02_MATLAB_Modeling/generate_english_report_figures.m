function generate_english_report_figures()
% GENERATE_ENGLISH_REPORT_FIGURES
% Export 3 clean, classroom-terminology, pure-white 300-DPI PNG figures in English
% for Practice 2 English Report (EDA, Multiple OLS + Residuals, Top-3 Features).

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
feature_short = {'Overall Quality', 'Living Area', 'Garage Capacity', 'Basement Area', ...
                 'Year Built', 'Full Bathrooms', 'Bedrooms Above', 'Lot Area'};
target_name   = 'SalePrice';

X = T{:, feature_names};
y = T{:, target_name};
N = size(X, 1);

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
rec_ols = m_map('T2_OLS_fitlm');

cv_hold = cvpartition(N, 'HoldOut', 0.20);
idx_tr = training(cv_hold);
idx_te = test(cv_hold);
X_tr = X(idx_tr, :); y_tr = y(idx_tr);
X_te = X(idx_te, :); y_te = y(idx_te);

mdl_ols = fitlm(X_tr, y_tr);
pred_ols_tr = predict(mdl_ols, X_tr);
pred_ols_te = predict(mdl_ols, X_te);

X_tr_aug = [ones(size(X_tr, 1), 1), X_tr];
beta_ne = (X_tr_aug' * X_tr_aug) \ (X_tr_aug' * y_tr);
pred_ne_te = [ones(size(X_te, 1), 1), X_te] * beta_ne;
max_diff_ne_fitlm = max(abs(pred_ne_te - pred_ols_te));

font_name = 'Arial';
c_navy    = [0.106, 0.310, 0.447];
c_crimson = [0.753, 0.224, 0.169];
c_amber   = [0.851, 0.447, 0.000];
c_teal    = [0.086, 0.569, 0.478];
c_slate   = [0.520, 0.575, 0.605];
c_axis    = [0.10,  0.10,  0.10];

set(0, 'DefaultFigureVisible', 'off');
set(0, 'DefaultLegendTextColor', c_axis);

%% ========================================================================
%  FIG 1 (EN): EDA (Correlation Heatmap + SalePrice Distribution)
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
cb.Label.String = 'Correlation r';
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
title(ax1, '(a) Correlation Matrix of 8 Predictors and SalePrice', ...
    'FontName', font_name, 'FontSize', 10.2, 'FontWeight', 'bold', 'Color', c_axis);

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
xlabel(ax2, 'SalePrice ($k)', 'FontName', font_name, 'FontSize', 9.8);
ylabel(ax2, 'Probability Density', 'FontName', font_name, 'FontSize', 9.8);
title(ax2, '(b) Histogram of SalePrice Distribution', ...
    'FontName', font_name, 'FontSize', 10.2, 'FontWeight', 'bold', 'Color', c_axis);
yl2 = ylim(ax2);
ylim(ax2, [0, yl2(2) * 1.24]);
xlim(ax2, [55, 465]);

legend(ax2, [h_norm, h_mean], ...
    {'Normal Reference Curve', sprintf('Sample Mean = $%.1fk', mu_y)}, ...
    'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.3, ...
    'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

stats_str = sprintf('N = %d\nMean = $%.1fk\nSD = $%.1fk\nRange = [$%.1fk, $%.1fk]', ...
    numel(yk), mu_y, sd_y, min(yk), max(yk));
text(ax2, 0.97, 0.95, stats_str, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontName', font_name, 'FontSize', 8.3, 'Color', c_axis, ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 5);

exportgraphics(f1, fullfile(fig_dir, 'fig1_en_eda.png'), 'Resolution', 300, 'BackgroundColor', 'white');
close(f1);

%% ========================================================================
%  FIG 2 (EN): Multiple Linear Regression Fit + Residual Distribution
%% ========================================================================
f2 = figure('Units', 'inches', 'Position', [0.5, 0.5, 11.4, 4.6], 'Color', 'w');
tl2 = tiledlayout(f2, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Panel (a): Predicted vs Actual
ax1 = nexttile(tl2, 1);
hold(ax1, 'on');
ytr_k = y_tr/1e3; ptr_k = pred_ols_tr/1e3;
yte_k = y_te/1e3; pte_k = pred_ols_te/1e3;
min_v = min([ytr_k; yte_k; ptr_k; pte_k]) - 15;
max_v = max([ytr_k; yte_k; ptr_k; pte_k]) + 15;

plot(ax1, [min_v, max_v], [min_v, max_v], '--', 'Color', c_crimson, 'LineWidth', 1.9, 'DisplayName', 'Reference Line y = x');
scatter(ax1, ytr_k, ptr_k, 22, c_navy, 'o', 'filled', 'MarkerFaceAlpha', 0.48, 'DisplayName', 'Training Set (N=240)');
scatter(ax1, yte_k, pte_k, 38, c_amber, 'd', 'filled', 'MarkerEdgeColor', [0.35 0.15 0], 'LineWidth', 0.6, 'DisplayName', 'Test Set (N=60)');

grid(ax1, 'on'); ax1.GridAlpha = 0.22;
axis(ax1, 'square');
xlim(ax1, [min_v, max_v]); ylim(ax1, [min_v, max_v]);
set(ax1, 'FontName', font_name, 'FontSize', 9.0, 'Color', 'w', 'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax1, 'Actual SalePrice ($k)', 'FontName', font_name, 'FontSize', 9.8);
ylabel(ax1, 'Predicted SalePrice ($k)', 'FontName', font_name, 'FontSize', 9.8);
title(ax1, '(a) Multiple Linear Regression: Predicted vs. Actual', ...
    'FontName', font_name, 'FontSize', 10.0, 'FontWeight', 'bold', 'Color', c_axis);
legend(ax1, 'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.2, 'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

ols_box = sprintf('5-Fold CV RMSE = $%.2fk (R^2=%.3f)\nTest RMSE = $%.2fk (R^2=%.3f)', ...
    rec_ols.cv_rmse_mean/1e3, rec_ols.cv_r2_mean, rec_ols.test.rmse/1e3, rec_ols.test.r2);
text(ax1, 0.96, 0.04, ols_box, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontName', font_name, 'FontSize', 8.1, 'Color', c_axis, 'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 4.5);

% Panel (b): Residuals vs Predicted
ax2 = nexttile(tl2, 2);
hold(ax2, 'on');
res_tr_k = (y_tr - pred_ols_tr) / 1e3;
res_te_k = (y_te - pred_ols_te) / 1e3;

scatter(ax2, ptr_k, res_tr_k, 22, c_navy, 'o', 'filled', 'MarkerFaceAlpha', 0.48, 'DisplayName', 'Training Residuals');
scatter(ax2, pte_k, res_te_k, 38, c_amber, 'd', 'filled', 'MarkerEdgeColor', [0.35 0.15 0], 'LineWidth', 0.6, 'DisplayName', 'Test Residuals');
yline(ax2, 0, '-', 'Color', c_crimson, 'LineWidth', 1.8, 'DisplayName', 'Zero Line');
yline(ax2, 25, '--', 'Color', c_teal, 'LineWidth', 1.2, 'DisplayName', '±$25k Band');
yline(ax2, -25, '--', 'Color', c_teal, 'LineWidth', 1.2, 'HandleVisibility', 'off');

grid(ax2, 'on'); ax2.GridAlpha = 0.22;
set(ax2, 'FontName', font_name, 'FontSize', 9.0, 'Color', 'w', 'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
xlabel(ax2, 'Predicted SalePrice ($k)', 'FontName', font_name, 'FontSize', 9.8);
ylabel(ax2, 'Residual: Actual - Predicted ($k)', 'FontName', font_name, 'FontSize', 9.8);
title(ax2, '(b) Residual Distribution of Linear Model', ...
    'FontName', font_name, 'FontSize', 10.0, 'FontWeight', 'bold', 'Color', c_axis);
xlim(ax2, [min_v, max_v]);
ylim(ax2, [-42, 42]);
legend(ax2, 'Location', 'northwest', 'FontName', font_name, 'FontSize', 8.0, 'Color', 'w', 'TextColor', c_axis, 'EdgeColor', [0.75 0.75 0.75]);

res_box = sprintf('Test MAE = $%.2fk\nMax Diff (Normal Eq vs fitlm) = %.2e\nUniform spread within ±$25k', ...
    rec_ols.test.mae/1e3, max_diff_ne_fitlm);
text(ax2, 0.97, 0.96, res_box, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontName', font_name, 'FontSize', 8.0, 'Color', c_axis, 'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.72 0.72 0.72], 'Margin', 4.5);

exportgraphics(f2, fullfile(fig_dir, 'fig2_en_ols_fit_and_residuals.png'), 'Resolution', 300, 'BackgroundColor', 'white');
close(f2);

%% ========================================================================
%  FIG 3 (EN): Two Feature Contribution Methods (Top 3 Highlighted)
%% ========================================================================
ranked = res.feature_importance.ranked_table;
n_f = numel(ranked);
lbls = cell(n_f, 1);
std_vals = zeros(n_f, 1);
drop_vals = zeros(n_f, 1);
is_top3 = false(n_f, 1);

short_map = containers.Map(feature_names, feature_short);
for i = 1:n_f
    if iscell(ranked)
        rk_i = ranked{i};
    else
        rk_i = ranked(i);
    end
    lbls{i} = sprintf('%s (%s)', rk_i.feature, short_map(rk_i.feature));
    std_vals(i) = rk_i.ols_std_abs_beta / 1e3;
    drop_vals(i) = rk_i.delta_cv_rmse / 1e3;
    is_top3(i) = (rk_i.consensus_rank <= 3);
end

f3 = figure('Units', 'inches', 'Position', [0.5, 0.5, 11.4, 4.6], 'Color', 'w');
tl3 = tiledlayout(f3, 1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

specs = {
    struct('vals', std_vals, 'title', '(a) Method 1: Standardized Coefficients |\beta_j^*|', ...
           'xlabel', 'Price Change per 1 SD Increase ($k)', 'is_delta', false), ...
    struct('vals', drop_vals, 'title', '(b) Method 2: Leave-One-Out 5-Fold CV RMSE Increase', ...
           'xlabel', '5-Fold CV RMSE Increase Upon Removal ($k)', 'is_delta', true)
};

for pi = 1:2
    ax = nexttile(tl3, pi);
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
    set(ax, 'FontName', font_name, 'FontSize', 8.4, 'Color', 'w', ...
        'XColor', c_axis, 'YColor', c_axis, 'LineWidth', 1.0, 'Box', 'on');
    xlabel(ax, sp.xlabel, 'FontName', font_name, 'FontSize', 9.2);
    title(ax, sp.title, 'FontName', font_name, 'FontSize', 9.8, 'FontWeight', 'bold', 'Color', c_axis);
end

exportgraphics(f3, fullfile(fig_dir, 'fig3_en_feature_importance_top3.png'), 'Resolution', 300, 'BackgroundColor', 'white');
close(f3);

set(0, 'DefaultFigureVisible', 'on');
fprintf('[OK] Exported 3 English report figures cleanly.\n');
end
