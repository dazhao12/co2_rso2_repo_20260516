#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025
R_BIN=/N/soft/rhel8/r/gnu/4.4.1/bin/Rscript
SCRIPT=$PROJECT_ROOT/slurm_final_code_3_2_2026/03_slice_ppt_figures_6cm_20260616.R
OVERALL_RESULT=$PROJECT_ROOT/result/v5_6_2026_rev2_20260506_co2tempfio2_hemo_adj_boot20_rso2_25_95_full_20260614_190104_overall_modelA_mapci_te_sec1_n10000_boot200_rowreplace

export CO2_PROJECT_ROOT=$PROJECT_ROOT
export INTRA5_EXPORT_PNG=0
export INTRA5_ADD_CLINICAL_COMPARE=1
export INTRA5_SKIP_MARGINAL=1
export INTRA5_XVARS=ET_CO2,TEMP,FiO2_new

for sp in 0.85 0.65 0.45; do
  tag=${sp/./p}
  export INTRA5_FIO2_SMOOTH_SP=$sp
  export INTRA5_OUT_FIG_BASE=$PROJECT_ROOT/fig_output/R_intraop5_slice_only_ppt_v2_4_1_2026_multismooth_6cm_20260616_overall_fio2sp_$tag
  echo "[run] FIO2_SMOOTH_SP=$sp"
  $R_BIN $SCRIPT $OVERALL_RESULT
done
