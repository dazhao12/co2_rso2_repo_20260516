#!/bin/bash
#SBATCH --job-name=ov_mapci_n100k_b200
#SBATCH --account=r00209
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=48:00:00
#SBATCH --output=/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result/slurm_logs/%x-%j.out
#SBATCH --error=/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result/slurm_logs/%x-%j.err

set -euo pipefail

# Runtime env
module load python/gpu
cd /N/project/waveform_mortality/ZhaoZhang
source /N/project/waveform_mortality/ZhaoZhang/timesfm311/bin/activate

BASE="/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025"
# Main analysis script: no "_patient_resample" suffix.
SCRIPT="${BASE}/slurm_final_code_3_2_2026/contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py"
R_SCRIPT="${BASE}/R_code/contour_9_29_2025/R_counter_GAM_py/切片图_slice_only_ppt_v2_4_1_2026_multismooth.R"
PYTHON_BIN="${PYTHON_BIN:-python}"
LOG_DIR="${BASE}/result/slurm_logs"
mkdir -p "${LOG_DIR}"

RUN_TAG="${RUN_TAG:-overall_mapci_te_n100k_boot200}"
echo "[INFO] host=$(hostname)"
echo "[INFO] start_time=$(date -Iseconds)"
echo "[INFO] run_tag=${RUN_TAG}"
echo "[INFO] script=${SCRIPT}"
echo "[INFO] python=${PYTHON_BIN}"

export PYTHONUNBUFFERED=1
export MPLBACKEND=Agg

# Core analysis switches
export INTRA5_ANALYSIS_SCOPE=overall
export INTRA5_HEMO_ADJUST_MODE=map_ci_te
export INTRA5_FREQUENCIES_SEC=1
export INTRA5_SUBSAMPLE_SIZE=100000
export INTRA5_N_OUTER_RESAMPLES=200
export INTRA5_AUTO_TUNE_SMOOTH="${INTRA5_AUTO_TUNE_SMOOTH:-1}"
export INTRA5_SMOOTH_STRATEGY="${INTRA5_SMOOTH_STRATEGY:-shared_k_sep_lam}"
export INTRA5_X_RANGE_MODE="${INTRA5_X_RANGE_MODE:-full}"
export INTRA5_AUTO_RENDER_PPT=0
export INTRA5_OUTDIR_TAG="${RUN_TAG}"

"${PYTHON_BIN}" "${SCRIPT}"

# Render slice PPT after Python finishes
LATEST_OUTDIR="$(ls -1dt "${BASE}/result/"*"_${RUN_TAG}" 2>/dev/null | head -n 1 || true)"
if [[ -z "${LATEST_OUTDIR}" ]]; then
  echo "[ERROR] cannot find result dir for tag: ${RUN_TAG}"
  exit 1
fi
echo "[INFO] latest_outdir=${LATEST_OUTDIR}"

INTRA5_PLOT_MODE=slice_median Rscript "${R_SCRIPT}" "${LATEST_OUTDIR}"

echo "[INFO] end_time=$(date -Iseconds)"
echo "[INFO] done"

