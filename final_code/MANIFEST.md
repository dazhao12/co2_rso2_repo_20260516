# Final Code

This folder keeps only the minimal final code entry points. The full working
copies remain under `code/` and `docs/`.

## Files

- `01_main_gam_analysis.py`
  - Main analysis script. This is the no-suffix script, not the
    patient-resampling variant.
- `02_submit_main_overall_mapci_te.sbatch`
  - Main HPC wrapper for the overall MAP/CI tensor model.
- `03_slice_ppt_figures.R`
  - Final slice-curve PPT figure script.
- `04_build_table1_2.py`
  - Main Table 1/2 builder.
- `05_build_supplemental_etables_3_5.py`
  - Supplemental eTables 3-5 builder.
- `06_build_supplemental_etables_6_8.py`
  - Supplemental eTables 6-8 builder.
- `07_generate_manuscript_assets.py`
  - Generates manuscript-facing figures, tables, and source data.
- `08_build_manuscript_docx.py`
  - Builds the main manuscript DOCX.
- `09_build_supplement_docx.py`
  - Builds the integrated supplemental DOCX.
- `10_reference_mapci_tissue_o2_figures.R`
  - Reference MAP/CI tissue-oxygen figure script from the prior analysis.
  - Kept only to inspect styling, especially the transparent slope bars:
    `SLOPE_BIN_ALPHA <- 0.7` and
    `geom_col(..., alpha = SLOPE_BIN_ALPHA)`.
