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
