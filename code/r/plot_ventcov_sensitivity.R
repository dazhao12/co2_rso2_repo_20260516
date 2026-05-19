#!/usr/bin/env Rscript
# =============================================================================
# R 绘图脚本: 通气协变量敏感性分析森林图 (5个模型对比)
# 采用与亚组图完全一致的聚集排版样式 (Clustered Forest Plot)
# 输出: PDF, PNG, 以及可直接导入 PPT 编辑的 PPTX 矢量文件
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(officer)
  library(rvg)
  library(xml2)
})

# ── 字体探测 ─────────────────────────────────────────────────────────────────
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

# ── 字号 / 颜色与主题 ─────────────────────────────────────────────────────────
AXIS_LABEL_FONTSIZE <- 12
TICK_FONTSIZE       <- 10
AXIS_COLOR          <- "#616161"
AXIS_LINEWIDTH      <- 0.7
AXIS_TICK_LEN_PT    <- 6
PLOT_MARGIN_PT      <- 5.5

theme_clean <- function() {
  theme_classic(base_size = TICK_FONTSIZE, base_family = BASE_FAMILY) +
    theme(
      panel.background  = element_rect(fill = "white", colour = NA),
      plot.background   = element_rect(fill = "white", colour = NA),
      panel.grid.major  = element_blank(),
      panel.grid.minor  = element_blank(),
      axis.title        = element_text(size = AXIS_LABEL_FONTSIZE, colour = "black"),
      axis.text         = element_text(size = TICK_FONTSIZE, colour = "black"),
      axis.line         = element_line(linewidth = AXIS_LINEWIDTH, colour = AXIS_COLOR),
      axis.ticks        = element_line(linewidth = AXIS_LINEWIDTH, colour = AXIS_COLOR),
      axis.ticks.length = unit(AXIS_TICK_LEN_PT, "pt"),
      plot.margin       = margin(PLOT_MARGIN_PT, PLOT_MARGIN_PT,
                                 PLOT_MARGIN_PT, PLOT_MARGIN_PT, "pt")
    )
}

# ── 1. 路径设置 ──────────────────────────────────────────────────────────────
base_dir <- "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/analysis_bundle"
csv_path <- file.path(base_dir, "output/tables/sensitivity_ventcov/etco2_sensitivity_5model_summary.csv")
out_dir  <- file.path(base_dir, "output/figures/sensitivity_ventcov")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(csv_path)) {
  stop(paste("找不到汇总 CSV 文件，请确认路径:", csv_path))
}

# ── 2. 读取并清洗数据 ──────────────────────────────────────────────────────────
df_raw <- read.csv(csv_path, stringsAsFactors = FALSE)
df     <- df_raw[df_raw$status == "ok", ]
stopifnot(nrow(df) > 0)

# ── 3. 定义通道与模型（顺序与标注）────────────────────────────────────────────
ch_levels <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
ch_labels <- c(
  "Left SctO\u2082 (%)",
  "Right SctO\u2082 (%)",
  "SftO\u2082 (%)"
)
names(ch_labels) <- ch_levels
ch_colors <- setNames(
  c("#1f77b4", "#2ca02c", "#d62728"),
  ch_labels[ch_levels]
)

model_levels <- c("base", "rrtotal_only", "tvinsp_only", "pmean_only", "all_three")
model_labels <- c(
  "Model B (Base Model)",
  "+ Respiratory Rate Only",
  "+ Tidal Volume Only",
  "+ Mean Airway Pressure Only",
  "Main Model (+ All Three)"
)
names(model_labels) <- model_levels

df$channel_f <- factor(df$ycol, levels = ch_levels, labels = ch_labels[ch_levels])
df$model_f   <- factor(df$run_key, levels = rev(model_levels), labels = rev(model_labels[model_levels]))

n_model <- length(model_levels)

# 计算 Y 轴偏移（将同一模型的三个通道在 Y 轴错开排列）
offsets     <- c(rSO2_Ch1 = -0.22, rSO2_Ch2 = 0.0, rSO2_Ch3 = 0.22)
df$y_offset <- offsets[df$ycol]
df$y_num    <- as.numeric(df$model_f) + df$y_offset

# ── 4. 计算底色带（交替灰色和白色）────────────────────────────────────────────
make_band_data <- function(model_levels) {
  n <- length(model_levels)
  bands <- data.frame(
    ymin = seq_len(n) - 0.45,
    ymax = seq_len(n) + 0.45,
    color = ifelse(seq_len(n) %% 2 == 0, "#f5f5f5", "white"),
    stringsAsFactors = FALSE
  )
  bands
}
bands <- make_band_data(model_levels)

# ── 5. ggplot2 聚集森林图绘制 ─────────────────────────────────────────────────
no_effect_y <- n_model + 0.52

p <- ggplot(df, aes(x = delta_rso2_plus5, y = y_num, color = channel_f)) +
  # ── 分组底色带 ───────────────────────────────────────────────────────
  geom_rect(
    data = bands,
    inherit.aes = FALSE,
    aes(xmin = -Inf, xmax = Inf, ymin = ymin, ymax = ymax),
    fill = bands$color,
    alpha = 0.6
  ) +

  # ── 零线 ─────────────────────────────────────────────────────────────
  geom_vline(xintercept = 0,
             linetype  = "solid",
             colour    = "#333333",
             linewidth = 0.8,
             alpha     = 0.75) +

  annotate("text",
           x = 0.05, y = no_effect_y,
           label  = "No effect",
           hjust  = 0, vjust  = 1,
           size   = 3.2, colour = "#333333",
           family = BASE_FAMILY) +

  # ── 95% CI 横线 ──────────────────────────────────────────────────────
  geom_errorbar(
    aes(xmin = delta_ci_lo, xmax = delta_ci_hi),
    orientation = "y",
    width     = 0.13,
    linewidth = 0.65,
    alpha     = 0.88
  ) +

  # ── 点估计 ───────────────────────────────────────────────────────────
  geom_point(size = 2.5, shape = 16) +

  scale_color_manual(values = ch_colors, name = NULL) +

  scale_y_continuous(
    breaks = seq_len(n_model),
    labels = model_labels[rev(model_levels)],
    expand = expansion(add = c(0.55, 0.75))
  ) +

  scale_x_continuous(breaks = seq(0, 4, 1)) +

  labs(
    x     = expression(Delta*"Tissue O"[2]*" saturation (pp),  ET-CO"[2]*" +5 mmHg"),
    y     = NULL,
    title = NULL
  ) +

  theme_clean() +
  theme(
    plot.margin     = margin(PLOT_MARGIN_PT, PLOT_MARGIN_PT,
                             PLOT_MARGIN_PT, PLOT_MARGIN_PT + 10, "pt"),
    axis.text.y     = element_text(size = TICK_FONTSIZE, hjust = 1,
                                   margin = margin(r = 4, unit = "pt")),
    legend.position = "right",
    legend.title    = element_blank(),
    legend.text     = element_text(size = TICK_FONTSIZE, family = BASE_FAMILY),
    legend.key.size = unit(14, "pt"),
    legend.background = element_rect(fill = NA, colour = NA),
    legend.key        = element_rect(fill = NA, colour = NA)
  )

# ── 6. 导出静态图与 PPTX ──────────────────────────────────────────────────────
SLIDE_W <- 13.333
SLIDE_H <- 7.5

set_ppt_slide_size <- function(ppt, w, h) {
  doc    <- ppt$presentation$get()
  ns     <- xml_ns(doc)
  sld_sz <- xml_find_first(doc, "//p:sldSz", ns = ns)
  if (!inherits(sld_sz, "xml_missing")) {
    xml_set_attr(sld_sz, "cx", as.character(round(w * 914400)))
    xml_set_attr(sld_sz, "cy", as.character(round(h * 914400)))
  }
  ppt
}

add_blank <- function(ppt) {
  add_slide(ppt, layout = "Blank",
            master = layout_summary(ppt)$master[1])
}

# 绘图区域尺寸限制（10 x 5.5 英寸，居中放置在 13.333 x 7.5 的幻灯片中）
w_in <- 10
h_in <- 5.5

png_path  <- file.path(out_dir, "etco2_sensitivity_5model_forest.png")
pdf_path  <- file.path(out_dir, "etco2_sensitivity_5model_forest.pdf")
pptx_path <- file.path(out_dir, "etco2_sensitivity_5model_forest.pptx")

ggsave(png_path, p, width = w_in, height = h_in, dpi = 300, bg = "white")
ggsave(pdf_path, p, width = w_in, height = h_in, device = cairo_pdf, bg = "white")
message("Saved PNG: ", basename(png_path))
message("Saved PDF: ", basename(pdf_path))

left_offset <- (SLIDE_W - w_in) / 2
top_offset  <- (SLIDE_H - h_in) / 2

ppt <- read_pptx()
ppt <- set_ppt_slide_size(ppt, SLIDE_W, SLIDE_H)
ppt <- add_blank(ppt)
ppt <- ph_with(
  ppt,
  value    = dml(ggobj = p),
  location = ph_location(left   = left_offset, top    = top_offset,
                         width  = w_in,         height = h_in)
)

print(ppt, target = pptx_path)
message("Saved PPTX: ", basename(pptx_path))
message("\u2705 Done.")
