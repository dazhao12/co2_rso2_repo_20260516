#!/usr/bin/env python3
"""Build main-text Table 2 subgroup clinical-increment effects."""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = ROOT.parent
DEFAULT_SUBGROUP_DIR = PROJECT_ROOT / "hpc_r_format_outputs" / "modelA_subgroup_20260614_195416"
DEFAULT_GENERATED_DIR = ROOT / "outputs_local" / "docs" / "manuscript_development" / "generated_assets"
DEFAULT_SHORT_DIR = PROJECT_ROOT / "hpc_r_format_outputs" / "ModelA_openable_ppt_20260614"
DEFAULT_MAIN_TABLES = ROOT / "docs" / "manuscript_development" / "CO2_MAIN_TABLES.md"

SUBGROUPS = [
    ("Age", "<70 years", "subgroup_Age_less_70"),
    ("Age", ">=70 years", "subgroup_Age_more_70"),
    ("Sex", "Female", "subgroup_Female"),
    ("Sex", "Male", "subgroup_Male"),
    ("Preoperative blood pressure", "<140/90 mmHg", "subgroup_Pre_hypertension_less_140_90"),
    ("Preoperative blood pressure", ">=140/90 mmHg", "subgroup_Pre_hypertension_more_140_90"),
]

EXPOSURES = [
    ("ET_CO2", "EtCO2 +5 mmHg"),
    ("FiO2_new", "FiO2 +5 percentage points"),
    ("TEMP", "Temperature +0.5 C"),
]

CHANNELS = [
    ("rSO2_Ch1", "Left SctO2"),
    ("rSO2_Ch2", "Right SctO2"),
    ("rSO2_Ch3", "SftO2"),
]


def fmt_effect(median: float, q25: float, q75: float) -> str:
    def clean(value: float) -> float:
        return 0.0 if round(value, 2) == 0 else value

    return f"{clean(median):.2f} ({clean(q25):.2f}, {clean(q75):.2f})"


def build_table(subgroup_dir: Path) -> pd.DataFrame:
    rows: list[dict[str, str]] = []
    for subgroup, level, folder in SUBGROUPS:
        path = subgroup_dir / folder / "plot_data_clinical_step_summary.csv"
        if not path.exists():
            raise FileNotFoundError(path)
        data = pd.read_csv(path)
        for xvar, exposure_label in EXPOSURES:
            row = {
                "Subgroup": subgroup,
                "Level": level,
                "Exposure increment": exposure_label,
            }
            for ycol, channel_label in CHANNELS:
                match = data[(data["xvar"] == xvar) & (data["ycol"] == ycol)]
                if len(match) != 1:
                    raise ValueError(f"Expected one row for {folder}, {xvar}, {ycol}; got {len(match)}")
                rec = match.iloc[0]
                row[channel_label] = fmt_effect(
                    float(rec["signed_effect_median"]),
                    float(rec["signed_effect_q25"]),
                    float(rec["signed_effect_q75"]),
                )
            rows.append(row)
    return pd.DataFrame(rows)


def to_markdown(df: pd.DataFrame) -> str:
    lines = [
        "## Table 2 | Subgroup adjusted tissue oxygenation differences for EtCO2, FiO2, and temperature increments",
        "",
        "| Subgroup | Level | Exposure increment | Left SctO2 | Right SctO2 | SftO2 |",
        "| --- | --- | --- | ---: | ---: | ---: |",
    ]
    prev_subgroup = None
    prev_level = None
    for _, row in df.iterrows():
        subgroup = row["Subgroup"] if row["Subgroup"] != prev_subgroup else ""
        level = row["Level"] if (row["Subgroup"], row["Level"]) != (prev_subgroup, prev_level) else ""
        lines.append(
            "| {subgroup} | {level} | {exposure} | {left} | {right} | {forearm} |".format(
                subgroup=subgroup,
                level=level,
                exposure=row["Exposure increment"],
                left=row["Left SctO2"],
                right=row["Right SctO2"],
                forearm=row["SftO2"],
            )
        )
        prev_subgroup = row["Subgroup"]
        prev_level = row["Level"]
    lines.extend(
        [
            "",
            "Notes:",
            "- Values are model-adjusted tissue oxygenation differences in percentage points for prespecified clinical increments, computed within each subgroup across 20 equal intervals spanning the model-input 5th-95th percentile exposure range and summarized as median (IQR).",
            "- Abbreviations: SctO2, cerebral tissue oxygen saturation; SftO2, forearm tissue oxygen saturation; EtCO2, end-tidal carbon dioxide; FiO2, fraction of inspired oxygen; IQR, interquartile range.",
            "",
        ]
    )
    return "\n".join(lines)


def replace_or_append_table2(main_tables_path: Path, table_md: str) -> None:
    text = main_tables_path.read_text(encoding="utf-8")
    marker = "\n## Table 2 | "
    idx = text.find(marker)
    if idx == -1:
        text = text.rstrip() + "\n\n" + table_md.rstrip() + "\n"
    else:
        text = text[: idx + 1].rstrip() + "\n\n" + table_md.rstrip() + "\n"
    main_tables_path.write_text(text, encoding="utf-8")


def write_outputs(df: pd.DataFrame, table_md: str, generated_dir: Path, short_dir: Path) -> None:
    generated_dir.mkdir(parents=True, exist_ok=True)
    short_dir.mkdir(parents=True, exist_ok=True)
    stem = "main_table2_subgroup_effects_ModelA_20260615"
    for outdir in [generated_dir, short_dir]:
        df.to_csv(outdir / f"{stem}.csv", index=False, encoding="utf-8")
        (outdir / f"{stem}.md").write_text(table_md, encoding="utf-8")
        with pd.ExcelWriter(outdir / f"{stem}.xlsx") as writer:
            df.to_excel(writer, sheet_name="Table2_subgroup_effects", index=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--subgroup-dir", type=Path, default=DEFAULT_SUBGROUP_DIR)
    parser.add_argument("--generated-dir", type=Path, default=DEFAULT_GENERATED_DIR)
    parser.add_argument("--short-dir", type=Path, default=DEFAULT_SHORT_DIR)
    parser.add_argument("--main-tables", type=Path, default=DEFAULT_MAIN_TABLES)
    args = parser.parse_args()

    df = build_table(args.subgroup_dir)
    table_md = to_markdown(df)
    write_outputs(df, table_md, args.generated_dir, args.short_dir)
    replace_or_append_table2(args.main_tables, table_md)
    print(f"Wrote {len(df)} Table 2 rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
