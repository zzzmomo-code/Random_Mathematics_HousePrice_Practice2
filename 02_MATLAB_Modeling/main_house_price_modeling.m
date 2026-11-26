%% House Price Regression Modeling & Top-3 Feature Contribution Analysis
% Course: Random Mathematics / Data Modeling Practice 2 (Prof. Liang Jing)
% Student: 裴翰章 (2025310104015)
% Environment: MATLAB R2025b (Statistics and Machine Learning Toolbox)
% Reproducibility: Fixed seed rng(42), strictly leak-free 80/20 split & 5-fold CV

clear; clc; close all;
rng(42, 'twister');

fprintf('=================================================================\n');
fprintf(' House Price Regression Modeling Pipeline (MATLAB R2025b)\n');
fprintf('=================================================================\n');

%% 0. Paths & Data Loading
root_dir   = 'E:\Random_Mathematics_Project_HousePrice';
data_csv   = fullfile(root_dir, '01_Data', '聚合数据用于学习训练', '数据样本.csv');
eda_json   = fullfile(root_dir, '01_Data', 'eda_summary.json');
model_dir  = fullfile(root_dir, '02_MATLAB_Modeling');
fig_dir    = fullfile(root_dir, '03_Figures');
res_json   = fullfile(model_dir, 'results_summary.json');

if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
addpath(model_dir);

opts = detectImportOptions(data_csv, 'Encoding', 'UTF-8');
opts.VariableNamingRule = 'preserve';
T = readtable(data_csv, opts);

N = height(T);
all_cols = T.Properties.VariableNames;
fprintf('[Step 0] Loaded %s: %d rows x %d columns\n', data_csv, N, width(T));

% Exclude sample index column 'Id' from predictive features
feature_names = {'OverallQual', 'GrLivArea', 'GarageCars', 'TotalBsmtSF', ...
                 'YearBuilt', 'FullBath', 'BedroomAbvGr', 'LotArea'};
feature_cn = {'综合质量', '地上居住面积', '车库容量', '地下室面积', ...
              '建造年份', '全卫生间数', '地上卧室数', '地块面积'};
target_name = 'SalePrice';
p = numel(feature_names);

X = T{:, feature_names};
y = T{:, target_name};

assert(N == 300, 'Expected 300 rows, got %d', N);
assert(all(~isnan(X), 'all') && all(~isnan(y)), 'Unexpected missing values found.');

%% 1. Comprehensive Exploratory Data Analysis (EDA)
fprintf('\n[Step 1] Computing EDA Statistics, Correlations, and VIF...\n');

eda = struct();
eda.dataset_path = data_csv;
eda.source_url = 'https://www.juhe.cn/dataset/product/id/mva1wdNmuJB';
eda.n_samples = N;
eda.n_raw_columns = width(T);
eda.excluded_columns = {'Id'};
eda.feature_names = feature_names;
eda.feature_names_cn = feature_cn;
eda.target_name = target_name;
eda.total_missing_values = sum(ismissing(T), 'all');

eda_vars = [feature_names, {target_name}];
M_all = [X, y];
desc_list = [];

for j = 1:numel(eda_vars)
    v = M_all(:, j);
    s = struct();
    s.variable = eda_vars{j};
    s.missing_count = sum(isnan(v));
    s.min = min(v);
    s.q25 = quantile(v, 0.25);
    s.median = median(v);
    s.mean = mean(v);
    s.q75 = quantile(v, 0.75);
    s.max = max(v);
    s.std = std(v, 0);
    s.skewness = skewness(v, 0);
    s.kurtosis = kurtosis(v, 0);
    if j == 1
        desc_list = repmat(s, numel(eda_vars), 1);
    else
        desc_list(j) = s;
    end
end
eda.descriptive_stats = desc_list;

% Correlation matrices (9x9)
[R_full, P_full] = corr(M_all, 'Type', 'Pearson');
[R_spearman_y, P_spearman_y] = corr(X, y, 'Type', 'Spearman');
R_pearson_y = R_full(1:p, end);
P_pearson_y = P_full(1:p, end);

% Collinearity diagnostics: VIF and condition number
R_xx = corr(X, 'Type', 'Pearson');
vif_vals = diag(inv(R_xx));
Z_all = (X - mean(X, 1)) ./ std(X, 0, 1);
cond_X_std = cond(Z_all);

% Feature correlation & VIF summary table
corr_summary = [];
for j = 1:p
    cs = struct();
    cs.feature = feature_names{j};
    cs.feature_cn = feature_cn{j};
    cs.pearson_r = R_pearson_y(j);
    cs.pearson_r2 = R_pearson_y(j)^2;
    cs.pearson_p = P_pearson_y(j);
    cs.spearman_rho = R_spearman_y(j);
    cs.spearman_p = P_spearman_y(j);
    cs.vif = vif_vals(j);
    if j == 1
        corr_summary = repmat(cs, p, 1);
    else
        corr_summary(j) = cs;
    end
end

eda.correlation_matrix_vars = eda_vars;
eda.pearson_corr_matrix = R_full;
eda.feature_target_correlations = corr_summary;
eda.max_interfeature_abs_r = max(abs(R_xx - eye(p)), [], 'all');
eda.max_vif = max(vif_vals);
eda.standardized_X_condition_number = cond_X_std;

% Identify top single feature by |r|
[~, top1_idx] = max(abs(R_pearson_y));
top1_feature = feature_names{top1_idx};
eda.top_single_feature = top1_feature;
eda.top_single_feature_r = R_pearson_y(top1_idx);

% Write eda_summary.json (UTF-8)
write_utf8_json(eda_json, eda);
fprintf('  Saved EDA summary -> %s\n', eda_json);
fprintf('  Top single feature: %s (r = %.4f, R^2 = %.4f), Max VIF = %.4f\n', ...
    top1_feature, R_pearson_y(top1_idx), R_pearson_y(top1_idx)^2, max(vif_vals));

%% 2. Leak-Free 80/20 Train/Test Split & 5-Fold Cross-Validation Partition
fprintf('\n[Step 2] Creating Leak-Free 80/20 Split & 5-Fold CV (rng(42))...\n');
rng(42, 'twister');
cv_hold = cvpartition(N, 'HoldOut', 0.20);
idx_train = training(cv_hold);
idx_test  = test(cv_hold);

X_train = X(idx_train, :);
y_train = y(idx_train);
X_test  = X(idx_test, :);
y_test  = y(idx_test);

N_train = size(X_train, 1);
N_test  = size(X_test, 1);

rng(42, 'twister');
K = 5;
cv5 = cvpartition(N_train, 'KFold', K);
fold_train_idx = cell(K, 1);
fold_val_idx   = cell(K, 1);
for k = 1:K
    fold_train_idx{k} = training(cv5, k);
    fold_val_idx{k}   = test(cv5, k);
end
fprintf('  Hold-out split: N_train = %d, N_test = %d | %d-fold CV on training set\n', ...
    N_train, N_test, K);

% Helper to compute CV summary from out-of-fold predictions & per-fold metrics
model_records = {};

%% 3. TIER 1: Single-Variable Curve Fitting (Line vs Parabola on GrLivArea)
fprintf('\n[Step 3 - Tier 1] Single-Variable Curve Fitting (%s: poly1 vs poly2)...\n', top1_feature);
x1_tr = X_train(:, top1_idx);
x1_te = X_test(:, top1_idx);

% --- Model 1a: 1D Linear (poly1) ---
oof_1a = zeros(N_train, 1);
fold_rmse_1a = zeros(K, 1); fold_r2_1a = zeros(K, 1);
for k = 1:K
    tr = fold_train_idx{k}; va = fold_val_idx{k};
    [p1_k, ~, mu1_k] = polyfit(x1_tr(tr), y_train(tr), 1);
    pred_va = polyval(p1_k, x1_tr(va), [], mu1_k);
    oof_1a(va) = pred_va;
    m_k = eval_metrics(y_train(va), pred_va, 1);
    fold_rmse_1a(k) = m_k.rmse; fold_r2_1a(k) = m_k.r2;
end
p1_raw = polyfit(x1_tr, y_train, 1);
mdl_poly1 = fitlm(x1_tr, y_train, 'linear', 'VarNames', {top1_feature, target_name});
pred_1a_tr = polyval(p1_raw, x1_tr);
pred_1a_te = polyval(p1_raw, x1_te);

rec_1a = make_model_record('T1_Single_Linear', 'Tier 1: Single-Var Curve Fit', ...
    '1D Linear (GrLivArea, poly1)', 1, ...
    y_train, pred_1a_tr, oof_1a, fold_rmse_1a, fold_r2_1a, y_test, pred_1a_te);
rec_1a.coefficients_raw = p1_raw(:); % [slope; intercept]
rec_1a.slope_p_value = mdl_poly1.Coefficients.pValue(2);
model_records{end+1} = rec_1a;

% --- Model 1b: 1D Parabolic (poly2) ---
oof_1b = zeros(N_train, 1);
fold_rmse_1b = zeros(K, 1); fold_r2_1b = zeros(K, 1);
for k = 1:K
    tr = fold_train_idx{k}; va = fold_val_idx{k};
    [p2_k, ~, mu2_k] = polyfit(x1_tr(tr), y_train(tr), 2);
    pred_va = polyval(p2_k, x1_tr(va), [], mu2_k);
    oof_1b(va) = pred_va;
    m_k = eval_metrics(y_train(va), pred_va, 2);
    fold_rmse_1b(k) = m_k.rmse; fold_r2_1b(k) = m_k.r2;
end
p2_raw = polyfit(x1_tr, y_train, 2);
mdl_poly2 = fitlm(x1_tr, y_train, 'poly2', 'VarNames', {top1_feature, target_name});
pred_1b_tr = polyval(p2_raw, x1_tr);
pred_1b_te = polyval(p2_raw, x1_te);

rec_1b = make_model_record('T1_Single_Parabolic', 'Tier 1: Single-Var Curve Fit', ...
    '1D Parabolic (GrLivArea, poly2)', 2, ...
    y_train, pred_1b_tr, oof_1b, fold_rmse_1b, fold_r2_1b, y_test, pred_1b_te);
rec_1b.coefficients_raw = p2_raw(:); % [a2; a1; a0]
rec_1b.quad_term_p_value = mdl_poly2.Coefficients.pValue(3);
model_records{end+1} = rec_1b;

fprintf('  1D Linear    : CV RMSE = $%.2f (R2 = %.4f) | Test RMSE = $%.2f (R2 = %.4f)\n', ...
    rec_1a.cv_rmse_mean, rec_1a.cv_r2_mean, rec_1a.test.rmse, rec_1a.test.r2);
fprintf('  1D Parabolic : CV RMSE = $%.2f (R2 = %.4f) | Test RMSE = $%.2f (R2 = %.4f) | quad p = %.4f\n', ...
    rec_1b.cv_rmse_mean, rec_1b.cv_r2_mean, rec_1b.test.rmse, rec_1b.test.r2, rec_1b.quad_term_p_value);

%% 4. TIER 2: Multivariate Linear Regression (OLS via 3 Solvers) + Quadratic Models
fprintf('\n[Step 4 - Tier 2] Multivariate OLS (Normal Eq / Batch GD / fitlm) + Quadratic...\n');

% --- Model 2a: OLS via Manual Normal Equation ---
oof_2a = zeros(N_train, 1);
fold_rmse_2a = zeros(K, 1); fold_r2_2a = zeros(K, 1);
for k = 1:K
    tr = fold_train_idx{k}; va = fold_val_idx{k};
    Xb_tr = [ones(sum(tr), 1), X_train(tr, :)];
    Xb_va = [ones(sum(va), 1), X_train(va, :)];
    beta_k = (Xb_tr' * Xb_tr) \ (Xb_tr' * y_train(tr));
    pred_va = Xb_va * beta_k;
    oof_2a(va) = pred_va;
    m_k = eval_metrics(y_train(va), pred_va, p);
    fold_rmse_2a(k) = m_k.rmse; fold_r2_2a(k) = m_k.r2;
end
Xb_train = [ones(N_train, 1), X_train];
Xb_test  = [ones(N_test, 1), X_test];
beta_ne = (Xb_train' * Xb_train) \ (Xb_train' * y_train);
pred_2a_tr = Xb_train * beta_ne;
pred_2a_te = Xb_test  * beta_ne;

rec_2a = make_model_record('T2_OLS_NormalEq', 'Tier 2: Multivariate Linear & Poly', ...
    'OLS (Normal Equation)', p, ...
    y_train, pred_2a_tr, oof_2a, fold_rmse_2a, fold_r2_2a, y_test, pred_2a_te);
rec_2a.beta_raw = beta_ne;
model_records{end+1} = rec_2a;

% --- Model 2b: OLS via Manual Batch Gradient Descent (standardized inside folds!) ---
gd_lr = 0.05;
gd_max_iter = 2500;
gd_tol = 1e-11;

oof_2b = zeros(N_train, 1);
fold_rmse_2b = zeros(K, 1); fold_r2_2b = zeros(K, 1);
for k = 1:K
    tr = fold_train_idx{k}; va = fold_val_idx{k};
    gd_k = fit_ols_gd(X_train(tr, :), y_train(tr), gd_lr, gd_max_iter, gd_tol);
    Z_va = (X_train(va, :) - gd_k.mu) ./ gd_k.sigma;
    pred_va = Z_va * gd_k.w_std + gd_k.b_std;
    oof_2b(va) = pred_va;
    m_k = eval_metrics(y_train(va), pred_va, p);
    fold_rmse_2b(k) = m_k.rmse; fold_r2_2b(k) = m_k.r2;
end
gd_full = fit_ols_gd(X_train, y_train, gd_lr, gd_max_iter, gd_tol);
Z_tr_gd = (X_train - gd_full.mu) ./ gd_full.sigma;
Z_te_gd = (X_test  - gd_full.mu) ./ gd_full.sigma;
pred_2b_tr = Z_tr_gd * gd_full.w_std + gd_full.b_std;
pred_2b_te = Z_te_gd * gd_full.w_std + gd_full.b_std;

rec_2b = make_model_record('T2_OLS_GradDesc', 'Tier 2: Multivariate Linear & Poly', ...
    'OLS (Manual Batch GD)', p, ...
    y_train, pred_2b_tr, oof_2b, fold_rmse_2b, fold_r2_2b, y_test, pred_2b_te);
rec_2b.beta_raw = gd_full.beta_raw;
rec_2b.gd_lr = gd_lr;
rec_2b.gd_iterations = gd_full.iterations;
rec_2b.gd_final_grad_norm = gd_full.grad_norm_history(end);
model_records{end+1} = rec_2b;

% --- Model 2c: OLS via MATLAB fitlm ---
oof_2c = zeros(N_train, 1);
fold_rmse_2c = zeros(K, 1); fold_r2_2c = zeros(K, 1);
for k = 1:K
    tr = fold_train_idx{k}; va = fold_val_idx{k};
    mdl_k = fitlm(X_train(tr, :), y_train(tr));
    pred_va = predict(mdl_k, X_train(va, :));
    oof_2c(va) = pred_va;
    m_k = eval_metrics(y_train(va), pred_va, p);
    fold_rmse_2c(k) = m_k.rmse; fold_r2_2c(k) = m_k.r2;
end
mdl_ols_train = fitlm(X_train, y_train, 'VarNames', [feature_names, {target_name}]);
beta_fitlm = mdl_ols_train.Coefficients.Estimate;
pred_2c_tr = predict(mdl_ols_train, X_train);
pred_2c_te = predict(mdl_ols_train, X_test);

% Also fit full-dataset OLS for complete inference table (clearly labeled N=300)
mdl_ols_all = fitlm(X, y, 'VarNames', [feature_names, {target_name}]);

rec_2c = make_model_record('T2_OLS_fitlm', 'Tier 2: Multivariate Linear & Poly', ...
    'OLS (MATLAB fitlm)', p, ...
    y_train, pred_2c_tr, oof_2c, fold_rmse_2c, fold_r2_2c, y_test, pred_2c_te);
rec_2c.beta_raw = beta_fitlm;
rec_2c.f_stat = mdl_ols_train.ModelFitVsNullModel.Fstat;
rec_2c.f_pvalue = mdl_ols_train.ModelFitVsNullModel.Pvalue;
model_records{end+1} = rec_2c;

% Verify strict numerical equivalence across all 3 OLS solvers
ols_equiv = struct();
ols_equiv.max_beta_diff_NE_vs_GD    = max(abs(beta_ne - gd_full.beta_raw));
ols_equiv.max_beta_diff_NE_vs_fitlm = max(abs(beta_ne - beta_fitlm));
ols_equiv.max_beta_diff_GD_vs_fitlm = max(abs(gd_full.beta_raw - beta_fitlm));
ols_equiv.max_test_pred_diff_NE_vs_GD    = max(abs(pred_2a_te - pred_2b_te));
ols_equiv.max_test_pred_diff_NE_vs_fitlm = max(abs(pred_2a_te - pred_2c_te));
ols_equiv.max_oof_pred_diff_NE_vs_GD     = max(abs(oof_2a - oof_2b));
ols_equiv.all_equivalent_under_1e6 = (ols_equiv.max_test_pred_diff_NE_vs_GD < 1e-6) && ...
                                     (ols_equiv.max_test_pred_diff_NE_vs_fitlm < 1e-6);

fprintf('  OLS (Normal Eq / GD / fitlm): CV RMSE = $%.2f (R2 = %.4f) | Test RMSE = $%.2f (R2 = %.4f)\n', ...
    rec_2c.cv_rmse_mean, rec_2c.cv_r2_mean, rec_2c.test.rmse, rec_2c.test.r2);
fprintf('  Equivalence check: max |y_hat_NE - y_hat_GD| = %.3e, max |y_hat_NE - y_hat_fitlm| = %.3e\n', ...
    ols_equiv.max_test_pred_diff_NE_vs_GD, ols_equiv.max_test_pred_diff_NE_vs_fitlm);

% --- Model 2d: Multivariate Pure Quadratic (16 terms, leak-free standardized) ---
oof_2d = zeros(N_train, 1);
fold_rmse_2d = zeros(K, 1); fold_r2_2d = zeros(K, 1);
for k = 1:K
    tr = fold_train_idx{k}; va = fold_val_idx{k};
    mu_k = mean(X_train(tr, :), 1); sd_k = std(X_train(tr, :), 0, 1);
    Z_tr_k = (X_train(tr, :) - mu_k) ./ sd_k;
    Z_va_k = (X_train(va, :) - mu_k) ./ sd_k;
    Phi_tr_k = [ones(sum(tr), 1), build_poly_features(Z_tr_k, feature_names, 'purequadratic')];
    Phi_va_k = [ones(sum(va), 1), build_poly_features(Z_va_k, feature_names, 'purequadratic')];
    b_k = Phi_tr_k \ y_train(tr);
    pred_va = Phi_va_k * b_k;
    oof_2d(va) = pred_va;
    m_k = eval_metrics(y_train(va), pred_va, 2*p);
    fold_rmse_2d(k) = m_k.rmse; fold_r2_2d(k) = m_k.r2;
end
mu_tr = mean(X_train, 1); sd_tr = std(X_train, 0, 1);
Z_train = (X_train - mu_tr) ./ sd_tr;
Z_test  = (X_test  - mu_tr) ./ sd_tr;

[Phi_pq_tr, pq_names] = build_poly_features(Z_train, feature_names, 'purequadratic');
Phi_pq_te = build_poly_features(Z_test, feature_names, 'purequadratic');
b_pq = [ones(N_train, 1), Phi_pq_tr] \ y_train;
pred_2d_tr = [ones(N_train, 1), Phi_pq_tr] * b_pq;
pred_2d_te = [ones(N_test, 1),  Phi_pq_te] * b_pq;

rec_2d = make_model_record('T2_PureQuadratic', 'Tier 2: Multivariate Linear & Poly', ...
    'Pure Quadratic (16 terms)', 2*p, ...
    y_train, pred_2d_tr, oof_2d, fold_rmse_2d, fold_r2_2d, y_test, pred_2d_te);
model_records{end+1} = rec_2d;

% --- Model 2e: Multivariate Full Quadratic (44 terms with interactions) ---
p_fq = 2*p + p*(p-1)/2;
oof_2e = zeros(N_train, 1);
fold_rmse_2e = zeros(K, 1); fold_r2_2e = zeros(K, 1);
for k = 1:K
    tr = fold_train_idx{k}; va = fold_val_idx{k};
    mu_k = mean(X_train(tr, :), 1); sd_k = std(X_train(tr, :), 0, 1);
    Z_tr_k = (X_train(tr, :) - mu_k) ./ sd_k;
    Z_va_k = (X_train(va, :) - mu_k) ./ sd_k;
    Phi_tr_k = [ones(sum(tr), 1), build_poly_features(Z_tr_k, feature_names, 'quadratic')];
    Phi_va_k = [ones(sum(va), 1), build_poly_features(Z_va_k, feature_names, 'quadratic')];
    b_k = Phi_tr_k \ y_train(tr);
    pred_va = Phi_va_k * b_k;
    oof_2e(va) = pred_va;
    m_k = eval_metrics(y_train(va), pred_va, p_fq);
    fold_rmse_2e(k) = m_k.rmse; fold_r2_2e(k) = m_k.r2;
end
Phi_fq_tr = build_poly_features(Z_train, feature_names, 'quadratic');
Phi_fq_te = build_poly_features(Z_test,  feature_names, 'quadratic');
b_fq = [ones(N_train, 1), Phi_fq_tr] \ y_train;
pred_2e_tr = [ones(N_train, 1), Phi_fq_tr] * b_fq;
pred_2e_te = [ones(N_test, 1),  Phi_fq_te] * b_fq;

rec_2e = make_model_record('T2_FullQuadratic', 'Tier 2: Multivariate Linear & Poly', ...
    'Full Quadratic (44 terms)', p_fq, ...
    y_train, pred_2e_tr, oof_2e, fold_rmse_2e, fold_r2_2e, y_test, pred_2e_te);
model_records{end+1} = rec_2e;

% --- Model 2f: Partial Quadratic (8 linear + GrLivArea^2 + TotalBsmtSF^2, 10 terms) ---
quad_cols = [2, 4]; % GrLivArea, TotalBsmtSF
oof_2f = zeros(N_train, 1);
fold_rmse_2f = zeros(K, 1); fold_r2_2f = zeros(K, 1);
for k = 1:K
    tr = fold_train_idx{k}; va = fold_val_idx{k};
    mu_k = mean(X_train(tr, :), 1); sd_k = std(X_train(tr, :), 0, 1);
    Z_tr_k = (X_train(tr, :) - mu_k) ./ sd_k;
    Z_va_k = (X_train(va, :) - mu_k) ./ sd_k;
    Phi_tr_k = [ones(sum(tr), 1), Z_tr_k, Z_tr_k(:, quad_cols).^2];
    Phi_va_k = [ones(sum(va), 1), Z_va_k, Z_va_k(:, quad_cols).^2];
    b_k = Phi_tr_k \ y_train(tr);
    pred_va = Phi_va_k * b_k;
    oof_2f(va) = pred_va;
    m_k = eval_metrics(y_train(va), pred_va, p + numel(quad_cols));
    fold_rmse_2f(k) = m_k.rmse; fold_r2_2f(k) = m_k.r2;
end
Phi_part_tr = [ones(N_train, 1), Z_train, Z_train(:, quad_cols).^2];
Phi_part_te = [ones(N_test, 1),  Z_test,  Z_test(:, quad_cols).^2];
b_part = Phi_part_tr \ y_train;
pred_2f_tr = Phi_part_tr * b_part;
pred_2f_te = Phi_part_te * b_part;

rec_2f = make_model_record('T2_PartialQuadratic', 'Tier 2: Multivariate Linear & Poly', ...
    'Partial Quadratic (GrLivArea+TotalBsmtSF^2, 10 terms)', p + numel(quad_cols), ...
    y_train, pred_2f_tr, oof_2f, fold_rmse_2f, fold_r2_2f, y_test, pred_2f_te);
model_records{end+1} = rec_2f;

fprintf('  Pure Quadratic (16)    : CV RMSE = $%.2f (R2 = %.4f) | Train R2 = %.4f | Test RMSE = $%.2f\n', ...
    rec_2d.cv_rmse_mean, rec_2d.cv_r2_mean, rec_2d.train.r2, rec_2d.test.rmse);
fprintf('  Full Quadratic (44)    : CV RMSE = $%.2f (R2 = %.4f) | Train R2 = %.4f | Test RMSE = $%.2f\n', ...
    rec_2e.cv_rmse_mean, rec_2e.cv_r2_mean, rec_2e.train.r2, rec_2e.test.rmse);
fprintf('  Partial Quadratic (10) : CV RMSE = $%.2f (R2 = %.4f) | Test RMSE = $%.2f (R2 = %.4f)\n', ...
    rec_2f.cv_rmse_mean, rec_2f.cv_r2_mean, rec_2f.test.rmse, rec_2f.test.r2);

%% 5. TIER 3: Regularized Linear Regression (Ridge L2 & Lasso L1)
fprintf('\n[Step 5 - Tier 3] Regularized Regression (Ridge L2 & Lasso L1, leak-free 5-fold CV)...\n');

% --- Model 3a: Ridge Regression (L2) ---
% Minimize ||y - b0 - Z*w||_2^2 + lambda * ||w||_2^2 (standardized strictly inside folds)
ridge_lambdas = [0, logspace(-4, 2.5, 130)];
n_rl = numel(ridge_lambdas);
ridge_cv_mse = zeros(K, n_rl);
ridge_oof_mat = zeros(N_train, n_rl);

for k = 1:K
    tr = fold_train_idx{k}; va = fold_val_idx{k};
    mu_k = mean(X_train(tr, :), 1); sd_k = std(X_train(tr, :), 0, 1);
    Z_tr_k = (X_train(tr, :) - mu_k) ./ sd_k;
    Z_va_k = (X_train(va, :) - mu_k) ./ sd_k;
    y_tr_k = y_train(tr);
    y_va_k = y_train(va);
    y_bar_k = mean(y_tr_k);
    ZtZ = Z_tr_k' * Z_tr_k;
    Zty = Z_tr_k' * (y_tr_k - y_bar_k);

    for li = 1:n_rl
        lam = ridge_lambdas(li);
        w_k = (ZtZ + lam * eye(p)) \ Zty;
        pred_va = y_bar_k + Z_va_k * w_k;
        ridge_oof_mat(va, li) = pred_va;
        ridge_cv_mse(k, li) = mean((y_va_k - pred_va).^2);
    end
end

ridge_cv_rmse_grid = sqrt(mean(ridge_cv_mse, 1));
[~, best_r_idx] = min(ridge_cv_rmse_grid);
best_ridge_lambda = ridge_lambdas(best_r_idx);

% Refit Ridge on full training set with best_ridge_lambda
y_bar_tr = mean(y_train);
w_ridge_std = (Z_train' * Z_train + best_ridge_lambda * eye(p)) \ (Z_train' * (y_train - y_bar_tr));
pred_3a_tr = y_bar_tr + Z_train * w_ridge_std;
pred_3a_te = y_bar_tr + Z_test  * w_ridge_std;
oof_3a = ridge_oof_mat(:, best_r_idx);

fold_rmse_3a = zeros(K, 1); fold_r2_3a = zeros(K, 1);
for k = 1:K
    va = fold_val_idx{k};
    m_k = eval_metrics(y_train(va), oof_3a(va), p);
    fold_rmse_3a(k) = m_k.rmse; fold_r2_3a(k) = m_k.r2;
end

% Cross-check closed-form Ridge with MATLAB built-in ridge()
b_builtin_ridge = ridge(y_train, Z_train, best_ridge_lambda, 0);
ridge_builtin_diff = max(abs([y_bar_tr; w_ridge_std] - b_builtin_ridge));

rec_3a = make_model_record('T3_Ridge_L2', 'Tier 3: Regularized Linear', ...
    'Ridge Regression (L2)', p, ...
    y_train, pred_3a_tr, oof_3a, fold_rmse_3a, fold_r2_3a, y_test, pred_3a_te);
rec_3a.best_lambda = best_ridge_lambda;
rec_3a.w_std = w_ridge_std;
rec_3a.builtin_ridge_max_diff = ridge_builtin_diff;
model_records{end+1} = rec_3a;

% --- Model 3b: Lasso Regression (L1) + Full Regularization Path ---
% Determine lambda_max on standardized training data: max(|Z'*yc|)/N_train
yc_tr = y_train - mean(y_train);
lam_max = max(abs(Z_train' * yc_tr)) / N_train;
% Build dense log-spaced lambda grid from lam_max*1.05 down to 1e-1
lasso_lambdas = logspace(log10(lam_max * 1.05), log10(1.0), 120);
n_ll = numel(lasso_lambdas);

lasso_cv_mse = zeros(K, n_ll);
lasso_oof_mat = zeros(N_train, n_ll);

for k = 1:K
    tr = fold_train_idx{k}; va = fold_val_idx{k};
    mu_k = mean(X_train(tr, :), 1); sd_k = std(X_train(tr, :), 0, 1);
    Z_tr_k = (X_train(tr, :) - mu_k) ./ sd_k;
    Z_va_k = (X_train(va, :) - mu_k) ./ sd_k;
    y_tr_k = y_train(tr);
    y_va_k = y_train(va);

    [B_k, Info_k] = lasso(Z_tr_k, y_tr_k, 'Lambda', lasso_lambdas, 'Standardize', false);
    % Map Info_k.Lambda order back to lasso_lambdas order safely
    [~, order_idx] = ismember(lasso_lambdas, Info_k.Lambda);
    if any(order_idx == 0)
        % Fallback nearest match if floating precision differs
        order_idx = zeros(1, n_ll);
        for li = 1:n_ll
            [~, order_idx(li)] = min(abs(Info_k.Lambda - lasso_lambdas(li)));
        end
    end
    B_k = B_k(:, order_idx);
    Int_k = Info_k.Intercept(order_idx);

    preds_va = Z_va_k * B_k + Int_k; % N_va x n_ll
    lasso_oof_mat(va, :) = preds_va;
    lasso_cv_mse(k, :) = mean((y_va_k - preds_va).^2, 1);
end

lasso_mean_mse = mean(lasso_cv_mse, 1);
lasso_se_mse   = std(lasso_cv_mse, 0, 1) / sqrt(K);
[min_lasso_mse, idx_min_mse] = min(lasso_mean_mse);
lam_min = lasso_lambdas(idx_min_mse);

% 1-SE rule: largest lambda whose CV MSE <= min_mse + SE(min_mse)
se_thresh = min_lasso_mse + lasso_se_mse(idx_min_mse);
valid_1se = find(lasso_mean_mse <= se_thresh);
[~, rel_max] = max(lasso_lambdas(valid_1se));
idx_1se = valid_1se(rel_max);
lam_1se = lasso_lambdas(idx_1se);

% Compute full Lasso path on full training standardized data (Z_train)
[B_path_raw, Info_path] = lasso(Z_train, y_train, 'Lambda', lasso_lambdas, 'Standardize', false);
order_p = zeros(1, n_ll);
for li = 1:n_ll
    [~, order_p(li)] = min(abs(Info_path.Lambda - lasso_lambdas(li)));
end
B_lasso_path = B_path_raw(:, order_p);       % p x n_ll (ordered high lambda -> low lambda)
Int_lasso_path = Info_path.Intercept(order_p);

% Predictions for Lasso at lambda_min
w_lasso_min = B_lasso_path(:, idx_min_mse);
b0_lasso_min = Int_lasso_path(idx_min_mse);
pred_3b_tr = Z_train * w_lasso_min + b0_lasso_min;
pred_3b_te = Z_test  * w_lasso_min + b0_lasso_min;
oof_3b = lasso_oof_mat(:, idx_min_mse);

fold_rmse_3b = zeros(K, 1); fold_r2_3b = zeros(K, 1);
for k = 1:K
    va = fold_val_idx{k};
    m_k = eval_metrics(y_train(va), oof_3b(va), sum(abs(w_lasso_min) > 1e-6));
    fold_rmse_3b(k) = m_k.rmse; fold_r2_3b(k) = m_k.r2;
end

rec_3b = make_model_record('T3_Lasso_L1', 'Tier 3: Regularized Linear', ...
    'Lasso Regression (L1)', sum(abs(w_lasso_min) > 1e-6), ...
    y_train, pred_3b_tr, oof_3b, fold_rmse_3b, fold_r2_3b, y_test, pred_3b_te);
rec_3b.lambda_min = lam_min;
rec_3b.lambda_1se = lam_1se;
rec_3b.w_std_min = w_lasso_min;
rec_3b.w_std_1se = B_lasso_path(:, idx_1se);
rec_3b.nonzero_count_min = sum(abs(w_lasso_min) > 1e-6);
rec_3b.nonzero_count_1se = sum(abs(B_lasso_path(:, idx_1se)) > 1e-6);
rec_3b.cv_rmse_1se = sqrt(lasso_mean_mse(idx_1se));
pred_3b_1se_te = Z_test * B_lasso_path(:, idx_1se) + Int_lasso_path(idx_1se);
rec_3b.test_1se = eval_metrics(y_test, pred_3b_1se_te, rec_3b.nonzero_count_1se);
model_records{end+1} = rec_3b;

fprintf('  Ridge (L2, lam=%.4f) : CV RMSE = $%.2f (R2 = %.4f) | Test RMSE = $%.2f (R2 = %.4f)\n', ...
    best_ridge_lambda, rec_3a.cv_rmse_mean, rec_3a.cv_r2_mean, rec_3a.test.rmse, rec_3a.test.r2);
fprintf('  Lasso (L1, lam_min=%.2f, nz=%d) : CV RMSE = $%.2f (R2 = %.4f) | Test RMSE = $%.2f (R2 = %.4f)\n', ...
    lam_min, rec_3b.nonzero_count_min, rec_3b.cv_rmse_mean, rec_3b.cv_r2_mean, rec_3b.test.rmse, rec_3b.test.r2);
fprintf('  Lasso (L1, lam_1se=%.2f, nz=%d) : CV RMSE = $%.2f | Test RMSE = $%.2f (R2 = %.4f)\n', ...
    lam_1se, rec_3b.nonzero_count_1se, rec_3b.cv_rmse_1se, rec_3b.test_1se.rmse, rec_3b.test_1se.r2);

%% 6. TIER 4: Tree & Ensemble Non-Linear Models (Decision Tree, Random Forest, GBDT)
fprintf('\n[Step 6 - Tier 4] Tree & Ensemble Non-Linear Models (CV-tuned for N=300)...\n');

% --- Model 4a: Regression Decision Tree (fitrtree) ---
leaf_grid = [3, 5, 8, 10, 12, 15, 20];
best_dt_rmse = inf; best_dt_leaf = 5;
best_dt_oof = zeros(N_train, 1);
best_dt_fold_rmse = zeros(K, 1); best_dt_fold_r2 = zeros(K, 1);

for ml = leaf_grid
    oof_tmp = zeros(N_train, 1);
    fr_tmp = zeros(K, 1); fr2_tmp = zeros(K, 1);
    for k = 1:K
        tr = fold_train_idx{k}; va = fold_val_idx{k};
        rng(42 + k, 'twister');
        mdl_k = fitrtree(X_train(tr, :), y_train(tr), 'MinLeafSize', ml);
        pred_va = predict(mdl_k, X_train(va, :));
        oof_tmp(va) = pred_va;
        m_k = eval_metrics(y_train(va), pred_va, p);
        fr_tmp(k) = m_k.rmse; fr2_tmp(k) = m_k.r2;
    end
    if mean(fr_tmp) < best_dt_rmse
        best_dt_rmse = mean(fr_tmp);
        best_dt_leaf = ml;
        best_dt_oof = oof_tmp;
        best_dt_fold_rmse = fr_tmp;
        best_dt_fold_r2 = fr2_tmp;
    end
end
rng(42, 'twister');
mdl_dt = fitrtree(X_train, y_train, 'MinLeafSize', best_dt_leaf, 'PredictorNames', feature_names);
pred_4a_tr = predict(mdl_dt, X_train);
pred_4a_te = predict(mdl_dt, X_test);

rec_4a = make_model_record('T4_DecisionTree', 'Tier 4: Tree & Ensemble', ...
    'Decision Tree (fitrtree)', p, ...
    y_train, pred_4a_tr, best_dt_oof, best_dt_fold_rmse, best_dt_fold_r2, y_test, pred_4a_te);
rec_4a.best_min_leaf_size = best_dt_leaf;
rec_4a.num_nodes = mdl_dt.NumNodes;
model_records{end+1} = rec_4a;

% --- Model 4b: Random Forest (TreeBagger with OOBPredictorImportance='on') ---
rf_leaf_grid = [2, 4, 6];
rf_mtry_grid = [3, 5, 7];
rf_ntrees_cv = 200;
best_rf_rmse = inf; best_rf_leaf = 2; best_rf_mtry = 5;
best_rf_oof = zeros(N_train, 1);
best_rf_fold_rmse = zeros(K, 1); best_rf_fold_r2 = zeros(K, 1);

for ml = rf_leaf_grid
    for mtry = rf_mtry_grid
        oof_tmp = zeros(N_train, 1);
        fr_tmp = zeros(K, 1); fr2_tmp = zeros(K, 1);
        for k = 1:K
            tr = fold_train_idx{k}; va = fold_val_idx{k};
            rng(42 + k, 'twister');
            rf_k = TreeBagger(rf_ntrees_cv, X_train(tr, :), y_train(tr), ...
                'Method', 'regression', 'MinLeafSize', ml, ...
                'NumPredictorsToSample', mtry);
            pred_va = predict(rf_k, X_train(va, :));
            oof_tmp(va) = pred_va;
            m_k = eval_metrics(y_train(va), pred_va, p);
            fr_tmp(k) = m_k.rmse; fr2_tmp(k) = m_k.r2;
        end
        if mean(fr_tmp) < best_rf_rmse
            best_rf_rmse = mean(fr_tmp);
            best_rf_leaf = ml;
            best_rf_mtry = mtry;
            best_rf_oof = oof_tmp;
            best_rf_fold_rmse = fr_tmp;
            best_rf_fold_r2 = fr2_tmp;
        end
    end
end

% Refit final Random Forest with 500 trees & OOBPredictorImportance='on'
rng(42, 'twister');
rf_ntrees_final = 500;
mdl_rf = TreeBagger(rf_ntrees_final, X_train, y_train, ...
    'Method', 'regression', ...
    'MinLeafSize', best_rf_leaf, ...
    'NumPredictorsToSample', best_rf_mtry, ...
    'OOBPrediction', 'on', ...
    'OOBPredictorImportance', 'on', ...
    'PredictorNames', feature_names);
pred_4b_tr = predict(mdl_rf, X_train);
pred_4b_te = predict(mdl_rf, X_test);
pred_4b_oob = oobPredict(mdl_rf);
m_rf_oob = eval_metrics(y_train, pred_4b_oob, p);
rf_oob_imp = mdl_rf.OOBPermutedPredictorDeltaError(:);

rec_4b = make_model_record('T4_RandomForest', 'Tier 4: Tree & Ensemble', ...
    'Random Forest (TreeBagger)', p, ...
    y_train, pred_4b_tr, best_rf_oof, best_rf_fold_rmse, best_rf_fold_r2, y_test, pred_4b_te);
rec_4b.best_min_leaf_size = best_rf_leaf;
rec_4b.best_mtry = best_rf_mtry;
rec_4b.num_trees = rf_ntrees_final;
rec_4b.oob_rmse = m_rf_oob.rmse;
rec_4b.oob_r2 = m_rf_oob.r2;
model_records{end+1} = rec_4b;

% --- Model 4c: Gradient Boosted Decision Trees - GBDT (fitrensemble LSBoost) ---
% Include MaxNumSplits=1 (stumps -> purely additive) & 2, 4 to avoid overfitting on N=240
gb_splits_grid = [1, 2, 4];
gb_lr_grid     = [0.05, 0.10];
gb_cycles_grid = [150, 300];
best_gb_rmse = inf; best_gb_splits = 1; best_gb_lr = 0.05; best_gb_cycles = 300;
best_gb_oof = zeros(N_train, 1);
best_gb_fold_rmse = zeros(K, 1); best_gb_fold_r2 = zeros(K, 1);

for ms = gb_splits_grid
    for lr_g = gb_lr_grid
        for nc = gb_cycles_grid
            oof_tmp = zeros(N_train, 1);
            fr_tmp = zeros(K, 1); fr2_tmp = zeros(K, 1);
            t_learner = templateTree('MaxNumSplits', ms, 'MinLeafSize', 5);
            for k = 1:K
                tr = fold_train_idx{k}; va = fold_val_idx{k};
                rng(42 + k, 'twister');
                gb_k = fitrensemble(X_train(tr, :), y_train(tr), ...
                    'Method', 'LSBoost', ...
                    'NumLearningCycles', nc, ...
                    'LearnRate', lr_g, ...
                    'Learners', t_learner);
                pred_va = predict(gb_k, X_train(va, :));
                oof_tmp(va) = pred_va;
                m_k = eval_metrics(y_train(va), pred_va, p);
                fr_tmp(k) = m_k.rmse; fr2_tmp(k) = m_k.r2;
            end
            if mean(fr_tmp) < best_gb_rmse
                best_gb_rmse = mean(fr_tmp);
                best_gb_splits = ms;
                best_gb_lr = lr_g;
                best_gb_cycles = nc;
                best_gb_oof = oof_tmp;
                best_gb_fold_rmse = fr_tmp;
                best_gb_fold_r2 = fr2_tmp;
            end
        end
    end
end

rng(42, 'twister');
t_best = templateTree('MaxNumSplits', best_gb_splits, 'MinLeafSize', 5);
mdl_gb = fitrensemble(X_train, y_train, ...
    'Method', 'LSBoost', ...
    'NumLearningCycles', best_gb_cycles, ...
    'LearnRate', best_gb_lr, ...
    'Learners', t_best, ...
    'PredictorNames', feature_names);
pred_4c_tr = predict(mdl_gb, X_train);
pred_4c_te = predict(mdl_gb, X_test);

rec_4c = make_model_record('T4_GBDT_LSBoost', 'Tier 4: Tree & Ensemble', ...
    'GBDT (LSBoost)', p, ...
    y_train, pred_4c_tr, best_gb_oof, best_gb_fold_rmse, best_gb_fold_r2, y_test, pred_4c_te);
rec_4c.best_max_num_splits = best_gb_splits;
rec_4c.best_learn_rate = best_gb_lr;
rec_4c.best_num_cycles = best_gb_cycles;
model_records{end+1} = rec_4c;

fprintf('  Decision Tree (leaf=%d) : CV RMSE = $%.2f (R2 = %.4f) | Test RMSE = $%.2f (R2 = %.4f)\n', ...
    best_dt_leaf, rec_4a.cv_rmse_mean, rec_4a.cv_r2_mean, rec_4a.test.rmse, rec_4a.test.r2);
fprintf('  Random Forest (leaf=%d, mtry=%d) : CV RMSE = $%.2f (R2 = %.4f) | OOB RMSE = $%.2f | Test RMSE = $%.2f (R2 = %.4f)\n', ...
    best_rf_leaf, best_rf_mtry, rec_4b.cv_rmse_mean, rec_4b.cv_r2_mean, rec_4b.oob_rmse, rec_4b.test.rmse, rec_4b.test.r2);
fprintf('  GBDT LSBoost (splits=%d, lr=%.2f, cyc=%d) : CV RMSE = $%.2f (R2 = %.4f) | Test RMSE = $%.2f (R2 = %.4f)\n', ...
    best_gb_splits, best_gb_lr, best_gb_cycles, rec_4c.cv_rmse_mean, rec_4c.cv_r2_mean, rec_4c.test.rmse, rec_4c.test.r2);

%% 7. Identify Overall Best Model (by 5-Fold CV RMSE) & Residual Diagnostics
cv_rmses_all = cellfun(@(r) r.cv_rmse_mean, model_records);
[~, best_model_idx] = min(cv_rmses_all);
best_rec = model_records{best_model_idx};
fprintf('\n[Step 7] Best Model by 5-Fold CV RMSE: %s (CV RMSE = $%.2f, Test RMSE = $%.2f, Test R2 = %.4f)\n', ...
    best_rec.display_name, best_rec.cv_rmse_mean, best_rec.test.rmse, best_rec.test.r2);

% Get best model train/test predictions for diagnostic plots
switch best_rec.id
    case 'T3_Lasso_L1'
        best_pred_tr = pred_3b_tr; best_pred_te = pred_3b_te;
    case 'T3_Ridge_L2'
        best_pred_tr = pred_3a_tr; best_pred_te = pred_3a_te;
    otherwise
        best_pred_tr = pred_2c_tr; best_pred_te = pred_2c_te;
end
resid_tr = y_train - best_pred_tr;
resid_te = y_test  - best_pred_te;
[jb_h, jb_p, jb_stat] = jbtest([resid_tr; resid_te]);

diag_info = struct();
diag_info.best_model_id = best_rec.id;
diag_info.best_model_name = best_rec.display_name;
diag_info.train_resid_mean = mean(resid_tr);
diag_info.train_resid_std  = std(resid_tr, 0);
diag_info.test_resid_mean  = mean(resid_te);
diag_info.test_resid_std   = std(resid_te, 0);
diag_info.all_resid_min    = min([resid_tr; resid_te]);
diag_info.all_resid_max    = max([resid_tr; resid_te]);
diag_info.all_resid_kurtosis = kurtosis([resid_tr; resid_te], 0);
diag_info.jarque_bera_reject_normal = logical(jb_h);
diag_info.jarque_bera_p = jb_p;
diag_info.jarque_bera_stat = jb_stat;
fprintf('  Residual normality (Jarque-Bera): stat = %.4f, p = %.4f (reject_normal = %d)\n', ...
    jb_stat, jb_p, jb_h);

%% 8. 4 Complementary Feature Contribution Evaluation Methods (Top-3 Analysis)
fprintf('\n[Step 8] Evaluating Feature Contributions Across 4 Complementary Methods...\n');

% --- Method A: Standardized OLS Coefficients |beta_j*| (on training set N=240 + full N=300 check) ---
mdl_ols_std_tr = fitlm(Z_train, y_train, 'VarNames', [feature_names, {target_name}]);
beta_std_tr = mdl_ols_std_tr.Coefficients.Estimate(2:end);
beta_std_se = mdl_ols_std_tr.Coefficients.SE(2:end);
beta_std_t  = mdl_ols_std_tr.Coefficients.tStat(2:end);
beta_std_p  = mdl_ols_std_tr.Coefficients.pValue(2:end);
abs_beta_std = abs(beta_std_tr);
share_beta_std = abs_beta_std / sum(abs_beta_std) * 100;

% Full-dataset standardized OLS check (N=300)
mdl_ols_std_all = fitlm(Z_all, y, 'VarNames', [feature_names, {target_name}]);
beta_std_all = mdl_ols_std_all.Coefficients.Estimate(2:end);

[~, ord_A] = sort(abs_beta_std, 'descend');
rank_A = invert_order_to_rank(ord_A);

% --- Method B: Leave-One-Feature-Out (Drop-Column) CV Marginal Contribution + Univariate R^2 ---
base_cv_rmse = rec_2c.cv_rmse_mean;
base_cv_r2   = rec_2c.cv_r2_mean;
drop_cv_rmse = zeros(p, 1);
drop_cv_r2   = zeros(p, 1);
delta_cv_rmse = zeros(p, 1);
delta_cv_r2   = zeros(p, 1);

for j = 1:p
    keep_cols = setdiff(1:p, j);
    fr_j = zeros(K, 1); fr2_j = zeros(K, 1);
    for k = 1:K
        tr = fold_train_idx{k}; va = fold_val_idx{k};
        Xb_tr_j = [ones(sum(tr), 1), X_train(tr, keep_cols)];
        Xb_va_j = [ones(sum(va), 1), X_train(va, keep_cols)];
        b_jk = (Xb_tr_j' * Xb_tr_j) \ (Xb_tr_j' * y_train(tr));
        pred_va = Xb_va_j * b_jk;
        m_jk = eval_metrics(y_train(va), pred_va, p - 1);
        fr_j(k) = m_jk.rmse; fr2_j(k) = m_jk.r2;
    end
    drop_cv_rmse(j) = mean(fr_j);
    drop_cv_r2(j)   = mean(fr2_j);
    delta_cv_rmse(j) = drop_cv_rmse(j) - base_cv_rmse;
    delta_cv_r2(j)   = base_cv_r2 - drop_cv_r2(j);
end

[~, ord_B] = sort(delta_cv_rmse, 'descend');
rank_B = invert_order_to_rank(ord_B);

% Univariate R^2 on training set (and full dataset)
r_uni_tr = corr(X_train, y_train, 'Type', 'Pearson');
r2_uni_tr = r_uni_tr.^2;
r2_uni_all = R_pearson_y.^2;
[~, ord_Uni] = sort(r2_uni_all, 'descend');
rank_Uni = invert_order_to_rank(ord_Uni);

% --- Method C: Lasso Regularization Path Entry Order & Retained Coefficients ---
% Track largest lambda where |beta_j(lambda)| > 1e-3 (in $ units on Z-scored X)
lasso_entry_lambda = zeros(p, 1);
for j = 1:p
    nz_idx = find(abs(B_lasso_path(j, :)) > 1e-3, 1, 'first');
    if ~isempty(nz_idx)
        lasso_entry_lambda(j) = lasso_lambdas(nz_idx);
    else
        lasso_entry_lambda(j) = 0;
    end
end
[~, ord_C] = sort(lasso_entry_lambda, 'descend');
rank_C = invert_order_to_rank(ord_C);

% --- Method D: Random Forest OOB Permutation Importance ---
[~, ord_D] = sort(rf_oob_imp, 'descend');
rank_D = invert_order_to_rank(ord_D);

% --- Unified Consensus Ranking Table ---
rank_matrix = [rank_A, rank_B, rank_C, rank_D];
mean_rank = mean(rank_matrix, 2);
[~, consensus_ord] = sort(mean_rank, 'ascend');
consensus_rank = invert_order_to_rank(consensus_ord);

% Compute pairwise Spearman rank correlations across the 4 methods
rank_corr_4methods = corr(rank_matrix, 'Type', 'Spearman');

fi_table = [];
fprintf('\n  %-14s | %-9s | %-9s | %-9s | %-9s | %-6s | Ranks [A,B,C,D] | Mean\n', ...
    'Feature', '|beta*|', 'dRMSE_CV', 'Uni R2', 'RF_Perm', 'EntryL');
fprintf('  ----------------------------------------------------------------------------------------------\n');
for idx = 1:p
    j = consensus_ord(idx);
    row = struct();
    row.consensus_rank = consensus_rank(j);
    row.feature = feature_names{j};
    row.feature_cn = feature_cn{j};
    row.ols_raw_beta_train = beta_fitlm(j + 1);
    row.ols_raw_beta_full  = mdl_ols_all.Coefficients.Estimate(j + 1);
    row.ols_std_beta_train = beta_std_tr(j);
    row.ols_std_beta_full  = beta_std_all(j);
    row.ols_std_abs_beta   = abs_beta_std(j);
    row.ols_std_share_pct  = share_beta_std(j);
    row.ols_tstat_train    = beta_std_t(j);
    row.ols_pvalue_train   = beta_std_p(j);
    row.ols_pvalue_full    = mdl_ols_all.Coefficients.pValue(j + 1);
    row.drop_cv_rmse       = drop_cv_rmse(j);
    row.delta_cv_rmse      = delta_cv_rmse(j);
    row.delta_cv_r2        = delta_cv_r2(j);
    row.univariate_r_all   = R_pearson_y(j);
    row.univariate_r2_all  = r2_uni_all(j);
    row.univariate_r2_train = r2_uni_tr(j);
    row.lasso_entry_lambda = lasso_entry_lambda(j);
    row.lasso_beta_min     = rec_3b.w_std_min(j);
    row.lasso_beta_1se     = rec_3b.w_std_1se(j);
    row.rf_oob_perm_imp    = rf_oob_imp(j);
    row.rank_methodA_stdOLS = rank_A(j);
    row.rank_methodB_dropCV = rank_B(j);
    row.rank_methodB_uniR2  = rank_Uni(j);
    row.rank_methodC_lasso  = rank_C(j);
    row.rank_methodD_rfPerm = rank_D(j);
    row.mean_rank_4methods  = mean_rank(j);
    if idx == 1
        fi_table = repmat(row, p, 1);
    else
        fi_table(idx) = row;
    end

    fprintf('  %-14s | $%8.1f | $%8.1f | %9.4f | %9.4f | %6.0f | [%d, %d, %d, %d]    | %.2f\n', ...
        feature_names{j}, abs_beta_std(j), delta_cv_rmse(j), r2_uni_all(j), ...
        rf_oob_imp(j), lasso_entry_lambda(j), rank_A(j), rank_B(j), rank_C(j), rank_D(j), mean_rank(j));
end

top3_features = feature_names(consensus_ord(1:3));
top3_all_agree = isequal(ord_A(1:3), ord_B(1:3)) && isequal(ord_A(1:3), ord_C(1:3)) && ...
                 isequal(ord_A(1:3), ord_D(1:3));
fprintf('\n  >>> Consensus Top 3 Features: 1) %s, 2) %s, 3) %s (Exact Top-3 order identical across all 4 methods: %d)\n', ...
    top3_features{1}, top3_features{2}, top3_features{3}, top3_all_agree);

%% 9. Generate All 5 Publication-Grade Figures (300 DPI, Pure White Background)
fprintf('\n[Step 9] Generating 5 Publication-Grade Figures (300 DPI)...\n');

plot_data = struct();
plot_data.fig_dir = fig_dir;
plot_data.feature_names = feature_names;
plot_data.feature_cn = feature_cn;
plot_data.eda_vars = eda_vars;
plot_data.R_full = R_full;
plot_data.y = y;
plot_data.X_train = X_train;
plot_data.y_train = y_train;
plot_data.X_test = X_test;
plot_data.y_test = y_test;
plot_data.top1_idx = top1_idx;
plot_data.top1_feature = top1_feature;
plot_data.mdl_poly1 = mdl_poly1;
plot_data.mdl_poly2 = mdl_poly2;
plot_data.rec_1a = rec_1a;
plot_data.rec_1b = rec_1b;
plot_data.model_records = model_records;
plot_data.best_rec = best_rec;
plot_data.best_pred_tr = best_pred_tr;
plot_data.best_pred_te = best_pred_te;
plot_data.diag_info = diag_info;
plot_data.gd_full = gd_full;
plot_data.ols_ne_train_mse = mean((y_train - pred_2a_tr).^2);
plot_data.ols_equiv = ols_equiv;
plot_data.lasso_lambdas = lasso_lambdas;
plot_data.B_lasso_path = B_lasso_path;
plot_data.lam_min = lam_min;
plot_data.lam_1se = lam_1se;
plot_data.lasso_entry_lambda = lasso_entry_lambda;
plot_data.abs_beta_std = abs_beta_std;
plot_data.delta_cv_rmse = delta_cv_rmse;
plot_data.r2_uni_all = r2_uni_all;
plot_data.R_pearson_y = R_pearson_y;
plot_data.rf_oob_imp = rf_oob_imp;
plot_data.top3_indices = consensus_ord(1:3);

fig_paths = generate_figures(plot_data);
for fi = 1:numel(fig_paths)
    fprintf('  Exported -> %s\n', fig_paths{fi});
end

%% 10. Save Complete Results Summary JSON (UTF-8)
fprintf('\n[Step 10] Exporting complete results_summary.json...\n');

results = struct();
results.metadata = struct( ...
    'project', 'House Price Regression Modeling & Top-3 Feature Contribution Analysis', ...
    'student', '裴翰章 (2025310104015)', ...
    'instructor', '梁菁', ...
    'matlab_version', version, ...
    'random_seed', 42, ...
    'train_test_split', '80/20 holdout (240 train / 60 test)', ...
    'cv_scheme', '5-fold CV strictly inside training set (leak-free scaling inside folds)', ...
    'generated_at', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));

results.dataset_summary = struct( ...
    'n_total', N, 'n_train', N_train, 'n_test', N_test, ...
    'n_features', p, 'excluded_columns', {{'Id'}}, ...
    'feature_names', {feature_names}, 'feature_names_cn', {feature_cn}, ...
    'target_name', target_name, ...
    'saleprice_mean', mean(y), 'saleprice_std', std(y, 0), ...
    'saleprice_median', median(y), 'saleprice_min', min(y), 'saleprice_max', max(y), ...
    'saleprice_skewness', skewness(y, 0), ...
    'max_vif', max(vif_vals), 'max_interfeature_abs_r', eda.max_interfeature_abs_r, ...
    'condition_number_std_X', cond_X_std);

% OLS detailed inference table (Train N=240 and Full N=300)
ols_terms = [{'Intercept'}, feature_names];
ols_inf_tr = [];
ols_inf_all = [];
for j = 1:(p + 1)
    s_tr = struct( ...
        'term', ols_terms{j}, ...
        'estimate', mdl_ols_train.Coefficients.Estimate(j), ...
        'se', mdl_ols_train.Coefficients.SE(j), ...
        'tStat', mdl_ols_train.Coefficients.tStat(j), ...
        'pValue', mdl_ols_train.Coefficients.pValue(j));
    s_all = struct( ...
        'term', ols_terms{j}, ...
        'estimate', mdl_ols_all.Coefficients.Estimate(j), ...
        'se', mdl_ols_all.Coefficients.SE(j), ...
        'tStat', mdl_ols_all.Coefficients.tStat(j), ...
        'pValue', mdl_ols_all.Coefficients.pValue(j));
    if j == 1
        ols_inf_tr = repmat(s_tr, p + 1, 1);
        ols_inf_all = repmat(s_all, p + 1, 1);
    else
        ols_inf_tr(j) = s_tr;
        ols_inf_all(j) = s_all;
    end
end

results.ols_equivalence_check = ols_equiv;
results.ols_inference_train_240 = struct( ...
    'r2', mdl_ols_train.Rsquared.Ordinary, ...
    'adj_r2', mdl_ols_train.Rsquared.Adjusted, ...
    'rmse', mdl_ols_train.RMSE, ...
    'f_stat', mdl_ols_train.ModelFitVsNullModel.Fstat, ...
    'f_pvalue', mdl_ols_train.ModelFitVsNullModel.Pvalue, ...
    'coefficients', ols_inf_tr);
results.ols_inference_full_300 = struct( ...
    'r2', mdl_ols_all.Rsquared.Ordinary, ...
    'adj_r2', mdl_ols_all.Rsquared.Adjusted, ...
    'rmse', mdl_ols_all.RMSE, ...
    'f_stat', mdl_ols_all.ModelFitVsNullModel.Fstat, ...
    'f_pvalue', mdl_ols_all.ModelFitVsNullModel.Pvalue, ...
    'coefficients', ols_inf_all);

results.models = model_records;
results.best_model_diagnostics = diag_info;

results.feature_importance = struct( ...
    'top3_consensus', {top3_features}, ...
    'top3_exact_order_agree_4methods', top3_all_agree, ...
    'rank_spearman_corr_4methods', rank_corr_4methods, ...
    'ranked_table', fi_table, ...
    'suppression_note', sprintf(['OverallQual vs GrLivArea sample r = %.4f: in univariate correlation ', ...
        'OverallQual (r=%.4f) nearly ties GarageCars (r=%.4f), whereas controlling for GrLivArea in ', ...
        'multivariate OLS reveals OverallQual (|beta*|=$%.0f) is clearly #2 well ahead of GarageCars ($%.0f).'], ...
        R_xx(1, 2), R_pearson_y(1), R_pearson_y(3), abs_beta_std(1), abs_beta_std(3)));

results.figure_paths = fig_paths;
results.eda_json_path = eda_json;

write_utf8_json(res_json, results);
fprintf('  Saved results summary -> %s\n', res_json);
fprintf('\n=================================================================\n');
fprintf(' Pipeline completed successfully with ZERO errors!\n');
fprintf('=================================================================\n');

%% ==================== Local Helper Functions ====================

function rec = make_model_record(id, tier, display_name, n_params, ...
        y_tr, pred_tr, oof_pred, fold_rmse, fold_r2, y_te, pred_te)
    rec = struct();
    rec.id = id;
    rec.tier = tier;
    rec.display_name = display_name;
    rec.n_params = n_params;
    rec.train = eval_metrics(y_tr, pred_tr, n_params);
    rec.cv_oof = eval_metrics(y_tr, oof_pred, n_params);
    rec.cv_rmse_mean = mean(fold_rmse);
    rec.cv_rmse_std  = std(fold_rmse, 0);
    rec.cv_r2_mean   = mean(fold_r2);
    rec.cv_r2_std    = std(fold_r2, 0);
    rec.cv_fold_rmses = fold_rmse(:);
    rec.cv_fold_r2s   = fold_r2(:);
    rec.test = eval_metrics(y_te, pred_te, n_params);
end

function ranks = invert_order_to_rank(ord)
    ranks = zeros(numel(ord), 1);
    for r = 1:numel(ord)
        ranks(ord(r)) = r;
    end
end

function write_utf8_json(filepath, data_struct)
    json_str = jsonencode(data_struct, 'PrettyPrint', true);
    fid = fopen(filepath, 'wb');
    assert(fid ~= -1, 'Failed to open file for writing: %s', filepath);
    fwrite(fid, unicode2native(json_str, 'UTF-8'), 'uint8');
    fclose(fid);
end
