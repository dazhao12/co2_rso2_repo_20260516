#!/bin/bash
#SBATCH -J slice6cm_t1
#SBATCH --account=r00209
#SBATCH -p general
#SBATCH -o /N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/logs/slice6cm_t1_%j.out
#SBATCH -e /N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/logs/slice6cm_t1_%j.err
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=96G

set -euo pipefail

R_BIN="/N/soft/rhel8/r/gnu/4.4.1/bin/Rscript"
PROJECT_ROOT="/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025"
SCRIPT="$PROJECT_ROOT/slurm_final_code_3_2_2026/03_slice_ppt_figures_6cm_20260616.R"

OVERALL_RESULT="$PROJECT_ROOT/result/v5_6_2026_rev2_20260506_co2tempfio2_hemo_adj_boot20_rso2_25_95_full_20260614_190104_overall_modelA_mapci_te_sec1_n10000_boot200_rowreplace"
SUBGROUP_RESULT="$PROJECT_ROOT/result/v5_6_2026_rev2_20260506_co2tempfio2_hemo_adj_boot20_rso2_25_95_full_20260614_190104_subgroup_modelA_mapci_te_sec1_n10000_boot200_rowreplace"

mkdir -p "$PROJECT_ROOT/logs"

export CO2_PROJECT_ROOT="$PROJECT_ROOT"
export INTRA5_EXPORT_PNG=0
export INTRA5_ADD_CLINICAL_COMPARE=1
export INTRA5_SKIP_MARGINAL=0
export INTRA5_XVARS="ET_CO2,TEMP,FiO2_new"
export INTRA5_FIO2_SMOOTH_SP=0.85
export INTRA5_OUT_FIG_BASE="$PROJECT_ROOT/fig_output/R_intraop5_slice_only_ppt_v2_4_1_2026_multismooth_6cm_20260616_fio2sp085_temp1_full"

"$R_BIN" "$SCRIPT" "$OVERALL_RESULT"
"$R_BIN" "$SCRIPT" "$SUBGROUP_RESULT"
