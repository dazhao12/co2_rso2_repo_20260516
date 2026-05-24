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

`%||%` <- function(a, b) if (!is.null(a)) a else b

args <- commandArgs(trailingOnly = TRUE)
RESULT_DIR <- if (length(args) >= 1 && nzchar(args[1])) args[1] else ""
if (!nzchar(RESULT_DIR)) stop("Need RESULT_DIR as first argument")
if (!dir_exists(RESULT_DIR)) stop("RESULT_DIR not found: ", RESULT_DIR)

file_arg <- commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))]
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[1]) else "code/r/figure2_etco2_focus_ppt_20260524.R"
SCRIPT_DIR <- dirname(normalizePath(script_path))
REPO_ROOT <- normalizePath(file.path(SCRIPT_DIR, "../.."))
OUT_DIR <- file.path(REPO_ROOT, "results", "figure2_modelB_focus_boxes_20260524")
dir_create(OUT_DIR, recurse = TRUE)

RAW_CACHE <- Sys.getenv(
  "INTRA5_RAW_CACHE",
  "/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result/raw_cache/intra5_selected_572ae06d53d8.parquet"
)
if (!file_exists(RAW_CACHE)) stop("RAW_CACHE not found: ", RAW_CACHE)

cm_to_in <- function(cm) cm / 2.54
FIG_W <- cm_to_in(6)
FIG_H <- cm_to_in(6)
GAP_IN <- 0.12
SIDE_MARGIN_IN <- 0.18
SLIDE_W <- max(7.5, 3 * FIG_W + 2 * GAP_IN + 2 * SIDE_MARGIN_IN)
SLIDE_H <- 3.0

FONT_FAMILY <- "Aptos"
AXIS_TITLE_SIZE <- 10
AXIS_TEXT_SIZE <- 7
LINE_SIZE <- 0.8
RIBBON_ALPHA <- 0.18
BOX_LINE_SIZE <- 0.45

Y_ORDER <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
X_ORDER <- c("ET_CO2", "TEMP", "FiO2_new")
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
  "ET_CO2" = list(lims = c(20, 50), breaks = seq(20, 50, 5), nice = 1),
  "TEMP" = list(lims = c(34, 37.5), breaks = seq(34, 37.5, 0.5), nice = 0.1),
  "FiO2_new" = list(lims = c(30, 100), breaks = seq(30, 100, 10), nice = 1)
)
Y_LIMS <- c(66, 81)
Y_BREAKS <- seq(66, 80, 2)
BOX_Y <- c(70, 79)

make_hist_df <- function(v, from, to, bins = 24L) {
  vv <- suppressWarnings(as.numeric(v))
  vv <- vv[is.finite(vv) & vv >= from & vv <= to]
  if (!length(vv)) return(data.frame(low = numeric(0), high = numeric(0), count = numeric(0)))
  br <- seq(from, to, length.out = bins + 1L)
  h <- hist(vv, breaks = br, include.lowest = TRUE, right = FALSE, plot = FALSE)
  data.frame(
    low = head(h$breaks, -1),
    high = tail(h$breaks, -1),
    count = as.numeric(h$counts)
  )
}

scale_x_hist <- function(h) {
  if (!nrow(h) || max(h$count, na.rm = TRUE) <= 0) return(h[0, ])
  h %>% mutate(ymin = Y_LIMS[1], ymax = Y_LIMS[1] + 1.35 * count / max(count, na.rm = TRUE))
}

scale_y_hist <- function(h, x_lims) {
  if (!nrow(h) || max(h$count, na.rm = TRUE) <= 0) return(h[0, ])
  h %>% mutate(xmin = x_lims[1], xmax = x_lims[1] + diff(x_lims) * 0.085 * count / max(count, na.rm = TRUE))
}

nice_floor <- function(x, step) floor(x / step) * step
nice_ceil <- function(x, step) ceiling(x / step) * step

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
}))
curve_df <- curve_df %>%
  filter(.data$xvar %in% X_ORDER, .data$plot_mode == "slice_median", .data$ycol %in% Y_ORDER) %>%
  mutate(
    x = as.numeric(.data$x),
    y = as.numeric(.data$pred_mean),
    y_lo = as.numeric(.data$pred_lo_2.5),
    y_hi = as.numeric(.data$pred_hi_97.5)
  )
if (!nrow(curve_df)) stop("No slice_median rows after filtering")

raw_df <- as.data.frame(read_parquet(RAW_CACHE, col_select = c(X_ORDER, Y_ORDER)))
range_rows <- list()
hist_map <- list()
for (xx in X_ORDER) {
  xcfg <- X_AXIS[[xx]]
  hist_map[[xx]] <- list()
  for (yy in Y_ORDER) {
    xv <- suppressWarnings(as.numeric(raw_df[[xx]]))
    yv <- suppressWarnings(as.numeric(raw_df[[yy]]))
    keep <- is.finite(xv) & xv >= xcfg$lims[1] & xv <= xcfg$lims[2] & is.finite(yv)
    x_keep <- xv[keep]
    q90 <- as.numeric(quantile(x_keep, probs = c(0.05, 0.95), na.rm = TRUE, names = FALSE))
    q95 <- as.numeric(quantile(x_keep, probs = c(0.025, 0.975), na.rm = TRUE, names = FALSE))
    range_rows[[length(range_rows) + 1L]] <- data.frame(
      xvar = xx,
      ycol = yy,
      display_lo = xcfg$lims[1],
      display_hi = xcfg$lims[2],
      n = length(x_keep),
      central90_lo = q90[1],
      central90_hi = q90[2],
      central95_lo = q95[1],
      central95_hi = q95[2],
      central90_box_lo = nice_floor(q90[1], xcfg$nice),
      central90_box_hi = nice_ceil(q90[2], xcfg$nice),
      central95_box_lo = nice_floor(q95[1], xcfg$nice),
      central95_box_hi = nice_ceil(q95[2], xcfg$nice)
    )
    hist_map[[xx]][[yy]] <- list(
      x = scale_x_hist(make_hist_df(x_keep, xcfg$lims[1], xcfg$lims[2], bins = 24L)),
      y = scale_y_hist(make_hist_df(yv[keep], Y_LIMS[1], Y_LIMS[2], bins = 24L), xcfg$lims)
    )
  }
}
range_df <- bind_rows(range_rows)
focus_specs <- bind_rows(lapply(X_ORDER, function(xx) {
  xcfg <- X_AXIS[[xx]]
  combined_x <- unlist(lapply(Y_ORDER, function(yy) {
    xv <- suppressWarnings(as.numeric(raw_df[[xx]]))
    yv <- suppressWarnings(as.numeric(raw_df[[yy]]))
    xv[is.finite(xv) & xv >= xcfg$lims[1] & xv <= xcfg$lims[2] & is.finite(yv)]
  }), use.names = FALSE)
  q90 <- as.numeric(quantile(combined_x, probs = c(0.05, 0.95), na.rm = TRUE, names = FALSE))
  q95 <- as.numeric(quantile(combined_x, probs = c(0.025, 0.975), na.rm = TRUE, names = FALSE))
  data.frame(
    xvar = xx,
    focus = c("central90", "central95"),
    display_lo = xcfg$lims[1],
    display_hi = xcfg$lims[2],
    n = length(combined_x),
    q_lo = c(q90[1], q95[1]),
    q_hi = c(q90[2], q95[2]),
    box_lo = c(nice_floor(q90[1], xcfg$nice), nice_floor(q95[1], xcfg$nice)),
    box_hi = c(nice_ceil(q90[2], xcfg$nice), nice_ceil(q95[2], xcfg$nice))
  )
}))
write_csv(range_df, file.path(OUT_DIR, "focus_ranges_by_channel.csv"))
write_csv(focus_specs, file.path(OUT_DIR, "focus_ranges_combined.csv"))

theme_figure2 <- function() {
  theme_classic(base_family = FONT_FAMILY, base_size = AXIS_TEXT_SIZE) +
    theme(
      axis.title = element_text(size = AXIS_TITLE_SIZE, colour = "black", family = FONT_FAMILY),
      axis.text = element_text(size = AXIS_TEXT_SIZE, colour = "black", family = FONT_FAMILY),
      axis.line = element_line(linewidth = 0.45, colour = "#5f5f5f"),
      axis.ticks = element_line(linewidth = 0.45, colour = "#5f5f5f"),
      axis.ticks.length = unit(3.5, "pt"),
      plot.margin = margin(2, 2, 2, 2, unit = "pt"),
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA)
    )
}

make_panel <- function(xx, yy, box_lo, box_hi) {
  xcfg <- X_AXIS[[xx]]
  d <- curve_df %>% filter(.data$xvar == xx, .data$ycol == yy)
  hm <- hist_map[[xx]][[yy]]
  ggplot(d, aes(x = .data$x, y = .data$y)) +
    geom_rect(
      data = hm$x,
      aes(xmin = .data$low, xmax = .data$high, ymin = .data$ymin, ymax = .data$ymax),
      inherit.aes = FALSE, fill = "#e5f2d9", colour = "#b8c7ad", linewidth = 0.2
    ) +
    geom_rect(
      data = hm$y,
      aes(xmin = .data$xmin, xmax = .data$xmax, ymin = .data$low, ymax = .data$high),
      inherit.aes = FALSE, fill = "#fdebd4", colour = "#b8a995", linewidth = 0.2
    ) +
    geom_ribbon(aes(ymin = .data$y_lo, ymax = .data$y_hi), fill = "#245a9b", alpha = RIBBON_ALPHA, colour = NA) +
    geom_line(colour = "#174f95", linewidth = LINE_SIZE) +
    annotate(
      "rect",
      xmin = box_lo, xmax = box_hi, ymin = BOX_Y[1], ymax = BOX_Y[2],
      fill = NA, colour = "#7f7f7f", linewidth = BOX_LINE_SIZE, linetype = "dashed"
    ) +
    coord_cartesian(xlim = xcfg$lims, ylim = Y_LIMS, expand = FALSE, clip = "off") +
    scale_x_continuous(breaks = xcfg$breaks) +
    scale_y_continuous(breaks = Y_BREAKS) +
    labs(x = X_LABELS[[xx]], y = Y_LABELS[[yy]]) +
    theme_figure2()
}

add_row_to_ppt <- function(ppt, plots) {
  left0 <- (SLIDE_W - (3 * FIG_W + 2 * GAP_IN)) / 2
  top0 <- 0.32
  for (i in seq_along(plots)) {
    ppt <- ph_with(
      ppt,
      dml(ggobj = plots[[i]]),
      location = ph_location(left = left0 + (i - 1) * (FIG_W + GAP_IN), top = top0, width = FIG_W, height = FIG_H)
    )
  }
  ppt
}

for (i in seq_len(nrow(focus_specs))) {
  spec <- focus_specs[i, ]
  plots <- lapply(Y_ORDER, function(yy) make_panel(spec$xvar, yy, box_lo = spec$box_lo, box_hi = spec$box_hi))
  ppt <- read_pptx()
  ppt <- set_ppt_slide_size(ppt, width_in = SLIDE_W, height_in = SLIDE_H)
  ppt <- add_blank(ppt)
  ppt <- add_row_to_ppt(ppt, plots)
  box_lo_tag <- gsub("\\.", "p", as.character(spec$box_lo))
  box_hi_tag <- gsub("\\.", "p", as.character(spec$box_hi))
  base <- glue("figure2_modelB_{spec$xvar}_{spec$focus}_box_x{box_lo_tag}_{box_hi_tag}_panel6cm")
  print(ppt, target = file.path(OUT_DIR, paste0(base, ".pptx")))
  for (j in seq_along(plots)) {
    ggsave(
      filename = file.path(OUT_DIR, paste0(base, "_", Y_ORDER[j], ".png")),
      plot = plots[[j]], width = FIG_W, height = FIG_H, units = "in", dpi = 600, bg = "white"
    )
  }
}

message("[done] output_dir=", OUT_DIR)
for (xx in X_ORDER) {
  ss <- focus_specs %>% filter(.data$xvar == xx)
  message("[done] ", xx, " central90 box=", ss$box_lo[ss$focus == "central90"], "-", ss$box_hi[ss$focus == "central90"],
          "; central95 box=", ss$box_lo[ss$focus == "central95"], "-", ss$box_hi[ss$focus == "central95"])
}
