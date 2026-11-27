Experiment & Practice #2: House Price Regression Modeling and Feature Contribution Analysis

Name: Hanzhang Pei  Student ID: 2025310104015  Instructor: Prof. Jing Liang  Course: Random Mathematics

**Abstract**: Based on 300 housing records (excluding the index column `Id` and keeping 8 house features), this report implements multiple linear regression and a partial quadratic extension in MATLAB R2025b, verified via both normal equations and `fitlm`. The partial quadratic model achieves test $R^2 = 0.9774$ and $\text{RMSE} = \$10,926$. Standardized coefficients and leave-one-out validation consistently identify the top three contributing features as `GrLivArea`, `OverallQual`, and `GarageCars`.

# 1. Introduction and Dataset Overview

This experiment builds a regression model from real house transaction data to predict sale prices and identify the three most influential features. The dataset contains $N = 300$ observations and 10 columns with zero missing values. Since the first column `Id` is only a sequential index ($1 \sim 300$), we drop it prior to modeling and keep the 8 physical house attributes as predictors $x_1,\dots,x_8$, with `SalePrice` (USD) as the response $y$.

Table 1 and Figure 1 summarize the basic statistics and correlation coefficients $r$ of each variable. Above-ground living area `GrLivArea` shows the strongest correlation with sale price ($r = 0.7451$), followed by `OverallQual` ($r = 0.3529$) and `GarageCars` ($r = 0.3513$), while correlations among predictors remain very small (all below $0.13$).

Table 1 Summary Statistics and Correlation Coefficients of Variables (N = 300)

| Variable | Meaning | Unit | Mean ± SD | Range | Corr. $r$ |
| :--- | :--- | :---: | :---: | :---: | :---: |
| OverallQual | Overall Quality | pts | 5.33 ± 2.87 | [1, 10] | +0.3529 |
| GrLivArea | Above-Ground Living Area | sq ft | 2,307.4 ± 1,042.6 | [504, 3,998] | +0.7451 |
| GarageCars | Garage Capacity | cars | 1.33 ± 1.11 | [0, 3] | +0.3513 |
| TotalBsmtSF | Basement Area | sq ft | 1,468.8 ± 672.3 | [303, 2,492] | +0.2502 |
| YearBuilt | Year Built | yr | 1986.2 ± 21.4 | [1950, 2023] | +0.2221 |
| FullBath | Full Bathrooms | rooms | 1.52 ± 1.13 | [0, 3] | +0.2737 |
| BedroomAbvGr | Bedrooms Above Ground | rooms | 2.93 ± 1.46 | [1, 5] | +0.0141 |
| LotArea | Lot Area | sq ft | 8,969.5 ± 3,753.5 | [2,009, 14,987] | -0.0390 |
| SalePrice | Sale Price (Response) | USD | 252,262.9 ± 74,998.1 | [82,494, 435,291] | 1.0000 |

![](03_Figures/fig1_en_eda.png)

Figure 1 Correlation Matrix of 8 Predictors and SalePrice Distribution Histogram

# 2. Regression Modeling and Fitting Analysis

The original dataset does not come pre-split into training and validation subsets. Borrowing the practice from AI model training and validation to prevent "memorizing" the training samples (overfitting), we fix the random seed `rng(42)` and split the 300 records 80/20 into a training set (240 samples, for estimating coefficients) and a test set (60 samples, serving as unseen exam data). Within the training set, we further apply 5-fold cross-validation (`CV`), a standard technique used during AI training and validation: the 240 training samples are evenly partitioned into 5 folds, fitting on 4 folds and validating on the remaining 1 fold in turn, then averaging the 5 validation errors. Model accuracy is evaluated by Root Mean Squared Error ($\text{RMSE}$), Mean Absolute Error ($\text{MAE}$), and $R^2$:

$$\text{RMSE} = \sqrt{\frac{1}{n}\sum_{i=1}^{n}(y_i - \hat{y}_i)^2}$$

$$R^2 = 1 - \frac{\sum_{i=1}^{n}(y_i - \hat{y}_i)^2}{\sum_{i=1}^{n}(y_i - \bar{y})^2}$$

## 2.1 Multiple Linear Regression and Solution

Using all 8 predictors in $\mathbf{y} = \mathbf{X}\boldsymbol{\beta} + \boldsymbol{\varepsilon}$, the least square method minimizes the residual sum of squares (SSE) $Q$:

$$Q = \sum_{i=1}^{n}(y_i - \hat{y}_i)^2$$

Adding a leading column of ones to represent the intercept and setting the partial derivatives of $Q$ to zero yields the normal equations:

$$(\mathbf{X}^\top \mathbf{X})\hat{\boldsymbol{\beta}} = \mathbf{X}^\top \mathbf{y}$$

We solve for $\hat{\boldsymbol{\beta}}$ via MATLAB backslash `\` and verify the solution against `fitlm`. Both solvers agree completely: the maximum coefficient difference is $1.30 \times 10^{-6}$, and the maximum test prediction difference is $2.44 \times 10^{-8}$ USD.

## 2.2 Partial Quadratic Extension: Key Area Features vs. Linear Predictors

Beyond the purely linear model, we add squared terms only to the 2 most suitable features while keeping the other 6 predictors linear (10 terms total). Among the 8 predictors, `GrLivArea` (living area) and `TotalBsmtSF` (basement area) are continuous area variables with the widest numerical spans, and individual tests show their squared terms reduce error most noticeably; discrete integer counts (`GarageCars`, `FullBath`, `BedroomAbvGr`) remain linear.

Table 2 Performance Comparison of Multiple Linear and Partial Quadratic Models (USD)

| Model Name | Terms | Train RMSE | 5-Fold CV RMSE | Test RMSE | Test MAE | Test $R^2$ |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| Multiple Linear Regression (8 linear terms) | 8 | 11,195 | 11,712 | 11,030 | 9,604 | 0.9770 |
| Partial Quadratic Fit (2 area sq. + 6 linear) | 10 | 11,168 | 11,756 | 10,926 | 9,505 | 0.9774 |

As shown in Table 2, adding squared terms solely for the two area features lowers test RMSE from $\$11,030$ to $\$10,926$ (test MAE to $\$9,505$), while 5-fold CV RMSE stays close to the linear baseline. Figure 2 confirms that linear predictions align tightly along $y=x$ with residuals balanced inside $\pm\$25\text{k}$, showing a predominantly linear relationship gently refined by local area curvature.

![](03_Figures/fig2_en_ols_fit_and_residuals.png)

Figure 2 Multiple Linear Regression Fit (Predicted vs. Actual) and Residual Spread

# 3. Feature Contribution Evaluation

We cannot compare raw coefficients $\hat{\beta}_j$ directly to rank feature importance because units differ vastly: in Table 3, each extra garage space (`GarageCars`) adds $+\$19,103$ while each square foot (`GrLivArea`) adds $+\$54.79$, yet living areas span thousands of square feet whereas garage capacity spans only 0–3 cars. Therefore, we adopt two straightforward evaluation methods that cross-check each other:

1. **Method 1 (Standardized Coefficient $|\beta_j^*|$)**: Each predictor is centered by its mean and divided by its standard deviation (SD) so every predictor varies on the common scale of "1 standard deviation". Fitting multiple linear regression on these standardized values yields $|\beta_j^*|$, which measures the expected price change in USD per 1-SD change in predictor $j$:

$$z_{ij} = \frac{x_{ij} - \bar{x}_j}{s_{x_j}}$$

$$\beta_j^* = \hat{\beta}_j \cdot s_{x_j}$$

2. **Method 2 (Leave-One-Out 5-Fold CV RMSE Increase $\Delta\text{RMSE}_{\text{CV}}$)**: Dropping predictor $j$ at a time and refitting on the remaining 7 predictors reveals how much 5-fold CV RMSE rises. A larger error jump indicates unique predictive information that cannot be substituted by the other predictors:

$$\Delta\text{RMSE}_{\text{CV}}^{(j)} = \text{RMSE}_{\text{CV}}^{(-j)} - \text{RMSE}_{\text{CV}}^{\text{full}}$$

Table 3 Feature Contribution Comparison and Consensus Ranking Across All 8 Predictors

| Rank | Feature Name | Raw Coef. $\hat{\beta}_j$ | Standardized $|\beta_j^*|$ (Share) | CV RMSE Increase | Corr. $r$ |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **1** | **GrLivArea (Living Area)** | +54.79 | **57,453 (34.7%)** | **+$48,882** | +0.7451 |
| **2** | **OverallQual (Overall Quality)** | +11,892 | **34,087 (20.6%)** | **+$26,231** | +0.3529 |
| **3** | **GarageCars (Garage Capacity)** | +19,103 | **21,319 (12.9%)** | **+$13,357** | +0.3513 |
| 4 | TotalBsmtSF (Basement Area) | +25.17 | 16,672 (10.1%) | +$9,179 | +0.2502 |
| 5 | YearBuilt (Year Built) | +765 | 16,280 (9.8%) | +$8,781 | +0.2221 |
| 6 | FullBath (Full Bathrooms) | +10,695 | 12,141 (7.3%) | +$5,851 | +0.2737 |
| 7 | BedroomAbvGr (Bedrooms Above) | +4,674 | 6,684 (4.0%) | +$1,892 | +0.0141 |
| 8 | LotArea (Lot Area) | -0.24 | 893 (0.5%) | -$49 | -0.0390 |

![](03_Figures/fig3_en_feature_importance_top3.png)

Figure 3 Feature Contribution Comparison via Both Methods (Top 3 Highlighted in Red)

Table 3 and Figure 3 show complete agreement between the two methods across all 8 predictors. The top three contributors are: **1st `GrLivArea`**, **2nd `OverallQual`**, and **3rd `GarageCars`**, accounting for $68.2\%$ of total standardized contribution. Although `OverallQual` and `GarageCars` have nearly identical correlation $r$ ($0.3529$ vs. $0.3513$), controlling for living area reveals a much stronger direct impact from `OverallQual`. Removing `LotArea` slightly decreases CV RMSE by $\$49$, confirming minimal contribution in this dataset.

# 4. Conclusion

Under the 80/20 split and 5-fold CV, 8-predictor multiple linear regression predicts sale prices accurately (test RMSE $\$11,030$), and adding quadratic terms on `GrLivArea` and `TotalBsmtSF` while keeping the other 6 predictors linear lowers test RMSE further to $\$10,926$. Normal equations and `fitlm` produce identical solutions, and both importance rankings establish `GrLivArea`, `OverallQual`, and `GarageCars` as the top three predictors.

# 5. Appendix: Core MATLAB Code

```matlab
% 1. Load data, drop Id, and create 80/20 train/test split
T = readtable('数据样本.csv', 'VariableNamingRule', 'preserve');
features = {'OverallQual','GrLivArea','GarageCars','TotalBsmtSF', ...
             'YearBuilt','FullBath','BedroomAbvGr','LotArea'};
X = T{:, features};  y = T{:, 'SalePrice'};
rng(42, 'twister');  cvHold = cvpartition(size(X,1), 'HoldOut', 0.20);
X_tr = X(training(cvHold), :);  y_tr = y(training(cvHold));
X_te = X(test(cvHold), :);      y_te = y(test(cvHold));

% 2. Multiple linear regression (normal equations & fitlm) + partial quadratic
Xb_tr = [ones(size(X_tr,1),1), X_tr];  Xb_te = [ones(size(X_te,1),1), X_te];
beta_ne = (Xb_tr' * Xb_tr) \ (Xb_tr' * y_tr);
mdl_ols = fitlm(X_tr, y_tr);
pred_ne = Xb_te * beta_ne;  pred_fitlm = predict(mdl_ols, X_te);

Z_tr = (X_tr - mean(X_tr,1)) ./ std(X_tr,0,1);
quadCols = [2, 4];  % Add squared terms only for GrLivArea & TotalBsmtSF
Phi_tr = [ones(size(X_tr,1),1), Z_tr, Z_tr(:, quadCols).^2];
beta_part = Phi_tr \ y_tr;

% 3. Feature contribution: standardized coefficients + 5-fold CV drop-column
beta_std = abs(fitlm(Z_tr, y_tr).Coefficients.Estimate(2:end));
rng(42, 'twister');  cv5 = cvpartition(size(X_tr,1), 'KFold', 5);
for j = 1:8
    keep_cols = setdiff(1:8, j);
    % Refit 5-fold CV on X_tr(:, keep_cols) to measure CV RMSE increase
end
```