#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-
# =============================================================================
# Description: Distributions and summaries for the three tissue oxygen cohorts
#              aligned to contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py
#
# Logic:
#   1) Load time series data from CSVs.
#   2) For each channel (rSO2_Ch1, rSO2_Ch2, rSO2_Ch3):
#      - Retain rows where ET_CO2 and ycol are non-missing (stage1 only).
#      - Do NOT perform range exclusion, clipping, or imputation.
#      - Describe distributions of ET_CO2 and ycol only.
#      - Generate side-by-side histograms (auto x-range) and export to PPT.
#   3) Export a PowerPoint presentation and Excel summaries.
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(tidyverse)
  library(glue)
  library(fs)
  library(officer)
  library(rvg)
  library(scales)
  library(openxlsx)
  library(patchwork)
  library(showtext)
  library(xml2)
})

Sys.setenv(TZ = "America/New_York")

# ── Slide Size Helper ────────────────────────────────────────────────────────
set_ppt_slide_size <- function(ppt, width_in, height_in) {
  doc <- ppt$presentation$get()
  ns <- xml2::xml_ns(doc)
  sld_sz <- xml2::xml_find_first(doc, "//p:sldSz", ns = ns)
  if (!inherits(sld_sz, "xml_missing")) {
    xml2::xml_set_attr(sld_sz, "cx", as.character(round(width_in * 914400)))
    xml2::xml_set_attr(sld_sz, "cy", as.character(round(height_in * 914400)))
  }
  ppt
}

# ── 路径与配置 ─────────────────────────────────────────────────────────────
REPO <- "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516"
CSV_DIR <- "/N/project/waveform_mortality/ZhaoZhang/data_ML_11_21_2025_final/final_processed"
OUT_DIR <- file.path(REPO, "results/modeling_data_description")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# 缓存配置：首次构建后，后续直接读缓存避免重复扫描 1800+ CSV
CACHE_DIR <- file.path(OUT_DIR, "cache")
dir.create(CACHE_DIR, recursive = TRUE, showWarnings = FALSE)
RAW_CACHE_RDS <- file.path(CACHE_DIR, "final_processed_selected_cols.rds")
RAW_CACHE_META_RDS <- file.path(CACHE_DIR, "final_processed_selected_cols_meta.rds")
FORCE_REBUILD_CACHE <- FALSE

STAMP <- format(Sys.time(), "%Y%m%d_%H%M%S")
PPT_PATH <- file.path(OUT_DIR, glue("modeling_cohort_distributions_{STAMP}.pptx"))
EXCEL_PATH <- file.path(OUT_DIR, glue("modeling_cohort_summary_stats_{STAMP}.xlsx"))

CHANNELS <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
ch_map <- c(
  rSO2_Ch1 = "Left SctO\u2082",
  rSO2_Ch2 = "Right SctO\u2082",
  rSO2_Ch3 = "SftO\u2082"
)

# ── 字体配置 ───────────────────────────────────────────────────────────────
FONT_PRIMARY <- "Aptos"
FONT_FALLBACK <- "Arial"
has_font <- function(family) {
  out <- tryCatch(system2("fc-list", stdout = TRUE, stderr = TRUE),
                  error = function(e) character(0))
  if (!length(out)) return(FALSE)
  any(grepl(family, out, ignore.case = TRUE))
}
BASE_FAMILY <- if (has_font(FONT_PRIMARY)) FONT_PRIMARY else FONT_FALLBACK

# ── 旧版直方图参数（对齐 contour 脚本）──────────────────────────────────────
cm_to_in <- function(cm) cm / 2.54
FIG_W_CM <- 9
FIG_H_CM <- 8
FIG_W <- cm_to_in(FIG_W_CM)
FIG_H <- cm_to_in(FIG_H_CM)

AXIS_LABEL_FONTSIZE <- 12
TICK_FONTSIZE <- 10
AXIS_COLOR <- "#616161"
AXIS_LINEWIDTH <- 0.7
AXIS_TICK_LEN_PT <- 6

# ── 绘图样式与主题（对齐旧版）──────────────────────────────────────────────
theme_sci_hist <- function() {
  theme_classic(base_size = 13, base_family = BASE_FAMILY) +
    theme(
      plot.title = element_blank(),
      axis.title = element_text(size = AXIS_LABEL_FONTSIZE, colour = "black"),
      axis.text = element_text(size = TICK_FONTSIZE, colour = "black"),
      axis.line = element_line(linewidth = AXIS_LINEWIDTH, colour = AXIS_COLOR),
      axis.ticks = element_line(linewidth = AXIS_LINEWIDTH, colour = AXIS_COLOR),
      axis.ticks.length = unit(AXIS_TICK_LEN_PT, "pt"),
      plot.margin = margin(6, 8, 4, 8, unit = "pt")
    )
}

# 填充颜色
COL_ETCO2 <- "#D9E2F3" # 浅蓝
COL_RSO2 <- c(
  rSO2_Ch1 = "#FFF2CC", # 浅黄
  rSO2_Ch2 = "#E2F0D9", # 浅绿
  rSO2_Ch3 = "#FBE5D6"  # 浅橙
)
# 计数标签格式化
label_k <- function(x) {
  ifelse(is.na(x), NA_character_,
         ifelse(x == 0, "0",
                ifelse(x >= 1000, paste0(format(round(x / 1000), big.mark = ","), "K"), as.character(x))))
}

# ── 1. 加载数据 ─────────────────────────────────────────────────────────────
message("[step 1] Loading timeseries files from final_processed...")
files <- list.files(CSV_DIR, pattern = "\\.csv$", full.names = TRUE)
if (!length(files)) stop("No CSV files found in: ", CSV_DIR)

need_cols <- c("patient_ID", "obstime", "ET_CO2", "rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3", "TEMP", "FiO2_new")

# 轻量指纹：用于判断缓存是否可复用
sig_size <- as.numeric(file.info(files)$size)
sig_mtime <- as.numeric(file.info(files)$mtime)
current_fingerprint <- list(
  n_files = length(files),
  size_sum = sum(sig_size, na.rm = TRUE),
  mtime_max = max(sig_mtime, na.rm = TRUE)
)

use_cache <- FALSE
if (!FORCE_REBUILD_CACHE &&
    file.exists(RAW_CACHE_RDS) &&
    file.exists(RAW_CACHE_META_RDS)) {
  old_meta <- tryCatch(readRDS(RAW_CACHE_META_RDS), error = function(e) NULL)
  if (!is.null(old_meta) &&
      isTRUE(all.equal(old_meta$n_files, current_fingerprint$n_files)) &&
      isTRUE(all.equal(old_meta$size_sum, current_fingerprint$size_sum)) &&
      isTRUE(all.equal(old_meta$mtime_max, current_fingerprint$mtime_max))) {
    use_cache <- TRUE
  }
}

if (use_cache) {
  message(glue("Cache hit: loading cached dataset -> {RAW_CACHE_RDS}"))
  df_all <- as.data.table(readRDS(RAW_CACHE_RDS))
} else {
  message("Cache miss: scanning CSV files and rebuilding cache...")
  d_list <- list()
  for (i in seq_along(files)) {
    fp <- files[i]
    hdr <- names(fread(fp, nrows = 0))
    use <- intersect(need_cols, hdr)
    if (!all(c("patient_ID", "ET_CO2") %in% use)) next
    
    dt <- fread(fp, select = use, showProgress = FALSE)
    if (nrow(dt)) d_list[[length(d_list) + 1]] <- dt
    if (length(d_list) %% 200 == 0) {
      message(glue("Loaded {length(d_list)} / {length(files)} files..."))
    }
  }
  df_all <- rbindlist(d_list, fill = TRUE, use.names = TRUE)
  saveRDS(df_all, RAW_CACHE_RDS, compress = "xz")
  saveRDS(current_fingerprint, RAW_CACHE_META_RDS, compress = "xz")
  message(glue("Cache rebuilt and saved: {RAW_CACHE_RDS}"))
}

message(glue("Loaded overall rows: {nrow(df_all)}, patients: {uniqueN(df_all$patient_ID)}"))

# 强制转换类型
df_all[, obstime := as.numeric(obstime)]
df_all[, ET_CO2 := as.numeric(ET_CO2)]
df_all[, rSO2_Ch1 := as.numeric(rSO2_Ch1)]
df_all[, rSO2_Ch2 := as.numeric(rSO2_Ch2)]
df_all[, rSO2_Ch3 := as.numeric(rSO2_Ch3)]
df_all[, TEMP := as.numeric(TEMP)]
df_all[, FiO2_new := as.numeric(FiO2_new)]

# ── 2. Stage1 辅助函数（仅去缺失）────────────────────────────────────────────
build_stage1_data <- function(df, ycol) {
  # 仅保留 ET_CO2 与 outcome 非缺失点；不做异常值剔除/裁剪/插补
  df_sub <- df[!is.na(ET_CO2) & !is.na(get(ycol))]
  setorder(df_sub, patient_ID, obstime)
  return(df_sub)
}

# ── 3. 统计描述辅助函数 ──────────────────────────────────────────────────────
get_summary_stats <- function(dt, ycol) {
  vars <- c("ET_CO2", ycol)
  stats_list <- list()
  qsafe <- function(x, p) {
    xx <- x[is.finite(x)]
    if (!length(xx)) return(NA_real_)
    as.numeric(quantile(xx, p, na.rm = TRUE))
  }
  msafe <- function(x, fn) {
    xx <- x[is.finite(x)]
    if (!length(xx)) return(NA_real_)
    fn(xx)
  }
  
  for (v in vars) {
    val <- dt[[v]]
    disp_v <- ifelse(v == ycol, "Tissue_Oxygen", v)
    stats_list[[length(stats_list) + 1]] <- tibble(
      Cohort = ch_map[ycol],
      Variable = disp_v,
      N_Patients = uniqueN(dt$patient_ID),
      N_Points = nrow(dt),
      Mean = msafe(val, mean),
      SD = msafe(val, sd),
      Min = msafe(val, min),
      Q25 = qsafe(val, 0.25),
      Median = qsafe(val, 0.50),
      Q75 = qsafe(val, 0.75),
      Max = msafe(val, max)
    )
  }
  bind_rows(stats_list)
}

# ── 4. 绘图辅助函数 ─────────────────────────────────────────────────────────
plot_histogram <- function(dt, col, xlab, fill_col, breaks_val = NULL, xlim_val = NULL) {
  val <- dt[[col]]
  val <- val[is.finite(val)]
  
  # 确定箱宽（仅本副本：CO2 和组织氧都改为 2）
  bw <- 1
  if (col == "ET_CO2" || startsWith(col, "rSO2_")) bw <- 2
  
  lo <- floor(min(val) / bw) * bw
  hi <- ceiling(max(val) / bw) * bw
  br <- seq(lo, hi, by = bw)
  
  h <- hist(val, breaks = br, plot = FALSE, include.lowest = TRUE, right = TRUE)
  df_bin <- tibble(
    bin_left = h$breaks[-length(h$breaks)],
    bin_right = h$breaks[-1],
    bin_mid = h$mids,
    count = as.integer(h$counts),
    width = bin_right - bin_left
  )
  
  p <- ggplot(df_bin, aes(x = bin_left, y = count, width = width)) +
    geom_col(
      color = scales::alpha(AXIS_COLOR, 0.3),
      fill = fill_col,
      linewidth = 0.5
    ) +
    labs(x = xlab, y = "Counts (n)") +
    scale_y_continuous(
      breaks = pretty_breaks(n = 5),
      labels = label_k,
      expand = expansion(mult = c(0, 0.05))
    ) +
    theme_sci_hist()
  
  # 固定 x 轴口径（用户指定）
  if (col == "ET_CO2") {
    p <- p +
      coord_cartesian(xlim = c(0, 80)) +
      scale_x_continuous(breaks = seq(0, 80, by = 10), expand = expansion(mult = c(0, 0)))
  } else if (startsWith(col, "rSO2_")) {
    p <- p +
      coord_cartesian(xlim = c(0, 100)) +
      scale_x_continuous(breaks = seq(0, 100, by = 10), expand = expansion(mult = c(0, 0)))
  } else if (!is.null(xlim_val)) {
    p <- p + coord_cartesian(xlim = xlim_val) +
      scale_x_continuous(breaks = breaks_val, expand = expansion(mult = c(0, 0)))
  } else {
    p <- p + scale_x_continuous(expand = expansion(mult = c(0, 0)))
  }
  
  return(p)
}

# ── 5. 循环构建与描述 ────────────────────────────────────────────────────────
summary_all <- list()
ppt <- read_pptx()
# 设置尺寸为 16:9 比例 (13.33 x 7.5 英寸)
SLIDE_W <- 13.33
SLIDE_H <- 7.5
ppt <- set_ppt_slide_size(ppt, SLIDE_W, SLIDE_H)

wb <- createWorkbook()
addWorksheet(wb, "Summary_Statistics")

for (ycol in CHANNELS) {
  message(glue("\n[step 2] Processing cohort for {ycol} ({ch_map[ycol]})..."))
  
  # Stage1: missing-value exclusion only
  dt_model <- build_stage1_data(df_all, ycol)
  
  # 统计描述
  stats <- get_summary_stats(dt_model, ycol)
  summary_all[[ycol]] <- stats
  
  # 绘图
  message("Generating plots...")
  p_et   <- plot_histogram(dt_model, "ET_CO2", "End-Tidal CO\u2082 (mmHg)", COL_ETCO2)
  p_rso2 <- plot_histogram(dt_model, ycol, paste0(ch_map[ycol], " (%)"), COL_RSO2[ycol])
  
  # 同一通道拼在一页（ET_CO2 + 对应组织氧）
  p_comb <- (p_et + p_rso2) + plot_layout(ncol = 2)
  combo_w <- FIG_W * 2 + 0.35
  combo_h <- FIG_H
  combo_left <- 1.0
  combo_top <- 1.0

  stem <- glue("modeling_cohort_dist_{ycol}_combined")
  png_path <- file.path(OUT_DIR, paste0(stem, ".png"))
  pdf_path <- file.path(OUT_DIR, paste0(stem, ".pdf"))
  ggsave(png_path, p_comb, width = combo_w, height = combo_h, dpi = 320, bg = "white")
  ggsave(pdf_path, p_comb, width = combo_w, height = combo_h, device = cairo_pdf, bg = "white")
  message(glue("Saved combined plot: {png_path}"))

  ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
  ppt <- ph_with(
    ppt,
    value = dml(ggobj = p_comb),
    location = ph_location(left = combo_left, top = combo_top, width = combo_w, height = combo_h)
  )
}

# ── 6. 整理汇总并输出 Excel 和 PPTX ──────────────────────────────────────────
df_summary_all <- bind_rows(summary_all)

# 写入 Excel
writeData(wb, "Summary_Statistics", df_summary_all)
# 美化 Excel 列宽
setColWidths(wb, "Summary_Statistics", cols = 1:ncol(df_summary_all), widths = "auto")
saveWorkbook(wb, EXCEL_PATH, overwrite = TRUE)
message("Excel summary stats saved: ", EXCEL_PATH)

# 将汇总表也作为最后一页 Slide 放入 PPTX
ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
ppt <- ph_with(
  ppt,
  value = "Summary Statistics of the Three Modeling Cohorts",
  location = ph_location(left = 0.5, top = 0.2, width = 12.33, height = 0.8)
)

# 格式化表格显示
df_tab_print <- df_summary_all %>%
  mutate(
    Mean_SD = sprintf("%.2f \u00B1 %.2f", Mean, SD),
    Median_IQR = sprintf("%.2f (%.2f - %.2f)", Median, Q25, Q75),
    Range = sprintf("[%.2f, %.2f]", Min, Max),
    N_Patients = format(N_Patients, big.mark = ","),
    N_Points = format(N_Points, big.mark = ",")
  ) %>%
  select(Cohort, Variable, N_Patients, N_Points, Mean_SD, Median_IQR, Range)

ppt <- ph_with(
  ppt,
  value = df_tab_print,
  location = ph_location(left = 1.0, top = 1.5, width = 11.33, height = 0.4 * (nrow(df_tab_print) + 1))
)

print(ppt, target = PPT_PATH)
message("PowerPoint presentation saved: ", PPT_PATH)

message("🎯 DONE: Described and plotted all three tissue oxygen modeling cohorts successfully.")
