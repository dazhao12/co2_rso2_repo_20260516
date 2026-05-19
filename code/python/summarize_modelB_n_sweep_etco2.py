#!/usr/bin/env python3
"""
v1.3 - 样本量敏感性汇总数据导出脚本
改动：
  - 去除 Python 内置的 Matplotlib 绘图与 python-pptx 生成逻辑。
  - 将 Delta 效应量、稳定性指标以及曲线坐标点统一汇总为 CSV 并存入 results/ 目录。
  - 自动调用 R 脚本 `plot_modelB_n_sweep_etco2.R`，以 ggplot2 + rvg + officer 生成完全可编辑的 PPTX 幻灯片。
基于：v1.2
解决问题：满足用户“画图一律用R，ggplot生成ppt可编辑”的要求。
"""
import argparse
import re
import subprocess
from pathlib import Path

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
    
    # Deduplicate runs: keep only the latest run for each sample size N
    n_to_dir = {}
    for d in dirs:
        n = parse_n_from_name(d.name)
        if n is not None:
            n_to_dir[n] = d
    unique_dirs = [n_to_dir[n] for n in sorted(n_to_dir.keys())]

    rows = []
    for d in unique_dirs:
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
    print(f"summary: {sum_fp}")

    if df.empty:
        print(f"no n-sweep result dirs found under: {result_root}")
        return

    df_ok = df[df["status"] == "ok"].copy()
    if not df_ok.empty:
        # 1. Export stability summary table
        stab = build_stability_summary(df_ok)
        stab_fp = out_tables / "modelB_n_sweep_stability_summary.csv"
        stab.to_csv(stab_fp, index=False)
        print(f"stability: {stab_fp}")

        # 2. Export detailed curves data for ggplot2
        curves_rows = []
        for _, row in df_ok.iterrows():
            n = int(row["sample_size"])
            ch = row["ycol"]
            curve_fp = Path(row["curve_fp"])
            if not curve_fp.exists():
                continue
            x, y, lo, hi = load_curve(curve_fp)
            for xi, yi, loi, hii in zip(x, y, lo, hi):
                curves_rows.append({
                    "sample_size": n,
                    "ycol": ch,
                    "etco2": float(xi),
                    "pred": float(yi),
                    "lo": float(loi),
                    "hi": float(hii)
                })
        df_curves = pd.DataFrame(curves_rows)
        curves_fp = out_tables / "modelB_n_sweep_curves_data.csv"
        df_curves.to_csv(curves_fp, index=False)
        print(f"curves data: {curves_fp}")

        # 3. Call R plotting and slide generation script
        r_script_path = Path("/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/r/plot_modelB_n_sweep_etco2.R")
        if r_script_path.exists():
            print(f"Invoking R plotting script: {r_script_path}")
            subprocess.run(["Rscript", str(r_script_path)], check=True)
        else:
            print(f"Warning: R plotting script not found at {r_script_path}")


if __name__ == "__main__":
    main()
