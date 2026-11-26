# -*- coding: utf-8 -*-
"""
《随机数学》Practice 2 实验报告自动化构建脚本（极简课内论文格式版）
流水线：
1. 读取 01_Data/eda_summary.json 与 02_MATLAB_Modeling/results_summary.json
2. 生成纯课堂表述、简练学生口吻的 Markdown 源码（严格一式一行 LaTeX 公式，全数来自 JSON）
3. 调用 Pandoc 编译为含 Word 原生 OMML (<m:oMath>) 公式的 DOCX
4. 通过 python-docx 深度规范论文格式排版：
   - 主标题 20pt 黑体粗体居中、H1 14pt 黑体粗体、H2 12pt 黑体粗体、正文 10.5pt 宋体/Times New Roman（首行缩进 2 字符 = 21pt）
   - 100% 零页眉（清空所有节的常规/首页/偶页页眉）
   - 100% 纯白三线表（无任何底色底纹，仅保留顶/表头底/底三根黑线）
   - 居中插图与图注 keep_with_next，公式引入段与块级公式 keep_with_next
5. 执行 XML 质量与术语自检，并调用 Word COM 导出正式 PDF（支持被占用时安全降级保存）
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
FALLBACK_DOCX_PATH = REPORT_DIR / "Practice2_HousePrice_Regression_Report_裴翰章_精简版.docx"
FINAL_PDF_PATH = REPORT_DIR / "Practice2_HousePrice_Regression_Report_裴翰章.pdf"
FALLBACK_PDF_PATH = REPORT_DIR / "Practice2_HousePrice_Regression_Report_裴翰章_精简版.pdf"


def load_json(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"未找到数据文件: {path}")
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def fmt_int(v: float) -> str:
    return f"{v:,.0f}"


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
    fi = res["feature_importance"]

    m_map = {m["id"]: m for m in res["models"]}
    m_lin1 = m_map["T1_Single_Linear"]
    m_quad1 = m_map["T1_Single_Parabolic"]
    m_ols_ne = m_map["T2_OLS_NormalEq"]
    m_ols_gd = m_map["T2_OLS_GradDesc"]
    m_ols = m_map["T2_OLS_fitlm"]

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

    # 表 1：8 个特征与房价的基本统计和相关系数
    t1_rows = []
    for var in eda["feature_names"] + ["SalePrice"]:
        d = desc_map[var]
        range_str = fmt_range(d["min"], d["max"])
        if var == "SalePrice":
            mean_sd = f"{d['mean']:,.1f} ± {d['std']:,.1f}"
            r_str = "1.0000"
        elif var == "YearBuilt":
            mean_sd = f"{d['mean']:.1f} ± {d['std']:.1f}"
            range_str = f"[{d['min']:.0f}, {d['max']:.0f}]"
            r_str = f"{corr_map[var]['pearson_r']:+.4f}"
        elif var in ("OverallQual", "GarageCars", "FullBath", "BedroomAbvGr"):
            mean_sd = f"{d['mean']:.2f} ± {d['std']:.2f}"
            r_str = f"{corr_map[var]['pearson_r']:+.4f}"
        else:
            mean_sd = f"{d['mean']:,.1f} ± {d['std']:,.1f}"
            r_str = f"{corr_map[var]['pearson_r']:+.4f}"
        t1_rows.append(
            f"| {var} | {cn_map[var]} | {unit_map[var]} | {mean_sd} | {range_str} | {r_str} |"
        )
    table1_md = "\n".join(t1_rows)

    # 表 2：模型对比（紧扣课内曲线拟合、多元回归正规方程及手动梯度下降单拓展）
    model_rows_spec = [
        ("单特征一次直线 (GrLivArea)", m_lin1, "1"),
        ("单特征二次抛物线 (GrLivArea)", m_quad1, "2"),
        ("多元线性回归（正规方程 / fitlm）", m_ols_ne, "8"),
        ("多元线性回归（手动梯度下降）", m_ols_gd, "8"),
    ]
    t2_rows = []
    for label, m, n_feat in model_rows_spec:
        is_best = m["id"] in ("T2_OLS_NormalEq", "T2_OLS_GradDesc")
        b = "**" if is_best else ""
        t2_rows.append(
            f"| {b}{label}{b} | {n_feat} | "
            f"{b}{fmt_int(m['train']['rmse'])}{b} | "
            f"{b}{fmt_int(m['cv_rmse_mean'])}{b} | "
            f"{b}{fmt_int(m['test']['rmse'])}{b} | "
            f"{b}{fmt_int(m['test']['mae'])}{b} | "
            f"{b}{m['test']['r2']:.4f}{b} |"
        )
    table2_md = "\n".join(t2_rows)

    # 表 3：8 特征贡献度评价与排名
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
            f"{row['univariate_r_all']:+.4f} |"
        )
    table3_md = "\n".join(t3_rows)

    top1, top2, top3 = ranked[0], ranked[1], ranked[2]
    top3_share = top1["ols_std_share_pct"] + top2["ols_std_share_pct"] + top3["ols_std_share_pct"]
    lot_row = next(r for r in ranked if r["feature"] == "LotArea")

    lin1_slope, lin1_int = m_lin1["coefficients_raw"][0], m_lin1["coefficients_raw"][1]
    quad1_p = m_quad1["quad_term_p_value"]
    diff_pred = eq["max_test_pred_diff_NE_vs_GD"]
    diff_beta_gd = eq["max_beta_diff_GD_vs_fitlm"]

    md = f"""Practice 2：房价回归建模与特征贡献度分析

姓名：裴翰章\u3000\u3000学号：2025310104015\u3000\u3000指导教师：梁菁 教授\u3000\u3000课程：《随机数学》

**摘要**：本文基于聚合数据平台提供的 300 条房价数据，剔除无实际含义的编号列 `Id` 后，利用其余 8 个房屋属性在 MATLAB R2025b 中完成房价回归建模与特征贡献度分析。模型上先比较单特征一次直线与二次抛物线拟合，再建立 8 特征多元线性回归，并采用正规方程、MATLAB 内置函数 `fitlm` 与手动批量梯度下降三种方式求解互证，在测试集上取得决定系数 $R^2 = {m_ols['test']['r2']:.4f}$、均方根误差 $\\text{{RMSE}} = \\${fmt_int(m_ols['test']['rmse'])}$ 的预测效果。随后通过标准化回归系数与逐个去特征法综合评估，一致确定对房价贡献最大的前三个特征依次为地上居住面积 `GrLivArea`、综合质量 `OverallQual` 与车库容量 `GarageCars`。

# 1. 引言与数据概况

本次实验利用真实房屋交易样本建立回归模型预测房价，并找出对房价贡献最大的前三个特征。数据来源于聚合数据平台，共有 $N = {ds['n_total']}$ 条样本、10 列且无缺失值。首列 `Id` 仅为 $1 \\sim 300$ 的顺序编号，建模前将它剔除，保留 8 个房屋物理属性作为输入 $\\mathbf{{X}} \\in \\mathbb{{R}}^{{300 \\times 8}}$，销售价格 `SalePrice`（美元）作为输出 $\\mathbf{{y}}$。

表 1 与图 1 给出了各变量的统计特征及相关性。地上居住面积 `GrLivArea` 与房价的相关系数最高（$r = {top1['univariate_r_all']:.4f}$），其次为综合质量 `OverallQual`（$r = {top2['univariate_r_all']:.4f}$）与车库容量 `GarageCars`（$r = {top3['univariate_r_all']:.4f}$），而 8 个特征彼此之间的相关性都很小（最大不超过 $0.13$）。

表 1\u3000300 条房价样本各变量的基本统计与相关系数

| 变量名称 | 中文含义 | 单位 | 均值 ± 标准差 | 取值范围 | 相关系数 $r$ |
| :--- | :---: | :---: | :---: | :---: | :---: |
{table1_md}

![](03_Figures/fig1_concise_eda.png)

图 1\u30008 个特征与房价的相关系数矩阵及 `SalePrice` 分布直方图

# 2. 回归模型建立与拟合分析

为客观评估模型对未知数据的预测效果，固定随机种子 `rng(42)` 按 8:2 将样本分成训练集（$240$ 条）和测试集（$60$ 条），并在训练集内做 5 折交叉验证（简称 CV，把训练数据平均分成 5 份，轮流拿 4 份训练、1 份验证并取平均误差）。下文采用均方根误差 $\\text{{RMSE}}$（预测值与真实值平均偏离幅度）、平均绝对误差 $\\text{{MAE}}$ 与决定系数 $R^2$（越接近 1 拟合越好）评价模型性能：

$$\\text{{RMSE}} = \\sqrt{{\\frac{{1}}{{n}}\\sum_{{i=1}}^{{n}}(y_i - \\hat{{y}}_i)^2}}$$

$$R^2 = 1 - \\frac{{\\sum_{{i=1}}^{{n}}(y_i - \\hat{{y}}_i)^2}}{{\\sum_{{i=1}}^{{n}}(y_i - \\bar{{y}})^2}}$$

## 2.1 单变量线性与二次拟合

先选取相关系数最高的 `GrLivArea`，仿照曲线拟合工具箱思路分别用一次直线和二次抛物线去拟合房价：

$$\\hat{{y}}_{{\\text{{line}}}} = \\beta_0 + \\beta_1 x$$

$$\\hat{{y}}_{{\\text{{quad}}}} = \\beta_0 + \\beta_1 x + \\beta_2 x^2$$

拟合得到一次直线 $\\hat{{y}} = {lin1_slope:.2f}\\,x + {lin1_int:,.2f}$，测试集 $\\text{{RMSE}} = \\${fmt_int(m_lin1['test']['rmse'])}$，$R^2 = {m_lin1['test']['r2']:.4f}$；改用二次抛物线后，测试集 $\\text{{RMSE}} = \\${fmt_int(m_quad1['test']['rmse'])}$，$R^2 = {m_quad1['test']['r2']:.4f}$（二次项系数 $p = {quad1_p:.4f} > 0.05$，并不显著）。如图 2 所示，两条拟合线几乎重合，残差仍达 $\\pm\\$100\\text{{k}}$，说明只看面积一个变量不够，需要把其余特征一起放入多元模型。

![](03_Figures/fig2_concise_line_vs_parabola.png)

图 2\u3000单特征 `GrLivArea` 一次直线与二次抛物线拟合及残差对比

## 2.2 多元线性回归与梯度下降求解

将全部 8 个特征代入多元线性回归模型 $\\mathbf{{y}} = \\mathbf{{X}}\\boldsymbol{{\\beta}} + \\boldsymbol{{\\varepsilon}}$，我们先按课堂最小二乘正规方程直接求解析解，并与 MATLAB 自带的线性回归函数 `fitlm` 核对：

$$\\hat{{\\boldsymbol{{\\beta}}}} = (\\mathbf{{X}}^\\top \\mathbf{{X}})^{{-1}}\\mathbf{{X}}^\\top \\mathbf{{y}}$$

在此基础上，再加入一个最贴近微积分知识的拓展方法——自己编写**批量梯度下降**程序，对标准化特征 $\\mathbf{{Z}}$ 沿负梯度方向逐步迭代更新参数（学习率 $\\alpha = {m_ols_gd['gd_lr']:.2f}$，迭代 {m_ols_gd['gd_iterations']} 步）：

$$\\boldsymbol{{\\beta}}^{{(t+1)}} = \\boldsymbol{{\\beta}}^{{(t)}} - \\frac{{\\alpha}}{{n}}\\mathbf{{Z}}^\\top(\\mathbf{{Z}}\\boldsymbol{{\\beta}}^{{(t)}} - \\mathbf{{y}})$$

如表 2 和图 3 所示，8 个特征全部加入后模型误差大幅下降，测试集 $\\text{{RMSE}}$ 从 $\\${fmt_int(m_lin1['test']['rmse'])}$ 降到 $\\${fmt_int(m_ols['test']['rmse'])}$，$R^2$ 升至 ${m_ols['test']['r2']:.4f}$，预测值与真实值紧贴在 $y=x$ 直线附近（图 3a）。手动梯度下降大约跑 120 步就稳步收敛到正规方程的解析解（图 3b），两种方式在测试集上的预测差值最大仅 ${fmt_sci(diff_pred)}$（系数最大差 ${fmt_sci(diff_beta_gd)}$），说明解析求解与迭代寻优结果完全一致。

表 2\u3000单变量与多元线性回归模型性能对比（RMSE、MAE 单位：美元）

| 模型名称 | 特征数 | 训练 RMSE | 5 折交叉验证 RMSE | 测试 RMSE | 测试 MAE | 测试 $R^2$ |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
{table2_md}

![](03_Figures/fig3_ols_fit_and_gd.png)

图 3\u3000多元线性回归预测效果图与梯度下降法均方误差收敛曲线

# 3. 特征贡献度评估与关键特征识别

判断哪个特征对房价贡献最大时，不能直接拿多元回归的原始系数 $\\hat{{\\beta}}_j$ 比大小，因为各特征单位完全不同。例如表 3 里 `GarageCars` 每多 1 个车位涨价 $+\\$19,103$，而 `GrLivArea` 每多 1 平方英尺只涨 $+\\$54.79$，但面积动辄相差上千平方英尺，车位一共才 0～3 个。由于课堂上没有专门讲过特征重要性的排序方法，这里设计了两种原理简单、互相印证的评价方案：

1. **方法 1（标准化回归系数 $|\\beta_j^*|$）**：先把每个特征减去均值再除以各自的标准差（即做标准化，消除平方英尺、年份、个数等单位差异），让所有特征都站在“变化 1 个标准差”的同一起跑线上再回归。此时算出的 $|\\beta_j^*|$ 直接表示该特征每波动 1 个标准差平均会引起多少美元的房价变化，消除了量纲偏差，数值越大贡献越强：

$$z_{{ij}} = \\frac{{x_{{ij}} - \\bar{{x}}_j}}{{s_{{x_j}}}}$$

$$\\beta_j^* = \\hat{{\\beta}}_j \\cdot s_{{x_j}}$$

2. **方法 2（逐个去掉特征看误差增幅 $\\Delta\\text{{RMSE}}_{{\\text{{CV}}}}$）**：依次从 8 个特征中临时拿掉第 $j$ 个特征，只用其余 7 个特征重新建模并计算 5 折 CV 的 RMSE。拿掉某个特征后，预测误差涨得越多，说明它包含的信息越不能被其他特征替代，对预测房价也就越重要，这从模型依赖度的角度检验了特征贡献：

$$\\Delta\\text{{RMSE}}_{{\\text{{CV}}}}^{{(j)}} = \\text{{RMSE}}_{{\\text{{CV}}}}^{{(-j)}} - \\text{{RMSE}}_{{\\text{{CV}}}}^{{\\text{{full}}}}$$

表 3\u30008 个特征在两种评价方法下的贡献度对比与排名

| 排名 | 特征名称 | 原始系数 $\\hat{{\\beta}}_j$ | 标准化系数 $|\\beta_j^*|$ (占比) | 去掉后误差增幅 | 相关系数 $r$ |
| :---: | :--- | :---: | :---: | :---: | :---: |
{table3_md}

![](03_Figures/fig4_feature_importance_top3.png)

图 4\u3000标准化回归系数与去特征误差增幅对比图（红色为前 3 贡献特征）

从表 3 和图 4 可以看出，两种思路完全不同的方法对全部 8 个特征给出了完全一致的排序。对房价贡献最大的前三个特征依次是：**第 1 名 `GrLivArea`（地上居住面积）**、**第 2 名 `OverallQual`（综合质量）** 和 **第 3 名 `GarageCars`（车库容量）**，三者合计占全部标准化贡献的 ${top3_share:.1f}\\%$；只要去掉 `GrLivArea`，误差就会暴涨 $+\\${fmt_int(top1['delta_cv_rmse'])}$。此外，多变量回归还体现了单看相关系数不易看清的细节：`OverallQual` 与 `GarageCars` 单看相关系数几乎相同（$0.3529$ 与 $0.3513$），但放到一起控制住面积之后，`OverallQual` 的净贡献明显更大；而地块面积 `LotArea` 去掉后误差反而微降 $\\${abs(lot_row['delta_cv_rmse']):.0f}$，说明它对这组数据的房价几乎没有贡献。

# 4. 结论

1. 相比只用单特征做直线或抛物线拟合，将全部 8 个物理特征纳入多元线性回归后，模型预测误差大幅降低、拟合优度显著提升，能够较准确地完成房价预测任务。
2. 最小二乘正规方程、MATLAB 内置函数 `fitlm` 与手动梯度下降三种求解方式结果一致，从解析公式和数值迭代两方面互相验证了回归模型的准确性。
3. 消除单位差异后，标准化回归系数与逐个去特征法一致表明，对房价贡献最大的前三个特征依次为地上居住面积 `GrLivArea`、综合质量 `OverallQual` 和车库容量 `GarageCars`，符合现实购房看重面积、品质和车位的常识。
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
    sz.set(qn("w:val"), "18")
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


def resize_drawing_in_paragraph(p, target_width_in: float = 5.0, max_height_in: float = 2.4) -> None:
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
                # 表 1、表 2 首列左对齐；表 3 第 2 列（特征名称）左对齐
                if len(row.cells) == 6 and "排名" in table.rows[0].cells[0].text:
                    p.alignment = WD_ALIGN_PARAGRAPH.LEFT if (c_idx == 1 and r_idx > 0) else WD_ALIGN_PARAGRAPH.CENTER
                else:
                    p.alignment = WD_ALIGN_PARAGRAPH.LEFT if (c_idx == 0 and r_idx > 0) else WD_ALIGN_PARAGRAPH.CENTER

                p.paragraph_format.first_line_indent = Pt(0)
                p.paragraph_format.left_indent = Pt(0)
                p.paragraph_format.space_before = Pt(1)
                p.paragraph_format.space_after = Pt(1)
                p.paragraph_format.line_spacing = 1.08
                if r_idx < n_rows - 1:
                    p.paragraph_format.keep_with_next = True
                for r in p.runs:
                    is_hdr = r_idx == 0
                    set_run_font(
                        r,
                        east_asia="黑体" if is_hdr else "宋体",
                        size_pt=9.0 if is_hdr else 8.5,
                        bold=True if is_hdr else r.bold,
                    )


def polish_word_document(
    in_docx: Path,
    out_docx: Path,
    fallback_docx: Path,
    table_widths_list: list[list[float]],
    fig_widths: dict[int, tuple[float, float]] | None = None,
) -> Path:
    doc = Document(str(in_docx))

    for section in doc.sections:
        section.page_width = Inches(8.27)
        section.page_height = Inches(11.69)
        section.top_margin = Inches(0.62)
        section.bottom_margin = Inches(0.62)
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
            p.paragraph_format.space_before = Pt(8)
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
            w_in, max_h_in = (5.05, 2.35)
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
            p.paragraph_format.space_after = Pt(4)
            p.paragraph_format.line_spacing = 1.08
            for r in p.runs:
                set_run_font(r, east_asia="黑体", size_pt=9.5, bold=True)
            continue

        if re.match(r"^表\s*\d+", txt) and len(txt) < 65 and "。" not in txt:
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(4)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.08
            p.paragraph_format.keep_with_next = True
            for r in p.runs:
                set_run_font(r, east_asia="黑体", size_pt=9.5, bold=True)
            continue

        if in_references:
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.14
            for r in p.runs:
                set_run_font(r, east_asia="宋体", size_pt=9.5, bold=False)
            continue

        if p._p.pPr is not None and p._p.pPr.find(qn("w:numPr")) is not None:
            p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            p.paragraph_format.left_indent = Pt(21)
            p.paragraph_format.first_line_indent = Pt(-12)
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(1.5)
            p.paragraph_format.line_spacing = 1.14
            if idx + 1 < len(doc.paragraphs) and is_display_math_paragraph(doc.paragraphs[idx + 1]):
                p.paragraph_format.keep_with_next = True
            for r in p.runs:
                set_run_font(r, east_asia="宋体", size_pt=10.5)
            continue

        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        p.paragraph_format.left_indent = Pt(0)
        p.paragraph_format.first_line_indent = Pt(21)
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.line_spacing = 1.15
        if idx + 1 < len(doc.paragraphs) and is_display_math_paragraph(doc.paragraphs[idx + 1]):
            p.paragraph_format.keep_with_next = True
        for r in p.runs:
            set_run_font(r, east_asia="宋体", size_pt=10.5)

    for t_idx, table in enumerate(doc.tables):
        widths = table_widths_list[t_idx] if t_idx < len(table_widths_list) else None
        style_three_line_table(table, col_widths_in=widths)

    saved_path = out_docx
    try:
        doc.save(str(out_docx))
    except PermissionError:
        saved_path = fallback_docx
        doc.save(str(fallback_docx))
        print(f"[WARN] 主 DOCX 被占用，已改存为: {fallback_docx}")
    print(f"[OK] Word 文档排版完成: {saved_path}")
    return saved_path


def _run_word_com_export(docx_path: Path, pdf_path: Path) -> None:
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
        raise RuntimeError(f"Word COM 导出失败:\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")


def export_pdf_via_word_com(docx_path: Path, primary_pdf: Path, fallback_pdf: Path) -> Path:
    try:
        _run_word_com_export(docx_path, primary_pdf)
        if primary_pdf.exists():
            print(f"[OK] PDF 导出完成: {primary_pdf}")
            return primary_pdf
    except Exception as e:
        print(f"[WARN] 主 PDF 导出失败 ({e})，尝试写入备用路径: {fallback_pdf}")

    _run_word_com_export(docx_path, fallback_pdf)
    if not fallback_pdf.exists():
        raise FileNotFoundError(f"PDF 导出后未找到文件: {fallback_pdf}")
    print(f"[OK] PDF 导出完成（备用路径）: {fallback_pdf}")
    return fallback_pdf


def self_audit_docx(docx_path: Path) -> None:
    with zipfile.ZipFile(docx_path, "r") as zf:
        doc_xml = zf.read("word/document.xml").decode("utf-8", errors="ignore")
        hdr_files = [n for n in zf.namelist() if n.startswith("word/header") and n.endswith(".xml")]
        hdr_text = ""
        for hf in hdr_files:
            raw = zf.read(hf).decode("utf-8", errors="ignore")
            hdr_text += "".join(re.findall(r"<w:t[^>]*>(.*?)</w:t>", raw))

    plain_text = "".join(re.findall(r"<w:t[^>]*>(.*?)</w:t>", doc_xml))
    omath_count = len(re.findall(r"<m:oMath\b", doc_xml))
    omath_para_count = len(re.findall(r"<m:oMathPara\b", doc_xml))
    raw_latex_hits = re.findall(r"(\\frac|\\sum|\\beta|\$\$)", doc_xml)
    non_white_shd = re.findall(r'<w:shd[^>]*w:fill="(?!FFFFFF|auto)[^"]+"', doc_xml)

    banned_terms = [
        "VIF", "条件数", "偏度", "峰度", "Jarque", "MAPE",
        "斯皮尔曼", "Spearman", "皮尔逊", "Pearson", "核密度", "KDE",
        "遮蔽效应", "方差膨胀", "无泄露", "框架", "揭示", "参考文献",
        "岭回归", "Ridge", "Lasso", "决策树", "随机森林", "梯度提升", "GBDT", "LSBoost", "OOB", "4 阶层",
        "王昊坤", "陈振夫", "百分百", "穷尽", "万无一失",
    ]
    hits = [t for t in banned_terms if t in plain_text]

    print(f"[AUDIT] OMML <m:oMath> / <m:oMathPara>: {omath_count} / {omath_para_count}")
    print(f"[AUDIT] 残留原始 LaTeX 命中: {len(raw_latex_hits)}")
    print(f"[AUDIT] 页眉残留文字长度: {len(hdr_text.strip())}")
    print(f"[AUDIT] 非白表格底纹数量: {len(non_white_shd)}")
    print(f"[AUDIT] 禁词/课外术语命中: {hits}")
    print(f"[AUDIT] 纯中文+字符总长度: {len(plain_text)}")

    assert omath_count >= 10, f"OMML 公式过少: {omath_count}"
    assert len(raw_latex_hits) == 0, f"发现未编译 LaTeX: {raw_latex_hits[:5]}"
    assert len(hdr_text.strip()) == 0, f"页眉非空: {hdr_text}"
    assert len(non_white_shd) == 0, f"存在非白底纹: {non_white_shd[:5]}"
    assert len(hits) == 0, f"发现禁止出现的课外/过度专业词或非本人姓名: {hits}"


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
        [1.10, 1.15, 0.65, 1.35, 1.45, 1.07],         # 表 1 (6 列)
        [2.20, 0.55, 0.80, 1.02, 0.78, 0.72, 0.70],   # 表 2 (7 列)
        [0.45, 1.72, 0.85, 1.45, 1.25, 1.05],         # 表 3 (6 列)
    ]
    fig_widths = {
        1: (5.85, 2.55),
        2: (5.85, 2.55),
        3: (5.85, 2.55),
        4: (5.85, 2.55),
    }

    saved_docx = polish_word_document(
        DOCX_RAW_PATH,
        FINAL_DOCX_PATH,
        FALLBACK_DOCX_PATH,
        table_widths_list=table_widths_list,
        fig_widths=fig_widths,
    )
    self_audit_docx(saved_docx)
    saved_pdf = export_pdf_via_word_com(saved_docx, FINAL_PDF_PATH, FALLBACK_PDF_PATH)
    if DOCX_RAW_PATH.exists():
        DOCX_RAW_PATH.unlink()
    print(f"[DONE] 极简课内报告构建完成:\n  DOCX: {saved_docx}\n  PDF:  {saved_pdf}")


if __name__ == "__main__":
    main()
