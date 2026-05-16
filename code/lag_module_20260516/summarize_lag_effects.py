#!/usr/bin/env python3
import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


CHANNELS = ["rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3"]


def interp(x, y, xq):
    return float(np.interp(float(xq), x, y))


def find_result_dir(result_root: Path, outdir_tag: str):
    cands = sorted(result_root.glob(f"*_{outdir_tag}"))
    if not cands:
        return None
    with_summary = [d for d in cands if (d / "run_summary.csv").exists()]
    return with_summary[-1] if with_summary else cands[-1]


def load_curve(curve_fp: Path):
    df = pd.read_csv(curve_fp)
    x = pd.to_numeric(df["x"], errors="coerce").to_numpy(dtype=float)
    y = pd.to_numeric(df["pred_mean"], errors="coerce").to_numpy(dtype=float)
    lo = pd.to_numeric(df["pred_lo_2.5"], errors="coerce").to_numpy(dtype=float)
    hi = pd.to_numeric(df["pred_hi_97.5"], errors="coerce").to_numpy(dtype=float)

    good = np.isfinite(x) & np.isfinite(y) & np.isfinite(lo) & np.isfinite(hi)
    x, y, lo, hi = x[good], y[good], lo[good], hi[good]
    idx = np.argsort(x)
    return x[idx], y[idx], lo[idx], hi[idx]


def find_boot_matrix(curve_fp: Path):
    cand1 = Path(str(curve_fp).replace("_curve_boot.csv", "_boot_raw_curve_matrix.csv"))
    if cand1.exists():
        return cand1
    cands = list(curve_fp.parent.glob("*boot_raw_curve_matrix.csv"))
    return cands[0] if cands else None


def delta_from_curve(curve_fp: Path, step: float = 5.0):
    x, y, lo, hi = load_curve(curve_fp)
    x0 = float(np.nanmedian(x))
    x1 = min(float(np.nanmax(x)), x0 + float(step))
    if x1 <= x0:
        x0, x1 = float(np.nanmin(x)), float(np.nanmax(x))

    d = interp(x, y, x1) - interp(x, y, x0)

    mat_fp = find_boot_matrix(curve_fp)
    if mat_fp is not None and mat_fp.exists():
        mat = pd.read_csv(mat_fp).to_numpy(dtype=float)
        if mat.shape[1] != len(x):
            x_mat = np.linspace(float(np.nanmin(x)), float(np.nanmax(x)), mat.shape[1])
        else:
            x_mat = x
        deltas = []
        for row in mat:
            if not np.all(np.isfinite(row)):
                continue
            deltas.append(interp(x_mat, row, x1) - interp(x_mat, row, x0))
        if len(deltas) >= 10:
            arr = np.array(deltas, dtype=float)
            return d, float(np.quantile(arr, 0.025)), float(np.quantile(arr, 0.975)), x0, x1, int(len(arr))

    se0 = max((interp(x, hi, x0) - interp(x, lo, x0)) / (2 * 1.96), 1e-9)
    se1 = max((interp(x, hi, x1) - interp(x, lo, x1)) / (2 * 1.96), 1e-9)
    se = np.sqrt(se0**2 + se1**2)
    return d, float(d - 1.96 * se), float(d + 1.96 * se), x0, x1, 0


def pick_strongest_lag_nonzero(df: pd.DataFrame):
    d = df[(df["status"] == "ok") & (df["lag_seconds"] > 0)].copy()
    if d.empty:
        return None
    g = d.groupby("lag_seconds", as_index=False)["delta_rso2_plus5"].mean()
    g["score"] = g["delta_rso2_plus5"].abs()
    g = g.sort_values(["score", "lag_seconds"], ascending=[False, True])
    return int(g.iloc[0]["lag_seconds"])


def extract_sample_counts(flow_fp: Path, ycol: str):
    if not flow_fp.exists():
        return np.nan, np.nan, np.nan, np.nan
    d = pd.read_csv(flow_fp)
    d = d[(d["sec"] == 1) & (d["subgroup"] == "All") & (d["ycol"] == ycol)]
    if d.empty:
        return np.nan, np.nan, np.nan, np.nan

    def get_stage(stage_name: str, col: str):
        s = d[d["stage"] == stage_name][col]
        if len(s) == 0:
            return np.nan
        return float(s.iloc[0])

    n_required_rows = get_stage("after_required_etco2_y_nonmissing", "n_rows")
    n_required_patients = get_stage("after_required_etco2_y_nonmissing", "n_patients")
    n_final_rows = get_stage("final_usable_points_strict_etco2_rso2", "n_rows")
    n_final_patients = get_stage("final_usable_points_strict_etco2_rso2", "n_patients")
    return n_required_rows, n_required_patients, n_final_rows, n_final_patients


def plot_lag_delta(df: pd.DataFrame, out_png: Path, out_pdf: Path):
    ok = df[df["status"] == "ok"].copy()
    if ok.empty:
        return

    plt.figure(figsize=(8.6, 5.4))
    colors = {
        "rSO2_Ch1": "#1f77b4",
        "rSO2_Ch2": "#ff7f0e",
        "rSO2_Ch3": "#2ca02c",
    }
    for ch in CHANNELS:
        sub = ok[ok["ycol"] == ch].sort_values("lag_seconds")
        if sub.empty:
            continue
        x = sub["lag_seconds"].to_numpy(dtype=float)
        y = sub["delta_rso2_plus5"].to_numpy(dtype=float)
        lo = sub["delta_ci_lo"].to_numpy(dtype=float)
        hi = sub["delta_ci_hi"].to_numpy(dtype=float)
        yerr = np.vstack([y - lo, hi - y])
        plt.errorbar(
            x,
            y,
            yerr=yerr,
            marker="o",
            linestyle="-",
            linewidth=1.5,
            capsize=3,
            color=colors.get(ch, None),
            label=ch,
        )

    plt.axhline(0.0, color="black", linestyle="--", linewidth=1.0)
    plt.xlabel("ET_CO2 lag (seconds)")
    plt.ylabel("Delta rSO2 (+5 mmHg ET_CO2)")
    plt.title("Lag sensitivity of ET_CO2 effect (Model B, n=10000, boot=200)")
    plt.xticks([0, 30, 60, 120, 180])
    plt.legend(frameon=False)
    plt.tight_layout()
    plt.savefig(out_png, dpi=220)
    plt.savefig(out_pdf)
    plt.close()


def plot_curve_compare(df: pd.DataFrame, lag0: int, lag_best: int, out_png: Path, out_pdf: Path):
    fig, axes = plt.subplots(1, 3, figsize=(14.5, 4.2), sharey=True)
    if not isinstance(axes, np.ndarray):
        axes = np.array([axes])

    for i, ch in enumerate(CHANNELS):
        ax = axes[i]
        sub = df[(df["status"] == "ok") & (df["ycol"] == ch) & (df["lag_seconds"].isin([lag0, lag_best]))]
        for lag_s, color in [(lag0, "#1f77b4"), (lag_best, "#d62728")]:
            one = sub[sub["lag_seconds"] == lag_s]
            if one.empty:
                continue
            curve_fp = Path(one.iloc[0]["curve_fp"])
            x, y, lo, hi = load_curve(curve_fp)
            ax.plot(x, y, color=color, linewidth=2.0, label=f"lag{lag_s}s")
            ax.fill_between(x, lo, hi, color=color, alpha=0.15)

        ax.set_title(ch)
        ax.set_xlabel("ET_CO2 (mmHg)")
        if i == 0:
            ax.set_ylabel("Predicted rSO2")
        ax.grid(alpha=0.2, linewidth=0.6)

    handles, labels = axes[0].get_legend_handles_labels()
    if handles:
        fig.legend(handles, labels, loc="lower center", ncol=2, frameon=False)
    fig.suptitle(f"ET_CO2 slice curves: lag0 vs lag{lag_best}s", y=1.02)
    plt.tight_layout()
    plt.savefig(out_png, dpi=220, bbox_inches="tight")
    plt.savefig(out_pdf, bbox_inches="tight")
    plt.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--workspace",
        default="/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/lag_module_20260516",
    )
    ap.add_argument("--matrix", default="lag_run_matrix.csv")
    ap.add_argument(
        "--result-root",
        default="/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/analysis_bundle/result",
    )
    ap.add_argument("--step", type=float, default=5.0)
    args = ap.parse_args()

    ws = Path(args.workspace)
    matrix_fp = ws / args.matrix
    result_root = Path(args.result_root)
    out_tables = ws / "output" / "tables"
    out_figs = ws / "output" / "figures"
    out_tables.mkdir(parents=True, exist_ok=True)
    out_figs.mkdir(parents=True, exist_ok=True)

    matrix = pd.read_csv(matrix_fp)
    rows = []

    for _, r in matrix.iterrows():
        if int(r.get("enabled", 0)) != 1:
            continue
        run_key = str(r["run_key"])
        lag_seconds = int(r["lag_seconds"])
        outdir_tag = str(r["outdir_tag"])
        result_dir = find_result_dir(result_root, outdir_tag)

        if result_dir is None:
            for ch in CHANNELS:
                rows.append({
                    "run_key": run_key,
                    "lag_seconds": lag_seconds,
                    "outdir_tag": outdir_tag,
                    "ycol": ch,
                    "status": "missing_result_dir",
                })
            continue

        flow_fp = result_dir / "filter_flow_counts.csv"
        for ch in CHANNELS:
            curve = next(result_dir.rglob(f"{ch}_ET_CO2_*_slice_median_curve_boot.csv"), None)
            if curve is None:
                rows.append({
                    "run_key": run_key,
                    "lag_seconds": lag_seconds,
                    "outdir_tag": outdir_tag,
                    "ycol": ch,
                    "status": "missing_curve",
                    "result_dir": str(result_dir),
                })
                continue

            d, lo, hi, x0, x1, n_boot_ok = delta_from_curve(curve, step=args.step)
            n_required_rows, n_required_patients, n_final_rows, n_final_patients = extract_sample_counts(flow_fp, ch)

            rows.append({
                "run_key": run_key,
                "lag_seconds": lag_seconds,
                "outdir_tag": outdir_tag,
                "ycol": ch,
                "status": "ok",
                "result_dir": str(result_dir),
                "curve_fp": str(curve),
                "x_from_median": x0,
                "x_to_plus5": x1,
                "delta_rso2_plus5": d,
                "delta_ci_lo": lo,
                "delta_ci_hi": hi,
                "n_boot_ok": n_boot_ok,
                "n_required_rows": n_required_rows,
                "n_required_patients": n_required_patients,
                "n_final_rows": n_final_rows,
                "n_final_patients": n_final_patients,
            })

    df = pd.DataFrame(rows)
    bych_fp = out_tables / "lag_effect_summary_by_channel.csv"
    df.to_csv(bych_fp, index=False)

    ok = df[df["status"] == "ok"].copy()
    if ok.empty:
        print(f"no completed lag results found under: {result_root}")
        print(f"wrote: {bych_fp}")
        return

    lag0_df = ok[ok["lag_seconds"] == 0][["ycol", "n_final_rows", "n_final_patients"]].rename(
        columns={"n_final_rows": "lag0_n_final_rows", "n_final_patients": "lag0_n_final_patients"}
    )
    ok = ok.merge(lag0_df, on="ycol", how="left")
    ok["rows_loss_vs_lag0"] = ok["lag0_n_final_rows"] - ok["n_final_rows"]

    bych_withloss_fp = out_tables / "lag_effect_summary_by_channel_with_loss.csv"
    ok.to_csv(bych_withloss_fp, index=False)

    lag_tbl = (
        ok.groupby("lag_seconds", as_index=False)
        .agg(
            mean_delta=("delta_rso2_plus5", "mean"),
            min_ci_lo=("delta_ci_lo", "min"),
            max_ci_hi=("delta_ci_hi", "max"),
            mean_final_rows=("n_final_rows", "mean"),
            mean_rows_loss_vs_lag0=("rows_loss_vs_lag0", "mean"),
        )
        .sort_values("lag_seconds")
    )
    lag_tbl_fp = out_tables / "lag_effect_summary_overall.csv"
    lag_tbl.to_csv(lag_tbl_fp, index=False)

    fig1_png = out_figs / "lag_delta_plus5_by_channel_modelB_n10000_b200.png"
    fig1_pdf = out_figs / "lag_delta_plus5_by_channel_modelB_n10000_b200.pdf"
    plot_lag_delta(ok, fig1_png, fig1_pdf)

    lag_best = pick_strongest_lag_nonzero(ok)
    if lag_best is None:
        lag_best = 60

    fig2_png = out_figs / f"lag_curve_compare_lag0_vs_lag{lag_best}_modelB_n10000_b200.png"
    fig2_pdf = out_figs / f"lag_curve_compare_lag0_vs_lag{lag_best}_modelB_n10000_b200.pdf"
    plot_curve_compare(ok, lag0=0, lag_best=lag_best, out_png=fig2_png, out_pdf=fig2_pdf)

    print(f"summary_by_channel: {bych_fp}")
    print(f"summary_by_channel_with_loss: {bych_withloss_fp}")
    print(f"summary_overall: {lag_tbl_fp}")
    print(f"figure1: {fig1_png}")
    print(f"figure2: {fig2_png}")


if __name__ == "__main__":
    main()
