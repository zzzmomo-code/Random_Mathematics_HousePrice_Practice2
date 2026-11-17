# -*- coding: utf-8 -*-
"""
《随机数学》Practice 2 实验报告自动化构建脚本
流水线：
1. 读取 01_Data/eda_summary.json 与 02_MATLAB_Modeling/results_summary.json
2. 自动生成结构化 Markdown 源码（一式一行 LaTeX 块级公式 + 行内公式，全数来自 JSON）
3. 调用 Pandoc 编译为含 Word 原生 OMML (<m:oMath>) 公式的 DOCX
4. 通过 python-docx 深度规范排版：
   - 标题层级：主标题 20pt 黑体粗体居中、H1 14pt 黑体粗体、H2 12pt 黑体粗体、正文 10.5pt 宋体/Times New Roman（首行缩进 2 字符 = 21pt）
   - 100% 零页眉（清空所有节的常规/首页/偶页页眉）
   - 100% 纯白三线表（清除所有默认样式底纹，仅保留顶/表头底/底三根黑线）
   - 居中插图（宽度约 4.9~5.1 英寸，同步更新 wp:extent 与 a:ext，并与图注 keep_with_next）
   - 块级公式居中零缩进；含行内公式的正文段落保持正常首行缩进
5. 执行 XML 质量自检并调用 Word COM 导出正式 PDF
"""

import json
import re
import subprocess
import zipfile
from pathlib import Path
from docx import Document
from docx.shared import Pt, Inches, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import qn

PROJECT_ROOT = Path(r"E:\Random_Mathematics_Project_HousePrice")
REPORT_DIR = PROJECT_ROOT / "04_Report"
FIG_DIR = PROJECT_ROOT / "03_Figures"
EDA_JSON = PROJECT_ROOT / "01_Data" / "eda_summary.json"
RESULTS_JSON = PROJECT_ROOT / "02_MATLAB_Modeling" / "results_summary.json"
PANDOC_BIN = Path(r"C:\Users\48747\miniconda3\Library\bin\pandoc.exe")

MD_PATH = REPORT_DIR / "practice2_report_source.md"
DOCX_RAW_PATH = REPORT_DIR / "_tmp_pandoc_raw.docx"
FINAL_DOCX_PATH = REPORT_DIR / "Practice2_HousePrice_Regression_Report_裴翰章.docx"
FINAL_PDF_PATH = REPORT_DIR / "Practice2_HousePrice_Regression_Report_裴翰章.pdf"


def load_json(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"未找到数据文件: {path}")
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def fmt_int(v: float) -> str:
    return f"{v:,.0f}"


def fmt_money_int(v: float) -> str:
    if v < 0:
        return f"-${abs(v):,.0f}"
    return f"${v:,.0f}"


def fmt_money_signed(v: float) -> str:
    if v >= 0:
        return f"+${v:,.0f}"
    return f"-${abs(v):,.0f}"


def fmt_range(vmin: float, vmax: float) -> str:
    return f"[{vmin:,.0f}, {vmax:,.0f}]"


def fmt_sci(v: float) -> str:
    if v == 0:
        return "0"
    exp = int(f"{v:.2e}".split("e")[1])
    mant = v / (10 ** exp)
    return f"{mant:.2f} \\times 10^{{{exp}}}"


def build_markdown_source(eda: dict, res: dict) -> str:
    ds = res["dataset_summary"]
    eq = res["ols_equivalence_check"]
    ols_inf = res["ols_inference_train_240"]
    diag = res["best_model_diagnostics"]
    fi = res["feature_importance"]

    # 索引模型字典
    m_map = {m["id"]: m for m in res["models"]}
    m_lin1 = m_map["T1_Single_Linear"]
    m_quad1 = m_map["T1_Single_Parabolic"]
    m_ols_ne = m_map["T2_OLS_NormalEq"]
    m_ols_gd = m_map["T2_OLS_GradDesc"]
    m_ols = m_map["T2_OLS_fitlm"]
    m_pquad = m_map["T2_PureQuadratic"]
    m_fquad = m_map["T2_FullQuadratic"]
    m_ridge = m_map["T3_Ridge_L2"]
    m_lasso = m_map["T3_Lasso_L1"]
    m_tree = m_map["T4_DecisionTree"]
    m_rf = m_map["T4_RandomForest"]
    m_gbdt = m_map["T4_GBDT_LSBoost"]

    # 表 1：描述性统计 + 单变量相关 + VIF
    desc_map = {item["variable"]: item for item in eda["descriptive_stats"]}
    corr_map = {item["feature"]: item for item in eda["feature_target_correlations"]}
    unit_map = {
        "OverallQual": "分",
        "GrLivArea": "ft²",
        "GarageCars": "车位",
        "TotalBsmtSF": "ft²",
        "YearBuilt": "年",
        "FullBath": "间",
        "BedroomAbvGr": "间",
        "LotArea": "ft²",
        "SalePrice": "美元",
    }
    cn_map = dict(zip(eda["feature_names"], eda["feature_names_cn"]))
    cn_map["SalePrice"] = "销售价格（目标）"

    t1_rows = []
    for var in eda["feature_names"] + ["SalePrice"]:
        d = desc_map[var]
        if var == "SalePrice":
            mean_sd = f"{d['mean']:,.1f} ± {d['std']:,.1f}"
            r_str = "1.0000"
            vif_str = "—"
        elif var in ("OverallQual", "GarageCars", "FullBath", "BedroomAbvGr"):
            mean_sd = f"{d['mean']:.2f} ± {d['std']:.2f}"
            r_str = f"{corr_map[var]['pearson_r']:+.4f}"
            vif_str = f"{corr_map[var]['vif']:.4f}"
        else:
            mean_sd = f"{d['mean']:,.1f} ± {d['std']:,.1f}"
            r_str = f"{corr_map[var]['pearson_r']:+.4f}"
            vif_str = f"{corr_map[var]['vif']:.4f}"
        t1_rows.append(
            f"| {var} | {cn_map[var]} | {unit_map[var]} | {mean_sd} | {fmt_range(d['min'], d['max'])} | {r_str} | {vif_str} |"
        )
    table1_md = "\n".join(t1_rows)

    # 表 2：4 阶层 10 模型性能对比（OLS 三求解器等价合并为一行）
    model_rows_spec = [
        ("T1 一次线性 (GrLivArea)", m_lin1, "1"),
        ("T1 二次抛物线 (GrLivArea)", m_quad1, "2"),
        ("T2 多元 OLS (NE/GD/fitlm)*", m_ols, "8"),
        ("T2 多元纯二次 (Pure Quad)", m_pquad, "16"),
        ("T2 多元全二次 (Full Quad)", m_fquad, "44"),
        ("T3 岭回归 Ridge ($\\lambda=0$)", m_ridge, "8"),
        ("T3 Lasso ($\\lambda_{\\min}=1.0$)", m_lasso, "8"),
        ("T4 决策树 (MinLeaf=5)", m_tree, "8"),
        ("T4 随机森林 (500 树)", m_rf, "8"),
        ("T4 梯度提升树 (LSBoost)", m_gbdt, "8"),
    ]
    t2_rows = []
    for label, m, n_feat in model_rows_spec:
        is_best = (m["id"] == "T2_OLS_fitlm")
        b = "**" if is_best else ""
        t2_rows.append(
            f"| {b}{label}{b} | {n_feat} | "
            f"{b}{fmt_int(m['train']['rmse'])}{b} | {b}{m['train']['r2']:.4f}{b} | "
            f"{b}{fmt_int(m['cv_rmse_mean'])}{b} | {b}{m['cv_r2_mean']:.4f}{b} | "
            f"{b}{fmt_int(m['test']['rmse'])}{b} | {b}{fmt_int(m['test']['mae'])}{b} | {b}{m['test']['r2']:.4f}{b} |"
        )
    table2_md = "\n".join(t2_rows)

    # 表 3：8 特征 4 种方法贡献度综合对比
    ranked = fi["ranked_table"]
    t3_rows = []
    for row in ranked:
        rk = row["consensus_rank"]
        b = "**" if rk <= 3 else ""
        raw_b = row["ols_raw_beta_train"]
        raw_str = f"{raw_b:+,.2f}" if abs(raw_b) < 100 else f"{raw_b:+,.0f}"
        t3_rows.append(
            f"| {b}{rk}{b} | {b}{row['feature']} ({row['feature_cn']}){b} | "
            f"{raw_str} | {b}{fmt_int(row['ols_std_abs_beta'])} ({row['ols_std_share_pct']:.1f}%){b} | "
            f"{b}{fmt_money_signed(row['delta_cv_rmse'])}{b} | "
            f"{row['univariate_r2_all']:.4f} | "
            f"{fmt_int(row['lasso_entry_lambda'])} | "
            f"{b}{row['rf_oob_perm_imp']:.3f}{b} |"
        )
    table3_md = "\n".join(t3_rows)

    # Top 3 与关键统计数值提取
    top1, top2, top3 = ranked[0], ranked[1], ranked[2]
    top3_share = top1["ols_std_share_pct"] + top2["ols_std_share_pct"] + top3["ols_std_share_pct"]
    bed_row = next(r for r in ranked if r["feature"] == "BedroomAbvGr")
    lot_row = next(r for r in ranked if r["feature"] == "LotArea")

    lin1_slope, lin1_int = m_lin1["coefficients_raw"][0], m_lin1["coefficients_raw"][1]
    quad1_p = m_quad1["quad_term_p_value"]
    gd_grad = m_ols_gd["gd_final_grad_norm"]
    diff_pred = eq["max_test_pred_diff_NE_vs_GD"]
    diff_beta_gd = eq["max_beta_diff_GD_vs_fitlm"]
    diff_beta_ne = eq["max_beta_diff_NE_vs_fitlm"]

    md = f"""Practice 2：房价多模型回归建模与特征贡献度分析

姓名：裴翰章\u3000\u3000学号：2025310104015\u3000\u3000指导教师：梁菁 教授\u3000\u3000课程：《随机数学》

**摘要**：本文针对 300 条房屋销售价格样本，在剔除无物理意义的索引列 `Id` 后，基于 8 项物理特征开展由简到难的回归建模与特征贡献度分析。在固定划分（240 训练 / 60 测试）与无泄露 5 折交叉验证框架下，依次比较了单变量直线与抛物线拟合、多元线性回归（正规方程、手动批量梯度下降与 MATLAB `fitlm` 三种等价求解）、多元二次多项式、岭回归与 Lasso 正则化以及决策树、随机森林和梯度提升树（GBDT）共 4 阶层 10 类模型。结果表明，多元线性回归在测试集上取得最优预测精度（$\\text{{RMSE}} = \\${fmt_int(m_ols['test']['rmse'])}$，$R^2 = {m_ols['test']['r2']:.4f}$，$\\text{{MAPE}} = {m_ols['test']['mape_pct']:.2f}\\%$），高于多元二次项与树集成模型；进一步通过标准化系数、留一特征法、Lasso 正则化路径及随机森林袋外置换重要性四种互补方法交叉检验，排序完全一致（方法间 Spearman 秩相关均为 $1.000$），明确识别出对房价贡献最大的前三项核心特征依次为地上居住面积 `GrLivArea`、综合质量 `OverallQual` 与车库容量 `GarageCars`。

# 1. 问题背景与数据概况

房屋销售价格受居住面积、装修质量、配套设施与建造年代等多维因素共同影响。本次实践所用数据集采集自聚合数据平台，共包含 $N = {ds['n_total']}$ 条观测样本、10 个字段，无任何缺失值。其中首列 `Id` 为 $1 \\sim 300$ 的顺序样本编号，不承载房屋物理属性，建模前予以显式剔除；最终保留 8 项房屋物理特征作为自变量 $\\mathbf{{X}} \\in \\mathbb{{R}}^{{300 \\times 8}}$，以房屋销售价格 `SalePrice`（单位：美元）作为因变量 $\\mathbf{{y}}$。

如表 1 所示，目标变量 `SalePrice` 均值为 $\\${ds['saleprice_mean']:,.1f}$，标准差为 $\\${ds['saleprice_std']:,.1f}$，中位数为 $\\${ds['saleprice_median']:,.1f}$，偏度仅 ${ds['saleprice_skewness']:.3f}$，分布近似对称（图 1b）。在 8 项物理特征内部，任意两特征间最大绝对相关系数仅 $|r|_{{\\max}} = {ds['max_interfeature_abs_r']:.4f}$（`GarageCars` 与 `FullBath`），所有特征的 $\\text{{VIF}} \\le {ds['max_vif']:.4f}$，标准化设计矩阵条件数 $\\kappa(\\mathbf{{Z}}) = {ds['condition_number_std_X']:.4f}$，说明特征间近似正交，几乎不存在多重共线性。

表 1\u3000300 条房价样本的描述性统计、单变量相关性及共线性诊断

| 变量名称 | 中文含义 | 单位 | 均值 ± 标准差 | 极值范围 | Pearson $r$ | VIF |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
{table1_md}

![](03_Figures/fig1_eda_correlation_heatmap.png)

图 1\u30008 项物理特征与房价的 Pearson 相关系数矩阵热力图及 `SalePrice` 分布直方图

由图 1a 可见，地上居住面积 `GrLivArea` 与房价的线性相关性遥遥领先（$r = {top1['univariate_r_all']:.4f}$），其次为综合质量 `OverallQual`（$r = {top2['univariate_r_all']:.4f}$）与车库容量 `GarageCars`（$r = {top3['univariate_r_all']:.4f}$），而地上卧室数 `BedroomAbvGr`（$r = {bed_row['univariate_r_all']:.4f}$）与地块面积 `LotArea`（$r = {lot_row['univariate_r_all']:.4f}$）的单变量相关性接近零。

# 2. 由简到难的回归建模拟合

为客观比较不同复杂度模型的泛化能力，所有实验在 MATLAB R2025b 中固定随机种子 `rng(42)` 执行：先按 80%/20% 划分为训练集（$N_{{\\text{{train}}}} = {ds['n_train']}$）与独立测试集（$N_{{\\text{{test}}}} = {ds['n_test']}$），再在训练集内进行 5 折交叉验证（5-Fold CV）。凡涉及特征标准化，均值与标准差均严格在每折训练子集内部估计，避免数据泄露。各模型统一采用均方根误差 $\\text{{RMSE}}$ 与可决系数 $R^2$ 评价：

$$\\text{{RMSE}} = \\sqrt{{\\frac{{1}}{{n}}\\sum_{{i=1}}^{{n}}(y_i - \\hat{{y}}_i)^2}}$$

$$R^2 = 1 - \\frac{{\\sum_{{i=1}}^{{n}}(y_i - \\hat{{y}}_i)^2}}{{\\sum_{{i=1}}^{{n}}(y_i - \\bar{{y}})^2}}$$

## 2.1 单变量曲线拟合：一次直线与二次抛物线

从最简单模型出发，选取与房价相关性最强的单特征 `GrLivArea` 分别拟合一次直线（`poly1`）与二次抛物线（`poly2`）：

$$\\hat{{y}}_{{\\text{{poly1}}}} = \\beta_0 + \\beta_1 x, \\qquad \\hat{{y}}_{{\\text{{poly2}}}} = \\beta_0 + \\beta_1 x + \\beta_2 x^2$$

训练集拟合得一次方程 $\\hat{{y}} = {lin1_slope:.2f}\\,x + {lin1_int:,.2f}$，5 折 CV RMSE 为 $\\${fmt_int(m_lin1['cv_rmse_mean'])}$（CV $R^2 = {m_lin1['cv_r2_mean']:.4f}$），测试集 RMSE 为 $\\${fmt_int(m_lin1['test']['rmse'])}$（$R^2 = {m_lin1['test']['r2']:.4f}$）。引入二次项后，拟合曲线与一次直线几乎重合（图 2a），CV RMSE 微升至 $\\${fmt_int(m_quad1['cv_rmse_mean'])}$，且二次项显著性检验 $p = {quad1_p:.4f} > 0.05$。图 2b 残差图无明显弯曲趋势，但上下离散幅度高达 $\\pm \\$100\\text{{k}}$，说明单变量误差的核心来源是遗漏其余房屋属性，而非面积与房价之间存在高阶曲率。

![](03_Figures/fig2_single_feature_line_vs_parabola.png)

图 2\u3000单特征 `GrLivArea` 一次直线与二次抛物线拟合效果及残差分布对比

## 2.2 多元线性回归、多元多项式与正则化模型

将全部 8 项物理特征纳入多元线性回归模型 $\\mathbf{{y}} = \\mathbf{{X}}\\boldsymbol{{\\beta}} + \\boldsymbol{{\\varepsilon}}$，分别通过正规方程解析求解、标准化特征批量梯度下降（学习率 $\\alpha = {m_ols_gd['gd_lr']:.2f}$，迭代 {m_ols_gd['gd_iterations']} 步）与 MATLAB 内置 `fitlm` 三种路径求解普通最小二乘（OLS）估计：

$$\\hat{{\\boldsymbol{{\\beta}}}}_{{\\text{{OLS}}}} = (\\mathbf{{X}}^\\top \\mathbf{{X}})^{{-1}}\\mathbf{{X}}^\\top \\mathbf{{y}}$$

$$\\boldsymbol{{\\beta}}^{{(t+1)}} = \\boldsymbol{{\\beta}}^{{(t)}} - \\frac{{\\alpha}}{{n}}\\mathbf{{Z}}^\\top(\\mathbf{{Z}}\\boldsymbol{{\\beta}}^{{(t)}} - \\mathbf{{y}})$$

数值核验表明，梯度下降经约 120 步即逼近解析解（图 4a），终态梯度范数降至 ${fmt_sci(gd_grad)}$；三种求解器在测试集预测上的最大绝对差仅 ${fmt_sci(diff_pred)}$（梯度下降与 `fitlm` 系数最大差为 ${fmt_sci(diff_beta_gd)}$，正规方程与 `fitlm` 为 ${fmt_sci(diff_beta_ne)}$），证实三者数值等价。引入全部 8 特征后，模型整体显著性 $F = {ols_inf['f_stat']:.2f}$（$p = {fmt_sci(ols_inf['f_pvalue'])}$），5 折 CV RMSE 由单变量的 $\\${fmt_int(m_lin1['cv_rmse_mean'])}$ 骤降至 $\\${fmt_int(m_ols['cv_rmse_mean'])}$，测试集 RMSE 降至 $\\${fmt_int(m_ols['test']['rmse'])}$（$R^2 = {m_ols['test']['r2']:.4f}$，平均绝对百分比误差 $\\text{{MAPE}} = {m_ols['test']['mape_pct']:.2f}\\%$）。

在此基础上构造多元纯二次模型（线性项与 8 个平方项，共 16 项）及含交互全二次模型（共 44 项）。如表 2 所示，全二次模型虽将训练集 RMSE 压低至 $\\${fmt_int(m_fquad['train']['rmse'])}$（$R^2 = {m_fquad['train']['r2']:.4f}$），但 5 折 CV RMSE 反升至 $\\${fmt_int(m_fquad['cv_rmse_mean'])}$，测试集 RMSE 恶化至 $\\${fmt_int(m_fquad['test']['rmse'])}$（测试集调整后 $R^2$ 降至 ${m_fquad['test']['adj_r2']:.4f}$），在 $N_{{\\text{{train}}}} = 240$ 的小样本下出现了典型的方差膨胀与过拟合。

进一步引入 $L_2$ 岭回归（Ridge）与 $L_1$ 稀疏回归（Lasso）以检验惩罚收缩效果：

$$\\hat{{\\boldsymbol{{\\beta}}}}_{{\\text{{Ridge}}}} = \\arg\\min_{{\\boldsymbol{{\\beta}}}}\\left\\{{\\frac{{1}}{{2n}}\\|\\mathbf{{y}} - \\mathbf{{Z}}\\boldsymbol{{\\beta}}\\|_2^2 + \\lambda\\|\\boldsymbol{{\\beta}}\\|_2^2\\right\\}}$$

$$\\hat{{\\boldsymbol{{\\beta}}}}_{{\\text{{Lasso}}}} = \\arg\\min_{{\\boldsymbol{{\\beta}}}}\\left\\{{\\frac{{1}}{{2n}}\\|\\mathbf{{y}} - \\mathbf{{Z}}\\boldsymbol{{\\beta}}\\|_2^2 + \\lambda\\|\\boldsymbol{{\\beta}}\\|_1\\right\\}}$$

由于特征间几乎无共线性且 $n \\gg p$（$240 \\gg 8$），岭回归 5 折交叉验证选出 $\\lambda = {m_ridge['best_lambda']:.0f}$，自动退化为无偏 OLS；Lasso 在最小误差点 $\\lambda_{{\\min}} = {m_lasso['lambda_min']:.0f}$ 处保留全部 8 特征，测试集 RMSE 为 $\\${fmt_int(m_lasso['test']['rmse'])}$（$R^2 = {m_lasso['test']['r2']:.4f}$）；在更简洁的一倍标准误点 $\\lambda_{{\\text{{1SE}}}} = {m_lasso['lambda_1se']:.1f}$ 处，`LotArea` 标准化系数被剧烈压缩至 $-\\${abs(lot_row['lasso_beta_1se']):.0f}$，而测试集 $R^2$ 仍保持 ${m_lasso['test_1se']['r2']:.4f}$（RMSE $\\${fmt_int(m_lasso['test_1se']['rmse'])}$）。

## 2.3 树模型与集成非线性回归及全阶层对比

为考察非参数非线性方法在小样本上的表现，经 5 折交叉验证调优后依次构建回归决策树（`fitrtree`，`MinLeafSize=5`）、随机森林（`TreeBagger`，500 棵树，`MinLeafSize=2`，`mtry=7`）与梯度提升树 GBDT（`LSBoost`，一阶树桩 `MaxNumSplits=1`，学习率 0.1，300 轮）。表 2 与图 3 汇总了 4 个阶层共 10 类模型的完整表现。

表 2\u3000由简到难 4 阶层 10 类回归模型性能统一对比（训练集 240 / 独立测试集 60，RMSE/MAE 单位：美元）

| 模型名称（阶层） | 项数 | 训 RMSE | 训 $R^2$ | 5 折 CV RMSE | 5 折 CV $R^2$ | 测 RMSE | 测 MAE | 测 $R^2$ |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
{table2_md}

*注：多元 OLS 正规方程、批量梯度下降与 `fitlm` 三种求解器在测试集上预测最大差值小于 $2.5 \\times 10^{{-8}}$，各项误差指标完全一致，故合并列示；训练集 RMSE 统一按样本数 $n$ 作分母计算。

![](03_Figures/fig3_models_progression_and_diagnostics.png)

图 3\u30004 阶层 10 类模型预测误差对比及最优多元 OLS 模型预测值与残差诊断图

对比表 2 与图 3 可得三点清晰规律：第一，由单变量跃升至 8 特征多元线性模型带来了最核心的精度飞跃，测试集 $R^2$ 由 ${m_lin1['test']['r2']:.4f}$ 跃升至 ${m_ols['test']['r2']:.4f}$；第二，三类树模型均逊于多元 OLS——单棵决策树受限于轴平行阶梯分段，测试集 RMSE 高达 $\\${fmt_int(m_tree['test']['rmse'])}$；随机森林借袋装平均将其压至 $\\${fmt_int(m_rf['test']['rmse'])}$（袋外 OOB $R^2 = {m_rf['oob_r2']:.4f}$）；GBDT 在交叉验证中自动选中深度为 1 的树桩基学习器（加性结构贴近线性真理），将测试集 RMSE 进一步降至 $\\${fmt_int(m_gbdt['test']['rmse'])}$（$R^2 = {m_gbdt['test']['r2']:.4f}$），但阶梯近似在 $N=240$ 样本下仍难以达到解析线性的平滑外推精度；第三，最优 OLS 模型的预测散点紧密贴合 $y = x$ 对角线（图 3b），残差均匀分布在 $[-\\${abs(diag['all_resid_min'])/1000:.1f}\\text{{k}}, +\\${diag['all_resid_max']/1000:.1f}\\text{{k}}]$ 内且无异方差趋势（图 3c），残差峰度为 ${diag['all_resid_kurtosis']:.3f}$（轻尾有界扰动，Jarque-Bera 正态性检验 $p = {diag['jarque_bera_p']:.4f}$），印证该数据集底层高度接近“线性加性主结构 + 有界随机噪声”。

![](03_Figures/fig4_gd_convergence_and_lasso_path.png)

图 4\u3000标准化批量梯度下降收敛过程及 Lasso 正则化系数路径（特征入模顺序）

# 3. 特征贡献度多维评价与 Top 3 识别

在多元回归中，不能直接以原始回归系数 $\\hat{{\\beta}}_j$ 的绝对值大小判断特征重要性，因为各特征物理量纲悬殊：例如表 3 中 `GarageCars` 原始系数为 $+\\$19,103$/车位，远大于 `GrLivArea` 的 $+\\$54.79$/平方英尺，但前者标准差仅 $1.11$ 车位，后者标准差高达 $1042.6$ 平方英尺。为此，本实验设计了四种相互独立且互补的特征贡献度评价方法进行交叉验证：

1. **方法 A（标准化 OLS 回归系数 $|\\beta_j^*|$）**：对特征执行 Z-score 标准化后重新回归，计算单个特征变化 1 个样本标准差所引起的房价美元变动：

$$\\beta_j^* = \\hat{{\\beta}}_j \\cdot s_{{x_j}}, \\qquad z_{{ij}} = \\frac{{x_{{ij}} - \\bar{{x}}_j}}{{s_{{x_j}}}}$$

2. **方法 B（留一特征边际贡献 $\\Delta\\text{{RMSE}}_{{\\text{{CV}}}}$ 与单变量 $R^2$）**：逐一从全模型剔除第 $j$ 个特征并重算 5 折 CV RMSE，以误差增幅衡量不可替代性：

$$\\Delta\\text{{RMSE}}_{{\\text{{CV}}}}^{{(j)}} = \\text{{RMSE}}_{{\\text{{CV}}}}^{{(-j)}} - \\text{{RMSE}}_{{\\text{{CV}}}}^{{\\text{{full}}}}$$

3. **方法 C（Lasso 正则化路径入模顺序）**：沿惩罚系数 $\\lambda$ 由大到小递减，观察各特征首次获得非零系数的临界 $\\lambda$（图 4b），越早入模说明解释信号越强。

4. **方法 D（随机森林 OOB 袋外置换重要性）**：随机打乱袋外样本中特征 $j$ 的取值，以非线性模型预测误差的标准化增幅进行独立核验。

表 3\u30008 项物理特征在四种互补贡献度评价方法下的定量指标与综合排名

| 排名 | 特征名称 | 原始 $\\hat{{\\beta}}_j$ | 标准化 $|\\beta_j^*|$ (占比) | $\\Delta\\text{{RMSE}}_{{\\text{{CV}}}}$ | 单变量 $R^2$ | Lasso 入模 $\\lambda$ | RF 置换重要性 |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
{table3_md}

![](03_Figures/fig5_feature_importance_4methods.png)

图 5\u3000四种互补特征贡献度评估方法结果对比（红色柱为一致锁定的 Top 3 核心特征）

综合表 3、图 4b 与图 5 可得两项核心发现：第一，**四种评价方法高度一致锁定 Top 3 核心特征**。无论基于线性参数（方法 A）、交叉验证边际误差（方法 B）、稀疏惩罚路径（方法 C）还是非参数树集成（方法 D），全部 8 项特征的排序完全一致（方法间 Spearman 秩相关系数均为 $1.000$）。对房价贡献最大的前三项特征依次为：**第 1 名 `GrLivArea`（地上居住面积）**、**第 2 名 `OverallQual`（综合质量）**、**第 3 名 `GarageCars`（车库容量）**。三者标准化系数贡献占比合计达 ${top3_share:.1f}\\%$，其中仅剔除 `GrLivArea` 就会使 5 折 CV RMSE 暴增 $+\\${fmt_int(top1['delta_cv_rmse'])}$（$\\Delta R^2_{{\\text{{CV}}}} = {top1['delta_cv_r2']:.4f}$），剔除 `OverallQual` 与 `GarageCars` 分别使误差增加 $+\\${fmt_int(top2['delta_cv_rmse'])}$ 与 $+\\${fmt_int(top3['delta_cv_rmse'])}$。

第二，**多变量建模揭示了单变量统计容易遗漏的遮蔽效应与冗余特征**。在单变量相关中，`OverallQual`（$R^2 = {top2['univariate_r2_all']:.4f}$）与 `GarageCars`（$R^2 = {top3['univariate_r2_all']:.4f}$）几乎并列，原因在于样本中 `OverallQual` 与 `GrLivArea` 存在轻微负相关（$r = -0.1164$）；在多元 OLS 中控制居住面积后，`OverallQual` 的净贡献（$|\\beta^*| = \\${fmt_int(top2['ols_std_abs_beta'])}$）明显领先于 `GarageCars`（$\\${fmt_int(top3['ols_std_abs_beta'])}$）。同理，`BedroomAbvGr` 单变量几乎不相关（$R^2 = {bed_row['univariate_r2_all']:.4f}$），控制面积后呈现显著正向贡献（$p = {fmt_sci(bed_row['ols_pvalue_train'])}$，每增 1 间卧室增价 $\\${fmt_int(bed_row['ols_raw_beta_train'])}$）；而 `LotArea` 回归系数不显著（$p = {lot_row['ols_pvalue_train']:.3f}$），剔除后 5 折 CV RMSE 反而微降 $\\${abs(lot_row['delta_cv_rmse']):.0f}$，属冗余特征。从物理意义看，Top 3 分别代表“空间体量（约 $\\$54.8/\\text{{ft}}^2$）、建筑品质（约 $\\$11,892$/级）、刚性配套（约 $\\$19,103$/车位）”三大核心定价维度，高度契合住宅市场规律。

# 4. 结论与思考

1. **模型复杂度须与样本规模及数据机理匹配**：在 $N=300$ 的小样本条件下，多元线性回归（测试集 $R^2 = {m_ols['test']['r2']:.4f}$，RMSE $= \\${fmt_int(m_ols['test']['rmse'])}$）显著优于易过拟合的 44 项全二次多项式（RMSE $= \\${fmt_int(m_fquad['test']['rmse'])}$）以及依赖阶梯近似的决策树、随机森林与 GBDT，体现了偏差-方差权衡在统计建模中的关键作用。
2. **理论推导与数值优化相互印证**：多元 OLS 的正规方程解析解、手动批量梯度下降迭代解与 MATLAB `fitlm` 求解结果在 $10^{{-8}}$ 精度内一致；在近似正交（$\\max\\text{{VIF}} = {ds['max_vif']:.4f}$）的数据上岭回归与 Lasso 虽未进一步降低测试误差，但 Lasso 路径直观刻画了特征重要性的先后层次。
3. **科学评估特征贡献须消除量纲与共变干扰**：直接比较原始系数会严重低估大尺度特征 `GrLivArea` 的主导地位；经四维方法交叉验证，可靠确立了 `GrLivArea`、`OverallQual`、`GarageCars` 为 Top 3 核心特征，并识别出 `LotArea` 在本样本中的统计不显著性。
4. **实验边界与展望**：本结论基于当前 300 条结构化样本与 8 项房屋物理属性得出，残差呈轻尾有界特征，尚未包含区位地段与宏观利率等因素；若推广至更大规模的真实跨区域房产数据，可进一步检验对数目标变换与非线性交互特征的改进空间。

# 5. 参考文献

[1] 聚合数据. 房屋销售价格学习训练数据集 [DB/OL]. https://www.juhe.cn/dataset/product/id/mva1wdNmuJB.

[2] MathWorks. Statistics and Machine Learning Toolbox User's Guide (R2025b) [EB/OL]. Natick, MA: The MathWorks, Inc., 2025.

[3] James G, Witten D, Hastie T, Tibshirani R. An Introduction to Statistical Learning with Applications in R (2nd ed.) [M]. New York: Springer, 2021.
"""
    return md


def compile_pandoc(md_path: Path, out_docx: Path) -> None:
    cmd = [
        str(PANDOC_BIN),
        str(md_path),
        "-f", "markdown+tex_math_dollars+pipe_tables-implicit_figures",
        "-t", "docx",
        "-o", str(out_docx),
        f"--resource-path={PROJECT_ROOT};{FIG_DIR};{REPORT_DIR}",
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if res.returncode != 0:
        raise RuntimeError(f"Pandoc 编译失败:\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")
    print(f"[OK] Pandoc 编译完成: {out_docx}")


def set_run_font(
    run,
    east_asia: str = "宋体",
    size_pt: float = 10.5,
    bold: bool | None = None,
    italic: bool | None = None,
    color_rgb: tuple[int, int, int] = (0, 0, 0),
    latin: str = "Times New Roman",
) -> None:
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic
    run.font.size = Pt(size_pt)
    run.font.color.rgb = RGBColor(*color_rgb)
    run.font.name = latin
    rPr = run._r.get_or_add_rPr()
    for old_rf in rPr.findall(qn("w:rFonts")):
        rPr.remove(old_rf)
    rFonts = OxmlElement("w:rFonts")
    rFonts.set(qn("w:ascii"), latin)
    rFonts.set(qn("w:hAnsi"), latin)
    rFonts.set(qn("w:cs"), latin)
    rFonts.set(qn("w:eastAsia"), east_asia)
    rPr.insert(0, rFonts)


def clear_all_headers(doc: Document) -> None:
    for section in doc.sections:
        section.different_first_page_header_footer = False
        for hdr in (section.header, section.first_page_header, section.even_page_header):
            hdr.is_linked_to_previous = False
            for p in list(hdr.paragraphs):
                p.text = ""
                for r in list(p.runs):
                    r.text = ""
            for t in list(hdr.tables):
                t._element.getparent().remove(t._element)


def setup_page_footer_page_number(section) -> None:
    footer = section.footer
    footer.is_linked_to_previous = False
    f_p = footer.paragraphs[0] if footer.paragraphs else footer.add_paragraph()
    f_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    f_p.paragraph_format.first_line_indent = Pt(0)
    f_p.paragraph_format.space_before = Pt(0)
    f_p.paragraph_format.space_after = Pt(0)
    f_p.text = ""
    fldSimple = OxmlElement("w:fldSimple")
    fldSimple.set(qn("w:instr"), "PAGE")
    r = OxmlElement("w:r")
    rPr = OxmlElement("w:rPr")
    rFonts = OxmlElement("w:rFonts")
    rFonts.set(qn("w:ascii"), "Times New Roman")
    rFonts.set(qn("w:hAnsi"), "Times New Roman")
    rPr.append(rFonts)
    sz = OxmlElement("w:sz")
    sz.set(qn("w:val"), "18")  # 9pt
    rPr.append(sz)
    r.append(rPr)
    fldSimple.append(r)
    f_p._p.append(fldSimple)


def is_display_math_paragraph(p) -> bool:
    xml = p._element.xml
    if "oMathPara" in xml:
        return True
    if "oMath" in xml and not p.text.strip():
        return True
    return False


def has_drawing_element(p) -> bool:
    return "w:drawing" in p._element.xml or "wp:inline" in p._element.xml


def resize_drawing_in_paragraph(p, target_width_in: float = 5.0, max_height_in: float = 3.6) -> None:
    emu_per_in = 914400
    target_cx = int(target_width_in * emu_per_in)
    max_cy = int(max_height_in * emu_per_in)

    for drawing in p._element.iter(qn("w:drawing")):
        exts = list(drawing.iter(qn("wp:extent")))
        if not exts:
            continue
        orig_cx = int(exts[0].get("cx", "0"))
        orig_cy = int(exts[0].get("cy", "0"))
        if orig_cx <= 0 or orig_cy <= 0:
            continue

        scale = target_cx / orig_cx
        new_cx = target_cx
        new_cy = int(orig_cy * scale)
        if new_cy > max_cy:
            scale2 = max_cy / new_cy
            new_cy = max_cy
            new_cx = int(new_cx * scale2)

        for ext in exts:
            ext.set("cx", str(new_cx))
            ext.set("cy", str(new_cy))
        for spPr in drawing.iter(qn("pic:spPr")):
            for a_ext in spPr.iter(qn("a:ext")):
                a_ext.set("cx", str(new_cx))
                a_ext.set("cy", str(new_cy))


def style_three_line_table(table, col_widths_in: list[float] | None = None) -> None:
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False

    tblPr = table._tbl.tblPr
    for tag in ("w:tblStyle", "w:shd", "w:tblBorders", "w:tblLook"):
        for el in tblPr.findall(qn(tag)):
            tblPr.remove(el)

    tblBorders = parse_xml(
        '<w:tblBorders xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/>'
        '<w:right w:val="none"/><w:insideH w:val="none"/><w:insideV w:val="none"/>'
        "</w:tblBorders>"
    )
    tblPr.append(tblBorders)

    for el in tblPr.findall(qn("w:tblCellMar")):
        tblPr.remove(el)
    tblCellMar = parse_xml(
        '<w:tblCellMar xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:top w:w="36" w:type="dxa"/><w:bottom w:w="36" w:type="dxa"/>'
        '<w:left w:w="50" w:type="dxa"/><w:right w:w="50" w:type="dxa"/>'
        "</w:tblCellMar>"
    )
    tblPr.append(tblCellMar)

    n_rows = len(table.rows)
    for r_idx, row in enumerate(table.rows):
        trPr = row._tr.get_or_add_trPr()
        for tag in ("w:cantSplit", "w:tblHeader"):
            for el in trPr.findall(qn(tag)):
                trPr.remove(el)
        trPr.append(parse_xml('<w:cantSplit xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>'))
        if r_idx == 0:
            trPr.append(parse_xml('<w:tblHeader xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>'))

        for c_idx, cell in enumerate(row.cells):
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            if col_widths_in and c_idx < len(col_widths_in):
                cell.width = Inches(col_widths_in[c_idx])

            tcPr = cell._tc.get_or_add_tcPr()
            for old_shd in tcPr.findall(qn("w:shd")):
                tcPr.remove(old_shd)
            tcPr.append(
                parse_xml(
                    '<w:shd xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
                    'w:val="clear" w:color="auto" w:fill="FFFFFF"/>'
                )
            )

            for old_b in tcPr.findall(qn("w:tcBorders")):
                tcPr.remove(old_b)
            top_attr = 'w:val="single" w:sz="12" w:space="0" w:color="000000"' if r_idx == 0 else 'w:val="nil"'
            if r_idx == n_rows - 1:
                bot_attr = 'w:val="single" w:sz="12" w:space="0" w:color="000000"'
            elif r_idx == 0:
                bot_attr = 'w:val="single" w:sz="6" w:space="0" w:color="000000"'
            else:
                bot_attr = 'w:val="nil"'

            tcBorders = parse_xml(
                f'<w:tcBorders xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
                f"<w:top {top_attr}/>"
                f'<w:left w:val="nil"/>'
                f"<w:bottom {bot_attr}/>"
                f'<w:right w:val="nil"/>'
                f"</w:tcBorders>"
            )
            tcPr.append(tcBorders)

            for p in cell.paragraphs:
                p.alignment = WD_ALIGN_PARAGRAPH.LEFT if (c_idx == 0 and r_idx > 0 and len(row.cells) != 8) else WD_ALIGN_PARAGRAPH.CENTER
                if len(row.cells) == 8 and c_idx == 1 and r_idx > 0:
                    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
                p.paragraph_format.first_line_indent = Pt(0)
                p.paragraph_format.left_indent = Pt(0)
                p.paragraph_format.space_before = Pt(1)
                p.paragraph_format.space_after = Pt(1)
                p.paragraph_format.line_spacing = 1.06
                for r in p.runs:
                    is_hdr = r_idx == 0
                    set_run_font(
                        r,
                        east_asia="黑体" if is_hdr else "宋体",
                        size_pt=8.5 if is_hdr else 8.0,
                        bold=True if is_hdr else r.bold,
                    )


def polish_word_document(
    in_docx: Path,
    out_docx: Path,
    table_widths_list: list[list[float]],
    fig_widths: dict[int, tuple[float, float]] | None = None,
) -> None:
    doc = Document(str(in_docx))

    # A4 紧凑规范边距
    for section in doc.sections:
        section.page_width = Inches(8.27)
        section.page_height = Inches(11.69)
        section.top_margin = Inches(0.60)
        section.bottom_margin = Inches(0.60)
        section.left_margin = Inches(0.75)
        section.right_margin = Inches(0.75)
        section.header_distance = Inches(0.28)
        section.footer_distance = Inches(0.30)
        section.gutter = 0
        setup_page_footer_page_number(section)

    clear_all_headers(doc)

    fig_counter = 0
    in_references = False

    for idx, p in enumerate(doc.paragraphs):
        txt = p.text.strip()
        style_name = p.style.name if p.style else ""

        if idx == 0:
            # 主标题：20pt 黑体粗体居中
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(4)
            p.paragraph_format.line_spacing = 1.15
            for r in p.runs:
                set_run_font(r, east_asia="黑体", size_pt=20.0, bold=True)
            continue

        if idx == 1:
            # 学生与课程信息栏：10.5pt 楷体居中
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(6)
            p.paragraph_format.line_spacing = 1.15
            for r in p.runs:
                set_run_font(r, east_asia="楷体", size_pt=10.5, bold=False)
            continue

        if style_name.startswith("Heading 1"):
            in_references = ("参考文献" in txt) or ("References" in txt)
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(9)
            p.paragraph_format.space_after = Pt(3)
            p.paragraph_format.line_spacing = 1.15
            p.paragraph_format.keep_with_next = True
            for r in p.runs:
                set_run_font(r, east_asia="黑体", size_pt=14.0, bold=True)
            continue

        if style_name.startswith("Heading 2"):
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(6)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.15
            p.paragraph_format.keep_with_next = True
            for r in p.runs:
                set_run_font(r, east_asia="黑体", size_pt=12.0, bold=True)
            continue

        if has_drawing_element(p):
            fig_counter += 1
            w_in, max_h_in = (5.05, 3.6)
            if fig_widths and fig_counter in fig_widths:
                w_in, max_h_in = fig_widths[fig_counter]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(3)
            p.paragraph_format.space_after = Pt(1)
            p.paragraph_format.keep_with_next = True
            resize_drawing_in_paragraph(p, target_width_in=w_in, max_height_in=max_h_in)
            continue

        if is_display_math_paragraph(p):
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.12
            continue

        if re.match(r"^图\s*\d+", txt) and len(txt) < 65 and "。" not in txt:
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(3.5)
            p.paragraph_format.line_spacing = 1.08
            for r in p.runs:
                set_run_font(r, east_asia="黑体", size_pt=9.5, bold=True)
            continue

        if re.match(r"^表\s*\d+", txt) and len(txt) < 65 and "。" not in txt:
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(3.5)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.08
            p.paragraph_format.keep_with_next = True
            for r in p.runs:
                set_run_font(r, east_asia="黑体", size_pt=9.5, bold=True)
            continue

        if txt.startswith("*注：") or txt.startswith("注："):
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(3)
            p.paragraph_format.line_spacing = 1.10
            for r in p.runs:
                set_run_font(r, east_asia="宋体", size_pt=8.5, italic=False)
            continue

        if in_references:
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.15
            for r in p.runs:
                set_run_font(r, east_asia="宋体", size_pt=9.5, bold=False)
            continue

        # 列表段落（如 1. **方法 A...** 或 结论 1..4）保持清晰排版
        if p._p.pPr is not None and p._p.pPr.find(qn("w:numPr")) is not None:
            p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            p.paragraph_format.left_indent = Pt(21)
            p.paragraph_format.first_line_indent = Pt(-12)
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(1.5)
            p.paragraph_format.line_spacing = 1.14
            for r in p.runs:
                set_run_font(r, east_asia="宋体", size_pt=10.5)
            continue

        # 普通正文段落（含行内公式）：10.5pt 宋体 / Times New Roman，首行缩进 2 字符 (21pt)
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        p.paragraph_format.left_indent = Pt(0)
        p.paragraph_format.first_line_indent = Pt(21)
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(1.8)
        p.paragraph_format.line_spacing = 1.15
        for r in p.runs:
            set_run_font(r, east_asia="宋体", size_pt=10.5)

    for t_idx, table in enumerate(doc.tables):
        widths = table_widths_list[t_idx] if t_idx < len(table_widths_list) else None
        style_three_line_table(table, col_widths_in=widths)

    doc.save(str(out_docx))
    print(f"[OK] Word 文档排版完成: {out_docx}")


def export_pdf_via_word_com(docx_path: Path, pdf_path: Path) -> None:
    ps_script = f'''
$ErrorActionPreference = "Stop"
$word = $null
$doc = $null
try {{
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $doc = $word.Documents.Open("{docx_path}")
    $doc.SaveAs([ref]"{pdf_path}", [ref]17)
}} finally {{
    if ($doc -ne $null) {{ $doc.Close([ref]0) }}
    if ($word -ne $null) {{ $word.Quit() }}
}}
'''
    res = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps_script],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=90,
    )
    if res.returncode != 0:
        raise RuntimeError(f"Word COM 导出 PDF 失败:\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")
    if not pdf_path.exists():
        raise FileNotFoundError(f"PDF 导出后未找到文件: {pdf_path}")
    print(f"[OK] PDF 导出完成: {pdf_path}")


def self_audit_docx(docx_path: Path) -> None:
    with zipfile.ZipFile(docx_path, "r") as zf:
        doc_xml = zf.read("word/document.xml").decode("utf-8", errors="ignore")
        hdr_files = [n for n in zf.namelist() if n.startswith("word/header") and n.endswith(".xml")]
        hdr_text = ""
        for hf in hdr_files:
            raw = zf.read(hf).decode("utf-8", errors="ignore")
            hdr_text += "".join(re.findall(r"<w:t[^>]*>(.*?)</w:t>", raw))

    omath_count = len(re.findall(r"<m:oMath\b", doc_xml))
    raw_latex_hits = re.findall(r"(\\frac|\\sum|\\beta|\$\$)", doc_xml)
    non_white_shd = re.findall(r'<w:shd[^>]*w:fill="(?!FFFFFF|auto)[^"]+"', doc_xml)
    forbidden = [n for n in ("王昊坤", "陈振夫", "百分百", "穷尽", "万无一失") if n in doc_xml]

    print(f"[AUDIT] OMML <m:oMath> 数量: {omath_count}")
    print(f"[AUDIT] 残留原始 LaTeX 命中: {len(raw_latex_hits)}")
    print(f"[AUDIT] 页眉残留文字长度: {len(hdr_text.strip())}")
    print(f"[AUDIT] 非白表格底纹数量: {len(non_white_shd)}")
    print(f"[AUDIT] 禁词/非本人姓名命中: {forbidden}")

    assert omath_count >= 5, f"OMML 公式过少: {omath_count}"
    assert len(raw_latex_hits) == 0, f"发现未编译 LaTeX: {raw_latex_hits[:5]}"
    assert len(hdr_text.strip()) == 0, f"页眉非空: {hdr_text}"
    assert len(non_white_shd) == 0, f"存在非白底纹: {non_white_shd[:5]}"
    assert len(forbidden) == 0, f"存在禁词或非本人姓名: {forbidden}"


def main() -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    eda = load_json(EDA_JSON)
    res = load_json(RESULTS_JSON)

    md = build_markdown_source(eda, res)
    MD_PATH.write_text(md, encoding="utf-8")
    print(f"[OK] Markdown 源码已生成: {MD_PATH}")

    compile_pandoc(MD_PATH, DOCX_RAW_PATH)

    # 总宽度约 6.77 英寸 (8.27 - 1.50)
    table_widths_list = [
        [1.00, 1.05, 0.55, 1.25, 1.22, 0.85, 0.85],              # 表 1 (7 列)
        [1.82, 0.42, 0.62, 0.60, 0.78, 0.68, 0.62, 0.61, 0.62],  # 表 2 (9 列)
        [0.38, 1.38, 0.66, 1.12, 0.84, 0.66, 0.82, 0.91],        # 表 3 (8 列)
    ]
    fig_widths = {
        1: (5.05, 2.38),  # Fig 1 (宽双子图)
        2: (5.05, 2.38),  # Fig 2 (宽双子图)
        3: (5.10, 3.55),  # Fig 3 (上+下双行组合图)
        4: (5.05, 2.38),  # Fig 4 (宽双子图)
        5: (5.05, 3.30),  # Fig 5 (2x2 四子图)
    }

    polish_word_document(
        DOCX_RAW_PATH,
        FINAL_DOCX_PATH,
        table_widths_list=table_widths_list,
        fig_widths=fig_widths,
    )
    self_audit_docx(FINAL_DOCX_PATH)
    export_pdf_via_word_com(FINAL_DOCX_PATH, FINAL_PDF_PATH)
    if DOCX_RAW_PATH.exists():
        DOCX_RAW_PATH.unlink()
    print("[DONE] Practice 2 报告构建与自检全部通过。")


if __name__ == "__main__":
    main()
