#!/usr/bin/env python3

import argparse
import importlib.util
from pathlib import Path
from typing import Dict, List

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


def load_main_module(script_path: Path):
    spec = importlib.util.spec_from_file_location("co2_main_module", str(script_path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load module from: {script_path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def build_df_base(mod):
    need_cols = (
        ["stay_id", "patient_ID", "patient_id", "obstime"]
        + mod.PRIMARY_VARS
        + mod.OPTIONAL_INTRAOP_COVARS
        + mod.OUTCOMES
        + mod.ADJ_CONT_CAND
        + mod.ADJ_CAT_CAND
        + mod.SUBGROUP_STATIC_VARS
        + ["Sex", "SEX", "Age"]
    )

    df_ts = mod.read_csv_folder_selected_cached(mod.CSV_DIR, mod.CSV_GLOB, need_cols=need_cols)
    static_need_cols = sorted(set(mod.ADJ_CONT_CAND + mod.ADJ_CAT_CAND + mod.SUBGROUP_STATIC_VARS + ["Sex", "SEX", "Age"]))
    static_df = mod.read_static_selected_multi(
        xlsx_paths=[mod.XLSX_PATH_MAIN, mod.XLSX_PATH_SUBGROUP],
        need_cols=static_need_cols,
    )

    df_ts = mod._coerce_stay_id(df_ts)
    static_df = mod._coerce_stay_id(static_df)
    df_ts = mod._coerce_patient_id(df_ts)
    static_df = mod._coerce_patient_id(static_df)

    merge_key = None
    for k in ["stay_id", "patient_ID", "patient_id"]:
        if (k in df_ts.columns) and (k in static_df.columns):
            merge_key = k
            break
    if merge_key is not None:
        static_cols = [c for c in static_df.columns if c != merge_key]
        df_base = df_ts.merge(static_df[[merge_key] + static_cols], on=merge_key, how="left")
    else:
        df_base = df_ts.copy()

    if "Sex" not in df_base.columns and "SEX" in df_base.columns:
        df_base["Sex"] = df_base["SEX"]
    if "SEX" not in df_base.columns and "Sex" in df_base.columns:
        df_base["SEX"] = df_base["Sex"]

    mod.safe_numeric(
        df_base,
        [
            c
            for c in mod.PRIMARY_VARS
            + mod.OPTIONAL_INTRAOP_COVARS
            + mod.OUTCOMES
            + mod.ADJ_CONT_CAND
            + mod.ADJ_CAT_CAND
            + mod.SUBGROUP_STATIC_VARS
            + ["Sex", "SEX", "Age"]
            if c in df_base.columns
        ],
    )
    mod.maybe_convert_fio2_to_percent(df_base, col="FiO2_new")
    return df_base


def summarize_stage1(df_stage0: pd.DataFrame, ycol: str) -> Dict[str, float]:
    needed = [c for c in ["ET_CO2", ycol] if c in df_stage0.columns]
    if len(needed) != 2:
        raise RuntimeError(f"Missing required columns for stage1 summary: {needed}")
    df_stage1 = df_stage0.dropna(subset=needed).copy()

    n0 = int(len(df_stage0))
    n1 = int(len(df_stage1))
    n_excl = int(n0 - n1)
    p_excl = (100.0 * n_excl / n0) if n0 > 0 else np.nan
    return {
        "n_available": n0,
        "n_excluded_missing": n_excl,
        "pct_excluded_missing": p_excl,
        "n_remained_stage1": n1,
    }


def main():
    parser = argparse.ArgumentParser(description="Plot stage-1 (missing-filtered only) histograms for EtCO2 and rSO2.")
    parser.add_argument(
        "--main-script",
        type=Path,
        default=Path(
            "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/python/"
            "contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py"
        ),
    )
    parser.add_argument("--sec", type=int, default=1)
    parser.add_argument("--ycol", type=str, default="rSO2_Ch1", choices=["rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3"])
    parser.add_argument("--subgroup-query", type=str, default="")
    parser.add_argument("--subgroup-tag", type=str, default="All")
    parser.add_argument(
        "--outdir",
        type=Path,
        default=Path(
            "/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/analysis_bundle/output/stage1_distribution"
        ),
    )
    args = parser.parse_args()

    mod = load_main_module(args.main_script)
    df_base = build_df_base(mod)
    df_sec = mod.downsample(df_base, sec=args.sec)
    df_sub = mod.apply_subgroup_query(df_sec, args.subgroup_query.strip()) if args.subgroup_query.strip() else df_sec.copy()

    needed = ["ET_CO2", args.ycol]
    df_stage1 = df_sub.dropna(subset=needed).copy()
    summary = summarize_stage1(df_sub, args.ycol)

    et_range = mod.ETCO2_REQUIRED_RANGE
    y_range = mod.OUTCOME_REQUIRED_RANGES.get(args.ycol, mod.OUTCOME_REQUIRED_RANGE)

    out_fig = args.outdir / "figures"
    out_tbl = args.outdir / "tables"
    out_fig.mkdir(parents=True, exist_ok=True)
    out_tbl.mkdir(parents=True, exist_ok=True)

    stem = f"{args.ycol}_sec{args.sec}_{args.subgroup_tag}_stage1_after_missing_only"

    sum_df = pd.DataFrame(
        [
            {
                "sec": int(args.sec),
                "subgroup": args.subgroup_tag,
                "subgroup_query": args.subgroup_query,
                "ycol": args.ycol,
                **summary,
                "etco2_required_lo": float(et_range[0]),
                "etco2_required_hi": float(et_range[1]),
                "y_required_lo": float(y_range[0]),
                "y_required_hi": float(y_range[1]),
            }
        ]
    )
    sum_df.to_csv(out_tbl / f"{stem}_summary.csv", index=False)

    desc = pd.DataFrame(
        {
            "variable": ["ET_CO2", args.ycol],
            "n_nonmissing_stage1": [int(df_stage1["ET_CO2"].notna().sum()), int(df_stage1[args.ycol].notna().sum())],
            "mean": [float(df_stage1["ET_CO2"].mean()), float(df_stage1[args.ycol].mean())],
            "sd": [float(df_stage1["ET_CO2"].std(ddof=1)), float(df_stage1[args.ycol].std(ddof=1))],
            "p01": [float(df_stage1["ET_CO2"].quantile(0.01)), float(df_stage1[args.ycol].quantile(0.01))],
            "p05": [float(df_stage1["ET_CO2"].quantile(0.05)), float(df_stage1[args.ycol].quantile(0.05))],
            "p50": [float(df_stage1["ET_CO2"].quantile(0.50)), float(df_stage1[args.ycol].quantile(0.50))],
            "p95": [float(df_stage1["ET_CO2"].quantile(0.95)), float(df_stage1[args.ycol].quantile(0.95))],
            "p99": [float(df_stage1["ET_CO2"].quantile(0.99)), float(df_stage1[args.ycol].quantile(0.99))],
        }
    )
    desc.to_csv(out_tbl / f"{stem}_describe.csv", index=False)

    fig, axes = plt.subplots(1, 2, figsize=(13, 4.6))
    fig.subplots_adjust(wspace=0.28, top=0.82)

    ax = axes[0]
    x1 = pd.to_numeric(df_stage1["ET_CO2"], errors="coerce").dropna().to_numpy()
    ax.hist(x1, bins=80, color="#9ecae1", edgecolor="white")
    ax.axvline(et_range[0], color="#d62728", linestyle="--", linewidth=1.2, label=f"threshold {et_range[0]:.0f}")
    ax.axvline(et_range[1], color="#d62728", linestyle="--", linewidth=1.2, label=f"threshold {et_range[1]:.0f}")
    ax.set_xlabel("ETCO2 (mmHg)")
    ax.set_ylabel("Count")
    ax.set_title("ETCO2 distribution after missing-value exclusion")

    ax = axes[1]
    x2 = pd.to_numeric(df_stage1[args.ycol], errors="coerce").dropna().to_numpy()
    y_label_map = {"rSO2_Ch1": "Left SctO2", "rSO2_Ch2": "Right SctO2", "rSO2_Ch3": "SftO2"}
    ax.hist(x2, bins=80, color="#fdd0a2", edgecolor="white")
    ax.axvline(y_range[0], color="#d62728", linestyle="--", linewidth=1.2, label=f"threshold {y_range[0]:.0f}")
    ax.axvline(y_range[1], color="#d62728", linestyle="--", linewidth=1.2, label=f"threshold {y_range[1]:.0f}")
    ax.set_xlabel(f"{y_label_map.get(args.ycol, args.ycol)} (%)")
    ax.set_ylabel("Count")
    ax.set_title(f"{y_label_map.get(args.ycol, args.ycol)} distribution after missing-value exclusion")

    title = (
        f"Stage-1 distributions (after removing missing ETCO2/{args.ycol}) | "
        f"available={summary['n_available']:,}, excluded={summary['n_excluded_missing']:,} "
        f"({summary['pct_excluded_missing']:.4f}%), remained={summary['n_remained_stage1']:,}"
    )
    fig.suptitle(title, fontsize=11)

    png_fp = out_fig / f"{stem}.png"
    pdf_fp = out_fig / f"{stem}.pdf"
    fig.savefig(png_fp, dpi=180, bbox_inches="tight")
    fig.savefig(pdf_fp, bbox_inches="tight")
    plt.close(fig)

    print(f"WROTE {out_tbl / f'{stem}_summary.csv'}")
    print(f"WROTE {out_tbl / f'{stem}_describe.csv'}")
    print(f"WROTE {png_fp}")
    print(f"WROTE {pdf_fp}")


if __name__ == "__main__":
    main()
