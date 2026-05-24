#!/bin/bash
#SBATCH --job-name=ov_etco2_0_60_n10k_b2
#SBATCH --account=r00209
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=24:00:00
#SBATCH --output=/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/result/slurm_logs/%x-%j.out
#SBATCH --error=/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/result/slurm_logs/%x-%j.err

set -euo pipefail

module load python/gpu
cd /N/project/waveform_mortality/ZhaoZhang
source /N/project/waveform_mortality/ZhaoZhang/timesfm311/bin/activate

mkdir -p /N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/result/slurm_logs
mkdir -p /N/scratch/zz86/tmp/mpl

SCRIPT=/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/python/contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95_etco2_0_60_test.py

export PYTHONUNBUFFERED=1
export MPLBACKEND=Agg
export MPLCONFIGDIR=/N/scratch/zz86/tmp/mpl

export INTRA5_ANALYSIS_SCOPE=overall
export INTRA5_ENABLE_SUBGROUP=0
export INTRA5_FREQUENCIES_SEC=1
export INTRA5_SUBSAMPLE_SIZE=10000
export INTRA5_N_OUTER_RESAMPLES=2
export INTRA5_OUTER_RESAMPLE_REPLACE=1
export INTRA5_REF_SAMPLE_REPLACE=1
export INTRA5_OUTDIR_TAG=overall_etco2_0_60_sec1_n10000_boot2_slurm
export INTRA5_AUTO_RENDER_PPT=1

python3 "$SCRIPT"
