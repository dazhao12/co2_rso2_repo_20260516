# -*- coding: utf-8 -*-
# PATIENT-RESAMPLING VARIANT, NOT THE DEFAULT MAIN ANALYSIS SCRIPT.
# Use only when patient-level resampling is explicitly intended.
"""
v5_6_2026_rev2_20260506 - CO2/TEMP/FiO2主分析版，血流动力学调整，boot=20
=================================================================
改动（基于 contour_5_6_2026_intraop9_noperf_shared_k_sep_lam_boot20.py）：
  - 主研究变量仅保留 ET_CO2 / TEMP / FiO2_new
  - 比较两种血流动力学调整项，不作为主结果出图：
      A) te(MAP, CI)
      B) s(MAP) + s(SV) + s(HR)
  - RRtotal/TVinsp/Pmean 默认作为平滑术中校正协变量，但不作为主结果出图
  - 静态连续协变量与既往文章一致，使用 s(..., k=4) 作为 penalized spline
  - 研究变量 ET_CO2 / TEMP / FiO2_new 共享搜索 k，lambda 可分别搜索
  - 组织氧筛选默认改为 25 < rSO2 < 95
  - Bootstrap 重采样次数默认改为 20
  - sec=1, n=100000 不变

目标：
1) 在同一个 GAM 中纳入 3 个术中主变量的平滑项：
   y ~ s(ET_CO2) + s(TEMP) + s(FiO2_new)
       + te(MAP, CI) [Model A]
       或 + s(MAP) + s(SV) + s(HR) [Model B]
       + s(other_intraop_covars)
       + s(other_cont_covars) + factor(cat_covars)
2) 三个组织氧通道分别建队列：仅保留 ET_CO2 与对应通道组织氧均非缺失，
   且满足 ET_CO2 > 20 且 < 50、组织氧 > 25 且 < 95 的数据点。
   这些数据点作为每个通道的最终可用样本池，并输出可用病人数和可用数据点数。
3) 在最终可用样本池中，再对 TEMP / FiO2_new / MAP / SV / HR / RRtotal / TVinsp / Pmean 做生理裁剪，
   将异常值置为缺失；随后这些术中时序变量缺失按如下顺序填充：
   个体内前向填充 -> 个体中位数 -> 全体中位数。
4) 每个模型同时输出 9 个主变量的两类图：
   - fixed-median slice plot
   - sample-averaged adjusted plot
5) 其他静态协变量按原规则处理：连续变量用中位数，分类变量用众数。
6) 可选输出“可比斜率”量化：
   - slope_at_median_per_unit
   - slope_at_median_per_sd_x            (dy / +1SD x)
   - mean_abs_slope_per_sd_q10_q90       (核心可比指标)
   - iqr_effect_dy, iqr_effect_per_sd_x
7) 保持独立输出，不覆盖现有脚本结果。
"""

import os
os.environ.setdefault("MPLBACKEND", "Agg")

import json
import hashlib
import datetime
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Tuple, Optional

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from pygam import LinearGAM, s, f, l, te


# ========================= 路径配置 =========================
PROJECT_ROOT = Path(__file__).resolve().parents[1]
CSV_DIR      = Path("/N/project/waveform_mortality/ZhaoZhang/data_ML_11_21_2025_final/final_processed").resolve()
CSV_GLOB     = "*.csv"
XLSX_PATH_MAIN = Path("/N/project/waveform_mortality/ZhaoZhang/Tao_data/4_7_2025_data_for_ML.xlsx").resolve()
XLSX_PATH_SUBGROUP = Path(
    "/N/project/waveform_mortality/ZhaoZhang/Tao_data/4_7_2025_data_for_ML_with_all_patient_htn_control_with_sex_mbp_group.xlsx"
).resolve()

SEED = int(os.getenv("INTRA5_SEED", "85"))
RNG = np.random.default_rng(SEED)
STAMP = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
SCRIPT_VERSION = "v5_6_2026_rev2_20260506_co2tempfio2_hemo_adj"
X_RANGE_MODE = os.getenv("INTRA5_X_RANGE_MODE", "full").strip().lower() # q01q99 or full
_outdir_tag_raw = os.getenv("INTRA5_OUTDIR_TAG", "").strip()
OUTDIR_TAG = re.sub(r"[^0-9A-Za-z_\-]+", "_", _outdir_tag_raw).strip("_") if _outdir_tag_raw else ""
OUTDIR_STEM = f"{SCRIPT_VERSION}_boot20_rso2_25_95_{X_RANGE_MODE}_{STAMP}"
if OUTDIR_TAG:
    OUTDIR_STEM = f"{OUTDIR_STEM}_{OUTDIR_TAG}"
OUTDIR = PROJECT_ROOT / "result" / OUTDIR_STEM
OUTDIR.mkdir(parents=True, exist_ok=True)
RAW_CACHE_VERSION = "v2_patient_id_key"
POOL_CACHE_VERSION = "v1_build_unified_pool_cache"
ENABLE_POOL_CACHE = os.getenv("INTRA5_ENABLE_POOL_CACHE", "1") == "1"
POOL_CACHE_ROOT = PROJECT_ROOT / "result" / "processed_pool_cache"
POOL_CACHE_ROOT.mkdir(parents=True, exist_ok=True)


# ========================= 分析配置 =========================
PRIMARY_VARS = ["ET_CO2", "TEMP", "FiO2_new"]
HEMO_ADJUST_MODE = os.getenv("INTRA5_HEMO_ADJUST_MODE", "auto").strip().lower()
if HEMO_ADJUST_MODE not in ("auto", "map_ci_te", "map_sv_smooth", "linear"):
    HEMO_ADJUST_MODE = "auto"
HEMO_TENSOR_VARS = ["MAP", "CI"]
HEMO_SMOOTH_COVARS_FALLBACK = ["MAP", "SV", "HR"]
# 非血流动力学主调整项：始终作为“其他术中平滑协变量”
INTRAOP_SMOOTH_COVARS = ["RRtotal", "TVinsp", "Pmean"]
INTRAOP_LINEAR_COVARS = [
    c for c in os.getenv("INTRA5_INTRAOP_LINEAR_COVARS", "").split(",")
    if c.strip()
]
OPTIONAL_INTRAOP_COVARS = sorted(set(HEMO_TENSOR_VARS + HEMO_SMOOTH_COVARS_FALLBACK + INTRAOP_SMOOTH_COVARS + INTRAOP_LINEAR_COVARS))
OUTCOMES = ["rSO2_Ch1", "rSO2_Ch2", "rSO2_Ch3"]

ETCO2_REQUIRED_RANGE = (20.0, 50.0)  # strict: >20 and <50
RSO2_REQUIRED_LO = float(os.getenv("INTRA5_RSO2_REQUIRED_LO", "25.0"))
RSO2_REQUIRED_HI = float(os.getenv("INTRA5_RSO2_REQUIRED_HI", "95.0"))
if RSO2_REQUIRED_HI < RSO2_REQUIRED_LO:
    RSO2_REQUIRED_LO, RSO2_REQUIRED_HI = RSO2_REQUIRED_HI, RSO2_REQUIRED_LO
OUTCOME_REQUIRED_RANGE = (float(RSO2_REQUIRED_LO), float(RSO2_REQUIRED_HI))
OUTCOME_REQUIRED_RANGES = {y: OUTCOME_REQUIRED_RANGE for y in OUTCOMES}

POINTWISE_FILL_VARS = ["TEMP", "FiO2_new", "MAP", "SV", "CI", "HR", "RRtotal", "TVinsp", "Pmean"]
PHYSIO_CLIP_RANGES = {
    "TEMP": (34.0, 37.5),
    "FiO2_new": (30.0, 100.0),
    "MAP": (20.0, 160.0),
    "SV": (20.0, 180.0),
    "HR": (35.0, 160.0),
    "RRtotal": (4.0, 35.0),
    "TVinsp": (150.0, 1000.0),
    "Pmean": (0.0, 20.0),
    "CI": (0.5, 8.0),
}
ENABLE_OUTCOME_CLIP = os.getenv("INTRA5_ENABLE_OUTCOME_CLIP", "1") == "1"
RSO2_CLIP_LO = float(os.getenv("INTRA5_RSO2_CLIP_LO", str(OUTCOME_REQUIRED_RANGE[0])))
RSO2_CLIP_HI = float(os.getenv("INTRA5_RSO2_CLIP_HI", str(OUTCOME_REQUIRED_RANGE[1])))
if RSO2_CLIP_HI < RSO2_CLIP_LO:
    RSO2_CLIP_LO, RSO2_CLIP_HI = RSO2_CLIP_HI, RSO2_CLIP_LO
OUTCOME_CLIP_RANGES = (
    {y: (float(RSO2_CLIP_LO), float(RSO2_CLIP_HI)) for y in OUTCOMES}
    if ENABLE_OUTCOME_CLIP
    else {}
)

ADJ_CONT_CAND = [
    "Age", "BMI", "Cardiac_index", "Mean_blood_pressure", "Hb",
    "Left_SctO2", "Right_SctO2", "SstO2",
]
ADJ_CAT_CAND = [
    "SEX", "Smoking_new", "Drinking_status", "Diabetes_status",
    "Hypertension", "Carotid_artery_disease", "Statin_1",
]
BASELINE_EXCLUDE_BY_Y = {
    "rSO2_Ch1": ["Right_SctO2", "SstO2"],
    "rSO2_Ch2": ["Left_SctO2",  "SstO2"],
    "rSO2_Ch3": ["Left_SctO2",  "Right_SctO2"],
}

FREQUENCIES_SEC = [int(x) for x in os.getenv("INTRA5_FREQUENCIES_SEC", "1").split(",") if x.strip()]
SUBSAMPLE_SIZE = [int(x) for x in os.getenv("INTRA5_SUBSAMPLE_SIZE", "100000").split(",") if x.strip()]
N_OUTER_RESAMPLES = int(os.getenv("INTRA5_N_OUTER_RESAMPLES", "20"))
OUTER_RESAMPLE_REPLACE = os.getenv("INTRA5_OUTER_RESAMPLE_REPLACE", "1") == "1"
REF_SAMPLE_REPLACE = os.getenv("INTRA5_REF_SAMPLE_REPLACE", "1") == "1"
RESAMPLE_UNIT = os.getenv("INTRA5_RESAMPLE_UNIT", "patient").strip().lower()
if RESAMPLE_UNIT not in ("row", "patient"):
    RESAMPLE_UNIT = "patient"

# 冒烟调试：限制池子行数（0=不限制）
MAX_POOL_ROWS = int(os.getenv("INTRA5_MAX_POOL_ROWS", "0"))

# 平滑参数：支持固定值 or 数据驱动自动选择
N_SPLINES_MAIN = int(os.getenv("INTRA5_N_SPLINES_MAIN", "10"))
N_SPLINES_TENSOR = int(os.getenv("INTRA5_N_SPLINES_TENSOR", "6"))
N_SPLINES_COV = int(os.getenv("INTRA5_N_SPLINES_COV", "4"))
LAM_FIXED = float(os.getenv("INTRA5_LAM_FIXED", "3.0"))
AUTO_TUNE_SMOOTH = os.getenv("INTRA5_AUTO_TUNE_SMOOTH", "1") == "1"
N_SPLINES_CAND = [int(x) for x in os.getenv("INTRA5_N_SPLINES_CAND", "6,8,10,12").split(",") if x.strip()]
N_SPLINES_CAND = sorted(set([x for x in N_SPLINES_CAND if x >= 5])) or [N_SPLINES_MAIN]
LAM_GRID = np.logspace(
    float(os.getenv("INTRA5_LAM_GRID_LOG10_MIN", "-3")),
    float(os.getenv("INTRA5_LAM_GRID_LOG10_MAX", "3")),
    int(os.getenv("INTRA5_LAM_GRID_N", "9")),
)
LAM_GRID = np.array(sorted(set([float(x) for x in np.append(LAM_GRID, 3.0)])))
SMOOTH_STRATEGY = os.getenv("INTRA5_SMOOTH_STRATEGY", "shared_k_sep_lam").strip().lower()

if SMOOTH_STRATEGY not in ("shared_all", "shared_k_sep_lam", "sep_k_sep_lam"):
    SMOOTH_STRATEGY = "shared_all"
SMOOTH_RANDOM_SEARCH_N = int(os.getenv("INTRA5_SMOOTH_RANDOM_SEARCH_N", "24"))
SMOOTH_RANDOM_SEARCH_N = max(4, SMOOTH_RANDOM_SEARCH_N)
NUISANCE_LAM_FIXED = float(os.getenv("INTRA5_NUISANCE_LAM_FIXED", str(LAM_FIXED)))

# 斜率汇总区间：q10_q90(默认，避免尾部稀疏点放大抖动) 或 full
SLOPE_WINDOW_MODE = os.getenv("INTRA5_SLOPE_WINDOW_MODE", "q10_q90").strip().lower()
if SLOPE_WINDOW_MODE not in ("full", "q10_q90"):
    SLOPE_WINDOW_MODE = "full"
N_GRID = int(os.getenv("INTRA5_N_GRID", "180"))
# 固定仅输出 slice_median（不再生成 adjusted_mean）
PLOT_MODES = ["slice_median"]

PLOT_DPI = int(os.getenv("INTRA5_PLOT_DPI", "260"))
SAVE_RAW_BOOT_CURVES = os.getenv("INTRA5_SAVE_RAW_BOOT_CURVES", "1") == "1"
# 开关：默认不输出可比斜率量化。兼容旧变量 INTRA5_EXPORT_SLOPE_METRICS
ENABLE_SLOPE_METRICS = os.getenv("INTRA5_ENABLE_SLOPE_METRICS", "0") == "1"
EXPORT_SLOPE_METRICS = os.getenv(
    "INTRA5_EXPORT_SLOPE_METRICS",
    "1" if ENABLE_SLOPE_METRICS else "0",
) == "1"
INCLUDE_SLOPE_PANEL = os.getenv(
    "INTRA5_INCLUDE_SLOPE_PANEL",
    "1" if EXPORT_SLOPE_METRICS else "0",
) == "1"
AUTO_RENDER_PPT = os.getenv("INTRA5_AUTO_RENDER_PPT", "1") == "1"
RSCRIPT_BIN = os.getenv("INTRA5_RSCRIPT_BIN", "Rscript")
_ppt_r_script_env = os.getenv("INTRA5_PPT_R_SCRIPT", "").strip()
PPT_R_SCRIPT = (
    Path(_ppt_r_script_env).resolve()
    if _ppt_r_script_env
    else PROJECT_ROOT / "R_code" / "contour_9_29_2025" / "R_counter_GAM_py" / "切片图_slice_only_ppt_v2_4_1_2026_multismooth.R"
)

# ========================= 亚组配置（默认不做亚组） =========================
# 推荐开关：INTRA5_ENABLE_SUBGROUP=1；如显式设置 INTRA5_ANALYSIS_SCOPE 则优先
ENABLE_SUBGROUP = os.getenv("INTRA5_ENABLE_SUBGROUP", "0") == "1"
_analysis_scope_raw = os.getenv("INTRA5_ANALYSIS_SCOPE", "").strip().lower()
ANALYSIS_SCOPE = _analysis_scope_raw if _analysis_scope_raw else ("subgroup" if ENABLE_SUBGROUP else "overall")
if ANALYSIS_SCOPE not in ("overall", "subgroup", "both"):
    ANALYSIS_SCOPE = "overall"
SUBGROUP_ROOT_DIR = os.getenv("INTRA5_SUBGROUP_ROOT_DIR", "subgroups")

# 年龄、性别、术前高血压(140/90) 三类亚组分析
SUBGROUP_DEFS = [
    {"tag": "Age_less_70", "query": "Age <= 70"},
    {"tag": "Age_more_70", "query": "Age > 70"},
    {"tag": "Male", "query": "Sex == 1"},
    {"tag": "Female", "query": "Sex == 0"},
    {"tag": "Pre_hypertension_more_140_90", "query": "Hypertension_140_90 == 1"},
    {"tag": "Pre_hypertension_less_140_90", "query": "Hypertension_140_90 == 0"},
]
# 这些列只用于分层过滤，不进入建模校正
SUBGROUP_STATIC_VARS = ["Hypertension_140_90", "Sex", "Age"]

PRETTY_LABELS = {
    "ET_CO2": "End-Tidal CO₂ (mmHg)",
    "TEMP": "Temperature (°C)",
    "FiO2_new": "FiO₂ (%)",
    "MAP": "Mean Arterial Pressure (mmHg)",
    "SV": "Stroke Volume (mL)",
    "HR": "Heart Rate (bpm)",
    "RRtotal": "Respiratory Rate (/min)",
    "TVinsp": "Inspiratory Tidal Volume (mL)",
    "Pmean": "Mean Airway Pressure (cmH2O)",
    "rSO2_Ch1": "Left SctO₂ (%)",
    "rSO2_Ch2": "Right SctO₂ (%)",
    "rSO2_Ch3": "SftO₂ (%)",
}
PLOT_MODE_LABELS = {
    "slice_median": "Fixed-median slice",
    "adjusted_mean": "Sample-averaged adjusted",
}


def _hash_obj(obj) -> str:
    return hashlib.md5(json.dumps(obj, sort_keys=True, default=str).encode()).hexdigest()[:12]


def _json_default(obj):
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (np.floating,)):
        return float(obj)
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    return str(obj)


def rows_and_patients(df: pd.DataFrame) -> Tuple[int, int]:
    n_rows = int(len(df))
    id_col = get_subject_id_col(df)
    if id_col is not None:
        n_pat = int(pd.Series(df[id_col]).nunique(dropna=True))
    else:
        n_pat = -1
    return n_rows, n_pat


def get_subject_id_col(df: pd.DataFrame) -> Optional[str]:
    for c in ["stay_id", "patient_ID", "patient_id"]:
        if c in df.columns:
            return c
    return None


def _normalize_id_col(df: pd.DataFrame) -> pd.DataFrame:
    if "stay_id" in df.columns:
        return df
    # 静态表常见主键：ID（例如 R04519）
    if "ID" in df.columns and "patient_ID" not in df.columns:
        return df.rename(columns={"ID": "patient_ID"})
    if "patient_ID" in df.columns:
        return df
    cand = [c for c in df.columns if "stay" in c.lower() and "id" in c.lower()]
    if cand:
        return df.rename(columns={cand[0]: "stay_id"})
    cand2 = [c for c in df.columns if c.lower() in ("patient_id", "pat_id")]
    if cand2:
        # 保留 patient_ID 语义，便于和时序表对齐
        return df.rename(columns={cand2[0]: "patient_ID"})
    return df


def _coerce_stay_id(df: pd.DataFrame) -> pd.DataFrame:
    if "stay_id" not in df.columns:
        return df
    s = pd.to_numeric(df["stay_id"], errors="coerce")
    df["stay_id"] = s.astype("Int64")
    return df


def _coerce_patient_id(df: pd.DataFrame) -> pd.DataFrame:
    if "patient_ID" in df.columns:
        df["patient_ID"] = df["patient_ID"].astype(str).str.strip()
    if "patient_id" in df.columns:
        df["patient_id"] = df["patient_id"].astype(str).str.strip()
    return df


def safe_numeric(df: pd.DataFrame, cols: List[str]):
    for c in cols:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")


def sample_rows_by_mode(
    df: pd.DataFrame,
    n: int,
    random_state: int,
    replace: bool,
    unit: str = "row",
    id_col: Optional[str] = None,
) -> pd.DataFrame:
    """
    unit='row'     : legacy row-level sampling.
    unit='patient' : sample patients first, then take all rows from selected patients,
                     then trim to n rows if overshooting.
    """
    n = int(max(1, n))
    if unit != "patient" or id_col is None or id_col not in df.columns:
        return df.sample(n=n, random_state=random_state, replace=replace)

    d = df.copy()
    d = d.loc[d[id_col].notna()].copy()
    if len(d) == 0:
        return df.sample(n=n, random_state=random_state, replace=replace)

    groups = d.groupby(id_col, sort=False).indices
    ids = np.array(list(groups.keys()))
    if len(ids) == 0:
        return df.sample(n=n, random_state=random_state, replace=replace)

    rng = np.random.default_rng(int(random_state))
    avg_rows_per_patient = max(1.0, float(len(d)) / float(len(ids)))
    # Draw enough patients so pooled rows likely exceed n, then trim to n.
    target_draws = int(np.ceil(n / avg_rows_per_patient))

    sampled_idx = []
    if replace:
        # patient-level bootstrap: with replacement
        draws = ids[rng.integers(0, len(ids), size=max(target_draws, 1))]
        for sid in draws:
            sampled_idx.extend(groups[sid].tolist())
        while len(sampled_idx) < n:
            sid = ids[rng.integers(0, len(ids))]
            sampled_idx.extend(groups[sid].tolist())
    else:
        # without replacement at patient level
        draws = rng.permutation(ids)
        for sid in draws:
            sampled_idx.extend(groups[sid].tolist())
            if len(sampled_idx) >= n:
                break
        if len(sampled_idx) < n:
            # fallback: top-up row-level without replacement (rare since n<=len(df))
            remain = n - len(sampled_idx)
            pool_left = d.drop(index=sampled_idx, errors="ignore")
            if len(pool_left) > 0:
                topup = pool_left.sample(n=min(remain, len(pool_left)), random_state=int(random_state) + 17, replace=False)
                sampled_idx.extend(topup.index.tolist())

    out = d.loc[sampled_idx].copy()
    if len(out) > n:
        out = out.sample(n=n, random_state=int(random_state) + 31, replace=False)
    elif len(out) < n:
        # conservative fallback to exact n rows
        need = n - len(out)
        extra = d.sample(n=need, random_state=int(random_state) + 47, replace=True)
        out = pd.concat([out, extra], axis=0, ignore_index=False)
    return out.reset_index(drop=True)


def fill_by_subject_then_global(
    df: pd.DataFrame,
    col: str,
    id_col: Optional[str],
    time_col: str = "obstime",
) -> Dict[str, float]:
    stats = {
        "column": col,
        "filled_by_forward_fill": 0,
        "filled_by_subject_median": 0,
        "filled_by_global_median": 0,
        "remaining_missing": 0,
        "global_median": np.nan,
    }
    if col not in df.columns:
        return stats

    s = pd.to_numeric(df[col], errors="coerce")
    miss_before = s.isna()

    # 1) subject-wise forward fill (ordered by obstime when available)
    if id_col is not None:
        if time_col in df.columns:
            tmp = pd.DataFrame({
                "_orig_idx": np.arange(len(df), dtype=np.int64),
                "_id": df[id_col].values,
                "_t": pd.to_numeric(df[time_col], errors="coerce").values,
                "_v": s.values,
            })
            tmp = tmp.sort_values(["_id", "_t", "_orig_idx"], kind="mergesort")
            tmp["_v_ffill"] = tmp.groupby("_id")["_v"].ffill()
            s_ffill = pd.Series(tmp["_v_ffill"].values, index=tmp["_orig_idx"].values).reindex(
                np.arange(len(df))
            )
            s_ffill.index = df.index
        else:
            s_ffill = s.groupby(df[id_col]).ffill()

        fill_ff = miss_before & s_ffill.notna()
        if fill_ff.any():
            s = s.where(~fill_ff, s_ffill)
            stats["filled_by_forward_fill"] = int(fill_ff.sum())

    # 2) subject median
    if id_col is not None:
        miss_before_subj = s.isna()
        subj_med = s.groupby(df[id_col]).transform("median")
        fill_subj = miss_before_subj & subj_med.notna()
        if fill_subj.any():
            s = s.where(~fill_subj, subj_med)
            stats["filled_by_subject_median"] = int(fill_subj.sum())

    # 3) global median
    miss_mid = s.isna()
    global_med = s.median()
    if np.isfinite(global_med):
        fill_global = miss_mid
        if fill_global.any():
            s = s.fillna(float(global_med))
            stats["filled_by_global_median"] = int(fill_global.sum())
        stats["global_median"] = float(global_med)

    df[col] = s
    stats["remaining_missing"] = int(pd.isna(df[col]).sum())
    return stats


def clip_outside_range_to_nan(
    df: pd.DataFrame,
    col: str,
    bounds: Tuple[float, float],
) -> Dict[str, float]:
    stats = {
        "column": col,
        "clip_lo": float(bounds[0]),
        "clip_hi": float(bounds[1]),
        "nonmissing_before": 0,
        "newly_clipped_to_missing": 0,
        "remaining_nonmissing": 0,
    }
    if col not in df.columns:
        return stats

    s = pd.to_numeric(df[col], errors="coerce")
    before_nonmissing = int(s.notna().sum())
    in_range = s.between(bounds[0], bounds[1], inclusive="both")
    newly_clipped = s.notna() & (~in_range)
    if newly_clipped.any():
        s = s.mask(newly_clipped, np.nan)
    df[col] = s

    stats["nonmissing_before"] = before_nonmissing
    stats["newly_clipped_to_missing"] = int(newly_clipped.sum())
    stats["remaining_nonmissing"] = int(s.notna().sum())
    return stats


def _safe_tag(s: str) -> str:
    s = str(s).strip()
    s = re.sub(r"[^0-9A-Za-z_\-]+", "_", s)
    return s.strip("_") or "group"


def _extract_query_cols(expr: str, cols: List[str]) -> List[str]:
    if not expr:
        return []
    hits = []
    for c in cols:
        if re.search(rf"\b{re.escape(c)}\b", expr):
            hits.append(c)
    return hits


def apply_subgroup_query(df: pd.DataFrame, expr: str) -> pd.DataFrame:
    if not expr:
        return df.copy()
    return df.query(expr, engine="python").copy()


def maybe_convert_fio2_to_percent(df: pd.DataFrame, col: str = "FiO2_new") -> Dict[str, float]:
    meta = {"fio2_converted_to_percent": 0, "fio2_rows_converted": 0, "fio2_valid_rows": 0}
    if col not in df.columns:
        return meta
    s = pd.to_numeric(df[col], errors="coerce")
    valid = s.notna()
    meta["fio2_valid_rows"] = int(valid.sum())
    if meta["fio2_valid_rows"] == 0:
        return meta
    q99 = float(s[valid].quantile(0.99))
    if np.isfinite(q99) and q99 <= 1.2:
        df[col] = s * 100.0
        meta["fio2_converted_to_percent"] = 1
        meta["fio2_rows_converted"] = int(valid.sum())
    else:
        df[col] = s
    return meta


def read_csv_folder_selected_cached(csv_dir: Path, csv_glob: str, need_cols: List[str]) -> pd.DataFrame:
    cache_root = PROJECT_ROOT / "result" / "raw_cache"
    cache_root.mkdir(parents=True, exist_ok=True)

    files = sorted(csv_dir.glob(csv_glob))
    sig = {
        "cache_version": RAW_CACHE_VERSION,
        "files": [str(f) for f in files],
        "sizes": [int(f.stat().st_size) for f in files],
        "mtimes": [int(f.stat().st_mtime) for f in files],
        "need_cols": sorted(need_cols),
    }
    key = _hash_obj(sig)
    p_parquet = cache_root / f"intra5_selected_{key}.parquet"
    p_pickle = cache_root / f"intra5_selected_{key}.pkl"
    if p_parquet.exists():
        try:
            return pd.read_parquet(p_parquet)
        except Exception:
            pass
    if p_pickle.exists():
        try:
            return pd.read_pickle(p_pickle)
        except Exception:
            pass

    dfs = []
    for fp in files:
        try:
            head = pd.read_csv(fp, nrows=2)
            use = [c for c in need_cols if c in head.columns]
            if not use:
                continue
            d = pd.read_csv(fp, usecols=use)
            dfs.append(d)
        except Exception:
            continue

    df = pd.concat(dfs, ignore_index=True) if dfs else pd.DataFrame(columns=need_cols)
    df = _normalize_id_col(df)
    df = _coerce_stay_id(df)
    df = _coerce_patient_id(df)
    try:
        df.to_parquet(p_parquet, index=False)
    except Exception:
        df.to_pickle(p_pickle)
    return df


def read_static_selected_multi(xlsx_paths: List[Path], need_cols: List[str]) -> pd.DataFrame:
    """
    依次读取多个静态表，按 stay_id 合并；后面的表只补齐前面缺失的字段。
    这样可在主表基础上补充亚组字段（如 Hypertension_140_90）。
    """
    frames = []
    for p in xlsx_paths:
        if not p.exists():
            continue
        try:
            d = pd.read_excel(p, sheet_name=0)
            d = _normalize_id_col(d)
            d = _coerce_stay_id(d)
            d = _coerce_patient_id(d)
            id_cols = [c for c in ["stay_id", "patient_ID", "patient_id"] if c in d.columns]
            keep = [c for c in (id_cols + need_cols) if c in d.columns]
            if id_cols and len(keep) > len(id_cols):
                frames.append(d[keep].copy())
        except Exception:
            continue

    if not frames:
        return pd.DataFrame(columns=["stay_id"] + need_cols)

    out = frames[0]
    for d in frames[1:]:
        key = None
        for k in ["stay_id", "patient_ID", "patient_id"]:
            if (k in out.columns) and (k in d.columns):
                key = k
                break
        if key is None:
            continue
        out = out.merge(d, on=key, how="outer", suffixes=("", "__new"))
        for c in need_cols:
            c_new = f"{c}__new"
            if c_new in out.columns:
                if c in out.columns:
                    out[c] = out[c].combine_first(out[c_new])
                    out = out.drop(columns=[c_new])
                else:
                    out = out.rename(columns={c_new: c})

    id_cols = [c for c in ["stay_id", "patient_ID", "patient_id"] if c in out.columns]
    keep = [c for c in (id_cols + need_cols) if c in out.columns]
    return out[keep].copy()


def _file_sig(path: Path) -> Dict[str, object]:
    if not path.exists():
        return {"path": str(path), "exists": 0}
    st = path.stat()
    return {
        "path": str(path),
        "exists": 1,
        "size": int(st.st_size),
        "mtime": int(st.st_mtime),
    }


def build_data_source_signature() -> str:
    files = sorted(CSV_DIR.glob(CSV_GLOB))
    sig = {
        "raw_cache_version": RAW_CACHE_VERSION,
        "csv_files": [str(f) for f in files],
        "csv_sizes": [int(f.stat().st_size) for f in files],
        "csv_mtimes": [int(f.stat().st_mtime) for f in files],
        "xlsx_main": _file_sig(XLSX_PATH_MAIN),
        "xlsx_subgroup": _file_sig(XLSX_PATH_SUBGROUP),
    }
    return _hash_obj(sig)


def build_pool_cache_key(
    data_source_sig: str,
    sec: int,
    subgroup_tag: str,
    subgroup_query: str,
    ycol: str,
) -> str:
    key_obj = {
        "pool_cache_version": POOL_CACHE_VERSION,
        "data_source_sig": data_source_sig,
        "sec": int(sec),
        "subgroup_tag": str(subgroup_tag),
        "subgroup_query": str(subgroup_query),
        "ycol": str(ycol),
        "etco2_required_range": list(ETCO2_REQUIRED_RANGE),
        "outcome_required_ranges": OUTCOME_REQUIRED_RANGES,
        "enable_outcome_clip": int(ENABLE_OUTCOME_CLIP),
        "outcome_clip_ranges": OUTCOME_CLIP_RANGES,
        "physio_clip_ranges": PHYSIO_CLIP_RANGES,
        "pointwise_fill_vars": POINTWISE_FILL_VARS,
        "max_pool_rows": int(MAX_POOL_ROWS),
    }
    return _hash_obj(key_obj)


def _load_pool_cache(cache_dir: Path):
    pool_fp = cache_dir / "pool.pkl"
    flow_fp = cache_dir / "flow_rows.json"
    clip_fp = cache_dir / "clip_rows.json"
    fill_fp = cache_dir / "fill_rows.json"
    if not (pool_fp.exists() and flow_fp.exists() and clip_fp.exists() and fill_fp.exists()):
        return None
    try:
        pool = pd.read_pickle(pool_fp)
        flow_rows = json.loads(flow_fp.read_text(encoding="utf-8"))
        clip_rows = json.loads(clip_fp.read_text(encoding="utf-8"))
        fill_rows = json.loads(fill_fp.read_text(encoding="utf-8"))
        return pool, flow_rows, clip_rows, fill_rows
    except Exception:
        return None


def _save_pool_cache(
    cache_dir: Path,
    pool: pd.DataFrame,
    flow_rows: List[Dict[str, object]],
    clip_rows: List[Dict[str, object]],
    fill_rows: List[Dict[str, object]],
) -> bool:
    try:
        cache_dir.mkdir(parents=True, exist_ok=True)
        pool.to_pickle(cache_dir / "pool.pkl")
        (cache_dir / "flow_rows.json").write_text(
            json.dumps(flow_rows, ensure_ascii=False, default=_json_default),
            encoding="utf-8",
        )
        (cache_dir / "clip_rows.json").write_text(
            json.dumps(clip_rows, ensure_ascii=False, default=_json_default),
            encoding="utf-8",
        )
        (cache_dir / "fill_rows.json").write_text(
            json.dumps(fill_rows, ensure_ascii=False, default=_json_default),
            encoding="utf-8",
        )
        return True
    except Exception:
        return False


def build_unified_pool_cached(
    df_base: pd.DataFrame,
    ycol: str,
    sec: int,
    subgroup_tag: str,
    subgroup_query: str,
    data_source_sig: str,
):
    if not ENABLE_POOL_CACHE:
        pool, flow_rows, clip_rows, fill_rows = build_unified_pool(df_base, ycol=ycol)
        return pool, flow_rows, clip_rows, fill_rows, 0, "", 0

    cache_key = build_pool_cache_key(
        data_source_sig=data_source_sig,
        sec=sec,
        subgroup_tag=subgroup_tag,
        subgroup_query=subgroup_query,
        ycol=ycol,
    )
    cache_dir = POOL_CACHE_ROOT / f"intra5_pool_{cache_key}"
    loaded = _load_pool_cache(cache_dir)
    if loaded is not None:
        pool, flow_rows, clip_rows, fill_rows = loaded
        return pool, flow_rows, clip_rows, fill_rows, 1, cache_key, 1

    pool, flow_rows, clip_rows, fill_rows = build_unified_pool(df_base, ycol=ycol)
    wrote = int(_save_pool_cache(cache_dir, pool, flow_rows, clip_rows, fill_rows))
    return pool, flow_rows, clip_rows, fill_rows, 0, cache_key, wrote


def downsample(df: pd.DataFrame, sec: int) -> pd.DataFrame:
    if sec <= 1:
        return df
    out = df.copy()
    out["obstime"] = pd.to_numeric(out["obstime"], errors="coerce")
    out = out.dropna(subset=["obstime"])
    out["_bin"] = (out["obstime"] // sec).astype(int)
    num_cols = out.select_dtypes(include=[np.number]).columns.tolist()
    agg_cols = ["stay_id", "_bin"]
    if "stay_id" not in out.columns:
        return out
    grp = out.groupby(agg_cols, as_index=False)[num_cols].median()
    grp["obstime"] = grp["_bin"] * sec
    return grp.drop(columns=["_bin"], errors="ignore")


def build_terms(
    n_primary: int,
    n_tensor_pairs: int,
    n_smooth_cov: int,
    n_cont_cov: int,
    n_cat_cov: int,
    n_splines_main,
):
    if n_primary <= 0:
        raise ValueError("n_primary must be >= 1")
    n_smooth_terms = n_primary + n_tensor_pairs + n_smooth_cov
    if isinstance(n_splines_main, (list, tuple, np.ndarray)):
        ns_list = [int(x) for x in np.asarray(n_splines_main).reshape(-1).tolist()]
    else:
        ns_list = [int(n_splines_main)] * n_smooth_terms
    if len(ns_list) != n_smooth_terms:
        raise ValueError("n_splines_main must be scalar or have length equal to smooth term count")

    terms = s(0, n_splines=ns_list[0])
    for i in range(1, n_primary):
        terms += s(i, n_splines=ns_list[i])
    base = n_primary
    ns_pos = n_primary
    for j in range(n_tensor_pairs):
        terms += te(base + 2 * j, base + 2 * j + 1, n_splines=[ns_list[ns_pos], ns_list[ns_pos]])
        ns_pos += 1
    base += 2 * n_tensor_pairs
    for j in range(n_smooth_cov):
        terms += s(base + j, n_splines=ns_list[ns_pos])
        ns_pos += 1
    base += n_smooth_cov
    for i in range(n_cont_cov):
        terms += l(base + i)
    for j in range(n_cat_cov):
        terms += f(base + n_cont_cov + j)
    return terms


def normalize_lam_for_pygam(lam):
    if lam is None:
        return None
    if isinstance(lam, (float, int, np.floating, np.integer)):
        return float(lam)
    if isinstance(lam, np.ndarray):
        if lam.size == 1:
            return float(lam.reshape(-1)[0])
        return [float(x) for x in lam.reshape(-1)]
    if isinstance(lam, (list, tuple)):
        out = []
        for v in lam:
            if isinstance(v, np.ndarray):
                arr = np.asarray(v, dtype=float).reshape(-1)
                out.append(float(arr[0]) if arr.size == 1 else [float(x) for x in arr])
            elif isinstance(v, (list, tuple)):
                arr = np.asarray(v, dtype=float).reshape(-1)
                out.append(float(arr[0]) if arr.size == 1 else [float(x) for x in arr])
            else:
                out.append(float(v))
        return out
    return float(lam)


def lam_for_json(lam):
    nlam = normalize_lam_for_pygam(lam)
    if isinstance(nlam, list):
        return json.dumps(nlam, ensure_ascii=False)
    return json.dumps(float(nlam) if nlam is not None else None, ensure_ascii=False)


def ns_for_json(n_splines_main):
    if isinstance(n_splines_main, (list, tuple, np.ndarray)):
        arr = [int(x) for x in np.asarray(n_splines_main).reshape(-1).tolist()]
        return json.dumps(arr, ensure_ascii=False)
    return json.dumps(int(n_splines_main), ensure_ascii=False)


def make_lam_vector(
    smooth_lams: List[float],
    n_primary: int,
    n_tensor_pairs: int,
    n_smooth_cov: int,
    n_cont_cov: int,
    n_cat_cov: int,
    nuisance_lam: float,
):
    out = []
    pos = 0
    for _ in range(n_primary):
        out.append(float(smooth_lams[pos]))
        pos += 1
    for _ in range(n_tensor_pairs):
        lam = float(smooth_lams[pos])
        out.append([lam, lam])
        pos += 1
    for _ in range(n_smooth_cov):
        out.append(float(smooth_lams[pos]))
        pos += 1
    out.extend([float(nuisance_lam)] * (n_cont_cov + n_cat_cov))
    return out


def score_gam(gm) -> float:
    st = gm.statistics_ if isinstance(gm.statistics_, dict) else {}
    score = st.get("GCV", np.nan)
    if not np.isfinite(score):
        score = st.get("AIC", np.nan)
    if not np.isfinite(score):
        score = st.get("UBRE", np.nan)
    if not np.isfinite(score):
        score = np.inf
    return float(score)


def candidate_param_configs(
    n_primary: int,
    n_tensor_pairs: int,
    n_smooth_cov: int,
    n_cont_cov: int,
    n_cat_cov: int,
):
    rng = np.random.default_rng(SEED + 303)
    lam_grid_list = [float(x) for x in LAM_GRID.tolist()]
    configs = []
    n_smooth_terms = n_primary + n_tensor_pairs + n_smooth_cov

    def ns_vec_for_primary_k(primary_k: int) -> List[int]:
        return (
            [int(primary_k)] * n_primary
            + [int(N_SPLINES_TENSOR)] * n_tensor_pairs
            + [int(N_SPLINES_COV)] * n_smooth_cov
        )

    if SMOOTH_STRATEGY == "shared_all":
        for ns in N_SPLINES_CAND:
            for lam in lam_grid_list:
                configs.append({
                    "n_splines_main": ns_vec_for_primary_k(ns),
                    "lam": float(lam),
                    "strategy": "shared_all",
                })
        return configs

    if SMOOTH_STRATEGY == "shared_k_sep_lam":
        lam_vectors = {tuple([float(l)] * n_smooth_terms) for l in lam_grid_list}
        while len(lam_vectors) < max(len(lam_grid_list), SMOOTH_RANDOM_SEARCH_N):
            draw = tuple(float(x) for x in rng.choice(LAM_GRID, size=n_smooth_terms, replace=True).tolist())
            lam_vectors.add(draw)
        lam_vectors = sorted(lam_vectors)
        for ns in N_SPLINES_CAND:
            for lam_vec in lam_vectors:
                configs.append({
                    "n_splines_main": ns_vec_for_primary_k(ns),
                    "lam": make_lam_vector(
                        list(lam_vec), n_primary=n_primary, n_tensor_pairs=n_tensor_pairs,
                        n_smooth_cov=n_smooth_cov, n_cont_cov=n_cont_cov,
                        n_cat_cov=n_cat_cov, nuisance_lam=NUISANCE_LAM_FIXED,
                    ),
                    "strategy": "shared_k_sep_lam",
                })
        return configs

    cfg_seen = set()
    # include the shared baselines as anchors
    for ns in N_SPLINES_CAND:
        for lam in lam_grid_list:
            ns_vec = tuple(ns_vec_for_primary_k(ns))
            key = (ns_vec, tuple([float(lam)] * n_smooth_terms))
            cfg_seen.add(key)
            configs.append({
                "n_splines_main": list(ns_vec),
                "lam": make_lam_vector(
                    [float(lam)] * n_smooth_terms, n_primary=n_primary,
                    n_tensor_pairs=n_tensor_pairs, n_smooth_cov=n_smooth_cov,
                    n_cont_cov=n_cont_cov, n_cat_cov=n_cat_cov,
                    nuisance_lam=NUISANCE_LAM_FIXED,
                ),
                "strategy": "sep_k_sep_lam",
            })
    target_n = len(configs) + SMOOTH_RANDOM_SEARCH_N
    while len(configs) < target_n:
        ns_vec = tuple(ns_vec_for_primary_k(int(rng.choice(N_SPLINES_CAND))))
        lam_vec = tuple(float(x) for x in rng.choice(LAM_GRID, size=n_smooth_terms, replace=True).tolist())
        key = (ns_vec, lam_vec)
        if key in cfg_seen:
            continue
        cfg_seen.add(key)
        configs.append({
            "n_splines_main": list(ns_vec),
            "lam": make_lam_vector(
                list(lam_vec), n_primary=n_primary, n_tensor_pairs=n_tensor_pairs,
                n_smooth_cov=n_smooth_cov, n_cont_cov=n_cont_cov,
                n_cat_cov=n_cat_cov, nuisance_lam=NUISANCE_LAM_FIXED,
            ),
            "strategy": "sep_k_sep_lam",
        })
    return configs


def fit_gam(
    df_model: pd.DataFrame,
    ycol: str,
    primary_vars: List[str],
    tensor_vars: List[str],
    smooth_covars: List[str],
    cont_cov: List[str],
    cat_cov: List[str],
    n_splines_main,
    lam_fixed=None,
):
    feat = primary_vars + tensor_vars + smooth_covars + cont_cov + cat_cov
    X = df_model[feat].astype(float).values
    y = df_model[ycol].astype(float).values
    terms = build_terms(
        len(primary_vars),
        int(len(tensor_vars) / 2),
        len(smooth_covars),
        len(cont_cov),
        len(cat_cov),
        n_splines_main=n_splines_main,
    )
    lam_use = normalize_lam_for_pygam(lam_fixed)
    gam = LinearGAM(terms, fit_intercept=True, lam=lam_use).fit(X, y)
    return gam


def tune_smoothing(
    df_model: pd.DataFrame,
    ycol: str,
    primary_vars: List[str],
    tensor_vars: List[str],
    smooth_covars: List[str],
    cont_cov: List[str],
    cat_cov: List[str],
):
    feat = primary_vars + tensor_vars + smooth_covars + cont_cov + cat_cov
    X = df_model[feat].astype(float).values
    y = df_model[ycol].astype(float).values
    n_tensor_pairs = int(len(tensor_vars) / 2)
    n_smooth_terms = len(primary_vars) + n_tensor_pairs + len(smooth_covars)

    best = None
    best_score = np.inf
    for cfg in candidate_param_configs(
        n_primary=len(primary_vars),
        n_tensor_pairs=n_tensor_pairs,
        n_smooth_cov=len(smooth_covars),
        n_cont_cov=len(cont_cov),
        n_cat_cov=len(cat_cov),
    ):
        try:
            terms = build_terms(
                len(primary_vars), n_tensor_pairs, len(smooth_covars), len(cont_cov), len(cat_cov),
                n_splines_main=cfg["n_splines_main"]
            )
            gm = LinearGAM(terms, fit_intercept=True, lam=normalize_lam_for_pygam(cfg["lam"])).fit(X, y)
            score = score_gam(gm)
            if score < best_score:
                best_score = float(score)
                best = {
                    "gam": gm,
                    "n_splines_main": cfg["n_splines_main"],
                    "lam": normalize_lam_for_pygam(gm.lam),
                    "score": float(score),
                    "strategy": cfg.get("strategy", SMOOTH_STRATEGY),
                }
        except Exception:
            continue

    if best is None:
        # fallback 到固定参数
        gm = fit_gam(
            df_model=df_model, ycol=ycol, primary_vars=primary_vars, tensor_vars=tensor_vars,
            smooth_covars=smooth_covars, cont_cov=cont_cov, cat_cov=cat_cov,
            n_splines_main=N_SPLINES_MAIN, lam_fixed=LAM_FIXED
        )
        best = {
            "gam": gm,
            "n_splines_main": [int(N_SPLINES_MAIN)] * n_smooth_terms,
            "lam": normalize_lam_for_pygam(LAM_FIXED),
            "score": np.nan,
            "strategy": "fallback_fixed",
        }
    return best


def make_ref_vals(
    df: pd.DataFrame,
    primary_vars: List[str],
    tensor_vars: List[str],
    smooth_covars: List[str],
    cont_cov: List[str],
    cat_cov: List[str],
) -> Dict[str, float]:
    ref = {}
    for c in primary_vars + tensor_vars + smooth_covars + cont_cov:
        s = pd.to_numeric(df[c], errors="coerce")
        med = s.median()
        ref[c] = float(med if np.isfinite(med) else 0.0)
    for c in cat_cov:
        s = pd.to_numeric(df[c], errors="coerce")
        mode = s.mode(dropna=True)
        ref[c] = float(mode.iloc[0]) if len(mode) else 0.0
    return ref


def build_feature_names(
    primary_vars: List[str],
    tensor_vars: List[str],
    smooth_covars: List[str],
    cont_cov: List[str],
    cat_cov: List[str],
) -> List[str]:
    return primary_vars + tensor_vars + smooth_covars + cont_cov + cat_cov


def make_ref_matrix(
    x_grid: np.ndarray,
    xvar: str,
    feature_names: List[str],
    ref_vals: Dict[str, float],
):
    n = len(x_grid)
    Xp = np.zeros((n, len(feature_names)), dtype=float)
    for j, c in enumerate(feature_names):
        Xp[:, j] = float(ref_vals.get(c, 0.0))
    Xp[:, feature_names.index(xvar)] = x_grid
    return Xp


def predict_curve_slice(
    gam,
    x_grid: np.ndarray,
    xvar: str,
    feature_names: List[str],
    ref_vals: Dict[str, float],
):
    Xp = make_ref_matrix(x_grid=x_grid, xvar=xvar, feature_names=feature_names, ref_vals=ref_vals)
    return gam.predict(Xp)


def predict_curve_adjusted(
    gam,
    x_grid: np.ndarray,
    xvar: str,
    primary_vars: List[str],
    feature_names: List[str],
    ref_vals: Dict[str, float],
    X_obs: np.ndarray,
):
    term_idx = primary_vars.index(xvar)
    pred_obs = np.asarray(gam.predict(X_obs), dtype=float).reshape(-1)
    # Additive GAM without interaction: sample-averaged adjusted curve equals
    # the target term curve plus the mean contribution of all remaining terms.
    term_obs = np.asarray(gam.partial_dependence(term=term_idx, X=X_obs), dtype=float).reshape(-1)
    other_mean = float(np.nanmean(pred_obs - term_obs))
    Xp = make_ref_matrix(x_grid=x_grid, xvar=xvar, feature_names=feature_names, ref_vals=ref_vals)
    term_grid = np.asarray(gam.partial_dependence(term=term_idx, X=Xp), dtype=float).reshape(-1)
    return term_grid + other_mean


def choose_hemo_adjustment(df: pd.DataFrame) -> Tuple[List[str], List[str], List[str]]:
    def _usable(c: str) -> bool:
        return c in df.columns and pd.to_numeric(df[c], errors="coerce").notna().any()

    if HEMO_ADJUST_MODE in ("auto", "map_ci_te") and all(_usable(c) for c in HEMO_TENSOR_VARS):
        return HEMO_TENSOR_VARS.copy(), [], ["te(MAP,CI)"]
    if HEMO_ADJUST_MODE == "map_ci_te":
        return [], [], ["requested_te(MAP,CI)_missing"]
    if HEMO_ADJUST_MODE in ("auto", "map_sv_smooth") and all(_usable(c) for c in HEMO_SMOOTH_COVARS_FALLBACK):
        return [], HEMO_SMOOTH_COVARS_FALLBACK.copy(), ["s(MAP)+s(SV)+s(HR)"]
    if HEMO_ADJUST_MODE == "map_sv_smooth":
        return [], [], ["requested_s(MAP)+s(SV)+s(HR)_missing"]
    return [], [], ["linear_available_hemo_covars"]


def prepare_model_df(
    df: pd.DataFrame,
    ycol: str,
    extra_exclude_covars: Optional[List[str]] = None,
):
    exclude = set(BASELINE_EXCLUDE_BY_Y.get(ycol, []))
    if extra_exclude_covars:
        exclude.update([str(c) for c in extra_exclude_covars])
    primary_vars = [c for c in PRIMARY_VARS if c in df.columns]
    tensor_vars, smooth_covars, hemo_terms = choose_hemo_adjustment(df)
    hemo_special = set(tensor_vars + smooth_covars)
    intraop_smooth = [
        c for c in INTRAOP_SMOOTH_COVARS
        if c in df.columns and c not in exclude and c not in primary_vars and c not in hemo_special
    ]
    smooth_covars = smooth_covars + intraop_smooth
    hemo_special = set(tensor_vars + smooth_covars)
    intraop_linear = [
        c for c in INTRAOP_LINEAR_COVARS
        if c in df.columns and c not in exclude and c not in primary_vars and c not in hemo_special
    ]
    if HEMO_ADJUST_MODE == "linear" or not hemo_special:
        intraop_linear.extend([
            c for c in ["MAP", "SV", "CI"]
            if c in df.columns and c not in exclude and c not in primary_vars and c not in intraop_linear
        ])
    static_smooth = [
        c for c in ADJ_CONT_CAND
        if c in df.columns and c not in exclude and c not in primary_vars and c not in hemo_special and c not in intraop_linear
    ]
    smooth_covars = smooth_covars + static_smooth
    hemo_special = set(tensor_vars + smooth_covars)
    cont_cov = intraop_linear
    cat_cov = [c for c in ADJ_CAT_CAND if c in df.columns and c not in exclude]
    required_model_covars = tensor_vars + smooth_covars
    use_cols = primary_vars + [ycol] + required_model_covars + cont_cov + cat_cov
    d = df[use_cols].copy()

    for c in primary_vars + [ycol] + required_model_covars + cont_cov:
        d[c] = pd.to_numeric(d[c], errors="coerce")
    d = d.dropna(subset=primary_vars + [ycol]).copy()

    for c in required_model_covars + cont_cov:
        med = d[c].median()
        if not np.isfinite(med):
            med = 0.0
        d[c] = d[c].fillna(float(med))
    for c in cat_cov:
        s = pd.to_numeric(d[c], errors="coerce")
        mode = s.mode(dropna=True)
        fillv = float(mode.iloc[0]) if len(mode) else 0.0
        s = s.fillna(fillv)
        d[c] = pd.Categorical(s.astype(str)).codes.astype(float)

    d = d.dropna(subset=primary_vars + [ycol] + required_model_covars).copy()
    d.attrs["hemo_adjustment_terms"] = hemo_terms
    return d, primary_vars, tensor_vars, smooth_covars, cont_cov, cat_cov


def calc_slope_metrics(
    x_grid: np.ndarray,
    y_curve: np.ndarray,
    x_series: pd.Series,
    window_mode: str = "full",
):
    x = np.asarray(x_grid, dtype=float)
    y = np.asarray(y_curve, dtype=float)
    slope_unit = np.gradient(y, x)

    sx = float(pd.to_numeric(x_series, errors="coerce").std())
    sx = sx if np.isfinite(sx) and sx > 0 else np.nan
    slope_sd = slope_unit * sx if np.isfinite(sx) else np.full_like(slope_unit, np.nan)

    q10 = float(pd.to_numeric(x_series, errors="coerce").quantile(0.10))
    q25 = float(pd.to_numeric(x_series, errors="coerce").quantile(0.25))
    q50 = float(pd.to_numeric(x_series, errors="coerce").quantile(0.50))
    q75 = float(pd.to_numeric(x_series, errors="coerce").quantile(0.75))
    q90 = float(pd.to_numeric(x_series, errors="coerce").quantile(0.90))
    xmin = float(pd.to_numeric(x_series, errors="coerce").min())
    xmax = float(pd.to_numeric(x_series, errors="coerce").max())

    idx_m = int(np.argmin(np.abs(x - q50)))
    if window_mode == "q10_q90":
        w_lo, w_hi = q10, q90
        mask_mid = (x >= q10) & (x <= q90)
    else:
        w_lo, w_hi = xmin, xmax
        mask_mid = (x >= xmin) & (x <= xmax)
    mean_abs_slope_sd = float(np.nanmean(np.abs(slope_sd[mask_mid]))) if mask_mid.any() else np.nan
    mean_slope_sd = float(np.nanmean(slope_sd[mask_mid])) if mask_mid.any() else np.nan

    y_q25 = float(np.interp(q25, x, y))
    y_q75 = float(np.interp(q75, x, y))
    iqr_effect = y_q75 - y_q25
    iqr_x = q75 - q25
    iqr_effect_per_sd = float(iqr_effect * sx / iqr_x) if (np.isfinite(sx) and iqr_x > 0) else np.nan

    metrics = {
        "slope_at_median_per_unit": float(slope_unit[idx_m]),
        "slope_at_median_per_sd_x": float(slope_sd[idx_m]) if np.isfinite(slope_sd[idx_m]) else np.nan,
        "mean_abs_slope_per_sd_q10_q90": mean_abs_slope_sd,
        "mean_slope_per_sd_q10_q90": mean_slope_sd,
        "iqr_effect_dy": float(iqr_effect),
        "iqr_effect_per_sd_x": iqr_effect_per_sd,
        "slope_window_mode": window_mode,
        "slope_window_lo": float(w_lo) if np.isfinite(w_lo) else np.nan,
        "slope_window_hi": float(w_hi) if np.isfinite(w_hi) else np.nan,
        "x_q10": q10,
        "x_q25": q25,
        "x_q50": q50,
        "x_q75": q75,
        "x_q90": q90,
        "x_sd": sx,
    }
    return metrics, slope_unit, slope_sd


def aggregate_with_ci(arr: np.ndarray):
    if arr.ndim == 1:
        arr = arr.reshape(1, -1)
    mean = np.nanmean(arr, axis=0)
    lo = np.nanpercentile(arr, 2.5, axis=0)
    hi = np.nanpercentile(arr, 97.5, axis=0)
    return mean, lo, hi


def plot_curve_and_slope(
    out_png: Path,
    x_grid: np.ndarray,
    y_mean: np.ndarray,
    y_lo: np.ndarray,
    y_hi: np.ndarray,
    s_mean: Optional[np.ndarray],
    s_lo: Optional[np.ndarray],
    s_hi: Optional[np.ndarray],
    xvar: str,
    ycol: str,
    n_boot_ok: int,
    plot_mode: str,
):
    if INCLUDE_SLOPE_PANEL:
        fig, (ax1, ax2) = plt.subplots(
            2, 1, figsize=(9.2, 7.6), sharex=True, gridspec_kw={"height_ratios": [2.2, 1.3]}
        )
    else:
        fig, ax1 = plt.subplots(1, 1, figsize=(9.2, 4.8))
        ax2 = None
    ax1.fill_between(x_grid, y_lo, y_hi, color="#4C72B0", alpha=0.18, linewidth=0)
    ax1.plot(x_grid, y_mean, color="#1F4E8C", lw=2.2)
    ax1.set_ylabel(PRETTY_LABELS.get(ycol, ycol), fontsize=11)
    ax1.grid(alpha=0.22)
    ax1.set_title(
        f"{PRETTY_LABELS.get(xvar, xvar)} vs {PRETTY_LABELS.get(ycol, ycol)}"
        f" | {PLOT_MODE_LABELS.get(plot_mode, plot_mode)} | boot={n_boot_ok}",
        fontsize=11,
    )
    if not INCLUDE_SLOPE_PANEL:
        ax1.set_xlabel(PRETTY_LABELS.get(xvar, xvar), fontsize=11)

    if ax2 is not None and s_mean is not None and s_lo is not None and s_hi is not None:
        ax2.fill_between(x_grid, s_lo, s_hi, color="#DD8452", alpha=0.20, linewidth=0)
        ax2.plot(x_grid, s_mean, color="#C15A1A", lw=2.0)
        ax2.axhline(0.0, color="0.35", lw=1.0, ls="--")
        ax2.set_xlabel(PRETTY_LABELS.get(xvar, xvar), fontsize=11)
        ax2.set_ylabel("Slope (dy / +1SD x)", fontsize=10)
        ax2.grid(alpha=0.22)

    axes = [ax1] if ax2 is None else [ax1, ax2]
    for ax in axes:
        ax.tick_params(labelsize=9)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

    fig.tight_layout()
    out_png.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_png, dpi=PLOT_DPI)
    plt.close(fig)


def summarize_metrics(metrics_ok: pd.DataFrame, fallback_metrics: Dict[str, float]) -> Dict[str, float]:
    if len(metrics_ok):
        cols = [c for c in metrics_ok.columns if c != "rep"]
        summary = {"n_boot_ok": int(len(metrics_ok))}
        for c in cols:
            vc = pd.to_numeric(metrics_ok[c], errors="coerce")
            if vc.notna().sum() == 0:
                continue
            vv = vc.values
            summary[f"{c}_mean"] = float(np.nanmean(vv))
            summary[f"{c}_lo2.5"] = float(np.nanpercentile(vv, 2.5))
            summary[f"{c}_hi97.5"] = float(np.nanpercentile(vv, 97.5))
        return summary

    summary = {"n_boot_ok": 0}
    for c, v in fallback_metrics.items():
        summary[f"{c}_mean"] = float(v) if np.isfinite(v) else np.nan
        summary[f"{c}_lo2.5"] = np.nan
        summary[f"{c}_hi97.5"] = np.nan
    return summary


def export_one_curve_mode(
    out_dir: Path,
    ycol: str,
    xvar: str,
    sec: int,
    take_n: int,
    subgroup_tag: str,
    plot_mode: str,
    x_grid: np.ndarray,
    arr_curve: np.ndarray,
    arr_slope: Optional[np.ndarray],
    summary: Optional[Dict[str, float]],
    chosen_ns,
    chosen_lam,
    chosen_strategy: str,
    ref_vals: Dict[str, float],
    n_primary_smooth: int,
):
    y_mean, y_lo, y_hi = aggregate_with_ci(arr_curve)
    n_boot_ok = int(summary["n_boot_ok"]) if summary is not None else 0
    if arr_slope is not None and INCLUDE_SLOPE_PANEL:
        s_mean, s_lo, s_hi = aggregate_with_ci(arr_slope)
    else:
        s_mean = s_lo = s_hi = None

    plot_curve_and_slope(
        out_png=out_dir / f"{ycol}_{xvar}_{sec}s_sub{take_n}_{plot_mode}_curve_slope.png",
        x_grid=x_grid,
        y_mean=y_mean,
        y_lo=y_lo,
        y_hi=y_hi,
        s_mean=s_mean,
        s_lo=s_lo,
        s_hi=s_hi,
        xvar=xvar,
        ycol=ycol,
        n_boot_ok=n_boot_ok,
        plot_mode=plot_mode,
    )

    df_curve = pd.DataFrame({
        "x": x_grid,
        "pred_mean": y_mean,
        "pred_lo_2.5": y_lo,
        "pred_hi_97.5": y_hi,
        "xvar": xvar,
        "ycol": ycol,
        "sec": sec,
        "subgroup": subgroup_tag,
        "n_sample": take_n,
        "plot_mode": plot_mode,
    })
    df_curve["n_boot_ok"] = n_boot_ok
    if s_mean is not None:
        df_curve["slope_per_sd_mean"] = s_mean
        df_curve["slope_per_sd_lo_2.5"] = s_lo
        df_curve["slope_per_sd_hi_97.5"] = s_hi
    df_curve.to_csv(out_dir / f"{ycol}_{xvar}_{sec}s_sub{take_n}_{plot_mode}_curve_boot.csv", index=False)

    if SAVE_RAW_BOOT_CURVES and len(arr_curve):
        pd.DataFrame(arr_curve).to_csv(
            out_dir / f"{ycol}_{xvar}_{sec}s_sub{take_n}_{plot_mode}_boot_raw_curve_matrix.csv",
            index=False,
        )

    if summary is None or not EXPORT_SLOPE_METRICS:
        return None

    summary_row = pd.DataFrame([{
        "ycol": ycol,
        "xvar": xvar,
        "subgroup": subgroup_tag,
        "sec": sec,
        "n_sample": take_n,
        "plot_mode": plot_mode,
        "auto_tune_smooth": int(AUTO_TUNE_SMOOTH),
        "smooth_strategy": str(chosen_strategy),
        "n_primary_smooth": int(n_primary_smooth),
        "n_splines_main_used_json": ns_for_json(chosen_ns),
        "lam_used": lam_for_json(chosen_lam),
        "slope_window_mode_used": SLOPE_WINDOW_MODE,
        "prediction_reference_json": json.dumps(ref_vals, ensure_ascii=False, sort_keys=True),
        **summary,
    }])
    summary_row.to_csv(out_dir / f"{ycol}_{xvar}_{sec}s_sub{take_n}_{plot_mode}_slope_metrics_summary.csv", index=False)
    return summary_row


def run_one_model(
    df_pool: pd.DataFrame,
    ycol: str,
    sec: int,
    k: int,
    out_root: Path,
    subgroup_tag: str,
    extra_exclude_covars: Optional[List[str]] = None,
):
    d_model, primary_vars, tensor_vars, smooth_covars, cont_cov, cat_cov = prepare_model_df(
        df_pool, ycol=ycol, extra_exclude_covars=extra_exclude_covars
    )
    if len(d_model) < 500:
        return None

    take_n = min(int(k), len(d_model))
    id_col = get_subject_id_col(d_model)
    df_ref = sample_rows_by_mode(
        d_model,
        n=take_n,
        random_state=SEED,
        replace=REF_SAMPLE_REPLACE,
        unit=RESAMPLE_UNIT,
        id_col=id_col,
    )
    feature_names = build_feature_names(primary_vars, tensor_vars, smooth_covars, cont_cov, cat_cov)
    X_ref = df_ref[feature_names].astype(float).values
    need_slope_outputs = EXPORT_SLOPE_METRICS or INCLUDE_SLOPE_PANEL

    x_grid_map = {}
    for xvar in primary_vars:
        x_s = pd.to_numeric(df_ref[xvar], errors="coerce")
        if X_RANGE_MODE == "full":
            x_lo = float(x_s.min())
            x_hi = float(x_s.max())
        else:
            x_lo = float(x_s.quantile(0.01))
            x_hi = float(x_s.quantile(0.99))
            
        if not np.isfinite(x_lo) or not np.isfinite(x_hi) or x_hi <= x_lo:
            x_lo = float(x_s.min())
            x_hi = float(x_s.max())
        x_grid_map[xvar] = np.linspace(x_lo, x_hi, max(60, N_GRID))

    # 参考模型：可选数据驱动自动平滑参数
    if AUTO_TUNE_SMOOTH:
        tuned = tune_smoothing(
            df_ref, ycol=ycol, primary_vars=primary_vars, tensor_vars=tensor_vars,
            smooth_covars=smooth_covars, cont_cov=cont_cov, cat_cov=cat_cov
        )
        gam_ref = tuned["gam"]
        chosen_ns = tuned["n_splines_main"]
        chosen_lam = tuned["lam"]
        chosen_strategy = str(tuned.get("strategy", SMOOTH_STRATEGY))
    else:
        gam_ref = fit_gam(
            df_ref, ycol=ycol, primary_vars=primary_vars, tensor_vars=tensor_vars,
            smooth_covars=smooth_covars, cont_cov=cont_cov, cat_cov=cat_cov,
            n_splines_main=N_SPLINES_MAIN, lam_fixed=LAM_FIXED
        )
        chosen_ns = (
            [int(N_SPLINES_MAIN)] * len(primary_vars)
            + [int(N_SPLINES_TENSOR)] * int(len(tensor_vars) / 2)
            + [int(N_SPLINES_COV)] * len(smooth_covars)
        )
        chosen_lam = LAM_FIXED
        chosen_strategy = "shared_all_fixed"

    ref_vals = make_ref_vals(
        df_ref, primary_vars=primary_vars, tensor_vars=tensor_vars,
        smooth_covars=smooth_covars, cont_cov=cont_cov, cat_cov=cat_cov
    )
    ref_vals["_hemo_adjustment_terms"] = ";".join(d_model.attrs.get("hemo_adjustment_terms", []))
    curve_store = {
        xvar: {mode: [] for mode in PLOT_MODES}
        for xvar in primary_vars
    }
    slope_store = {xvar: [] for xvar in primary_vars} if need_slope_outputs else {}
    metrics_store = {xvar: [] for xvar in primary_vars} if EXPORT_SLOPE_METRICS else {}
    fallback_metrics = {} if EXPORT_SLOPE_METRICS else {}
    fallback_slopes = {} if need_slope_outputs else {}
    for xvar in primary_vars:
        x_grid = x_grid_map[xvar]
        y_ref_slice = predict_curve_slice(
            gam_ref, x_grid=x_grid, xvar=xvar, feature_names=feature_names, ref_vals=ref_vals
        )
        y_ref_adjusted = predict_curve_adjusted(
            gam_ref, x_grid=x_grid, xvar=xvar, primary_vars=primary_vars,
            feature_names=feature_names, ref_vals=ref_vals, X_obs=X_ref
        )
        m_ref = None
        slope_sd_ref = None
        if need_slope_outputs or EXPORT_SLOPE_METRICS:
            m_ref, _, slope_sd_ref = calc_slope_metrics(
                x_grid, y_ref_adjusted, x_series=df_ref[xvar], window_mode=SLOPE_WINDOW_MODE
            )
        if "slice_median" in PLOT_MODES:
            curve_store[xvar]["slice_median"].append(y_ref_slice)
        if "adjusted_mean" in PLOT_MODES:
            curve_store[xvar]["adjusted_mean"].append(y_ref_adjusted)
        if EXPORT_SLOPE_METRICS:
            fallback_metrics[xvar] = m_ref
        if need_slope_outputs:
            fallback_slopes[xvar] = slope_sd_ref
            slope_store[xvar].append(slope_sd_ref)

    local_rng = np.random.default_rng(SEED + 101)
    for r in range(1, N_OUTER_RESAMPLES + 1):
        seed_r = int(local_rng.integers(1_000_000_000))
        df_r = sample_rows_by_mode(
            d_model,
            n=take_n,
            random_state=seed_r,
            replace=OUTER_RESAMPLE_REPLACE,
            unit=RESAMPLE_UNIT,
            id_col=id_col,
        )
        try:
            gam_r = fit_gam(
                df_r, ycol=ycol, primary_vars=primary_vars, tensor_vars=tensor_vars,
                smooth_covars=smooth_covars, cont_cov=cont_cov, cat_cov=cat_cov,
                n_splines_main=chosen_ns, lam_fixed=chosen_lam
            )
            for xvar in primary_vars:
                x_grid = x_grid_map[xvar]
                y_r_slice = predict_curve_slice(
                    gam_r, x_grid=x_grid, xvar=xvar, feature_names=feature_names, ref_vals=ref_vals
                )
                y_r_adjusted = predict_curve_adjusted(
                    gam_r, x_grid=x_grid, xvar=xvar, primary_vars=primary_vars,
                    feature_names=feature_names, ref_vals=ref_vals, X_obs=X_ref
                )
                m_r = None
                slope_sd_r = None
                if need_slope_outputs or EXPORT_SLOPE_METRICS:
                    m_r, _, slope_sd_r = calc_slope_metrics(
                        x_grid, y_r_adjusted, x_series=df_ref[xvar], window_mode=SLOPE_WINDOW_MODE
                    )
                if "slice_median" in PLOT_MODES:
                    curve_store[xvar]["slice_median"].append(y_r_slice)
                if "adjusted_mean" in PLOT_MODES:
                    curve_store[xvar]["adjusted_mean"].append(y_r_adjusted)
                if need_slope_outputs:
                    slope_store[xvar].append(slope_sd_r)
                if EXPORT_SLOPE_METRICS:
                    m_r["rep"] = r
                    metrics_store[xvar].append(m_r)
        except Exception as e:
            if EXPORT_SLOPE_METRICS:
                for xvar in primary_vars:
                    metrics_store[xvar].append({"rep": r, "error": str(e)})

    out_rows = []
    for xvar in primary_vars:
        out_dir = out_root / ycol / f"{sec}s" / f"sub{take_n}" / xvar
        out_dir.mkdir(parents=True, exist_ok=True)

        metrics_ok = pd.DataFrame([m for m in metrics_store[xvar] if "error" not in m]) if EXPORT_SLOPE_METRICS else pd.DataFrame()
        summary = summarize_metrics(metrics_ok=metrics_ok, fallback_metrics=fallback_metrics[xvar]) if EXPORT_SLOPE_METRICS else None
        arr_slope = None
        if need_slope_outputs:
            arr_slope = np.stack(slope_store[xvar], axis=0) if len(slope_store[xvar]) else np.stack([fallback_slopes[xvar]], axis=0)

        if EXPORT_SLOPE_METRICS and len(metrics_ok):
            metrics_ok.to_csv(out_dir / f"{ycol}_{xvar}_{sec}s_sub{take_n}_boot_metrics_raw.csv", index=False)

        for plot_mode in PLOT_MODES:
            curve_list = curve_store[xvar].get(plot_mode, [])
            if not curve_list:
                continue
            arr_curve = np.stack(curve_list, axis=0)
            df_sum = export_one_curve_mode(
                out_dir=out_dir,
                ycol=ycol,
                xvar=xvar,
                sec=sec,
                take_n=take_n,
                subgroup_tag=subgroup_tag,
                plot_mode=plot_mode,
                x_grid=x_grid_map[xvar],
                arr_curve=arr_curve,
                arr_slope=arr_slope,
                summary=summary,
                chosen_ns=chosen_ns,
                chosen_lam=chosen_lam,
                chosen_strategy=chosen_strategy,
                ref_vals=ref_vals,
                n_primary_smooth=len(primary_vars),
            )
            if df_sum is not None:
                out_rows.append(df_sum)
    return out_rows


def build_unified_pool(df_base: pd.DataFrame, ycol: str):
    d = df_base.copy()
    flow_rows = []
    clip_rows = []
    fill_rows = []
    id_col = get_subject_id_col(d)

    n_rows_raw, n_pat_raw = rows_and_patients(d)
    flow_rows.append({
        "ycol": ycol,
        "stage": "raw_timeseries_rows",
        "n_rows": n_rows_raw,
        "n_patients": n_pat_raw,
    })

    needed = [c for c in ["ET_CO2", ycol] if c in d.columns]
    d = d.dropna(subset=needed).copy()

    n_rows_na, n_pat_na = rows_and_patients(d)
    flow_rows.append({
        "ycol": ycol,
        "stage": "after_required_etco2_y_nonmissing",
        "n_rows": n_rows_na,
        "n_patients": n_pat_na,
    })

    # Cohort-defining range screen: ETCO2 and outcome
    if "ET_CO2" in d.columns:
        clip_stat = clip_outside_range_to_nan(d, "ET_CO2", ETCO2_REQUIRED_RANGE)
        clip_stat["ycol"] = ycol
        clip_rows.append(clip_stat)
    y_bounds = OUTCOME_CLIP_RANGES.get(ycol, OUTCOME_REQUIRED_RANGES.get(ycol, OUTCOME_REQUIRED_RANGE))
    if ycol in d.columns and y_bounds is not None:
        clip_stat = clip_outside_range_to_nan(d, ycol, y_bounds)
        clip_stat["ycol"] = ycol
        clip_rows.append(clip_stat)
    d = d.dropna(subset=needed).copy()
    n_rows_screen, n_pat_screen = rows_and_patients(d)
    flow_rows.append({
        "ycol": ycol,
        "stage": "after_cohort_clip_to_missing_and_dropna",
        "n_rows": n_rows_screen,
        "n_patients": n_pat_screen,
    })

    y_req_bounds = OUTCOME_REQUIRED_RANGES.get(ycol, OUTCOME_REQUIRED_RANGE)
    if "ET_CO2" in d.columns:
        s_et = pd.to_numeric(d["ET_CO2"], errors="coerce")
        d = d.loc[(s_et > ETCO2_REQUIRED_RANGE[0]) & (s_et < ETCO2_REQUIRED_RANGE[1])]
    if ycol in d.columns:
        s_y = pd.to_numeric(d[ycol], errors="coerce")
        d = d.loc[(s_y > y_req_bounds[0]) & (s_y < y_req_bounds[1])]
    d = d.copy()

    n_rows_xphys, n_pat_xphys = rows_and_patients(d)
    flow_rows.append({
        "ycol": ycol,
        "stage": "final_usable_points_strict_etco2_rso2",
        "n_rows": n_rows_xphys,
        "n_patients": n_pat_xphys,
    })

    # Pointwise physiological clip for nuisance intra-op covariates
    for c, bounds in PHYSIO_CLIP_RANGES.items():
        if c in d.columns:
            clip_stat = clip_outside_range_to_nan(d, c, bounds)
            clip_stat["ycol"] = ycol
            clip_rows.append(clip_stat)
    n_rows_covclip, n_pat_covclip = rows_and_patients(d)
    flow_rows.append({
        "ycol": ycol,
        "stage": "after_intraop_covars_clip_to_missing",
        "n_rows": n_rows_covclip,
        "n_patients": n_pat_covclip,
    })

    for c in POINTWISE_FILL_VARS:
        if c in d.columns:
            fill_stat = fill_by_subject_then_global(d, c, id_col=id_col, time_col="obstime")
            fill_stat["ycol"] = ycol
            fill_rows.append(fill_stat)

    if MAX_POOL_ROWS > 0 and len(d) > MAX_POOL_ROWS:
        d = d.sample(n=MAX_POOL_ROWS, random_state=SEED, replace=False).copy()
    n_rows_final, n_pat_final = rows_and_patients(d)
    flow_rows.append({
        "ycol": ycol,
        "stage": "after_intraop_covars_fill",
        "n_rows": n_rows_final,
        "n_patients": n_pat_final,
    })
    return d, flow_rows, clip_rows, fill_rows


def build_subgroup_items() -> List[Dict[str, str]]:
    items = []
    if ANALYSIS_SCOPE in ("overall", "both"):
        items.append({"tag": "All", "query": ""})
    if ANALYSIS_SCOPE in ("subgroup", "both"):
        items.extend(SUBGROUP_DEFS)

    tags_env = os.getenv("SUBGROUP_TAGS", "").strip()
    if tags_env:
        wanted = {_safe_tag(x) for x in tags_env.split(",") if x.strip()}
        items = [x for x in items if _safe_tag(x.get("tag", "")) in wanted]
    return items


def build_subgroup_slope_metrics_csv(subgroup_dir: Path) -> int:
    files = sorted(subgroup_dir.rglob("*_slope_metrics_summary.csv"))
    if not files:
        return 0
    frames = []
    for fp in files:
        try:
            d = pd.read_csv(fp)
        except Exception:
            continue
        if len(d):
            frames.append(d)
    if not frames:
        return 0
    df = pd.concat(frames, ignore_index=True)
    df.to_csv(subgroup_dir / "slope_metrics_all.csv", index=False)
    return int(len(df))


def count_curve_boot_files(result_dir: Path) -> int:
    return int(len(list(result_dir.rglob("*_curve_boot.csv"))))


def render_result_ppt(result_dir: Path, plot_mode: str) -> Dict[str, str]:
    plot_mode = str(plot_mode).strip().lower()
    log_fp = result_dir / f"ppt_render_{plot_mode}.log"
    if not PPT_R_SCRIPT.exists():
        msg = f"skip: ppt R script not found: {PPT_R_SCRIPT}"
        log_fp.write_text(msg + "\n", encoding="utf-8")
        print(f"[ppt] [{result_dir.name}] [{plot_mode}] {msg}")
        return {"plot_mode": plot_mode, "status": "skip_missing_r_script", "log": str(log_fp)}

    cmd = [RSCRIPT_BIN, str(PPT_R_SCRIPT), str(result_dir)]
    try:
        env = os.environ.copy()
        env["INTRA5_PLOT_MODE"] = plot_mode
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True, check=False, env=env)
        out = p.stdout if isinstance(p.stdout, str) else ""
        log_fp.write_text(out, encoding="utf-8")
        if p.returncode == 0:
            print(f"[ppt] [{result_dir.name}] [{plot_mode}] done")
            return {"plot_mode": plot_mode, "status": "ok", "log": str(log_fp)}
        print(f"[ppt] [{result_dir.name}] [{plot_mode}] failed rc={p.returncode}")
        return {"plot_mode": plot_mode, "status": f"failed_rc_{p.returncode}", "log": str(log_fp)}
    except Exception as e:
        log_fp.write_text(f"exception: {e}\n", encoding="utf-8")
        print(f"[ppt] [{result_dir.name}] [{plot_mode}] exception: {e}")
        return {"plot_mode": plot_mode, "status": "exception", "log": str(log_fp)}


def render_result_ppt_both_modes(result_dir: Path) -> List[Dict[str, str]]:
    # 固定仅渲染 slice_median 的 PPT
    ppt_plot_modes = ["slice_median"]
    rows = []
    for plot_mode in ppt_plot_modes:
        rows.append(render_result_ppt(result_dir, plot_mode=plot_mode))
    return rows


def auto_render_subgroup_ppt(outdir: Path):
    if not AUTO_RENDER_PPT:
        print("[ppt] auto render disabled by INTRA5_AUTO_RENDER_PPT=0")
        return

    subgroup_root = outdir / SUBGROUP_ROOT_DIR
    if not subgroup_root.exists():
        n_metrics = build_subgroup_slope_metrics_csv(outdir)
        n_curve_files = count_curve_boot_files(outdir)
        if n_curve_files <= 0:
            print(f"[ppt] no subgroup root and no curve files: {outdir}")
            return
        rows = []
        for info in render_result_ppt_both_modes(outdir):
            rows.append({
                "subgroup": "All",
                "plot_mode": info.get("plot_mode", ""),
                "n_metrics_rows": int(n_metrics),
                "n_curve_boot_files": int(n_curve_files),
                "ppt_status": info.get("status", ""),
                "ppt_log": info.get("log", ""),
            })
        pd.DataFrame(rows).to_csv(outdir / "ppt_render_summary.csv", index=False)
        return

    rows = []
    subgroup_dirs = sorted([d for d in subgroup_root.iterdir() if d.is_dir()])
    for sg_dir in subgroup_dirs:
        n_metrics = build_subgroup_slope_metrics_csv(sg_dir)
        n_curve_files = count_curve_boot_files(sg_dir)
        if n_curve_files <= 0:
            print(f"[ppt] [{sg_dir.name}] skip: no curve_boot files")
            rows.append({
                "subgroup": sg_dir.name,
                "n_metrics_rows": int(n_metrics),
                "n_curve_boot_files": 0,
                "ppt_status": "skip_no_curve_boot",
                "ppt_log": "",
            })
            continue
        for info in render_result_ppt_both_modes(sg_dir):
            rows.append({
                "subgroup": sg_dir.name,
                "plot_mode": info.get("plot_mode", ""),
                "n_metrics_rows": int(n_metrics),
                "n_curve_boot_files": int(n_curve_files),
                "ppt_status": info.get("status", ""),
                "ppt_log": info.get("log", ""),
            })

    if rows:
        pd.DataFrame(rows).to_csv(outdir / "ppt_render_summary.csv", index=False)


def main():
    print(f"[OUTDIR] {OUTDIR}")
    print(f"[cfg] script_version={SCRIPT_VERSION}")
    print(
        f"[cfg] sec={FREQUENCIES_SEC}, k={SUBSAMPLE_SIZE}, boot={N_OUTER_RESAMPLES}, "
        f"outer_replace={OUTER_RESAMPLE_REPLACE}, ref_replace={REF_SAMPLE_REPLACE}"
    )
    print(
        f"[cfg] outcome-specific cohorts=1, ETCO2 strict range=({ETCO2_REQUIRED_RANGE[0]}, {ETCO2_REQUIRED_RANGE[1]})"
    )
    print(f"[cfg] outcome strict ranges={OUTCOME_REQUIRED_RANGES}")
    print(f"[cfg] physio clip ranges={PHYSIO_CLIP_RANGES}")
    print(f"[cfg] outcome clip ranges={OUTCOME_CLIP_RANGES}")
    print(f"[cfg] pointwise fill vars={POINTWISE_FILL_VARS}")
    print(
        f"[cfg] smooth auto={AUTO_TUNE_SMOOTH}, strategy={SMOOTH_STRATEGY}, "
        f"n_splines_cand={N_SPLINES_CAND}, lam_grid_n={len(LAM_GRID)}, "
        f"primary shared-k candidates={N_SPLINES_CAND}, tensor_k={N_SPLINES_TENSOR}, "
        f"covariate_k={N_SPLINES_COV}, random_search_n={SMOOTH_RANDOM_SEARCH_N}, "
        f"nuisance_lam_fixed={NUISANCE_LAM_FIXED}"
    )
    print(
        f"[cfg] main smooth vars={PRIMARY_VARS}, hemo_adjust_mode={HEMO_ADJUST_MODE}, "
        f"intraop_smooth_covars={INTRAOP_SMOOTH_COVARS}, optional_intraop_covars={OPTIONAL_INTRAOP_COVARS}"
    )
    print(f"[cfg] slope window mode={SLOPE_WINDOW_MODE}")
    print(f"[cfg] plot_modes={PLOT_MODES}")
    print(
        f"[cfg] analysis_scope={ANALYSIS_SCOPE}, enable_subgroup_switch={int(ENABLE_SUBGROUP)}, "
        f"subgroup_defs={len(SUBGROUP_DEFS)}"
    )
    print(
        f"[cfg] export_slope_metrics={int(EXPORT_SLOPE_METRICS)}, "
        f"enable_slope_metrics_switch={int(ENABLE_SLOPE_METRICS)}, "
        f"include_slope_panel={int(INCLUDE_SLOPE_PANEL)}"
    )
    print(f"[cfg] enable_pool_cache={int(ENABLE_POOL_CACHE)}, pool_cache_root={POOL_CACHE_ROOT}")

    need_cols = (
        ["stay_id", "patient_ID", "patient_id", "obstime"]
        + PRIMARY_VARS
        + OPTIONAL_INTRAOP_COVARS
        + OUTCOMES
        + ADJ_CONT_CAND
        + ADJ_CAT_CAND
        + SUBGROUP_STATIC_VARS
        + ["Sex", "SEX", "Age"]
    )
    df_ts = read_csv_folder_selected_cached(CSV_DIR, CSV_GLOB, need_cols=need_cols)
    static_need_cols = sorted(set(ADJ_CONT_CAND + ADJ_CAT_CAND + SUBGROUP_STATIC_VARS + ["Sex", "SEX", "Age"]))
    static_df = read_static_selected_multi(
        xlsx_paths=[XLSX_PATH_MAIN, XLSX_PATH_SUBGROUP],
        need_cols=static_need_cols,
    )

    df_ts = _coerce_stay_id(df_ts)
    static_df = _coerce_stay_id(static_df)
    df_ts = _coerce_patient_id(df_ts)
    static_df = _coerce_patient_id(static_df)

    merge_key = None
    for k in ["stay_id", "patient_ID", "patient_id"]:
        if (k in df_ts.columns) and (k in static_df.columns):
            merge_key = k
            break
    if merge_key is not None:
        static_cols = [c for c in static_df.columns if c != merge_key]
        df_base = df_ts.merge(static_df[[merge_key] + static_cols], on=merge_key, how="left")
    else:
        df_base = df_ts.copy()

    # 性别列兼容（Sex / SEX）
    if "Sex" not in df_base.columns and "SEX" in df_base.columns:
        df_base["Sex"] = df_base["SEX"]
    if "SEX" not in df_base.columns and "Sex" in df_base.columns:
        df_base["SEX"] = df_base["Sex"]

    safe_numeric(
        df_base,
        [c for c in PRIMARY_VARS + OPTIONAL_INTRAOP_COVARS + OUTCOMES + ADJ_CONT_CAND + ADJ_CAT_CAND + SUBGROUP_STATIC_VARS + ["Sex", "SEX", "Age"] if c in df_base.columns],
    )
    fio2_meta = maybe_convert_fio2_to_percent(df_base, col="FiO2_new")
    subgroup_items = build_subgroup_items()
    data_source_sig = build_data_source_signature()
    print(f"[cfg] subgroup_items={[_safe_tag(x.get('tag', '')) for x in subgroup_items]}")
    print(f"[cfg] data_source_sig={data_source_sig}")

    summary_rows = []
    flow_all = []
    clip_all = []
    fill_all = []
    pool_cache_rows = []
    pool_cache_hits = 0
    pool_cache_misses = 0
    pool_cache_writes = 0
    for sec in FREQUENCIES_SEC:
        df_sec = downsample(df_base, sec=sec)
        sec_rows, sec_pats = rows_and_patients(df_sec)
        flow_all.append({
            "sec": int(sec),
            "subgroup": "ALL",
            "subgroup_query": "",
            "ycol": "ALL",
            "stage": "sec_input_before_any_filter",
            "n_rows": sec_rows,
            "n_patients": sec_pats,
        })
        for sg in subgroup_items:
            sg_tag_raw = sg.get("tag", "group")
            sg_tag = _safe_tag(sg_tag_raw)
            sg_expr = str(sg.get("query", "") or "").strip()

            out_root = OUTDIR if sg_tag == "All" else (OUTDIR / SUBGROUP_ROOT_DIR / sg_tag)
            out_root.mkdir(parents=True, exist_ok=True)

            try:
                df_sub = apply_subgroup_query(df_sec, sg_expr)
            except Exception as e:
                print(f"[skip-subgroup] {sg_tag} | sec={sec}s | bad query `{sg_expr}`: {e}")
                continue

            if len(df_sub) == 0:
                print(f"[skip-subgroup] {sg_tag} | sec={sec}s | empty")
                continue

            sub_rows, sub_pats = rows_and_patients(df_sub)
            flow_all.append({
                "sec": int(sec),
                "subgroup": sg_tag,
                "subgroup_query": sg_expr,
                "ycol": "ALL",
                "stage": "after_subgroup_filter",
                "n_rows": sub_rows,
                "n_patients": sub_pats,
            })

            used_query_cols = set(_extract_query_cols(sg_expr, list(df_sub.columns)))
            # Sex/SEX 别名同步剔除，避免分层变量再次进入协变量校正
            if "Sex" in used_query_cols:
                used_query_cols.add("SEX")
            if "SEX" in used_query_cols:
                used_query_cols.add("Sex")
            extra_exclude_covars = sorted(used_query_cols)

            for ycol in OUTCOMES:
                if ycol not in df_sub.columns:
                    continue
                pool, flow_rows, clip_rows, fill_rows, cache_hit, cache_key, cache_written = build_unified_pool_cached(
                    df_sub,
                    ycol=ycol,
                    sec=int(sec),
                    subgroup_tag=sg_tag,
                    subgroup_query=sg_expr,
                    data_source_sig=data_source_sig,
                )
                if ENABLE_POOL_CACHE:
                    pool_cache_hits += int(cache_hit)
                    pool_cache_misses += int(1 - int(cache_hit))
                    pool_cache_writes += int(cache_written)
                else:
                    cache_key = "disabled"
                pool_rows, pool_pats = rows_and_patients(pool)
                pool_cache_rows.append({
                    "sec": int(sec),
                    "subgroup": sg_tag,
                    "subgroup_query": sg_expr,
                    "ycol": ycol,
                    "cache_hit": int(cache_hit),
                    "cache_written": int(cache_written),
                    "cache_key": str(cache_key),
                    "pool_rows": int(pool_rows),
                    "pool_patients": int(pool_pats),
                })
                print(
                    f"[pool-cache] [{sg_tag}] {ycol} {sec}s | "
                    f"{'hit' if cache_hit else ('disabled' if not ENABLE_POOL_CACHE else 'miss')} | key={cache_key}"
                )
                for fr in flow_rows:
                    fr["sec"] = int(sec)
                    fr["subgroup"] = sg_tag
                    fr["subgroup_query"] = sg_expr
                    flow_all.append(fr)
                for rr in clip_rows:
                    rr["sec"] = int(sec)
                    rr["subgroup"] = sg_tag
                    rr["subgroup_query"] = sg_expr
                    clip_all.append(rr)
                for rr in fill_rows:
                    rr["sec"] = int(sec)
                    rr["subgroup"] = sg_tag
                    rr["subgroup_query"] = sg_expr
                    fill_all.append(rr)
                if len(pool) < 1000:
                    print(f"[skip] [{sg_tag}] {ycol} {sec}s pool too small: {len(pool)}")
                    continue
                print(f"[pool] [{sg_tag}] {ycol} {sec}s rows={len(pool):,}")
                for k in SUBSAMPLE_SIZE:
                    try:
                        res_list = run_one_model(
                            pool,
                            ycol=ycol,
                            sec=sec,
                            k=int(k),
                            out_root=out_root,
                            subgroup_tag=sg_tag,
                            extra_exclude_covars=extra_exclude_covars,
                        )
                        if res_list is not None:
                            for res in res_list:
                                res["subgroup"] = sg_tag
                                res["subgroup_query"] = sg_expr
                                summary_rows.append(res)
                            print(
                                f"[done] [{sg_tag}] {ycol} | {sec}s | sub{min(int(k), len(pool))} "
                                f"| multismooth={len(PRIMARY_VARS)} | plot_modes={len(PLOT_MODES)}"
                            )
                        else:
                            print(f"[skip] [{sg_tag}] {ycol} | {sec}s | insufficient rows")
                    except Exception as e:
                        print(f"[error] [{sg_tag}] {ycol} | {sec}s | multismooth | {e}")

    if summary_rows:
        df_all = pd.concat(summary_rows, ignore_index=True)
        df_all.to_csv(OUTDIR / "slope_metrics_all.csv", index=False)
    else:
        df_all = pd.DataFrame()

    pd.DataFrame([{
        "script_version": SCRIPT_VERSION,
        "script_file": str(Path(__file__).resolve()),
        "run_stamp": STAMP,
        "rows_raw": int(len(df_base)),
        "fio2_converted_to_percent": int(fio2_meta.get("fio2_converted_to_percent", 0)),
        "fio2_rows_converted": int(fio2_meta.get("fio2_rows_converted", 0)),
        "fio2_valid_rows": int(fio2_meta.get("fio2_valid_rows", 0)),
        "outcome_specific_cohorts": 1,
        "etco2_required_lo_strict": ETCO2_REQUIRED_RANGE[0],
        "etco2_required_hi_strict": ETCO2_REQUIRED_RANGE[1],
        "outcome_required_ranges_strict": json.dumps(OUTCOME_REQUIRED_RANGES, ensure_ascii=False),
        "physio_clip_ranges": json.dumps(PHYSIO_CLIP_RANGES, ensure_ascii=False),
        "enable_outcome_clip": int(ENABLE_OUTCOME_CLIP),
        "outcome_clip_ranges": json.dumps(OUTCOME_CLIP_RANGES, ensure_ascii=False),
        "pointwise_fill_vars": json.dumps(POINTWISE_FILL_VARS, ensure_ascii=False),
        "pointwise_fill_strategy": "forward_fill_then_subject_median_then_global_median",
        "ref_sample_replace": int(REF_SAMPLE_REPLACE),
        "main_smooth_vars": json.dumps(PRIMARY_VARS, ensure_ascii=False),
        "hemo_adjust_mode": HEMO_ADJUST_MODE,
        "hemo_tensor_vars": json.dumps(HEMO_TENSOR_VARS, ensure_ascii=False),
        "hemo_smooth_covars_fallback": json.dumps(HEMO_SMOOTH_COVARS_FALLBACK, ensure_ascii=False),
        "intraop_smooth_covars": json.dumps(INTRAOP_SMOOTH_COVARS, ensure_ascii=False),
        "static_continuous_covars_term": "s()",
        "intraop_linear_covars": json.dumps(INTRAOP_LINEAR_COVARS, ensure_ascii=False),
        "auto_tune_smooth": int(AUTO_TUNE_SMOOTH),
        "smooth_strategy": SMOOTH_STRATEGY,
        "smooth_random_search_n": int(SMOOTH_RANDOM_SEARCH_N),
        "nuisance_lam_fixed": float(NUISANCE_LAM_FIXED),
        "n_splines_main_fixed": N_SPLINES_MAIN,
        "n_splines_primary_candidates": json.dumps(N_SPLINES_CAND, ensure_ascii=False),
        "n_splines_tensor_fixed": int(N_SPLINES_TENSOR),
        "n_splines_covariate_fixed": int(N_SPLINES_COV),
        "lam_fixed": LAM_FIXED,
        "n_splines_candidates": json.dumps(N_SPLINES_CAND, ensure_ascii=False),
        "lam_grid": json.dumps([float(x) for x in LAM_GRID], ensure_ascii=False),
        "slope_window_mode": SLOPE_WINDOW_MODE,
        "plot_modes": json.dumps(PLOT_MODES, ensure_ascii=False),
        "auto_render_ppt": int(AUTO_RENDER_PPT),
        "rscript_bin": RSCRIPT_BIN,
        "ppt_r_script": str(PPT_R_SCRIPT),
        "analysis_scope": ANALYSIS_SCOPE,
        "enable_subgroup_switch": int(ENABLE_SUBGROUP),
        "export_slope_metrics": int(EXPORT_SLOPE_METRICS),
        "enable_slope_metrics_switch": int(ENABLE_SLOPE_METRICS),
        "include_slope_panel": int(INCLUDE_SLOPE_PANEL),
        "enable_pool_cache": int(ENABLE_POOL_CACHE),
        "pool_cache_version": POOL_CACHE_VERSION,
        "pool_cache_hits": int(pool_cache_hits),
        "pool_cache_misses": int(pool_cache_misses),
        "pool_cache_writes": int(pool_cache_writes),
        "data_source_sig": data_source_sig,
        "static_xlsx_main": str(XLSX_PATH_MAIN),
        "static_xlsx_subgroup": str(XLSX_PATH_SUBGROUP),
        "subgroup_defs": json.dumps(SUBGROUP_DEFS, ensure_ascii=False),
        "n_results": int(len(df_all)),
    }]).to_csv(OUTDIR / "run_summary.csv", index=False)

    if len(flow_all):
        pd.DataFrame(flow_all).to_csv(OUTDIR / "filter_flow_counts.csv", index=False)
    if len(clip_all):
        pd.DataFrame(clip_all).to_csv(OUTDIR / "physio_clip_summary.csv", index=False)
    if len(fill_all):
        pd.DataFrame(fill_all).to_csv(OUTDIR / "pointwise_fill_summary.csv", index=False)
    if len(pool_cache_rows):
        pd.DataFrame(pool_cache_rows).to_csv(OUTDIR / "pool_cache_summary.csv", index=False)

    auto_render_subgroup_ppt(OUTDIR)

    print(f"[done] outputs in: {OUTDIR}")


if __name__ == "__main__":
    main()
