#!/bin/bash
set -euo pipefail

BASE_RESULT="/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/result"
SCRIPT_DIR="/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/python"
SBATCH_SCRIPT="${SCRIPT_DIR}/submit_intraop3var_overall_modelB_n_sweep_boot50_single.sbatch"
LOG_DIR="/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/logs"
mkdir -p "${LOG_DIR}"

# Fixed grid from protocol
NS=(500 1000 5000 10000 50000 100000 500000 1000000 5000000)
N_BOOT="${N_BOOT:-50}"
RUN_TAG_PREFIX="${RUN_TAG_PREFIX:-overall_modelB_sec1_nSweep}"

stamp="$(date +%Y%m%d_%H%M%S)"
out_csv="${LOG_DIR}/modelB_n_sweep_resubmit_${stamp}.csv"
echo "n,status,job_id,reason,existing_dir" > "${out_csv}"

for N in "${NS[@]}"; do
  pat="*_${RUN_TAG_PREFIX}_${N}_boot${N_BOOT}_rowreplace"
  latest="$(ls -1dt ${BASE_RESULT}/${pat} 2>/dev/null | head -n 1 || true)"

  complete=0
  if [[ -n "${latest}" && -f "${latest}/run_summary.csv" ]]; then
    c1=$(find "${latest}" -type f -name "rSO2_Ch1_ET_CO2_*_slice_median_curve_boot.csv" | wc -l)
    c2=$(find "${latest}" -type f -name "rSO2_Ch2_ET_CO2_*_slice_median_curve_boot.csv" | wc -l)
    c3=$(find "${latest}" -type f -name "rSO2_Ch3_ET_CO2_*_slice_median_curve_boot.csv" | wc -l)
    if [[ ${c1} -ge 1 && ${c2} -ge 1 && ${c3} -ge 1 ]]; then
      complete=1
    fi
  fi

  if [[ ${complete} -eq 1 ]]; then
    echo "${N},skip,,already_complete,${latest}" >> "${out_csv}"
    echo "[skip] N=${N} complete"
    continue
  fi

  submit_out="$(N=${N} N_BOOT=${N_BOOT} RUN_TAG_PREFIX=${RUN_TAG_PREFIX} sbatch "${SBATCH_SCRIPT}")"
  job_id="$(echo "${submit_out}" | awk '{print $NF}')"
  echo "${N},submitted,${job_id},missing_or_incomplete,${latest}" >> "${out_csv}"
  echo "[submit] N=${N} job=${job_id}"
done

echo "[done] ${out_csv}"
