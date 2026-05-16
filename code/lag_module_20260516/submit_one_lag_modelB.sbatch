#!/bin/bash
#SBATCH --job-name=lag_modelB
#SBATCH --account=r00209
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=48:00:00
#SBATCH --output=/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/lag_module_20260516/output/logs/%x-%j.out
#SBATCH --error=/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/lag_module_20260516/output/logs/%x-%j.err

set -euo pipefail

module load python/gpu
cd /N/project/waveform_mortality/ZhaoZhang
source /N/project/waveform_mortality/ZhaoZhang/timesfm311/bin/activate

LAG_WS="/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/lag_module_20260516"
PY_SCRIPT="${LAG_WS}/run_lag_single_modelB.py"

LAG_SECONDS="${LAG_SECONDS:-0}"
OUTDIR_TAG="${OUTDIR_TAG:-lag${LAG_SECONDS}_modelB_n10000_b200}"

mkdir -p "${LAG_WS}/output/logs"

export PYTHONUNBUFFERED=1
export MPLBACKEND=Agg

export INTRA5_ENABLE_SUBGROUP=0
export INTRA5_ANALYSIS_SCOPE=overall
export INTRA5_HEMO_ADJUST_MODE=map_sv_smooth
export INTRA5_FREQUENCIES_SEC=1
export INTRA5_SUBSAMPLE_SIZE=10000
export INTRA5_N_OUTER_RESAMPLES=200
export INTRA5_OUTER_RESAMPLE_REPLACE=1
export INTRA5_REF_SAMPLE_REPLACE=1
export INTRA5_AUTO_TUNE_SMOOTH=1
export INTRA5_SMOOTH_STRATEGY=shared_k_sep_lam
export INTRA5_X_RANGE_MODE=full
export INTRA5_AUTO_RENDER_PPT=0
export INTRA5_SLICE_VARS=ET_CO2
export INTRA5_ENABLE_POOL_CACHE=0

export INTRA5_CO2_LAG_SECONDS="${LAG_SECONDS}"
export INTRA5_OUTDIR_TAG="${OUTDIR_TAG}"

python "${PY_SCRIPT}"
