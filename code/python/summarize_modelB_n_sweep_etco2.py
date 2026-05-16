#!/usr/bin/env python3
import argparse
import re
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

CHANNELS = ["rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3"]


def interp(x, y, xq):
    return float(np.interp(float(xq), x, y))


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
    p = Path(str(curve_fp).replace("_curve_boot.csv", "_boot_raw_curve_matrix.csv"))
    if p.exists():
        return p
    cands = list(curve_fp.parent.glob("*boot_raw_curve_matrix.csv"))
    return cands[0] if cands else None


def delta_from_curve(curve_fp: Path, step: float = 5.0):
    x, y, lo, hi = load_curve(curve_fp)
    x0 = float(np.nanmedian(x))
    x1 = min(float(np.nanmax(x)), x0 + step)
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
            return d, float(np.quantile(arr, 0.025)), float(np.quantile(arr, 0.975)), len(arr)

    se0 = max((interp(x, hi, x0) - interp(x, lo, x0)) / (2 * 1.96), 1e-9)
    se1 = max((interp(x, hi, x1) - interp(x, lo, x1)) / (2 * 1.96), 1e-9)
    se = np.sqrt(se0**2 + se1**2)
    return d, float(d - 1.96 * se), float(d + 1.96 * se), 0


def parse_n_from_name(name: str):
    m = re.search(r"_nSweep_(\d+)_boot\d+_rowreplace$", name)
    return int(m.group(1)) if m else None


def pick_curve(result_dir: Path, ch: str):
    cands = sorted(result_dir.rglob(f"{ch}_ET_CO2_*_slice_median_curve_boot.csv"))
    return cands[0] if cands else None


def plot_delta(df_ok: pd.DataFrame, out_png: Path, out_pdf: Path):
    plt.figure(figsize=(8.6, 5.2))
    colors = {"rSO2_Ch1": "#1f77b4", "rSO2_Ch2": "#ff7f0e", "rSO2_Ch3": "#2ca02c"}

    for ch in CHANNELS:
        d = df_ok[df_ok["ycol"] == ch].sort_values("sample_size")
        if d.empty:
            continue
        x = d["sample_size"].to_numpy(dtype=float)
        y = d["delta_rso2_plus5"].to_numpy(dtype=float)
        lo = d["delta_ci_lo"].to_numpy(dtype=float)
        hi = d["delta_ci_hi"].to_numpy(dtype=float)
        yerr = np.vstack([y - lo, hi - y])
        plt.errorbar(x, y, yerr=yerr, marker="o", linestyle="-", capsize=3, linewidth=1.5, color=colors[ch], label=ch)

    plt.xscale("log")
    plt.axvline(10000, color="black", linestyle="--", linewidth=1.0, alpha=0.7)
    plt.xlabel("Sample size (log scale)")
    plt.ylabel("Delta rSO2 (+5 mmHg ET_CO2)")
    plt.title("Model B n-sweep stability: ET_CO2 effect")
    plt.legend(frameon=False)
    plt.tight_layout()
    plt.savefig(out_png, dpi=220)
    plt.savefig(out_pdf)
    plt.close()


def plot_curve_overlay(df_ok: pd.DataFrame, out_png: Path, out_pdf: Path):
    picks = [1000, 10000, 100000, 1000000]
    fig, axes = plt.subplots(1, 3, figsize=(14.5, 4.2), sharey=True)

    for i, ch in enumerate(CHANNELS):
        ax = axes[i]
        dch = df_ok[df_ok["ycol"] == ch].copy()
        if dch.empty:
            ax.set_title(ch)
            continue

        ns_avail = sorted(dch["sample_size"].unique())
        draw_ns = [n for n in picks if n in ns_avail]
        if not draw_ns:
            draw_ns = ns_avail[: min(4, len(ns_avail))]

        cmap = plt.get_cmap("viridis")
        for j, n in enumerate(draw_ns):
            one = dch[dch["sample_size"] == n].iloc[0]
            curve_fp = Path(one["curve_fp"])
            x, y, lo, hi = load_curve(curve_fp)
            color = cmap(j / max(1, len(draw_ns) - 1))
            ax.plot(x, y, color=color, linewidth=2.0, label=f"N={n}")
            ax.fill_between(x, lo, hi, color=color, alpha=0.12)

        ax.set_title(ch)
        ax.set_xlabel("ET_CO2 (mmHg)")
        ax.grid(alpha=0.2)
        if i == 0:
            ax.set_ylabel("Predicted rSO2")

    handles, labels = axes[0].get_legend_handles_labels()
    if handles:
        fig.legend(handles, labels, loc="lower center", ncol=min(4, len(labels)), frameon=False)
    fig.suptitle("ET_CO2 curve shape across sample sizes (Model B)", y=1.02)
    plt.tight_layout()
    plt.savefig(out_png, dpi=220, bbox_inches="tight")
    plt.savefig(out_pdf, bbox_inches="tight")
    plt.close()


def build_stability_summary(df_ok: pd.DataFrame):
    rows = []
    for ch in CHANNELS:
        dch = df_ok[df_ok["ycol"] == ch].sort_values("sample_size")
        if dch.empty:
            continue
        ref = dch.iloc[-1]
        d10k = dch[dch["sample_size"] == 10000]
        if d10k.empty:
            continue
        d10k = d10k.iloc[0]
        abs_diff = abs(float(d10k["delta_rso2_plus5"]) - float(ref["delta_rso2_plus5"]))
        rel_diff = abs_diff / (abs(float(ref["delta_rso2_plus5"])) + 1e-9)

        # heuristic plateau flag
        plateau = (abs_diff <= 0.2) or (rel_diff <= 0.1)
        rows.append(
            {
                "ycol": ch,
                "n_ref": int(ref["sample_size"]),
                "delta_ref": float(ref["delta_rso2_plus5"]),
                "delta_n10000": float(d10k["delta_rso2_plus5"]),
                "abs_diff_n10000_vs_ref": float(abs_diff),
                "rel_diff_n10000_vs_ref": float(rel_diff),
                "n10000_in_stable_plateau": bool(plateau),
            }
        )
    return pd.DataFrame(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--result-root", default="/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result")
    ap.add_argument("--out-dir", default="/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/results/modelb_n_sweep_eval")
    ap.add_argument("--step", type=float, default=5.0)
    args = ap.parse_args()

    result_root = Path(args.result_root)
    out_dir = Path(args.out_dir)
    out_tables = out_dir / "tables"
    out_figs = out_dir / "figures"
    out_tables.mkdir(parents=True, exist_ok=True)
    out_figs.mkdir(parents=True, exist_ok=True)

    dirs = sorted(result_root.glob("*overall_modelB_sec1_nSweep_*_boot50_rowreplace"))
    rows = []

    for d in dirs:
        n = parse_n_from_name(d.name)
        if n is None:
            continue
        run_summary_ok = (d / "run_summary.csv").exists()

        for ch in CHANNELS:
            curve = pick_curve(d, ch)
            if curve is None:
                rows.append(
                    {
                        "sample_size": n,
                        "ycol": ch,
                        "status": "missing_curve",
                        "result_dir": str(d),
                        "run_summary_ok": int(run_summary_ok),
                    }
                )
                continue
            delta, lo, hi, n_boot = delta_from_curve(curve, step=args.step)
            rows.append(
                {
                    "sample_size": n,
                    "ycol": ch,
                    "status": "ok",
                    "result_dir": str(d),
                    "run_summary_ok": int(run_summary_ok),
                    "curve_fp": str(curve),
                    "delta_rso2_plus5": delta,
                    "delta_ci_lo": lo,
                    "delta_ci_hi": hi,
                    "n_boot_for_ci": int(n_boot),
                }
            )

    df = pd.DataFrame(rows).sort_values(["sample_size", "ycol"]) if rows else pd.DataFrame()
    sum_fp = out_tables / "modelB_n_sweep_etco2_delta_summary.csv"
    df.to_csv(sum_fp, index=False)

    if df.empty:
        print(f"no n-sweep result dirs found under: {result_root}")
        print(f"summary: {sum_fp}")
        return

    df_ok = df[df["status"] == "ok"].copy()
    if not df_ok.empty:
        plot_delta(
            df_ok,
            out_figs / "modelB_n_sweep_delta_plus5_by_channel.png",
            out_figs / "modelB_n_sweep_delta_plus5_by_channel.pdf",
        )
        plot_curve_overlay(
            df_ok,
            out_figs / "modelB_n_sweep_curve_overlay_by_channel.png",
            out_figs / "modelB_n_sweep_curve_overlay_by_channel.pdf",
        )

        stab = build_stability_summary(df_ok)
        stab_fp = out_tables / "modelB_n_sweep_stability_summary.csv"
        stab.to_csv(stab_fp, index=False)
        print(f"stability: {stab_fp}")

    print(f"summary: {sum_fp}")
    print(f"figures: {out_figs}")


if __name__ == "__main__":
    main()
