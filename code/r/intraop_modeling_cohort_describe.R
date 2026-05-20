#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-
# =============================================================================
# Description: Distributions and summaries for the three tissue oxygen cohorts
#              aligned to contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py
#
# Logic:
#   1) Load time series data from CSVs.
#   2) For each channel (rSO2_Ch1, rSO2_Ch2, rSO2_Ch3):
#      - Retain rows where ET_CO2 and ycol are non-missing,
#        and ET_CO2 is in (20, 50) and ycol is in (25, 95).
#      - Clip TEMP to (34.0, 37.5) and FiO2_new to (30.0, 100.0).
#      - Impute missing TEMP and FiO2_new: subject ffill -> subject median -> global median.
#      - Describe distributions of ET_CO2, ycol, FiO2_new, and TEMP.
#      - Generate individual and 2x2 grid plots.
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

STAMP <- format(Sys.time(), "%Y%m%d_%H%M%S")
PPT_PATH <- file.path(OUT_DIR, glue("modeling_cohort_distributions_{STAMP}.pptx"))
EXCEL_PATH <- file.path(OUT_DIR, glue("modeling_cohort_summary_stats_{STAMP}.xlsx"))

# ── 生理裁剪与筛选区间 ────────────────────────────────────────────────────────
ET_RANGE <- c(20.0, 50.0)      # >20 and <50
RSO2_RANGE <- c(25.0, 95.0)    # >25 and <95
TEMP_CLIP <- c(34.0, 37.5)     # (34.0, 37.5)
FIO2_CLIP <- c(30.0, 100.0)    # (30.0, 100.0)

CHANNELS <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
ch_map <- c(
  rSO2_Ch1 = "Left SctO\u2082",
  rSO2_Ch2 = "Right SctO\u2082",
  rSO2_Ch3 = "SftO\u2082"
)

# ── 字体配置 ───────────────────────────────────────────────────────────────
FONT_PRIMARY <- "Aptos"
FONT_FALLBACK <- "sans"
has_font <- function(family) {
  out <- tryCatch(system2("fc-list", stdout = TRUE, stderr = TRUE),
                  error = function(e) character(0))
  if (!length(out)) return(FALSE)
  any(grepl(family, out, ignore.case = TRUE))
}
BASE_FAMILY <- if (has_font(FONT_PRIMARY)) FONT_PRIMARY else FONT_FALLBACK

# ── 绘图样式与主题 ───────────────────────────────────────────────────────────
theme_premium <- function() {
  theme_classic(base_size = 11, base_family = BASE_FAMILY) +
    theme(
      plot.title   = element_text(size = 12, face = "bold", hjust = 0.5, colour = "black"),
      axis.title   = element_text(size = 10, colour = "black"),
      axis.text    = element_text(size = 9, colour = "black"),
      axis.line    = element_line(linewidth = 0.7, colour = "#616161"),
      axis.ticks   = element_line(linewidth = 0.7, colour = "#616161"),
      axis.ticks.length = unit(5, "pt"),
      plot.margin  = margin(10, 10, 10, 10, unit = "pt"),
      panel.grid.major.y = element_line(linewidth = 0.3, colour = "#e0e0e0", linetype = "dashed")
    )
}

# 填充颜色
COL_ETCO2 <- "#D9E2F3" # 浅蓝
COL_RSO2 <- c(
  rSO2_Ch1 = "#FFF2CC", # 浅黄
  rSO2_Ch2 = "#E2F0D9", # 浅绿
  rSO2_Ch3 = "#FBE5D6"  # 浅橙
)
COL_FIO2 <- "#E1D5E7"  # 浅紫
COL_TEMP <- "#F8CECC"  # 浅粉红

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

# data.table 快速读取
d_list <- list()
for (i in seq_along(files)) {
  fp <- files[i]
  # 获取列名
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
message(glue("Loaded overall raw rows: {nrow(df_all)}, patients: {uniqueN(df_all$patient_ID)}"))

# 强制转换类型
df_all[, obstime := as.numeric(obstime)]
df_all[, ET_CO2 := as.numeric(ET_CO2)]
df_all[, rSO2_Ch1 := as.numeric(rSO2_Ch1)]
df_all[, rSO2_Ch2 := as.numeric(rSO2_Ch2)]
df_all[, rSO2_Ch3 := as.numeric(rSO2_Ch3)]
df_all[, TEMP := as.numeric(TEMP)]
df_all[, FiO2_new := as.numeric(FiO2_new)]

# ── 2. Imputation 辅助函数 ──────────────────────────────────────────────────
impute_cohort_data <- function(df, ycol) {
  # (A) 筛选条件：ET_CO2 与 outcome 必须存在且在非包含区间内 (strict bounds)
  df_sub <- df[!is.na(ET_CO2) & !is.na(get(ycol))]
  df_sub <- df_sub[ET_CO2 > ET_RANGE[1] & ET_CO2 < ET_RANGE[2]]
  df_sub <- df_sub[get(ycol) > RSO2_RANGE[1] & get(ycol) < RSO2_RANGE[2]]
  
  # (B) 拷贝并做生理裁剪
  df_sub[, TEMP := ifelse(TEMP > TEMP_CLIP[1] & TEMP < TEMP_CLIP[2], TEMP, NA_real_)]
  df_sub[, FiO2_new := ifelse(FiO2_new >= FIO2_CLIP[1] & FiO2_new <= FIO2_CLIP[2], FiO2_new, NA_real_)]
  
  # (C) 排序
  setorder(df_sub, patient_ID, obstime)
  
  # (D) Imputation 序列：1) Subject locf, 2) Subject median, 3) Global median
  for (col in c("TEMP", "FiO2_new")) {
    # 1. Subject-level locf (forward fill)
    df_sub[, (col) := nafill(get(col), type = "locf"), by = patient_ID]
    
    # 2. Subject-level median
    df_sub[, sub_med := as.numeric(median(get(col), na.rm = TRUE)), by = patient_ID]
    df_sub[is.na(get(col)), (col) := sub_med]
    df_sub[, sub_med := NULL]
    
    # 3. Global median
    global_med <- as.numeric(median(df_sub[[col]], na.rm = TRUE))
    if (is.na(global_med)) {
      global_med <- if (col == "TEMP") 36.5 else 50.0
    }
    df_sub[is.na(get(col)), (col) := global_med]
  }
  
  return(df_sub)
}

# ── 3. 统计描述辅助函数 ──────────────────────────────────────────────────────
get_summary_stats <- function(dt, ycol) {
  vars <- c("ET_CO2", ycol, "FiO2_new", "TEMP")
  stats_list <- list()
  
  for (v in vars) {
    val <- dt[[v]]
    disp_v <- ifelse(v == ycol, "Tissue_Oxygen", v)
    stats_list[[length(stats_list) + 1]] <- tibble(
      Cohort = ch_map[ycol],
      Variable = disp_v,
      N_Patients = uniqueN(dt$patient_ID),
      N_Points = nrow(dt),
      Mean = mean(val),
      SD = sd(val),
      Min = min(val),
      Q25 = quantile(val, 0.25),
      Median = median(val),
      Q75 = quantile(val, 0.75),
      Max = max(val)
    )
  }
  bind_rows(stats_list)
}

# ── 4. 绘图辅助函数 ─────────────────────────────────────────────────────────
plot_histogram <- function(dt, col, xlab, fill_col, breaks_val = NULL, xlim_val = NULL) {
  val <- dt[[col]]
  val <- val[is.finite(val)]
  
  # 确定箱宽
  bw <- 1
  if (col == "TEMP") bw <- 0.1
  if (col == "FiO2_new") bw <- 5
  
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
      color = alpha("#616161", 0.2),
      fill = fill_col,
      linewidth = 0.3
    ) +
    labs(x = xlab, y = "Counts (n)") +
    scale_y_continuous(
      breaks = pretty_breaks(n = 5),
      labels = label_k,
      expand = expansion(mult = c(0, 0.05))
    ) +
    theme_premium()
  
  if (!is.null(xlim_val)) {
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
ppt <- set_ppt_slide_size(ppt, 13.33, 7.5)

wb <- createWorkbook()
addWorksheet(wb, "Summary_Statistics")

for (ycol in CHANNELS) {
  message(glue("\n[step 2] Processing cohort for {ycol} ({ch_map[ycol]})..."))
  
  # Impute
  dt_model <- impute_cohort_data(df_all, ycol)
  
  # 统计描述
  stats <- get_summary_stats(dt_model, ycol)
  summary_all[[ycol]] <- stats
  
  # 绘图
  message("Generating plots...")
  p_et   <- plot_histogram(dt_model, "ET_CO2", "End-Tidal CO\u2082 (mmHg)", COL_ETCO2, seq(20, 50, by = 5), c(20, 50))
  p_rso2 <- plot_histogram(dt_model, ycol, paste0(ch_map[ycol], " (%)"), COL_RSO2[ycol], seq(45, 95, by = 10), c(45, 95))
  p_fio2 <- plot_histogram(dt_model, "FiO2_new", "Inspired Oxygen Fraction FiO\u2082 (%)", COL_FIO2, seq(30, 100, by = 10), c(30, 100))
  p_temp <- plot_histogram(dt_model, "TEMP", "Nasopharyngeal Temperature (\u00B0C)", COL_TEMP, seq(34, 37.5, by = 0.5), c(34.0, 37.5))
  
  # 使用 patchwork 拼接 2x2 图
  p_comb <- (p_et + p_rso2) / (p_fio2 + p_temp) +
    plot_annotation(
      title = glue("Modeling Cohort Distributions: {ch_map[ycol]} (N_pts={format(nrow(dt_model), big.mark=',')}, N_subj={uniqueN(dt_model$patient_ID)})"),
      theme = theme(
        plot.title = element_text(size = 13, face = "bold", hjust = 0.5, family = BASE_FAMILY, margin = margin(b = 10))
      )
    )
  
  # 保存图为 PNG 和 PDF
  stem <- glue("modeling_cohort_dist_{ycol}")
  png_path <- file.path(OUT_DIR, paste0(stem, ".png"))
  pdf_path <- file.path(OUT_DIR, paste0(stem, ".pdf"))
  ggsave(png_path, p_comb, width = 9.0, height = 6.0, dpi = 300, bg = "white")
  ggsave(pdf_path, p_comb, width = 9.0, height = 6.0, device = cairo_pdf, bg = "white")
  message(glue("Saved combined plot: {png_path}"))
  
  # 添加到 PPTX
  ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
  ppt <- ph_with(
    ppt,
    value = glue("Modeling Cohort Variable Distributions - {ch_map[ycol]}"),
    location = ph_location(left = 0.5, top = 0.2, width = 12.33, height = 0.8)
  )
  ppt <- ph_with(
    ppt,
    value = dml(ggobj = p_comb),
    location = ph_location(left = 2.16, top = 1.2, width = 9.0, height = 6.0)
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
