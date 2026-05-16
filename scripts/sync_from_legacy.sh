#!/bin/bash
set -euo pipefail

SRC="/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025"
DST="/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516"

# Incremental sync of key code files
cp "${SRC}/slurm_final_code_3_2_2026/contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py" "${DST}/code/python/"
cp "${SRC}/slurm_final_code_3_2_2026/contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95_patient_resample.py" "${DST}/code/python/"
cp "${SRC}/R_code/contour_9_29_2025/R_counter_GAM_py/切片图_slice_only_ppt_v2_4_1_2026_multismooth.R" "${DST}/code/r/"

# Sync analysis bundle lightweight content (exclude heavy result dir)
rsync -a --delete --exclude 'result/' "${SRC}/analysis_crossvar_bundle_20260513/" "${DST}/code/analysis_bundle/"

echo "sync complete"
