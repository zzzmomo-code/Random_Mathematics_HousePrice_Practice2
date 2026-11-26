# HANDOFF — 《随机数学》Practice 2：房价多模型回归建模与特征贡献度分析

> 面向联邦 AI 协作的权威交接文档（机器可读，精确路径与数值严格对应 `eda_summary.json` / `results_summary.json`）。

---

## 1. 项目元数据与边界

- **项目绝对路径**：`E:\Random_Mathematics_Project_HousePrice`
- **GitHub 仓库（公开，个人独立作业）**：`https://github.com/zzzmomo-code/Random_Mathematics_HousePrice_Practice2`
- **课程与任务**：《随机数学》Practice 2（房价回归建模与 Top 3 特征贡献度分析）
- **学生（个人独立完成，无组员）**：裴翰章（学号：`2025310104015`）
- **指导教师**：梁菁 教授
- **环境工具链**：
  - MATLAB R2025b：`E:\Data\Program Files\MATLAB\R2025b\bin\matlab.exe`（Statistics and Machine Learning Toolbox + Curve Fitting Toolbox）
  - Python 3.12：`C:\Users\48747\AppData\Local\Programs\Python\Python312\python.exe`（`python-docx 1.2.0`, `pymupdf`）
  - Pandoc 3.9.0.2：`C:\Users\48747\miniconda3\Library\bin\pandoc.exe`
  - PDF 导出：Microsoft Word COM（Windows 原生）
- **当前范围与边界**：
  - **2026-11-26 精简审校定稿**：正式中文 `Practice Report`（DOCX / PDF）已按用户最新要求重构为 **4 页纯课堂口吻论文格式**：仅保留单特征直线/抛物线拟合、多元线性回归（正规方程/`fitlm`）及**唯一最简课内拓展（手动批量梯度下降）**，并采用**标准化回归系数**与**逐个去特征误差增幅**两种原理直白的贡献度评价方法；彻底去除参考文献与 `VIF`/条件数/偏度/峰度/Jarque-Bera/MAPE/斯皮尔曼/皮尔逊/KDE/多项式交互/Ridge/Lasso/决策树/随机森林/GBDT 等过度专业或课外内容。
  - 原有 `main_house_price_modeling.m` 与 `results_summary.json` 仍完整保留在 `02_MATLAB_Modeling\` 中作为全量对照备份；报告专用 4 张质朴白底图由 `02_MATLAB_Modeling\generate_concise_report_figures.m` 生成。
  - **英文版报告**：按用户确认方案，待中文版审核通过后视需要再生成。
  - 数据源为聚合数据 300 条学习样本，结果仅代表该样本集规律，不含区位/学区/宏观变量。

---

## 2. 权威输入与核心产物绝对路径

### 权威原始数据
- `E:\Random_Mathematics_Project_HousePrice\01_Data\聚合数据用于学习训练\数据样本.csv`（300 行 × 10 列，0 缺失值；剔除索引列 `Id`，保留 8 项物理特征 + 目标 `SalePrice`）
- `E:\Random_Mathematics_Project_HousePrice\01_Data\聚合数据用于学习训练\数据字典.csv`
- `E:\Random_Mathematics_Project_HousePrice\01_Data\聚合数据用于学习训练\网站.txt`（`https://www.juhe.cn/dataset/product/id/mva1wdNmuJB`）

### MATLAB 建模与结构化数据产物
- `E:\Random_Mathematics_Project_HousePrice\01_Data\eda_summary.json`
- `E:\Random_Mathematics_Project_HousePrice\02_MATLAB_Modeling\main_house_price_modeling.m`（主入口，`rng(42)` 可复现）
- `E:\Random_Mathematics_Project_HousePrice\02_MATLAB_Modeling\eval_metrics.m`
- `E:\Random_Mathematics_Project_HousePrice\02_MATLAB_Modeling\fit_ols_gd.m`
- `E:\Random_Mathematics_Project_HousePrice\02_MATLAB_Modeling\build_poly_features.m`
- `E:\Random_Mathematics_Project_HousePrice\02_MATLAB_Modeling\generate_figures.m`
- `E:\Random_Mathematics_Project_HousePrice\02_MATLAB_Modeling\results_summary.json`

### 3 张精简版正式报告专用 MATLAB 300-DPI 白底图（`generate_concise_report_figures.m` 生成）与双版本独立运行脚本
- `E:\Random_Mathematics_Project_HousePrice\02_MATLAB_Modeling\practice2_house_price_clean.m`（精简无注释提交版，独立单文件可直接运行）
- `E:\Random_Mathematics_Project_HousePrice\02_MATLAB_Modeling\practice2_house_price_tutorial.m`（详细中文注释教学版，按 6 步逐行讲解语法与思路）
- `E:\Random_Mathematics_Project_HousePrice\03_Figures\fig1_concise_eda.png`
- `E:\Random_Mathematics_Project_HousePrice\03_Figures\fig2_ols_fit_and_residuals.png`
- `E:\Random_Mathematics_Project_HousePrice\03_Figures\fig4_feature_importance_top3.png`
*(全量拓展对比图与早期图亦保留于 `03_Figures\` 目录备查)*

### 报告、教学手册与协作文档
- `E:\Random_Mathematics_Project_HousePrice\04_Report\build_practice2_report.py`
- `E:\Random_Mathematics_Project_HousePrice\04_Report\practice2_report_source.md`
- `E:\Random_Mathematics_Project_HousePrice\04_Report\Practice2_HousePrice_Regression_Report_裴翰章.docx`
- `E:\Random_Mathematics_Project_HousePrice\04_Report\Practice2_HousePrice_Regression_Report_裴翰章_定稿版.pdf`（因先前 PDF 被 WPS 占用，自动导出至 `_定稿版.pdf`，严格 4 页完整无拆表：去掉单变量与梯度下降，聚焦 8 特征一次线性 vs 二次多项式对比，文末附精简核心 MATLAB 代码）
- `E:\Random_Mathematics_Project_HousePrice\00_【给MoMo看】房价回归实验通俗教学指南.md`
- `E:\Random_Mathematics_Project_HousePrice\README.md`
- `E:\Random_Mathematics_Project_HousePrice\AI_CHAT.md`
- `E:\Random_Mathematics_Project_HousePrice\HANDOFF.md`

---

## 3. 首个里程碑核心数值成果（严格来自 JSON）

- **数据体检**：$N=300$，8 特征 + `SalePrice`（均值 `$252,262.9`，标准差 `$74,998.1`，中位数 `$251,292.5`，偏度 `0.0779`）；最大两两特征相关 $|r|_{\max}=0.1257$（`GarageCars` vs `FullBath`），最大 $\text{VIF}=1.0396$，标准化矩阵条件数 $\kappa(\mathbf{Z})=1.2690$。
- **划分与无泄露 CV**：固定 `rng(42)`，80%/20% 划分（240 训练 / 60 独立测试）+ 训练集内 5 折 CV（标准化在每折训练子集内部拟合）。
- **4 阶层 10 类模型对比**：
  - T1 一次线性 (`GrLivArea`)：CV RMSE `$49,877` ($R^2=0.5370$)，Test RMSE `$52,260` ($R^2=0.4841$)
  - T1 二次抛物线 (`GrLivArea`)：CV RMSE `$49,929` ($R^2=0.5354$)，Test RMSE `$51,872` ($R^2=0.4917$)，二次项 $p=0.3223$
  - **T2 多元 OLS（NE / GD / `fitlm` 三求解器数值等价，测试预测最大差 `2.44e-08`）**：Train RMSE `$11,195` ($R^2=0.9779$)，CV RMSE **`$11,712`** ($R^2=0.9739$)，Test RMSE **`$11,030`**，Test MAE **`$9,604`**，Test $R^2=$ **`0.9770`**，MAPE `4.27%`
  - T2 多元纯二次 (16 项)：CV RMSE `$12,165`，Test RMSE `$11,095` ($R^2=0.9767$)
  - T2 多元全二次 (44 项)：Train RMSE `$10,185`，CV RMSE `$12,325`，Test RMSE `$12,194` ($R^2=0.9719$，调整 $R^2=0.8895$，小样本过拟合)
  - T3 岭回归 Ridge ($\lambda=0$)：退化至 OLS，Test RMSE `$11,030` ($R^2=0.9770$)
  - T3 Lasso ($\lambda_{\min}=1.0$)：Test RMSE `$11,030` ($R^2=0.9770$)；$\lambda_{\text{1SE}}=775.7$ 时 Test RMSE `$11,156` ($R^2=0.9765$)
  - T4 决策树 (`MinLeafSize=5`)：CV RMSE `$41,567`，Test RMSE `$43,011` ($R^2=0.6505$)
  - T4 随机森林 (`500 trees, leaf=2, mtry=7`)：CV RMSE `$28,607`，OOB $R^2=0.8681$，Test RMSE `$28,917` ($R^2=0.8420$)
  - T4 梯度提升树 GBDT (`LSBoost, MaxNumSplits=1, lr=0.1, 300 cycles`)：CV RMSE `$16,919`，Test RMSE `$15,806` ($R^2=0.9528$)
- **Top 3 特征贡献度（4 方法 Spearman 秩相关全为 `1.000`）**：
  1. `GrLivArea`（地上居住面积）：$|\beta^*|=\$57,453$ (34.7%)，$\Delta\text{RMSE}_{\text{CV}}=+\$48,882$，单变量 $R^2=0.5552$，Lasso 入模 $\lambda=54,438$，RF Perm `5.692`
  2. `OverallQual`（综合质量）：$|\beta^*|=\$34,087$ (20.6%)，$\Delta\text{RMSE}_{\text{CV}}=+\$26,231$，单变量 $R^2=0.1245$，Lasso 入模 $\lambda=28,507$，RF Perm `3.106`
  3. `GarageCars`（车库容量）：$|\beta^*|=\$21,319$ (12.9%)，$\Delta\text{RMSE}_{\text{CV}}=+\$13,357$，单变量 $R^2=0.1234$，Lasso 入模 $\lambda=21,605$，RF Perm `1.374`
  - 其余排序：`4. TotalBsmtSF`、`5. YearBuilt`、`6. FullBath`、`7. BedroomAbvGr`、`8. LotArea`（$p=0.231$ 不显著，$\Delta\text{RMSE}_{\text{CV}}=-\$49$）。

---

## 4. 验证证据分层

- **级别 1（代码与语法）**：MATLAB 脚本在 R2025b 零报错零警告执行通过（exit code 0）；Python 构建脚本零报错执行通过。
- **级别 2（配置与排版审计）**：DOCX 经 XML 审计：原生 OMML `<m:oMath>` 公式数 >= 135、原始 LaTeX 残留 = 0、页眉文字 = 0、非白底纹 = 0、非本人姓名/禁词 = 0。
- **级别 3（数值交叉复核与视觉验收）**：独立 Python 交叉复核 OLS 系数差异 <= `1.86e-9`、VIF 差异 <= `2.22e-16`；5 张 PNG 图表与导出 PDF 每页均完成逐页图像级人工视觉检查。
- **级别 4（硬件实测）**：不适用（纯统计建模与课程报告项目）。

---

## 5. 当前状态、风险与接手者第一项操作

- **当前状态**：Stage 1（MATLAB 建模与 5 张高清图表）与 Stage 2（中文正式报告 DOCX/PDF、MoMo 教学指南、协作与仓库文档）均已通过独立验证（零缺陷），并已初始化 Git `main` 分支同步至 GitHub 仓库 `https://github.com/zzzmomo-code/Random_Mathematics_HousePrice_Practice2`。
- **潜在风险 / 后续项**：
  1. 若用户审阅中文报告后需要提交英文版本，可基于 `04_Report\build_practice2_report.py` 扩展英文版报告构建脚本。
  2. 数据源仅覆盖聚合数据 300 条结构化样本，结论边界已如实声明。
- **接手者确切第一项操作**：读取 `E:\Random_Mathematics_Project_HousePrice\02_MATLAB_Modeling\results_summary.json` 并审阅 `E:\Random_Mathematics_Project_HousePrice\04_Report\Practice2_HousePrice_Regression_Report_裴翰章.pdf`，根据用户反馈执行英文版翻译或微调重编译（运行 `python -X utf8 E:\Random_Mathematics_Project_HousePrice\04_Report\build_practice2_report.py`）。
