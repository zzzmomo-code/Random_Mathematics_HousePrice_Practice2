%% =========================================================================
% 《随机数学》Experiment & Practice #2：房价回归建模与特征贡献评估（教学详注版）
% 配套课程：Chapter 10 Linear Statistical Models
% 作者：裴翰章（2025310104015）   指导教师：梁菁 教授
%
% 【程序整体流程（共 6 步）】
%   步骤 1：读入 CSV 数据，去掉无意义的编号列 Id，提取 8 个预测变量 X 和响应变量 y
%   步骤 2：固定随机种子按 8:2 划分训练集/测试集，并准备训练集内的 5 折交叉验证
%   步骤 3：建立多元一次线性回归模型（手写正规方程求解 + MATLAB 内置 fitlm 互证）
%   步骤 4：建立多元二次多项式回归模型（加入 x_j^2，检验是否需要高次项）
%   步骤 5：用“标准化回归系数”和“逐个去掉特征看误差增幅”两种方法排出贡献前 3 名
%   步骤 6：绘制质朴白底的预测效果图与特征贡献排名图
%% =========================================================================

clear;      % 清空工作区所有变量，防止以前跑过的旧变量干扰结果
clc;        % 清空命令行窗口文字
close all;  % 关闭之前打开的所有图窗

%% 步骤 1：读取数据并准备预测变量 X 与响应变量 y
% 数据文件绝对路径
dataPath = 'E:\Random_Mathematics_Project_HousePrice\01_Data\聚合数据用于学习训练\数据样本.csv';

% detectImportOptions 会自动识别 CSV 的编码和列名；
% VariableNamingRule='preserve' 表示保持原始列名不变（如 GrLivArea、OverallQual）
opts = detectImportOptions(dataPath, 'Encoding', 'UTF-8');
opts.VariableNamingRule = 'preserve';
T = readtable(dataPath, opts);

% 第一列 Id 只是 1~300 的序号，对房价没有物理意义，所以建模前剔除它，只保留其余 8 个特征
features = {'OverallQual', 'GrLivArea', 'GarageCars', 'TotalBsmtSF', ...
            'YearBuilt', 'FullBath', 'BedroomAbvGr', 'LotArea'};

% T{:, features} 用大括号取表格里的数值，直接得到纯数字矩阵 X（300 行 x 8 列）
X = T{:, features};
y = T{:, 'SalePrice'};   % 响应变量 y（300 行 x 1 列，单位：美元）
[N, p] = size(X);        % N = 300 条样本，p = 8 个预测变量

%% 步骤 2：固定随机种子、划分 8:2 数据集与 5 折交叉验证（CV）
% 固定随机种子为 42，保证每次运行划分结果一模一样，便于复现和检查
rng(42, 'twister');
% HoldOut=0.20 表示随机抽 20%（60 条）作为独立测试集，其余 80%（240 条）作为训练集
cvHold = cvpartition(N, 'HoldOut', 0.20);
idxTr = training(cvHold);   % 长度为 300 的逻辑向量，训练集位置为 1
idxTe = test(cvHold);       % 测试集位置为 1

X_tr = X(idxTr, :); y_tr = y(idxTr);
X_te = X(idxTe, :); y_te = y(idxTe);

% 在训练集（240 条）内部再划分 5 折交叉验证：每次拿 4 折建模、1 折验证，轮流 5 次求平均误差
rng(42, 'twister');
K = 5;
cv5 = cvpartition(size(X_tr, 1), 'KFold', K);

% 定义 3 个匿名函数计算误差指标（与报告第 2 节公式完全对应）
% RMSE：均方根误差，越小越好；MAE：平均绝对误差，越小越好；R^2：越接近 1 拟合越好
calcRmse = @(yt, yp) sqrt(mean((yt - yp).^2));
calcMae  = @(yt, yp) mean(abs(yt - yp));
calcR2   = @(yt, yp) 1 - sum((yt - yp).^2) / sum((yt - mean(yt)).^2);

%% 步骤 3：多元一次线性回归（课堂正规方程求解 vs MATLAB 内置函数 fitlm）
% 3.1 先算 5 折交叉验证误差，评估模型在未知子集上的稳定性
cvRmseLin = zeros(K, 1);
for k = 1:K
    tr = training(cv5, k);   % 第 k 折中的 4 份训练数据（192 条）
    va = test(cv5, k);       % 第 k 折中的 1 份验证数据（48 条）

    % 在特征矩阵最左边拼一列全 1，用来对应模型里的常数截距项 beta_0
    Xb_tr_k = [ones(sum(tr), 1), X_tr(tr, :)];
    Xb_va_k = [ones(sum(va), 1), X_tr(va, :)];

    % 正规方程求解：beta_hat = (X'X)^(-1) * X'y
    % 在 MATLAB 里推荐用左除反斜杠 A \ b 代替 inv(A)*b，计算更快、数值精度更高
    b_k = (Xb_tr_k' * Xb_tr_k) \ (Xb_tr_k' * y_tr(tr));

    pred_va = Xb_va_k * b_k;
    cvRmseLin(k) = calcRmse(y_tr(va), pred_va);
end

% 3.2 用全部 240 条训练集拟合最终多元一次线性模型
Xb_tr = [ones(size(X_tr, 1), 1), X_tr];
Xb_te = [ones(size(X_te, 1), 1), X_te];
beta_ne = (Xb_tr' * Xb_tr) \ (Xb_tr' * y_tr);   % 正规方程求出的 9 个系数（截距 + 8个斜率）

% 同时调用 MATLAB 自带函数 fitlm 拟合同一组数据，互相核对结果
mdl_ols = fitlm(X_tr, y_tr, 'VarNames', [features, {'SalePrice'}]);

% 用两种方法在测试集上做预测，对比是否一致
pred_lin_tr   = Xb_tr * beta_ne;
pred_lin_te   = Xb_te * beta_ne;
pred_fitlm_te = predict(mdl_ols, X_te);

%% 步骤 4：多元二次多项式回归（加入每个特征的平方项 x_j^2，共 16 项）
% 目的：检验房价与特征之间是否存在二次弯曲关系，看看加上平方项后效果会不会更好
% 注意：构造平方项前先做标准化（减均值除以标准差），避免平方后数值太大影响计算精度
cvRmseQuad = zeros(K, 1);
for k = 1:K
    tr = training(cv5, k);
    va = test(cv5, k);

    % 严格只在当前折的训练子集里算均值 mu_k 和标准差 sd_k，防止验证集信息提前泄露
    mu_k = mean(X_tr(tr, :), 1);
    sd_k = std(X_tr(tr, :), 0, 1);
    Z_tr_k = (X_tr(tr, :) - mu_k) ./ sd_k;
    Z_va_k = (X_tr(va, :) - mu_k) ./ sd_k;

    % 把 8 个一次标准化特征 Z 和 8 个平方项 Z.^2 拼在一起（再加上截距列全 1）
    Phi_tr_k = [ones(sum(tr), 1), Z_tr_k, Z_tr_k.^2];
    Phi_va_k = [ones(sum(va), 1), Z_va_k, Z_va_k.^2];

    b_qk = Phi_tr_k \ y_tr(tr);
    cvRmseQuad(k) = calcRmse(y_tr(va), Phi_va_k * b_qk);
end

% 在全训练集（240 条）上拟合多元二次多项式并在测试集（60 条）上验证
mu_tr = mean(X_tr, 1);
sd_tr = std(X_tr, 0, 1);
Z_tr = (X_tr - mu_tr) ./ sd_tr;   % 训练集标准化矩阵（后续方法 1 也要直接用它）
Z_te = (X_te - mu_tr) ./ sd_tr;   % 测试集必须使用训练集的均值和标准差来缩放
Phi_tr = [ones(size(X_tr, 1), 1), Z_tr, Z_tr.^2];
Phi_te = [ones(size(X_te, 1), 1), Z_te, Z_te.^2];
beta_quad = Phi_tr \ y_tr;
pred_quad_tr = Phi_tr * beta_quad;
pred_quad_te = Phi_te * beta_quad;

% 打印步骤 3 和步骤 4 的性能对比（与报告表 2 对应）
fprintf('================ 多元回归模型性能对比 ================\n');
fprintf('多元一次线性 (8项)   | 训练RMSE=$%.0f | 5折CV RMSE=$%.0f | 测试RMSE=$%.0f | 测试MAE=$%.0f | 测试R^2=%.4f\n', ...
    calcRmse(y_tr, pred_lin_tr), mean(cvRmseLin), calcRmse(y_te, pred_lin_te), calcMae(y_te, pred_lin_te), calcR2(y_te, pred_lin_te));
fprintf('多元二次多项式 (16项)| 训练RMSE=$%.0f | 5折CV RMSE=$%.0f | 测试RMSE=$%.0f | 测试MAE=$%.0f | 测试R^2=%.4f\n', ...
    calcRmse(y_tr, pred_quad_tr), mean(cvRmseQuad), calcRmse(y_te, pred_quad_te), calcMae(y_te, pred_quad_te), calcR2(y_te, pred_quad_te));
fprintf('正规方程与 fitlm 在测试集上的最大预测差值: %.2e 美元\n\n', max(abs(pred_lin_te - pred_fitlm_te)));

%% 步骤 5：特征贡献评估（找出对房价贡献最大的前 3 个特征）
% 为什么不能直接比较原始系数 beta_ne(2:end)？
% 因为单位完全不同（面积是几千平方英尺，车库是 0~3 个，不能直接拿数字比大小）。

% 方法 1：标准化回归系数 |beta_j*|
% 直接用标准化后的 Z_tr 去回归 y_tr；Estimate(2:end) 跳过第 1 行的截距项，取 8 个特征系数
mdl_std = fitlm(Z_tr, y_tr);
beta_std = abs(mdl_std.Coefficients.Estimate(2:end));   % 每个系数代表“变化 1 个标准差”带来的房价变动
share_std = beta_std / sum(beta_std) * 100;             % 换算成百分比占比

% 方法 2：逐个去掉特征看 5 折交叉验证误差增幅（Delta RMSE_CV）
% 如果去掉某个特征后预测误差大幅上升，说明它携带的房价信息很难被其他特征代替
base_cv = mean(cvRmseLin);   % 保留全部 8 个特征时的基准 5 折 CV RMSE
delta_cv = zeros(p, 1);
for j = 1:p
    keep = setdiff(1:p, j);   % setdiff(1:8, j) 表示去掉第 j 列，留下其余 7 列
    rmses_j = zeros(K, 1);
    for k = 1:K
        tr = training(cv5, k);
        va = test(cv5, k);
        Xb_tr_j = [ones(sum(tr), 1), X_tr(tr, keep)];
        Xb_va_j = [ones(sum(va), 1), X_tr(va, keep)];
        b_j = (Xb_tr_j' * Xb_tr_j) \ (Xb_tr_j' * y_tr(tr));
        rmses_j(k) = calcRmse(y_tr(va), Xb_va_j * b_j);
    end
    delta_cv(j) = mean(rmses_j) - base_cv;   % 去掉第 j 个特征后误差增加了多少美元
end

% 计算每个特征与房价的课堂相关系数 r 作为对照参考
r_y = corr(X, y);
% 按标准化回归系数从大到小排序，取出排序索引 order
[~, order] = sort(beta_std, 'descend');

fprintf('================ 8 个特征贡献评估与排名 ================\n');
for idx = 1:p
    j = order(idx);
    fprintf('第 %d 名 %-12s | 原始系数=%+10.2f | 标准化|beta*|=$%7.0f (%4.1f%%) | 去掉后误差增幅=%+7.0f | 相关系数r=%+.4f\n', ...
        idx, features{j}, beta_ne(j+1), beta_std(j), share_std(j), delta_cv(j), r_y(j));
end

%% 步骤 6：绘制简洁白底图（测试集预测对比 + 特征贡献柱状图）
figure('Color', 'w', 'Position', [120, 120, 1020, 420]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% 左图：测试集预测房价 vs 实际房价（点越贴近红虚线 y=x，预测越准）
nexttile;
plot([min(y_te); max(y_te)]/1e3, [min(y_te); max(y_te)]/1e3, '--r', 'LineWidth', 1.6);
hold on;
scatter(y_te/1e3, pred_lin_te/1e3, 36, 'filled');
grid on; axis square;
xlabel('实际房价 SalePrice ($k)');
ylabel('预测房价 Predicted ($k)');
title('(a) 多元一次线性回归：测试集预测 vs 实际房价');

% 右图：特征贡献排名水平柱状图
nexttile;
barh(1:p, beta_std(order)/1e3);
set(gca, 'YDir', 'reverse');   % 把 Y 轴反过来，让第 1 名排在最上面
yticks(1:p);
yticklabels(features(order));
grid on;
xlabel('标准化回归系数 |\beta_j^*| ($k)');
title('(b) 特征贡献排名（前三名贡献合计约 68.2%）');
