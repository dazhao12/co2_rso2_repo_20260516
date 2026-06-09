#!/usr/bin/env Rscript
# ================================================================
#  v1.2 - 在 v1.1 基础上，允许通过开关单独只做 Violin Plot
#  v1.2.1 - 数据源改为 model_ready_cache/df_clean_{ycol}_1s.parquet
#           与 Python v2.6 建模数据完全一致（已做 dropna + 分位数过滤）
#           参考: slice_individual_PLOT_v98.2_final_2_11_2026.R
#
#  改动：
#    - 新增：从原始 parquet 数据中筛选 MAP/CI 条件，做小提琴图
#    - 四种方案：
#      S1: MAP exact,   CI exact (=2.5)
#      S2: MAP exact,   CI ± 0.2
#      S3: MAP ± 5,     CI exact (=2.5)
#      S4: MAP ± 5,     CI ± 0.2
#    - 图形细长，X轴宽，防止小提琴叠在一起
#  基于：切片图_fianl_v1_chang_ci_range_12_28_2025.R
#  解决问题：可视化不同MAP水平下组织氧的分布
# ================================================================

suppressPackageStartupMessages({
    library(data.table)
    library(readr)
    library(readxl)
    library(dplyr)
    library(ggplot2)
    library(glue)
    library(fs)
    library(officer)
    library(rvg)
    library(scales)
    library(grid)
    library(arrow)
})

`%||%` <- function(a, b) if (!is.null(a)) a else b

# =========================
# 0) FONT (Aptos)
# =========================
FONT_PRIMARY <- "Aptos"
FONT_FALLBACK <- "Arial"
FONT_STRICT <- FALSE

has_font <- function(family) {
    out <- tryCatch(system2("fc-list", stdout = TRUE, stderr = TRUE), error = function(e) character(0))
    if (!length(out)) {
        return(FALSE)
    }
    any(grepl(family, out, ignore.case = TRUE))
}

if (has_font(FONT_PRIMARY)) {
    BASE_FAMILY <- FONT_PRIMARY
    message("[font] Using: ", BASE_FAMILY)
} else {
    msg <- paste0("[font] NOT FOUND: ", FONT_PRIMARY, " (fc-list). ")
    if (FONT_STRICT) stop(msg, "Please run: fc-cache -f ~/.local/share/fonts and re-login.")
    BASE_FAMILY <- FONT_FALLBACK
    message(msg, "Fallback to: ", BASE_FAMILY)
}

# =========================
# 1) ROOTS / CONFIG
# =========================

SUBGROUPS_ROOT <- "/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result"
if (!dir_exists(SUBGROUPS_ROOT)) stop("SUBGROUPS_ROOT 不存在：", SUBGROUPS_ROOT)

EXPORT_DIR_BASE <- "/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/fig_output/R_slice_plus_slope_final_1_17_2025"
dir_create(EXPORT_DIR_BASE, recurse = TRUE)

CHANNELS <- c("rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3")
SEC <- 1

FIXED_MAP_VALUES <- c(60, 70, 80, 90, 100)
FIXED_CI_VALUES <- c(2.0, 2.5, 3.0, 3.5, 4.0)

SHOW_LEGEND <- TRUE
SHOW_CI_BAND <- TRUE
SHOW_SLOPE_ERRBAR <- FALSE

# =========================
# 1.1) FEATURE TOGGLES  ✅ 新增开关
# =========================
ENABLE_SLICE_PLOT <- FALSE # 是否绘制切片图
ENABLE_SLOPE_PLOT <- FALSE # 是否绘制斜率图

# =========================
# 1.1a) SELECT MODE
# =========================
SELECT_MODE <- "file"
SELECT_FILE <- "/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result/selected_outdirs_legacy_snapshot_20260320.txt"
SELECT_REGEX <- "12_19_slurm_.*232159"
EXCLUDE_SUBGROUP_OUTDIRS <- TRUE # TRUE=只保留主分析目录（过滤掉 .../subgroups/...）
PRIMARY_OUTDIR_PATTERN <- "12_19_slurm_fnal_chang_axis_20260303_113357" # 只保留主分析目录；设为 "" 可关闭

# =========================
# 1.2) VIOLIN CONFIG  ✅ 新增
# =========================
# ✅ 数据源：Python v2.6 生成的建模数据缓存（按通道分文件）
# 文件格式: df_clean_{ycol}_{sec}s.parquet
# 与 Python 建模输入数据完全一致（已 dropna + 分位数过滤）
MODEL_READY_CACHE_ROOT <- "/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result_archive/legacy_snapshot/2026-03-20/model_ready_cache"
VIOLIN_SEC <- 1 # 秒数，对应 df_clean_{ycol}_{VIOLIN_SEC}s.parquet
STRICT_MODEL_READY_ONLY <- TRUE # TRUE=必须使用 model_ready；不存在即报错

# MAP 三个分箱（用于小提琴图）
VIOLIN_MAP_BIN_LEVELS <- c("MAP <= 70 mmHg", "70 < MAP <= 100 mmHg", "MAP > 100 mmHg")
VIOLIN_MAP_BIN_TICKS <- c("≤ 70", "70-100", "> 100")
# CI 三个分箱（与 slope 分段一致）
VIOLIN_CI_BIN_LEVELS <- c("CI <= 2.8 L/min/m²", "2.8 < CI <= 4.2 L/min/m²", "CI > 4.2 L/min/m²")
VIOLIN_CI_BIN_TICKS <- c("≤ 2.8", "2.8-4.2", "> 4.2")

# 小提琴图两种展示方案
VIOLIN_SHOW_STYLE1_GROUPS_ON_X <- TRUE # 方案1：X轴显示3个bin
VIOLIN_SHOW_STYLE2_LEGEND_ONLY <- FALSE # 方案2：X轴仅标题，bin信息走图例

# 小提琴图尺寸：与 slope 图一致（9 x 8 cm）
VIOLIN_FIG_W_CM <- 9
VIOLIN_FIG_H_CM <- 8
cm_to_in <- function(cm) cm / 2.54
VIOLIN_FIG_W <- cm_to_in(VIOLIN_FIG_W_CM)
VIOLIN_FIG_H <- cm_to_in(VIOLIN_FIG_H_CM)

# =========================
# Legend position (shared)
# =========================
LEGEND_POS_INNER <- c(0.02, 0.98)
LEGEND_JUST_INNER <- c(0, 1)

# =========================
# 2) STYLE
# =========================
AXIS_LABEL_FONTSIZE <- 12
TICK_FONTSIZE <- 10
LEGEND_FONTSIZE <- 9

# 小提琴图字号（与 slope 图一致）
VIOLIN_AXIS_TITLE_SIZE <- AXIS_LABEL_FONTSIZE
VIOLIN_AXIS_TEXT_SIZE <- TICK_FONTSIZE
VIOLIN_SUBTITLE_SIZE <- TICK_FONTSIZE

# Y=60 临床阈值线设置
VIOLIN_HLINE_Y <- 60 # 组织氧臨值
VIOLIN_HLINE_COLOR <- "#D62728" # 红色
VIOLIN_HLINE_LWD <- 0.8 # 线宽
VIOLIN_HLINE_LTY <- "dashed" # 虽线
VIOLIN_PLOT_MAX_N <- 600000 # 仅用于绘图的总抽样上限（分层抽样；统计仍用全量）
SLOPE_BIN_ALPHA <- 0.7 # 与 slope 和 violin 共用透明度
VIOLIN_OUTLINE_LWD <- 0.6 # 小提琴外框线宽（贴近 slope 视觉粗细）
VIOLIN_DENSITY_ADJUST <- 1.8 # 小提琴密度平滑系数（越大越平滑）
VIOLIN_DENSITY_N <- 2048 # 密度曲线采样点数（越大边缘越平滑）
VIOLIN_X_TITLE_MARGIN_PT <- 10 # X轴标题与刻度的间距
VIOLIN_BOX_LWD <- 0.5 # 中间箱线图线宽
VIOLIN_MEDIAN_SIZE <- 1.6 # 中位数点大小
VIOLIN_Y_BREAKS <- c(50, 60, 70, 80, 90) # 显示50和90
VIOLIN_Y_LIMS <- c(50, 90)

FIG_W_CM <- 9
FIG_H_CM <- 8
FIG_W <- cm_to_in(FIG_W_CM)
FIG_H <- cm_to_in(FIG_H_CM)

AXIS_COLOR <- "#616161"
AXIS_LINEWIDTH <- 0.7
AXIS_TICK_LEN_PT <- 6

PLOT_MARGIN_PT <- 5.5

X_PAD_FRAC_CI <- 0.01
X_PAD_FRAC_MAP <- 0.01
pad_limits <- function(lims, frac = 0.02) {
    w <- diff(lims)
    c(lims[1] - w * frac, lims[2] + w * frac)
}

TOL_SCI_10 <- c(
    "#332288", "#117733", "#44AA99", "#88CCEE", "#DDCC77",
    "#CC6677", "#AA4499", "#882255", "#6699CC", "#999933"
)
pick_palette <- function(n) {
    idx <- round(seq(1, length(TOL_SCI_10), length.out = n))
    TOL_SCI_10[idx]
}

PRETTY_LABELS <- c(
    "MAP"      = "Mean Arterial Pressure (mmHg)",
    "CI"       = "Cardiac Index (L/min/m\u00B2)",
    "rSO2_Ch1" = "Left SctO\u2082 (%)",
    "rSO2_Ch2" = "Right SctO\u2082 (%)",
    "rSO2_Ch3" = "SftO\u2082 (%)"
)
pretty_lab <- function(x) ifelse(x %in% names(PRETTY_LABELS), PRETTY_LABELS[[x]], x)

theme_clean <- function() {
    theme_classic(
        base_size = TICK_FONTSIZE,
        base_family = BASE_FAMILY
    ) +
        theme(
            panel.background = element_rect(fill = "white", colour = NA),
            plot.background = element_rect(fill = "white", colour = NA),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            axis.title = element_text(size = AXIS_LABEL_FONTSIZE, colour = "black"),
            axis.text = element_text(size = TICK_FONTSIZE, colour = "black"),
            axis.line = element_line(linewidth = AXIS_LINEWIDTH, colour = AXIS_COLOR),
            axis.ticks = element_line(linewidth = AXIS_LINEWIDTH, colour = AXIS_COLOR),
            axis.ticks.length = unit(AXIS_TICK_LEN_PT, "pt"),
            legend.title = element_blank(),
            legend.text = element_text(size = LEGEND_FONTSIZE),
            plot.margin = margin(PLOT_MARGIN_PT, PLOT_MARGIN_PT, PLOT_MARGIN_PT, PLOT_MARGIN_PT, unit = "pt")
        )
}

x_axis_spec <- function(vary_name) {
    if (vary_name == "MAP") {
        lims0 <- c(45, 124)
        list(
            lims = pad_limits(lims0, X_PAD_FRAC_MAP),
            breaks = seq(50, 120, 10),
            lab = scales::label_number(accuracy = 1)
        )
    } else if (vary_name == "CI") {
        lims0 <- c(1.1, 5.4)
        list(
            lims = pad_limits(lims0, X_PAD_FRAC_CI),
            breaks = seq(1.5, 5.0, 0.5),
            lab = function(x) sprintf("%.1f", x)
        )
    } else {
        list(lims = NULL, breaks = waiver(), lab = waiver())
    }
}

legend_label <- function(fixed_axis, v) {
    if (fixed_axis == "CI") {
        paste0("CI = ", formatC(v, digits = 1, format = "f"), " L/min/m\u00B2")
    } else if (fixed_axis == "MAP") {
        paste0("MAP = ", formatC(v, digits = 0, format = "f"), " mmHg")
    } else {
        stop("fixed_axis 必须是 'MAP' 或 'CI'")
    }
}

palette_for_fixed_values <- function(fixed_axis, values_sorted) {
    labs <- legend_label(fixed_axis, values_sorted)
    pal <- pick_palette(length(labs))
    names(pal) <- labs
    pal
}

# =========================
# 3) Y axis mode for slices
# =========================
Y_AXIS_MODE <- "rules"
Y_LIMS_OVERRIDE_ALL <- NULL
Y_BREAKS_OVERRIDE_ALL <- NULL

Y_AXIS_RULES <- list(
    rSO2_Ch1 = list(lims = c(67.5, 76.5), breaks = seq(68, 76, 1)),
    rSO2_Ch2 = list(lims = c(67.5, 76.5), breaks = seq(68, 76, 1)),
    rSO2_Ch3 = list(lims = c(71.5, 80), breaks = seq(72, 80, 1))
)

Y_AUTO_PAD_FRAC <- 0.05
Y_AUTO_MIN_RANGE <- 2.0
Y_AUTO_N_BREAKS <- 5

get_y_values_for_range <- function(df_sum) {
    y <- df_sum$yhat_mean
    lo <- intersect(c("yhat_lo", "lo", "lower", "lwr"), names(df_sum))[1]
    hi <- intersect(c("yhat_hi", "hi", "upper", "upr"), names(df_sum))[1]
    if (!is.na(lo)) y <- c(y, df_sum[[lo]])
    if (!is.na(hi)) y <- c(y, df_sum[[hi]])
    y[is.finite(y)]
}

y_axis_spec <- function(ycol, df_sum = NULL) {
    mode <- tolower(Y_AXIS_MODE)
    if (mode == "global") {
        return(list(lims = Y_LIMS_OVERRIDE_ALL, breaks = Y_BREAKS_OVERRIDE_ALL %||% waiver()))
    }
    if (mode == "rules") {
        rule <- Y_AXIS_RULES[[ycol]]
        if (!is.null(rule)) {
            return(list(lims = rule$lims %||% NULL, breaks = rule$breaks %||% waiver()))
        }
        mode <- "auto"
    }
    if (is.null(df_sum) || !nrow(df_sum)) {
        return(list(lims = NULL, breaks = waiver()))
    }
    yy <- get_y_values_for_range(df_sum)
    if (!length(yy)) {
        return(list(lims = NULL, breaks = waiver()))
    }
    rng <- range(yy, na.rm = TRUE)
    if (!all(is.finite(rng))) {
        return(list(lims = NULL, breaks = waiver()))
    }
    if (diff(rng) < Y_AUTO_MIN_RANGE) {
        mid <- mean(rng)
        half <- Y_AUTO_MIN_RANGE / 2
        rng <- c(mid - half, mid + half)
    }
    pad <- diff(rng) * Y_AUTO_PAD_FRAC
    lims <- c(rng[1] - pad, rng[2] + pad)
    brks <- pretty(lims, n = Y_AUTO_N_BREAKS)
    list(lims = lims, breaks = brks)
}

# =========================
# 4) Load slices from exports (SAFE)
# =========================
load_from_exports_safe <- function(OUTDIR, ycol, sec, fixed_axis) {
    root <- file.path(OUTDIR, "exports", ycol, glue("{sec}s"))
    if (!dir_exists(root)) {
        warning("找不到目录：", root, " （跳过该通道/该sec）", call. = FALSE)
        return(NULL)
    }
    subs <- dir_ls(root, type = "directory", recurse = FALSE, regexp = "sub\\d+$") |> basename()
    if (!length(subs)) {
        warning("该 sec 下没有 sub* 目录：", root, " （跳过）", call. = FALSE)
        return(NULL)
    }
    sub_order <- suppressWarnings(as.integer(sub("^sub", "", subs)))
    sub_latest <- subs[order(sub_order)][length(sub_order)]
    sub_dir <- file.path(root, sub_latest)
    k <- sub("^sub", "", sub_latest)

    csv_agg_wide <- file.path(sub_dir, glue("{ycol}_{sec}s_{k}_slices_agg.csv"))
    csv_agg_long <- file.path(sub_dir, glue("{ycol}_{sec}s_{k}_slices_agg_long.csv"))
    xlsx_data <- file.path(sub_dir, glue("{ycol}_{sec}s_{k}_data.xlsx"))
    csv_slices <- file.path(sub_dir, glue("{ycol}_{sec}s_{k}_slices.csv"))

    use_agg_wide <- function(dfw, fixed_axis) {
        dfw <- dfw %>% mutate(
            fixed_axis = ifelse(.data$fixed_kind == "fixMAP", "MAP",
                ifelse(.data$fixed_kind == "fixCI", "CI", NA_character_)
            )
        )
        if (fixed_axis == "MAP") {
            d <- dfw %>% filter(fixed_axis == "MAP", .data$x_var == "CI")
            transmute(d,
                vary_name = "CI", vary_value = .data$x, fixed_value = .data$fixed_value,
                yhat_mean = .data$mean, yhat_lo = .data$lo, yhat_hi = .data$hi
            )
        } else if (fixed_axis == "CI") {
            d <- dfw %>% filter(fixed_axis == "CI", .data$x_var == "MAP")
            transmute(d,
                vary_name = "MAP", vary_value = .data$x, fixed_value = .data$fixed_value,
                yhat_mean = .data$mean, yhat_lo = .data$lo, yhat_hi = .data$hi
            )
        } else {
            stop("fixed_axis 必须是 'MAP' 或 'CI'")
        }
    }

    df_sum <- NULL
    if (file_exists(csv_agg_wide)) {
        dfw <- suppressMessages(readr::read_csv(csv_agg_wide, show_col_types = FALSE))
        df_sum <- use_agg_wide(dfw, fixed_axis)
    } else if (file_exists(xlsx_data) && "slices_agg" %in% tryCatch(readxl::excel_sheets(xlsx_data), error = function(e) character(0))) {
        dfw <- readxl::read_xlsx(xlsx_data, sheet = "slices_agg")
        df_sum <- use_agg_wide(dfw, fixed_axis)
    }

    if (is.null(df_sum)) {
        dfl <- NULL
        if (file_exists(csv_agg_long)) {
            dfl <- suppressMessages(readr::read_csv(csv_agg_long, show_col_types = FALSE))
        } else if (file_exists(xlsx_data) && "slices_agg_long" %in% tryCatch(readxl::excel_sheets(xlsx_data), error = function(e) character(0))) {
            dfl <- readxl::read_xlsx(xlsx_data, sheet = "slices_agg_long")
        }
        if (!is.null(dfl)) {
            dt <- as.data.table(dfl)
            wide <- dcast(dt, x_var + x + fixed_var + fixed_value + y_var + fixed_kind + agg_kind + n_rep ~ stat,
                value.var = "pred"
            )
            df_sum <- use_agg_wide(as.data.frame(wide), fixed_axis)
        }
    }

    if (is.null(df_sum)) {
        df_old <- NULL
        if (file_exists(csv_slices)) {
            df_old <- suppressMessages(readr::read_csv(csv_slices, show_col_types = FALSE))
        } else if (file_exists(xlsx_data)) {
            sheets <- tryCatch(readxl::excel_sheets(xlsx_data), error = function(e) character(0))
            if ("slices" %in% sheets) df_old <- readxl::read_xlsx(xlsx_data, sheet = "slices")
        }
        if (is.null(df_old)) {
            warning("未找到可用切片数据（跳过）：", ycol, " | ", sec, "s", call. = FALSE)
            return(NULL)
        }
        names(df_old) <- trimws(names(df_old))
        if (fixed_axis == "MAP") {
            df_sum <- df_old %>%
                filter(.data$curve_kind == "slice_summary_single", .data$fixed_kind == "MAP") %>%
                transmute(vary_name = "CI", vary_value = .data$CI, fixed_value = .data$MAP, yhat_mean = .data$pred)
        } else {
            df_sum <- df_old %>%
                filter(.data$curve_kind == "slice_summary_single", .data$fixed_kind == "CI") %>%
                transmute(vary_name = "MAP", vary_value = .data$MAP, fixed_value = .data$CI, yhat_mean = .data$pred)
        }
    }

    if (is.null(df_sum) || !nrow(df_sum)) {
        warning("df_sum 为空（跳过）：", ycol, " | ", sec, "s", call. = FALSE)
        return(NULL)
    }
    list(df_sum = df_sum, df_rep = NULL)
}

# =========================
# 5) Plot slices
# =========================
detect_ci_cols <- function(df) {
    nm <- names(df)
    lo <- intersect(c("yhat_lo", "lo", "lower", "lwr"), nm)[1]
    hi <- intersect(c("yhat_hi", "hi", "upper", "upr"), nm)[1]
    if (length(lo) && length(hi)) list(lo = lo, hi = hi) else NULL
}

gg_slices <- function(ycol, fixed_axis, bundle, fixed_values = NULL,
                      show_legend = TRUE, mean_size = 1.4) {
    df_sum <- bundle$df_sum
    if (is.null(df_sum) || !nrow(df_sum)) stop("df_sum 为空：没有可画的汇总切片。")
    vary_name <- unique(df_sum$vary_name)[1]
    all_vals <- sort(unique(df_sum$fixed_value))
    use_vals <- if (is.null(fixed_values)) {
        all_vals
    } else {
        unique(sapply(fixed_values, function(v) all_vals[which.min(abs(all_vals - v))]))
    }
    d_sum <- df_sum %>%
        filter(fixed_value %in% use_vals) %>%
        arrange(fixed_value, vary_value) %>%
        mutate(fixed_lab = factor(legend_label(fixed_axis, fixed_value),
            levels = legend_label(fixed_axis, sort(use_vals))
        ))
    pal <- palette_for_fixed_values(fixed_axis, sort(use_vals))
    xs <- x_axis_spec(vary_name)
    ys <- y_axis_spec(ycol, d_sum)
    p <- ggplot()
    ci <- detect_ci_cols(d_sum)
    if (SHOW_CI_BAND && !is.null(ci)) {
        p <- p + geom_ribbon(
            data = d_sum,
            aes(x = vary_value, ymin = .data[[ci$lo]], ymax = .data[[ci$hi]], fill = fixed_lab, group = fixed_lab),
            alpha = 0.18, colour = NA, show.legend = FALSE
        )
    }
    p <- p + geom_path(
        data = d_sum,
        aes(x = vary_value, y = yhat_mean, colour = fixed_lab),
        linewidth = mean_size, show.legend = TRUE
    )
    p +
        scale_colour_manual(values = pal, name = NULL, drop = FALSE) +
        scale_fill_manual(values = pal, guide = "none", drop = FALSE) +
        scale_x_continuous(limits = xs$lims, breaks = xs$breaks, labels = xs$lab) +
        scale_y_continuous(limits = ys$lims, breaks = ys$breaks, labels = label_number(accuracy = 1)) +
        labs(x = pretty_lab(vary_name), y = pretty_lab(ycol)) +
        theme_clean() +
        guides(
            colour = guide_legend(
                ncol = 1, byrow = TRUE,
                override.aes = list(linewidth = 1.0, alpha = 1, fill = NA),
                keyheight = unit(6, "pt"), keywidth = unit(10, "pt")
            )
        ) +
        theme(
            legend.position = if (show_legend) LEGEND_POS_INNER else "none",
            legend.justification = LEGEND_JUST_INNER,
            legend.background = element_rect(fill = "transparent", colour = NA),
            legend.key = element_rect(fill = "transparent", colour = NA),
            legend.key.height = unit(6, "pt"),
            legend.key.width = unit(10, "pt"),
            legend.spacing.y = unit(-1, "pt"),
            legend.spacing.x = unit(2, "pt"),
            legend.margin = margin(2, 2, 2, 2)
        )
}

# =========================
# 6) PPT helpers
# =========================
ppt_add_plot <- function(ppt, p, width = FIG_W, height = FIG_H, top = 0.8) {
    sz <- officer::slide_size(ppt)
    left <- (sz$width - width) / 2
    ppt <- add_slide(ppt, layout = "Blank", master = layout_summary(ppt)$master[1])
    ppt <- ph_with(ppt,
        value = rvg::dml(ggobj = p),
        location = ph_location(left = left, top = top, width = width, height = height)
    )
    ppt
}

# ==========================================================
# 7) slope helpers
# ==========================================================
fit_beta <- function(dseg, yname = "yhat_mean") {
    dseg <- dseg %>%
        mutate(.y = .data[[yname]]) %>%
        filter(is.finite(vary_value), is.finite(.y)) %>%
        transmute(x = vary_value, y = .y)
    if (nrow(dseg) < 2) {
        return(list(beta = NA_real_, n = nrow(dseg)))
    }
    fit <- lm(y ~ x, data = dseg)
    list(beta = unname(coef(fit)[["x"]]), n = nrow(dseg))
}

# ==========================================================
# 8) MAP-slope: MAP piecewise @ fixed CI
# ==========================================================
MAP_SLOPE_UNIT <- "per1"
PW_BREAKS_MAP <- list(a = c(-Inf, 70), b = c(70, 100), c = c(100, Inf))
range_label_map_abc <- function(k) {
    if (k == "a") {
        "MAP \u2264 70 mmHg"
    } else if (k == "b") {
        "70 < MAP \u2264 100 mmHg"
    } else {
        "MAP > 100 mmHg"
    }
}

piecewise_slopes_MAP_with_ci <- function(df_sum, ycol) {
    if (!all(df_sum$vary_name == "MAP")) df_sum <- df_sum %>% filter(vary_name == "MAP")
    has_ci <- all(c("yhat_lo", "yhat_hi") %in% names(df_sum)) &&
        any(is.finite(df_sum$yhat_lo)) && any(is.finite(df_sum$yhat_hi))
    out <- df_sum %>%
        group_by(fixed_value) %>%
        group_modify(~ {
            d <- .x %>% arrange(vary_value)
            res <- lapply(names(PW_BREAKS_MAP), function(k) {
                lo <- PW_BREAKS_MAP[[k]][1]
                hi <- PW_BREAKS_MAP[[k]][2]
                if (k == "a") dseg <- d %>% filter(vary_value <= hi)
                if (k == "b") dseg <- d %>% filter(vary_value > lo, vary_value <= hi)
                if (k == "c") dseg <- d %>% filter(vary_value > lo)
                fm <- fit_beta(dseg, "yhat_mean")
                row <- data.frame(range = k, beta_per_mmHg = fm$beta, slope_per_10mmHg = fm$beta * 10, n_points = fm$n)
                if (has_ci) {
                    flo <- fit_beta(dseg, "yhat_lo")
                    fhi <- fit_beta(dseg, "yhat_hi")
                    row$beta_lo_per_mmHg <- flo$beta
                    row$beta_hi_per_mmHg <- fhi$beta
                    row$slope_lo_per_10mmHg <- flo$beta * 10
                    row$slope_hi_per_10mmHg <- fhi$beta * 10
                }
                row
            }) %>% bind_rows()
            res
        }) %>%
        ungroup() %>%
        mutate(
            ycol = ycol, CI = fixed_value,
            range_label = factor(sapply(range, range_label_map_abc),
                levels = c(range_label_map_abc("a"), range_label_map_abc("b"), range_label_map_abc("c"))
            )
        ) %>%
        select(
            ycol, CI, range, range_label, beta_per_mmHg, slope_per_10mmHg, n_points,
            any_of(c("beta_lo_per_mmHg", "beta_hi_per_mmHg", "slope_lo_per_10mmHg", "slope_hi_per_10mmHg"))
        )
    out
}

# ==========================================================
# 9) CI-slope: CI piecewise @ fixed MAP
# ==========================================================
CI_SLOPE_UNIT <- "per1"
PW_BREAKS_CI <- list(a = c(-Inf, 2.8), b = c(2.8, 4.2), c = c(4.2, Inf))
range_label_ci_abc <- function(k) {
    if (k == "a") {
        "CI \u2264 2.8 L/min/m\u00B2"
    } else if (k == "b") {
        "2.8 < CI \u2264 4.2 L/min/m\u00B2"
    } else {
        "CI > 4.2 L/min/m\u00B2"
    }
}

piecewise_slopes_CI_with_ci <- function(df_sum, ycol) {
    if (!all(df_sum$vary_name == "CI")) df_sum <- df_sum %>% filter(vary_name == "CI")
    has_ci <- all(c("yhat_lo", "yhat_hi") %in% names(df_sum)) &&
        any(is.finite(df_sum$yhat_lo)) && any(is.finite(df_sum$yhat_hi))
    out <- df_sum %>%
        group_by(fixed_value) %>%
        group_modify(~ {
            d <- .x %>% arrange(vary_value)
            res <- lapply(names(PW_BREAKS_CI), function(k) {
                lo <- PW_BREAKS_CI[[k]][1]
                hi <- PW_BREAKS_CI[[k]][2]
                if (k == "a") dseg <- d %>% filter(vary_value <= hi)
                if (k == "b") dseg <- d %>% filter(vary_value > lo, vary_value <= hi)
                if (k == "c") dseg <- d %>% filter(vary_value > lo)
                fm <- fit_beta(dseg, "yhat_mean")
                row <- data.frame(range = k, beta_per_CI = fm$beta, slope_per_0.5CI = fm$beta * 0.5, n_points = fm$n)
                if (has_ci) {
                    flo <- fit_beta(dseg, "yhat_lo")
                    fhi <- fit_beta(dseg, "yhat_hi")
                    row$beta_lo_per_CI <- flo$beta
                    row$beta_hi_per_CI <- fhi$beta
                    row$slope_lo_per_0.5CI <- flo$beta * 0.5
                    row$slope_hi_per_0.5CI <- fhi$beta * 0.5
                }
                row
            }) %>% bind_rows()
            res
        }) %>%
        ungroup() %>%
        mutate(
            ycol = ycol, MAP = fixed_value,
            range_label = factor(sapply(range, range_label_ci_abc),
                levels = c(range_label_ci_abc("a"), range_label_ci_abc("b"), range_label_ci_abc("c"))
            )
        ) %>%
        select(
            ycol, MAP, range, range_label, beta_per_CI, slope_per_0.5CI, n_points,
            any_of(c("beta_lo_per_CI", "beta_hi_per_CI", "slope_lo_per_0.5CI", "slope_hi_per_0.5CI"))
        )
    out
}

# ==========================================================
# 10) slope plots
# ==========================================================
map_slope_ylab <- function(unit = MAP_SLOPE_UNIT) {
    if (tolower(unit) == "per1") "Slope (%/mmHg)" else "Slope (%/10 mmHg)"
}
ci_slope_ylab <- function(unit = CI_SLOPE_UNIT) {
    if (tolower(unit) == "per1") "Slope (%/L/min/m\u00B2)" else "Slope (%/0.5 L/min/m\u00B2)"
}

MAP_SLOPE_Y_LIMS <- c(0, 0.16)
MAP_SLOPE_Y_BREAKS <- seq(0, 0.16, 0.02)
CI_SLOPE_Y_LIMS <- c(0, 3.2)
CI_SLOPE_Y_BREAKS <- seq(0, 3.2, 0.4)

plot_MAP_slope_compact <- function(sl_map, fixed_ci_values, show_err = SHOW_SLOPE_ERRBAR) {
    SLOPE_BAR_WIDTH <- 0.6
    SLOPE_DODGE_WIDTH <- 0.7
    LEGEND_TEXT_SIZE <- 9
    LEGEND_KEY_W_PT <- 8
    LEGEND_KEY_H_PT <- 8
    SEG_LEVELS <- c("MAP \u2264 70 mmHg", "70 < MAP \u2264 100 mmHg", "MAP > 100 mmHg")
    SLOPE_SEG_COLORS_LOCAL <- c("MAP \u2264 70 mmHg" = "#C55A11", "70 < MAP \u2264 100 mmHg" = "#2E75B6", "MAP > 100 mmHg" = "#BF9000")
    y_col <- if (MAP_SLOPE_UNIT == "per1") "beta_per_mmHg" else "slope_per_10mmHg"
    lo_col <- if (MAP_SLOPE_UNIT == "per1") "beta_lo_per_mmHg" else "slope_lo_per_10mmHg"
    hi_col <- if (MAP_SLOPE_UNIT == "per1") "beta_hi_per_mmHg" else "slope_hi_per_10mmHg"
    ci_levels <- sprintf("%.1f", sort(unique(round(fixed_ci_values, 1))))
    d <- sl_map %>%
        mutate(
            CI_num = round(as.numeric(CI), 1), CI_fac = factor(sprintf("%.1f", CI_num), levels = ci_levels),
            seg = factor(as.character(range_label), levels = SEG_LEVELS)
        ) %>%
        filter(CI_num %in% round(fixed_ci_values, 1))
    dodge <- position_dodge(width = SLOPE_DODGE_WIDTH)
    p <- ggplot(d, aes(x = CI_fac, y = .data[[y_col]], fill = seg)) +
        geom_col(width = SLOPE_BAR_WIDTH, position = dodge, alpha = SLOPE_BIN_ALPHA) +
        scale_fill_manual(values = SLOPE_SEG_COLORS_LOCAL, drop = FALSE) +
        labs(x = "Cardiac Index (L/min/m\u00B2)", y = map_slope_ylab()) +
        scale_y_continuous(breaks = MAP_SLOPE_Y_BREAKS) +
        coord_cartesian(ylim = MAP_SLOPE_Y_LIMS) +
        theme_clean() +
        theme(
            axis.text.x = element_text(size = 9), legend.position = LEGEND_POS_INNER,
            legend.justification = LEGEND_JUST_INNER, legend.direction = "vertical",
            legend.title = element_blank(), legend.text = element_text(size = LEGEND_TEXT_SIZE),
            legend.key.width = unit(LEGEND_KEY_W_PT, "pt"), legend.key.height = unit(LEGEND_KEY_H_PT, "pt"),
            legend.spacing.y = unit(2, "pt"), legend.margin = margin(2, 2, 2, 2),
            legend.background = element_rect(fill = "transparent", colour = NA),
            legend.key = element_rect(fill = "transparent", colour = NA)
        ) +
        guides(fill = guide_legend(ncol = 1, byrow = TRUE))
    if (show_err && all(c(lo_col, hi_col) %in% names(d))) {
        d2 <- d %>% filter(is.finite(.data[[lo_col]]), is.finite(.data[[hi_col]]), is.finite(.data[[y_col]]))
        if (nrow(d2)) {
            p <- p + geom_errorbar(
                data = d2, aes(ymin = .data[[lo_col]], ymax = .data[[hi_col]], colour = seg),
                width = 0.06, linewidth = 0.5, position = dodge
            ) +
                scale_colour_manual(values = SLOPE_SEG_COLORS_LOCAL, guide = "none")
        }
    }
    p
}

plot_CI_slope_compact <- function(sl_ci, fixed_map_values, show_err = SHOW_SLOPE_ERRBAR) {
    SLOPE_BAR_WIDTH <- 0.6
    SLOPE_DODGE_WIDTH <- 0.7
    LEGEND_TEXT_SIZE <- 9
    LEGEND_KEY_W_PT <- 8
    LEGEND_KEY_H_PT <- 8
    SEG_LEVELS <- c("CI \u2264 2.8 L/min/m\u00B2", "2.8 < CI \u2264 4.2 L/min/m\u00B2", "CI > 4.2 L/min/m\u00B2")
    SLOPE_SEG_COLORS_LOCAL <- c("CI \u2264 2.8 L/min/m\u00B2" = "#C55A11", "2.8 < CI \u2264 4.2 L/min/m\u00B2" = "#2E75B6", "CI > 4.2 L/min/m\u00B2" = "#BF9000")
    y_col <- if (CI_SLOPE_UNIT == "per1") "beta_per_CI" else "slope_per_0.5CI"
    lo_col <- if (CI_SLOPE_UNIT == "per1") "beta_lo_per_CI" else "slope_lo_per_0.5CI"
    hi_col <- if (CI_SLOPE_UNIT == "per1") "beta_hi_per_CI" else "slope_hi_per_0.5CI"
    map_levels <- sprintf("%d", sort(unique(round(fixed_map_values, 0))))
    d <- sl_ci %>%
        mutate(
            MAP_num = round(as.numeric(MAP), 0), MAP_fac = factor(sprintf("%d", MAP_num), levels = map_levels),
            seg = factor(as.character(range_label), levels = SEG_LEVELS)
        ) %>%
        filter(MAP_num %in% round(fixed_map_values, 0))
    dodge <- position_dodge(width = SLOPE_DODGE_WIDTH)
    p <- ggplot(d, aes(x = MAP_fac, y = .data[[y_col]], fill = seg)) +
        geom_col(width = SLOPE_BAR_WIDTH, position = dodge, alpha = SLOPE_BIN_ALPHA) +
        scale_fill_manual(values = SLOPE_SEG_COLORS_LOCAL, drop = FALSE) +
        labs(x = "Mean Arterial Pressure (mmHg)", y = ci_slope_ylab()) +
        scale_y_continuous(breaks = CI_SLOPE_Y_BREAKS) +
        coord_cartesian(ylim = CI_SLOPE_Y_LIMS) +
        theme_clean() +
        theme(
            axis.text.x = element_text(size = 9), legend.position = LEGEND_POS_INNER,
            legend.justification = LEGEND_JUST_INNER, legend.direction = "vertical",
            legend.title = element_blank(), legend.text = element_text(size = LEGEND_TEXT_SIZE),
            legend.key.width = unit(LEGEND_KEY_W_PT, "pt"), legend.key.height = unit(LEGEND_KEY_H_PT, "pt"),
            legend.spacing.y = unit(2, "pt"), legend.margin = margin(2, 2, 2, 2),
            legend.background = element_rect(fill = "transparent", colour = NA),
            legend.key = element_rect(fill = "transparent", colour = NA)
        ) +
        guides(fill = guide_legend(ncol = 1, byrow = TRUE))
    if (show_err && all(c(lo_col, hi_col) %in% names(d))) {
        d2 <- d %>% filter(is.finite(.data[[lo_col]]), is.finite(.data[[hi_col]]), is.finite(.data[[y_col]]))
        if (nrow(d2)) {
            p <- p + geom_errorbar(
                data = d2, aes(ymin = .data[[lo_col]], ymax = .data[[hi_col]], colour = seg),
                width = 0.06, linewidth = 0.5, position = dodge
            ) +
                scale_colour_manual(values = SLOPE_SEG_COLORS_LOCAL, guide = "none")
        }
    }
    p
}

# ==========================================================
# 11) Find OUTDIRs recursively (exports/)
# ==========================================================
find_outdirs_with_exports <- function(root) {
    ex <- dir_ls(root, recurse = TRUE, type = "directory", regexp = "(^|/)exports$")
    if (!length(ex)) {
        return(character(0))
    }
    unique(path_dir(ex))
}

is_abs_path <- function(p) grepl("^/", p)

find_outdirs_with_exports_under <- function(root_dir) {
    if (!fs::dir_exists(root_dir)) {
        return(character(0))
    }
    ex <- fs::dir_ls(root_dir, recurse = TRUE, type = "directory", regexp = "(^|/)exports$")
    if (!length(ex)) {
        return(character(0))
    }
    unique(fs::path_dir(ex))
}

read_selected_outdirs_expand <- function(path, base_root) {
    if (!file.exists(path)) stop("SELECT_FILE 不存在：", path)
    x <- readLines(path, warn = FALSE, encoding = "UTF-8")
    x <- trimws(x)
    x <- x[nzchar(x)]
    x <- x[!startsWith(x, "#")]
    if (!length(x)) stop("SELECT_FILE 为空：", path)
    x <- vapply(x, function(p) {
        if (is_abs_path(p)) fs::path_norm(p) else fs::path_norm(fs::path(base_root, p))
    }, character(1))
    out_all <- character(0)
    bad <- character(0)
    for (p in x) {
        if (!fs::dir_exists(p)) {
            bad <- c(bad, p)
            next
        }
        if (fs::dir_exists(file.path(p, "exports"))) {
            out_all <- c(out_all, p)
            next
        }
        hits <- find_outdirs_with_exports_under(p)
        if (length(hits)) {
            out_all <- c(out_all, sort(unique(hits)))
        } else {
            bad <- c(bad, p)
        }
    }
    out_all <- unique(out_all)
    if (length(bad)) warning("以下条目不存在或其子目录中找不到 exports/，将跳过：\n", paste(bad, collapse = "\n"), call. = FALSE)
    if (!length(out_all)) stop("SELECT_FILE 里没有任何可用 OUTDIR")
    out_all
}

# ==========================================================
# 12) ✅ 新增：小提琴图功能
# ==========================================================

#' 从 model_ready_cache 加载建模数据（按通道，与 Python v2.6 完全一致）
#' 参考: get_intraop_df_v2() in slice_individual_PLOT_v98.2
load_raw_for_violin <- function(ycol) {
    fname <- glue("df_clean_{ycol}_{VIOLIN_SEC}s.parquet")
    fpath <- file.path(MODEL_READY_CACHE_ROOT, fname)

    if (isTRUE(STRICT_MODEL_READY_ONLY) && !file.exists(fpath)) {
        stop("[violin] 严格模式：缺少建模数据文件 ", fpath)
    }

    if (!file.exists(fpath)) {
        warning("[violin] ⚠️ 缺少建模数据文件，跳过: ", fpath, call. = FALSE)
        return(NULL)
    }

    message("[violin] 加载建模数据: ", fname)
    ds <- arrow::open_dataset(fpath)
    all_cols <- names(ds)
    id_col <- if ("stay_id" %in% all_cols) "stay_id" else if ("patient_ID" %in% all_cols) "patient_ID" else NULL

    # 只读取需要的列（CI, MAP, ycol）
    cols_needed <- c("CI", "MAP", ycol)
    cols_to_read <- intersect(cols_needed, all_cols)
    if (!ycol %in% cols_to_read) {
        # 尝试 "value" 作为 fallback
        if ("value" %in% all_cols) {
            cols_to_read <- c(setdiff(cols_to_read, ycol), "value")
            message("[violin] 列 '", ycol, "' 不存在，使用 'value' 替代")
        } else {
            warning("[violin] ⚠️ 找不到列 '", ycol, "' 或 'value'，跳过", call. = FALSE)
            return(NULL)
        }
    }

    df <- ds |>
        dplyr::select(dplyr::all_of(cols_to_read)) |>
        dplyr::filter(!is.na(CI), !is.na(MAP)) |>
        dplyr::collect()

    # 如果读到的是 "value" 列，重命名为 ycol
    if (!ycol %in% names(df) && "value" %in% names(df)) {
        names(df)[names(df) == "value"] <- ycol
    }

    df <- df[is.finite(df[["CI"]]) & is.finite(df[["MAP"]]) & is.finite(df[[ycol]]), ]

    message("[violin] 加载完成，有效行数: ", nrow(df))
    as.data.table(df)
}

#' MAP 分3箱（CI不限制）
prepare_violin_map_bins <- function(dt) {
    if (is.null(dt) || nrow(dt) == 0) return(NULL)
    sub <- copy(dt)
    sub[, MAP_bin := fifelse(
        MAP <= 70, VIOLIN_MAP_BIN_LEVELS[1],
        fifelse(MAP <= 100, VIOLIN_MAP_BIN_LEVELS[2], VIOLIN_MAP_BIN_LEVELS[3])
    )]
    sub[, MAP_bin := factor(MAP_bin, levels = VIOLIN_MAP_BIN_LEVELS)]
    sub
}

#' CI 分3箱（MAP不限制，分箱与 slope 一致）
prepare_violin_ci_bins <- function(dt) {
    if (is.null(dt) || nrow(dt) == 0) return(NULL)
    sub <- copy(dt)
    sub[, CI_bin := fifelse(
        CI <= 2.8, VIOLIN_CI_BIN_LEVELS[1],
        fifelse(CI <= 4.2, VIOLIN_CI_BIN_LEVELS[2], VIOLIN_CI_BIN_LEVELS[3])
    )]
    sub[, CI_bin := factor(CI_bin, levels = VIOLIN_CI_BIN_LEVELS)]
    sub
}

#' 通用：按分组画小提琴图
gg_violin_by_group <- function(df_violin, ycol, group_col, group_levels, group_tick_labels,
                               x_lab, legend_only = FALSE) {
    if (is.null(df_violin) || nrow(df_violin) == 0) return(NULL)

    d_full <- copy(df_violin)
    d_full[, grp := factor(get(group_col), levels = group_levels)]
    d_full <- d_full[!is.na(grp)]
    if (!nrow(d_full)) return(NULL)

    tick_map <- setNames(group_tick_labels, group_levels)

    # 线条颜色（与 slope 一致）+ 填充颜色（按用户指定顺序）
    violin_colors <- setNames(c("#C55A11", "#2E75B6", "#BF9000"), group_levels)
    violin_fill_colors <- setNames(c("#FBE5D6", "#DEEBF7", "#FFF2CC"), group_levels)
    d_plot <- copy(d_full)
    if (is.finite(VIOLIN_PLOT_MAX_N) && nrow(d_plot) > VIOLIN_PLOT_MAX_N) {
        # 分层抽样：每个bin分配近似相同上限，避免某一组被过度抽样
        set.seed(20260428)
        n_grp <- d_plot[, uniqueN(grp)]
        cap_per_grp <- max(1L, as.integer(ceiling(VIOLIN_PLOT_MAX_N / n_grp)))
        d_plot <- d_plot[, if (.N > cap_per_grp) .SD[sample(.N, cap_per_grp)] else .SD, by = grp]
    }
    if (!isTRUE(legend_only)) {
        return(
            ggplot(d_plot, aes(x = grp, y = .data[[ycol]], fill = grp, colour = grp, group = grp)) +
                geom_hline(
                    yintercept = VIOLIN_HLINE_Y,
                    colour = VIOLIN_HLINE_COLOR,
                    linewidth = VIOLIN_HLINE_LWD,
                    linetype = VIOLIN_HLINE_LTY
                ) +
                geom_violin(
                    trim = TRUE, adjust = VIOLIN_DENSITY_ADJUST, n = VIOLIN_DENSITY_N, scale = "width", width = 0.6,
                    alpha = 1, linewidth = VIOLIN_OUTLINE_LWD, show.legend = FALSE
                ) +
                geom_boxplot(
                    data = d_plot,
                    aes(x = grp, y = .data[[ycol]], group = grp),
                    inherit.aes = FALSE,
                    width = 0.10, fill = "white", alpha = 0.85,
                    outlier.size = 0.2, outlier.alpha = 0.2, linewidth = VIOLIN_BOX_LWD,
                    colour = "#333333", show.legend = FALSE
                ) +
                stat_summary(
                    data = d_plot,
                    aes(x = grp, y = .data[[ycol]], group = grp),
                    inherit.aes = FALSE,
                    fun = median, geom = "point", shape = 18,
                    size = VIOLIN_MEDIAN_SIZE, colour = "#E41A1C", show.legend = FALSE
                ) +
                scale_fill_manual(values = violin_fill_colors, guide = "none", drop = FALSE) +
                scale_colour_manual(values = violin_colors, guide = "none", drop = FALSE) +
                scale_x_discrete(labels = tick_map, drop = FALSE) +
                scale_y_continuous(
                    breaks = VIOLIN_Y_BREAKS,
                    minor_breaks = NULL
                ) +
                coord_cartesian(ylim = VIOLIN_Y_LIMS) +
                labs(
                    x = x_lab,
                    y = pretty_lab(ycol)
                ) +
                theme_clean() +
                theme(
                    axis.title = element_text(size = VIOLIN_AXIS_TITLE_SIZE, colour = "black"),
                    axis.title.x = element_text(margin = margin(t = VIOLIN_X_TITLE_MARGIN_PT)),
                    axis.text = element_text(size = VIOLIN_AXIS_TEXT_SIZE, colour = "black"),
                    axis.text.x = element_text(size = VIOLIN_AXIS_TEXT_SIZE, lineheight = 0.9)
                )
        )
    }

    # 方案2：X轴仅保留标题，分组信息在图例
    d_plot[, x_dummy := "all_data"]
    d_full[, x_dummy := "all_data"]
    dodge <- position_dodge(width = 0.7)
    ggplot(d_plot, aes(x = x_dummy, y = .data[[ycol]], fill = grp, colour = grp, group = grp)) +
        geom_hline(
            yintercept = VIOLIN_HLINE_Y,
            colour = VIOLIN_HLINE_COLOR,
            linewidth = VIOLIN_HLINE_LWD,
            linetype = VIOLIN_HLINE_LTY
        ) +
        geom_violin(
            trim = TRUE, adjust = VIOLIN_DENSITY_ADJUST, n = VIOLIN_DENSITY_N, scale = "width", width = 0.6,
            alpha = 1, linewidth = VIOLIN_OUTLINE_LWD, position = dodge
        ) +
        geom_boxplot(
            data = d_plot,
            aes(x = x_dummy, y = .data[[ycol]], group = grp),
            inherit.aes = FALSE,
            width = 0.08, fill = "white", alpha = 0.85,
            outlier.size = 0.2, outlier.alpha = 0.2, linewidth = VIOLIN_BOX_LWD,
            colour = "#333333", position = dodge, show.legend = FALSE
        ) +
        stat_summary(
            data = d_plot,
            aes(x = x_dummy, y = .data[[ycol]], group = grp),
            inherit.aes = FALSE,
            fun = median, geom = "point", shape = 18,
            size = VIOLIN_MEDIAN_SIZE, colour = "#E41A1C",
            position = dodge, show.legend = FALSE
        ) +
        scale_fill_manual(values = violin_fill_colors, drop = FALSE) +
        scale_colour_manual(values = violin_colors, drop = FALSE, guide = "none") +
        scale_x_discrete(labels = function(x) rep("", length(x))) +
        scale_y_continuous(
            breaks = VIOLIN_Y_BREAKS,
            minor_breaks = NULL
        ) +
        coord_cartesian(ylim = VIOLIN_Y_LIMS) +
        labs(
            x = x_lab,
            y = pretty_lab(ycol)
        ) +
        theme_clean() +
        theme(
            axis.title = element_text(size = VIOLIN_AXIS_TITLE_SIZE, colour = "black"),
            axis.title.x = element_text(margin = margin(t = VIOLIN_X_TITLE_MARGIN_PT)),
            axis.text = element_text(size = VIOLIN_AXIS_TEXT_SIZE, colour = "black"),
            axis.text.x = element_text(size = VIOLIN_AXIS_TEXT_SIZE, lineheight = 0.9),
            legend.position = LEGEND_POS_INNER,
            legend.justification = LEGEND_JUST_INNER,
            legend.direction = "vertical",
            legend.title = element_blank(),
            legend.text = element_text(size = LEGEND_FONTSIZE),
            legend.key.width = unit(8, "pt"),
            legend.key.height = unit(8, "pt"),
            legend.spacing.y = unit(2, "pt"),
            legend.margin = margin(2, 2, 2, 2),
            legend.background = element_rect(fill = "transparent", colour = NA),
            legend.key = element_rect(fill = "transparent", colour = NA)
        ) +
        guides(fill = guide_legend(ncol = 1, byrow = TRUE))
}

# ==========================================================
# 13) MAIN
# ==========================================================
main <- function() {
    ts_run <- format(Sys.time(), "%Y%m%d_%H%M%S")
    EXPORT_RUN <- file.path(EXPORT_DIR_BASE, paste0("run_", ts_run))
    dir_create(EXPORT_RUN, recurse = TRUE)

    if (SELECT_MODE == "all") {
        OUTDIR_LIST <- find_outdirs_with_exports(SUBGROUPS_ROOT)
    } else if (SELECT_MODE == "file") {
        OUTDIR_LIST <- read_selected_outdirs_expand(SELECT_FILE, base_root = SUBGROUPS_ROOT)
    } else if (SELECT_MODE == "regex") {
        all_out <- find_outdirs_with_exports(SUBGROUPS_ROOT)
        OUTDIR_LIST <- all_out[grepl(SELECT_REGEX, basename(all_out))]
    } else {
        stop("SELECT_MODE 只能是 all/file/regex，当前：", SELECT_MODE)
    }

    if (!length(OUTDIR_LIST)) stop("未找到任何可用 OUTDIR")

    if (isTRUE(EXCLUDE_SUBGROUP_OUTDIRS)) {
        OUTDIR_LIST <- OUTDIR_LIST[!grepl("(^|/)subgroups(/|$)", OUTDIR_LIST)]
        if (!length(OUTDIR_LIST)) stop("过滤 subgroups 后无可用 OUTDIR")
    }
    if (nzchar(PRIMARY_OUTDIR_PATTERN)) {
        OUTDIR_LIST <- OUTDIR_LIST[grepl(PRIMARY_OUTDIR_PATTERN, OUTDIR_LIST)]
        if (!length(OUTDIR_LIST)) stop("按 PRIMARY_OUTDIR_PATTERN 过滤后无可用 OUTDIR")
    }

    message("[root] SUBGROUPS_ROOT : ", SUBGROUPS_ROOT)
    message("[out ] EXPORT_RUN    : ", EXPORT_RUN)
    message("[sel ] SELECT_MODE   : ", SELECT_MODE)
    if (SELECT_MODE == "file") message("[sel ] SELECT_FILE   : ", SELECT_FILE)
    if (SELECT_MODE == "regex") message("[sel ] SELECT_REGEX  : ", SELECT_REGEX)
    message("[n   ] OUTDIRs        : ", length(OUTDIR_LIST))
    message("[opt ] EXCLUDE_SUBGROUP_OUTDIRS : ", EXCLUDE_SUBGROUP_OUTDIRS)
    message("[opt ] PRIMARY_OUTDIR_PATTERN : ", PRIMARY_OUTDIR_PATTERN)
    message("[opt ] SHOW_SLOPE_ERRBAR : ", SHOW_SLOPE_ERRBAR)
    message("[opt ] STRICT_MODEL_READY_ONLY : ", STRICT_MODEL_READY_ONLY)
    message("[leg ] LEGEND_POS_INNER  : ", paste0(LEGEND_POS_INNER, collapse = ", "))
    message("[leg ] LEGEND_JUST_INNER : ", paste0(LEGEND_JUST_INNER, collapse = ", "))
    message("[font] BASE_FAMILY       : ", BASE_FAMILY)

    writeLines(OUTDIR_LIST, file.path(EXPORT_RUN, "OUTDIR_LIST_USED.txt"))

    # ==========================================
    # ✅ 预加载建模数据用于小提琴图（每个通道加载一次）
    # ==========================================
    raw_data_cache <- list()
    if (!dir.exists(MODEL_READY_CACHE_ROOT)) {
        warning("[violin] ⚠️ model_ready_cache 目录不存在: ", MODEL_READY_CACHE_ROOT, call. = FALSE)
    }
    for (ycol in CHANNELS) {
        raw_data_cache[[ycol]] <- load_raw_for_violin(ycol)
    }

    for (OUTDIR in OUTDIR_LIST) {
        out_tag <- basename(OUTDIR)
        ppt_path <- file.path(EXPORT_RUN, glue("SlicesPlusSlopes_{out_tag}_sec{SEC}_{ts_run}.pptx"))

        message("\n--------------------------------------------------")
        message("[in ] OUTDIR : ", OUTDIR)
        message("[ppt] OUT    : ", ppt_path)

        ppt <- read_pptx()

        for (ycol in CHANNELS) {
            message("\n==== ", ycol, " ====")

            tryCatch(
                {
                    # --- 原有切片图 ---
                    if (ENABLE_SLICE_PLOT || ENABLE_SLOPE_PLOT) {
                        bA <- load_from_exports_safe(OUTDIR, ycol, SEC, fixed_axis = "CI")
                        if (!is.null(bA)) {
                            if (ENABLE_SLICE_PLOT) {
                                pA <- gg_slices(ycol, fixed_axis = "CI", bundle = bA, fixed_values = FIXED_CI_VALUES, show_legend = SHOW_LEGEND)
                                ppt <- ppt_add_plot(ppt, pA, width = FIG_W, height = FIG_H, top = 0.8)
                            }
                            if (ENABLE_SLOPE_PLOT) {
                                sl_map <- piecewise_slopes_MAP_with_ci(bA$df_sum, ycol = ycol) %>%
                                    mutate(CI = round(as.numeric(CI), 1)) %>%
                                    filter(CI %in% round(FIXED_CI_VALUES, 1))
                                write_csv(sl_map, file.path(EXPORT_RUN, glue("{out_tag}_{ycol}_sec{SEC}_MAP_slope_piecewise.csv")))
                                p_map <- plot_MAP_slope_compact(sl_map, fixed_ci_values = FIXED_CI_VALUES)
                                ppt <- ppt_add_plot(ppt, p_map, width = FIG_W, height = FIG_H, top = 0.8)
                            }
                        } else {
                            message("⚠️ 跳过 fixedCI（缺 exports/<ycol>/<sec>s/...）")
                        }

                        bB <- load_from_exports_safe(OUTDIR, ycol, SEC, fixed_axis = "MAP")
                        if (!is.null(bB)) {
                            if (ENABLE_SLICE_PLOT) {
                                pB <- gg_slices(ycol, fixed_axis = "MAP", bundle = bB, fixed_values = FIXED_MAP_VALUES, show_legend = SHOW_LEGEND)
                                ppt <- ppt_add_plot(ppt, pB, width = FIG_W, height = FIG_H, top = 0.8)
                            }
                            if (ENABLE_SLOPE_PLOT) {
                                sl_ci <- piecewise_slopes_CI_with_ci(bB$df_sum, ycol = ycol) %>%
                                    mutate(MAP = round(as.numeric(MAP), 0)) %>%
                                    filter(MAP %in% round(FIXED_MAP_VALUES, 0))
                                write_csv(sl_ci, file.path(EXPORT_RUN, glue("{out_tag}_{ycol}_sec{SEC}_CI_slope_piecewise.csv")))
                                p_ci <- plot_CI_slope_compact(sl_ci, fixed_map_values = FIXED_MAP_VALUES)
                                ppt <- ppt_add_plot(ppt, p_ci, width = FIG_W, height = FIG_H, top = 0.8)
                            }
                        } else {
                            message("⚠️ 跳过 fixedMAP（缺 exports/<ycol>/<sec>s/...）")
                        }
                    }

                    # --- ✅ 新增：小提琴图 ---
                    if (!is.null(raw_data_cache[[ycol]])) {
                        dt_raw <- raw_data_cache[[ycol]]
                        # 1) MAP 三分箱（CI不限制）
                        message("  [violin] ", ycol, " - MAP bins (CI unrestricted)")
                        df_map <- prepare_violin_map_bins(dt_raw)
                        if (!is.null(df_map) && nrow(df_map) > 0) {
                            stats_map <- df_map[, .(
                                n = .N,
                                mean_y = mean(get(ycol), na.rm = TRUE),
                                sd_y = sd(get(ycol), na.rm = TRUE),
                                median_y = median(get(ycol), na.rm = TRUE)
                            ),
                            by = MAP_bin
                            ]
                            write_csv(stats_map, file.path(
                                EXPORT_RUN,
                                glue("{out_tag}_{ycol}_sec{SEC}_violin_MAP_bins_CI_unrestricted_stats.csv")
                            ))

                            if (isTRUE(VIOLIN_SHOW_STYLE1_GROUPS_ON_X)) {
                                p_map_s1 <- gg_violin_by_group(
                                    df_map, ycol,
                                    group_col = "MAP_bin",
                                    group_levels = VIOLIN_MAP_BIN_LEVELS,
                                    group_tick_labels = VIOLIN_MAP_BIN_TICKS,
                                    x_lab = "Mean Arterial Pressure (mmHg)",
                                    legend_only = FALSE
                                )
                                if (!is.null(p_map_s1)) {
                                    ppt <- ppt_add_plot(ppt, p_map_s1,
                                    width = VIOLIN_FIG_W, height = VIOLIN_FIG_H, top = 0.8
                                    )
                                    message("    ✅ MAP-bin 小提琴图（x轴分组）已添加")
                                }
                            }
                            if (isTRUE(VIOLIN_SHOW_STYLE2_LEGEND_ONLY)) {
                                p_map_s2 <- gg_violin_by_group(
                                    df_map, ycol,
                                    group_col = "MAP_bin",
                                    group_levels = VIOLIN_MAP_BIN_LEVELS,
                                    group_tick_labels = VIOLIN_MAP_BIN_TICKS,
                                    x_lab = "Mean Arterial Pressure (mmHg)",
                                    legend_only = TRUE
                                )
                                if (!is.null(p_map_s2)) {
                                    ppt <- ppt_add_plot(ppt, p_map_s2,
                                    width = VIOLIN_FIG_W, height = VIOLIN_FIG_H, top = 0.8
                                    )
                                    message("    ✅ MAP-bin 小提琴图（图例分组）已添加")
                                }
                            }
                        } else {
                            message("    ⚠️ MAP分箱无数据，跳过")
                        }

                        # 2) CI 三分箱（MAP不限制，与 slope 分段一致）
                        message("  [violin] ", ycol, " - CI bins (MAP unrestricted)")
                        df_ci <- prepare_violin_ci_bins(dt_raw)
                        if (!is.null(df_ci) && nrow(df_ci) > 0) {
                            stats_ci <- df_ci[, .(
                                n = .N,
                                mean_y = mean(get(ycol), na.rm = TRUE),
                                sd_y = sd(get(ycol), na.rm = TRUE),
                                median_y = median(get(ycol), na.rm = TRUE)
                            ),
                            by = CI_bin
                            ]
                            write_csv(stats_ci, file.path(
                                EXPORT_RUN,
                                glue("{out_tag}_{ycol}_sec{SEC}_violin_CI_bins_MAP_unrestricted_stats.csv")
                            ))

                            if (isTRUE(VIOLIN_SHOW_STYLE1_GROUPS_ON_X)) {
                                p_ci_s1 <- gg_violin_by_group(
                                    df_ci, ycol,
                                    group_col = "CI_bin",
                                    group_levels = VIOLIN_CI_BIN_LEVELS,
                                    group_tick_labels = VIOLIN_CI_BIN_TICKS,
                                    x_lab = "Cardiac Index (L/min/m²)",
                                    legend_only = FALSE
                                )
                                if (!is.null(p_ci_s1)) {
                                    ppt <- ppt_add_plot(ppt, p_ci_s1,
                                    width = VIOLIN_FIG_W, height = VIOLIN_FIG_H, top = 0.8
                                    )
                                    message("    ✅ CI-bin 小提琴图（x轴分组）已添加")
                                }
                            }
                            if (isTRUE(VIOLIN_SHOW_STYLE2_LEGEND_ONLY)) {
                                p_ci_s2 <- gg_violin_by_group(
                                    df_ci, ycol,
                                    group_col = "CI_bin",
                                    group_levels = VIOLIN_CI_BIN_LEVELS,
                                    group_tick_labels = VIOLIN_CI_BIN_TICKS,
                                    x_lab = "Cardiac Index (L/min/m²)",
                                    legend_only = TRUE
                                )
                                if (!is.null(p_ci_s2)) {
                                    ppt <- ppt_add_plot(ppt, p_ci_s2,
                                    width = VIOLIN_FIG_W, height = VIOLIN_FIG_H, top = 0.8
                                    )
                                    message("    ✅ CI-bin 小提琴图（图例分组）已添加")
                                }
                            }
                        } else {
                            message("    ⚠️ CI分箱无数据，跳过")
                        }
                    }
                },
                error = function(e) {
                    warning("通道失败但继续：", out_tag, " | ", ycol, " | ", conditionMessage(e), call. = FALSE)
                }
            )
        }

        print(ppt, target = ppt_path)
        message("✅ PPT written: ", ppt_path)
    }

    message("\n✅ ALL DONE. Outputs in: ", EXPORT_RUN)
    message("[notes] slope 误差线开关 SHOW_SLOPE_ERRBAR = ", SHOW_SLOPE_ERRBAR)
    message("[notes] OUTDIR selection mode = ", SELECT_MODE)
    message("[notes] legend shared pos = (", paste0(LEGEND_POS_INNER, collapse = ","), "), just = (", paste0(LEGEND_JUST_INNER, collapse = ","), ")")
    message("[notes] font = ", BASE_FAMILY)
    message("[notes] STRICT_MODEL_READY_ONLY = ", STRICT_MODEL_READY_ONLY)
    message("[notes] SLOPE_BIN_ALPHA = ", SLOPE_BIN_ALPHA)
    message("[notes] violin MAP bins = ", paste(VIOLIN_MAP_BIN_LEVELS, collapse = " | "))
    message("[notes] violin CI bins = ", paste(VIOLIN_CI_BIN_LEVELS, collapse = " | "))
}

main()
