# Migration Manifest (2026-05-16)

Source root:
- `/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025`

Copied code:
- `slurm_final_code_3_2_2026/contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py`
- `slurm_final_code_3_2_2026/contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95_patient_resample.py`
- `slurm_final_code_3_2_2026/submit_intraop3var_overall_modelB_n10000_boot200_rowreplace.sbatch`
- `slurm_final_code_3_2_2026/submit_intraop3var_subgroup_modelB_n10000_boot200_rowreplace.sbatch`
- `slurm_final_code_3_2_2026/submit_intraop3var_overall_mapci_te_n100k_boot200_ppt.sbatch`
- `R_code/contour_9_29_2025/R_counter_GAM_py/切片图_slice_only_ppt_v2_4_1_2026_multismooth.R`
- `analysis_crossvar_bundle_20260513/{code,input_links,output}` (excluding `result/`)

Copied key results:
- `result/..._overall_mapci_te_n10000_boot200`
- `result/..._overall_modelB_sec1_n10000_boot200_rowreplace`
- `result/..._subgroup_modelB_sec1_n10000_boot200_rowreplace`
- Key figure-output folders under `fig_output/R_intraop5_slice_only_ppt_v2_4_1_2026_multismooth/`

Excluded intentionally:
- Large intermediate caches and bulk historical result trees not needed for immediate CO2-rSO2 workflow.
