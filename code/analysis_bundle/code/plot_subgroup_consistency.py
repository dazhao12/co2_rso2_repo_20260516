#!/usr/bin/env python3
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, BoundaryNorm


def _order_subgroups(vals):
    preferred = [
        "Age_less_70",
        "Age_more_70",
        "Female",
        "Male",
        "Pre_hypertension_less_140_90",
        "Pre_hypertension_more_140_90",
    ]
    existing = list(dict.fromkeys(vals))
    out = [x for x in preferred if x in existing]
    out.extend([x for x in existing if x not in out])
    return out


def draw_forest(df, out_dir):
    channels = ["rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3"]
    ch_label = {"rSO2_Ch1": "Ch1", "rSO2_Ch2": "Ch2", "rSO2_Ch3": "Ch3"}
    ch_color = {"rSO2_Ch1": "#1f77b4", "rSO2_Ch2": "#2ca02c", "rSO2_Ch3": "#d62728"}
    offsets = {"rSO2_Ch1": -0.22, "rSO2_Ch2": 0.0, "rSO2_Ch3": 0.22}

    sgs = _order_subgroups(df["subgroup"].tolist())
    y_base = np.arange(len(sgs))[::-1]
    y_map = {sg: y for sg, y in zip(sgs, y_base)}

    fig_h = max(5.0, 0.8 * len(sgs) + 1.8)
    fig, ax = plt.subplots(figsize=(10.5, fig_h))

    for ch in channels:
        d = df[df["channel"] == ch]
        xs, ys, xlo, xhi = [], [], [], []
        for _, r in d.iterrows():
            xs.append(float(r["delta_rso2_plus5"]))
            ys.append(y_map[r["subgroup"]] + offsets[ch])
            lo = float(r["delta_ci_lo"]) if pd.notna(r["delta_ci_lo"]) else np.nan
            hi = float(r["delta_ci_hi"]) if pd.notna(r["delta_ci_hi"]) else np.nan
            xlo.append(np.nan if np.isnan(lo) else xs[-1] - lo)
            xhi.append(np.nan if np.isnan(hi) else hi - xs[-1])

        xs = np.array(xs, dtype=float)
        ys = np.array(ys, dtype=float)
        xlo = np.array(xlo, dtype=float)
        xhi = np.array(xhi, dtype=float)
        has_ci = np.isfinite(xlo) & np.isfinite(xhi)

        if np.any(has_ci):
            ax.errorbar(
                xs[has_ci],
                ys[has_ci],
                xerr=[xlo[has_ci], xhi[has_ci]],
                fmt="o",
                ms=6,
                color=ch_color[ch],
                ecolor=ch_color[ch],
                elinewidth=1.2,
                capsize=3,
                label=ch_label[ch],
            )
        if np.any(~has_ci):
            ax.scatter(xs[~has_ci], ys[~has_ci], s=36, color=ch_color[ch], label=None)

    ax.axvline(0.0, color="#444444", linestyle="--", linewidth=1.0, alpha=0.9)
    ax.grid(axis="x", linestyle=":", alpha=0.35)
    ax.set_yticks(y_base)
    ax.set_yticklabels(sgs)
    ax.set_xlabel("Delta rSO2 for +5 mmHg ET_CO2")
    ax.set_ylabel("Subgroup")
    ax.set_title("Subgroup Consistency: ET_CO2 Effect (Model B, n=10000, boot=200)")
    ax.legend(title="Channel", loc="best", frameon=False)
    fig.tight_layout()

    png = out_dir / "subgroup_delta_forest_modelB_n10000_b200.png"
    pdf = out_dir / "subgroup_delta_forest_modelB_n10000_b200.pdf"
    fig.savefig(png, dpi=220)
    fig.savefig(pdf)
    plt.close(fig)
    return png, pdf


def draw_heatmap(df, out_dir):
    channels = ["rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3"]
    sgs = _order_subgroups(df["subgroup"].tolist())
    ch_label = {"rSO2_Ch1": "Ch1", "rSO2_Ch2": "Ch2", "rSO2_Ch3": "Ch3"}

    mat = np.full((len(sgs), len(channels)), np.nan)
    anno = np.empty((len(sgs), len(channels)), dtype=object)
    for i, sg in enumerate(sgs):
        for j, ch in enumerate(channels):
            r = df[(df["subgroup"] == sg) & (df["channel"] == ch)]
            if r.empty:
                anno[i, j] = ""
                continue
            rr = r.iloc[0]
            d = float(rr["delta_rso2_plus5"])
            lo = float(rr["delta_ci_lo"]) if pd.notna(rr["delta_ci_lo"]) else np.nan
            hi = float(rr["delta_ci_hi"]) if pd.notna(rr["delta_ci_hi"]) else np.nan
            if np.isfinite(lo) and np.isfinite(hi) and lo <= 0.0 <= hi:
                v = 0
            else:
                v = 1 if d > 0 else (-1 if d < 0 else 0)
            mat[i, j] = v
            anno[i, j] = f"{d:.2f}"

    cmap = ListedColormap(["#d95f5f", "#e3e3e3", "#4f86c6"])
    norm = BoundaryNorm([-1.5, -0.5, 0.5, 1.5], cmap.N)

    fig_h = max(4.2, 0.8 * len(sgs) + 1.5)
    fig, ax = plt.subplots(figsize=(8.6, fig_h))
    im = ax.imshow(mat, cmap=cmap, norm=norm, aspect="auto")
    ax.set_xticks(np.arange(len(channels)))
    ax.set_xticklabels([ch_label[c] for c in channels])
    ax.set_yticks(np.arange(len(sgs)))
    ax.set_yticklabels(sgs)
    ax.set_xlabel("Channel")
    ax.set_ylabel("Subgroup")
    ax.set_title("Direction Consistency Heatmap (value = Delta rSO2 for +5 mmHg)")

    for i in range(mat.shape[0]):
        for j in range(mat.shape[1]):
            txt = anno[i, j]
            if txt == "":
                continue
            ax.text(j, i, txt, ha="center", va="center", fontsize=9, color="#111111")

    cbar = fig.colorbar(im, ax=ax, fraction=0.046, pad=0.03, ticks=[-1, 0, 1])
    cbar.ax.set_yticklabels(["Opposite", "Uncertain", "Same direction"])
    fig.tight_layout()

    png = out_dir / "subgroup_direction_heatmap_modelB_n10000_b200.png"
    pdf = out_dir / "subgroup_direction_heatmap_modelB_n10000_b200.pdf"
    fig.savefig(png, dpi=220)
    fig.savefig(pdf)
    plt.close(fig)
    return png, pdf


def main():
    repo = Path("/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516")
    in_fp = repo / "code/analysis_bundle/output/tables/subgroup_consistency_etco2_delta_plus5_modelB_n10000_b200.csv"
    out_dir = repo / "code/analysis_bundle/output/figures"
    out_dir.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(in_fp)
    df = df[df["status"] == "ok"].copy()
    if df.empty:
        raise RuntimeError(f"No usable rows in {in_fp}")

    p1, p2 = draw_forest(df, out_dir)
    p3, p4 = draw_heatmap(df, out_dir)
    print(str(p1))
    print(str(p2))
    print(str(p3))
    print(str(p4))


if __name__ == "__main__":
    main()
