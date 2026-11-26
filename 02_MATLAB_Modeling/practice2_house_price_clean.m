clear; clc; close all;

dataPath = 'E:\Random_Mathematics_Project_HousePrice\01_Data\聚合数据用于学习训练\数据样本.csv';
opts = detectImportOptions(dataPath, 'Encoding', 'UTF-8');
opts.VariableNamingRule = 'preserve';
T = readtable(dataPath, opts);

features = {'OverallQual', 'GrLivArea', 'GarageCars', 'TotalBsmtSF', ...
            'YearBuilt', 'FullBath', 'BedroomAbvGr', 'LotArea'};
X = T{:, features};
y = T{:, 'SalePrice'};
[N, p] = size(X);

rng(42, 'twister');
cvHold = cvpartition(N, 'HoldOut', 0.20);
X_tr = X(training(cvHold), :);
y_tr = y(training(cvHold));
X_te = X(test(cvHold), :);
y_te = y(test(cvHold));

rng(42, 'twister');
K = 5;
cv5 = cvpartition(size(X_tr, 1), 'KFold', K);

calcRmse = @(yt, yp) sqrt(mean((yt - yp).^2));
calcMae  = @(yt, yp) mean(abs(yt - yp));
calcR2   = @(yt, yp) 1 - sum((yt - yp).^2) / sum((yt - mean(yt)).^2);

cvRmseLin = zeros(K, 1);
for k = 1:K
    tr = training(cv5, k);
    va = test(cv5, k);
    Xb_tr_k = [ones(sum(tr), 1), X_tr(tr, :)];
    Xb_va_k = [ones(sum(va), 1), X_tr(va, :)];
    b_k = (Xb_tr_k' * Xb_tr_k) \ (Xb_tr_k' * y_tr(tr));
    cvRmseLin(k) = calcRmse(y_tr(va), Xb_va_k * b_k);
end

Xb_tr = [ones(size(X_tr, 1), 1), X_tr];
Xb_te = [ones(size(X_te, 1), 1), X_te];
beta_ne = (Xb_tr' * Xb_tr) \ (Xb_tr' * y_tr);
mdl_ols = fitlm(X_tr, y_tr, 'VarNames', [features, {'SalePrice'}]);

pred_lin_tr = Xb_tr * beta_ne;
pred_lin_te = Xb_te * beta_ne;
pred_fitlm_te = predict(mdl_ols, X_te);

quadCols = [2, 4];
cvRmseQuad = zeros(K, 1);
for k = 1:K
    tr = training(cv5, k);
    va = test(cv5, k);
    mu_k = mean(X_tr(tr, :), 1);
    sd_k = std(X_tr(tr, :), 0, 1);
    Z_tr_k = (X_tr(tr, :) - mu_k) ./ sd_k;
    Z_va_k = (X_tr(va, :) - mu_k) ./ sd_k;
    Phi_tr_k = [ones(sum(tr), 1), Z_tr_k, Z_tr_k(:, quadCols).^2];
    Phi_va_k = [ones(sum(va), 1), Z_va_k, Z_va_k(:, quadCols).^2];
    b_qk = Phi_tr_k \ y_tr(tr);
    cvRmseQuad(k) = calcRmse(y_tr(va), Phi_va_k * b_qk);
end

mu_tr = mean(X_tr, 1);
sd_tr = std(X_tr, 0, 1);
Z_tr = (X_tr - mu_tr) ./ sd_tr;
Z_te = (X_te - mu_tr) ./ sd_tr;
Phi_tr = [ones(size(X_tr, 1), 1), Z_tr, Z_tr(:, quadCols).^2];
Phi_te = [ones(size(X_te, 1), 1), Z_te, Z_te(:, quadCols).^2];
beta_quad = Phi_tr \ y_tr;
pred_quad_tr = Phi_tr * beta_quad;
pred_quad_te = Phi_te * beta_quad;

fprintf('=== 多元回归模型性能对比 ===\n');
fprintf('多元一次线性 (8项)   | Train RMSE=$%.0f | 5折CV RMSE=$%.0f | Test RMSE=$%.0f | Test MAE=$%.0f | Test R^2=%.4f\n', ...
    calcRmse(y_tr, pred_lin_tr), mean(cvRmseLin), calcRmse(y_te, pred_lin_te), calcMae(y_te, pred_lin_te), calcR2(y_te, pred_lin_te));
fprintf('部分二次拟合 (10项)  | Train RMSE=$%.0f | 5折CV RMSE=$%.0f | Test RMSE=$%.0f | Test MAE=$%.0f | Test R^2=%.4f\n', ...
    calcRmse(y_tr, pred_quad_tr), mean(cvRmseQuad), calcRmse(y_te, pred_quad_te), calcMae(y_te, pred_quad_te), calcR2(y_te, pred_quad_te));
fprintf('正规方程与 fitlm 最大预测差: %.2e\n\n', max(abs(pred_lin_te - pred_fitlm_te)));

mdl_std = fitlm(Z_tr, y_tr);
beta_std = abs(mdl_std.Coefficients.Estimate(2:end));
share_std = beta_std / sum(beta_std) * 100;

base_cv = mean(cvRmseLin);
delta_cv = zeros(p, 1);
for j = 1:p
    keep = setdiff(1:p, j);
    rmses_j = zeros(K, 1);
    for k = 1:K
        tr = training(cv5, k);
        va = test(cv5, k);
        Xb_tr_j = [ones(sum(tr), 1), X_tr(tr, keep)];
        Xb_va_j = [ones(sum(va), 1), X_tr(va, keep)];
        b_j = (Xb_tr_j' * Xb_tr_j) \ (Xb_tr_j' * y_tr(tr));
        rmses_j(k) = calcRmse(y_tr(va), Xb_va_j * b_j);
    end
    delta_cv(j) = mean(rmses_j) - base_cv;
end

r_y = corr(X, y);
[~, order] = sort(beta_std, 'descend');

fprintf('=== 8个特征贡献排名 ===\n');
for idx = 1:p
    j = order(idx);
    fprintf('第%d名 %-12s | 原始系数=%+10.2f | 标准化|beta*|=$%7.0f (%4.1f%%) | 去特征增幅=%+7.0f | 相关系数r=%+.4f\n', ...
        idx, features{j}, beta_ne(j+1), beta_std(j), share_std(j), delta_cv(j), r_y(j));
end

figure('Color', 'w', 'Position', [120, 120, 1020, 420]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot([min(y_te); max(y_te)]/1e3, [min(y_te); max(y_te)]/1e3, '--r', 'LineWidth', 1.6);
hold on;
scatter(y_te/1e3, pred_lin_te/1e3, 36, 'filled');
grid on; axis square;
xlabel('实际房价 ($k)'); ylabel('预测房价 ($k)');
title('测试集预测 vs 实际房价');

nexttile;
barh(1:p, beta_std(order)/1e3);
set(gca, 'YDir', 'reverse');
yticks(1:p); yticklabels(features(order));
grid on;
xlabel('标准化回归系数 |\beta_j^*| ($k)');
title('特征贡献排名');
