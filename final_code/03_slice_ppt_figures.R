#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
  library(glue)
  library(fs)
  library(officer)
  library(rvg)
  library(xml2)
})

`%||%` <- function(a, b) if (!is.null(a)) a else b

FONT_PRIMARY <- "Aptos"
FONT_FALLBACK <- "Arial"
has_font <- function(family) {
  out <- tryCatch(system2("fc-list", stdout = TRUE, stderr = TRUE), error = function(e) character(0))
  if (!length(out)) return(FALSE)
  any(grepl(family, out, ignore.case = TRUE))
}
BASE_FAMILY <- if (has_font(FONT_PRIMARY)) FONT_PRIMARY else FONT_FALLBACK

AXIS_LABEL_FONTSIZE <- 12
TICK_FONTSIZE <- 10
SUBTITLE_FONTSIZE <- 8.5
CAPTION_FONTSIZE <- 7.5
AXIS_COLOR <- "#616161"
AXIS_LINEWIDTH <- 0.7
AXIS_TICK_LEN_PT <- 6
PLOT_MARGIN_PT <- 5.5

cm_to_in <- function(cm) cm / 2.54
FIG_W <- cm_to_in(9)
FIG_H <- cm_to_in(8)
MERGE_GAP_IN <- 0.18
MERGE_SIDE_MARGIN_IN <- 0.20
MERGE_SLIDE_H_IN <- 7.5
MERGE_SLIDE_W_IN <- max(13.333, 3 * FIG_W + 2 * MERGE_GAP_IN + 2 * MERGE_SIDE_MARGIN_IN)

theme_clean <- function() {
  theme_classic(base_size = TICK_FONTSIZE, base_family = BASE_FAMILY) +
    theme(
      panel.background = element_rect(fill = "white", colour = NA),
      plot.background = element_rect(fill = "white", colour = NA),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.title = element_text(size = AXIS_LABEL_FONTSIZE, colour = "black"),
      axis.text = element_text(size = TICK_FONTSIZE, colour = "black"),
      plot.subtitle = element_text(size = SUBTITLE_FONTSIZE, colour = "#2f2f2f"),
      plot.caption = element_text(size = CAPTION_FONTSIZE, colour = "#5a5a5a", hjust = 0),
      axis.line = element_line(linewidth = AXIS_LINEWIDTH, colour = AXIS_COLOR),
      axis.ticks = element_line(linewidth = AXIS_LINEWIDTH, colour = AXIS_COLOR),
      axis.ticks.length = unit(AXIS_TICK_LEN_PT, "pt"),
      plot.margin = margin(PLOT_MARGIN_PT, PLOT_MARGIN_PT, PLOT_MARGIN_PT, PLOT_MARGIN_PT, unit = "pt")
    )
}

XVAR_ORDER_DEFAULT <- c("ET_CO2", "TEMP", "FiO2_new", "MAP", "CI", "SV", "HR", "RRtotal", "TVinsp", "Pmean", "Perf")
Y_ORDER_ALL <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
parse_y_order <- function(raw, valid) {
  ys <- trimws(strsplit(raw, ",")[[1]])
  ys <- ys[nzchar(ys)]
  ys <- ys[ys %in% valid]
  ys <- unique(ys)
  if (!length(ys)) valid else ys
}
Y_ORDER <- parse_y_order(Sys.getenv("INTRA5_YCOLS", paste(Y_ORDER_ALL, collapse = ",")), Y_ORDER_ALL)
parse_x_order <- function(raw, valid, desired) {
  valid <- unique(as.character(valid))
  if (!length(valid)) return(character(0))
  xs <- trimws(strsplit(raw, ",")[[1]])
  xs <- xs[nzchar(xs)]
  xs <- xs[xs %in% valid]
  xs <- unique(xs)
  if (length(xs)) return(xs)
  keep <- desired[desired %in% valid]
  if (length(keep)) return(keep)
  valid
}
XVAR_ORDER <- XVAR_ORDER_DEFAULT

PRETTY_LABELS <- c(
  "ET_CO2" = "End-Tidal CO₂ (mmHg)",
  "TEMP" = "Temperature (°C)",
  "FiO2_new" = "FiO₂ (%)",
  "MAP" = "Mean Arterial Pressure (mmHg)",
  "CI" = "Cardiac Index (L/min/m²)",
  "SV" = "Stroke Volume (mL)",
  "HR" = "Heart Rate (bpm)",
  "RRtotal" = "Respiratory Rate (/min)",
  "TVinsp" = "Inspiratory Tidal Volume (mL)",
  "Pmean" = "Mean Airway Pressure (cmH2O)",
  "Perf" = "Perfusion Index",
  "rSO2_Ch1" = "Left SctO₂ (%)",
  "rSO2_Ch2" = "Right SctO₂ (%)",
  "rSO2_Ch3" = "SftO₂ (%)"
)
pretty_lab <- function(x) {
  x <- as.character(x)
  vapply(x, function(xx) PRETTY_LABELS[[xx]] %||% xx, FUN.VALUE = character(1))
}

# Use plotmath labels in figures so subscripts/units render reliably in PPT.
AXIS_LABEL_EXPR <- list(
  "ET_CO2" = quote("End-Tidal" ~ CO[2] ~ "(mmHg)"),
  "TEMP" = quote("Temperature" ~ "(" * degree * "C)"),
  "FiO2_new" = quote(FiO[2] ~ "(%)"),
  "MAP" = quote("Mean Arterial Pressure" ~ "(mmHg)"),
  "CI" = quote("Cardiac Index" ~ "(L/min/m"^2 * ")"),
  "SV" = quote("Stroke Volume" ~ "(mL)"),
  "HR" = quote("Heart Rate" ~ "(bpm)"),
  "RRtotal" = quote("Respiratory Rate" ~ "(/min)"),
  "TVinsp" = quote("Inspiratory Tidal Volume" ~ "(mL)"),
  "Pmean" = quote("Mean Airway Pressure" ~ "(cmH"[2] * "O)"),
  "Perf" = quote("Perfusion Index"),
  "rSO2_Ch1" = quote("Left" ~ SctO[2] ~ "(%)"),
  "rSO2_Ch2" = quote("Right" ~ SctO[2] ~ "(%)"),
  "rSO2_Ch3" = quote(SftO[2] ~ "(%)")
)
pretty_lab_axis <- function(x) {
  key <- as.character(x)[1]
  AXIS_LABEL_EXPR[[key]] %||% (PRETTY_LABELS[[key]] %||% key)
}

PLOT_MODE <- "slice_median"
PLOT_MODE_TAG <- "slice"
PLOT_MODE_TITLE <- ""

Y_AXIS_PRESET <- Sys.getenv("INTRA5_Y_AXIS_PRESET", "66_80_2")
get_slice_y_axis <- function(preset) {
  if (identical(preset, "55_85_5")) return(list(lims = c(55, 85), breaks = seq(55, 85, 5)))
  if (identical(preset, "66_80_2")) return(list(lims = c(66, 81), breaks = seq(66, 80, 2)))
  v <- suppressWarnings(as.numeric(strsplit(preset, "_")[[1]]))
  if (length(v) == 3 && all(is.finite(v)) && v[2] > v[1] && v[3] > 0) {
    return(list(lims = c(v[1], v[2]), breaks = seq(v[1], v[2], by = v[3])))
  }
  list(lims = c(66, 81), breaks = seq(66, 80, 2))
}
Y_AXIS_CFG <- get_slice_y_axis(Y_AXIS_PRESET)
SLICE_Y_LIMS <- Y_AXIS_CFG$lims
SLICE_Y_BREAKS <- Y_AXIS_CFG$breaks
X_LEFT_PAD_FRAC <- suppressWarnings(as.numeric(Sys.getenv("INTRA5_X_LEFT_PAD_FRAC", "0.14")))
if (!is.finite(X_LEFT_PAD_FRAC) || X_LEFT_PAD_FRAC < 0) X_LEFT_PAD_FRAC <- 0.14
X_LEFT_PAD_FRAC <- min(X_LEFT_PAD_FRAC, 0.40)

ETCO2_X_MIN <- suppressWarnings(as.numeric(Sys.getenv("INTRA5_ETCO2_X_MIN", "20")))
ETCO2_X_MAX <- suppressWarnings(as.numeric(Sys.getenv("INTRA5_ETCO2_X_MAX", "50")))
ETCO2_X_STEP <- suppressWarnings(as.numeric(Sys.getenv("INTRA5_ETCO2_X_STEP", "5")))
if (!is.finite(ETCO2_X_MIN)) ETCO2_X_MIN <- 20
if (!is.finite(ETCO2_X_MAX) || ETCO2_X_MAX <= ETCO2_X_MIN) ETCO2_X_MAX <- 50
if (!is.finite(ETCO2_X_STEP) || ETCO2_X_STEP <= 0) ETCO2_X_STEP <- 5

X_AXIS_RULES <- list(
  "MAP" = list(lims = c(40, 120), breaks = seq(40, 120, 20)),
  "CI" = list(lims = c(0.5, 5.5), breaks = seq(0.5, 5.5, 1)),
  "FiO2_new" = list(lims = c(30, 100), breaks = seq(30, 100, 10)),
  "TEMP" = list(lims = c(34, 37.5), breaks = seq(34, 37.5, 0.5)),
  "ET_CO2" = list(lims = c(ETCO2_X_MIN, ETCO2_X_MAX), breaks = seq(ETCO2_X_MIN, ETCO2_X_MAX, ETCO2_X_STEP)),
  "SV" = list(lims = c(30, 140), breaks = seq(40, 140, 20)),
  "HR" = list(lims = c(40, 100), breaks = seq(40, 100, 10)),
  "RRtotal" = list(lims = c(8, 20), breaks = seq(8, 20, 2)),
  "TVinsp" = list(lims = c(180, 600), breaks = seq(200, 600, 100)),
  "Pmean" = list(lims = c(3, 12), breaks = seq(3, 12, 1)),
  "Perf" = list(lims = c(0.1, 7), breaks = c(0.1, 0.5, 1, 2, 3, 5, 7))
)
get_x_axis_spec <- function(xvar) X_AXIS_RULES[[xvar]] %||% list(lims = NULL, breaks = waiver())
PRIMARY_PHYSIO_LIMITS <- list(
  "ET_CO2" = c(20, 60),
  "TEMP" = c(34, 39.5),
  "FiO2_new" = c(30, 100),
  "MAP" = c(20, 160),
  "CI" = c(0.5, 8),
  "SV" = c(20, 180),
  "HR" = c(30, 180),
  "RRtotal" = c(4, 40),
  "TVinsp" = c(100, 1200),
  "Pmean" = c(0, 25),
  "Perf" = c(0.02, 20)
)
Y_PHYSIO_LIMITS <- c(25, 95)
MARG_DENSITY_MAX_N <- 400000
MARG_BAND_RATIO <- 0.12
MARG_BINS_X <- 24
MARG_BINS_Y <- 24
MARG_Y_BIN_WIDTH_MIN <- 0.5
MARG_Y_BIN_WIDTH_MAX <- 2.0
MARG_Y_BIN_WIDTH_FIXED <- suppressWarnings(as.numeric(Sys.getenv("INTRA5_Y_HIST_BIN_WIDTH", "0")))
FIO2_EXTRA_SMOOTH <- tolower(Sys.getenv("INTRA5_FIO2_EXTRA_SMOOTH", "1")) %in% c("1", "true", "t", "yes", "y")
FIO2_SMOOTH_SP <- suppressWarnings(as.numeric(Sys.getenv("INTRA5_FIO2_SMOOTH_SP", "1.25")))
if (!is.finite(FIO2_SMOOTH_SP)) FIO2_SMOOTH_SP <- 1.25
FIO2_SMOOTH_SP <- max(0.2, min(2.0, FIO2_SMOOTH_SP))
EXPORT_PNG <- tolower(Sys.getenv("INTRA5_EXPORT_PNG", "0")) %in% c("1", "true", "t", "yes", "y")
SKIP_MARGINAL <- tolower(Sys.getenv("INTRA5_SKIP_MARGINAL", "0")) %in% c("1", "true", "t", "yes", "y")
ADD_CLINICAL_COMPARE <- tolower(Sys.getenv("INTRA5_ADD_CLINICAL_COMPARE", "1")) %in% c("1", "true", "t", "yes", "y")
CLINICAL_Q_WINDOW <- c(0.05, 0.95)
CLINICAL_N_SEGMENTS <- suppressWarnings(as.integer(Sys.getenv("INTRA5_CLINICAL_N_SEGMENTS", "20")))
if (!is.finite(CLINICAL_N_SEGMENTS) || CLINICAL_N_SEGMENTS < 2) CLINICAL_N_SEGMENTS <- 20L
CLINICAL_STEPS <- c(
  "ET_CO2" = 5,
  "FiO2_new" = 5,
  "TEMP" = 0.5,
  "MAP" = 5,
  "CI" = 0.05
)
CLINICAL_STEP_LABELS <- c(
  "ET_CO2" = "CO2 +5 mmHg",
  "FiO2_new" = "FiO2 +5%",
  "TEMP" = "TEMP +0.5 C",
  "MAP" = "MAP +5 mmHg",
  "CI" = "CI +0.05"
)
CLINICAL_STEP_COLORS <- c(
  "ET_CO2" = "#C55A11",
  "TEMP" = "#2E75B6",
  "FiO2_new" = "#BF9000",
  "MAP" = "#C55A11",
  "CI" = "#2E75B6"
)
CLINICAL_STEP_FILL_COLORS <- c(
  "ET_CO2" = "#FBE5D6",
  "TEMP" = "#DEEBF7",
  "FiO2_new" = "#FFF2CC",
  "MAP" = "#FBE5D6",
  "CI" = "#DEEBF7"
)
XVAR_TICK_LABELS <- c(
  "ET_CO2" = "EtCO2",
  "TEMP" = "TEMP",
  "FiO2_new" = "FiO2",
  "MAP" = "MAP",
  "CI" = "CI"
)
COMPARE_ERRBAR_LWD <- 0.5
COMPARE_ERRBAR_CAP <- 0.20

PROJECT_ROOT <- "/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025"
OUT_FIG_BASE <- file.path(PROJECT_ROOT, "fig_output", "R_intraop5_slice_only_ppt_v2_4_1_2026_multismooth")
dir_create(OUT_FIG_BASE, recurse = TRUE)

args <- commandArgs(trailingOnly = TRUE)
RESULT_DIR <- if (length(args) >= 1 && nzchar(args[1])) args[1] else ""
if (!nzchar(RESULT_DIR)) stop("Need RESULT_DIR as first argument")
if (!dir_exists(RESULT_DIR)) stop("RESULT_DIR not found: ", RESULT_DIR)

YCOL_TAG <- paste(gsub("^rSO2_", "", Y_ORDER), collapse = "_")
ETCO2_AXIS_TAG <- paste0(
  "xco2_",
  gsub("\\.", "p", format(ETCO2_X_MIN, trim = TRUE, scientific = FALSE)),
  "_",
  gsub("\\.", "p", format(ETCO2_X_MAX, trim = TRUE, scientific = FALSE)),
  "_",
  gsub("\\.", "p", format(ETCO2_X_STEP, trim = TRUE, scientific = FALSE))
)
OUTDIR_BASE <- file.path(
  OUT_FIG_BASE,
  paste0("from_", basename(RESULT_DIR), "_", PLOT_MODE_TAG, "_y", gsub("[^0-9_]", "", Y_AXIS_PRESET), "_yc", YCOL_TAG, "_", ETCO2_AXIS_TAG)
)
OUTDIR <- OUTDIR_BASE
if (dir_exists(OUTDIR_BASE) && length(dir_ls(OUTDIR_BASE, recurse = TRUE, type = "file")) > 0) {
  OUTDIR <- paste0(OUTDIR_BASE, "_v", format(Sys.time(), "%Y%m%d_%H%M%S"))
}
dir_create(OUTDIR, recurse = TRUE)

message("[RESULT_DIR] ", RESULT_DIR)
message("[OUTDIR] ", OUTDIR)
message("[PLOT_MODE] ", PLOT_MODE)
message("[EXPORT_PNG] ", EXPORT_PNG)
message("[SKIP_MARGINAL] ", SKIP_MARGINAL)
message("[ADD_CLINICAL_COMPARE] ", ADD_CLINICAL_COMPARE)

curve_files <- dir_ls(RESULT_DIR, recurse = TRUE, type = "file", regexp = "_curve_boot\\.csv$")
if (!length(curve_files)) stop("No *_curve_boot.csv found in RESULT_DIR")

curve_df <- bind_rows(lapply(curve_files, function(fp) {
  d <- suppressMessages(read_csv(fp, show_col_types = FALSE))
  d$source_csv <- fp
  d
}))
if (!nrow(curve_df)) stop("curve_df is empty")

if ("plot_mode" %in% names(curve_df)) {
  curve_df <- curve_df %>% filter(tolower(plot_mode) == PLOT_MODE)
} else {
  curve_df <- curve_df %>% filter(grepl(PLOT_MODE, source_csv, fixed = TRUE))
}
if (!("subgroup" %in% names(curve_df))) curve_df$subgroup <- "All"
curve_df <- curve_df %>%
  filter(as.character(ycol) %in% Y_ORDER) %>%
  mutate(
    xvar = as.character(.data$xvar),
    ycol = as.character(.data$ycol),
    subgroup = as.character(.data$subgroup),
    x = as.numeric(.data$x),
    pred_mean = as.numeric(.data$pred_mean),
    `pred_lo_2.5` = as.numeric(.data[["pred_lo_2.5"]]),
    `pred_hi_97.5` = as.numeric(.data[["pred_hi_97.5"]])
  )
XVAR_ORDER <- parse_x_order(
  Sys.getenv("INTRA5_XVARS", ""),
  valid = unique(curve_df$xvar),
  desired = XVAR_ORDER_DEFAULT
)
curve_df <- curve_df %>% filter(.data$xvar %in% XVAR_ORDER)
if (!nrow(curve_df)) stop("No rows left after filtering selected plot_mode / channels")
curve_df <- curve_df %>%
  mutate(
    subgroup = ifelse(is.na(.data$subgroup) | !nzchar(trimws(.data$subgroup)), "All", trimws(.data$subgroup))
  )
SUBGROUP_VALUES <- unique(curve_df$subgroup)
if (!length(SUBGROUP_VALUES)) SUBGROUP_VALUES <- "All"
message("[SUBGROUPS] ", paste(SUBGROUP_VALUES, collapse = ", "))

load_model_input_quantiles <- function(result_dir) {
  fp <- Sys.getenv("INTRA5_MODEL_INPUT_QUANTILES", file.path(result_dir, "model_input_quantiles_n10000_ref_sample.csv"))
  if (!nzchar(fp) || !file_exists(fp)) {
    warning("[clinical compare] model input quantile CSV not found; falling back to curve-grid 5%-95% ranges: ", fp)
    return(tibble(
      ycol = character(0),
      xvar = character(0),
      q05 = numeric(0),
      q95 = numeric(0)
    ))
  }
  qd <- suppressMessages(read_csv(fp, show_col_types = FALSE))
  req <- c("ycol", "xvar", "q05", "q95")
  miss <- setdiff(req, names(qd))
  if (length(miss)) {
    stop("[clinical compare] quantile CSV missing columns: ", paste(miss, collapse = ", "))
  }
  qd %>%
    transmute(
      ycol = as.character(.data$ycol),
      xvar = as.character(.data$xvar),
      q05 = as.numeric(.data$q05),
      q95 = as.numeric(.data$q95)
    ) %>%
    filter(
      .data$ycol %in% Y_ORDER,
      .data$xvar %in% names(CLINICAL_STEPS),
      is.finite(.data$q05),
      is.finite(.data$q95),
      .data$q95 > .data$q05
    )
}
model_input_quantiles <- load_model_input_quantiles(RESULT_DIR)

find_unified_cache <- function(root_dir) {
  cache_dir <- file.path(root_dir, "result", "raw_cache")
  cands_unified <- dir_ls(cache_dir, type = "file", recurse = FALSE, regexp = "unified5_selected_.*\\.parquet$")
  cands <- cands_unified
  if (!length(cands)) {
    cands <- dir_ls(cache_dir, type = "file", recurse = FALSE, regexp = "intra5_selected_.*\\.parquet$")
  }
  if (!length(cands)) return(character(0))
  cands[order(file_info(cands)$modification_time, decreasing = TRUE)]
}

downsample_for_density <- function(v, max_n = MARG_DENSITY_MAX_N) {
  v <- as.numeric(v)
  v <- v[is.finite(v)]
  if (length(v) > max_n) {
    set.seed(85)
    v <- sample(v, size = max_n, replace = FALSE)
  }
  v
}

make_hist_df <- function(v, from, to, bins = 24L, break_by = NULL) {
  vv <- downsample_for_density(v)
  if (length(vv) < 50 || !is.finite(from) || !is.finite(to) || to <= from) {
    return(data.frame(low = numeric(0), high = numeric(0), count = numeric(0)))
  }
  vv <- vv[vv >= from & vv <= to]
  if (length(vv) < 50) {
    return(data.frame(low = numeric(0), high = numeric(0), count = numeric(0)))
  }
  if (!is.null(break_by) && is.finite(break_by) && break_by > 0) {
    br <- seq(from, to, by = break_by)
    if (tail(br, 1) < to) br <- c(br, to)
    if (length(br) < 2) br <- c(from, to)
  } else {
    br <- seq(from, to, length.out = bins + 1L)
  }
  h <- hist(vv, breaks = br, include.lowest = TRUE, right = FALSE, plot = FALSE)
  data.frame(low = h$breaks[-length(h$breaks)], high = h$breaks[-1], count = as.numeric(h$counts))
}

choose_adaptive_bin_width <- function(v, from, to, width_min = 0.5, width_max = 2.0, target_nonzero = 0.75) {
  vv <- downsample_for_density(v)
  vv <- vv[vv >= from & vv <= to]
  if (length(vv) < 50 || !is.finite(from) || !is.finite(to) || to <= from) return(width_min)

  int_ratio <- mean(abs(vv - round(vv)) < 1e-8)
  half_ratio <- mean(abs(vv * 2 - round(vv * 2)) < 1e-8)
  if (is.finite(int_ratio) && int_ratio >= 0.90) return(1.0)
  if (is.finite(half_ratio) && half_ratio >= 0.90) return(0.5)

  fd <- 2 * IQR(vv, na.rm = TRUE) / (length(vv)^(1 / 3))
  if (!is.finite(fd) || fd <= 0) fd <- (to - from) / 24

  width_min <- max(0.1, width_min)
  width_max <- max(width_min, width_max)
  cand <- sort(unique(c(fd, seq(width_min, width_max, by = 0.25), width_max)))

  for (w in cand) {
    br <- seq(from, to, by = w)
    if (tail(br, 1) < to) br <- c(br, to)
    if (length(br) < 2) next
    h <- hist(vv, breaks = br, include.lowest = TRUE, right = FALSE, plot = FALSE)
    nz_ratio <- mean(h$counts > 0)
    if (is.finite(nz_ratio) && (nz_ratio >= target_nonzero || length(h$counts) <= 18)) {
      return(w)
    }
  }
  tail(cand, 1)
}

build_marginal_density_map <- function(df_raw) {
  need <- unique(c(XVAR_ORDER, Y_ORDER))
  if (!all(need %in% names(df_raw))) stop("Missing required cols in raw cache for marginal density.")

  for (c in need) df_raw[[c]] <- suppressWarnings(as.numeric(df_raw[[c]]))

  mask_base <- complete.cases(df_raw[, need, drop = FALSE])
  for (xv in XVAR_ORDER) {
    lim <- PRIMARY_PHYSIO_LIMITS[[xv]]
    mask_base <- mask_base & df_raw[[xv]] >= lim[1] & df_raw[[xv]] <= lim[2]
  }

  out <- list()
  for (yy in Y_ORDER) {
    yv <- df_raw[[yy]]
    mask_y <- mask_base & yv >= Y_PHYSIO_LIMITS[1] & yv <= Y_PHYSIO_LIMITS[2]
    y_tmp <- yv[mask_y]
    if (length(y_tmp) < 200) {
      out[[yy]] <- list(
        x_hist = list(),
        y_hist = data.frame(low = numeric(0), high = numeric(0), count = numeric(0)),
        n = 0L
      )
      next
    }
    ql <- as.numeric(stats::quantile(y_tmp, probs = 0.005, na.rm = TRUE))
    qh <- as.numeric(stats::quantile(y_tmp, probs = 0.995, na.rm = TRUE))
    mask_y <- mask_y & yv >= ql & yv <= qh
    y_use <- yv[mask_y]

    x_hist <- list()
    for (xv in XVAR_ORDER) {
      spx <- get_x_axis_spec(xv)
      x_use <- df_raw[[xv]][mask_y]
      x_hist[[xv]] <- make_hist_df(x_use, from = spx$lims[1], to = spx$lims[2], bins = MARG_BINS_X)
    }
    if (is.finite(MARG_Y_BIN_WIDTH_FIXED) && MARG_Y_BIN_WIDTH_FIXED > 0) {
      y_break_by <- MARG_Y_BIN_WIDTH_FIXED
    } else {
      y_break_by <- choose_adaptive_bin_width(
        y_use,
        from = SLICE_Y_LIMS[1],
        to = SLICE_Y_LIMS[2],
        width_min = MARG_Y_BIN_WIDTH_MIN,
        width_max = MARG_Y_BIN_WIDTH_MAX
      )
    }
    y_hist <- make_hist_df(
      y_use,
      from = SLICE_Y_LIMS[1],
      to = SLICE_Y_LIMS[2],
      bins = MARG_BINS_Y,
      break_by = y_break_by
    )
    out[[yy]] <- list(x_hist = x_hist, y_hist = y_hist, n = as.integer(length(y_use)))
  }
  out
}

read_parquet_safe <- function(fp, cols) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    warning("[marginal] package `arrow` not available; skip edge density.")
    return(NULL)
  }
  arrow::read_parquet(fp, col_select = any_of(cols))
}

if (isTRUE(SKIP_MARGINAL)) {
  message("[marginal] INTRA5_SKIP_MARGINAL=1; skip edge density.")
  marginal_density_map <- list()
} else {
raw_cache_candidates <- find_unified_cache(PROJECT_ROOT)
if (length(raw_cache_candidates)) {
  best_raw <- NULL
  best_cache_fp <- NA_character_
  best_score <- -1
  for (cand in raw_cache_candidates) {
    message("[marginal] trying cache: ", cand)
    raw_try <- tryCatch(
      read_parquet_safe(cand, unique(c(XVAR_ORDER, Y_ORDER))),
      error = function(e) {
        warning("[marginal] failed to read cache ", cand, ": ", conditionMessage(e))
        NULL
      }
    )
    if (!is.null(raw_try)) {
      score_x <- length(intersect(names(raw_try), XVAR_ORDER))
      score_y <- length(intersect(names(raw_try), Y_ORDER))
      score <- score_y * 100 + score_x
      if (score > best_score) {
        best_raw <- raw_try
        best_cache_fp <- cand
        best_score <- score
      }
    }
  }
  if (!is.null(best_raw)) {
    message("[marginal] selected cache: ", best_cache_fp, " (score=", best_score, ")")
    marginal_density_map <- build_marginal_density_map(best_raw)
    rm(best_raw)
    gc()
  } else {
    warning("[marginal] no readable cache with required columns; skip edge density.")
    marginal_density_map <- list()
  }
} else {
  warning("[marginal] no unified raw cache found; skip edge density.")
  marginal_density_map <- list()
}
}

save_png <- function(p, path, w = FIG_W, h = FIG_H, dpi = 320) {
  if (!isTRUE(EXPORT_PNG)) return(NA_character_)
  dir_create(path_dir(path), recurse = TRUE)
  ggsave(path, p, width = w, height = h, dpi = dpi, bg = "white")
  path
}

add_blank <- function(ppt) add_slide(ppt, layout = "Blank", master = layout_summary(ppt)$master[1])

set_ppt_slide_size <- function(ppt, width_in, height_in) {
  doc <- ppt$presentation$get()
  ns <- xml_ns(doc)
  sld_sz <- xml_find_first(doc, "//p:sldSz", ns = ns)
  if (!inherits(sld_sz, "xml_missing")) {
    xml_set_attr(sld_sz, "cx", as.character(round(width_in * 914400)))
    xml_set_attr(sld_sz, "cy", as.character(round(height_in * 914400)))
  }
  ppt
}

ppt_add_one <- function(ppt, p, width = FIG_W, height = FIG_H, top = 0.8) {
  sz <- officer::slide_size(ppt)
  left <- (sz$width - width) / 2
  ph_with(ppt, dml(ggobj = p), location = ph_location(left = left, top = top, width = width, height = height))
}

ppt_add_plots_in_row <- function(ppt, ps, top = 0.75, gap = MERGE_GAP_IN) {
  n <- length(ps)
  if (n < 1) return(ppt)
  sz <- officer::slide_size(ppt)
  total_w <- n * FIG_W + (n - 1) * gap
  left_margin <- max(0.1, (sz$width - total_w) / 2)
  for (i in seq_len(n)) {
    left <- left_margin + (i - 1) * (FIG_W + gap)
    ppt <- ph_with(ppt, dml(ggobj = ps[[i]]), location = ph_location(left = left, top = top, width = FIG_W, height = FIG_H))
  }
  ppt
}

ppt_add_full_plot <- function(ppt, p, margin = 0.45, top = 0.55) {
  sz <- officer::slide_size(ppt)
  ph_with(
    ppt,
    dml(ggobj = p),
    location = ph_location(
      left = margin,
      top = top,
      width = sz$width - 2 * margin,
      height = sz$height - top - margin
    )
  )
}

add_edge_marginal_layers <- function(p, x_hist, y_hist, x_data_lims, x_plot_lims, y_lims) {
  x_band <- diff(y_lims) * MARG_BAND_RATIO
  y_band <- max(x_data_lims[1] - x_plot_lims[1], diff(x_data_lims) * 0.06)

  if (nrow(x_hist) > 0 && max(x_hist$count, na.rm = TRUE) > 0) {
    xh <- x_hist %>%
      mutate(
        ymin = y_lims[1],
        ymax = y_lims[1] + (count / max(count, na.rm = TRUE)) * x_band
      )
    p <- p +
      geom_rect(
        data = xh,
        aes(xmin = low, xmax = high, ymin = ymin, ymax = ymax),
        inherit.aes = FALSE, fill = "#B2DF8A", alpha = 0.34, colour = "#AFAFAF", linewidth = 0.20
      )
  }
  if (nrow(y_hist) > 0 && max(y_hist$count, na.rm = TRUE) > 0) {
    yh <- y_hist %>%
      mutate(
        xmin = x_plot_lims[1],
        xmax = x_plot_lims[1] + (count / max(count, na.rm = TRUE)) * y_band
      )
    p <- p +
      geom_rect(
        data = yh,
        aes(xmin = xmin, xmax = xmax, ymin = low, ymax = high),
        inherit.aes = FALSE, fill = "#FDB863", alpha = 0.30, colour = "#AFAFAF", linewidth = 0.20
      )
  }
  p
}

fmt_num <- function(x, digits = 2) {
  if (!is.finite(x)) return("NA")
  format(round(x, digits = digits), trim = TRUE, nsmall = 0, scientific = FALSE)
}

hist_range_peak <- function(h) {
  if (is.null(h) || !nrow(h) || all(!is.finite(h$count)) || max(h$count, na.rm = TRUE) <= 0) {
    return(list(has = FALSE, range = "NA", peak = "NA"))
  }
  h2 <- h %>% filter(is.finite(.data$count), .data$count > 0)
  if (!nrow(h2)) return(list(has = FALSE, range = "NA", peak = "NA"))
  low <- min(h2$low, na.rm = TRUE)
  high <- max(h2$high, na.rm = TRUE)
  peak_idx <- which.max(h2$count)[1]
  peak_mid <- (h2$low[peak_idx] + h2$high[peak_idx]) / 2
  list(
    has = TRUE,
    range = glue("{fmt_num(low, 2)}-{fmt_num(high, 2)}"),
    peak = fmt_num(peak_mid, 2)
  )
}

build_hist_descriptions <- function(x_hist, y_hist, xvar, ycol) {
  sx <- hist_range_peak(x_hist)
  sy <- hist_range_peak(y_hist)
  subtitle <- ""
  caption <- ""
  list(
    subtitle = subtitle,
    caption = caption,
    x_hist_available = sx$has,
    y_hist_available = sy$has,
    x_hist_range = sx$range,
    y_hist_range = sy$range,
    x_hist_peak = sx$peak,
    y_hist_peak = sy$peak
  )
}

compare_y_label <- function(ycol) {
  labs <- c(
    "rSO2_Ch1" = "Left SctO2",
    "rSO2_Ch2" = "Right SctO2",
    "rSO2_Ch3" = "SftO2"
  )
  labs[[as.character(ycol)[1]]] %||% as.character(ycol)[1]
}

get_clinical_window <- function(ycol, xvar, d, input_quantiles) {
  qrow <- input_quantiles %>%
    filter(.data$ycol == !!ycol, .data$xvar == !!xvar) %>%
    slice_head(n = 1)
  if (nrow(qrow)) {
    return(list(
      lo = qrow$q05[[1]],
      hi = qrow$q95[[1]],
      source = "model_input_q05_q95"
    ))
  }
  q <- as.numeric(stats::quantile(d$x, probs = CLINICAL_Q_WINDOW, na.rm = TRUE, names = FALSE))
  list(lo = q[[1]], hi = q[[2]], source = "curve_grid_q05_q95")
}

build_clinical_compare_data <- function(curves, input_quantiles = tibble()) {
  dat <- curves %>%
    filter(.data$xvar %in% names(CLINICAL_STEPS), .data$ycol %in% Y_ORDER) %>%
    mutate(
      subgroup = as.character(.data$subgroup),
      ycol = as.character(.data$ycol),
      xvar = as.character(.data$xvar),
      x = as.numeric(.data$x),
      pred_mean = as.numeric(.data$pred_mean)
    ) %>%
    filter(is.finite(.data$x), is.finite(.data$pred_mean))

  if (!nrow(dat)) {
    return(list(summary = tibble(), segments = tibble()))
  }

  split_keys <- interaction(dat$subgroup, dat$ycol, dat$xvar, drop = TRUE, sep = "\r")
  pieces <- split(dat, split_keys)
  segment_rows <- list()
  summary_rows <- list()

  for (d0 in pieces) {
    subgroup_vals <- unique(as.character(d0$subgroup))
    ycol_vals <- unique(as.character(d0$ycol))
    xvar_vals <- unique(as.character(d0$xvar))
    if (length(subgroup_vals) != 1L || length(ycol_vals) != 1L || length(xvar_vals) != 1L) next
    subgroup <- subgroup_vals[[1]]
    ycol <- ycol_vals[[1]]
    xvar <- xvar_vals[[1]]
    clinical_step_value <- unname(CLINICAL_STEPS[[xvar]])
    clinical_step_label <- unname(CLINICAL_STEP_LABELS[[xvar]])
    if (!is.finite(clinical_step_value) || length(clinical_step_value) != 1L) next
    d <- d0 %>%
      group_by(.data$x) %>%
      summarise(pred_mean = mean(.data$pred_mean, na.rm = TRUE), .groups = "drop") %>%
      arrange(.data$x)
    if (nrow(d) < 2) next

    win <- get_clinical_window(ycol, xvar, d, input_quantiles)
    lo <- as.numeric(win$lo)
    hi <- as.numeric(win$hi)
    if (!is.finite(lo) || !is.finite(hi) || hi <= lo) next

    edges <- seq(lo, hi, length.out = CLINICAL_N_SEGMENTS + 1L)
    x0 <- head(edges, -1)
    x1 <- tail(edges, -1)
    y0 <- approx(d$x, d$pred_mean, xout = x0, ties = mean, rule = 1)$y
    y1 <- approx(d$x, d$pred_mean, xout = x1, ties = mean, rule = 1)$y
    effect <- (y1 - y0) / (x1 - x0) * clinical_step_value
    ok <- is.finite(effect)
    if (!any(ok)) next

    seg <- tibble(
      subgroup = subgroup,
      ycol = ycol,
      xvar = xvar,
      segment = seq_along(x0),
      x_start = x0,
      x_end = x1,
      pred_start = y0,
      pred_end = y1,
      clinical_step = clinical_step_value,
      clinical_step_label = clinical_step_label,
      signed_effect = effect,
      window_lo = lo,
      window_hi = hi,
      window_source = win$source
    ) %>%
      filter(is.finite(.data$signed_effect))
    segment_rows[[length(segment_rows) + 1L]] <- seg

    qs <- as.numeric(stats::quantile(seg$signed_effect, probs = c(0.25, 0.50, 0.75), na.rm = TRUE, names = FALSE))
    summary_rows[[length(summary_rows) + 1L]] <- tibble(
      subgroup = subgroup,
      ycol = ycol,
      xvar = xvar,
      clinical_step = clinical_step_value,
      clinical_step_label = clinical_step_label,
      signed_effect_q25 = qs[[1]],
      signed_effect_median = qs[[2]],
      signed_effect_q75 = qs[[3]],
      n_segments = nrow(seg),
      window_lo = lo,
      window_hi = hi,
      window_source = win$source
    )
  }

  list(
    summary = if (length(summary_rows)) bind_rows(summary_rows) else tibble(),
    segments = if (length(segment_rows)) bind_rows(segment_rows) else tibble()
  )
}

build_compare_plot_data <- function(summary_df, segment_df) {
  if (!nrow(summary_df)) return(tibble())
  signed <- summary_df %>%
    transmute(
      subgroup = .data$subgroup,
      ycol = .data$ycol,
      xvar = .data$xvar,
      signed_est = .data$signed_effect_median,
      signed_lo = .data$signed_effect_q25,
      signed_hi = .data$signed_effect_q75,
      window_lo = .data$window_lo,
      window_hi = .data$window_hi,
      window_source = .data$window_source,
      clinical_step = .data$clinical_step,
      clinical_step_label = .data$clinical_step_label,
      n_segments = .data$n_segments
    )
  abs_df <- if (nrow(segment_df)) {
    segment_df %>%
      mutate(abs_effect = abs(.data$signed_effect)) %>%
      group_by(.data$subgroup, .data$ycol, .data$xvar) %>%
      summarise(
        abs_lo = as.numeric(stats::quantile(.data$abs_effect, 0.25, na.rm = TRUE, names = FALSE)),
        abs_est = as.numeric(stats::quantile(.data$abs_effect, 0.50, na.rm = TRUE, names = FALSE)),
        abs_hi = as.numeric(stats::quantile(.data$abs_effect, 0.75, na.rm = TRUE, names = FALSE)),
        .groups = "drop"
      )
  } else {
    signed %>%
      transmute(
        subgroup = .data$subgroup,
        ycol = .data$ycol,
        xvar = .data$xvar,
        abs_lo = abs(.data$signed_lo),
        abs_est = abs(.data$signed_est),
        abs_hi = abs(.data$signed_hi)
      )
  }
  signed %>%
    left_join(abs_df, by = c("subgroup", "ycol", "xvar")) %>%
    mutate(
      xvar = factor(as.character(.data$xvar), levels = XVAR_ORDER[XVAR_ORDER %in% names(CLINICAL_STEPS)])
    )
}

get_compare_y_spec <- function(db, metric = c("abs", "signed")) {
  metric <- match.arg(metric)
  if (!nrow(db)) return(list(lims = c(0, 1), breaks = pretty(c(0, 1), n = 6)))
  if (metric == "abs") {
    vals <- c(0, db$abs_lo, db$abs_hi)
    vals <- vals[is.finite(vals)]
    if (!length(vals)) vals <- c(0, 1)
    lo <- min(0, min(vals, na.rm = TRUE))
    hi <- max(vals, na.rm = TRUE)
    span <- max(hi - lo, 1e-8)
    pad <- max(0.08 * span, 0.05)
    br <- pretty(c(lo, hi + pad), n = 6)
    br <- br[br >= lo - 1e-8]
    lims <- c(lo, max(br, hi + pad, na.rm = TRUE))
  } else {
    vals <- c(0, db$signed_lo, db$signed_hi)
    vals <- vals[is.finite(vals)]
    if (!length(vals)) vals <- c(-1, 1)
    lo <- min(vals, na.rm = TRUE)
    hi <- max(vals, na.rm = TRUE)
    span <- max(hi - lo, 1e-8)
    pad <- max(0.08 * span, 0.05)
    br <- pretty(c(lo - pad, hi + pad), n = 6)
    lims <- range(br, lo - pad, hi + pad, finite = TRUE)
  }
  list(lims = lims, breaks = br)
}

plot_compare_channel <- function(db, y_target, y_spec, metric = c("abs", "signed"), show_legend = FALSE) {
  metric <- match.arg(metric)
  d <- db %>%
    filter(as.character(.data$ycol) == y_target, !is.na(.data$xvar))
  if (!nrow(d)) return(NULL)
  if (metric == "abs") {
    y_est <- "abs_est"
    y_lo <- "abs_lo"
    y_hi <- "abs_hi"
    y_lab <- "Absolute tissue O2 change (% per clinical increment)"
  } else {
    y_est <- "signed_est"
    y_lo <- "signed_lo"
    y_hi <- "signed_hi"
    y_lab <- "Tissue O2 change (% per clinical increment)"
  }
  ggplot(d, aes(x = .data$xvar, fill = .data$xvar, colour = .data$xvar, y = .data[[y_est]])) +
    geom_col(width = 0.6, linewidth = 0.5) +
    geom_errorbar(
      aes(ymin = .data[[y_lo]], ymax = .data[[y_hi]], colour = .data$xvar),
      width = COMPARE_ERRBAR_CAP,
      linewidth = COMPARE_ERRBAR_LWD,
      show.legend = FALSE
    ) +
    geom_hline(yintercept = 0, colour = "#9E9E9E", linewidth = 0.35, linetype = "dashed") +
    scale_fill_manual(values = CLINICAL_STEP_FILL_COLORS, labels = function(v) pretty_lab(v), drop = FALSE) +
    scale_colour_manual(values = CLINICAL_STEP_COLORS, labels = function(v) pretty_lab(v), guide = "none", drop = FALSE) +
    scale_x_discrete(labels = XVAR_TICK_LABELS, drop = FALSE) +
    scale_y_continuous(limits = y_spec$lims, breaks = y_spec$breaks, expand = expansion(mult = c(0, 0.02))) +
    labs(
      x = "Intraoperative variable",
      y = y_lab,
      title = NULL
    ) +
    theme_clean() +
    theme(
      legend.position = if (show_legend) "right" else "none",
      axis.text.x = element_text(size = TICK_FONTSIZE)
    )
}

smooth_fio2_curves <- function(d) {
  if (!isTRUE(FIO2_EXTRA_SMOOTH)) return(d)
  if (!nrow(d)) return(d)
  xvar <- as.character(d$xvar[1] %||% "")
  if (!identical(xvar, "FiO2_new")) return(d)

  dd <- d %>% arrange(.data$x)
  x <- dd$x

  smooth_one <- function(y) {
    ok <- is.finite(x) & is.finite(y)
    if (sum(ok) < 8) return(y)
    fit <- tryCatch(
      stats::smooth.spline(x = x[ok], y = y[ok], spar = FIO2_SMOOTH_SP),
      error = function(e) NULL
    )
    if (is.null(fit)) return(y)
    ys <- y
    ys[ok] <- as.numeric(stats::predict(fit, x = x[ok])$y)
    ys
  }

  dd$pred_mean <- smooth_one(dd$pred_mean)
  dd$`pred_lo_2.5` <- smooth_one(dd$`pred_lo_2.5`)
  dd$`pred_hi_97.5` <- smooth_one(dd$`pred_hi_97.5`)
  lo <- pmin(dd$`pred_lo_2.5`, dd$`pred_hi_97.5`)
  hi <- pmax(dd$`pred_lo_2.5`, dd$`pred_hi_97.5`)
  dd$`pred_lo_2.5` <- lo
  dd$`pred_hi_97.5` <- hi
  dd$pred_mean <- pmax(lo, pmin(hi, dd$pred_mean))
  dd
}

plot_slice_curve <- function(d) {
  d <- smooth_fio2_curves(d)
  xvar <- as.character(d$xvar[1])
  ycol <- as.character(d$ycol[1])
  spx <- get_x_axis_spec(xvar)
  if (is.null(spx$lims) || any(!is.finite(spx$lims))) {
    spx$lims <- range(d$x, na.rm = TRUE)
  }
  x_pad <- diff(spx$lims) * X_LEFT_PAD_FRAC
  x_plot_lims <- c(spx$lims[1] - x_pad, spx$lims[2])
  p <- ggplot(d, aes(x = .data$x)) + theme_clean()

  m <- marginal_density_map[[ycol]] %||% list()
  x_hist <- m$x_hist[[xvar]] %||% data.frame(low = numeric(0), high = numeric(0), count = numeric(0))
  y_hist <- m$y_hist %||% data.frame(low = numeric(0), high = numeric(0), count = numeric(0))
  hist_desc <- build_hist_descriptions(x_hist, y_hist, xvar, ycol)
  p <- add_edge_marginal_layers(
    p,
    x_hist = x_hist,
    y_hist = y_hist,
    x_data_lims = spx$lims,
    x_plot_lims = x_plot_lims,
    y_lims = SLICE_Y_LIMS
  )

  p +
    geom_ribbon(aes(ymin = .data[["pred_lo_2.5"]], ymax = .data[["pred_hi_97.5"]]), fill = "#4C72B0", alpha = 0.18, colour = NA) +
    geom_line(aes(y = .data$pred_mean), colour = "#1F4E8C", linewidth = 1.2) +
    scale_x_continuous(breaks = spx$breaks) +
    scale_y_continuous(breaks = SLICE_Y_BREAKS) +
    coord_cartesian(xlim = x_plot_lims, ylim = SLICE_Y_LIMS, expand = FALSE) +
    labs(
      x = pretty_lab_axis(xvar),
      y = pretty_lab_axis(ycol),
      title = NULL
    ) +
    theme_clean()
}

sanitize_tag <- function(x) {
  x <- as.character(x %||% "All")
  x <- trimws(x)
  if (!nzchar(x)) x <- "All"
  gsub("[^A-Za-z0-9._-]+", "_", x)
}

render_one_subgroup <- function(curve_df_sub, subgroup_val) {
  subgroup_tag <- sanitize_tag(subgroup_val)
  split_needed <- length(SUBGROUP_VALUES) > 1 || subgroup_tag != "All"
  out_root <- if (split_needed) file.path(OUTDIR, paste0("subgroup_", subgroup_tag)) else OUTDIR
  dir_create(out_root, recurse = TRUE)

  plot_index <- list()
  slice_plot_rows <- list()
  hist_desc_rows <- list()
  plot_map <- list()
  pair_grid <- expand.grid(
    y_key = Y_ORDER,
    x_key = XVAR_ORDER,
    stringsAsFactors = FALSE
  )

  for (ii in seq_len(nrow(pair_grid))) {
    y_key <- pair_grid$y_key[[ii]]
    x_key <- pair_grid$x_key[[ii]]
    d <- curve_df_sub %>%
      filter(.data$ycol == y_key, .data$xvar == x_key) %>%
      arrange(.data$x)
    if (!nrow(d)) next

    p <- plot_slice_curve(d)
    key <- paste(y_key, x_key, sep = "__")
    plot_map[[key]] <- p

    sec <- unique(d$sec)[1] %||% NA
    n_sample <- unique(d$n_sample)[1] %||% NA
    n_boot_ok <- unique(d$n_boot_ok)[1] %||% NA
    out_sub <- file.path(out_root, y_key, paste0(sec, "s"), paste0("sub", n_sample), x_key)
    out_png <- file.path(out_sub, glue("{y_key}_{x_key}_{sec}s_sub{n_sample}_{PLOT_MODE_TAG}_curve.png"))
    save_png(p, out_png)

    plot_index[[length(plot_index) + 1]] <- data.frame(
      kind = PLOT_MODE_TAG,
      plot_mode = PLOT_MODE,
      subgroup = subgroup_val,
      ycol = y_key,
      xvar = x_key,
      sec = sec,
      n_sample = n_sample,
      n_boot_ok = n_boot_ok,
      output_png = out_png,
      stringsAsFactors = FALSE
    )

    spx <- get_x_axis_spec(x_key)
    slice_plot_rows[[length(slice_plot_rows) + 1]] <- d %>%
      transmute(
        plot_mode = PLOT_MODE,
        subgroup = subgroup_val,
        ycol = .data$ycol,
        xvar = .data$xvar,
        sec, n_sample, n_boot_ok, x,
        y = .data$pred_mean, y_lo = .data[["pred_lo_2.5"]], y_hi = .data[["pred_hi_97.5"]],
        x_lim_lo = spx$lims[1] %||% NA_real_,
        x_lim_hi = spx$lims[2] %||% NA_real_,
        y_lim_lo = SLICE_Y_LIMS[1],
        y_lim_hi = SLICE_Y_LIMS[2]
      )

    m <- marginal_density_map[[y_key]] %||% list()
    x_hist <- m$x_hist[[x_key]] %||% data.frame(low = numeric(0), high = numeric(0), count = numeric(0))
    y_hist <- m$y_hist %||% data.frame(low = numeric(0), high = numeric(0), count = numeric(0))
    hd <- build_hist_descriptions(x_hist, y_hist, x_key, y_key)
    hist_desc_rows[[length(hist_desc_rows) + 1]] <- data.frame(
      plot_mode = PLOT_MODE,
      subgroup = subgroup_val,
      ycol = y_key,
      xvar = x_key,
      sec = sec,
      n_sample = n_sample,
      x_hist_available = hd$x_hist_available,
      y_hist_available = hd$y_hist_available,
      x_hist_range = hd$x_hist_range,
      y_hist_range = hd$y_hist_range,
      x_hist_peak = hd$x_hist_peak,
      y_hist_peak = hd$y_hist_peak,
      subtitle = hd$subtitle,
      caption = hd$caption,
      stringsAsFactors = FALSE
    )
  }

  if (!length(plot_map)) {
    message("[skip] subgroup=", subgroup_val, " has no plot rows after filters")
    return(invisible(NULL))
  }

  clinical_compare <- if (isTRUE(ADD_CLINICAL_COMPARE)) {
    build_clinical_compare_data(curve_df_sub, model_input_quantiles)
  } else {
    list(summary = tibble(), segments = tibble())
  }
  compare_summary <- clinical_compare$summary
  compare_segments <- clinical_compare$segments
  compare_data <- build_compare_plot_data(compare_summary, compare_segments)
  compare_y_spec_signed <- get_compare_y_spec(compare_data, metric = "signed")
  compare_y_spec_abs <- get_compare_y_spec(compare_data, metric = "abs")
  compare_plot_map_signed <- list()
  compare_plot_map_abs <- list()
  if (nrow(compare_data)) {
    for (y in Y_ORDER) {
      p_signed <- plot_compare_channel(compare_data, y, compare_y_spec_signed, metric = "signed")
      p_abs <- plot_compare_channel(compare_data, y, compare_y_spec_abs, metric = "abs")
      compare_plot_map_signed[[y]] <- p_signed
      compare_plot_map_abs[[y]] <- p_abs
      if (!is.null(p_signed)) {
        plot_index[[length(plot_index) + 1]] <- data.frame(
          plot_id = glue("compare_signed_{subgroup_tag}_{y}"),
          subgroup = subgroup_val,
          ycol = y,
          xvar = "clinical_compare",
          sec = NA_real_,
          plot_mode = paste0(PLOT_MODE, "_compare_signed"),
          output_png = save_png(p_signed, file.path(out_root, glue("compare_signed_{subgroup_tag}_{y}.png")), FIG_W, FIG_H),
          stringsAsFactors = FALSE
        )
      }
      if (!is.null(p_abs)) {
        plot_index[[length(plot_index) + 1]] <- data.frame(
          plot_id = glue("compare_abs_{subgroup_tag}_{y}"),
          subgroup = subgroup_val,
          ycol = y,
          xvar = "clinical_compare",
          sec = NA_real_,
          plot_mode = paste0(PLOT_MODE, "_compare_abs"),
          output_png = save_png(p_abs, file.path(out_root, glue("compare_abs_{subgroup_tag}_{y}.png")), FIG_W, FIG_H),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  ppt_merge <- read_pptx()
  ppt_merge <- set_ppt_slide_size(ppt_merge, width_in = MERGE_SLIDE_W_IN, height_in = MERGE_SLIDE_H_IN)
  for (x in XVAR_ORDER) {
    ps <- lapply(Y_ORDER, function(y) plot_map[[paste(y, x, sep = "__")]])
    ps <- Filter(Negate(is.null), ps)
    if (!length(ps)) next
    ppt_merge <- add_blank(ppt_merge)
    ppt_merge <- ppt_add_plots_in_row(ppt_merge, ps)
  }
  compare_ps_signed <- lapply(Y_ORDER, function(y) compare_plot_map_signed[[y]])
  compare_ps_signed <- Filter(Negate(is.null), compare_ps_signed)
  if (length(compare_ps_signed)) {
    ppt_merge <- add_blank(ppt_merge)
    ppt_merge <- ppt_add_plots_in_row(ppt_merge, compare_ps_signed)
  }
  compare_ps_abs <- lapply(Y_ORDER, function(y) compare_plot_map_abs[[y]])
  compare_ps_abs <- Filter(Negate(is.null), compare_ps_abs)
  if (length(compare_ps_abs)) {
    ppt_merge <- add_blank(ppt_merge)
    ppt_merge <- ppt_add_plots_in_row(ppt_merge, compare_ps_abs)
  }

  ppt_single <- read_pptx()
  for (y in Y_ORDER) {
    for (x in XVAR_ORDER) {
      p <- plot_map[[paste(y, x, sep = "__")]]
      if (is.null(p)) next
      ppt_single <- add_blank(ppt_single)
      ppt_single <- ppt_add_one(ppt_single, p, width = FIG_W, height = FIG_H, top = 0.8)
    }
    p_compare_signed <- compare_plot_map_signed[[y]]
    if (!is.null(p_compare_signed)) {
      ppt_single <- add_blank(ppt_single)
      ppt_single <- ppt_add_one(ppt_single, p_compare_signed, width = FIG_W, height = FIG_H, top = 0.8)
    }
    p_compare_abs <- compare_plot_map_abs[[y]]
    if (!is.null(p_compare_abs)) {
      ppt_single <- add_blank(ppt_single)
      ppt_single <- ppt_add_one(ppt_single, p_compare_abs, width = FIG_W, height = FIG_H, top = 0.8)
    }
  }

  name_suffix <- if (split_needed) paste0("_sg_", subgroup_tag) else ""
  ppt_merge_path <- file.path(out_root, glue("intraop_multivar_{PLOT_MODE_TAG}_merged{length(Y_ORDER)}ch_{basename(RESULT_DIR)}{name_suffix}.pptx"))
  ppt_single_path <- file.path(out_root, glue("intraop_multivar_{PLOT_MODE_TAG}_by_channel_{basename(RESULT_DIR)}{name_suffix}.pptx"))
  print(ppt_merge, target = ppt_merge_path)
  print(ppt_single, target = ppt_single_path)

  idx_df <- if (length(plot_index)) bind_rows(plot_index) else data.frame()
  if (nrow(idx_df)) write_csv(idx_df, file.path(out_root, "plot_index.csv"))
  if (length(slice_plot_rows)) write_csv(bind_rows(slice_plot_rows), file.path(out_root, "plot_data_slice_all.csv"))
  if (length(hist_desc_rows)) write_csv(bind_rows(hist_desc_rows), file.path(out_root, "plot_hist_descriptions.csv"))
  if (nrow(compare_summary)) write_csv(compare_summary, file.path(out_root, "plot_data_clinical_step_summary.csv"))
  if (nrow(compare_segments)) write_csv(compare_segments, file.path(out_root, "plot_data_clinical_step_segments.csv"))
  if (nrow(compare_data)) write_csv(compare_data, file.path(out_root, "plot_data_comparable_bar.csv"))
  write_csv(
    bind_rows(lapply(XVAR_ORDER, function(v) {
      sp <- get_x_axis_spec(v)
      data.frame(
        subgroup = subgroup_val,
        xvar = v,
        x_lim_lo = (sp$lims %||% c(NA_real_, NA_real_))[1],
        x_lim_hi = (sp$lims %||% c(NA_real_, NA_real_))[2],
        x_breaks = if (inherits(sp$breaks, "waiver")) "" else paste(sp$breaks, collapse = "|"),
        y_lim_lo = SLICE_Y_LIMS[1],
        y_lim_hi = SLICE_Y_LIMS[2],
        y_breaks = paste(SLICE_Y_BREAKS, collapse = "|"),
        stringsAsFactors = FALSE
      )
    })),
    file.path(out_root, "plot_axis_config.csv")
  )

  metrics_csv <- file.path(RESULT_DIR, "slope_metrics_all.csv")
  if (file_exists(metrics_csv)) {
    file_copy(metrics_csv, file.path(out_root, "slope_metrics_all_copy.csv"), overwrite = TRUE)
  }

  message("[done] subgroup=", subgroup_val)
  message("[done] merged ppt: ", ppt_merge_path)
  message("[done] single ppt: ", ppt_single_path)
  message("[done] figures dir: ", out_root)
}

for (sg in SUBGROUP_VALUES) {
  dsg <- curve_df %>% filter(.data$subgroup == sg)
  render_one_subgroup(dsg, sg)
}
