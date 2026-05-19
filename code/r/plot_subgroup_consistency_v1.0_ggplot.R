#!/usr/bin/env Rscript
# =============================================================================
# v1.0 - 亚组一致性图（ggplot2 版，可输出 PPT 可编辑格式）
# 改动：
#   - 用 ggplot2 重写 Python plot_subgroup_consistency.py 的两张图
#   - 图A: 森林图（Forest Plot）── 各亚组 × 通道 的 ΔrSO2(+5) + 95%CI
#   - 图B: 方向热图（Direction Heatmap）── 正/不确定/负 三色
#   - 输出：PNG / PDF（300 dpi）+ 可编辑 PPTX（via officer + rvg）
# 输入：
#   code/analysis_bundle/output/tables/
#     subgroup_consistency_etco2_delta_plus5_modelB_n10000_b200.csv
# 输出：
#   code/analysis_bundle/output/figures/
#     subgroup_delta_forest_ggplot_modelB_n10000_b200.{png,pdf}
#     subgroup_direction_heatmap_ggplot_modelB_n10000_b200.{png,pdf}
#     subgroup_plots_modelB_n10000_b200.pptx
# 基于：plot_subgroup_consistency.py
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(officer)
  library(rvg)
})

# ── 路径设置 ────────────────────────────────────────────────────────────────
REPO <- "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516"
IN_FILE <- file.path(REPO,
  "code/analysis_bundle/output/tables",
  "subgroup_consistency_etco2_delta_plus5_modelB_n10000_b200.csv")
OUT_DIR <- file.path(REPO, "code/analysis_bundle/output/figures")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ── 读取数据 ────────────────────────────────────────────────────────────────
df_raw <- read.csv(IN_FILE, stringsAsFactors = FALSE)
df <- df_raw %>% filter(status == "ok")
stopifnot(nrow(df) > 0)

# 亚组显示标签
sg_levels <- c(
  "Age_less_70", "Age_more_70",
  "Female", "Male",
  "Pre_hypertension_less_140_90", "Pre_hypertension_more_140_90"
)
sg_labels <- c(
  "Age < 70 yr", "Age ≥ 70 yr",
  "Female", "Male",
  "No Hypertension", "Hypertension"
)
names(sg_labels) <- sg_levels

# 通道颜色 / 标签
ch_levels <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
ch_labels <- c("Ch1 (left frontal)", "Ch2 (right frontal)", "Ch3 (left somatic)")
names(ch_labels) <- ch_levels
ch_colors <- c(rSO2_Ch1 = "#1f77b4", rSO2_Ch2 = "#2ca02c", rSO2_Ch3 = "#d62728")

df <- df %>%
  mutate(
    subgroup_f = factor(subgroup, levels = rev(sg_levels),
                        labels = rev(sg_labels[sg_levels])),
    channel_f  = factor(channel, levels = ch_levels,
                        labels = ch_labels[ch_levels])
  )

# ── 偏移量（同一亚组内三条通道纵向错开，避免重叠）──────────────────────────
offsets <- c(rSO2_Ch1 = -0.22, rSO2_Ch2 = 0.0, rSO2_Ch3 = 0.22)
df$y_offset <- offsets[df$channel]
df$y_num <- as.numeric(df$subgroup_f) + df$y_offset

# =============================================================================
# 图A：Forest Plot
# =============================================================================
make_forest <- function(df) {
  ggplot(df, aes(x = delta_rso2_plus5, y = y_num, color = channel_f)) +

    # 95% CI 横线
    geom_errorbarh(
      aes(xmin = delta_ci_lo, xmax = delta_ci_hi),
      height = 0.12, linewidth = 0.7, alpha = 0.85
    ) +
    # 点估计
    geom_point(size = 2.8, shape = 16) +

    # 零线
    geom_vline(xintercept = 0, linetype = "dashed",
               color = "#444444", linewidth = 0.6, alpha = 0.9) +

    # 颜色
    scale_color_manual(
      values = ch_colors,
      labels = ch_labels[ch_levels],
      name   = "Channel"
    ) +

    # Y 轴：亚组标签
    scale_y_continuous(
      breaks = seq_along(rev(sg_levels)),
      labels = sg_labels[rev(sg_levels)],
      expand = expansion(add = 0.6)
    ) +

    labs(
      x     = expression(Delta*"rSO"[2]*" for +5 mmHg ET"[CO[2]]*" (%)"),
      y     = NULL,
      title = "Subgroup Consistency: ET-CO₂ Effect on rSO₂",
      subtitle = "Model B  ·  n = 10,000  ·  bootstrap = 200  ·  points = median ET-CO₂ → +5 mmHg"
    ) +

    theme_bw(base_size = 12) +
    theme(
      plot.title    = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(size = 9, color = "grey40"),
      legend.position = "right",
      legend.title  = element_text(face = "bold", size = 10),
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      axis.text.y   = element_text(size = 11)
    )
}

p_forest <- make_forest(df)

# =============================================================================
# 图B：Direction Heatmap
# =============================================================================
make_heatmap <- function(df) {
  df_heat <- df %>%
    mutate(
      direction_code = case_when(
        delta_ci_lo <= 0 & delta_ci_hi >= 0 ~ "Uncertain",
        delta_rso2_plus5 > 0               ~ "Positive",
        TRUE                               ~ "Negative"
      ),
      direction_code = factor(direction_code,
                              levels = c("Positive", "Uncertain", "Negative")),
      label_txt = sprintf("%.2f", delta_rso2_plus5)
    )

  ggplot(df_heat,
         aes(x = channel_f, y = subgroup_f, fill = direction_code)) +
    geom_tile(color = "white", linewidth = 0.8) +
    geom_text(aes(label = label_txt), size = 3.5, fontface = "bold",
              color = "grey10") +

    scale_fill_manual(
      values = c(Positive = "#4f86c6", Uncertain = "#e3e3e3", Negative = "#d95f5f"),
      name   = "Direction vs. Overall"
    ) +

    scale_x_discrete(labels = function(x) sub(" \\(.*\\)$", "", x)) +

    labs(
      x     = "Channel",
      y     = NULL,
      title = "Direction Consistency Heatmap",
      subtitle = expression("Values = " * Delta * "rSO"[2] * " for +5 mmHg ET"[CO[2]])
    ) +

    theme_bw(base_size = 12) +
    theme(
      plot.title      = element_text(face = "bold", size = 13),
      plot.subtitle   = element_text(size = 9, color = "grey40"),
      axis.text.x     = element_text(size = 11),
      axis.text.y     = element_text(size = 11),
      legend.position = "right",
      legend.title    = element_text(face = "bold", size = 10),
      panel.grid      = element_blank()
    )
}

p_heatmap <- make_heatmap(df)

# =============================================================================
# 保存函数：PNG + PDF + PPTX slide
# =============================================================================
save_figure <- function(plot_obj, stem, width_in, height_in, ppt_obj) {
  png_path <- file.path(OUT_DIR, paste0(stem, ".png"))
  pdf_path <- file.path(OUT_DIR, paste0(stem, ".pdf"))

  ggsave(png_path, plot_obj, width = width_in, height = height_in,
         dpi = 300, bg = "white")
  ggsave(pdf_path, plot_obj, width = width_in, height = height_in,
         device = cairo_pdf, bg = "white")
  message("Saved: ", basename(png_path))
  message("Saved: ", basename(pdf_path))

  # 添加到 PPTX（可编辑矢量图形 via rvg）
  ppt_obj <- add_slide(ppt_obj, layout = "Blank", master = "Office Theme")
  ppt_obj <- ph_with(
    ppt_obj,
    value = dml(ggobj = plot_obj),
    location = ph_location(
      left   = 0.5,
      top    = 0.5,
      width  = width_in,
      height = height_in
    )
  )
  return(ppt_obj)
}

# =============================================================================
# 执行保存
# =============================================================================
ppt <- read_pptx()

ppt <- save_figure(p_forest,
                   "subgroup_delta_forest_ggplot_modelB_n10000_b200",
                   width_in = 10, height_in = 5.5, ppt_obj = ppt)

ppt <- save_figure(p_heatmap,
                   "subgroup_direction_heatmap_ggplot_modelB_n10000_b200",
                   width_in = 7, height_in = 5, ppt_obj = ppt)

pptx_path <- file.path(OUT_DIR, "subgroup_plots_modelB_n10000_b200.pptx")
print(ppt, target = pptx_path)
message("Saved PPTX: ", basename(pptx_path))

message("\n✅ 全部完成。输出目录: ", OUT_DIR)
