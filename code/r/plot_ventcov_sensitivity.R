#!/usr/bin/env Rscript
# ==============================================================================
# R 绘图脚本: 通气协变量敏感性分析森林图 (5个模型对比)
# 输出: PDF, PNG, 以及可直接导入 PPT 编辑的 PPTX 矢量文件
# ==============================================================================

# 安装/加载必要包
libs <- c("ggplot2", "dplyr", "officer", "rvg", "showtext")
for (lib in libs) {
  if (!require(lib, character.only = TRUE, quietly = TRUE)) {
    install.packages(lib, repos = "https://cloud.r-project.org")
    library(lib, character.only = TRUE)
  }
}

# 启用系统字体支持 (Aptos/Inter/Roboto)
font_add_google("Roboto", "roboto")
showtext_auto()

# 1. 路径设置
base_dir <- "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/analysis_bundle"
csv_path <- file.path(base_dir, "output/tables/etco2_sensitivity_5model_summary.csv")
out_dir  <- file.path(base_dir, "output/figures")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(csv_path)) {
  stop(paste("找不到汇总 CSV 文件，请确认路径:", csv_path))
}

# 2. 读取并清洗数据
df <- read.csv(csv_path, stringsAsFactors = FALSE) %>%
  filter(status == "ok")

# 映射通道名称 (符合期刊规范)
channel_map <- c(
  "rSO2_Ch1" = "Left SctO2 (%)",
  "rSO2_Ch2" = "Right SctO2 (%)",
  "rSO2_Ch3" = "SftO2 (%)"
)
df$channel_label <- factor(channel_map[df$ycol], levels = c("Left SctO2 (%)", "Right SctO2 (%)", "SftO2 (%)"))

# 映射模型名称 (中文或英文，英文更符合学术规范)
model_map <- c(
  "base"         = "Model B (Base, No Vent Covars)",
  "rrtotal_only" = "+ Respiratory Rate Only",
  "tvinsp_only"  = "+ Tidal Volume Only",
  "pmean_only"   = "+ Mean Airway Pressure Only",
  "all_three"    = "+ All Three (RR, TV, Pmean)"
)
df$model_label <- factor(model_map[df$run_key], levels = rev(c(
  "Model B (Base, No Vent Covars)",
  "+ Respiratory Rate Only",
  "+ Tidal Volume Only",
  "+ Mean Airway Pressure Only",
  "+ All Three (RR, TV, Pmean)"
)))

# 3. ggplot2 森林图绘制
p <- ggplot(df, aes(x = delta_rso2_plus5, y = model_label, color = channel_label)) +
  # 参考虚线：X=0 代表无效应
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray60", linewidth = 0.5) +
  # 误差条 (置信区间)
  geom_errorbar(aes(xmin = delta_ci_lo, xmax = delta_ci_hi), width = 0.25, linewidth = 0.8) +
  # 均值点
  geom_point(size = 3.5, shape = 16) +
  # 分面板展示通道
  facet_wrap(~channel_label, scales = "free_x") +
  # 专业配色 (使用 HSL 和谐色系)
  scale_color_manual(values = c("Left SctO2 (%)" = "#2A6F97", "Right SctO2 (%)" = "#014F86", "SftO2 (%)" = "#5C677D")) +
  # 图表标签
  labs(
    x = "rSO2 Change (%) per 5 mmHg Increase in ETCO2",
    y = NULL,
    title = "Ventilation Covariates Sensitivity Analysis (Model B)",
    subtitle = "Comparing different respiratory adjustment strategies"
  ) +
  # 主题细化
  theme_bw(base_size = 13, base_family = "roboto") +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5, color = "#1E293B"),
    plot.subtitle = element_text(size = 11, hjust = 0.5, color = "#64748B", margin = margin(b = 15)),
    strip.background = element_rect(fill = "#F1F5F9", color = "gray80"),
    strip.text = element_text(face = "bold", color = "#1E293B", size = 11),
    axis.text.y = element_text(color = "#334155", size = 10, face = "bold"),
    axis.text.x = element_text(color = "#334155"),
    axis.title.x = element_text(margin = margin(t = 12), color = "#1E293B"),
    legend.position = "none",
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(color = "#F1F5F9"),
    panel.border = element_rect(color = "gray85")
  )

# 4. 导出静态图
pdf_path <- file.path(out_dir, "etco2_sensitivity_5model_forest.pdf")
png_path <- file.path(out_dir, "etco2_sensitivity_5model_forest.png")

ggsave(pdf_path, plot = p, width = 9.5, height = 4.5, device = "pdf")
ggsave(png_path, plot = p, width = 9.5, height = 4.5, dpi = 300)
message("Saved PDF to: ", pdf_path)
message("Saved PNG to: ", png_path)

# 5. 导出可编辑 PPTX
pptx_path <- file.path(out_dir, "etco2_sensitivity_5model_forest.pptx")
editable_dml <- rvg::dml(ggobj = p)

doc <- read_pptx() %>%
  add_slide(layout = "Blank", master = "Office Theme") %>%
  ph_with(value = editable_dml, location = ph_location(
    left = 0.5, top = 0.5, width = 9.0, height = 5.0
  ))

print(doc, target = pptx_path)
message("Saved editable PPTX to: ", pptx_path)
