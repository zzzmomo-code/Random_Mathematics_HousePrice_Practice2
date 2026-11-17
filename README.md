# 《随机数学》Practice 2：基于多模型递进回归的房价预测与特征贡献度分析

> **学生**：裴翰章（学号：`2025310104015`）｜**指导教师**：梁菁 教授｜**工具环境**：MATLAB R2025b / Python 3.12 / Pandoc
> **GitHub 仓库**：<https://github.com/zzzmomo-code/Random_Mathematics_HousePrice_Practice2>

---

## 一、项目简介

本项目基于聚合数据平台的 300 条房屋销售价格样本（`数据样本.csv`），在剔除无物理意义的样本序号列 `Id` 后，利用 8 项房屋物理特征预测销售价格 `SalePrice`（美元）。项目采用固定随机种子 `rng(42)`、80%/20% 独立划分（240 训练 / 60 测试）与训练集内严格无泄露 5 折交叉验证，完成两项核心任务：

1. **由简到难的 4 阶层 10 类回归建模**：单变量一次直线/二次抛物线 → 多元线性回归 OLS（正规方程、手动批量梯度下降、`fitlm` 三求解器等价核验）与多元纯二次/全二次多项式 → 岭回归（L2）与 Lasso（L1）→ 决策树、随机森林与梯度提升树（GBDT）。
2. **四维互补特征贡献度评价与 Top 3 识别**：标准化回归系数 $|\beta_j^*|$、留一特征法 $\Delta\text{RMSE}_{\text{CV}}$（配单变量 $R^2$）、Lasso 正则化路径入模顺序与随机森林袋外（OOB）置换重要性。

---

## 二、核心实验结果一览

### 1. 模型性能对比（训练集 240 / 独立测试集 60）

| 模型名称（阶层） | 项数 | 5 折 CV RMSE ($) | 5 折 CV $R^2$ | 测试集 RMSE ($) | 测试集 MAE ($) | 测试集 $R^2$ |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| T1 一次线性 (`GrLivArea`) | 1 | 49,877 | 0.5370 | 52,260 | 39,572 | 0.4841 |
| T1 二次抛物线 (`GrLivArea`) | 2 | 49,929 | 0.5354 | 51,872 | 39,025 | 0.4917 |
| **T2 多元 OLS (NE / GD / `fitlm`)** | **8** | **11,712** | **0.9739** | **11,030** | **9,604** | **0.9770** |
| T2 多元纯二次 (Pure Quad) | 16 | 12,165 | 0.9717 | 11,095 | 9,622 | 0.9767 |
| T2 多元全二次 (Full Quad) | 44 | 12,325 | 0.9709 | 12,194 | 10,344 | 0.9719 |
| T3 岭回归 Ridge ($\lambda=0$) | 8 | 11,712 | 0.9739 | 11,030 | 9,604 | 0.9770 |
| T3 Lasso ($\lambda_{\min}=1.0$) | 8 | 11,712 | 0.9739 | 11,030 | 9,605 | 0.9770 |
| T4 决策树 (`fitrtree`) | 8 | 41,567 | 0.6658 | 43,011 | 36,322 | 0.6505 |
| T4 随机森林 (`TreeBagger`, 500 树) | 8 | 28,607 | 0.8453 | 28,917 | 23,024 | 0.8420 |
| T4 梯度提升树 (`LSBoost`) | 8 | 16,919 | 0.9446 | 15,806 | 12,439 | 0.9528 |

### 2. Top 3 核心贡献特征（4 种方法排序完全一致，Spearman $\rho = 1.000$）

1. **`GrLivArea`（地上居住面积）**：$|\beta^*|=\$57,453$（占 34.7%），$\Delta\text{RMSE}_{\text{CV}}=+\$48,882$，单变量 $R^2=0.5552$，RF 置换重要性 `5.692`
2. **`OverallQual`（综合质量）**：$|\beta^*|=\$34,087$（占 20.6%），$\Delta\text{RMSE}_{\text{CV}}=+\$26,231$，单变量 $R^2=0.1245$，RF 置换重要性 `3.106`
3. **`GarageCars`（车库容量）**：$|\beta^*|=\$21,319$（占 12.9%），$\Delta\text{RMSE}_{\text{CV}}=+\$13,357$，单变量 $R^2=0.1234$，RF 置换重要性 `1.374`

---

## 三、目录结构

```text
Random_Mathematics_Project_HousePrice/
├── 00_Raw_Archive/                         # 原始数据集压缩包
├── 01_Data/
│   ├── 聚合数据用于学习训练/                # 数据样本.csv、数据字典.csv、网站.txt
│   └── eda_summary.json                    # EDA 描述性统计与共线性诊断结果
├── 02_MATLAB_Modeling/
│   ├── main_house_price_modeling.m         # MATLAB R2025b 一键建模主脚本
│   ├── eval_metrics.m                      # 统一误差评价函数
│   ├── fit_ols_gd.m                        # 手动批量梯度下降求解器
│   ├── build_poly_features.m               # 多元纯二次/全二次特征构造
│   ├── generate_figures.m                  # 5 张 300-DPI 白底图表绘制脚本
│   └── results_summary.json                # 完整数值结果汇总
├── 03_Figures/                             # fig1 ~ fig5 高清白底 PNG 图表
├── 04_Report/
│   ├── build_practice2_report.py           # Pandoc OMML + python-docx 报告生成脚本
│   ├── Practice2_HousePrice_Regression_Report_裴翰章.docx
│   └── Practice2_HousePrice_Regression_Report_裴翰章.pdf
├── 00_【给MoMo看】房价回归实验通俗教学指南.md  # 通俗原理讲解与答辩问答手册
├── HANDOFF.md                              # 跨 AI 协作交接文档
├── AI_CHAT.md                              # 协作日志
└── README.md                               # 项目说明
```

---

## 四、一键复现方法

### 1. 运行 MATLAB 建模与出图（MATLAB R2025b）
```matlab
cd('E:\Random_Mathematics_Project_HousePrice\02_MATLAB_Modeling')
main_house_price_modeling
```

### 2. 重新编译正式 Word 与 PDF 报告（Windows PowerShell）
```powershell
& "C:\Users\48747\AppData\Local\Programs\Python\Python312\python.exe" -X utf8 "E:\Random_Mathematics_Project_HousePrice\04_Report\build_practice2_report.py"
```

---

## 五、数据来源

- 聚合数据房屋销售价格数据集：<https://www.juhe.cn/dataset/product/id/mva1wdNmuJB>
