#!/usr/bin/env Rscript
# =============================================================================
# v1.1 - 亚组一致性图（ggplot2 版，可输出 PPT 可编辑格式）
# 改动（相对 v1.0）：
#   - [fix] ch_colors 的 names 改为标签字符串，与 channel_f factor 对齐，
#           解决 "No shared levels" warning 导致颜色全灰的问题
#   - [fix] geom_errorbarh() 已在 ggplot2 4.0 废弃，
#           改用 geom_errorbar(orientation = "y")
# 图A: 森林图（Forest Plot）── 各亚组 × 通道 的 ΔrSO2(+5) + 95%CI
# 图B: 方向热图（Direction Heatmap）── 正/不确定/负 三色
# 输出：PNG(300dpi) / PDF(cairo) / 可编辑 PPTX（officer + rvg）
# 输入：
#   code/analysis_bundle/output/tables/
#     subgroup_consistency_etco2_delta_plus5_modelB_n10000_b200.csv
# 输出：
#   code/analysis_bundle/output/figures/
#     subgroup_delta_forest_ggplot_modelB_n10000_b200.{png,pdf}
#     subgroup_direction_heatmap_ggplot_modelB_n10000_b200.{png,pdf}
#     subgroup_plots_modelB_n10000_b200.pptx
# 基于：plot_subgroup_consistency_v1.0_ggplot.R
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(officer)
  library(rvg)
})

# ── 路径 ────────────────────────────────────────────────────────────────────
REPO    <- "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516"
IN_FILE <- file.path(REPO,
  "code/analysis_bundle/output/tables",
  "subgroup_consistency_etco2_delta_plus5_modelB_n10000_b200.csv")
OUT_DIR <- file.path(REPO, "code/analysis_bundle/output/figures")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ── 读取数据 ─────────────────────────────────────────────────────────────────
df_raw <- read.csv(IN_FILE, stringsAsFactors = FALSE)
df     <- df_raw[df_raw$status == "ok", ]
stopifnot(nrow(df) > 0)

# ── 亚组标签（按论文顺序：年龄→性别→高血压）─────────────────────────────────
sg_levels <- c(
  "Age_less_70", "Age_more_70",
  "Female", "Male",
  "Pre_hypertension_less_140_90", "Pre_hypertension_more_140_90"
)
sg_labels <- c(
  "Age < 70 yr", "Age \u2265 70 yr",
  "Female", "Male",
  "No Hypertension", "Hypertension"
)
names(sg_labels) <- sg_levels

# ── 通道标签 & 颜色 ───────────────────────────────────────────────────────────
ch_levels <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
ch_labels <- c("Ch1 (left frontal)", "Ch2 (right frontal)", "Ch3 (left somatic)")
names(ch_labels) <- ch_levels

# [fix v1.1] colors 必须以「factor 标签」为 name，而非原始列名
ch_colors <- setNames(
  c("#1f77b4", "#2ca02c", "#d62728"),
  ch_labels[ch_levels]           # ← 关键：用标签做 name
)

# ── 转 factor（森林图 Y 轴从下到上：最后一个亚组在最上）────────────────────
df$subgroup_f <- factor(df$subgroup,
                        levels = rev(sg_levels),
                        labels = rev(sg_labels[sg_levels]))
df$channel_f  <- factor(df$channel,
                        levels = ch_levels,
                        labels = ch_labels[ch_levels])

# ── 纵向偏移（同一亚组三通道错开，避免重叠）─────────────────────────────────
offsets       <- c(rSO2_Ch1 = -0.22, rSO2_Ch2 = 0.0, rSO2_Ch3 = 0.22)
df$y_offset   <- offsets[df$channel]
df$y_num      <- as.numeric(df$subgroup_f) + df$y_offset

# =============================================================================
# 图A：Forest Plot
# =============================================================================
make_forest <- function(df) {

  ggplot(df, aes(x = delta_rso2_plus5, y = y_num, color = channel_f)) +

    # [fix v1.1] geom_errorbarh → geom_errorbar(orientation="y")
    geom_errorbar(
      aes(xmin = delta_ci_lo, xmax = delta_ci_hi),
      orientation = "y",
      width       = 0.12,    # width 控制帽子长度（原 height 参数）
      linewidth   = 0.7,
      alpha       = 0.85
    ) +

    geom_point(size = 2.8, shape = 16) +

    geom_vline(xintercept = 0, linetype = "dashed",
               color = "#444444", linewidth = 0.6, alpha = 0.9) +

    scale_color_manual(
      values = ch_colors,          # ← 现在 name 与 channel_f levels 对齐
      name   = "Channel"
    ) +

    scale_y_continuous(
      breaks = seq_along(rev(sg_levels)),
      labels = sg_labels[rev(sg_levels)],
      expand = expansion(add = 0.6)
    ) +

    labs(
      x        = expression(Delta*"rSO"[2]*" for +5 mmHg ET"[CO[2]]*" (percentage points)"),
      y        = NULL,
      title    = "Subgroup Consistency: ET-CO\u2082 Effect on rSO\u2082",
      subtitle = "Model B  \u00b7  n = 10,000  \u00b7  bootstrap = 200  \u00b7  \u0394rSO\u2082 from median ET-CO\u2082 to +5 mmHg"
    ) +

    theme_bw(base_size = 12) +
    theme(
      plot.title         = element_text(face = "bold", size = 13),
      plot.subtitle      = element_text(size = 9, color = "grey40"),
      legend.position    = "right",
      legend.title       = element_text(face = "bold", size = 10),
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      axis.text.y        = element_text(size = 11)
    )
}

p_forest <- make_forest(df)

# =============================================================================
# 图B：Direction Heatmap
# =============================================================================
make_heatmap <- function(df) {

  df_heat <- df
  df_heat$direction_code <- with(df_heat, ifelse(
    delta_ci_lo <= 0 & delta_ci_hi >= 0, "Uncertain",
    ifelse(delta_rso2_plus5 > 0, "Positive", "Negative")
  ))
  df_heat$direction_code <- factor(df_heat$direction_code,
                                   levels = c("Positive", "Uncertain", "Negative"))
  df_heat$label_txt <- sprintf("%.2f", df_heat$delta_rso2_plus5)

  # x 轴只显示 "Ch1 / Ch2 / Ch3"（去掉括号里的位置描述）
  ch_short <- setNames(sub(" \\(.*\\)$", "", ch_labels[ch_levels]),
                       ch_labels[ch_levels])

  ggplot(df_heat,
         aes(x = channel_f, y = subgroup_f, fill = direction_code)) +

    geom_tile(color = "white", linewidth = 0.8) +
    geom_text(aes(label = label_txt), size = 3.8, fontface = "bold",
              color = "grey10") +

    scale_fill_manual(
      values = c(Positive = "#4f86c6", Uncertain = "#e3e3e3", Negative = "#d95f5f"),
      name   = "Direction vs. Overall\n(blue = same, red = opposite)"
    ) +

    scale_x_discrete(labels = ch_short) +

    labs(
      x        = "Channel",
      y        = NULL,
      title    = "Direction Consistency Heatmap",
      subtitle = expression("Cell value = \u0394rSO"[2]*" for +5 mmHg ET"[CO[2]]*"  |  blue: same direction as overall  |  grey: uncertain (95%CI crosses 0)")
    ) +

    theme_bw(base_size = 12) +
    theme(
      plot.title    = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(size = 8.5, color = "grey40"),
      axis.text.x   = element_text(size = 11),
      axis.text.y   = element_text(size = 11),
      legend.position = "right",
      legend.title  = element_text(face = "bold", size = 9),
      panel.grid    = element_blank()
    )
}

p_heatmap <- make_heatmap(df)

# =============================================================================
# 保存：PNG + PDF + PPTX（可编辑矢量）
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

  # PPTX slide：dml() 输出的是可编辑矢量对象
  ppt_obj <- add_slide(ppt_obj, layout = "Blank", master = "Office Theme")
  ppt_obj <- ph_with(
    ppt_obj,
    value    = dml(ggobj = plot_obj),
    location = ph_location(left = 0.3, top = 0.3,
                           width = width_in, height = height_in)
  )
  return(ppt_obj)
}

ppt <- read_pptx()

ppt <- save_figure(p_forest,
                   "subgroup_delta_forest_ggplot_modelB_n10000_b200",
                   width_in = 10, height_in = 5.5, ppt_obj = ppt)

ppt <- save_figure(p_heatmap,
                   "subgroup_direction_heatmap_ggplot_modelB_n10000_b200",
                   width_in = 7.5, height_in = 5, ppt_obj = ppt)

pptx_path <- file.path(OUT_DIR, "subgroup_plots_modelB_n10000_b200.pptx")
print(ppt, target = pptx_path)
message("Saved PPTX: ", basename(pptx_path))

message("\n\u2705 Done. Output: ", OUT_DIR)
