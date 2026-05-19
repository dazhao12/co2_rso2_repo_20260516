# 版本变更日志 (CHANGELOG)

---

## [sens/sample-size-n-sweep-modelb] - 2026-05-19

### v1.2 - 优化 PPT 报告布局与局部图例排版，移除大标题
* **图表样式升级**：
  * **图例重构**：将曲线重叠对比图的全局横排图例移除，改为在 3 个通道子面板内部的左上角各自展示一个紧凑的**垂直排列图例**。有效解决图例与 X 轴标签挤在一起的问题，且不遮挡主曲线。
  * **大标题清理**：移除了图片内置的全局大标题（`suptitle` 与 `title`），保证绘图输出仅包含科学图表本体，避免在 PPT 报告或论文中重复。
* **PPT 幻灯片排版改良**：
  * **页面比例**：将 PPT 幻灯片调整为 `16:9` 宽屏规格（13.33 x 7.5 英寸），重新计算并水平居中对齐图片。
  * **表格重构**：将 Slide 3 的硬编码文本表格升级为 PowerPoint 原生的**高拟合度矢量表格**，并支持自动映射通道的正式出版名称与数值格式化（加千分位）。

### v1.1 - 样本量敏感性扫描与绘图风格对齐
* **重构路径与脚本**：
  * 重构了 `submit_intraop3var_overall_modelB_n_sweep_boot50_single.sbatch`，移除外部路径硬编码，直接链接仓库内的 `contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py` 与 R 绘图脚本。
  * 重构了 `submit_intraop3var_overall_modelB_n_sweep_boot50_missing.sh`，将其运行日志及输出结果指向仓库内的相对路径，增强了作业完整性检查。
  * 升级了 `summarize_modelB_n_sweep_etco2.py`，支持基于 `python-pptx` 自动排版并生成总结 PPT 报告。
* **绘图风格对齐 (全面对齐亚组一致性图规范)**：
  * **通道命名**：将 `rSO2_Ch1` 改为 `"Left SctO₂ (%)"`，`rSO2_Ch2` 改为 `"Right SctO₂ (%)"`，`rSO2_Ch3` 改为 `"SftO₂ (%)"`。
  * **配色系统**：修改为亚组专属配色：Ch1 用蓝色 (`#1f77b4`)，Ch2 用绿色 (`#2ca02c`)，Ch3 用红色 (`#d62728`)。
  * **视觉布局**：移除了 Matplotlib 的 Top/Right 边框，轴线与刻度统一使用 `#616161` 颜色，增加了千分位标注及 N=10,000 的基准虚线，整体风格对齐 ggplot 经典质感。

---

## [sens/lag-etco2] - 2026-05-19

### v1.1 - 滞后效应分析脚本重构与任务提交
* **通用运行与调度框架**：
  * 创建了通用的平移运行管道 `run_lag_single.py`，动态获取 `REPO_ROOT`，支持从环境变量自动判定并加载 `modelA` 或 `modelB`。
  * 编写了通用的 `submit_one_lag.sbatch` 与参数扫描 CLI `submit_lag_sweep.sh`，支持一键 Sweep 多个时延及多重自助抽样设置。
  * 升级了 `summarize_lag_effects.py`，集成了 `python-pptx` 以在汇总绘图时自动拼装幻灯片。
* **数据平移逻辑**：
  * 确立了在降采样（未过滤缺失值且等时间间隔 1s）的患者分组数据上进行平移（`groupby().shift()`）的时序对齐规范，保证时序连续性与物理对齐的严谨。
