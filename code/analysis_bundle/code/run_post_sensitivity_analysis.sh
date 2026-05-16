#!/bin/bash
set -euo pipefail

cd /N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/analysis_crossvar_bundle_20260513
python3 code/summarize_etco2_sensitivity.py
python3 code/mediation_singleM_from_sensitivity.py

echo "done: output/tables/etco2_sensitivity_5model_summary.csv"
echo "done: output/tables/etco2_attenuation_vs_base.csv"
echo "done: output/tables/mediation_singleM_effects.csv"
echo "done: output/tables/mediation_singleM_bootstrap.csv"
echo "done: output/figures/mediation_singleM_forest_plot.png (if enough completed data)"
