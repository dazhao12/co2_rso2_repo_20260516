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
   - Earlier CO2 supplemental eTable 3-5 code/results labeled `rSO2_Ch3` as `Frontal SctO2 cohort`; the local manuscript package now treats this as a label bug and has corrected the local script/outputs.
   - Current CO2 supplemental eTable 6-8 code/results label `rSO2_Ch3` as `SftO2 cohort` / `SftO2 model`.
   - The manuscript should use SftO2 for `rSO2_Ch3`, and eTables 3-5 should be regenerated or corrected to match.
   - See `CO2_CHANNEL_NAMING_AUDIT.md`.

2. Table 1 and Table 2 generation
   - Need baseline patient characteristics.
   - Need intraoperative management characteristics.
   - These should mirror the prior MAP/CI table format but use the CO2 analytic cohort.
   - See `CO2_TABLE1_EXTRACTION_SPEC.md` for the current variable list and HPC run guardrails.

3. Main EtCO2 slope or contrast table
   - Need a manuscript-ready table for EtCO2 increments or zones.
   - Candidate: 5 mmHg clinical-step contrast by channel with bootstrap CI.
   - Optional: quantile-zone slopes from `crossvar_slope_bins.csv`.

4. Sensitivity analysis decision
   - `code/analysis_bundle/output/tables/etco2_sensitivity_5model_summary.csv` currently marks all planned sensitivity result directories as `missing_result_dir`.
   - Either run these analyses or remove the planned sensitivity claims.

5. All-intraop comparison decision
   - `run_checks_all_intraop_n10000_mapci_te.csv` reports 27 expected rows, 27 rows present, and 18 missing values.
   - Current complete comparisons are EtCO2, FiO2, and TEMP only.
   - Do not use empty MAP/SV/HR/RRtotal/TVinsp/Pmean panels in the main paper.

6. Figure cleanup
   - Figure A is usable as a concept but should remove variables with missing values if used in the main text.
   - Figure B and C should be remade as EtCO2/FiO2/TEMP-only or EtCO2-focused figures.
   - Main figures need publication sizing, panel labels, readable fonts, and colorblind-safe colors.

7. Methods provenance
   - The manuscript must cite current scripts and output paths.
   - The final methods should state bootstrap design, sampling unit, sample size per bootstrap, number of repeats, smoothing parameters, and covariate set.

8. Outcome scope
   - If no postoperative outcome is added, the paper is a physiology/methods manuscript.
   - If outcome is added, define endpoint, missingness, model, and causal limits before drafting claims.

## Recommended next work order

1. Pull the corrected supplemental eTable 3-5 labels through to the HPC repo and regenerated submission supplement.
2. Generate Table 1/2 from the CO2 analytic cohort on a compute node or Slurm job.
3. Generate EtCO2 5 mmHg contrast table with bootstrap CIs.
4. Remake main figures as EtCO2-focused.
5. Decide whether to rerun 5-model sensitivity.
6. Convert the draft skeleton into a full manuscript.
