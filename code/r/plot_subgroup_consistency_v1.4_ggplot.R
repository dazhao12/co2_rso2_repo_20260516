#!/usr/bin/env Rscript
# =============================================================================
# v1.4 - 亚组一致性图 — 7组14子层（ggplot2 + PPT 可编辑版）
# 改动（相对 v1.3）：
#   - [subgroup] 新增4个亚组（糖尿病/贫血/BMI/颈动脉），共7组14条
#   - [layout] 森林图和热图高度自动适配更多亚组行
#   - [forest] 亚组之间加水平分隔带（按category分组视觉区分）
#   - [heatmap] 行数增加，X轴通道标签保持简洁
# 基于：plot_subgroup_consistency_v1.3_ggplot.R
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(officer)
  library(rvg)
  library(xml2)
})

# ── 字体 ─────────────────────────────────────────────────────────────────────
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

# ── 字号 / 颜色 ───────────────────────────────────────────────────────────────
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

# ── 路径 ─────────────────────────────────────────────────────────────────────
REPO    <- "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516"
IN_FILE <- file.path(REPO,
  "code/analysis_bundle/output/tables",
  "subgroup_consistency_etco2_delta_plus5_modelB_n10000_b200.csv")
OUT_DIR <- file.path(REPO, "code/analysis_bundle/output/figures")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ── 数据 ─────────────────────────────────────────────────────────────────────
df_raw <- read.csv(IN_FILE, stringsAsFactors = FALSE)
df     <- df_raw[df_raw$status == "ok", ]
stopifnot(nrow(df) > 0)

# ── 亚组标签（从下到上，按临床分类分组）─────────────────────────────────────
# 顺序：颈动脉 → BMI → 贫血 → 糖尿病 → 高血压 → 性别 → 年龄（最上方）
sg_levels <- c(
  "Carotid_No", "Carotid_Yes",
  "BMI_lt28", "BMI_ge28",
  "Anemia_WHO_No", "Anemia_WHO_Yes",
  "Diabetes_No", "Diabetes_Yes",
  "Pre_hypertension_less_140_90", "Pre_hypertension_more_140_90",
  "Female", "Male",
  "Age_less_70", "Age_more_70"
)
sg_labels <- c(
  "No Carotid Disease",  "Carotid Disease",
  "BMI < 28",            "BMI \u2265 28",
  "No Anemia",           "Anemia (WHO)",
  "No Diabetes",         "Diabetes",
  "No Hypertension",     "Hypertension",
  "Female",              "Male",
  "Age < 70 yr",         "Age \u2265 70 yr"
)
names(sg_labels) <- sg_levels

# 分组标注（用于添加左侧分组标签或分隔带）
sg_categories <- c(
  rep("Carotid", 2), rep("BMI", 2), rep("Anemia", 2),
  rep("Diabetes", 2), rep("HTN", 2), rep("Sex", 2), rep("Age", 2)
)
names(sg_categories) <- sg_levels

# ── 通道标签 & 颜色 ──────────────────────────────────────────────────────────
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

# ── Factor 转换 ───────────────────────────────────────────────────────────────
# 只保留数据中存在的亚组
sg_present <- sg_levels[sg_levels %in% unique(df$subgroup)]
sg_labels_present <- sg_labels[sg_present]

df$subgroup_f <- factor(df$subgroup,
                        levels = rev(sg_present),
                        labels = rev(sg_labels_present))
df$channel_f  <- factor(df$channel,
                        levels = ch_levels,
                        labels = ch_labels[ch_levels])

n_sg <- length(sg_present)

offsets     <- c(rSO2_Ch1 = -0.22, rSO2_Ch2 = 0.0, rSO2_Ch3 = 0.22)
df$y_offset <- offsets[df$channel]
df$y_num    <- as.numeric(df$subgroup_f) + df$y_offset

# ── 分组分隔带（灰色半透明矩形，每对亚组交替底色）──────────────────────────
make_band_data <- function(sg_present) {
  # sg_present 是从下到上的顺序，reverse 后 factor 的 numeric 从1开始
  # 每对（2个子层）用一个矩形
  n <- length(sg_present)
  cats <- sg_categories[rev(sg_present)]  # 对应 factor 1..n 的分类
  unique_cats <- unique(cats)  # 按出现顺序
  bands <- data.frame(ymin = numeric(0), ymax = numeric(0),
                      fill_band = character(0), stringsAsFactors = FALSE)
  for (uc in unique_cats) {
    idx <- which(cats == uc)
    bands <- rbind(bands, data.frame(
      ymin = min(idx) - 0.45,
      ymax = max(idx) + 0.45,
      fill_band = uc,
      stringsAsFactors = FALSE
    ))
  }
  # 交替着色
  bands$color <- ifelse(seq_len(nrow(bands)) %% 2 == 0, "#f5f5f5", "white")
  bands
}

bands <- make_band_data(sg_present)

# =============================================================================
# 图A：Forest Plot  v1.4
# =============================================================================
make_forest <- function(df) {

  no_effect_y <- n_sg + 0.52

  ggplot(df, aes(x = delta_rso2_plus5, y = y_num, color = channel_f)) +

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
      breaks = seq_len(n_sg),
      labels = sg_labels_present[rev(sg_present)],
      expand = expansion(add = c(0.55, 0.75))
    ) +

    scale_x_continuous(breaks = seq(-2, 5, 1)) +

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
}

p_forest <- make_forest(df)

# =============================================================================
# 图B：Direction Heatmap  v1.4
# =============================================================================
make_heatmap <- function(df) {

  df_heat <- df
  df_heat$ci_status <- with(df_heat, ifelse(
    delta_ci_lo <= 0 & delta_ci_hi >= 0,
    "95%CI \u220b 0",
    ifelse(delta_rso2_plus5 > 0, "95%CI > 0", "95%CI < 0")
  ))
  df_heat$ci_status <- factor(df_heat$ci_status,
                              levels = c("95%CI > 0", "95%CI \u220b 0", "95%CI < 0"))
  df_heat$label_txt <- sprintf("%.2f", df_heat$delta_rso2_plus5)

  ch_short <- setNames(
    sub("\\s*\\(.*\\)$", "", ch_labels[ch_levels]),
    ch_labels[ch_levels]
  )

  ggplot(df_heat,
         aes(x = channel_f, y = subgroup_f, fill = ci_status)) +

    geom_tile(color = "white", linewidth = 0.9) +
    geom_text(aes(label = label_txt),
              size = 3.5, fontface = "bold",
              family = BASE_FAMILY, colour = "grey10") +

    scale_fill_manual(
      values = c(
        "95%CI > 0"        = "#4f86c6",
        "95%CI \u220b 0"   = "#e8e8e8",
        "95%CI < 0"        = "#d95f5f"
      ),
      name = "Bootstrap 95%CI",
      drop = FALSE
    ) +

    scale_x_discrete(labels = ch_short) +

    labs(x = NULL, y = NULL, title = NULL) +

    theme_clean() +
    theme(
      axis.line    = element_blank(),
      axis.ticks   = element_blank(),
      axis.text.x  = element_text(size = TICK_FONTSIZE, colour = "black",
                                  margin = margin(t = 4, unit = "pt")),
      axis.text.y  = element_text(size = TICK_FONTSIZE, hjust = 1, colour = "black",
                                  margin = margin(r = 5, unit = "pt")),
      plot.margin  = margin(PLOT_MARGIN_PT, PLOT_MARGIN_PT,
                            PLOT_MARGIN_PT, PLOT_MARGIN_PT + 8, "pt"),
      legend.position  = "right",
      legend.title     = element_text(size = TICK_FONTSIZE, face = "bold",
                                      family = BASE_FAMILY),
      legend.text      = element_text(size = TICK_FONTSIZE, family = BASE_FAMILY),
      legend.key.size  = unit(14, "pt"),
      legend.background = element_rect(fill = NA, colour = NA),
      legend.key        = element_rect(fill = NA, colour = NA),
      panel.border      = element_blank()
    )
}

p_heatmap <- make_heatmap(df)

# =============================================================================
# PPT 工具函数
# =============================================================================
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

save_figure <- function(plot_obj, stem, w_in, h_in, ppt_obj) {
  png_path <- file.path(OUT_DIR, paste0(stem, ".png"))
  pdf_path <- file.path(OUT_DIR, paste0(stem, ".pdf"))

  ggsave(png_path, plot_obj, width = w_in, height = h_in,
         dpi = 300, bg = "white")
  ggsave(pdf_path, plot_obj, width = w_in, height = h_in,
         device = cairo_pdf, bg = "white")
  message("Saved: ", basename(png_path))
  message("Saved: ", basename(pdf_path))

  left_offset <- (SLIDE_W - w_in) / 2
  top_offset  <- (SLIDE_H - h_in) / 2

  ppt_obj <- add_blank(ppt_obj)
  ppt_obj <- ph_with(
    ppt_obj,
    value    = dml(ggobj = plot_obj),
    location = ph_location(left   = left_offset, top    = top_offset,
                           width  = w_in,         height = h_in)
  )
  return(ppt_obj)
}

# =============================================================================
# 执行
# =============================================================================
# 自适应高度：每亚组约 0.55 in
forest_h  <- max(5.5, n_sg * 0.55 + 1.2)
heatmap_h <- max(5.0, n_sg * 0.45 + 1.0)

ppt <- read_pptx()
ppt <- set_ppt_slide_size(ppt, SLIDE_W, SLIDE_H)

ppt <- save_figure(p_forest,
                   "subgroup_delta_forest_v1.4",
                   w_in = 10, h_in = forest_h, ppt_obj = ppt)

ppt <- save_figure(p_heatmap,
                   "subgroup_direction_heatmap_v1.4",
                   w_in = 7.5, h_in = heatmap_h, ppt_obj = ppt)

pptx_path <- file.path(OUT_DIR, "subgroup_consistency_v1.4.pptx")
print(ppt, target = pptx_path)
message("Saved PPTX: ", basename(pptx_path))
message("\n\u2705 Done. ", n_sg, " subgroups plotted. Output: ", OUT_DIR)
