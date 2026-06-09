#!/usr/bin/env python3
"""Build manuscript Table 1/2 summaries for the CO2-rSO2 project.

This script intentionally reuses the current CO2 model script's data-loading
and cohort-filtering functions so Table 1/2 follow the same analytic cohort as
the GAM outputs.
"""

from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL_SCRIPT = (
    ROOT
    / "code"
    / "python"
    / "contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py"
)
DEFAULT_OUTDIR = ROOT / "results" / "manuscript_tables"

CHANNEL_LABELS = {
    "rSO2_Ch1": "Left SctO2",
    "rSO2_Ch2": "Right SctO2",
    "rSO2_Ch3": "SftO2",
}

BASELINE_CONT = [
    "Age",
    "BMI",
    "Cardiac_index",
    "Mean_blood_pressure",
    "Hb",
    "Left_SctO2",
    "Right_SctO2",
    "SstO2",
]
BASELINE_CAT = [
    "SEX",
    "Smoking_new",
    "Drinking_status",
    "Diabetes_status",
    "Hypertension",
    "Carotid_artery_disease",
    "Statin_1",
    "Hypertension_140_90",
]
INTRAOP_VARS = ["ET_CO2", "FiO2_new", "TEMP", "MAP", "SV", "HR", "CI", "RRtotal", "TVinsp", "Pmean"]


def load_module(script_path: Path):
    spec = importlib.util.spec_from_file_location("co2_model", script_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot import model script: {script_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # type: ignore[attr-defined]
    return module


def numeric_series(df: pd.DataFrame, col: str) -> pd.Series:
    return pd.to_numeric(df[col], errors="coerce") if col in df.columns else pd.Series(dtype=float)


def fmt_mean_sd(x: pd.Series, digits: int = 1) -> str:
    x = pd.to_numeric(x, errors="coerce").dropna()
    if x.empty:
        return "NA"
    return f"{x.mean():.{digits}f} ({x.std(ddof=1):.{digits}f})"


def fmt_median_iqr(x: pd.Series, digits: int = 1) -> str:
    x = pd.to_numeric(x, errors="coerce").dropna()
    if x.empty:
        return "NA"
    q1, med, q3 = np.percentile(x.to_numpy(), [25, 50, 75])
    return f"{med:.{digits}f} ({q1:.{digits}f}-{q3:.{digits}f})"


def fmt_n_pct(n: int, den: int) -> str:
    pct = 100.0 * n / den if den else 0.0
    return f"{n} ({pct:.1f}%)"


def patient_id_col(df: pd.DataFrame) -> str:
    for col in ["stay_id", "patient_ID", "patient_id"]:
        if col in df.columns:
            return col
    raise KeyError("No patient/stay id column found")


def one_row_per_patient(pool: pd.DataFrame) -> pd.DataFrame:
    id_col = patient_id_col(pool)
    sort_cols = [c for c in [id_col, "obstime"] if c in pool.columns]
    d = pool.sort_values(sort_cols) if sort_cols else pool
    return d.drop_duplicates(subset=[id_col], keep="first").copy()


def summarize_continuous(rows: list[dict], table: str, cohort: str, df: pd.DataFrame, cols: Iterable[str]):
    n_pat = len(df)
    for col in cols:
        if col not in df.columns:
            rows.append({"table": table, "cohort": cohort, "characteristic": col, "value": "not_available", "missing_n": "NA"})
            continue
        x = numeric_series(df, col)
        rows.append(
            {
                "table": table,
                "cohort": cohort,
                "characteristic": f"{col}, mean (SD)",
                "value": fmt_mean_sd(x),
                "missing_n": int(x.isna().sum()),
            }
        )
        rows.append(
            {
                "table": table,
                "cohort": cohort,
                "characteristic": f"{col}, median (IQR)",
                "value": fmt_median_iqr(x),
                "missing_n": int(x.isna().sum()),
            }
        )
    rows.append({"table": table, "cohort": cohort, "characteristic": "Patients, n", "value": str(n_pat), "missing_n": 0})


def summarize_categorical(rows: list[dict], table: str, cohort: str, df: pd.DataFrame, cols: Iterable[str]):
    den = len(df)
    for col in cols:
        if col not in df.columns:
            rows.append({"table": table, "cohort": cohort, "characteristic": col, "value": "not_available", "missing_n": "NA"})
            continue
        s = df[col]
        miss = int(s.isna().sum())
        vals = sorted([v for v in s.dropna().unique().tolist()], key=lambda x: str(x))
        if len(vals) <= 2 and set(str(v) for v in vals).issubset({"0", "0.0", "1", "1.0"}):
            n = int((pd.to_numeric(s, errors="coerce") == 1).sum())
            rows.append({"table": table, "cohort": cohort, "characteristic": f"{col}, n (%)", "value": fmt_n_pct(n, den), "missing_n": miss})
        else:
            for v in vals[:20]:
                n = int((s == v).sum())
                rows.append({"table": table, "cohort": cohort, "characteristic": f"{col}={v}, n (%)", "value": fmt_n_pct(n, den), "missing_n": miss})


def make_wide(long_df: pd.DataFrame) -> pd.DataFrame:
    value_wide = long_df.pivot_table(index=["table", "characteristic"], columns="cohort", values="value", aggfunc="first")
    missing_wide = long_df.pivot_table(index=["table", "characteristic"], columns="cohort", values="missing_n", aggfunc="first")
    missing_wide = missing_wide.add_prefix("Missing ")
    out = pd.concat([value_wide, missing_wide], axis=1).reset_index()
    preferred = ["table", "characteristic", "Left SctO2", "Right SctO2", "SftO2", "Missing Left SctO2", "Missing Right SctO2", "Missing SftO2"]
    return out[[c for c in preferred if c in out.columns] + [c for c in out.columns if c not in preferred]]


def build_base_dataframe(m) -> pd.DataFrame:
    need_cols = (
        ["stay_id", "patient_ID", "patient_id", "obstime"]
        + list(m.PRIMARY_VARS)
        + list(m.OPTIONAL_INTRAOP_COVARS)
        + list(m.OUTCOMES)
        + list(m.ADJ_CONT_CAND)
        + list(m.ADJ_CAT_CAND)
        + list(m.SUBGROUP_STATIC_VARS)
        + ["Sex", "SEX", "Age"]
    )
    df_ts = m.read_csv_folder_selected_cached(m.CSV_DIR, m.CSV_GLOB, need_cols=need_cols)
    static_need_cols = sorted(set(list(m.ADJ_CONT_CAND) + list(m.ADJ_CAT_CAND) + list(m.SUBGROUP_STATIC_VARS) + ["Sex", "SEX", "Age"]))
    static_df = m.read_static_selected_multi(
        xlsx_paths=[m.XLSX_PATH_MAIN, m.XLSX_PATH_SUBGROUP],
        need_cols=static_need_cols,
    )
    df_ts = m._coerce_patient_id(m._coerce_stay_id(df_ts))
    static_df = m._coerce_patient_id(m._coerce_stay_id(static_df))
    merge_key = next((k for k in ["stay_id", "patient_ID", "patient_id"] if k in df_ts.columns and k in static_df.columns), None)
    if merge_key is None:
        df_base = df_ts.copy()
    else:
        static_cols = [c for c in static_df.columns if c != merge_key]
        df_base = df_ts.merge(static_df[[merge_key] + static_cols], on=merge_key, how="left")
    if "Sex" not in df_base.columns and "SEX" in df_base.columns:
        df_base["Sex"] = df_base["SEX"]
    if "SEX" not in df_base.columns and "Sex" in df_base.columns:
        df_base["SEX"] = df_base["Sex"]
    m.safe_numeric(df_base, [c for c in set(BASELINE_CONT + BASELINE_CAT + INTRAOP_VARS + list(m.OUTCOMES)) if c in df_base.columns])
    m.maybe_convert_fio2_to_percent(df_base, col="FiO2_new")
    return df_base


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-script", type=Path, default=DEFAULT_MODEL_SCRIPT)
    ap.add_argument("--outdir", type=Path, default=DEFAULT_OUTDIR)
    args = ap.parse_args()

    outdir = args.outdir
    outdir.mkdir(parents=True, exist_ok=True)
    m = load_module(args.model_script)
    df_base = build_base_dataframe(m)

    rows: list[dict] = []
    flow_rows: list[dict] = []
    available_columns = []
    for ycol, cohort in CHANNEL_LABELS.items():
        pool, flow, _clip, _fill = m.build_unified_pool(df_base, ycol)
        flow_rows.extend(flow)
        patient_df = one_row_per_patient(pool)
        available_columns.append({"cohort": cohort, "n_rows": len(pool), "n_patients": len(patient_df), "available_columns": "|".join(pool.columns)})
        summarize_continuous(rows, "Table 1 baseline/static", cohort, patient_df, BASELINE_CONT)
        summarize_categorical(rows, "Table 1 baseline/static", cohort, patient_df, BASELINE_CAT)
        summarize_continuous(rows, "Table 2 intraoperative/timestamp", cohort, pool, INTRAOP_VARS + [ycol])

    long_df = pd.DataFrame(rows)
    wide_df = make_wide(long_df)
    flow_df = pd.DataFrame(flow_rows)
    avail_df = pd.DataFrame(available_columns)

    long_df.to_csv(outdir / "table1_2_co2_rso2_long.csv", index=False, encoding="utf-8-sig")
    wide_df.to_csv(outdir / "table1_2_co2_rso2_wide.csv", index=False, encoding="utf-8-sig")
    flow_df.to_csv(outdir / "table1_2_co2_rso2_flow_counts.csv", index=False, encoding="utf-8-sig")
    avail_df.to_csv(outdir / "table1_2_co2_rso2_available_columns.csv", index=False, encoding="utf-8-sig")
    with pd.ExcelWriter(outdir / "table1_2_co2_rso2.xlsx") as writer:
        wide_df.to_excel(writer, sheet_name="wide", index=False)
        long_df.to_excel(writer, sheet_name="long", index=False)
        flow_df.to_excel(writer, sheet_name="flow_counts", index=False)
        avail_df.to_excel(writer, sheet_name="available_columns", index=False)
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
