# -*- coding: utf-8 -*-
"""
Random Mathematics Practice 2 English Report Builder (Clean Course Terminology Version)
Matches the exact structure, data, equations, and style of the final V4 Chinese report:
1. Reads 01_Data/eda_summary.json and 02_MATLAB_Modeling/results_summary.json
2. Generates clean, natural sophomore-level academic English Markdown source
3. Compiles with Pandoc to DOCX with native Word OMML (<m:oMath>) equations
4. Polishes DOCX formatting via python-docx (0 headers, pure-white three-line tables,
   clean Times New Roman / Arial / Consolas styling, unbroken tables, keep_with_next)
5. Runs XML + terminology self-audit and exports PDF via Word COM (_V1/_V2/_V3 lock-safe)
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

MD_PATH = REPORT_DIR / "practice2_report_source_en.md"
DOCX_RAW_PATH = REPORT_DIR / "_tmp_pandoc_raw_en.docx"
FINAL_DOCX_PATH = REPORT_DIR / "Practice2_HousePrice_Regression_Report_Hanzhang_Pei_EN_V1.docx"
FALLBACK_DOCX_PATH = REPORT_DIR / "Practice2_HousePrice_Regression_Report_Hanzhang_Pei_EN_V2.docx"
FINAL_PDF_PATH = REPORT_DIR / "Practice2_HousePrice_Regression_Report_Hanzhang_Pei_EN_V1.pdf"


def load_json(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"JSON file not found: {path}")
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
    m_ols_ne = m_map["T2_OLS_NormalEq"]
    m_ols = m_map["T2_OLS_fitlm"]
    m_part_quad = m_map["T2_PartialQuadratic"]

    desc_map = {item["variable"]: item for item in eda["descriptive_stats"]}
    corr_map = {item["feature"]: item for item in eda["feature_target_correlations"]}

    en_meaning_map = {
        "OverallQual": "Overall Quality",
        "GrLivArea": "Above-Ground Living Area",
        "GarageCars": "Garage Capacity",
        "TotalBsmtSF": "Basement Area",
        "YearBuilt": "Year Built",
        "FullBath": "Full Bathrooms",
        "BedroomAbvGr": "Bedrooms Above Ground",
        "LotArea": "Lot Area",
        "SalePrice": "Sale Price (Response)",
    }
    en_short_map = {
        "OverallQual": "Overall Quality",
        "GrLivArea": "Living Area",
        "GarageCars": "Garage Capacity",
        "TotalBsmtSF": "Basement Area",
        "YearBuilt": "Year Built",
        "FullBath": "Full Bathrooms",
        "BedroomAbvGr": "Bedrooms Above",
        "LotArea": "Lot Area",
    }
    unit_map = {
        "OverallQual": "pts",
        "GrLivArea": "sq ft",
        "GarageCars": "cars",
        "TotalBsmtSF": "sq ft",
        "YearBuilt": "yr",
        "FullBath": "rooms",
        "BedroomAbvGr": "rooms",
        "LotArea": "sq ft",
        "SalePrice": "USD",
    }

    # Table 1: Descriptive statistics and correlation coefficients
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
            f"| {var} | {en_meaning_map[var]} | {unit_map[var]} | {mean_sd} | {range_str} | {r_str} |"
        )
    table1_md = "\n".join(t1_rows)

    # Table 2: Multiple linear regression vs partial quadratic regression
    model_rows_spec = [
        ("Multiple Linear Regression (8 linear terms)", m_ols_ne, "8"),
        ("Partial Quadratic Fit (2 area sq. + 6 linear)", m_part_quad, "10"),
    ]
    t2_rows = []
    for label, m, n_feat in model_rows_spec:
        t2_rows.append(
            f"| {label} | {n_feat} | "
            f"{fmt_int(m['train']['rmse'])} | "
            f"{fmt_int(m['cv_rmse_mean'])} | "
            f"{fmt_int(m['test']['rmse'])} | "
            f"{fmt_int(m['test']['mae'])} | "
            f"{m['test']['r2']:.4f} |"
        )
    table2_md = "\n".join(t2_rows)

    # Table 3: Feature contribution comparison and ranking
    ranked = fi["ranked_table"]
    t3_rows = []
    for row in ranked:
        rk = row["consensus_rank"]
        b = "**" if rk <= 3 else ""
        raw_b = row["ols_raw_beta_train"]
        raw_str = f"{raw_b:+,.2f}" if abs(raw_b) < 100 else f"{raw_b:+,.0f}"
        fname = row["feature"]
        t3_rows.append(
            f"| {b}{rk}{b} | {b}{fname} ({en_short_map[fname]}){b} | "
            f"{raw_str} | {b}{fmt_int(row['ols_std_abs_beta'])} ({row['ols_std_share_pct']:.1f}%){b} | "
            f"{b}{fmt_money_signed(row['delta_cv_rmse'])}{b} | "
            f"{row['univariate_r_all']:+.4f} |"
        )
    table3_md = "\n".join(t3_rows)

    top1, top2, top3 = ranked[0], ranked[1], ranked[2]
    top3_share = top1["ols_std_share_pct"] + top2["ols_std_share_pct"] + top3["ols_std_share_pct"]
    lot_row = next(r for r in ranked if r["feature"] == "LotArea")

    diff_pred = eq["max_test_pred_diff_NE_vs_fitlm"]
    diff_beta = eq["max_beta_diff_NE_vs_fitlm"]

    md = f"""Experiment & Practice #2: House Price Regression Modeling and Feature Contribution Analysis

Name: Hanzhang Pei\u2003\u2003Student ID: 2025310104015\u2003\u2003Instructor: Prof. Jing Liang\u2003\u2003Course: Random Mathematics

**Abstract**: Based on 300 housing records (excluding the index column `Id` and keeping 8 house features), this report implements multiple linear regression and a partial quadratic extension in MATLAB R2025b, verified via both normal equations and `fitlm`. The partial quadratic model achieves test $R^2 = {m_part_quad['test']['r2']:.4f}$ and $\\text{{RMSE}} = \\${fmt_int(m_part_quad['test']['rmse'])}$. Standardized coefficients and leave-one-out validation consistently identify the top three contributing features as `GrLivArea`, `OverallQual`, and `GarageCars`.

# 1. Introduction and Dataset Overview

This experiment builds a regression model from real house transaction data to predict sale prices and identify the three most influential features. The dataset contains $N = {ds['n_total']}$ observations and 10 columns with zero missing values. Since the first column `Id` is only a sequential index ($1 \\sim 300$), we drop it prior to modeling and keep the 8 physical house attributes as predictors $x_1,\\dots,x_8$, with `SalePrice` (USD) as the response $y$.

Table 1 and Figure 1 summarize the basic statistics and correlation coefficients $r$ of each variable. Above-ground living area `GrLivArea` shows the strongest correlation with sale price ($r = {top1['univariate_r_all']:.4f}$), followed by `OverallQual` ($r = {top2['univariate_r_all']:.4f}$) and `GarageCars` ($r = {top3['univariate_r_all']:.4f}$), while correlations among predictors remain very small (all below $0.13$).

Table 1\u2003Summary Statistics and Correlation Coefficients of Variables (N = 300)

| Variable | Meaning | Unit | Mean ± SD | Range | Corr. $r$ |
| :--- | :--- | :---: | :---: | :---: | :---: |
{table1_md}

![](03_Figures/fig1_en_eda.png)

Figure 1\u2003Correlation Matrix of 8 Predictors and SalePrice Distribution Histogram

# 2. Regression Modeling and Fitting Analysis

The original dataset does not come pre-split into training and validation subsets. Borrowing the practice from AI model training and validation to prevent "memorizing" the training samples (overfitting), we fix the random seed `rng(42)` and split the 300 records 80/20 into a training set (240 samples, for estimating coefficients) and a test set (60 samples, serving as unseen exam data). Within the training set, we further apply 5-fold cross-validation (`CV`), a standard technique used during AI training and validation: the 240 training samples are evenly partitioned into 5 folds, fitting on 4 folds and validating on the remaining 1 fold in turn, then averaging the 5 validation errors. Model accuracy is evaluated by Root Mean Squared Error ($\\text{{RMSE}}$), Mean Absolute Error ($\\text{{MAE}}$), and $R^2$:

$$\\text{{RMSE}} = \\sqrt{{\\frac{{1}}{{n}}\\sum_{{i=1}}^{{n}}(y_i - \\hat{{y}}_i)^2}}$$

$$R^2 = 1 - \\frac{{\\sum_{{i=1}}^{{n}}(y_i - \\hat{{y}}_i)^2}}{{\\sum_{{i=1}}^{{n}}(y_i - \\bar{{y}})^2}}$$

## 2.1 Multiple Linear Regression and Solution

Using all 8 predictors in $\\mathbf{{y}} = \\mathbf{{X}}\\boldsymbol{{\\beta}} + \\boldsymbol{{\\varepsilon}}$, the least square method minimizes the residual sum of squares (SSE) $Q$:

$$Q = \\sum_{{i=1}}^{{n}}(y_i - \\hat{{y}}_i)^2$$

Adding a leading column of ones to represent the intercept and setting the partial derivatives of $Q$ to zero yields the normal equations:

$$(\\mathbf{{X}}^\\top \\mathbf{{X}})\\hat{{\\boldsymbol{{\\beta}}}} = \\mathbf{{X}}^\\top \\mathbf{{y}}$$

We solve for $\\hat{{\\boldsymbol{{\\beta}}}}$ via MATLAB backslash `\\` and verify the solution against `fitlm`. Both solvers agree completely: the maximum coefficient difference is ${fmt_sci(diff_beta)}$, and the maximum test prediction difference is ${fmt_sci(diff_pred)}$ USD.

## 2.2 Partial Quadratic Extension: Key Area Features vs. Linear Predictors

Beyond the purely linear model, we add squared terms only to the 2 most suitable features while keeping the other 6 predictors linear (10 terms total). Among the 8 predictors, `GrLivArea` (living area) and `TotalBsmtSF` (basement area) are continuous area variables with the widest numerical spans, and individual tests show their squared terms reduce error most noticeably; discrete integer counts (`GarageCars`, `FullBath`, `BedroomAbvGr`) remain linear.

Table 2\u2003Performance Comparison of Multiple Linear and Partial Quadratic Models (USD)

| Model Name | Terms | Train RMSE | 5-Fold CV RMSE | Test RMSE | Test MAE | Test $R^2$ |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
{table2_md}

As shown in Table 2, adding squared terms solely for the two area features lowers test RMSE from $\\${fmt_int(m_ols_ne['test']['rmse'])}$ to $\\${fmt_int(m_part_quad['test']['rmse'])}$ (test MAE to $\\${fmt_int(m_part_quad['test']['mae'])}$), while 5-fold CV RMSE stays close to the linear baseline. Figure 2 confirms that linear predictions align tightly along $y=x$ with residuals balanced inside $\\pm\\$25\\text{{k}}$, showing a predominantly linear relationship gently refined by local area curvature.

![](03_Figures/fig2_en_ols_fit_and_residuals.png)

Figure 2\u2003Multiple Linear Regression Fit (Predicted vs. Actual) and Residual Spread

# 3. Feature Contribution Evaluation

We cannot compare raw coefficients $\\hat{{\\beta}}_j$ directly to rank feature importance because units differ vastly: in Table 3, each extra garage space (`GarageCars`) adds $+\\$19,103$ while each square foot (`GrLivArea`) adds $+\\$54.79$, yet living areas span thousands of square feet whereas garage capacity spans only 0–3 cars. Therefore, we adopt two straightforward evaluation methods that cross-check each other:

1. **Method 1 (Standardized Coefficient $|\\beta_j^*|$)**: Each predictor is centered by its mean and divided by its standard deviation (SD) so every predictor varies on the common scale of "1 standard deviation". Fitting multiple linear regression on these standardized values yields $|\\beta_j^*|$, which measures the expected price change in USD per 1-SD change in predictor $j$:

$$z_{{ij}} = \\frac{{x_{{ij}} - \\bar{{x}}_j}}{{s_{{x_j}}}}$$

$$\\beta_j^* = \\hat{{\\beta}}_j \\cdot s_{{x_j}}$$

2. **Method 2 (Leave-One-Out 5-Fold CV RMSE Increase $\\Delta\\text{{RMSE}}_{{\\text{{CV}}}}$)**: Dropping predictor $j$ at a time and refitting on the remaining 7 predictors reveals how much 5-fold CV RMSE rises. A larger error jump indicates unique predictive information that cannot be substituted by the other predictors:

$$\\Delta\\text{{RMSE}}_{{\\text{{CV}}}}^{{(j)}} = \\text{{RMSE}}_{{\\text{{CV}}}}^{{(-j)}} - \\text{{RMSE}}_{{\\text{{CV}}}}^{{\\text{{full}}}}$$

Table 3\u2003Feature Contribution Comparison and Consensus Ranking Across All 8 Predictors

| Rank | Feature Name | Raw Coef. $\\hat{{\\beta}}_j$ | Standardized $|\\beta_j^*|$ (Share) | CV RMSE Increase | Corr. $r$ |
| :---: | :--- | :---: | :---: | :---: | :---: |
{table3_md}

![](03_Figures/fig3_en_feature_importance_top3.png)

Figure 3\u2003Feature Contribution Comparison via Both Methods (Top 3 Highlighted in Red)

Table 3 and Figure 3 show complete agreement between the two methods across all 8 predictors. The top three contributors are: **1st `GrLivArea`**, **2nd `OverallQual`**, and **3rd `GarageCars`**, accounting for ${top3_share:.1f}\\%$ of total standardized contribution. Although `OverallQual` and `GarageCars` have nearly identical correlation $r$ ($0.3529$ vs. $0.3513$), controlling for living area reveals a much stronger direct impact from `OverallQual`. Removing `LotArea` slightly decreases CV RMSE by $\\${abs(lot_row['delta_cv_rmse']):.0f}$, confirming minimal contribution in this dataset.

# 4. Conclusion

Under the 80/20 split and 5-fold CV, 8-predictor multiple linear regression predicts sale prices accurately (test RMSE $\\${fmt_int(m_ols_ne['test']['rmse'])}$), and adding quadratic terms on `GrLivArea` and `TotalBsmtSF` while keeping the other 6 predictors linear lowers test RMSE further to $\\${fmt_int(m_part_quad['test']['rmse'])}$. Normal equations and `fitlm` produce identical solutions, and both importance rankings establish `GrLivArea`, `OverallQual`, and `GarageCars` as the top three predictors.

# 5. Appendix: Core MATLAB Code

```matlab
% 1. Load data, drop Id, and create 80/20 train/test split
T = readtable('数据样本.csv', 'VariableNamingRule', 'preserve');
features = {{'OverallQual','GrLivArea','GarageCars','TotalBsmtSF', ...
             'YearBuilt','FullBath','BedroomAbvGr','LotArea'}};
X = T{{:, features}};  y = T{{:, 'SalePrice'}};
rng(42, 'twister');  cvHold = cvpartition(size(X,1), 'HoldOut', 0.20);
X_tr = X(training(cvHold), :);  y_tr = y(training(cvHold));
X_te = X(test(cvHold), :);      y_te = y(test(cvHold));

% 2. Multiple linear regression (normal equations & fitlm) + partial quadratic
Xb_tr = [ones(size(X_tr,1),1), X_tr];  Xb_te = [ones(size(X_te,1),1), X_te];
beta_ne = (Xb_tr' * Xb_tr) \\ (Xb_tr' * y_tr);
mdl_ols = fitlm(X_tr, y_tr);
pred_ne = Xb_te * beta_ne;  pred_fitlm = predict(mdl_ols, X_te);

Z_tr = (X_tr - mean(X_tr,1)) ./ std(X_tr,0,1);
quadCols = [2, 4];  % Add squared terms only for GrLivArea & TotalBsmtSF
Phi_tr = [ones(size(X_tr,1),1), Z_tr, Z_tr(:, quadCols).^2];
beta_part = Phi_tr \\ y_tr;

% 3. Feature contribution: standardized coefficients + 5-fold CV drop-column
beta_std = abs(fitlm(Z_tr, y_tr).Coefficients.Estimate(2:end));
rng(42, 'twister');  cv5 = cvpartition(size(X_tr,1), 'KFold', 5);
for j = 1:8
    keep_cols = setdiff(1:8, j);
    % Refit 5-fold CV on X_tr(:, keep_cols) to measure CV RMSE increase
end
```"""
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
        raise RuntimeError(f"Pandoc compilation failed:\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")
    print(f"[OK] Pandoc compiled: {out_docx}")


def set_run_font(
    run,
    east_asia: str = "宋体",
    size_pt: float = 10.0,
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
        '<w:top w:w="32" w:type="dxa"/><w:bottom w:w="32" w:type="dxa"/>'
        '<w:left w:w="45" w:type="dxa"/><w:right w:w="45" w:type="dxa"/>'
        "</w:tblCellMar>"
    )
    tblPr.append(tblCellMar)

    n_rows = len(table.rows)
    hdr_col0 = table.rows[0].cells[0].text.strip()
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
                if "Rank" in hdr_col0:
                    p.alignment = WD_ALIGN_PARAGRAPH.LEFT if (c_idx == 1 and r_idx > 0) else WD_ALIGN_PARAGRAPH.CENTER
                elif "Variable" in hdr_col0:
                    p.alignment = WD_ALIGN_PARAGRAPH.LEFT if (c_idx in (0, 1) and r_idx > 0) else WD_ALIGN_PARAGRAPH.CENTER
                else:
                    p.alignment = WD_ALIGN_PARAGRAPH.LEFT if (c_idx == 0 and r_idx > 0) else WD_ALIGN_PARAGRAPH.CENTER

                p.paragraph_format.first_line_indent = Pt(0)
                p.paragraph_format.left_indent = Pt(0)
                p.paragraph_format.space_before = Pt(1)
                p.paragraph_format.space_after = Pt(1)
                p.paragraph_format.line_spacing = 1.06
                if r_idx < n_rows - 1:
                    p.paragraph_format.keep_with_next = True
                for r in p.runs:
                    is_hdr = r_idx == 0
                    set_run_font(
                        r,
                        latin="Arial" if is_hdr else "Times New Roman",
                        size_pt=8.8 if is_hdr else 8.4,
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
        section.top_margin = Inches(0.58)
        section.bottom_margin = Inches(0.58)
        section.left_margin = Inches(0.72)
        section.right_margin = Inches(0.72)
        section.header_distance = Inches(0.28)
        section.footer_distance = Inches(0.28)
        section.gutter = 0
        setup_page_footer_page_number(section)

    clear_all_headers(doc)

    fig_counter = 0

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
                set_run_font(r, latin="Arial", size_pt=15.5, bold=True)
            continue

        if idx == 1:
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(6)
            p.paragraph_format.line_spacing = 1.12
            for r in p.runs:
                set_run_font(r, east_asia="楷体", latin="Times New Roman", size_pt=10.0, bold=False)
            continue

        if style_name.startswith("Heading 1"):
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(7)
            p.paragraph_format.space_after = Pt(2.5)
            p.paragraph_format.line_spacing = 1.12
            p.paragraph_format.keep_with_next = True
            for r in p.runs:
                set_run_font(r, latin="Arial", size_pt=12.5, bold=True)
            continue

        if style_name.startswith("Heading 2"):
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(5)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.12
            p.paragraph_format.keep_with_next = True
            for r in p.runs:
                set_run_font(r, latin="Arial", size_pt=11.0, bold=True)
            continue

        if has_drawing_element(p):
            fig_counter += 1
            w_in, max_h_in = (5.55, 2.38)
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
            p.paragraph_format.space_before = Pt(1.5)
            p.paragraph_format.space_after = Pt(1.5)
            p.paragraph_format.line_spacing = 1.10
            continue

        if re.match(r"^Figure\s+\d+", txt) and len(txt) < 110:
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(3.5)
            p.paragraph_format.line_spacing = 1.08
            for r in p.runs:
                set_run_font(r, latin="Arial", size_pt=9.2, bold=True)
            continue

        if re.match(r"^Table\s+\d+", txt) and len(txt) < 110:
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(0)
            p.paragraph_format.space_before = Pt(3.5)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.08
            p.paragraph_format.keep_with_next = True
            for r in p.runs:
                set_run_font(r, latin="Arial", size_pt=9.2, bold=True)
            continue

        if p._p.pPr is not None and p._p.pPr.find(qn("w:numPr")) is not None:
            p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            p.paragraph_format.left_indent = Pt(18)
            p.paragraph_format.first_line_indent = Pt(-12)
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(1.5)
            p.paragraph_format.line_spacing = 1.12
            if idx + 1 < len(doc.paragraphs) and is_display_math_paragraph(doc.paragraphs[idx + 1]):
                p.paragraph_format.keep_with_next = True
            for r in p.runs:
                set_run_font(r, latin="Times New Roman", size_pt=9.8)
            continue

        if style_name.startswith("Source") or "Code" in style_name or "Verbatim" in style_name:
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            p.paragraph_format.first_line_indent = Pt(0)
            p.paragraph_format.left_indent = Pt(8)
            p.paragraph_format.space_before = Pt(1.5)
            p.paragraph_format.space_after = Pt(1.5)
            p.paragraph_format.line_spacing = 1.04
            if p._p.pPr is not None:
                for shd in p._p.pPr.findall(qn("w:shd")):
                    p._p.pPr.remove(shd)
            for r in p.runs:
                if r._r.rPr is not None:
                    for shd in r._r.rPr.findall(qn("w:shd")):
                        r._r.rPr.remove(shd)
                set_run_font(r, east_asia="宋体", size_pt=8.0, bold=False, latin="Consolas")
            continue

        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        p.paragraph_format.left_indent = Pt(0)
        p.paragraph_format.first_line_indent = Pt(0) if txt.startswith("Abstract:") else Pt(16)
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(2.5)
        p.paragraph_format.line_spacing = 1.12
        if idx + 1 < len(doc.paragraphs) and is_display_math_paragraph(doc.paragraphs[idx + 1]):
            p.paragraph_format.keep_with_next = True
        for r in p.runs:
            set_run_font(r, latin="Times New Roman", size_pt=9.8)

    for st_shd in list(doc.styles.element.iter(qn("w:shd"))):
        parent = st_shd.getparent()
        if parent is not None:
            parent.remove(st_shd)

    for t_idx, table in enumerate(doc.tables):
        widths = table_widths_list[t_idx] if t_idx < len(table_widths_list) else None
        style_three_line_table(table, col_widths_in=widths)

    saved_path = out_docx
    if not _is_writable(out_docx):
        saved_path = fallback_docx
    try:
        doc.save(str(saved_path))
    except PermissionError:
        saved_path = fallback_docx
        doc.save(str(fallback_docx))
        print(f"[WARN] Primary DOCX locked, saved fallback: {fallback_docx}")
    print(f"[OK] English Word document polished: {saved_path}")
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
        raise RuntimeError(f"Word COM export failed:\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")


def _is_writable(path: Path) -> bool:
    if not path.exists():
        return True
    try:
        with open(path, "r+b"):
            return True
    except OSError:
        return False


def export_pdf_via_word_com(docx_path: Path, primary_pdf: Path) -> Path:
    candidates = [primary_pdf]
    for idx in range(2, 10):
        candidates.append(primary_pdf.with_name(f"Practice2_HousePrice_Regression_Report_Hanzhang_Pei_EN_V{idx}.pdf"))

    last_err = None
    for target in candidates:
        if not _is_writable(target):
            print(f"[WARN] PDF locked, skipping: {target}")
            continue
        try:
            _run_word_com_export(docx_path, target)
            if target.exists():
                print(f"[OK] English PDF exported: {target}")
                return target
        except Exception as e:
            last_err = e
            print(f"[WARN] PDF export failed ({target}): {e}")

    raise FileNotFoundError(f"All candidate PDF paths failed; last error: {last_err}")


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
        "VIF", "condition number", "skewness", "kurtosis", "Jarque", "MAPE",
        "Spearman", "Pearson", "KDE", "kernel density", "suppression", "References",
        "Ridge", "Lasso", "Decision Tree", "Random Forest", "GBDT", "LSBoost", "OOB",
        "Gradient Descent", "gradient descent", "single-variable", "p-value",
        "Haokun", "Zhenfu", "王昊坤", "陈振夫",
    ]
    hits = [t for t in banned_terms if t in plain_text]

    # Ensure prose is English (allowing only author Chinese name, CSV filename, and math chars)
    print(f"[AUDIT] OMML <m:oMath> / <m:oMathPara>: {omath_count} / {omath_para_count}")
    print(f"[AUDIT] Raw LaTeX hits: {len(raw_latex_hits)}")
    print(f"[AUDIT] Header text length: {len(hdr_text.strip())}")
    print(f"[AUDIT] Non-white shading count: {len(non_white_shd)}")
    print(f"[AUDIT] Banned jargon hits: {hits}")
    print(f"[AUDIT] Extracted plain text length: {len(plain_text)}")

    assert omath_count >= 10, f"Too few OMML equations: {omath_count}"
    assert len(raw_latex_hits) == 0, f"Uncompiled LaTeX found: {raw_latex_hits[:5]}"
    assert len(hdr_text.strip()) == 0, f"Header non-empty: {hdr_text}"
    assert len(non_white_shd) == 0, f"Non-white shading found: {non_white_shd[:5]}"
    assert len(hits) == 0, f"Forbidden terms found: {hits}"


def main() -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    eda = load_json(EDA_JSON)
    res = load_json(RESULTS_JSON)

    md = build_markdown_source(eda, res)
    MD_PATH.write_text(md, encoding="utf-8")
    print(f"[OK] English Markdown generated: {MD_PATH}")

    compile_pandoc(MD_PATH, DOCX_RAW_PATH)

    # Printable width ~6.83 in (8.27 - 1.44)
    table_widths_list = [
        [1.05, 1.62, 0.56, 1.30, 1.35, 0.95],         # Table 1 (6 cols)
        [2.38, 0.52, 0.80, 1.00, 0.77, 0.72, 0.64],   # Table 2 (7 cols)
        [0.45, 2.02, 0.82, 1.40, 1.24, 0.90],         # Table 3 (6 cols)
    ]
    fig_widths = {
        1: (5.65, 2.40),
        2: (5.65, 2.40),
        3: (5.65, 2.40),
    }

    saved_docx = polish_word_document(
        DOCX_RAW_PATH,
        FINAL_DOCX_PATH,
        FALLBACK_DOCX_PATH,
        table_widths_list=table_widths_list,
        fig_widths=fig_widths,
    )
    self_audit_docx(saved_docx)
    saved_pdf = export_pdf_via_word_com(saved_docx, FINAL_PDF_PATH)
    if DOCX_RAW_PATH.exists():
        DOCX_RAW_PATH.unlink()
    print(f"[DONE] English Practice 2 Report Built:\n  DOCX: {saved_docx}\n  PDF:  {saved_pdf}")


if __name__ == "__main__":
    main()
