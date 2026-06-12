#!/usr/bin/env python3
"""
Build the left SctO2 intraoperative management supplementary table.

The table is patient-level and intentionally mirrors the prior Bottomline-CS
management-characteristics table:
  Characteristic | Overall (n=...) | Missing, n

By default, the cohort is derived from the same timestamp-level inclusion
logic used by 01_main_gam_analysis.py for rSO2_Ch1, then summarized in the
provided patient-level Excel file.
"""

from __future__ import annotations

import argparse
import importlib.util
import os
from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd


DEFAULT_MODEL_SCRIPT = (
    Path(__file__).resolve().parent / "01_main_gam_analysis.py"
)
LOCAL_DATA_XLSX = Path(
    "E:/BaiduSyncdisk/desktop_5_15/04_数据备份/data/"
    "cohort_data_10_10_2025_final_reclassified.xlsx"
)
HPC_DATA_XLSX = Path(
    "/N/project/waveform_mortality/ZhaoZhang/Tao_data/"
    "cohort_data_10_10_2025_final_reclassified.xlsx"
)
DEFAULT_OUT_DIR = Path(
    "/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/"
    "result/management_etables"
)


TABLE_ROWS = [
    ("Mean midazolam (SD), mg", ["Midazolam", "Midazolam_"], "mean_sd", 1),
    ("Median propofol (IQR), mg", ["Propofol", "Propofol_"], "median_iqr", 0),
    ("Median sevoflurane (IQR), mL", ["Sevoflurane", "Sevoflurane_"], "median_iqr", 0),
    ("Median cisatracurium (IQR), mg", ["Cisatracurium", "Cisatracurium_"], "median_iqr", 0),
    ("Median sufentanil (IQR), μg", ["Sufentanil", "Sufentanil_"], "median_iqr", 0),
    ("Noradrenaline, n (%)", ["Noradrenaline"], "binary", 1),
    ("Epinephrine, n (%)", ["Epinephrine"], "binary", 1),
    ("Metaraminol, n (%)", ["Metaraminol"], "binary", 1),
    ("Milrinone, n (%)", ["Milrinone"], "binary", 1),
    ("Nicardipine, n (%)", ["Nicardipine"], "binary", 1),
    ("Urapidil, n (%)", ["Urapidil"], "binary", 1),
    ("Esmolol, n (%)", ["Esmolol"], "binary", 1),
    ("Dexmedetomidine, n (%)", ["Dexmedetomidine", "Dexmedetomidine_"], "binary", 1),
    ("Tranexamic acid, n (%)", ["Tranexamic_acid"], "binary", 1),
    ("Mean crystalloid (SD), mL", ["Crystalloid"], "mean_sd", 0),
    ("Median colloid (IQR), mL", ["Colloid"], "median_iqr", 0),
    ("Mean autologous blood (SD), mL", ["Autologous_blood"], "mean_sd", 0),
    ("Mean blood loss (SD), mL", ["Blood_loss"], "mean_sd", 0),
    ("Median urine output (IQR), mL", ["Urine_output"], "median_iqr", 0),
    ("Mean lowest hemoglobin (SD), g/dL", ["Hemoglobin_lowest"], "mean_sd", 1),
    ("Median highest lactate (IQR), mmol/L", ["Lactate_highest"], "median_iqr", 1),
    ("Median highest glucose (IQR), mmol/L", ["Glucose_highest"], "median_iqr", 1),
    ("Median surgery time (IQR), min", ["Surgery_time"], "median_iqr", 0),
    ("Median numbers of bypass (IQR)", ["Numbers_of_bypass"], "median_iqr", 0),
]


def default_data_xlsx() -> Path:
    env_path = os.environ.get("CO2_MANAGEMENT_DATA_XLSX")
    if env_path:
        return Path(env_path)
    if LOCAL_DATA_XLSX.exists():
        return LOCAL_DATA_XLSX
    return HPC_DATA_XLSX


def import_model_module(path: Path):
    spec = importlib.util.spec_from_file_location("co2_main_gam_analysis", str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot import model script: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def coerce_id_string(s: pd.Series) -> pd.Series:
    return s.astype(str).str.strip()


def first_existing_col(df: pd.DataFrame, candidates: Iterable[str]) -> str | None:
    for c in candidates:
        if c in df.columns:
            return c
    lower_map = {str(c).lower(): c for c in df.columns}
    for c in candidates:
        hit = lower_map.get(str(c).lower())
        if hit is not None:
            return str(hit)
    return None


def derive_left_cohort_ids(model_script: Path) -> pd.DataFrame:
    m = import_model_module(model_script)
    need_cols = ["stay_id", "patient_ID", "patient_id", "obstime", "ET_CO2", "rSO2_Ch1"]
    df_ts = m.read_csv_folder_selected_cached(m.CSV_DIR, m.CSV_GLOB, need_cols=need_cols)
    df_ts = m._coerce_stay_id(df_ts)
    df_ts = m._coerce_patient_id(df_ts)
    pool, flow_rows, _, _ = m.build_unified_pool(df_ts, "rSO2_Ch1")

    id_col = m.get_subject_id_col(pool)
    ids = pool[[id_col]].dropna().drop_duplicates().copy()
    ids[id_col] = coerce_id_string(ids[id_col])
    ids = ids.rename(columns={id_col: "cohort_id"})
    flow = pd.DataFrame(flow_rows)
    return ids, flow


def load_patient_ids_csv(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    id_col = first_existing_col(df, ["cohort_id", "patient_ID", "patient_id", "ID", "stay_id"])
    if id_col is None:
        raise ValueError(f"No patient ID column found in {path}")
    out = df[[id_col]].dropna().drop_duplicates().copy()
    out[id_col] = coerce_id_string(out[id_col])
    return out.rename(columns={id_col: "cohort_id"})


def load_management_data(path: Path) -> pd.DataFrame:
    df = pd.read_excel(path, sheet_name=0)
    if "ID" in df.columns and "patient_ID" not in df.columns:
        df = df.rename(columns={"ID": "patient_ID"})
    for c in ["patient_ID", "patient_id", "stay_id"]:
        if c in df.columns:
            df[c] = coerce_id_string(df[c])
    return df


def subset_to_cohort(static_df: pd.DataFrame, cohort_ids: pd.DataFrame) -> tuple[pd.DataFrame, str]:
    for key in ["patient_ID", "patient_id", "stay_id"]:
        if key in static_df.columns:
            left = static_df.copy()
            cohort = cohort_ids.copy()
            left[key] = coerce_id_string(left[key])
            cohort["cohort_id"] = coerce_id_string(cohort["cohort_id"])
            sub = left[left[key].isin(set(cohort["cohort_id"]))].copy()
            if len(sub) > 0:
                return sub, key
    raise ValueError("Could not match cohort IDs to patient-level data.")


def fmt_num(x: float, digits: int) -> str:
    if not np.isfinite(x):
        return "NA"
    if digits == 0:
        return f"{x:.0f}"
    return f"{x:.{digits}f}"


def mean_sd(s: pd.Series, digits: int) -> str:
    x = pd.to_numeric(s, errors="coerce").dropna()
    if len(x) == 0:
        return "NA"
    sd = x.std(ddof=1) if len(x) > 1 else 0.0
    return f"{fmt_num(float(x.mean()), digits)} ({fmt_num(float(sd), digits)})"


def median_iqr(s: pd.Series, digits: int) -> str:
    x = pd.to_numeric(s, errors="coerce").dropna()
    if len(x) == 0:
        return "NA"
    q = x.quantile([0.25, 0.5, 0.75])
    return (
        f"{fmt_num(float(q.loc[0.5]), digits)} "
        f"({fmt_num(float(q.loc[0.25]), digits)} - {fmt_num(float(q.loc[0.75]), digits)})"
    )


def binary_n_pct(s: pd.Series, digits: int) -> str:
    x = pd.to_numeric(s, errors="coerce")
    den = int(x.notna().sum())
    if den == 0:
        return "NA"
    n = int((x.fillna(0) != 0).sum())
    return f"{n} ({100.0 * n / den:.{digits}f})"


def build_table(df: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for label, candidates, stat, digits in TABLE_ROWS:
        col = first_existing_col(df, candidates)
        if col is None:
            rows.append({
                "Characteristics*": label,
                "Overall": "Not available",
                "Missing, n": "NA",
                "source_column": "",
            })
            continue
        s = df[col]
        if stat == "mean_sd":
            val = mean_sd(s, digits)
        elif stat == "median_iqr":
            val = median_iqr(s, digits)
        elif stat == "binary":
            val = binary_n_pct(s, digits)
        else:
            raise ValueError(stat)
        rows.append({
            "Characteristics*": label,
            "Overall": val,
            "Missing, n": int(s.isna().sum()),
            "source_column": col,
        })
    return pd.DataFrame(rows)


def table_to_markdown(table: pd.DataFrame, n: int) -> str:
    show = table[["Characteristics*", "Overall", "Missing, n"]].copy()
    show = show.rename(columns={"Overall": f"Overall (n={n})"})
    lines = [
        f"## eTable X. Intraoperative management characteristics in the left cerebral tissue oxygen saturation analytic cohort",
        "",
        show.to_markdown(index=False),
        "",
        "Notes:",
        "- * Continuous variables are presented as mean (SD) or median (IQR), and categorical variables as n (%). Missing values are shown as n.",
        "- SctO2, cerebral tissue oxygen saturation; IQR, interquartile range; SD, standard deviation.",
    ]
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-xlsx", type=Path, default=default_data_xlsx())
    ap.add_argument("--model-script", type=Path, default=DEFAULT_MODEL_SCRIPT)
    ap.add_argument("--patient-ids-csv", type=Path, default=None)
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = ap.parse_args()

    if args.patient_ids_csv:
        cohort_ids = load_patient_ids_csv(args.patient_ids_csv)
        flow = pd.DataFrame()
    else:
        cohort_ids, flow = derive_left_cohort_ids(args.model_script)

    static_df = load_management_data(args.data_xlsx)
    cohort_df, match_key = subset_to_cohort(static_df, cohort_ids)
    table = build_table(cohort_df)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    csv_path = args.out_dir / "left_scto2_intraoperative_management_etable.csv"
    xlsx_path = args.out_dir / "left_scto2_intraoperative_management_etable.xlsx"
    md_path = args.out_dir / "left_scto2_intraoperative_management_etable.md"
    ids_path = args.out_dir / "left_scto2_management_cohort_patient_ids.csv"
    meta_path = args.out_dir / "left_scto2_management_etable_metadata.csv"

    table.to_csv(csv_path, index=False, encoding="utf-8-sig")
    with pd.ExcelWriter(xlsx_path, engine="openpyxl") as writer:
        table.to_excel(writer, index=False, sheet_name="eTable_management")
        if not flow.empty:
            flow.to_excel(writer, index=False, sheet_name="cohort_flow")
    md_path.write_text(table_to_markdown(table, len(cohort_df)), encoding="utf-8")
    cohort_df[[match_key]].drop_duplicates().to_csv(ids_path, index=False, encoding="utf-8-sig")
    pd.DataFrame([{
        "n_static_rows": len(static_df),
        "n_cohort_ids": int(cohort_ids["cohort_id"].nunique()),
        "n_matched_rows": len(cohort_df),
        "match_key": match_key,
        "data_xlsx": str(args.data_xlsx),
        "model_script": str(args.model_script),
        "patient_ids_csv": str(args.patient_ids_csv) if args.patient_ids_csv else "",
    }]).to_csv(meta_path, index=False, encoding="utf-8-sig")

    print(f"[done] n={len(cohort_df)} match_key={match_key}")
    print(f"[done] {csv_path}")
    print(f"[done] {xlsx_path}")
    print(f"[done] {md_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
