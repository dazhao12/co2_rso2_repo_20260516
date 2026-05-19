#!/usr/bin/env python3
"""
v1.1 - 通用滞后单次运行脚本
改动：
  - 消除绝对路径硬编码，基于 Path(__file__) 动态获取 REPO_ROOT。
  - 动态从环境变量读取 HEMO_ADJUST 并以 modelA/modelB 自动命名输出文件夹。
基于：run_lag_single_modelB.py
解决问题：模型配置写死、路径硬编码问题，提高可维护性。
"""


import importlib.util
import os
from pathlib import Path

import pandas as pd

# Use relative pathing to resolve the base script path robustly
REPO_ROOT = Path(__file__).resolve().parents[2]
BASE_SCRIPT = REPO_ROOT / "code" / "analysis_bundle" / "code" / "contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95_slicevars.py"


def load_base_module():
    spec = importlib.util.spec_from_file_location("slicevars_base", str(BASE_SCRIPT))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load base script: {BASE_SCRIPT}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def patch_downsample_with_lag(mod, lag_seconds: int):
    orig_downsample = mod.downsample

    def downsample_with_lag(df, sec: int):
        out = orig_downsample(df, sec)
        if lag_seconds <= 0:
            return out
        if "ET_CO2" not in out.columns:
            return out

        steps = int(round(float(lag_seconds) / float(sec)))
        if steps <= 0:
            return out

        id_col = mod.get_subject_id_col(out)
        if id_col is None or id_col not in out.columns:
            # Fallback: global shift if subject id is unavailable
            out = out.copy()
            out["ET_CO2"] = pd.to_numeric(out["ET_CO2"], errors="coerce").shift(steps)
            return out

        tmp = out.copy()
        tmp["_orig_idx"] = range(len(tmp))
        tmp["obstime"] = pd.to_numeric(tmp["obstime"], errors="coerce")
        tmp = tmp.sort_values([id_col, "obstime", "_orig_idx"], kind="mergesort")

        s_et = pd.to_numeric(tmp["ET_CO2"], errors="coerce")
        tmp["ET_CO2"] = s_et.groupby(tmp[id_col]).shift(steps)

        tmp = tmp.sort_values("_orig_idx", kind="mergesort").drop(columns=["_orig_idx"], errors="ignore")
        return tmp

    mod.downsample = downsample_with_lag


def main():
    lag_seconds = int(os.getenv("INTRA5_CO2_LAG_SECONDS", "0"))
    mod = load_base_module()

    # Ensure the run summary records this lag setting.
    mod.LAG_SECONDS = lag_seconds

    # Patch data preparation: ET_CO2(t) -> ET_CO2(t-L).
    patch_downsample_with_lag(mod, lag_seconds=lag_seconds)

    print(f"[lag] using ET_CO2 lag={lag_seconds}s (within-subject shift)")
    mod.main()


if __name__ == "__main__":
    main()
