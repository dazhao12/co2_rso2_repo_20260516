# Intraoperative GAM Analysis Script Guide

This directory intentionally keeps two closely related Python scripts. Use this
file as the source of truth when choosing which script to run.

## Main analysis

Use:

`contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py`

Role:

- This is the main analysis script.
- Current sbatch jobs call this script.
- Bootstrap/reference sampling is row-level sampling.
- Keep this script as the default for manuscript main results unless the
  analysis plan is explicitly changed.

Current sbatch wrappers:

- `submit_intraop3var_overall_mapci_te_n100k_boot200_ppt.sbatch`
- `submit_intraop3var_overall_modelB_n10000_boot200_rowreplace.sbatch`
- `submit_intraop3var_subgroup_modelB_n10000_boot200_rowreplace.sbatch`

## Patient-resampling variant

Use:

`contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95_patient_resample.py`

Role:

- This is not the current main analysis script.
- It is a patient-level resampling variant.
- It samples patients first, then takes rows from selected patients.
- Treat it as a sensitivity or alternative bootstrap implementation unless
  the sbatch wrappers are deliberately switched to it.

## Naming rule

- No suffix: main analysis.
- `_patient_resample`: patient-level resampling variant, not main by default.
