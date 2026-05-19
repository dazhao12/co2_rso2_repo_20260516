#!/usr/bin/env python3
import argparse
from pathlib import Path
import numpy as np
import pandas as pd


def interp(x, y, xq):
    return float(np.interp(float(xq), x, y))


def load_curve(curve_fp):
    df = pd.read_csv(curve_fp)
    x = pd.to_numeric(df['x'], errors='coerce').to_numpy(dtype=float)
    y = pd.to_numeric(df['pred_mean'], errors='coerce').to_numpy(dtype=float)
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
            return d, float(np.quantile(arr, 0.025)), float(np.quantile(arr, 0.975)), arr

    se0 = max((interp(x, hi, x0) - interp(x, lo, x0)) / (2 * 1.96), 1e-9)
    se1 = max((interp(x, hi, x1) - interp(x, lo, x1)) / (2 * 1.96), 1e-9)
    se = np.sqrt(se0**2 + se1**2)
    return d, float(d - 1.96 * se), float(d + 1.96 * se), None


def find_result_dir(result_roots, outdir_tag):
    if isinstance(result_roots, (str, Path)):
        result_roots = [result_roots]
    all_cands = []
    for rr in result_roots:
        rr = Path(rr)
        if not rr.exists():
            continue
        all_cands.extend(sorted(rr.glob(f"*_{outdir_tag}")))
    if not all_cands:
        return None
    all_cands = sorted(all_cands, key=lambda p: p.name)
    return all_cands[-1]


def main():
    ap = argparse.ArgumentParser()
    default_ws = str(Path(__file__).resolve().parents[1])
    ap.add_argument('--workspace', default=default_ws)
    ap.add_argument('--matrix', default='code/sensitivity5_run_matrix.csv')
    ap.add_argument(
        '--result-root',
        default='',
        help='Optional single root. If omitted, auto-search workspace/result then legacy contour result roots.',
    )
    ap.add_argument('--step', type=float, default=5.0)
    args = ap.parse_args()

    ws = Path(args.workspace)
    matrix = pd.read_csv(ws / args.matrix)
    candidate_roots = []
    if args.result_root.strip():
        candidate_roots.append(Path(args.result_root.strip()))
    else:
        # Prefer workspace-local result folder, then legacy locations.
        candidate_roots.extend([
            ws / 'result',
            Path('/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/analysis_crossvar_bundle_20260513/result'),
            Path('/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result'),
        ])

    rows = []
    dist = {}

    for _, r in matrix.iterrows():
        if int(r['enabled']) != 1:
            continue
        run_key = str(r['run_key'])
        outdir_tag = str(r['outdir_tag'])
        result_dir = find_result_dir(candidate_roots, outdir_tag)
        if result_dir is None:
            for ch in ['rSO2_Ch1', 'rSO2_Ch2', 'rSO2_Ch3']:
                rows.append({'run_key': run_key, 'outdir_tag': outdir_tag, 'ycol': ch, 'status': 'missing_result_dir'})
            continue

        for ch in ['rSO2_Ch1', 'rSO2_Ch2', 'rSO2_Ch3']:
            curve = next(result_dir.rglob(f"{ch}_ET_CO2_*_slice_median_curve_boot.csv"), None)
            if curve is None:
                rows.append({'run_key': run_key, 'outdir_tag': outdir_tag, 'ycol': ch, 'status': 'missing_curve', 'result_dir': str(result_dir)})
                continue
            d, lo, hi, arr = delta_from_curve(curve, step=args.step)
            rows.append({
                'run_key': run_key,
                'outdir_tag': outdir_tag,
                'ycol': ch,
                'status': 'ok',
                'result_dir': str(result_dir),
                'curve_fp': str(curve),
                'delta_rso2_plus5': d,
                'delta_ci_lo': lo,
                'delta_ci_hi': hi,
            })
            dist[(run_key, ch)] = arr

    df = pd.DataFrame(rows)
    out_tables = ws / 'output' / 'tables' / 'sensitivity_ventcov'
    out_tables.mkdir(parents=True, exist_ok=True)
    sum_fp = out_tables / 'etco2_sensitivity_5model_summary.csv'
    df.to_csv(sum_fp, index=False)

    for c in ['delta_rso2_plus5','delta_ci_lo','delta_ci_hi']:
        if c not in df.columns:
            df[c] = np.nan

    base = df[(df['run_key'] == 'base') & (df['status'] == 'ok')][['ycol','delta_rso2_plus5']].rename(columns={'delta_rso2_plus5':'base_delta'})
    m = df[df['status']=='ok'].merge(base, on='ycol', how='left')
    if len(m) == 0:
        att_fp = out_tables / 'etco2_attenuation_vs_base.csv'
        pd.DataFrame(columns=['run_key','ycol','attenuation_vs_base','attenuation_ci_lo','attenuation_ci_hi']).to_csv(att_fp, index=False)
        print('summary:', sum_fp)
        print('attenuation:', att_fp)
        return

    m['attenuation_vs_base'] = (m['base_delta'] - m['delta_rso2_plus5']) / m['base_delta']

    ci_lo, ci_hi = [], []
    for _, rr in m.iterrows():
        ch = rr['ycol']
        rk = rr['run_key']
        if rk == 'base':
            ci_lo.append(0.0); ci_hi.append(0.0); continue
        a = dist.get(('base', ch), None)
        b = dist.get((rk, ch), None)
        if a is None or b is None:
            ci_lo.append(np.nan); ci_hi.append(np.nan); continue
        n = min(len(a), len(b))
        aa, bb = np.array(a[:n], float), np.array(b[:n], float)
        mask = np.abs(aa) > 1e-8
        if mask.sum() < 20:
            ci_lo.append(np.nan); ci_hi.append(np.nan); continue
        att = (aa[mask] - bb[mask]) / aa[mask]
        ci_lo.append(float(np.quantile(att, 0.025)))
        ci_hi.append(float(np.quantile(att, 0.975)))

    m['attenuation_ci_lo'] = ci_lo
    m['attenuation_ci_hi'] = ci_hi

    att_fp = out_tables / 'etco2_attenuation_vs_base.csv'
    m.to_csv(att_fp, index=False)
    print('summary:', sum_fp)
    print('attenuation:', att_fp)


if __name__ == '__main__':
    main()
