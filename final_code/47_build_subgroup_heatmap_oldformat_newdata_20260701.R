suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
  library(officer)
  library(rvg)
  library(xml2)
})

ROOT_DIR <- normalizePath(Sys.getenv("CO2_PROJECT_ROOT", getwd()), winslash = "/", mustWork = FALSE)
cm_to_in <- function(cm) cm / 2.54
SOURCE_CSV <- Sys.getenv(
  "SUBGROUP_MATRIX_SOURCE_CSV",
  file.path(
    ROOT_DIR,
    "hpc_r_format_outputs",
    "subgroup_heatmap_table1_table2_20260701",
    "subgroup_table1_clinical_increment_mean_95ci.csv"
  )
)
LABEL_MODE <- Sys.getenv("SUBGROUP_MATRIX_LABEL_MODE", "clinical")
RAW_ONLY <- Sys.getenv("SUBGROUP_MATRIX_RAW_ONLY", "0") %in% c("1", "true", "TRUE", "yes", "YES")
MATRIX_FILL_LOW <- Sys.getenv("SUBGROUP_MATRIX_FILL_LOW", "#0057B8")
MATRIX_FILL_MID <- Sys.getenv("SUBGROUP_MATRIX_FILL_MID", "#FFFFFF")
MATRIX_FILL_HIGH <- Sys.getenv("SUBGROUP_MATRIX_FILL_HIGH", "#FD5002")
MATRIX_WIDTH_CM <- 18
MATRIX_ROW_HEIGHT_CM <- 0.82
MATRIX_EXTRA_HEIGHT_CM <- 2.5
MATRIX_MIN_HEIGHT_CM <- 8.2
MATRIX_WIDTH_IN <- cm_to_in(MATRIX_WIDTH_CM)

OVERALL_CSV <- Sys.getenv(
  "SUBGROUP_MATRIX_OVERALL_CSV",
  file.path(
    ROOT_DIR,
    "Final_manuscript_6_12_2026",
    "final_plot_code_results_20260616_6cm_update",
    "results",
    "table_inputs_bootdiff_20260616",
    "table1_overall_clinical_step_effect_summary.csv"
  )
)
SUBGROUP_CSV <- Sys.getenv(
  "SUBGROUP_MATRIX_SUBGROUP_CSV",
  file.path(
    ROOT_DIR,
    "Final_manuscript_6_12_2026",
    "final_plot_code_results_20260616_6cm_update",
    "results",
    "table_inputs_bootdiff_20260616",
    "supplement_subgroup_clinical_step_effect_summary.csv"
  )
)
OUT_DIR <- Sys.getenv(
  "SUBGROUP_MATRIX_OUT_DIR",
  file.path(
    ROOT_DIR,
    "hpc_r_format_outputs",
    "subgroup_heatmap_table1_table2_20260701",
    "oldformat_table1_clinical_increment"
  )
)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

subgroup_labels <- c(
  "All" = "Overall",
  "Age_less_70" = "Age <70 year",
  "Age_more_70" = "Age \u226570 year",
  "Female" = "Female",
  "Male" = "Male",
  "Pre_hypertension_less_140_90" = "Preop BP\n<140/90 mmHg",
  "Pre_hypertension_more_140_90" = "Preop BP\n\u2265140/90 mmHg"
)
row_levels <- c(
  "Overall", "Age <70 year", "Age \u226570 year", "Female", "Male",
  "Preop BP\n<140/90 mmHg", "Preop BP\n\u2265140/90 mmHg"
)
MATRIX_AXIS_Y_SIZE <- if (max(nchar(row_levels), na.rm = TRUE) >= 22) 8.2 else 9.2
MATRIX_AXIS_X_SIZE <- 7.8
MATRIX_STRIP_SIZE <- 10.4
MATRIX_VALUE_SIZE <- 2.85
MATRIX_LEGEND_TEXT_SIZE <- 8.2
MATRIX_LEGEND_TITLE_SIZE <- 8.8
MATRIX_LEGEND_Y_PAD_FRAC <- suppressWarnings(as.numeric(Sys.getenv("SUBGROUP_MATRIX_LEGEND_Y_PAD_FRAC", "0.17")))
if (is.na(MATRIX_LEGEND_Y_PAD_FRAC)) MATRIX_LEGEND_Y_PAD_FRAC <- 0.17
MATRIX_LEGEND_Y_SHIFT <- suppressWarnings(as.numeric(Sys.getenv("SUBGROUP_MATRIX_LEGEND_Y_SHIFT", "0")))
if (is.na(MATRIX_LEGEND_Y_SHIFT)) MATRIX_LEGEND_Y_SHIFT <- 0
MATRIX_LEGEND_OVERLAP_CM <- suppressWarnings(as.numeric(Sys.getenv("SUBGROUP_MATRIX_LEGEND_OVERLAP_CM", "0")))
if (is.na(MATRIX_LEGEND_OVERLAP_CM)) MATRIX_LEGEND_OVERLAP_CM <- 0
MATRIX_FILL_MIN <- -0.5
MATRIX_FILL_MAX <- as.numeric(Sys.getenv("SUBGROUP_MATRIX_FILL_MAX", "3.0"))
MATRIX_TILE_BORDER <- "white"
MATRIX_PANEL_BORDER <- "#5F5F5F"
PLOT_FONT_FAMILY <- "sans"
PPT_FONT_FAMILY <- "Aptos"
y_levels <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
y_labels <- c(
  "rSO2_Ch1" = "Left~SctO[2]",
  "rSO2_Ch2" = "Right~SctO[2]",
  "rSO2_Ch3" = "SftO[2]"
)
x_levels <- c("ET_CO2", "FiO2_new", "TEMP")
if (identical(LABEL_MODE, "range")) {
  x_labels <- c(
    "ET_CO2" = "EtCO[2]",
    "TEMP" = "TEMP",
    "FiO2_new" = "FiO[2]"
  )
} else {
  x_labels <- c(
    "ET_CO2" = "atop(EtCO[2], '(+5 mmHg)')",
    "TEMP" = "atop(TEMP, paste('(+0.5 ', degree, 'C)'))",
    "FiO2_new" = "atop(FiO[2], '(+10 %)')"
  )
}

read_compare_data <- function() {
  if (!file.exists(SOURCE_CSV)) stop("Source CSV not found: ", SOURCE_CSV)

  combined <- suppressMessages(read_csv(SOURCE_CSV, show_col_types = FALSE)) %>%
    transmute(
      subgroup = as.character(.data$subgroup),
      source_csv = SOURCE_CSV,
      ycol = recode(
        as.character(.data$ycol),
        "Left SctO\u2082" = "rSO2_Ch1",
        "Right SctO\u2082" = "rSO2_Ch2",
        "SftO\u2082" = "rSO2_Ch3"
      ),
      xvar = as.character(.data$xvar),
      signed_est = as.numeric(.data$mean),
      signed_lo = as.numeric(.data$lo95),
      signed_hi = as.numeric(.data$hi95)
    )
  mapped_subgroup <- unname(subgroup_labels[as.character(combined$subgroup)])
  combined$subgroup <- ifelse(is.na(mapped_subgroup), as.character(combined$subgroup), mapped_subgroup)

  if ("signed_effect_median" %in% names(combined)) {
    combined <- combined %>%
      mutate(
        signed_est = as.numeric(.data$signed_effect_median),
        signed_lo = as.numeric(.data$signed_effect_q25),
        signed_hi = as.numeric(.data$signed_effect_q75)
      )
  }

  combined %>%
    mutate(
      subgroup = as.character(.data$subgroup),
      ycol = as.character(.data$ycol),
      xvar = as.character(.data$xvar),
      signed_est = as.numeric(.data$signed_est),
      signed_lo = as.numeric(.data$signed_lo),
      signed_hi = as.numeric(.data$signed_hi)
    ) %>%
    filter(
      .data$subgroup %in% row_levels,
      .data$ycol %in% y_levels,
      .data$xvar %in% x_levels,
      is.finite(.data$signed_est)
    ) %>%
    mutate(
      subgroup = factor(.data$subgroup, levels = rev(row_levels)),
      ycol = factor(.data$ycol, levels = y_levels, labels = unname(y_labels[y_levels])),
      xvar = factor(.data$xvar, levels = x_levels),
      x_label = factor(unname(x_labels[as.character(.data$xvar)]), levels = unname(x_labels[x_levels])),
      iqr_status = if_else(.data$signed_lo <= 0 & .data$signed_hi >= 0, "IQR crosses 0", "IQR excludes 0"),
      value_label = if_else(abs(.data$signed_est) >= 0.01, sprintf("%.2f", .data$signed_est), sprintf("%.3f", .data$signed_est))
    )
}

clip_range <- function(x, lower, upper) pmax(pmin(x, upper), lower)

nice_bounds <- function(x, n = 5) {
  b <- pretty(x[is.finite(x)], n = n)
  b <- b[is.finite(b)]
  if (!length(b)) return(c(-0.5, 0.5))
  c(min(b), max(b))
}

build_matrix_data <- function(df, mode = c("raw", "delta")) {
  mode <- match.arg(mode)
  if (mode == "raw") {
    fill_min <- MATRIX_FILL_MIN
    fill_max <- MATRIX_FILL_MAX
    return(df %>%
      mutate(
        fill_value = clip_range(.data$signed_est, fill_min, fill_max),
        fill_min = fill_min,
        fill_max = fill_max
      ))
  }

  overall_ref <- df %>%
    filter(as.character(.data$subgroup) == "Overall") %>%
    transmute(ycol = as.character(.data$ycol), xvar = as.character(.data$xvar), overall_est = .data$signed_est)
  d <- df %>%
    left_join(overall_ref, by = c("ycol", "xvar")) %>%
    mutate(delta_overall = .data$signed_est - .data$overall_est)
  delta_vals <- d$delta_overall[as.character(d$subgroup) != "Overall"]
  fill_bounds <- nice_bounds(c(0, delta_vals), n = 5)
  fill_min <- fill_bounds[1]
  fill_max <- fill_bounds[2]
  d %>%
    mutate(
      fill_value = clip_range(.data$delta_overall, fill_min, fill_max),
      fill_min = fill_min,
      fill_max = fill_max
    )
}

theme_matrix <- function() {
  theme_minimal(base_size = 9.0, base_family = PLOT_FONT_FAMILY) +
    theme(
      panel.grid = element_blank(),
      axis.title = element_blank(),
      text = element_text(family = PLOT_FONT_FAMILY),
      axis.text.x = element_text(size = MATRIX_AXIS_X_SIZE, colour = "black", lineheight = 0.88, hjust = 0.5, margin = margin(t = 3.5, unit = "pt"), family = PLOT_FONT_FAMILY),
      axis.text.y = element_text(size = MATRIX_AXIS_Y_SIZE, colour = "black", hjust = 1, margin = margin(r = 4, unit = "pt"), family = PLOT_FONT_FAMILY),
      axis.ticks = element_line(colour = "#5F5F5F", linewidth = 0.35),
      axis.ticks.length = grid::unit(2.0, "pt"),
      strip.text = element_text(size = MATRIX_STRIP_SIZE, colour = "black", face = "plain", family = PLOT_FONT_FAMILY),
      panel.border = element_rect(colour = MATRIX_PANEL_BORDER, fill = NA, linewidth = 0.35),
      panel.spacing.x = grid::unit(7, "pt"),
      legend.title = element_text(size = MATRIX_LEGEND_TITLE_SIZE, colour = "black", family = PLOT_FONT_FAMILY),
      legend.text = element_text(size = MATRIX_LEGEND_TEXT_SIZE, colour = "black", margin = margin(l = 3, unit = "pt"), family = PLOT_FONT_FAMILY),
      legend.box.margin = margin(0, 0, 0, 4, "pt"),
      legend.spacing.x = grid::unit(5, "pt"),
      plot.caption = element_text(size = 8.0, colour = "#444444", hjust = 0, lineheight = 1.10, family = PLOT_FONT_FAMILY),
      plot.margin = margin(6, 2, 8, 6, "pt")
    )
}

png_device <- function(filename, width, height, units = "in", dpi = 360, ...) {
  if (isTRUE(capabilities("cairo"))) {
    grDevices::png(filename, width = width, height = height, units = units, res = dpi, type = "cairo", ...)
  } else {
    grDevices::png(filename, width = width, height = height, units = units, res = dpi, ...)
  }
}

pdf_device <- if (isTRUE(capabilities("cairo"))) grDevices::cairo_pdf else grDevices::pdf

parse_plotmath_labels <- function(labels) {
  parse(text = as.character(labels))
}

legend_breaks <- function(fill_min, fill_max, mode) {
  if (identical(mode, "raw")) {
    raw_tick_by <- suppressWarnings(as.numeric(Sys.getenv("SUBGROUP_MATRIX_RAW_TICK_BY", NA_character_)))
    by <- if (is.finite(raw_tick_by)) raw_tick_by else if ((fill_max - fill_min) >= 5) 1 else 0.5
    lo <- ceiling(fill_min / by) * by
    hi <- floor(fill_max / by) * by
    if (lo > hi) return(0)
    return(seq(lo, hi, by = by))
  }
  b <- pretty(c(fill_min, fill_max), n = 5)
  b[b >= fill_min & b <= fill_max]
}

legend_labels <- function(x, mode) {
  if (identical(mode, "raw")) sprintf("%.1f", x) else sprintf("%.1f", x)
}

make_colorbar_legend <- function(fill_min, fill_max, mode, title) {
  title_parse <- grepl("\\[|\\(|~|paste", title)
  fill_breaks <- legend_breaks(fill_min, fill_max, mode)
  ylim_pad <- MATRIX_LEGEND_Y_PAD_FRAC * (fill_max - fill_min)
  legend_steps <- 90
  bar_height <- (fill_max - fill_min) / legend_steps
  bar_df <- data.frame(
    x = 0.67,
    y = seq(fill_min + bar_height / 2, fill_max - bar_height / 2, length.out = legend_steps),
    fill_value = seq(fill_min, fill_max, length.out = legend_steps)
  )
  tick_df <- data.frame(
    y = fill_breaks,
    label = legend_labels(fill_breaks, mode)
  )

  ggplot(bar_df, aes(x = .data$x, y = .data$y, fill = .data$fill_value)) +
    geom_tile(width = 0.30, height = bar_height) +
    annotate(
      "rect",
      xmin = 0.52, xmax = 0.82, ymin = fill_min, ymax = fill_max,
      fill = NA, colour = "#333333", linewidth = 0.35
    ) +
    geom_segment(
      data = tick_df,
      aes(x = 0.82, xend = 0.91, y = .data$y, yend = .data$y),
      inherit.aes = FALSE,
      colour = "#333333", linewidth = 0.35
    ) +
    geom_text(
      data = tick_df,
      aes(x = 0.98, y = .data$y, label = .data$label),
      inherit.aes = FALSE,
      hjust = 0, size = 2.75, colour = "black", family = PLOT_FONT_FAMILY
    ) +
    annotate(
      "text",
      x = 1.72, y = (fill_min + fill_max) / 2, label = title,
      angle = 90, hjust = 0.5, vjust = 0.5, size = 2.95, colour = "black",
      parse = title_parse, family = PLOT_FONT_FAMILY
    ) +
    scale_fill_gradient2(
      low = MATRIX_FILL_LOW, mid = MATRIX_FILL_MID, high = MATRIX_FILL_HIGH,
      midpoint = 0, limits = c(fill_min, fill_max), guide = "none"
    ) +
    coord_cartesian(
      xlim = c(0.48, 1.76),
      ylim = c(fill_min - ylim_pad - MATRIX_LEGEND_Y_SHIFT, fill_max + ylim_pad - MATRIX_LEGEND_Y_SHIFT),
      expand = FALSE,
      clip = "off"
    ) +
    theme_void(base_family = PLOT_FONT_FAMILY) +
    theme(plot.margin = margin(4, 2, 4, 0, "pt"))
}

combine_with_legend <- function(main_plot, legend_plot) {
  main_grob <- ggplotGrob(main_plot)
  legend_grob <- ggplotGrob(legend_plot)
  gt <- gtable::gtable(
    widths = grid::unit.c(
      grid::unit(1, "null"),
      grid::unit(-MATRIX_LEGEND_OVERLAP_CM, "cm"),
      grid::unit(0.46, "in")
    ),
    heights = grid::unit(1, "null")
  )
  gt <- gtable::gtable_add_grob(gt, main_grob, t = 1, l = 1)
  gt <- gtable::gtable_add_grob(gt, legend_grob, t = 1, l = 3)
  gt
}

plot_matrix <- function(df, mode = c("raw", "delta")) {
  mode <- match.arg(mode)
  d <- build_matrix_data(df, mode)
  fill_min <- unique(d$fill_min)[1]
  fill_max <- unique(d$fill_max)[1]
  if (identical(mode, "raw")) {
    d <- d %>%
      mutate(text_colour = if_else(
        .data$fill_value >= fill_max - 0.25 * (fill_max - fill_min),
        "white", "#222222"
      ))
  } else {
    d <- d %>%
      mutate(text_colour = if_else(abs(.data$fill_value) >= 0.75 * max(abs(fill_min), abs(fill_max)), "white", "#222222"))
  }
  legend_title <- if (mode == "raw") "paste('Adjusted Tissue O'[2], ' Change (%)')" else "Difference vs overall"
  main_plot <- ggplot(d, aes(x = .data$x_label, y = .data$subgroup)) +
    geom_tile(
      aes(fill = .data$fill_value),
      width = 0.98, height = 0.98, colour = MATRIX_TILE_BORDER, linewidth = 0.70
    ) +
    geom_text(aes(label = .data$value_label, colour = .data$text_colour), size = MATRIX_VALUE_SIZE, family = PLOT_FONT_FAMILY) +
    facet_grid(. ~ ycol, labeller = label_parsed) +
    scale_fill_gradient2(
      low = MATRIX_FILL_LOW, mid = MATRIX_FILL_MID, high = MATRIX_FILL_HIGH,
      midpoint = 0, limits = c(fill_min, fill_max), guide = "none"
    ) +
    scale_x_discrete(drop = FALSE, labels = parse_plotmath_labels) +
    scale_colour_identity() +
    coord_fixed(ratio = 0.66, expand = FALSE) +
    theme_matrix()

  combine_with_legend(main_plot, make_colorbar_legend(fill_min, fill_max, mode, legend_title))
}

set_ppt_slide_size <- function(ppt, width_in, height_in) {
  doc <- ppt$presentation$get()
  ns <- xml_ns(doc)
  sld_sz <- xml_find_first(doc, "//p:sldSz", ns = ns)
  if (!inherits(sld_sz, "xml_missing")) {
    xml_set_attr(sld_sz, "cx", as.character(round(width_in * 914400)))
    xml_set_attr(sld_sz, "cy", as.character(round(height_in * 914400)))
    xml_set_attr(sld_sz, "type", "wide")
  }
  ppt
}

add_blank <- function(ppt) add_slide(ppt, layout = "Blank", master = layout_summary(ppt)$master[1])
add_full_plot <- function(ppt, p, left = 0.45, top = 0.35, width = 12.45, height = 6.75) {
  ph_with(
    ppt,
    dml(code = grid::grid.draw(p), fonts = list(sans = PPT_FONT_FAMILY, serif = PPT_FONT_FAMILY, mono = PPT_FONT_FAMILY)),
    location = ph_location(left = left, top = top, width = width, height = height)
  )
}

matrix_height_in <- function(df) {
  n_rows <- length(unique(as.character(df$subgroup)))
  cm_to_in(max(MATRIX_MIN_HEIGHT_CM, MATRIX_EXTRA_HEIGHT_CM + MATRIX_ROW_HEIGHT_CM * n_rows))
}

df <- read_compare_data()
write_csv(df, file.path(OUT_DIR, "subgroup_slope_matrix_source.csv"))

p_raw <- plot_matrix(df, "raw")
p_delta <- if (RAW_ONLY) NULL else plot_matrix(df, "delta")
MATRIX_HEIGHT_IN <- matrix_height_in(df)
MATRIX_SLIDE_W_IN <- MATRIX_WIDTH_IN + cm_to_in(1.2)
MATRIX_SLIDE_H_IN <- MATRIX_HEIGHT_IN + cm_to_in(1.1)
MATRIX_LEFT_IN <- (MATRIX_SLIDE_W_IN - MATRIX_WIDTH_IN) / 2
MATRIX_TOP_IN <- (MATRIX_SLIDE_H_IN - MATRIX_HEIGHT_IN) / 2

ggsave(file.path(OUT_DIR, "subgroup_slope_matrix_raw_18cm_ggplot.png"), p_raw, width = MATRIX_WIDTH_IN, height = MATRIX_HEIGHT_IN, dpi = 360, bg = "white", device = png_device)
ggsave(file.path(OUT_DIR, "subgroup_slope_matrix_raw_18cm_ggplot.pdf"), p_raw, width = MATRIX_WIDTH_IN, height = MATRIX_HEIGHT_IN, bg = "white", device = pdf_device)
if (!RAW_ONLY) {
  ggsave(file.path(OUT_DIR, "subgroup_slope_matrix_delta_18cm_ggplot.png"), p_delta, width = MATRIX_WIDTH_IN, height = MATRIX_HEIGHT_IN, dpi = 360, bg = "white", device = png_device)
  ggsave(file.path(OUT_DIR, "subgroup_slope_matrix_delta_18cm_ggplot.pdf"), p_delta, width = MATRIX_WIDTH_IN, height = MATRIX_HEIGHT_IN, bg = "white", device = pdf_device)
}

ppt <- read_pptx()
ppt <- set_ppt_slide_size(ppt, MATRIX_SLIDE_W_IN, MATRIX_SLIDE_H_IN)
ppt <- add_blank(ppt)
ppt <- add_full_plot(ppt, p_raw, left = MATRIX_LEFT_IN, top = MATRIX_TOP_IN, width = MATRIX_WIDTH_IN, height = MATRIX_HEIGHT_IN)
if (!RAW_ONLY) {
  ppt <- add_blank(ppt)
  ppt <- add_full_plot(ppt, p_delta, left = MATRIX_LEFT_IN, top = MATRIX_TOP_IN, width = MATRIX_WIDTH_IN, height = MATRIX_HEIGHT_IN)
}
ppt_path <- file.path(OUT_DIR, "subgroup_slope_matrix_editable_18cm_ggplot.pptx")
print(ppt, target = ppt_path)

message("[done] ", ppt_path)
