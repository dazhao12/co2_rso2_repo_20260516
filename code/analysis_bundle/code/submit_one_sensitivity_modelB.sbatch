#!/bin/bash
#SBATCH --job-name=sens_modelB
#SBATCH --account=r00209
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=48:00:00
#SBATCH --output=/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/analysis_crossvar_bundle_20260513/output/logs/%x-%j.out
#SBATCH --error=/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/analysis_crossvar_bundle_20260513/output/logs/%x-%j.err

set -euo pipefail

module load python/gpu
cd /N/project/waveform_mortality/ZhaoZhang
source /N/project/waveform_mortality/ZhaoZhang/timesfm311/bin/activate

WS="/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/analysis_crossvar_bundle_20260513"
PY_SCRIPT="${WS}/code/contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95_slicevars.py"

RUN_KEY="${RUN_KEY:-base}"
OUTDIR_TAG="${OUTDIR_TAG:-sensA_base_no_ventcov_modelB_n10000_b200}"
INTRAOP_SMOOTH_COVARS="${INTRAOP_SMOOTH_COVARS:-}"

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
export INTRA5_OUTDIR_TAG="${OUTDIR_TAG}"
export INTRA5_INTRAOP_SMOOTH_COVARS="${INTRAOP_SMOOTH_COVARS}"
export INTRA5_SLICE_VARS=ET_CO2

python "${PY_SCRIPT}"
