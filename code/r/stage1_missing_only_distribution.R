#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

argv <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  idx <- which(argv == flag)
  if (!length(idx)) return(default)
  i <- idx[length(idx)]
  if (i >= length(argv)) return(default)
  argv[i + 1]
}

csv_dir <- get_arg("--csv_dir", "/N/project/waveform_mortality/ZhaoZhang/data_ML_11_21_2025_final/final_processed")
csv_glob <- get_arg("--csv_glob", "*.csv")
ycol <- get_arg("--ycol", "rSO2_Ch1")
sec <- as.integer(get_arg("--sec", "1"))
subgroup_tag <- get_arg("--subgroup_tag", "All")
out_root <- get_arg("--out_root", "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/analysis_bundle/output/stage1_distribution_r")
flow_csv <- get_arg("--flow_csv", "")

if (!ycol %in% c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")) {
  stop("--ycol must be one of rSO2_Ch1, rSO2_Ch2, rSO2_Ch3")
}
if (is.na(sec) || sec < 1L) sec <- 1L

et_lo <- 20
et_hi <- 50
y_lo <- 25
y_hi <- 95

files <- Sys.glob(file.path(csv_dir, csv_glob))
if (!length(files)) {
  stop(sprintf("No input files: %s/%s", csv_dir, csv_glob))
}

need_cols <- c("stay_id", "obstime", "patient_ID", "ET_CO2", ycol)

read_one <- function(fp) {
  hdr <- tryCatch(names(fread(fp, nrows = 0L, showProgress = FALSE)), error = function(e) character(0))
  if (!length(hdr)) return(NULL)
  use <- intersect(need_cols, hdr)
  if (!all(c("patient_ID", "ET_CO2") %in% use)) return(NULL)
  dt <- tryCatch(fread(fp, select = use, showProgress = FALSE), error = function(e) NULL)
  if (is.null(dt)) return(NULL)
  miss_cols <- setdiff(c("patient_ID", "ET_CO2", ycol, "stay_id", "obstime"), names(dt))
  for (cc in miss_cols) dt[, (cc) := NA_real_]
  dt
}

d_list <- lapply(files, read_one)
d_list <- Filter(Negate(is.null), d_list)
if (!length(d_list)) {
  stop("No readable files with ET_CO2 and target outcome")
}

dt <- rbindlist(d_list, use.names = TRUE, fill = TRUE)

for (cc in intersect(c("ET_CO2", ycol, "obstime"), names(dt))) {
  suppressWarnings(dt[, (cc) := as.numeric(get(cc))])
}

if (sec > 1L && all(c("stay_id", "obstime") %in% names(dt))) {
  dt <- dt[!is.na(obstime)]
  dt[, bin_ := as.integer(floor(obstime / sec))]
  num_cols <- names(dt)[vapply(dt, is.numeric, logical(1))]
  num_cols <- setdiff(num_cols, "bin_")
  dt <- dt[, lapply(.SD, median, na.rm = TRUE), by = .(stay_id, bin_), .SDcols = num_cols]
  dt[, obstime := bin_ * sec]
  dt[, bin_ := NULL]
}

n_available <- nrow(dt)
stage1 <- dt[!is.na(ET_CO2) & !is.na(get(ycol))]
n_stage1 <- nrow(stage1)
n_excl <- n_available - n_stage1
p_excl <- if (n_available > 0) 100 * n_excl / n_available else NA_real_

# Optional: align counts to main pipeline filter_flow_counts.csv
if (nzchar(flow_csv) && file.exists(flow_csv)) {
  flow_dt <- tryCatch(fread(flow_csv), error = function(e) NULL)
  if (!is.null(flow_dt) && all(c("ycol", "stage", "n_rows") %in% names(flow_dt))) {
    ycol_name <- ycol
    raw_hit <- flow_dt[get("ycol") == ycol_name & get("stage") == "raw_timeseries_rows"][1]
    st1_hit <- flow_dt[get("ycol") == ycol_name & get("stage") == "after_required_etco2_y_nonmissing"][1]
    if (nrow(raw_hit) == 1L && nrow(st1_hit) == 1L &&
        is.finite(raw_hit$n_rows) && is.finite(st1_hit$n_rows)) {
      n_available <- as.integer(raw_hit$n_rows)
      n_stage1 <- as.integer(st1_hit$n_rows)
      n_excl <- n_available - n_stage1
      p_excl <- if (n_available > 0) 100 * n_excl / n_available else NA_real_
    }
  }
}

desc_one <- function(v, nm) {
  vv <- v[is.finite(v)]
  data.table(
    variable = nm,
    n_nonmissing_stage1 = length(vv),
    mean = if (length(vv)) mean(vv) else NA_real_,
    sd = if (length(vv) > 1L) sd(vv) else NA_real_,
    p01 = if (length(vv)) as.numeric(quantile(vv, 0.01, na.rm = TRUE)) else NA_real_,
    p05 = if (length(vv)) as.numeric(quantile(vv, 0.05, na.rm = TRUE)) else NA_real_,
    p50 = if (length(vv)) as.numeric(quantile(vv, 0.50, na.rm = TRUE)) else NA_real_,
    p95 = if (length(vv)) as.numeric(quantile(vv, 0.95, na.rm = TRUE)) else NA_real_,
    p99 = if (length(vv)) as.numeric(quantile(vv, 0.99, na.rm = TRUE)) else NA_real_
  )
}

summary_dt <- data.table(
  sec = sec,
  subgroup = subgroup_tag,
  ycol = ycol,
  n_available = n_available,
  n_excluded_missing = n_excl,
  pct_excluded_missing = p_excl,
  n_remained_stage1 = n_stage1,
  etco2_required_lo = et_lo,
  etco2_required_hi = et_hi,
  y_required_lo = y_lo,
  y_required_hi = y_hi
)

describe_dt <- rbind(
  desc_one(stage1$ET_CO2, "ET_CO2"),
  desc_one(stage1[[ycol]], ycol)
)

fig_dir <- file.path(out_root, "figures")
tab_dir <- file.path(out_root, "tables")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)

stem <- sprintf("%s_sec%s_%s_stage1_after_missing_only_r", ycol, sec, subgroup_tag)

fwrite(summary_dt, file.path(tab_dir, paste0(stem, "_summary.csv")))
fwrite(describe_dt, file.path(tab_dir, paste0(stem, "_describe.csv")))

y_lab <- switch(
  ycol,
  rSO2_Ch1 = "Left SctO2 (%)",
  rSO2_Ch2 = "Right SctO2 (%)",
  rSO2_Ch3 = "SftO2 (%)",
  ycol
)

plot_dt <- rbind(
  data.table(value = stage1$ET_CO2, panel = "ETCO2"),
  data.table(value = stage1[[ycol]], panel = ycol),
  fill = TRUE
)
plot_dt <- plot_dt[is.finite(value)]

thr_dt <- data.table(
  panel = c("ETCO2", "ETCO2", ycol, ycol),
  xint = c(et_lo, et_hi, y_lo, y_hi)
)

p <- ggplot(plot_dt, aes(x = value)) +
  geom_histogram(bins = 80, fill = "#9ecae1", color = "white") +
  geom_vline(data = thr_dt, aes(xintercept = xint), linetype = "dashed", color = "#d62728", linewidth = 0.5) +
  facet_wrap(
    ~panel,
    nrow = 1,
    scales = "free_x",
    labeller = as_labeller(c("ETCO2" = "ETCO2 (mmHg)", setNames(y_lab, ycol)))
  ) +
  labs(
    title = sprintf(
      "Stage-1 after missing exclusion | available=%s, excluded=%s (%.4f%%), remained=%s",
      format(n_available, big.mark = ","), format(n_excl, big.mark = ","), p_excl, format(n_stage1, big.mark = ",")
    ),
    x = NULL,
    y = "Count"
  ) +
  theme_bw(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

png_fp <- file.path(fig_dir, paste0(stem, ".png"))
pdf_fp <- file.path(fig_dir, paste0(stem, ".pdf"))
ggsave(png_fp, p, width = 12.5, height = 4.8, dpi = 200)
ggsave(pdf_fp, p, width = 12.5, height = 4.8)

cat(sprintf("WROTE %s\n", file.path(tab_dir, paste0(stem, "_summary.csv"))))
cat(sprintf("WROTE %s\n", file.path(tab_dir, paste0(stem, "_describe.csv"))))
cat(sprintf("WROTE %s\n", png_fp))
cat(sprintf("WROTE %s\n", pdf_fp))
