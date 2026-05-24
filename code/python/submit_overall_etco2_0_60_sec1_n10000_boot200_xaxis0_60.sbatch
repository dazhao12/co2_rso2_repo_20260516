#!/bin/bash
#SBATCH --job-name=ov_etco2_0_60_n10k_b200
#SBATCH --account=r00209
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=48:00:00
#SBATCH --output=/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/result/slurm_logs/%x-%j.out
#SBATCH --error=/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/result/slurm_logs/%x-%j.err

set -euo pipefail

module load python/gpu
cd /N/project/waveform_mortality/ZhaoZhang
source /N/project/waveform_mortality/ZhaoZhang/timesfm311/bin/activate

REPO="/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516"
SCRIPT="${REPO}/code/python/contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95_etco2_0_60_test.py"
R_SCRIPT="${REPO}/code/r/切片图_slice_only_ppt_v2_4_1_2026_multismooth.R"
RUN_TAG="${RUN_TAG:-overall_etco2_0_60_sec1_n10000_boot200_xaxis0_60_slurm}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
RSCRIPT_BIN="${RSCRIPT_BIN:-Rscript}"

mkdir -p "${REPO}/code/result/slurm_logs"
mkdir -p /N/scratch/zz86/tmp/mpl

echo "[INFO] host=$(hostname)"
echo "[INFO] start_time=$(date -Iseconds)"
echo "[INFO] run_tag=${RUN_TAG}"

export PYTHONUNBUFFERED=1
export MPLBACKEND=Agg
export MPLCONFIGDIR=/N/scratch/zz86/tmp/mpl

export INTRA5_ANALYSIS_SCOPE=overall
export INTRA5_ENABLE_SUBGROUP=0
export INTRA5_FREQUENCIES_SEC=1
export INTRA5_SUBSAMPLE_SIZE=10000
export INTRA5_N_OUTER_RESAMPLES=200
export INTRA5_OUTER_RESAMPLE_REPLACE=1
export INTRA5_REF_SAMPLE_REPLACE=1
export INTRA5_OUTDIR_TAG="${RUN_TAG}"

# Render PPT after the model run so the expanded ETCO2 axis is explicit.
export INTRA5_AUTO_RENDER_PPT=0
export INTRA5_ETCO2_X_MIN=0
export INTRA5_ETCO2_X_MAX=60
export INTRA5_ETCO2_X_STEP=10

"${PYTHON_BIN}" "${SCRIPT}"

LATEST_OUTDIR="$(ls -1dt "${REPO}/code/result/"*"_${RUN_TAG}" 2>/dev/null | head -n 1 || true)"
if [[ -z "${LATEST_OUTDIR}" ]]; then
  echo "[ERROR] cannot find result dir for tag: ${RUN_TAG}"
  exit 1
fi
echo "[INFO] latest_outdir=${LATEST_OUTDIR}"

"${RSCRIPT_BIN}" "${R_SCRIPT}" "${LATEST_OUTDIR}"

RESULT_BASENAME="$(basename "${LATEST_OUTDIR}")"
PPT_SOURCE_BASE="/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/fig_output/R_intraop5_slice_only_ppt_v2_4_1_2026_multismooth"
PPT_DIR="$(ls -1dt "${PPT_SOURCE_BASE}/from_${RESULT_BASENAME}_slice_y66_80_2_ycCh1_Ch2_Ch3_xco2_0_60_10"* 2>/dev/null | head -n 1 || true)"
if [[ -z "${PPT_DIR}" ]]; then
  echo "[ERROR] cannot find rendered PPT directory for result: ${RESULT_BASENAME}"
  exit 1
fi
mkdir -p "${REPO}/results/fig_output"
cp -r "${PPT_DIR}" "${REPO}/results/fig_output/"
echo "[INFO] copied_ppt_dir=${REPO}/results/fig_output/$(basename "${PPT_DIR}")"

echo "[INFO] end_time=$(date -Iseconds)"
echo "[INFO] done"
