#!/usr/bin/env Rscript
# =============================================================================
# v1.2 - 亚组一致性图（ggplot2 + PPT 可编辑版）
# 改动（相对 v1.1）：
#   - [style] 全面对齐 切片图_slice_only_ppt_v2_4_1_2026_multismooth.R 风格
#     · 字体：Aptos（有则用，否则 Arial）
#     · theme_classic 基础，白底无网格，轴线/刻度用 #616161
#     · 字号体系：轴标签 12pt、刻度 10pt、副标题 8.5pt
#   - [style] 去掉多余 title/subtitle，只保留简洁轴标签
#   - [fix]  Y 轴标签与面板边框不再拥挤：左侧 margin 加宽，
#            hjust=1 保证右对齐，plot.margin 留足左边距
#   - [label] 通道名称改为正式标名：
#             Ch1 = "Left SctO₂ (%)" / Ch2 = "Right SctO₂ (%)" / Ch3 = "SftO₂ (%)"
#   - [ppt] PPT 幻灯片尺寸 13.33×7.5 in（宽屏 16:9），图居中
# 输出：
#   code/analysis_bundle/output/figures/
#     subgroup_delta_forest_v1.2.{png,pdf}
#     subgroup_direction_heatmap_v1.2.{png,pdf}
#     subgroup_consistency_v1.2.pptx
# 基于：plot_subgroup_consistency_v1.1_ggplot.R
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(officer)
  library(rvg)
  library(xml2)
})

# ── 字体（与参考脚本相同逻辑）──────────────────────────────────────────────
FONT_PRIMARY  <- "Aptos"
FONT_FALLBACK <- "Arial"
has_font <- function(family) {
  out <- tryCatch(system2("fc-list", stdout = TRUE, stderr = TRUE),
                  error = function(e) character(0))
  if (!length(out)) return(FALSE)
  any(grepl(family, out, ignore.case = TRUE))
}
BASE_FAMILY <- if (has_font(FONT_PRIMARY)) FONT_PRIMARY else FONT_FALLBACK
message("[font] Using: ", BASE_FAMILY)

# ── 字号 / 颜色（直接从参考脚本抄）──────────────────────────────────────────
AXIS_LABEL_FONTSIZE <- 12
TICK_FONTSIZE       <- 10
SUBTITLE_FONTSIZE   <- 8.5
AXIS_COLOR          <- "#616161"
AXIS_LINEWIDTH      <- 0.7
AXIS_TICK_LEN_PT    <- 6
PLOT_MARGIN_PT      <- 5.5

# ── theme_clean（与参考脚本保持一致，仅 base_size 改为 TICK_FONTSIZE）──────
theme_clean <- function() {
  theme_classic(base_size = TICK_FONTSIZE, base_family = BASE_FAMILY) +
    theme(
      panel.background   = element_rect(fill = "white", colour = NA),
      plot.background    = element_rect(fill = "white", colour = NA),
      panel.grid.major   = element_blank(),
      panel.grid.minor   = element_blank(),
      axis.title         = element_text(size = AXIS_LABEL_FONTSIZE, colour = "black"),
      axis.text          = element_text(size = TICK_FONTSIZE, colour = "black"),
      plot.subtitle      = element_text(size = SUBTITLE_FONTSIZE, colour = "#2f2f2f"),
      plot.caption       = element_text(size = 7.5, colour = "#5a5a5a", hjust = 0),
      axis.line          = element_line(linewidth = AXIS_LINEWIDTH, colour = AXIS_COLOR),
      axis.ticks         = element_line(linewidth = AXIS_LINEWIDTH, colour = AXIS_COLOR),
      axis.ticks.length  = unit(AXIS_TICK_LEN_PT, "pt"),
      plot.margin        = margin(PLOT_MARGIN_PT, PLOT_MARGIN_PT, PLOT_MARGIN_PT,
                                  PLOT_MARGIN_PT, unit = "pt")
    )
}

# ── 路径 ─────────────────────────────────────────────────────────────────────
REPO    <- "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516"
IN_FILE <- file.path(REPO,
  "code/analysis_bundle/output/tables",
  "subgroup_consistency_etco2_delta_plus5_modelB_n10000_b200.csv")
OUT_DIR <- file.path(REPO, "code/analysis_bundle/output/figures")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ── 读取数据 ──────────────────────────────────────────────────────────────────
df_raw <- read.csv(IN_FILE, stringsAsFactors = FALSE)
df     <- df_raw[df_raw$status == "ok", ]
stopifnot(nrow(df) > 0)

# ── 亚组标签（从下到上排列）──────────────────────────────────────────────────
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

# ── 通道标签（正式名称）──────────────────────────────────────────────────────
ch_levels <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
ch_labels <- c(
  "Left SctO\u2082 (%)",    # rSO2_Ch1
  "Right SctO\u2082 (%)",   # rSO2_Ch2
  "SftO\u2082 (%)"          # rSO2_Ch3
)
names(ch_labels) <- ch_levels

# 颜色 name 必须和 factor label 一致
ch_colors <- setNames(
  c("#1f77b4", "#2ca02c", "#d62728"),
  ch_labels[ch_levels]
)

# ── Factor 转换 ───────────────────────────────────────────────────────────────
# 森林图 Y 轴：最后一个亚组在最上方
df$subgroup_f <- factor(df$subgroup,
                        levels = rev(sg_levels),
                        labels = rev(sg_labels[sg_levels]))
df$channel_f  <- factor(df$channel,
                        levels = ch_levels,
                        labels = ch_labels[ch_levels])

# 纵向偏移（同亚组三通道错开）
offsets     <- c(rSO2_Ch1 = -0.22, rSO2_Ch2 = 0.0, rSO2_Ch3 = 0.22)
df$y_offset <- offsets[df$channel]
df$y_num    <- as.numeric(df$subgroup_f) + df$y_offset

# =============================================================================
# 图A：Forest Plot
# =============================================================================
make_forest <- function(df) {

  n_sg  <- length(sg_levels)
  # Y 轴标签与面板边框之间的空间：用 expand 控制
  # 增加左侧 plot.margin（额外留出 Y 轴标签宽度）
  extra_left_pt <- 10

  p <- ggplot(df, aes(x = delta_rso2_plus5, y = y_num, color = channel_f)) +

    # 95% CI 横线
    geom_errorbar(
      aes(xmin = delta_ci_lo, xmax = delta_ci_hi),
      orientation = "y",
      width     = 0.13,
      linewidth = 0.65,
      alpha     = 0.88
    ) +

    # 点估计
    geom_point(size = 2.5, shape = 16) +

    # 零线
    geom_vline(xintercept = 0, linetype = "dashed",
               colour = "#444444", linewidth = 0.55, alpha = 0.85) +

    # 颜色（label 对齐，不报 warning）
    scale_color_manual(values = ch_colors, name = NULL) +

    # Y 轴：亚组标签（expand 避免第一行贴边）
    scale_y_continuous(
      breaks = seq_len(n_sg),
      labels = sg_labels[rev(sg_levels)],    # 从下到上
      expand = expansion(add = 0.55)
    ) +

    # X 轴
    scale_x_continuous(
      breaks = seq(-2, 5, 1),
      labels = function(x) ifelse(x == 0, "0", as.character(x))
    ) +

    labs(
      x     = expression(Delta*"rSO"[2]*" for +5 mmHg ET-CO"[2]*"  (percentage points)"),
      y     = NULL,
      title = NULL
    ) +

    theme_clean() +
    theme(
      # 加宽左侧 margin，防止 Y 轴标签被截断
      plot.margin      = margin(PLOT_MARGIN_PT, PLOT_MARGIN_PT,
                                PLOT_MARGIN_PT, PLOT_MARGIN_PT + extra_left_pt, "pt"),
      # Y 轴标签：右对齐，与轴线之间留一点间距
      axis.text.y      = element_text(size = TICK_FONTSIZE, hjust = 1,
                                      margin = margin(r = 4, unit = "pt")),
      legend.position  = "right",
      legend.title     = element_blank(),
      legend.text      = element_text(size = TICK_FONTSIZE, family = BASE_FAMILY),
      legend.key.size  = unit(14, "pt"),
      # 去掉 legend 背景框
      legend.background = element_rect(fill = NA, colour = NA),
      legend.key        = element_rect(fill = NA, colour = NA)
    )

  p
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

  # X 轴：只显示简短通道名（去掉括号内的 %）
  ch_short <- setNames(
    sub("\\s*\\(.*\\)$", "", ch_labels[ch_levels]),  # "Left SctO₂" 等
    ch_labels[ch_levels]
  )

  ggplot(df_heat,
         aes(x = channel_f, y = subgroup_f, fill = direction_code)) +

    geom_tile(color = "white", linewidth = 0.9) +
    geom_text(aes(label = label_txt),
              size = 3.6, fontface = "bold",
              family = BASE_FAMILY, colour = "grey10") +

    scale_fill_manual(
      values = c(Positive = "#4f86c6", Uncertain = "#e8e8e8", Negative = "#d95f5f"),
      name   = NULL,
      labels = c(Positive = "Positive", Uncertain = "Uncertain (95%CI \u22130)", Negative = "Negative")
    ) +

    scale_x_discrete(labels = ch_short) +

    labs(
      x     = NULL,
      y     = NULL,
      title = NULL
    ) +

    theme_clean() +
    theme(
      axis.line        = element_blank(),   # 热图不需要轴线
      axis.ticks       = element_blank(),
      axis.text.x      = element_text(size = TICK_FONTSIZE, colour = "black",
                                      margin = margin(t = 4, unit = "pt")),
      axis.text.y      = element_text(size = TICK_FONTSIZE, hjust = 1, colour = "black",
                                      margin = margin(r = 5, unit = "pt")),
      plot.margin      = margin(PLOT_MARGIN_PT, PLOT_MARGIN_PT,
                                PLOT_MARGIN_PT, PLOT_MARGIN_PT + 8, "pt"),
      legend.position  = "right",
      legend.text      = element_text(size = TICK_FONTSIZE - 0.5, family = BASE_FAMILY),
      legend.key.size  = unit(14, "pt"),
      legend.background = element_rect(fill = NA, colour = NA),
      legend.key        = element_rect(fill = NA, colour = NA),
      panel.border      = element_blank()
    )
}

p_heatmap <- make_heatmap(df)

# =============================================================================
# PPT 幻灯片尺寸设置（16:9 宽屏，与参考脚本一致）
# =============================================================================
SLIDE_W <- 13.333
SLIDE_H <- 7.5

set_ppt_slide_size <- function(ppt, width_in, height_in) {
  doc    <- ppt$presentation$get()
  ns     <- xml_ns(doc)
  sld_sz <- xml_find_first(doc, "//p:sldSz", ns = ns)
  if (!inherits(sld_sz, "xml_missing")) {
    xml_set_attr(sld_sz, "cx", as.character(round(width_in  * 914400)))
    xml_set_attr(sld_sz, "cy", as.character(round(height_in * 914400)))
  }
  ppt
}

add_blank <- function(ppt) {
  add_slide(ppt, layout = "Blank",
            master = layout_summary(ppt)$master[1])
}

# =============================================================================
# 保存函数（PNG 300dpi + PDF cairo + PPTX 矢量）
# =============================================================================
save_figure <- function(plot_obj, stem, w_in, h_in, ppt_obj) {
  png_path <- file.path(OUT_DIR, paste0(stem, ".png"))
  pdf_path <- file.path(OUT_DIR, paste0(stem, ".pdf"))

  ggsave(png_path, plot_obj, width = w_in, height = h_in,
         dpi = 300, bg = "white")
  ggsave(pdf_path, plot_obj, width = w_in, height = h_in,
         device = cairo_pdf, bg = "white")
  message("Saved: ", basename(png_path))
  message("Saved: ", basename(pdf_path))

  # 居中放置在幻灯片上
  left_offset <- (SLIDE_W - w_in) / 2
  top_offset  <- (SLIDE_H - h_in) / 2

  ppt_obj <- add_blank(ppt_obj)
  ppt_obj <- ph_with(
    ppt_obj,
    value    = dml(ggobj = plot_obj),
    location = ph_location(left   = left_offset,
                           top    = top_offset,
                           width  = w_in,
                           height = h_in)
  )
  return(ppt_obj)
}

# =============================================================================
# 执行
# =============================================================================
ppt <- read_pptx()
ppt <- set_ppt_slide_size(ppt, SLIDE_W, SLIDE_H)

ppt <- save_figure(p_forest,
                   "subgroup_delta_forest_v1.2",
                   w_in = 10, h_in = 5.5, ppt_obj = ppt)

ppt <- save_figure(p_heatmap,
                   "subgroup_direction_heatmap_v1.2",
                   w_in = 7, h_in = 5, ppt_obj = ppt)

pptx_path <- file.path(OUT_DIR, "subgroup_consistency_v1.2.pptx")
print(ppt, target = pptx_path)
message("Saved PPTX: ", basename(pptx_path))
message("\n\u2705 Done. Output: ", OUT_DIR)
