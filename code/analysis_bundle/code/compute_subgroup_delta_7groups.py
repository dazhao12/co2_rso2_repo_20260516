#!/usr/bin/env python3
"""
compute_subgroup_delta_7groups.py
从 14 个亚组子目录的 *_curve_boot.csv 中提取 ΔrSO₂(+5 mmHg) 及 bootstrap 95%CI。
输出：subgroup_consistency_etco2_delta_plus5_modelB_n10000_b200.csv

用法：
  python compute_subgroup_delta_7groups.py --result-dir <path_to_result_dir>

result-dir 结构示例：
  result_dir/
    subgroups/
      Age_less_70/  ...  rSO2_Ch1_ET_CO2_*_slice_median_curve_boot.csv
      Diabetes_Yes/ ...
      ...
"""

import argparse
from pathlib import Path
import numpy as np
import pandas as pd


SUBGROUP_TAGS = [
    "Age_less_70", "Age_more_70",
    "Male", "Female",
    "Pre_hypertension_more_140_90", "Pre_hypertension_less_140_90",
    "Diabetes_Yes", "Diabetes_No",
    "Anemia_WHO_Yes", "Anemia_WHO_No",
    "BMI_ge28", "BMI_lt28",
    "Carotid_Yes", "Carotid_No",
]

CHANNELS = ["rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3"]


def interp(x, y, xq):
    return float(np.interp(float(xq), x, y))


def load_curve(curve_fp):
    df = pd.read_csv(curve_fp)
    x  = pd.to_numeric(df['x'], errors='coerce').to_numpy(dtype=float)
    y  = pd.to_numeric(df['pred_mean'], errors='coerce').to_numpy(dtype=float)
    lo = pd.to_numeric(df['pred_lo_2.5'], errors='coerce').to_numpy(dtype=float)
    hi = pd.to_numeric(df['pred_hi_97.5'], errors='coerce').to_numpy(dtype=float)
    good = np.isfinite(x) & np.isfinite(y) & np.isfinite(lo) & np.isfinite(hi)
    x, y, lo, hi = x[good], y[good], lo[good], hi[good]
    idx = np.argsort(x)
    return x[idx], y[idx], lo[idx], hi[idx]


def delta_from_curve(curve_fp, step=5.0):
    x, y, lo, hi = load_curve(curve_fp)
    x0 = float(np.nanmedian(x))
    x1 = min(float(np.nanmax(x)), x0 + step)
    if x1 <= x0:
        x0, x1 = float(np.nanmin(x)), float(np.nanmax(x))
    d = interp(x, y, x1) - interp(x, y, x0)

    # 优先使用 bootstrap 矩阵
    mat_fp = Path(str(curve_fp).replace('_curve_boot.csv', '_boot_raw_curve_matrix.csv'))
    if mat_fp.exists():
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
            return d, float(np.quantile(arr, 0.025)), float(np.quantile(arr, 0.975)), x0, x1

    # fallback: SE 近似
    se0 = max((interp(x, hi, x0) - interp(x, lo, x0)) / (2 * 1.96), 1e-9)
    se1 = max((interp(x, hi, x1) - interp(x, lo, x1)) / (2 * 1.96), 1e-9)
    se = np.sqrt(se0**2 + se1**2)
    return d, float(d - 1.96 * se), float(d + 1.96 * se), x0, x1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--result-dir', required=True, help='Result directory containing subgroups/')
    ap.add_argument('--step', type=float, default=5.0)
    ap.add_argument('--output', default=None, help='Output CSV path (default: auto)')
    args = ap.parse_args()

    result_dir = Path(args.result_dir)
    sg_root = result_dir / 'subgroups'
    if not sg_root.exists():
        print(f"[error] {sg_root} does not exist")
        return

    rows = []
    overall_deltas = {}

    # 先算 overall（如果存在）
    for ch in CHANNELS:
        curve = next(result_dir.rglob(f"{ch}_ET_CO2_*_slice_median_curve_boot.csv"), None)
        if curve and "subgroups" not in str(curve):
            d, lo, hi, x0, x1 = delta_from_curve(curve, step=args.step)
            overall_deltas[ch] = d

    for sg_tag in SUBGROUP_TAGS:
        sg_dir = sg_root / sg_tag
        if not sg_dir.exists():
            for ch in CHANNELS:
                rows.append({
                    'subgroup': sg_tag, 'channel': ch,
                    'status': 'missing_dir',
                })
            continue

        for ch in CHANNELS:
            curve = next(sg_dir.rglob(f"{ch}_ET_CO2_*_slice_median_curve_boot.csv"), None)
            if curve is None:
                rows.append({
                    'subgroup': sg_tag, 'channel': ch,
                    'status': 'missing_curve', 'result_dir': str(sg_dir),
                })
                continue

            d, lo, hi, x0, x1 = delta_from_curve(curve, step=args.step)
            direction = 'positive' if d > 0 else 'negative'
            overall_d = overall_deltas.get(ch, np.nan)
            overall_dir = 'positive' if overall_d > 0 else 'negative'
            same_dir = direction == overall_dir

            rows.append({
                'subgroup': sg_tag,
                'channel': ch,
                'status': 'ok',
                'delta_rso2_plus5': d,
                'delta_ci_lo': lo,
                'delta_ci_hi': hi,
                'x_from_median': x0,
                'x_to_plus5': x1,
                'direction': direction,
                'overall_delta_rso2_plus5': overall_d,
                'overall_direction': overall_dir,
                'same_direction_vs_overall': same_dir,
            })

    df = pd.DataFrame(rows)
    if args.output:
        out_fp = Path(args.output)
    else:
        out_fp = Path(__file__).resolve().parents[1] / 'output' / 'tables' / \
            'subgroup_consistency_etco2_delta_plus5_modelB_n10000_b200.csv'
    out_fp.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out_fp, index=False)
    print(f"[done] {len(df)} rows -> {out_fp}")
    print(f"  ok={len(df[df['status']=='ok'])} / missing={len(df[df['status']!='ok'])}")


if __name__ == '__main__':
    main()
