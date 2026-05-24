#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(fs)
  library(ggplot2)
  library(glue)
  library(officer)
  library(readr)
  library(rvg)
  library(xml2)
})

args <- commandArgs(trailingOnly = TRUE)
RESULT_DIR <- if (length(args) >= 1 && nzchar(args[1])) args[1] else file.path(
  "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516",
  "results/model_runs",
  "v5_6_2026_rev2_20260506_co2tempfio2_hemo_adj_boot20_rso2_25_95_full_20260513_154630_subgroup_modelB_sec1_n10000_boot200_rowreplace"
)
if (!dir_exists(RESULT_DIR)) stop("RESULT_DIR not found: ", RESULT_DIR)
TARGET_XVAR <- if (length(args) >= 2 && nzchar(args[2])) args[2] else Sys.getenv("INTRA5_TARGET_XVAR", "ET_CO2")

file_arg <- commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))]
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[1]) else "code/r/subgroup_compare_panel3x2_ppt_20260524.R"
SCRIPT_DIR <- dirname(normalizePath(script_path))
REPO_ROOT <- normalizePath(file.path(SCRIPT_DIR, "../.."))
STAMP <- format(Sys.time(), "%Y%m%d_%H%M%S")
RAW_CACHE <- Sys.getenv(
  "INTRA5_RAW_CACHE",
  "/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result/raw_cache/intra5_selected_572ae06d53d8.parquet"
)
if (!file_exists(RAW_CACHE)) stop("RAW_CACHE not found: ", RAW_CACHE)

cm_to_in <- function(cm) cm / 2.54
FIG_W <- cm_to_in(6)
FIG_H <- cm_to_in(6)
GAP_X_IN <- 0.16
GAP_Y_IN <- 0.18
SLIDE_W <- 2 * FIG_W + GAP_X_IN + 0.42
SLIDE_H <- 3 * FIG_H + 2 * GAP_Y_IN + 0.42

FONT_FAMILY <- "Aptos"
AXIS_TITLE_SIZE <- 10
AXIS_TEXT_SIZE <- 7
LINE_SIZE <- 0.8
RIBBON_ALPHA <- 0.18
FIO2_EXTRA_SMOOTH <- tolower(Sys.getenv("INTRA5_FIO2_EXTRA_SMOOTH", "1")) %in% c("1", "true", "t", "yes", "y")
FIO2_SMOOTH_SP <- suppressWarnings(as.numeric(Sys.getenv("INTRA5_FIO2_SMOOTH_SP", "1.0")))
if (!is.finite(FIO2_SMOOTH_SP)) FIO2_SMOOTH_SP <- 1.0
FIO2_SMOOTH_SP <- max(0.2, min(2.0, FIO2_SMOOTH_SP))
SHOW_SUBGROUP_LABELS <- tolower(Sys.getenv("INTRA5_SHOW_SUBGROUP_LABELS", "0")) %in% c("1", "true", "t", "yes", "y")
FIO2_SMOOTH_TAG <- if (isTRUE(FIO2_EXTRA_SMOOTH)) {
  paste0("fio2spar", gsub("\\.", "p", format(FIO2_SMOOTH_SP, trim = TRUE, scientific = FALSE)))
} else {
  "fio2raw"
}
LABEL_TAG <- if (isTRUE(SHOW_SUBGROUP_LABELS)) "withlabels" else "nolabels"
OUT_DIR <- file.path(REPO_ROOT, "results", glue("subgroup_compare_{TARGET_XVAR}_panel3x2_no_box_panel6cm_{FIO2_SMOOTH_TAG}_{LABEL_TAG}_{STAMP}"))
dir_create(OUT_DIR, recurse = TRUE)

Y_ORDER <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
X_ORDER <- c("ET_CO2", "TEMP", "FiO2_new")
if (!TARGET_XVAR %in% X_ORDER) stop("TARGET_XVAR must be one of: ", paste(X_ORDER, collapse = ", "))
X_ORDER <- TARGET_XVAR
SUBGROUP_MATRIX <- matrix(
  c(
    "Age_less_70", "Age_more_70",
    "Female", "Male",
    "Pre_hypertension_less_140_90", "Pre_hypertension_more_140_90"
  ),
  nrow = 3,
  byrow = TRUE
)
SUBGROUP_LABELS <- list(
  "Age_less_70" = "Age <70 y",
  "Age_more_70" = "Age >=70 y",
  "Female" = "Female",
  "Male" = "Male",
  "Pre_hypertension_less_140_90" = "Preop BP <140/90",
  "Pre_hypertension_more_140_90" = "Preop BP >=140/90"
)
Y_LABELS <- list(
  "rSO2_Ch1" = quote("Left SctO"[2] ~ "(%)"),
  "rSO2_Ch2" = quote("Right SctO"[2] ~ "(%)"),
  "rSO2_Ch3" = quote("SftO"[2] ~ "(%)")
)
X_LABELS <- list(
  "ET_CO2" = quote("End-Tidal CO"[2] ~ "(mmHg)"),
  "TEMP" = quote("Temperature (" * degree * "C)"),
  "FiO2_new" = quote("Inspired Oxygen (%)")
)
X_AXIS <- list(
  "ET_CO2" = list(lims = c(20, 50), breaks = seq(20, 50, 5)),
  "TEMP" = list(lims = c(34, 37.5), breaks = seq(34, 37.5, 0.5)),
  "FiO2_new" = list(lims = c(30, 100), breaks = seq(30, 100, 10))
)
Y_LIMS <- c(66, 81)
Y_BREAKS <- seq(66, 80, 2)
X_LEFT_PAD_FRAC <- 0.14
MARG_BAND_RATIO <- 0.12
MARG_BINS_X <- 24L
MARG_BINS_Y <- 24L
MARG_Y_BIN_WIDTH_MIN <- 0.5
MARG_Y_BIN_WIDTH_MAX <- 2.0
MARG_Y_BIN_WIDTH_FIXED <- suppressWarnings(as.numeric(Sys.getenv("INTRA5_Y_HIST_BIN_WIDTH", "0")))
Y_PHYSIO_LIMITS <- c(25, 95)

make_hist_df <- function(v, from, to, bins = 24L, break_by = NULL) {
  vv <- suppressWarnings(as.numeric(v))
  vv <- vv[is.finite(vv) & vv >= from & vv <= to]
  if (!length(vv)) return(data.frame(low = numeric(0), high = numeric(0), count = numeric(0)))
  if (!is.null(break_by) && is.finite(break_by) && break_by > 0) {
    br <- seq(from, to, by = break_by)
    if (tail(br, 1) < to) br <- c(br, to)
    if (length(br) < 2) br <- c(from, to)
  } else {
    br <- seq(from, to, length.out = bins + 1L)
  }
  h <- hist(vv, breaks = br, include.lowest = TRUE, right = FALSE, plot = FALSE)
  data.frame(low = head(h$breaks, -1), high = tail(h$breaks, -1), count = as.numeric(h$counts))
}

choose_adaptive_bin_width <- function(v, from, to, width_min = 0.5, width_max = 2.0, target_nonzero = 0.75) {
  vv <- suppressWarnings(as.numeric(v))
  vv <- vv[is.finite(vv) & vv >= from & vv <= to]
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
    if (is.finite(nz_ratio) && (nz_ratio >= target_nonzero || length(h$counts) <= 18)) return(w)
  }
  tail(cand, 1)
}

scale_x_hist <- function(h, y_lims) {
  if (!nrow(h) || max(h$count, na.rm = TRUE) <= 0) return(h[0, ])
  x_band <- diff(y_lims) * MARG_BAND_RATIO
  h %>% mutate(ymin = y_lims[1], ymax = y_lims[1] + (count / max(count, na.rm = TRUE)) * x_band)
}

scale_y_hist <- function(h, x_data_lims, x_plot_lims) {
  if (!nrow(h) || max(h$count, na.rm = TRUE) <= 0) return(h[0, ])
  y_band <- max(x_data_lims[1] - x_plot_lims[1], diff(x_data_lims) * 0.06)
  h %>% mutate(xmin = x_plot_lims[1], xmax = x_plot_lims[1] + (count / max(count, na.rm = TRUE)) * y_band)
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

curve_files <- dir_ls(RESULT_DIR, recurse = TRUE, type = "file", regexp = "_curve_boot\\.csv$")
if (!length(curve_files)) stop("No curve_boot files found in RESULT_DIR")

curve_df <- bind_rows(lapply(curve_files, function(fp) {
  d <- suppressMessages(read_csv(fp, show_col_types = FALSE))
  d$source_csv <- fp
  d
})) %>%
  filter(.data$xvar %in% X_ORDER, .data$plot_mode == "slice_median", .data$ycol %in% Y_ORDER) %>%
  mutate(
    x = as.numeric(.data$x),
    y = as.numeric(.data$pred_mean),
    y_lo = as.numeric(.data$pred_lo_2.5),
    y_hi = as.numeric(.data$pred_hi_97.5)
  )
if (!nrow(curve_df)) stop("No slice_median rows after filtering")
if (!("subgroup" %in% names(curve_df))) curve_df$subgroup <- "All"
curve_df$subgroup <- as.character(curve_df$subgroup)

raw_df <- as.data.frame(read_parquet(RAW_CACHE, col_select = c(X_ORDER, Y_ORDER)))
hist_map <- list()
for (xx in X_ORDER) {
  xcfg <- X_AXIS[[xx]]
  x_pad <- diff(xcfg$lims) * X_LEFT_PAD_FRAC
  x_plot_lims <- c(xcfg$lims[1] - x_pad, xcfg$lims[2])
  hist_map[[xx]] <- list()
  xv <- suppressWarnings(as.numeric(raw_df[[xx]]))
  for (yy in Y_ORDER) {
    yv <- suppressWarnings(as.numeric(raw_df[[yy]]))
    mask_y <- is.finite(yv) & yv >= Y_PHYSIO_LIMITS[1] & yv <= Y_PHYSIO_LIMITS[2]
    y_tmp <- yv[mask_y]
    if (length(y_tmp) >= 200) {
      ql <- as.numeric(stats::quantile(y_tmp, probs = 0.005, na.rm = TRUE))
      qh <- as.numeric(stats::quantile(y_tmp, probs = 0.995, na.rm = TRUE))
      mask_y <- mask_y & yv >= ql & yv <= qh
    }
    x_use <- xv[mask_y]
    x_use <- x_use[is.finite(x_use) & x_use >= xcfg$lims[1] & x_use <= xcfg$lims[2]]
    y_use <- yv[mask_y]
    y_break_by <- if (is.finite(MARG_Y_BIN_WIDTH_FIXED) && MARG_Y_BIN_WIDTH_FIXED > 0) {
      MARG_Y_BIN_WIDTH_FIXED
    } else {
      choose_adaptive_bin_width(
        y_use,
        from = Y_LIMS[1],
        to = Y_LIMS[2],
        width_min = MARG_Y_BIN_WIDTH_MIN,
        width_max = MARG_Y_BIN_WIDTH_MAX
      )
    }
    hist_map[[xx]][[yy]] <- list(
      x = scale_x_hist(make_hist_df(x_use, xcfg$lims[1], xcfg$lims[2], bins = MARG_BINS_X), Y_LIMS),
      y = scale_y_hist(
        make_hist_df(y_use, Y_LIMS[1], Y_LIMS[2], bins = MARG_BINS_Y, break_by = y_break_by),
        x_data_lims = xcfg$lims,
        x_plot_lims = x_plot_lims
      )
    )
  }
}

theme_figure2 <- function() {
  theme_classic(base_family = FONT_FAMILY, base_size = AXIS_TEXT_SIZE) +
    theme(
      axis.title = element_text(size = AXIS_TITLE_SIZE, colour = "black", family = FONT_FAMILY),
      axis.text = element_text(size = AXIS_TEXT_SIZE, colour = "black", family = FONT_FAMILY),
      axis.line = element_line(linewidth = 0.45, colour = "#5f5f5f"),
      axis.ticks = element_line(linewidth = 0.45, colour = "#5f5f5f"),
      axis.ticks.length = unit(3.5, "pt"),
      plot.title = element_text(size = 8, colour = "black", family = FONT_FAMILY, hjust = 0.5, face = "plain"),
      plot.margin = margin(2, 2, 2, 2, unit = "pt"),
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA)
    )
}

smooth_fio2_curves <- function(d) {
  if (!isTRUE(FIO2_EXTRA_SMOOTH)) return(d)
  if (!nrow(d)) return(d)
  xvar <- as.character(d$xvar[1])
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

  dd$y <- smooth_one(dd$y)
  dd$y_lo <- smooth_one(dd$y_lo)
  dd$y_hi <- smooth_one(dd$y_hi)
  lo <- pmin(dd$y_lo, dd$y_hi)
  hi <- pmax(dd$y_lo, dd$y_hi)
  dd$y_lo <- lo
  dd$y_hi <- hi
  dd$y <- pmax(lo, pmin(hi, dd$y))
  dd
}

sanitize_tag <- function(x) {
  x <- trimws(as.character(x))
  if (!nzchar(x)) x <- "All"
  gsub("[^A-Za-z0-9._-]+", "_", x)
}

make_panel <- function(xx, yy, subgroup_value) {
  xcfg <- X_AXIS[[xx]]
  x_pad <- diff(xcfg$lims) * X_LEFT_PAD_FRAC
  x_plot_lims <- c(xcfg$lims[1] - x_pad, xcfg$lims[2])
  d <- curve_df %>%
    filter(.data$xvar == xx, .data$ycol == yy, .data$subgroup == subgroup_value) %>%
    smooth_fio2_curves()
  if (!nrow(d)) {
    stop("No curve rows for subgroup=", subgroup_value, ", xvar=", xx, ", ycol=", yy)
  }
  hm <- hist_map[[xx]][[yy]]
  ggplot(d, aes(x = .data$x, y = .data$y)) +
    geom_rect(
      data = hm$x,
      aes(xmin = .data$low, xmax = .data$high, ymin = .data$ymin, ymax = .data$ymax),
      inherit.aes = FALSE, fill = "#B2DF8A", alpha = 0.34, colour = "#AFAFAF", linewidth = 0.20
    ) +
    geom_rect(
      data = hm$y,
      aes(xmin = .data$xmin, xmax = .data$xmax, ymin = .data$low, ymax = .data$high),
      inherit.aes = FALSE, fill = "#FDB863", alpha = 0.30, colour = "#AFAFAF", linewidth = 0.20
    ) +
    geom_ribbon(aes(ymin = .data$y_lo, ymax = .data$y_hi), fill = "#245a9b", alpha = RIBBON_ALPHA, colour = NA) +
    geom_line(colour = "#174f95", linewidth = LINE_SIZE) +
    coord_cartesian(xlim = x_plot_lims, ylim = Y_LIMS, expand = FALSE, clip = "off") +
    scale_x_continuous(breaks = xcfg$breaks) +
    scale_y_continuous(breaks = Y_BREAKS) +
    labs(
      x = X_LABELS[[xx]],
      y = Y_LABELS[[yy]],
      title = if (isTRUE(SHOW_SUBGROUP_LABELS)) SUBGROUP_LABELS[[subgroup_value]] %||% subgroup_value else NULL
    ) +
    theme_figure2()
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x)) y else x

add_matrix_to_ppt <- function(ppt, plots_matrix) {
  left0 <- (SLIDE_W - (2 * FIG_W + GAP_X_IN)) / 2
  top0 <- (SLIDE_H - (3 * FIG_H + 2 * GAP_Y_IN)) / 2
  for (r in seq_len(3)) {
    for (c in seq_len(2)) {
      ppt <- ph_with(
        ppt,
        dml(ggobj = plots_matrix[[r, c]]),
        location = ph_location(
          left = left0 + (c - 1) * (FIG_W + GAP_X_IN),
          top = top0 + (r - 1) * (FIG_H + GAP_Y_IN),
          width = FIG_W,
          height = FIG_H
        )
      )
    }
  }
  ppt
}

missing_subgroups <- setdiff(as.vector(SUBGROUP_MATRIX), unique(curve_df$subgroup))
if (length(missing_subgroups)) {
  stop("Missing required subgroup(s): ", paste(missing_subgroups, collapse = ", "))
}

plot_index <- list()
png_dir <- file.path(OUT_DIR, "png")
dir_create(png_dir, recurse = TRUE)

ppt <- read_pptx()
ppt <- set_ppt_slide_size(ppt, width_in = SLIDE_W, height_in = SLIDE_H)

for (yy in Y_ORDER) {
  plots_matrix <- matrix(list(), nrow = 3, ncol = 2)
  for (r in seq_len(nrow(SUBGROUP_MATRIX))) {
    for (c in seq_len(ncol(SUBGROUP_MATRIX))) {
      sg <- SUBGROUP_MATRIX[r, c]
      p <- make_panel(TARGET_XVAR, yy, subgroup_value = sg)
      plots_matrix[[r, c]] <- p
      png_name <- glue("subgroup_compare_{TARGET_XVAR}_{yy}_{sanitize_tag(sg)}_panel6cm.png")
      ggsave(file.path(png_dir, png_name), plot = p, width = FIG_W, height = FIG_H, units = "in", dpi = 600, bg = "white")
      plot_index[[length(plot_index) + 1L]] <- data.frame(
        xvar = TARGET_XVAR,
        ycol = yy,
        subgroup = sg,
        row = r,
        col = c,
        png = file.path("png", png_name)
      )
    }
  }
  ppt <- add_blank(ppt)
  ppt <- add_matrix_to_ppt(ppt, plots_matrix)
}

ppt_name <- glue("subgroup_compare_{TARGET_XVAR}_modelB_n10000_b200_panel3x2.pptx")
print(ppt, target = file.path(OUT_DIR, ppt_name))
write_csv(bind_rows(plot_index), file.path(OUT_DIR, "plot_index.csv"))

message("[done] result_dir=", RESULT_DIR)
message("[done] output_dir=", OUT_DIR)
message("[done] target_xvar=", TARGET_XVAR)
message("[done] ppt=", file.path(OUT_DIR, ppt_name))
