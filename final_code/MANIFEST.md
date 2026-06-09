# Final Code Manifest

This folder is a snapshot of the final scripts used for the CO2-rSO2 analysis
package. Files are copied here for backup and handoff. The original working
locations under `code/` and `docs/` remain the active development locations.

## Rule for model scripts

- Main analysis script: the no-suffix Python script.
- Patient-resampling variant: the `_patient_resample.py` script.
- Current sbatch wrappers call the no-suffix main analysis script.

## python_model

- `contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py`
  - Main GAM analysis script.
  - Default manuscript main analysis.
  - Row-level bootstrap/reference sampling.
- `contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95_patient_resample.py`
  - Patient-level resampling variant.
  - Keep as sensitivity/alternative implementation unless the analysis plan is
    deliberately changed.
- `submit_intraop3var_overall_mapci_te_n100k_boot200_ppt.sbatch`
  - Overall Model A wrapper: `te(MAP, CI)`, n=100000, boot=200.
- `submit_intraop3var_overall_modelB_n10000_boot200_rowreplace.sbatch`
  - Overall Model B wrapper: `s(MAP) + s(SV) + s(HR)`, n=10000, boot=200.
- `submit_intraop3var_subgroup_modelB_n10000_boot200_rowreplace.sbatch`
  - Subgroup Model B wrapper, n=10000, boot=200.
- `ANALYSIS_SCRIPT_GUIDE.md`
  - Short guide for choosing between the no-suffix main script and the
    patient-resampling variant.

## r_figures

- `切片图_slice_only_ppt_v2_4_1_2026_multismooth.R`
  - Final R script for slice-curve PPT generation from model output folders.

## tables

- `build_table1_2_co2_rso2.py`
  - Builds manuscript Table 1/2 cohort and intraoperative summaries.
- `build_supplemental_etables_3_5_co2_rso2.py`
  - Builds supplemental eTables 3-5.
- `build_supplemental_etables_6_8_co2_rso2.py`
  - Builds supplemental eTables 6-8.

## manuscript_code

- `generate_manuscript_assets.py`
  - Generates manuscript-facing tables, figures, and source-data assets.
- `build_manuscript_docx.py`
  - Builds the main manuscript DOCX.
- `build_integrated_supplement_docx.py`
  - Builds the integrated supplemental DOCX.
- `build_manuscript_package.py`
  - Builds the manuscript-development package.
- `check_manuscript_package.py`
  - Checks the manuscript-development package.

## Maintenance note

If final scripts change later, update the source file first, then refresh the
copy in `final_code/` and update this manifest.
