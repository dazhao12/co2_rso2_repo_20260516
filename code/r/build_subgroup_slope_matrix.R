suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
  library(officer)
  library(rvg)
  library(xml2)
})

ROOT_DIR <- normalizePath(Sys.getenv("CO2_PROJECT_ROOT", getwd()), winslash = "/", mustWork = FALSE)
OVERALL_CSV <- Sys.getenv(
  "SUBGROUP_MATRIX_OVERALL_CSV",
  file.path(
    ROOT_DIR,
    "hpc_r_format_outputs",
    "intraop5_slice_ppt_v20260611_184137_labels_overall",
    "plot_data_comparable_bar.csv"
  )
)
SUBGROUP_ROOT <- Sys.getenv(
  "SUBGROUP_MATRIX_SUBGROUP_ROOT",
  file.path(ROOT_DIR, "hpc_r_format_outputs", "intraop5_slice_ppt_v20260611_184224_labels_subgroup")
)
OUT_DIR <- Sys.getenv(
  "SUBGROUP_MATRIX_OUT_DIR",
  file.path(ROOT_DIR, "hpc_r_format_outputs", "subgroup_summary_demo_20260611_r")
)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

subgroup_labels <- c(
  "All" = "Overall",
  "Age_less_70" = "Age <70",
  "Age_more_70" = "Age >=70",
  "Female" = "Female",
  "Male" = "Male",
  "Pre_hypertension_less_140_90" = "Preop BP <140/90",
  "Pre_hypertension_more_140_90" = "Preop BP >=140/90"
)
row_levels <- c(
  "Overall", "Age <70", "Age >=70", "Female", "Male",
  "Preop BP <140/90", "Preop BP >=140/90"
)
y_levels <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
y_labels <- c(
  "rSO2_Ch1" = "Left~SctO[2]",
  "rSO2_Ch2" = "Right~SctO[2]",
  "rSO2_Ch3" = "SftO[2]"
)
x_levels <- c("ET_CO2", "TEMP", "FiO2_new")
x_labels <- c(
  "ET_CO2" = "atop(EtCO[2], '+5 mmHg')",
  "TEMP" = "atop(TEMP, '+0.5 '*degree*C)",
  "FiO2_new" = "atop(FiO[2], '+5%')"
)

read_compare_data <- function() {
  if (!file.exists(OVERALL_CSV)) stop("Overall CSV not found: ", OVERALL_CSV)
  overall <- suppressMessages(read_csv(OVERALL_CSV, show_col_types = FALSE))
  overall$subgroup <- "Overall"

  subgroup_csvs <- list.files(SUBGROUP_ROOT, pattern = "plot_data_comparable_bar\\.csv$", recursive = TRUE, full.names = TRUE)
  if (!length(subgroup_csvs)) stop("No subgroup plot_data_comparable_bar.csv files found under: ", SUBGROUP_ROOT)
  subgroup <- bind_rows(lapply(subgroup_csvs, function(fp) {
    d <- suppressMessages(read_csv(fp, show_col_types = FALSE))
    d$source_csv <- fp
    d
  }))
  mapped_subgroup <- unname(subgroup_labels[as.character(subgroup$subgroup)])
  subgroup$subgroup <- ifelse(is.na(mapped_subgroup), as.character(subgroup$subgroup), mapped_subgroup)

  bind_rows(overall, subgroup) %>%
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

build_matrix_data <- function(df, mode = c("raw", "delta")) {
  mode <- match.arg(mode)
  if (mode == "raw") {
    fill_min <- -0.5
    fill_max <- max(ceiling(stats::quantile(df$signed_est, 0.90, na.rm = TRUE) / 0.5) * 0.5, 0.5)
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
  fill_min <- -0.5
  fill_max <- 0.5
  d %>%
    mutate(
      fill_value = clip_range(.data$delta_overall, fill_min, fill_max),
      fill_min = fill_min,
      fill_max = fill_max
    )
}

theme_matrix <- function() {
  theme_minimal(base_size = 9.8) +
    theme(
      panel.grid = element_blank(),
      axis.title = element_blank(),
      axis.text.x = element_text(size = 9.8, colour = "black", lineheight = 0.95),
      axis.text.y = element_text(size = 9.8, colour = "black"),
      axis.ticks = element_blank(),
      strip.text = element_text(size = 11.8, colour = "black", face = "plain"),
      legend.title = element_text(size = 9.8, colour = "black"),
      legend.text = element_text(size = 9.2, colour = "black", margin = margin(l = 3, unit = "pt")),
      legend.box.margin = margin(0, 0, 0, 8, "pt"),
      legend.spacing.x = grid::unit(5, "pt"),
      plot.caption = element_text(size = 9.0, colour = "#444444", hjust = 0, lineheight = 1.15),
      plot.margin = margin(6, 0, 8, 6, "pt")
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
  by <- 0.5
  lo <- ceiling(fill_min / by) * by
  hi <- floor(fill_max / by) * by
  if (lo > hi) return(0)
  seq(lo, hi, by = by)
}

legend_labels <- function(x, mode) {
  if (identical(mode, "raw")) sprintf("%.1f", x) else sprintf("%.1f", x)
}

make_colorbar_legend <- function(fill_min, fill_max, mode, title) {
  fill_breaks <- legend_breaks(fill_min, fill_max, mode)
  ylim_pad <- 0.10 * (fill_max - fill_min)
  legend_steps <- 90
  bar_df <- data.frame(
    x = 1,
    y = seq(fill_min, fill_max, length.out = legend_steps)
  )
  bar_height <- (fill_max - fill_min) / (legend_steps - 1)
  tick_df <- data.frame(
    y = fill_breaks,
    label = legend_labels(fill_breaks, mode)
  )

  ggplot(bar_df, aes(x = .data$x, y = .data$y, fill = .data$y)) +
    geom_tile(width = 0.30, height = bar_height) +
    annotate(
      "rect",
      xmin = 0.85, xmax = 1.15, ymin = fill_min, ymax = fill_max,
      fill = NA, colour = "#333333", linewidth = 0.35
    ) +
    geom_segment(
      data = tick_df,
      aes(x = 1.15, xend = 1.24, y = .data$y, yend = .data$y),
      inherit.aes = FALSE,
      colour = "#333333", linewidth = 0.35
    ) +
    geom_text(
      data = tick_df,
      aes(x = 1.31, y = .data$y, label = .data$label),
      inherit.aes = FALSE,
      hjust = 0, size = 3.05, colour = "black"
    ) +
    annotate(
      "text",
      x = 1.92, y = 0, label = title,
      angle = 90, hjust = 0.5, vjust = 0.5, size = 3.3, colour = "black"
    ) +
    scale_fill_gradient2(
      low = "#2166AC", mid = "#F7F7F7", high = "#B85C1E",
      midpoint = 0, limits = c(fill_min, fill_max), guide = "none"
    ) +
    coord_cartesian(
      xlim = c(0.82, 2.05),
      ylim = c(fill_min - ylim_pad, fill_max + ylim_pad),
      expand = FALSE,
      clip = "off"
    ) +
    theme_void() +
    theme(plot.margin = margin(4, 2, 4, 0, "pt"))
}

combine_with_legend <- function(main_plot, legend_plot) {
  main_grob <- ggplotGrob(main_plot)
  legend_grob <- ggplotGrob(legend_plot)
  gt <- gtable::gtable(
    widths = grid::unit.c(grid::unit(1, "null"), grid::unit(0.56, "in")),
    heights = grid::unit(1, "null")
  )
  gt <- gtable::gtable_add_grob(gt, main_grob, t = 1, l = 1)
  gt <- gtable::gtable_add_grob(gt, legend_grob, t = 1, l = 2)
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
        .data$fill_value >= fill_max - 0.25 * (fill_max - fill_min) |
          .data$fill_value <= fill_min + 0.05 * (fill_max - fill_min),
        "white", "#222222"
      ))
  } else {
    d <- d %>%
      mutate(text_colour = if_else(abs(.data$fill_value) >= 0.75 * max(abs(fill_min), abs(fill_max)), "white", "#222222"))
  }
  legend_title <- if (mode == "raw") "Slope (% per clinical increment)" else "Difference vs overall"
  main_plot <- ggplot(d, aes(x = .data$x_label, y = .data$subgroup)) +
    geom_tile(
      aes(fill = .data$fill_value),
      width = 0.98, height = 0.98, colour = "white", linewidth = 0.70
    ) +
    geom_text(aes(label = .data$value_label, colour = .data$text_colour), size = 3.05) +
    facet_grid(. ~ ycol, labeller = label_parsed) +
    scale_fill_gradient2(
      low = "#2166AC", mid = "#F7F7F7", high = "#B85C1E",
      midpoint = 0, limits = c(fill_min, fill_max), guide = "none"
    ) +
    scale_x_discrete(drop = FALSE, labels = parse_plotmath_labels) +
    scale_colour_identity() +
    coord_fixed(ratio = 0.72, expand = FALSE) +
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
  ph_with(ppt, dml(code = grid::grid.draw(p)), location = ph_location(left = left, top = top, width = width, height = height))
}

df <- read_compare_data()
write_csv(df, file.path(OUT_DIR, "subgroup_slope_matrix_source.csv"))

p_raw <- plot_matrix(df, "raw")
p_delta <- plot_matrix(df, "delta")

ggsave(file.path(OUT_DIR, "subgroup_slope_matrix_raw_ggplot.png"), p_raw, width = 10.8, height = 5.7, dpi = 360, bg = "white", device = png_device)
ggsave(file.path(OUT_DIR, "subgroup_slope_matrix_raw_ggplot.pdf"), p_raw, width = 10.8, height = 5.7, bg = "white", device = pdf_device)
ggsave(file.path(OUT_DIR, "subgroup_slope_matrix_delta_ggplot.png"), p_delta, width = 10.8, height = 5.7, dpi = 360, bg = "white", device = png_device)
ggsave(file.path(OUT_DIR, "subgroup_slope_matrix_delta_ggplot.pdf"), p_delta, width = 10.8, height = 5.7, bg = "white", device = pdf_device)

ppt <- read_pptx()
ppt <- set_ppt_slide_size(ppt, 13.333333, 7.5)
ppt <- add_blank(ppt)
ppt <- add_full_plot(ppt, p_raw)
ppt <- add_blank(ppt)
ppt <- add_full_plot(ppt, p_delta)
ppt_path <- file.path(OUT_DIR, "subgroup_slope_matrix_editable_ggplot.pptx")
print(ppt, target = ppt_path)

message("[done] ", ppt_path)
