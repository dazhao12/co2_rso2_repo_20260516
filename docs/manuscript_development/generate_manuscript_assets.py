from pathlib import Path
import html
import math

import pandas as pd
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "manuscript_development" / "generated_assets"
OUT.mkdir(parents=True, exist_ok=True)

RUN_DIR = (
    ROOT
    / "results"
    / "model_runs"
    / "v5_6_2026_rev2_20260506_co2tempfio2_hemo_adj_boot20_rso2_25_95_full_20260512_152154_overall_mapci_te_n10000_boot200"
)

CHANNEL_LABELS = {
    "rSO2_Ch1": "Left SctO2",
    "rSO2_Ch2": "Right SctO2",
    "rSO2_Ch3": "SftO2",
}

EXPOSURE_LABELS = {
    "ET_CO2": "EtCO2",
    "FiO2_new": "FiO2",
    "TEMP": "Temperature",
}


def fmt(x, digits=2):
    return f"{float(x):.{digits}f}"


def write_tables():
    effects = pd.read_csv(ROOT / "code" / "analysis_bundle" / "output" / "tables" / "crossvar_effect_summary.csv")
    effects = effects[effects["xvar"].isin(["ET_CO2", "FiO2_new", "TEMP"])].copy()
    effects["Outcome channel"] = effects["ycol"].map(CHANNEL_LABELS)
    effects["Exposure"] = effects["xvar"].map(EXPOSURE_LABELS)
    effects["Clinical increment"] = effects["xvar"].map(
        {"ET_CO2": "+5 mmHg", "FiO2_new": "+10 percentage points", "TEMP": "+0.5 C"}
    )
    effects["Adjusted rSO2 difference, percentage points"] = effects["delta_rso2_clinical_step"].map(lambda x: fmt(x))
    effects["95% CI"] = effects.apply(
        lambda r: f"{fmt(r['delta_rso2_ci_lo'])} to {fmt(r['delta_rso2_ci_hi'])}", axis=1
    )
    table2 = effects[
        [
            "Outcome channel",
            "Exposure",
            "Clinical increment",
            "Adjusted rSO2 difference, percentage points",
            "95% CI",
        ]
    ]
    table2.to_csv(OUT / "table2_clinical_step_contrasts.csv", index=False, encoding="utf-8-sig")
    table2.to_excel(OUT / "table2_clinical_step_contrasts.xlsx", index=False)

    perf = pd.read_csv(ROOT / "results" / "supplemental_etables" / "supplemental_etable6_model_performance_co2_rso2.csv")
    terms = pd.read_csv(ROOT / "results" / "supplemental_etables" / "supplemental_etable7_nonparametric_terms_co2_rso2.csv")
    rows = []
    for ycol, label in CHANNEL_LABELS.items():
        p = perf[perf["ycol"] == ycol].set_index("metric")["value"]
        t = terms[(terms["ycol"] == ycol) & (terms["variable"] == "ET_CO2")].iloc[0]
        rows.append(
            {
                "Outcome channel": label,
                "Sampled observations": int(float(p["N Samples"])),
                "Model features": int(float(p["N Features"])),
                "Effective DOF": round(float(p["Effective DOF (model)"]), 2),
                "Deviance explained": round(float(p["Deviance Explained"]), 3),
                "EtCO2 smooth EDF": round(float(t["effect_degrees_of_freedom"]), 2),
                "EtCO2 smooth p value": t["p_value_display"],
            }
        )
    diag = pd.DataFrame(rows)
    diag.to_csv(OUT / "supplementary_model_diagnostics.csv", index=False, encoding="utf-8-sig")
    diag.to_excel(OUT / "supplementary_model_diagnostics.xlsx", index=False)
    return table2, diag


def write_table1_assets():
    table_dir = ROOT / "results" / "manuscript_tables"
    wide_path = table_dir / "table1_2_co2_rso2_wide.csv"
    long_path = table_dir / "table1_2_co2_rso2_long.csv"
    flow_path = table_dir / "table1_2_co2_rso2_flow_counts.csv"
    wide = pd.read_csv(wide_path)
    long = pd.read_csv(long_path)
    flow = pd.read_csv(flow_path)

    flow_final = flow[flow["stage"] == "final_usable_points_strict_etco2_rso2"].copy()
    flow_final["Outcome channel"] = flow_final["ycol"].map(CHANNEL_LABELS)
    obs_map = dict(zip(flow_final["Outcome channel"], flow_final["n_rows"].map(lambda x: f"{int(x):,}")))

    row_map = {
        "Patients, n": "Patients, n",
        "Age, mean (SD)": "Age, years, mean (s.d.)",
        "BMI, mean (SD)": "Body mass index, kg/m2, mean (s.d.)",
        "SEX, n (%)": "SEX=1, n (%)",
        "Diabetes_status, n (%)": "Diabetes, n (%)",
        "Hypertension, n (%)": "Hypertension, n (%)",
        "Drinking_status, n (%)": "Drinking history, n (%)",
        "Hb, mean (SD)": "Haemoglobin, g/L, mean (s.d.)",
        "Cardiac_index, mean (SD)": "Baseline cardiac index, L/min/m2, mean (s.d.)",
        "Mean_blood_pressure, mean (SD)": "Baseline mean blood pressure, mmHg, mean (s.d.)",
        "ET_CO2, mean (SD)": "EtCO2, mmHg, mean (s.d.)",
        "FiO2_new, mean (SD)": "FiO2, %, mean (s.d.)",
        "TEMP, mean (SD)": "Temperature, C, mean (s.d.)",
        "MAP, mean (SD)": "Intraoperative MAP, mmHg, mean (s.d.)",
        "CI, mean (SD)": "Intraoperative cardiac index, L/min/m2, mean (s.d.)",
        "rSO2_Ch1, mean (SD)": "Left SctO2, %, mean (s.d.)",
        "rSO2_Ch2, mean (SD)": "Right SctO2, %, mean (s.d.)",
        "rSO2_Ch3, mean (SD)": "SftO2, %, mean (s.d.)",
    }
    desired = [
        "Patients, n",
        "Timestamp-level observations, n",
        "Age, mean (SD)",
        "BMI, mean (SD)",
        "SEX, n (%)",
        "Diabetes_status, n (%)",
        "Hypertension, n (%)",
        "Drinking_status, n (%)",
        "Hb, mean (SD)",
        "Cardiac_index, mean (SD)",
        "Mean_blood_pressure, mean (SD)",
        "ET_CO2, mean (SD)",
        "FiO2_new, mean (SD)",
        "TEMP, mean (SD)",
        "MAP, mean (SD)",
        "CI, mean (SD)",
        "rSO2_Ch1, mean (SD)",
        "rSO2_Ch2, mean (SD)",
        "rSO2_Ch3, mean (SD)",
    ]

    rows = []
    for key in desired:
        if key == "Timestamp-level observations, n":
            row = {"Characteristic": "Timestamp-level observations, n"}
            for label in CHANNEL_LABELS.values():
                row[label] = obs_map.get(label, "")
            rows.append(row)
            continue
        matches = wide[wide["characteristic"] == key]
        if matches.empty:
            continue
        src = matches.iloc[0]
        row = {"Characteristic": row_map[key]}
        for label in CHANNEL_LABELS.values():
            row[label] = src.get(label, "")
        rows.append(row)
    table1 = pd.DataFrame(rows)
    table1.to_csv(OUT / "table1_cohort_characteristics.csv", index=False, encoding="utf-8-sig")
    table1.to_excel(OUT / "table1_cohort_characteristics.xlsx", index=False)

    with pd.ExcelWriter(OUT / "supplementary_etable1_2_cohort_characteristics.xlsx") as writer:
        wide.to_excel(writer, sheet_name="wide", index=False)
        long.to_excel(writer, sheet_name="long", index=False)
        flow.to_excel(writer, sheet_name="flow_counts", index=False)

    long.to_csv(OUT / "supplementary_etable1_2_cohort_characteristics_long.csv", index=False, encoding="utf-8-sig")
    return table1


def read_etco2_curves():
    dfs = []
    for ycol in CHANNEL_LABELS:
        p = RUN_DIR / ycol / "1s" / "sub10000" / "ET_CO2" / f"{ycol}_ET_CO2_1s_sub10000_slice_median_curve_boot.csv"
        df = pd.read_csv(p)
        df["channel_label"] = CHANNEL_LABELS[ycol]
        dfs.append(df)
    curves = pd.concat(dfs, ignore_index=True)
    curves.to_csv(OUT / "source_data_figure2_etco2_curves.csv", index=False, encoding="utf-8-sig")
    return curves


def path_poly(points):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in points)


def svg_text(x, y, text, size=12, anchor="middle", weight="normal", fill="#111"):
    return (
        f'<text x="{x:.1f}" y="{y:.1f}" font-family="Arial, Helvetica, sans-serif" '
        f'font-size="{size}" text-anchor="{anchor}" font-weight="{weight}" fill="{fill}">'
        f"{html.escape(str(text))}</text>"
    )


def font(size, bold=False):
    candidates = [
        "arialbd.ttf" if bold else "arial.ttf",
        "calibrib.ttf" if bold else "calibri.ttf",
    ]
    for name in candidates:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def text(draw, xy, value, size=12, anchor="mm", bold=False, fill=(17, 17, 17)):
    draw.text(xy, str(value), font=font(size, bold=bold), anchor=anchor, fill=fill)


def make_figure2(curves):
    width, height = 1500, 520
    margin_left, margin_right, margin_top, margin_bottom = 70, 30, 95, 70
    gap = 45
    panel_w = (width - margin_left - margin_right - 2 * gap) / 3
    panel_h = height - margin_top - margin_bottom
    x_min, x_max = 21, 49
    y_min = math.floor(curves["pred_lo_2.5"].min()) - 1
    y_max = math.ceil(curves["pred_hi_97.5"].max()) + 1

    def sx(x, idx):
        left = margin_left + idx * (panel_w + gap)
        return left + (float(x) - x_min) / (x_max - x_min) * panel_w

    def sy(y):
        return margin_top + (y_max - float(y)) / (y_max - y_min) * panel_h

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        svg_text(width / 2, 26, "Adjusted EtCO2-rSO2 relationships", 20, weight="bold"),
        svg_text(width / 2, 52, "Solid lines show adjusted means; bands show 95% bootstrap intervals", 12, fill="#444"),
    ]
    for idx, (ycol, label) in enumerate(CHANNEL_LABELS.items()):
        left = margin_left + idx * (panel_w + gap)
        right = left + panel_w
        top = margin_top
        bottom = top + panel_h
        parts.append(f'<rect x="{left:.1f}" y="{top:.1f}" width="{panel_w:.1f}" height="{panel_h:.1f}" fill="#FFFFFF" stroke="#222" stroke-width="1"/>')
        for ytick in range(int(y_min), int(y_max) + 1, 2):
            y = sy(ytick)
            parts.append(f'<line x1="{left:.1f}" x2="{right:.1f}" y1="{y:.1f}" y2="{y:.1f}" stroke="#E5E7EB" stroke-width="1"/>')
            if idx == 0:
                parts.append(svg_text(left - 10, y + 4, ytick, 11, anchor="end", fill="#333"))
        for xtick in [20, 25, 30, 35, 40, 45, 50]:
            if xtick < x_min or xtick > x_max:
                continue
            x = sx(xtick, idx)
            parts.append(f'<line x1="{x:.1f}" x2="{x:.1f}" y1="{top:.1f}" y2="{bottom:.1f}" stroke="#F0F0F0" stroke-width="1"/>')
            parts.append(svg_text(x, bottom + 22, xtick, 11, fill="#333"))
        for marker in [35, 40]:
            x = sx(marker, idx)
            parts.append(f'<line x1="{x:.1f}" x2="{x:.1f}" y1="{top:.1f}" y2="{bottom:.1f}" stroke="#888" stroke-width="1" stroke-dasharray="4 4"/>')
        sub = curves[curves["ycol"] == ycol].sort_values("x")
        upper = [(sx(r.x, idx), sy(getattr(r, "pred_hi_97_5", r["pred_hi_97.5"]))) for _, r in sub.iterrows()]
        lower = [(sx(r.x, idx), sy(getattr(r, "pred_lo_2_5", r["pred_lo_2.5"]))) for _, r in sub.iloc[::-1].iterrows()]
        mean = [(sx(r.x, idx), sy(r.pred_mean)) for _, r in sub.iterrows()]
        parts.append(f'<polygon points="{path_poly(upper + lower)}" fill="#93C5FD" opacity="0.35" stroke="none"/>')
        parts.append(f'<polyline points="{path_poly(mean)}" fill="none" stroke="#1D4ED8" stroke-width="3"/>')
        parts.append(svg_text((left + right) / 2, top - 18, label, 14, weight="bold"))
        parts.append(svg_text((left + right) / 2, height - 18, "EtCO2 (mmHg)", 12))
    parts.append(svg_text(margin_left, margin_top - 20, "Adjusted rSO2 (%)", 12, anchor="start"))
    parts.append("</svg>")
    (OUT / "figure2_etco2_adjusted_curves.svg").write_text("\n".join(parts), encoding="utf-8")
    make_figure2_png(curves)


def make_figure2_png(curves):
    scale = 2
    width, height = 1500, 520
    img = Image.new("RGB", (width * scale, height * scale), "white")
    draw = ImageDraw.Draw(img, "RGBA")

    def S(v):
        return float(v) * scale

    margin_left, margin_right, margin_top, margin_bottom = 70, 30, 95, 70
    gap = 45
    panel_w = (width - margin_left - margin_right - 2 * gap) / 3
    panel_h = height - margin_top - margin_bottom
    x_min, x_max = 21, 49
    y_min = math.floor(curves["pred_lo_2.5"].min()) - 1
    y_max = math.ceil(curves["pred_hi_97.5"].max()) + 1

    def sx(x, idx):
        left = margin_left + idx * (panel_w + gap)
        return left + (float(x) - x_min) / (x_max - x_min) * panel_w

    def sy(y):
        return margin_top + (y_max - float(y)) / (y_max - y_min) * panel_h

    text(draw, (S(width / 2), S(26)), "Adjusted EtCO2-rSO2 relationships", 20 * scale, bold=True)
    text(draw, (S(width / 2), S(52)), "Solid lines show adjusted means; bands show 95% bootstrap intervals", 12 * scale, fill=(68, 68, 68))

    for idx, (ycol, label) in enumerate(CHANNEL_LABELS.items()):
        left = margin_left + idx * (panel_w + gap)
        right = left + panel_w
        top = margin_top
        bottom = top + panel_h
        draw.rectangle([S(left), S(top), S(right), S(bottom)], outline=(34, 34, 34), width=2)
        for ytick in range(int(y_min), int(y_max) + 1, 2):
            y = sy(ytick)
            draw.line([S(left), S(y), S(right), S(y)], fill=(229, 231, 235), width=1)
            if idx == 0:
                text(draw, (S(left - 10), S(y + 4)), ytick, 11 * scale, anchor="rm", fill=(51, 51, 51))
        for xtick in [25, 30, 35, 40, 45]:
            x = sx(xtick, idx)
            draw.line([S(x), S(top), S(x), S(bottom)], fill=(240, 240, 240), width=1)
            text(draw, (S(x), S(bottom + 22)), xtick, 11 * scale, fill=(51, 51, 51))
        for marker in [35, 40]:
            x = sx(marker, idx)
            y = top
            while y < bottom:
                draw.line([S(x), S(y), S(x), S(min(y + 4, bottom))], fill=(136, 136, 136), width=2)
                y += 8
        sub = curves[curves["ycol"] == ycol].sort_values("x")
        upper = [(S(sx(r["x"], idx)), S(sy(r["pred_hi_97.5"]))) for _, r in sub.iterrows()]
        lower = [(S(sx(r["x"], idx)), S(sy(r["pred_lo_2.5"]))) for _, r in sub.iloc[::-1].iterrows()]
        mean = [(S(sx(r["x"], idx)), S(sy(r["pred_mean"]))) for _, r in sub.iterrows()]
        draw.polygon(upper + lower, fill=(147, 197, 253, 90))
        draw.line(mean, fill=(29, 78, 216), width=6, joint="curve")
        text(draw, (S((left + right) / 2), S(top - 18)), label, 14 * scale, bold=True)
        text(draw, (S((left + right) / 2), S(height - 18)), "EtCO2 (mmHg)", 12 * scale)

    text(draw, (S(margin_left), S(margin_top - 20)), "Adjusted rSO2 (%)", 12 * scale, anchor="lm")
    img = img.resize((width, height), Image.Resampling.LANCZOS)
    img.save(OUT / "figure2_etco2_adjusted_curves.png")


def make_figure3(table2):
    source = table2.copy()
    source.to_csv(OUT / "source_data_figure3_clinical_step.csv", index=False, encoding="utf-8-sig")
    width, height = 1300, 520
    margin_left, margin_right, margin_top, margin_bottom = 70, 30, 95, 80
    gap = 45
    panel_w = (width - margin_left - margin_right - 2 * gap) / 3
    panel_h = height - margin_top - margin_bottom
    y_min, y_max = -1.0, 3.8
    colors = {"EtCO2": "#2563EB", "FiO2": "#16A34A", "Temperature": "#DC2626"}

    def sy(y):
        return margin_top + (y_max - float(y)) / (y_max - y_min) * panel_h

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        svg_text(width / 2, 26, "Adjusted clinical-step contrasts", 20, weight="bold"),
        svg_text(width / 2, 52, "Bars show adjusted rSO2 differences; error bars show 95% bootstrap intervals", 12, fill="#444"),
    ]
    for idx, label in enumerate(CHANNEL_LABELS.values()):
        left = margin_left + idx * (panel_w + gap)
        right = left + panel_w
        top = margin_top
        bottom = top + panel_h
        parts.append(f'<rect x="{left:.1f}" y="{top:.1f}" width="{panel_w:.1f}" height="{panel_h:.1f}" fill="#FFFFFF" stroke="#222" stroke-width="1"/>')
        for ytick in [-1, 0, 1, 2, 3]:
            y = sy(ytick)
            parts.append(f'<line x1="{left:.1f}" x2="{right:.1f}" y1="{y:.1f}" y2="{y:.1f}" stroke="#E5E7EB" stroke-width="1"/>')
            if idx == 0:
                parts.append(svg_text(left - 10, y + 4, ytick, 11, anchor="end", fill="#333"))
        zero = sy(0)
        parts.append(f'<line x1="{left:.1f}" x2="{right:.1f}" y1="{zero:.1f}" y2="{zero:.1f}" stroke="#111" stroke-width="1.2"/>')
        sub = source[source["Outcome channel"] == label]
        for j, exp in enumerate(["EtCO2", "FiO2", "Temperature"]):
            r = sub[sub["Exposure"] == exp].iloc[0]
            delta = float(r["Adjusted rSO2 difference, percentage points"])
            lo, hi = [float(x.strip()) for x in r["95% CI"].split(" to ")]
            cx = left + (j + 0.5) * panel_w / 3
            bar_w = panel_w / 6
            y0, yv = sy(0), sy(delta)
            rect_y = min(y0, yv)
            rect_h = abs(y0 - yv)
            parts.append(f'<rect x="{cx - bar_w / 2:.1f}" y="{rect_y:.1f}" width="{bar_w:.1f}" height="{rect_h:.1f}" fill="{colors[exp]}"/>')
            parts.append(f'<line x1="{cx:.1f}" x2="{cx:.1f}" y1="{sy(lo):.1f}" y2="{sy(hi):.1f}" stroke="#111" stroke-width="1.5"/>')
            parts.append(f'<line x1="{cx - 7:.1f}" x2="{cx + 7:.1f}" y1="{sy(lo):.1f}" y2="{sy(lo):.1f}" stroke="#111" stroke-width="1.5"/>')
            parts.append(f'<line x1="{cx - 7:.1f}" x2="{cx + 7:.1f}" y1="{sy(hi):.1f}" y2="{sy(hi):.1f}" stroke="#111" stroke-width="1.5"/>')
            parts.append(svg_text(cx, bottom + 22, exp, 11))
        parts.append(svg_text((left + right) / 2, top - 18, label, 14, weight="bold"))
    parts.append(svg_text(margin_left, margin_top - 20, "Adjusted rSO2 difference (percentage points)", 12, anchor="start"))
    parts.append("</svg>")
    (OUT / "figure3_clinical_step_contrasts.svg").write_text("\n".join(parts), encoding="utf-8")
    make_figure3_png(table2)


def make_figure3_png(table2):
    scale = 2
    width, height = 1300, 520
    img = Image.new("RGB", (width * scale, height * scale), "white")
    draw = ImageDraw.Draw(img, "RGBA")
    source = table2.copy()
    margin_left, margin_right, margin_top, margin_bottom = 70, 30, 95, 80
    gap = 45
    panel_w = (width - margin_left - margin_right - 2 * gap) / 3
    panel_h = height - margin_top - margin_bottom
    y_min, y_max = -1.0, 3.8
    colors = {"EtCO2": (37, 99, 235), "FiO2": (22, 163, 74), "Temperature": (220, 38, 38)}

    def S(v):
        return float(v) * scale

    def sy(y):
        return margin_top + (y_max - float(y)) / (y_max - y_min) * panel_h

    text(draw, (S(width / 2), S(26)), "Adjusted clinical-step contrasts", 20 * scale, bold=True)
    text(draw, (S(width / 2), S(52)), "Bars show adjusted rSO2 differences; error bars show 95% bootstrap intervals", 12 * scale, fill=(68, 68, 68))

    for idx, label in enumerate(CHANNEL_LABELS.values()):
        left = margin_left + idx * (panel_w + gap)
        right = left + panel_w
        top = margin_top
        bottom = top + panel_h
        draw.rectangle([S(left), S(top), S(right), S(bottom)], outline=(34, 34, 34), width=2)
        for ytick in [-1, 0, 1, 2, 3]:
            y = sy(ytick)
            draw.line([S(left), S(y), S(right), S(y)], fill=(229, 231, 235), width=1)
            if idx == 0:
                text(draw, (S(left - 10), S(y + 4)), ytick, 11 * scale, anchor="rm", fill=(51, 51, 51))
        zero = sy(0)
        draw.line([S(left), S(zero), S(right), S(zero)], fill=(17, 17, 17), width=2)
        sub = source[source["Outcome channel"] == label]
        for j, exp in enumerate(["EtCO2", "FiO2", "Temperature"]):
            r = sub[sub["Exposure"] == exp].iloc[0]
            delta = float(r["Adjusted rSO2 difference, percentage points"])
            lo, hi = [float(x.strip()) for x in r["95% CI"].split(" to ")]
            cx = left + (j + 0.5) * panel_w / 3
            bar_w = panel_w / 6
            y0, yv = sy(0), sy(delta)
            draw.rectangle([S(cx - bar_w / 2), S(min(y0, yv)), S(cx + bar_w / 2), S(max(y0, yv))], fill=colors[exp] + (255,))
            draw.line([S(cx), S(sy(lo)), S(cx), S(sy(hi))], fill=(17, 17, 17), width=3)
            draw.line([S(cx - 7), S(sy(lo)), S(cx + 7), S(sy(lo))], fill=(17, 17, 17), width=3)
            draw.line([S(cx - 7), S(sy(hi)), S(cx + 7), S(sy(hi))], fill=(17, 17, 17), width=3)
            text(draw, (S(cx), S(bottom + 22)), exp, 11 * scale)
        text(draw, (S((left + right) / 2), S(top - 18)), label, 14 * scale, bold=True)

    text(draw, (S(margin_left), S(margin_top - 20)), "Adjusted rSO2 difference", 12 * scale, anchor="lm")
    img = img.resize((width, height), Image.Resampling.LANCZOS)
    img.save(OUT / "figure3_clinical_step_contrasts.png")


def main():
    write_table1_assets()
    table2, diag = write_tables()
    curves = read_etco2_curves()
    make_figure2(curves)
    make_figure3(table2)
    print(OUT)


if __name__ == "__main__":
    main()
