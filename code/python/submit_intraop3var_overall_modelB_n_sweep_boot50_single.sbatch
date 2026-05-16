#!/bin/bash
#SBATCH --job-name=ov_modelB_nsweep_b50
#SBATCH --account=r00209
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=48:00:00
#SBATCH --output=/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result/slurm_logs/%x-%A.out
#SBATCH --error=/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result/slurm_logs/%x-%A.err

set -euo pipefail

module load python/gpu
cd /N/project/waveform_mortality/ZhaoZhang
source /N/project/waveform_mortality/ZhaoZhang/timesfm311/bin/activate

BASE="/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025"
SCRIPT="${BASE}/slurm_final_code_3_2_2026/contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py"
R_SCRIPT="${BASE}/R_code/contour_9_29_2025/R_counter_GAM_py/切片图_slice_only_ppt_v2_4_1_2026_multismooth.R"
PYTHON_BIN="${PYTHON_BIN:-python}"
mkdir -p "${BASE}/result/slurm_logs"

N="${N:?N is required}"
N_BOOT="${N_BOOT:-50}"
RUN_TAG="${RUN_TAG_PREFIX:-overall_modelB_sec1_nSweep}_${N}_boot${N_BOOT}_rowreplace"

echo "[INFO] host=$(hostname)"
echo "[INFO] start_time=$(date -Iseconds)"
echo "[INFO] run_tag=${RUN_TAG}"
echo "[INFO] n=${N}, boot=${N_BOOT}"

export PYTHONUNBUFFERED=1
export MPLBACKEND=Agg

export INTRA5_ENABLE_SUBGROUP=0
export INTRA5_ANALYSIS_SCOPE=overall
export INTRA5_HEMO_ADJUST_MODE=map_sv_smooth
export INTRA5_FREQUENCIES_SEC=1
export INTRA5_SUBSAMPLE_SIZE="${N}"
export INTRA5_N_OUTER_RESAMPLES="${N_BOOT}"
export INTRA5_OUTER_RESAMPLE_REPLACE=1
export INTRA5_REF_SAMPLE_REPLACE=1
export INTRA5_AUTO_TUNE_SMOOTH="${INTRA5_AUTO_TUNE_SMOOTH:-1}"
export INTRA5_SMOOTH_STRATEGY="${INTRA5_SMOOTH_STRATEGY:-shared_k_sep_lam}"
export INTRA5_X_RANGE_MODE="${INTRA5_X_RANGE_MODE:-full}"
export INTRA5_AUTO_RENDER_PPT=0
export INTRA5_OUTDIR_TAG="${RUN_TAG}"

"${PYTHON_BIN}" "${SCRIPT}"

LATEST_OUTDIR="$(ls -1dt "${BASE}/result/"*"_${RUN_TAG}" 2>/dev/null | head -n 1 || true)"
if [[ -z "${LATEST_OUTDIR}" ]]; then
  echo "[ERROR] cannot find result dir for tag: ${RUN_TAG}"
  exit 1
fi
echo "[INFO] latest_outdir=${LATEST_OUTDIR}"

INTRA5_PLOT_MODE=slice_median Rscript "${R_SCRIPT}" "${LATEST_OUTDIR}"

echo "[INFO] end_time=$(date -Iseconds)"
echo "[INFO] done"
