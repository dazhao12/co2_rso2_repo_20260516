#!/usr/bin/env python3
import argparse
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

RUN_TO_MED = {
    'rrtotal_only': 'RRtotal',
    'tvinsp_only': 'TVinsp',
    'pmean_only': 'Pmean',
}


def interp(x, y, xq):
    return float(np.interp(float(xq), x, y))


def load_delta_boot(curve_fp, step=5.0):
    df = pd.read_csv(curve_fp)
    x = pd.to_numeric(df['x'], errors='coerce').to_numpy(dtype=float)
    y = pd.to_numeric(df['pred_mean'], errors='coerce').to_numpy(dtype=float)
    good = np.isfinite(x) & np.isfinite(y)
    x, y = x[good], y[good]
    idx = np.argsort(x)
    x, y = x[idx], y[idx]
    x0 = float(np.nanmedian(x))
    x1 = min(float(np.nanmax(x)), x0 + step)
    if x1 <= x0:
        x0, x1 = float(np.nanmin(x)), float(np.nanmax(x))
    d = interp(x, y, x1) - interp(x, y, x0)

    mat_fp = Path(str(curve_fp).replace('_curve_boot.csv', '_boot_raw_curve_matrix.csv'))
    if not mat_fp.exists():
        return d, None
    mat = pd.read_csv(mat_fp).to_numpy(dtype=float)
    if mat.shape[1] != len(x):
        x_mat = np.linspace(float(np.nanmin(x)), float(np.nanmax(x)), mat.shape[1])
    else:
        x_mat = x
    ds = []
    for row in mat:
        if not np.all(np.isfinite(row)):
            continue
        ds.append(interp(x_mat, row, x1) - interp(x_mat, row, x0))
    if len(ds) < 20:
        return d, None
    return d, np.array(ds, dtype=float)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--workspace', default='/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/analysis_crossvar_bundle_20260513')
    ap.add_argument('--summary-csv', default='output/tables/etco2_sensitivity_5model_summary.csv')
    ap.add_argument('--step', type=float, default=5.0)
    args = ap.parse_args()

    ws = Path(args.workspace)
    df = pd.read_csv(ws / args.summary_csv)
    ok = df[df['status'] == 'ok'].copy()

    rows_eff, rows_boot = [], []

    for ch in ['rSO2_Ch1', 'rSO2_Ch2', 'rSO2_Ch3']:
        b = ok[(ok['run_key'] == 'base') & (ok['ycol'] == ch)]
        if b.empty:
            continue
        b = b.iloc[0]
        te, te_boot = load_delta_boot(Path(b['curve_fp']), step=args.step)

        for run_key, med in RUN_TO_MED.items():
            m = ok[(ok['run_key'] == run_key) & (ok['ycol'] == ch)]
            if m.empty:
                rows_eff.append({'ycol': ch, 'mediator': med, 'status': 'missing_model'})
                continue
            m = m.iloc[0]
            nde, nde_boot = load_delta_boot(Path(m['curve_fp']), step=args.step)
            nie = te - nde
            pm = nie / te if abs(te) > 1e-8 else np.nan

            te_lo = te_hi = nde_lo = nde_hi = nie_lo = nie_hi = pm_lo = pm_hi = np.nan
            if te_boot is not None and nde_boot is not None:
                n = min(len(te_boot), len(nde_boot))
                te_arr = te_boot[:n]
                nde_arr = nde_boot[:n]
                nie_arr = te_arr - nde_arr
                mask = np.abs(te_arr) > 1e-8
                pm_arr = np.full_like(nie_arr, np.nan)
                pm_arr[mask] = nie_arr[mask] / te_arr[mask]

                te_lo, te_hi = np.quantile(te_arr, [0.025, 0.975])
                nde_lo, nde_hi = np.quantile(nde_arr, [0.025, 0.975])
                nie_lo, nie_hi = np.quantile(nie_arr, [0.025, 0.975])
                if np.isfinite(pm_arr).sum() >= 20:
                    pm_lo, pm_hi = np.nanquantile(pm_arr, [0.025, 0.975])

                for i in range(n):
                    rows_boot.append({
                        'ycol': ch,
                        'mediator': med,
                        'rep': i + 1,
                        'TE': float(te_arr[i]),
                        'NDE': float(nde_arr[i]),
                        'NIE': float(nie_arr[i]),
                        'PM': float(pm_arr[i]) if np.isfinite(pm_arr[i]) else np.nan,
                    })

            rows_eff.append({
                'ycol': ch,
                'mediator': med,
                'status': 'ok',
                'TE': te,
                'TE_ci_lo': te_lo,
                'TE_ci_hi': te_hi,
                'NDE': nde,
                'NDE_ci_lo': nde_lo,
                'NDE_ci_hi': nde_hi,
                'NIE': nie,
                'NIE_ci_lo': nie_lo,
                'NIE_ci_hi': nie_hi,
                'PM': pm,
                'PM_ci_lo': pm_lo,
                'PM_ci_hi': pm_hi,
                'method_note': 'TE from base model, NDE from +single mediator model, NIE=TE-NDE',
            })

    eff = pd.DataFrame(rows_eff)
    boot = pd.DataFrame(rows_boot)
    if 'status' not in eff.columns:
        eff = pd.DataFrame(columns=['ycol','mediator','status','TE','TE_ci_lo','TE_ci_hi','NDE','NDE_ci_lo','NDE_ci_hi','NIE','NIE_ci_lo','NIE_ci_hi','PM','PM_ci_lo','PM_ci_hi','method_note'])

    out_tab = ws / 'output' / 'tables'
    out_fig = ws / 'output' / 'figures'
    out_tab.mkdir(parents=True, exist_ok=True)
    out_fig.mkdir(parents=True, exist_ok=True)

    eff_fp = out_tab / 'mediation_singleM_effects.csv'
    boot_fp = out_tab / 'mediation_singleM_bootstrap.csv'
    eff.to_csv(eff_fp, index=False)
    boot.to_csv(boot_fp, index=False)

    # Forest plot for NIE and PM
    ok_eff = eff[eff['status'] == 'ok'].copy()
    if len(ok_eff):
        labels = [f"{r['ycol']} | {r['mediator']}" for _, r in ok_eff.iterrows()]
        y = np.arange(len(ok_eff))[::-1]

        fig, axes = plt.subplots(1, 2, figsize=(14, max(6, 0.45 * len(ok_eff) + 2)), sharey=True)

        # NIE
        axes[0].axvline(0, color='black', lw=0.8)
        axes[0].errorbar(ok_eff['NIE'], y,
                         xerr=[ok_eff['NIE'] - ok_eff['NIE_ci_lo'], ok_eff['NIE_ci_hi'] - ok_eff['NIE']],
                         fmt='o', color='#1f77b4', ecolor='#1f77b4', capsize=3)
        axes[0].set_yticks(y)
        axes[0].set_yticklabels(labels, fontsize=9)
        axes[0].set_title('NIE (Delta rSO2)')
        axes[0].grid(alpha=0.2, axis='x')

        # PM
        axes[1].axvline(0, color='black', lw=0.8)
        axes[1].errorbar(ok_eff['PM'], y,
                         xerr=[ok_eff['PM'] - ok_eff['PM_ci_lo'], ok_eff['PM_ci_hi'] - ok_eff['PM']],
                         fmt='o', color='#d62728', ecolor='#d62728', capsize=3)
        axes[1].set_title('Proportion Mediated (PM)')
        axes[1].grid(alpha=0.2, axis='x')

        fig.suptitle('Single-mediator decomposition (ET_CO2 -> rSO2)', fontsize=13)
        fig.tight_layout(rect=[0, 0, 1, 0.96])
        png = out_fig / 'mediation_singleM_forest_plot.png'
        pdf = out_fig / 'mediation_singleM_forest_plot.pdf'
        fig.savefig(png, dpi=300)
        fig.savefig(pdf)
        plt.close(fig)

    print('effects:', eff_fp)
    print('bootstrap:', boot_fp)


if __name__ == '__main__':
    main()
