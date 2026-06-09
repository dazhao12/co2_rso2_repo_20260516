# CO2-rSO2 Submission Gap Checklist

This checklist separates what exists from what must be completed before a submission-ready manuscript can be claimed.

## Evidence already present

- High-frequency CO2-rSO2 analysis repository is organized.
- Supplemental eTables 3-8 exist as CSV and XLSX outputs.
- Figure A/B/C cross-variable outputs exist in PNG and PDF.
- Prior MAP/CI manuscript, Table 1, supplementary methods, and supplemental digital content provide a usable structural template.
- Current cross-variable effect table supports the main EtCO2 claim for three channels.

## Required before full manuscript submission

1. Channel naming and supplemental label consistency
   - Current files use `rSO2_Ch1`, `rSO2_Ch2`, and `rSO2_Ch3`.
   - Prior MAP/CI paper used left SctO2, right SctO2, and SftO2.
   - CO2 model/plot scripts label `rSO2_Ch3` as SftO2.
   - Earlier CO2 supplemental eTable 3-5 code/results labeled `rSO2_Ch3` as `Frontal SctO2 cohort`; the local manuscript package now treats this as a label bug and has corrected the local script, CSV outputs, and formatted workbook titles.
   - Current CO2 supplemental eTable 6-8 code/results label `rSO2_Ch3` as `SftO2 cohort` / `SftO2 model`.
   - The manuscript should use SftO2 for `rSO2_Ch3`.
   - See `CO2_CHANNEL_NAMING_AUDIT.md`.

2. Table 1 and Table 2 generation
   - Complete for the current manuscript-development package.
   - Source files are under `results/manuscript_tables/`.
   - Main Table 1 assets are under `docs/manuscript_development/generated_assets/table1_cohort_characteristics.*`.
   - Full supplementary eTable 1/2 assets are under `docs/manuscript_development/generated_assets/supplementary_etable1_2_cohort_characteristics.*`.
   - The source-coded `SEX=1` label is now reported as `Male, n (%)` in manuscript-facing generated assets.
   - See `CO2_SEX_LABEL_AUDIT.md`.

3. Main EtCO2 slope or contrast table
   - Complete as a manuscript-development asset.
   - Current file: `docs/manuscript_development/generated_assets/table2_clinical_step_contrasts.xlsx`.
   - It reports the 5 mmHg EtCO2 clinical-step contrast by channel with model-based uncertainty intervals from archived prediction matrices.
   - Optional: quantile-zone slopes from `crossvar_slope_bins.csv`.

4. Sensitivity analysis decision
   - `code/analysis_bundle/output/tables/etco2_sensitivity_5model_summary.csv` currently marks all planned sensitivity result directories as `missing_result_dir`.
   - Current manuscript-development decision: do not report sensitivity analyses and do not make a robustness claim.
   - See `CO2_SENSITIVITY_DECISION.md`.

5. All-intraop comparison decision
   - `run_checks_all_intraop_n10000_mapci_te.csv` reports 27 expected rows, 27 rows present, and 18 missing values.
   - Current complete comparisons are EtCO2, FiO2, and TEMP only.
   - Do not use empty MAP/SV/HR/RRtotal/TVinsp/Pmean panels in the main paper.

6. Figure cleanup
   - Main manuscript-development figures now exist for cohort flow, adjusted EtCO2-rSO2 curves, clinical-step contrasts, and EtCO2 local slopes.
   - Generated assets are under `docs/manuscript_development/generated_assets/`.
   - Final submission figures still need target-journal sizing, panel labels, font checks, and journal-specific source-data packaging.

7. Methods provenance
   - The manuscript must cite current scripts and output paths.
   - The final methods should state bootstrap design, sampling unit, sample size per bootstrap, number of repeats, smoothing parameters, and covariate set.

8. Outcome scope
   - If no postoperative outcome is added, the paper is a physiology/methods manuscript.
   - If outcome is added, define endpoint, missingness, model, and causal limits before drafting claims.

## Recommended next work order

1. Fill `CO2_AUTHOR_SUBMISSION_STATEMENTS_TEMPLATE.md` with confirmed author-side information.
2. Decide whether to run the planned 5-model sensitivity package before journal submission.
3. Complete target-journal figure formatting and source-data packaging.
4. Complete optional rendered DOCX page-level visual QA.
