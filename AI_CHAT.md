# AI_CHAT — 跨 AI 协作日志（Practice 2 房价回归项目）

> 记录本项目的关键设计决策、各阶段交付路径与验证结论，供后续协作 AI 快速同步上下文。

---

## [2026-11-17] 阶段一：MATLAB R2025b 全流程建模与可视化完成（已验证）

- **执行角色**：`matlab-modeler` + `verifier`
- **关键决策与实现**：
  - 显式排除无物理意义的样本索引列 `Id`，保留 8 项物理特征预测 `SalePrice`（$N=300$，无缺失值）。
  - 固定随机种子 `rng(42)`，采用 80/20 划分（240 训练 / 60 独立测试）与训练集内严格无泄露 5 折交叉验证（特征标准化均在折内拟合）。
  - 完成 4 阶层 10 类模型递进建模（单变量直线/抛物线 → 多元 OLS [NE/GD/`fitlm`] 与纯二次/全二次 → Ridge/Lasso → 决策树/随机森林/GBDT），以及 4 种互补特征贡献度评估方法（标准化 $|\beta^*|$、留一 $\Delta\text{RMSE}_{\text{CV}}$ + 单变量 $R^2$、Lasso 正则化路径、RF OOB 置换重要性）。
- **验证结论（Stage 1 PASS）**：
  - MATLAB R2025b 运行 exit code 0、零警告；独立 Python 交叉复核 OLS 系数差异 `<= 1.86e-9`，VIF 差异 `<= 2.22e-16`。
  - OLS 三求解器（正规方程、手动批量 GD、`fitlm`）测试集预测最大差 `2.44e-08`。
  - 4 种贡献度方法对 8 项特征排序完全一致（Spearman $\rho = 1.000$），Top 3 锁定为 `GrLivArea`、`OverallQual`、`GarageCars`。
  - 全部 5 张白底 300-DPI 图表视觉检查通过（无乱码、无遮挡、图例清晰）。
  - 注意：`results_summary.json` 为唯一权威数值源（其中 `max_interfeature_abs_r=0.1257`、`condition_number_std_X=1.2690`、`OLS test.mae=9604.48`、`GarageCars delta_cv_rmse=13357.48`、`GrLivArea rf_oob_perm_imp=5.6925`）。

---

## [2026-11-17] 阶段二：中文正式报告、MoMo 教学指南与协作文档构建完成

- **执行角色**：`report-author`
- **受众隔离交付物**：
  1. **给梁菁老师看（正式实验报告）**：
     - `E:\Random_Mathematics_Project_HousePrice\04_Report\build_practice2_report.py`（全自动 JSON 驱动 + Pandoc 原生 OMML + python-docx 三线表/零页眉排版 + Word COM PDF 导出）
     - `E:\Random_Mathematics_Project_HousePrice\04_Report\Practice2_HousePrice_Regression_Report_裴翰章.docx`
     - `E:\Random_Mathematics_Project_HousePrice\04_Report\Practice2_HousePrice_Regression_Report_裴翰章.pdf`
  2. **给 MoMo 看（零代码通俗教学指南）**：
     - `E:\Random_Mathematics_Project_HousePrice\00_【给MoMo看】房价回归实验通俗教学指南.md`
  3. **给 AI 与 GitHub 看（交接与仓库说明）**：
     - `E:\Random_Mathematics_Project_HousePrice\HANDOFF.md`
     - `E:\Random_Mathematics_Project_HousePrice\AI_CHAT.md`
     - `E:\Random_Mathematics_Project_HousePrice\README.md`
- **自检与排版精修**：
  - 报告严格单人署名（裴翰章 `2025310104015`，指导教师：梁菁 教授），无其他同学姓名、无 AI 过程痕迹、无浮夸绝对词。
  - 首轮渲染发现并修正了第 1 页正文段误触表注居中规则、主标题折行、公式负号间距与第 7 页稀疏尾页问题，重编译压缩至平衡 6 页。
- **终审与归档**：Stage 1（MATLAB 数值与 5 图视觉复核）及 Stage 2（DOCX 137 个 OMML 公式/零页眉/纯白三线表/全表数值核对 + PDF 6 页逐页视觉检查）均通过 `@verifier` 独立验证（零缺陷），仓库已同步推送至 GitHub `https://github.com/zzzmomo-code/Random_Mathematics_HousePrice_Practice2`。待用户审阅中文版报告后视需要扩展英文版。

---

## [2026-11-26] 阶段三：审查优化 —— 极简课堂口吻 4 页论文格式定稿

- **优化依据**：按 MoMo 审阅意见，消除过度专业词与课外算法堆砌，采用“正式标题 + 学生口吻正文 + 全课堂术语 + 极简结论 + 无参考文献”写法。
- **核心改动**：
  1. **MATLAB 精简白底插图**：新建 `02_MATLAB_Modeling\generate_concise_report_figures.m` 实跑导出 4 张质朴白底图（`fig1_concise_eda.png`、`fig2_concise_line_vs_parabola.png`、`fig3_ols_fit_and_gd.png`、`fig4_feature_importance_top3.png`），放大插入宽度至 5.85 英寸方便教师阅览。
  2. **仅留唯一最简课内拓展**：报告聚焦单特征直线/抛物线 → 多元线性回归（正规方程 / `fitlm`）+ 唯一课内微积分拓展（手动批量梯度下降）；特征贡献度详尽通俗讲解标准化回归系数与逐个去特征误差增幅两种方法，彻底剔除 `VIF`/条件数/偏度/峰度/Jarque-Bera/MAPE/斯皮尔曼/皮尔逊/KDE/多项式交互/Ridge/Lasso/树集成与参考文献。
  3. **排版自检与 PDF 逐页验收**：`04_Report\Practice2_HousePrice_Regression_Report_裴翰章.docx`（59 个 OMML 公式 / 9 个一式一行块公式，0 未渲染 LaTeX，0 页眉，0 非白底纹，0 禁词命中）与 `04_Report\Practice2_HousePrice_Regression_Report_裴翰章_精简版.pdf`（**严格 4 页**，表 1–3 全整表不跨页，年份无千分位逗号，`BedroomAbvGr` 不折行）已通过逐页视觉核查。

---

## [2026-11-26] 阶段四：对齐梁菁老师课件术语与作业要求的最终定稿

- **课件核对来源**：梁菁老师上传的 `Experiment & Practice #2`、`Chapter 10: Linear Statistical Models`、`Chapter 4` 与 `Homework #5 / #7`。
- **精确对齐调整**：
  1. 标题改为 `Experiment & Practice #2：房价回归建模与特征贡献度分析`，第 1 节明确引入课堂术语**预测变量（predictors）$x_1,\dots,x_8$** 与**响应变量（response）$y$**。
  2. 剔除仅剩的课外假设检验表述（二次项系数 $p$ 值、`显著`、`暴涨`），并在 `self_audit_docx` 禁词表新增 `"显著"` 与 `"p ="`。
  3. 第 2.2 节补入课堂最小二乘目标函数 $Q = \sum_{i=1}^{n}(y_i - \hat{y}_i)^2$（即残差平方和 $\text{SSE}$）及“求偏导置零得正规方程”的推导衔接。
  4. 为 `export_pdf_via_word_com` 增加占用检测与 `_定稿版.pdf` 自动降级保存逻辑。
- **验证结果**：`build_practice2_report.py` 零报错运行完成（OMML `61 / 10`，0 未渲染 LaTeX，0 页眉，0 非白底纹，0 禁词命中）；`04_Report\Practice2_HousePrice_Regression_Report_裴翰章_定稿版.pdf` 逐页检查确认严格 4 页、全整表不跨页。

---

## [2026-11-27] 阶段五：去单变量与梯度下降、聚焦多变量一次 vs 二次、加核心代码附录及双版本教学程序

- **用户最新澄清与要求**：
  1. 题目并未要求单变量回归，直接聚焦 8 特征多元线性回归，并与多元二次多项式回归（含平方项 $x_j^2$）对比；
  2. 彻底删去未在课上重点讲授的手动梯度下降，回归求解仅保留正规方程与 MATLAB 内置函数 `fitlm` 互证；
  3. 精简摘要文字并润色语句，第 3 节标题改为 `3. 特征贡献评估`，文末附精简核心 MATLAB 代码，并另备两版独立 MATLAB 程序（精简无注释版 + 详尽注释教学版）。
- **核心改动与验证**：
  1. `02_MATLAB_Modeling\generate_concise_report_figures.m`：将图 2 重构为 `03_Figures\fig2_ols_fit_and_residuals.png`（预测 vs 实际散点 + 残差分布），MATLAB R2025b 零警告导出 3 张 300-DPI 白底图。
  2. 新建 `02_MATLAB_Modeling\practice2_house_price_clean.m` 与 `02_MATLAB_Modeling\practice2_house_price_tutorial.m`，在 MATLAB R2025b 实跑均退出码 0，数值与 `results_summary.json` 完全一致（测试集 `RMSE=$11,030`, `R^2=0.9770`；二次 `16` 项测试集 `RMSE=$11,095`；Top 3：`GrLivArea`/`OverallQual`/`GarageCars`）。
  3. `04_Report\build_practice2_report.py` 更新并在 `self_audit_docx` 新增 `"梯度下降"`、`"批量梯度"`、`"单特征"`、`"单变量"` 禁词拦截；生成报告通过审计（OMML `52 / 7`，0 未渲染 LaTeX，0 页眉，0 非白底纹，0 禁词命中），`Practice2_HousePrice_Regression_Report_裴翰章.pdf` 逐页视觉检查通过（严格 4 页，标题单行居中，3 张表整表不跨页，第 4 页代码附录排版整洁）。脚本文件版本降级后缀已全面规范为仅作用于文件名的 `_V1`/`_V2`/`_V3`...（禁用“定稿/终版”命名）。

---

## [2026-11-27] 阶段六：V3 —— 审查 Codex V2 后补齐局部面积二次项、AI 划分原理与代码清理

- **审查背景**：Codex（`V1`/`V2`）补充了左除正规方程讲解与精简了划分说明及结论，但仍保留全 8 特征 16 项平方对比、未明示“AI 防过拟合”原理、附录第 126 行多出一行未用的 `Z_te`、且第 4 节人民币/美元表述与前文略异。
- **V3 修正与验证**：
  1. **部分二次项建模（10 项）**：逐项排查 8 特征后选定跨度最大的两个连续面积特征 `GrLivArea` 与 `TotalBsmtSF` 加二次平方项，其余 6 个特征保持线性；同步更新 `main_house_price_modeling.m` (`T2_PartialQuadratic`)、`practice2_house_price_clean.m` 与 `practice2_house_price_tutorial.m`。MATLAB R2025b 实跑：`Train RMSE=$11,168`，`5折 CV RMSE=$11,756`，`Test RMSE=$10,926`（较全线性 `\$11,030` 再降）、`Test MAE=$9,505`、`Test R^2=0.9774`。
  2. **报告正文与附录修复**：第 2 节开头明确解释借鉴 AI 训练防“背答案”（过拟合）的 8:2 划分与 5 折 CV 原理；第 2.2 节与表 2 改为“多元一次线性（8 项）vs 部分二次拟合（10 项）”；移除附录冗余 `Z_te`；统一第 4 节 `$11,030` / `$10,926` 与 `5 折` 用词。
  3. **验收通过**：XML 自检通过（`OMML 48 / 7`，0 残留 LaTeX，0 页眉，0 非白底纹，0 禁词命中）；进一步修正第 2 节与教学脚本为“AI 训练与验证过程中常用的 5 折交叉验证（CV）”并导出 `04_Report\Practice2_HousePrice_Regression_Report_裴翰章_V4.pdf`（同步刷新 `.docx` 与 `_V1.pdf`），逐页视觉检查确认严格 4 页、全整表不跨页。
