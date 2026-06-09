#!/usr/bin/env python3
import csv
import html
import math
import shutil
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


WORKSPACE = Path(__file__).resolve().parents[1]
OUT = WORKSPACE / "output"
TABLES = OUT / "tables"
PPT = OUT / "ppt"
TEMPLATE = PPT / "crossvar_summary_n10000.pptx"
MAIN_CSV = TABLES / "crossvar_effect_summary_n10000_overall_mapci_te_boot200.csv"
SENS_CSV = TABLES / "crossvar_effect_summary_all_intraop_n10000_mapci_te.csv"
SEG_CSV = TABLES / "crossvar_slope_bins_n10000_overall_mapci_te_boot200.csv"
OUT_PPTX = PPT / "crossvar_clinical_step_median_iqr_ppt_only.pptx"

EMU = 914400
SLIDE_W = 12192000
SLIDE_H = 6858000

CHANNELS = [
    ("rSO2_Ch1", "Left SctO2"),
    ("rSO2_Ch2", "Right SctO2"),
    ("rSO2_Ch3", "SftO2"),
]
EXPOSURES = [
    ("ET_CO2", "EtCO2", "#2563EB"),
    ("FiO2_new", "FiO2", "#16A34A"),
    ("TEMP", "Temperature", "#DC2626"),
]
SENS_EXPOSURES = EXPOSURES + [
    ("MAP", "MAP", "#7C3AED"),
    ("CI", "CI", "#92400E"),
]


def read_rows(fp):
    with fp.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def esc(s):
    return html.escape(str(s), quote=False)


def e(v):
    return str(int(round(float(v) * EMU)))


def color_hex(c):
    return c.strip("#").upper()


def srgb(c):
    return f'<a:solidFill><a:srgbClr val="{color_hex(c)}"/></a:solidFill>'


def nofill():
    return "<a:noFill/>"


class Slide:
    def __init__(self):
        self.parts = []
        self.next_id = 2

    def _id(self):
        i = self.next_id
        self.next_id += 1
        return i

    def text(self, x, y, w, h, text, size=14, bold=False, color="#111111", align="l"):
        sid = self._id()
        paras = str(text).split("\n")
        pxml = []
        for p in paras:
            pxml.append(
                f'<a:p><a:pPr algn="{align}"/>'
                f'<a:r><a:rPr lang="en-US" sz="{int(size * 100)}"'
                f'{" b=\"1\"" if bold else ""}>{srgb(color)}</a:rPr><a:t>{esc(p)}</a:t></a:r>'
                f'</a:p>'
            )
        self.parts.append(
            f'<p:sp><p:nvSpPr><p:cNvPr id="{sid}" name="Text {sid}"/>'
            f'<p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
            f'<p:spPr><a:xfrm><a:off x="{e(x)}" y="{e(y)}"/>'
            f'<a:ext cx="{e(w)}" cy="{e(h)}"/></a:xfrm>'
            f'<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{nofill()}'
            f'<a:ln>{nofill()}</a:ln></p:spPr>'
            f'<p:txBody><a:bodyPr wrap="square"/><a:lstStyle/>{"".join(pxml)}</p:txBody></p:sp>'
        )

    def rect(self, x, y, w, h, fill="#FFFFFF", line="#111111", lw=1, text="", size=10, bold=False, align="ctr"):
        sid = self._id()
        line_xml = f'<a:ln w="{int(lw * 12700)}">{srgb(line)}</a:ln>' if line else f"<a:ln>{nofill()}</a:ln>"
        if text:
            tx = (
                f'<p:txBody><a:bodyPr wrap="square" anchor="ctr"/><a:lstStyle/>'
                f'<a:p><a:pPr algn="{align}"/><a:r><a:rPr lang="en-US" sz="{int(size * 100)}"'
                f'{" b=\"1\"" if bold else ""}>{srgb("#111111")}</a:rPr><a:t>{esc(text)}</a:t></a:r></a:p>'
                f'</p:txBody>'
            )
        else:
            tx = '<p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>'
        self.parts.append(
            f'<p:sp><p:nvSpPr><p:cNvPr id="{sid}" name="Rect {sid}"/>'
            f'<p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr>'
            f'<a:xfrm><a:off x="{e(x)}" y="{e(y)}"/><a:ext cx="{e(w)}" cy="{e(h)}"/></a:xfrm>'
            f'<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>{srgb(fill)}{line_xml}'
            f'</p:spPr>{tx}</p:sp>'
        )

    def xml(self):
        return (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
            'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
            '<p:cSld><p:spTree>'
            '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
            '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
            '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
            + "".join(self.parts)
            + '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>'
        )


def fnum(x, digits=2):
    try:
        return f"{float(x):.{digits}f}"
    except Exception:
        return ""


def by_key(rows):
    return {(r.get("ycol"), r.get("xvar")): r for r in rows}


def draw_title(slide, title, subtitle=""):
    slide.text(0.45, 0.25, 12.2, 0.4, title, size=22, bold=True, align="ctr")
    if subtitle:
        slide.text(0.65, 0.68, 11.8, 0.35, subtitle, size=11, color="#444444", align="ctr")


def slide_title(main_rows, sens_rows):
    s = Slide()
    draw_title(s, "Clinical-step effects across model-input 5%-95% windows")
    s.text(
        0.9,
        1.35,
        11.5,
        2.4,
        "Method: for each exposure and outcome, the final model fitting-sample 5%-95% range was split into 20 equal-width segments. "
        "Each segment effect is the adjusted mean curve slope multiplied by a clinically meaningful increment; the summary is median (IQR) across the 20 segment effects.\n\n"
        "Primary exposures: EtCO2 +5 mmHg, FiO2 +5 percentage points, temperature +0.5 C.\n"
        "Sensitivity exposures requested: MAP +5 mmHg and CI +0.05. Current MAP/CI rows are marked missing until MAP/CI slice curves are exported from the model run.",
        size=15,
        color="#222222",
    )
    s.rect(0.9, 4.25, 11.4, 0.85, fill="#F8FAFC", line="#CBD5E1")
    s.text(
        1.15,
        4.42,
        10.8,
        0.42,
        f"Primary table rows: {sum(1 for r in main_rows if r.get('status') == 'ok')}/9 complete. "
        f"Sensitivity rows: {len(sens_rows)} total, {sum(1 for r in sens_rows if r.get('status') == 'missing')} missing.",
        size=14,
        bold=True,
        align="ctr",
    )
    return s


def slide_bar(main_rows):
    s = Slide()
    draw_title(s, "Median clinical-step effect, primary exposures", "Error bars show IQR across 20 segments")
    data = by_key(main_rows)
    vals = [float(data[(ch, x)]["delta_rso2_clinical_step"]) for ch, _ in CHANNELS for x, _, _ in EXPOSURES]
    los = [float(data[(ch, x)]["delta_rso2_iqr_lo"]) for ch, _ in CHANNELS for x, _, _ in EXPOSURES]
    his = [float(data[(ch, x)]["delta_rso2_iqr_hi"]) for ch, _ in CHANNELS for x, _, _ in EXPOSURES]
    y_min = min(-0.5, math.floor(min(los) * 2) / 2)
    y_max = max(3.5, math.ceil(max(his) * 2) / 2)
    left, top, width, height = 0.85, 1.25, 11.8, 4.8

    def sy(v):
        return top + (y_max - v) / (y_max - y_min) * height

    s.text(0.15, top - 0.05, 0.6, 0.25, "Delta rSO2", size=9, color="#444444")
    for tick in np_ticks(y_min, y_max, 0.5):
        y = sy(tick)
        s.rect(left, y, width, 0.006, fill="#E5E7EB", line=None)
        s.text(0.25, y - 0.09, 0.45, 0.18, f"{tick:g}", size=8, color="#444444", align="r")
    s.rect(left, sy(0), width, 0.012, fill="#111111", line=None)

    group_w = width / 3
    bar_w = 0.23
    for gi, (ch, ch_label) in enumerate(CHANNELS):
        gx = left + gi * group_w
        s.text(gx + 0.05, top + height + 0.18, group_w - 0.1, 0.25, ch_label, size=11, bold=True, align="ctr")
        for ei, (xvar, label, color) in enumerate(EXPOSURES):
            r = data[(ch, xvar)]
            val = float(r["delta_rso2_clinical_step"])
            lo = float(r["delta_rso2_iqr_lo"])
            hi = float(r["delta_rso2_iqr_hi"])
            cx = gx + group_w * (0.25 + ei * 0.25)
            y0, yv = sy(0), sy(val)
            s.rect(cx - bar_w / 2, min(y0, yv), bar_w, abs(yv - y0), fill=color, line=color)
            s.rect(cx - 0.015, sy(hi), 0.03, sy(lo) - sy(hi), fill="#111111", line=None)
            s.rect(cx - 0.07, sy(lo), 0.14, 0.018, fill="#111111", line=None)
            s.rect(cx - 0.07, sy(hi), 0.14, 0.018, fill="#111111", line=None)
            s.text(cx - 0.22, top + height + 0.48, 0.44, 0.18, label, size=8, align="ctr")

    for i, (_, label, color) in enumerate(EXPOSURES):
        s.rect(4.8 + i * 1.45, 0.92, 0.18, 0.18, fill=color, line=color)
        s.text(5.03 + i * 1.45, 0.88, 1.0, 0.22, label, size=9)
    return s


def np_ticks(y_min, y_max, step):
    vals = []
    v = math.ceil(y_min / step) * step
    while v <= y_max + 1e-9:
        vals.append(round(v, 6))
        v += step
    return vals


def slide_table(main_rows):
    s = Slide()
    draw_title(s, "Primary exposure summary table", "Median (IQR) across 20 segment effects")
    headers = ["Outcome", "Exposure", "Window", "Increment", "Median", "IQR"]
    xs = [0.4, 2.55, 4.15, 6.25, 8.05, 9.25]
    ws = [2.0, 1.45, 1.95, 1.55, 1.05, 2.15]
    y = 1.0
    for x, w, h in zip(xs, ws, headers):
        s.rect(x, y, w, 0.38, fill="#E2E8F0", line="#94A3B8", text=h, size=10, bold=True)
    y += 0.38
    data = by_key(main_rows)
    for ch, ch_label in CHANNELS:
        for xvar, label, _ in EXPOSURES:
            r = data[(ch, xvar)]
            vals = [
                ch_label,
                label,
                f"{fnum(r['effect_window_lo'], 2)}-{fnum(r['effect_window_hi'], 2)}",
                f"+{fnum(r['clinical_step'], 2)}",
                fnum(r["delta_rso2_clinical_step"], 2),
                f"{fnum(r['delta_rso2_iqr_lo'], 2)} to {fnum(r['delta_rso2_iqr_hi'], 2)}",
            ]
            fill = "#FFFFFF" if int((y - 1.38) / 0.38) % 2 == 0 else "#F8FAFC"
            for x, w, val in zip(xs, ws, vals):
                s.rect(x, y, w, 0.38, fill=fill, line="#CBD5E1", text=val, size=8.5)
            y += 0.38
    return s


def blend(v, vmax):
    if not math.isfinite(v) or vmax <= 0:
        return "#F8FAFC"
    t = max(-1, min(1, v / vmax))
    if t >= 0:
        a = t
        r, g, b = 255, int(255 * (1 - a) + 99 * a), int(255 * (1 - a) + 99 * a)
    else:
        a = -t
        r, g, b = int(255 * (1 - a) + 37 * a), int(255 * (1 - a) + 99 * a), 255
    return f"#{r:02X}{g:02X}{b:02X}"


def slide_heatmap(seg_rows):
    s = Slide()
    draw_title(s, "20-segment clinical-step effects", "Each cell is the segment-specific clinical-step effect")
    rows = [r for r in seg_rows if r["xvar"] in {"ET_CO2", "FiO2_new", "TEMP"}]
    vals = [abs(float(r["clinical_step_effect"])) for r in rows if r.get("clinical_step_effect")]
    vmax = max(vals) if vals else 1.0
    cell_w, cell_h = 0.25, 0.22
    x0, y0 = 2.0, 1.0
    row_idx = 0
    for ch, ch_label in CHANNELS:
        for xvar, label, _ in EXPOSURES:
            s.text(0.35, y0 + row_idx * cell_h - 0.01, 1.55, 0.18, f"{ch_label} {label}", size=7.4)
            sub = sorted([r for r in rows if r["ycol"] == ch and r["xvar"] == xvar], key=lambda r: int(r["bin_idx"]))
            for j, r in enumerate(sub[:20]):
                v = float(r["clinical_step_effect"])
                s.rect(x0 + j * cell_w, y0 + row_idx * cell_h, cell_w, cell_h, fill=blend(v, vmax), line="#FFFFFF")
            row_idx += 1
    for j in range(20):
        if j % 2 == 0:
            s.text(x0 + j * cell_w - 0.01, 0.78, cell_w, 0.15, str(j + 1), size=6.5, align="ctr")
    s.text(7.55, 1.15, 4.8, 1.1, "Rows combine outcome channel and exposure.\nColumns S01-S20 span each exposure's model-input 5%-95% range.\nBlue indicates negative effects; red indicates positive effects.", size=12, color="#334155")
    s.rect(7.7, 2.65, 0.35, 0.24, fill=blend(-vmax, vmax), line="#FFFFFF")
    s.text(8.1, 2.64, 1.2, 0.2, "negative", size=9)
    s.rect(7.7, 3.0, 0.35, 0.24, fill=blend(0, vmax), line="#CBD5E1")
    s.text(8.1, 2.99, 1.2, 0.2, "near zero", size=9)
    s.rect(7.7, 3.35, 0.35, 0.24, fill=blend(vmax, vmax), line="#FFFFFF")
    s.text(8.1, 3.34, 1.2, 0.2, "positive", size=9)
    return s


def slide_sensitivity(sens_rows):
    s = Slide()
    draw_title(s, "Five-variable sensitivity status", "MAP and CI require model curve export before effects can be calculated")
    headers = ["Outcome", "Exposure", "Window", "Increment", "Median", "IQR", "Status"]
    xs = [0.25, 2.0, 3.25, 4.75, 6.0, 7.0, 9.1]
    ws = [1.65, 1.15, 1.4, 1.15, 0.9, 1.95, 1.15]
    y = 0.95
    for x, w, h in zip(xs, ws, headers):
        s.rect(x, y, w, 0.33, fill="#E2E8F0", line="#94A3B8", text=h, size=8.4, bold=True)
    y += 0.33
    data = by_key(sens_rows)
    for ch, ch_label in CHANNELS:
        for xvar, label, _ in SENS_EXPOSURES:
            r = data.get((ch, xvar), {})
            status = r.get("status", "missing")
            vals = [
                ch_label,
                label,
                f"{fnum(r.get('effect_window_lo'), 2)}-{fnum(r.get('effect_window_hi'), 2)}",
                f"+{fnum(r.get('clinical_step'), 2)}",
                fnum(r.get("delta_rso2_clinical_step"), 2),
                (f"{fnum(r.get('delta_rso2_iqr_lo'), 2)} to {fnum(r.get('delta_rso2_iqr_hi'), 2)}" if status == "ok" else ""),
                status,
            ]
            fill = "#FFF7ED" if status == "missing" else "#FFFFFF"
            for x, w, val in zip(xs, ws, vals):
                s.rect(x, y, w, 0.31, fill=fill, line="#CBD5E1", text=val, size=7.3)
            y += 0.31
    s.text(0.55, 6.15, 12.0, 0.4, "To fill MAP/CI: rerun the model with INTRA5_SENSITIVITY_XVARS=MAP,CI so slice_median curve CSV files are exported.", size=11, bold=True, color="#92400E")
    return s


def keep_slide_layout_rels(xml_bytes):
    root = ET.fromstring(xml_bytes)
    keep = []
    for rel in root:
        typ = rel.attrib.get("Type", "")
        if typ.endswith("/slideLayout"):
            keep.append(rel)
    out = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>']
    out.append('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
    for rel in keep:
        out.append(
            f'<Relationship Id="{esc(rel.attrib["Id"])}" Type="{esc(rel.attrib["Type"])}" Target="{esc(rel.attrib["Target"])}"/>'
        )
    out.append("</Relationships>")
    return "".join(out)


def write_pptx(slides):
    if not TEMPLATE.exists():
        raise SystemExit(f"Template PPTX missing: {TEMPLATE}")
    tmp = OUT_PPTX.with_suffix(".tmp.pptx")
    skip = {f"ppt/slides/slide{i}.xml" for i in range(1, 6)}
    skip.update({f"ppt/slides/_rels/slide{i}.xml.rels" for i in range(1, 6)})
    with zipfile.ZipFile(TEMPLATE, "r") as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        rels = {}
        for i in range(1, 6):
            rel_name = f"ppt/slides/_rels/slide{i}.xml.rels"
            rels[i] = keep_slide_layout_rels(zin.read(rel_name))
        for item in zin.infolist():
            if item.filename in skip or item.filename.startswith("ppt/media/"):
                continue
            zout.writestr(item, zin.read(item.filename))
        for i, slide in enumerate(slides, start=1):
            zout.writestr(f"ppt/slides/slide{i}.xml", slide.xml())
            zout.writestr(f"ppt/slides/_rels/slide{i}.xml.rels", rels[i])
    shutil.move(tmp, OUT_PPTX)


def main():
    main_rows = read_rows(MAIN_CSV)
    sens_rows = read_rows(SENS_CSV)
    seg_rows = read_rows(SEG_CSV)
    slides = [
        slide_title(main_rows, sens_rows),
        slide_bar(main_rows),
        slide_table(main_rows),
        slide_heatmap(seg_rows),
        slide_sensitivity(sens_rows),
    ]
    write_pptx(slides)
    print(OUT_PPTX)


if __name__ == "__main__":
    main()
