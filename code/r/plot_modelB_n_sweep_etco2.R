#!/usr/bin/env Rscript
# =============================================================================
# v1.1 - 样本量敏感性绘图与 PPT 生成脚本（ggplot2 + PPT 可编辑版）
# 基于：plot_subgroup_consistency_v1.2_ggplot.R 的设计规范
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(officer)
  library(rvg)
  library(xml2)
})

# ── 字体与常规变量 ─────────────────────────────────────────────────────────────
FONT_PRIMARY  <- "Aptos"
FONT_FALLBACK <- "Arial"
has_font <- function(family) {
  out <- tryCatch(system2("fc-list", stdout = TRUE, stderr = TRUE),
                  error = function(e) character(0))
  if (!length(out)) return(FALSE)
  any(grepl(family, out, ignore.case = TRUE))
}
BASE_FAMILY <- if (has_font(FONT_PRIMARY)) FONT_PRIMARY else FONT_FALLBACK

AXIS_LABEL_FONTSIZE <- 12
TICK_FONTSIZE       <- 10
SUBTITLE_FONTSIZE   <- 8.5
AXIS_COLOR          <- "#616161"
AXIS_LINEWIDTH      <- 0.7
AXIS_TICK_LEN_PT    <- 6
PLOT_MARGIN_PT      <- 5.5

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
REPO <- "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516"
IN_DIR <- file.path(REPO, "results/modelb_n_sweep_eval/tables")
OUT_DIR <- file.path(REPO, "results/modelb_n_sweep_eval/figures")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

DELTA_FILE  <- file.path(IN_DIR, "modelB_n_sweep_etco2_delta_summary.csv")
CURVES_FILE <- file.path(IN_DIR, "modelB_n_sweep_curves_data.csv")
STAB_FILE   <- file.path(IN_DIR, "modelB_n_sweep_stability_summary.csv")

# ── 通道标签与颜色映射 ─────────────────────────────────────────────────────────
ch_levels <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
ch_map <- c(
  rSO2_Ch1 = "Left SctO\u2082 (%)",
  rSO2_Ch2 = "Right SctO\u2082 (%)",
  rSO2_Ch3 = "SftO\u2082 (%)"
)
ch_colors <- c(
  "Left SctO\u2082 (%)" = "#1f77b4",
  "Right SctO\u2082 (%)" = "#2ca02c",
  "SftO\u2082 (%)" = "#d62728"
)

# =============================================================================
# 1. 绘制 Delta 效应折线图 (Fig 1)
# =============================================================================
plot_delta_fn <- function() {
  df <- read.csv(DELTA_FILE, stringsAsFactors = FALSE)
  df <- df[df$status == "ok", ]
  df$channel_f <- factor(ch_map[df$ycol], levels = unname(ch_map))
  
  ggplot(df, aes(x = sample_size, y = delta_rso2_plus5, color = channel_f, group = channel_f)) +
    geom_errorbar(aes(ymin = delta_ci_lo, ymax = delta_ci_hi), width = 0.05, linewidth = 0.6) +
    geom_line(linewidth = 1.0) +
    geom_point(size = 2.0) +
    geom_vline(xintercept = 10000, linetype = "dashed", color = "#7f7f7f", linewidth = 0.8) +
    scale_x_log10(
      breaks = c(500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000, 5000000),
      labels = c("500", "1k", "5k", "10k", "50k", "100k", "500k", "1M", "5M")
    ) +
    scale_color_manual(values = ch_colors, name = NULL) +
    labs(
      x = "Subsample Size N (log scale)",
      y = expression(Delta*"rSO"[2]*" (%) for +5 mmHg ET-CO"[2]),
      title = NULL
    ) +
    theme_clean() +
    theme(
      legend.position = "right",
      legend.title = element_blank(),
      legend.background = element_rect(fill = NA, colour = NA),
      legend.key = element_rect(fill = NA, colour = NA)
    )
}

# =============================================================================
# 2. 绘制 Response Curves 重叠图 (Fig 2)
# =============================================================================
plot_curves_fn <- function() {
  df <- read.csv(CURVES_FILE, stringsAsFactors = FALSE)
  df$channel_f <- factor(ch_map[df$ycol], levels = unname(ch_map))
  
  picks <- c(1000, 10000, 100000, 1000000)
  df_sub <- df %>% filter(sample_size %in% picks)
  df_sub$n_factor <- factor(df_sub$sample_size, levels = picks, 
                            labels = c("N = 1,000", "N = 10,000", "N = 100,000", "N = 1,000,000"))
  
  ggplot(df_sub, aes(x = etco2, y = pred, color = n_factor, fill = n_factor, group = n_factor)) +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.08, color = NA) +
    geom_line(linewidth = 1.0) +
    scale_color_viridis_d(name = NULL) +
    scale_fill_viridis_d(name = NULL) +
    facet_wrap(~channel_f, ncol = 3, scales = "free_y") +
    labs(
      x = expression("ET-CO"[2]*" (mmHg)"),
      y = "Predicted Oxygenation (%)",
      title = NULL
    ) +
    theme_clean() +
    theme(
      legend.position = "right",
      legend.background = element_rect(fill = NA, colour = NA),
      legend.key = element_rect(fill = NA, colour = NA),
      strip.background = element_blank(),
      strip.text = element_text(size = 12, face = "bold", family = BASE_FAMILY)
    )
}

# =============================================================================
# PPTX 导出设置 (13.333 x 7.5)
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
  add_slide(ppt, layout = "Blank", master = layout_summary(ppt)$master[1])
}

save_slide_plot <- function(ppt, plot_obj, stem, w_in, h_in) {
  png_path <- file.path(OUT_DIR, paste0(stem, ".png"))
  pdf_path <- file.path(OUT_DIR, paste0(stem, ".pdf"))
  ggsave(png_path, plot_obj, width = w_in, height = h_in, dpi = 300, bg = "white")
  ggsave(pdf_path, plot_obj, width = w_in, height = h_in, device = cairo_pdf, bg = "white")
  
  left_offset <- (SLIDE_W - w_in) / 2
  top_offset  <- (SLIDE_H - h_in) / 2
  
  ppt <- add_blank(ppt)
  
  title_txt <- if(stem == "modelB_n_sweep_delta_plus5_by_channel") {
    "ET-CO₂ Effect Size Stability vs Sample Size N"
  } else {
    "ET-CO₂ Response Curves across Subsample Sizes"
  }
  
  ppt <- ph_with(
    ppt,
    value = title_txt,
    location = ph_location(left = 0.5, top = 0.2, width = 12.33, height = 0.8)
  )
  
  ppt <- ph_with(
    ppt,
    value = dml(ggobj = plot_obj),
    location = ph_location(left = left_offset, top = 1.6, width = w_in, height = h_in)
  )
  return(ppt)
}

# =============================================================================
# 执行
# =============================================================================
p_delta <- plot_delta_fn()
p_curves <- plot_curves_fn()

ppt <- read_pptx()
ppt <- set_ppt_slide_size(ppt, SLIDE_W, SLIDE_H)

ppt <- save_slide_plot(ppt, p_delta, "modelB_n_sweep_delta_plus5_by_channel", w_in = 8.0, h_in = 4.8)
ppt <- save_slide_plot(ppt, p_curves, "modelB_n_sweep_curve_overlay_by_channel", w_in = 11.5, h_in = 4.8)

# ── 添加 Slide 3: 原生表格 ────────────────────────────────────────────────────
stab <- read.csv(STAB_FILE, stringsAsFactors = FALSE)
ppt <- add_blank(ppt)
ppt <- ph_with(
  ppt,
  value = "Stability Comparison: N=10,000 vs Maximum Sample Size N_ref",
  location = ph_location(left = 0.5, top = 0.2, width = 12.33, height = 0.8)
)

stab_formatted <- stab %>%
  mutate(
    Channel = ch_map[ycol],
    N_ref = format(as.numeric(n_ref), big.mark = ","),
    Delta_ref = sprintf("%.4f", as.numeric(delta_ref)),
    Delta_10k = sprintf("%.4f", as.numeric(delta_n10000)),
    Abs_Diff = sprintf("%.4f", as.numeric(abs_diff_n10000_vs_ref)),
    Rel_Diff = sprintf("%.2f%%", as.numeric(rel_diff_n10000_vs_ref) * 100),
    Stable = ifelse(n10000_in_stable_plateau == "True" | n10000_in_stable_plateau == "TRUE" | n10000_in_stable_plateau == TRUE, "Yes", "No")
  ) %>%
  select(Channel, N_ref, Delta_ref, Delta_10k, Abs_Diff, Rel_Diff, Stable)

ppt <- ph_with(
  ppt,
  value = stab_formatted,
  location = ph_location(left = 1.5, top = 1.8, width = 10.33, height = 0.4 * (nrow(stab_formatted) + 1))
)

out_pptx <- file.path(OUT_DIR, "modelB_n_sweep_etco2_stability_summary.pptx")
print(ppt, target = out_pptx)
message("[done] Generated R editable PPTX: ", out_pptx)
