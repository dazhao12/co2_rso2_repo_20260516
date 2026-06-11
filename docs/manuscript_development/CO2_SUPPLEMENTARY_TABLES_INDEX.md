# CO2 Supplementary Tables Index

Draft status: journal-facing supplement index for coauthor review. The table contents are source-backed, but final journal captions, workbook tab names, and file naming should be adjusted after the target journal is chosen.

## Supplementary Table Plan

| Item | Purpose | Key columns or contents | Status |
| --- | --- | --- | --- |
| eTable 1. Cohort flow and signal availability | Documents patient and timestamp retention for each tissue oxygenation channel. | Filtering stage, tissue oxygenation channel, timestamp rows, patient counts. | Available locally |
| eTable 2. Baseline and intraoperative characteristics | Provides the expanded cohort description behind main Table 1. | Cohort, characteristic, value, missing count; wide and long formats are available. | Available locally |
| eTable 3. Timestamp-level artifact and outlier exclusions | Describes implausible EtCO2 and tissue oxygenation values removed before modeling. | Variable, channel, exclusion rule, excluded timestamps, retained timestamps. | Available locally |
| eTable 4. Missingness and imputation of time-varying covariates | Documents preprocessing for intraoperative covariates used in adjustment. | Variable, physiologic range, missing before imputation, imputation step, missing after imputation. | Available locally |
| eTable 5. Patient-level EtCO2 and tissue oxygenation summaries | Summarizes exposure and outcome distributions at the patient level. | Tissue oxygenation channel, patients, observations, EtCO2 mean, rSO2 mean. | Available locally |
| eTable 6. Model performance | Reports fit and complexity of the channel-specific generalized additive models. | Outcome, sampled rows, model features, effective degrees of freedom, deviance explained, RMSE. | Available locally |
| eTable 7. Nonparametric smooth terms | Supports the nonlinear EtCO2-rSO2 claim and other smooth covariate adjustments. | Outcome, smooth term, effective degrees of freedom, test statistic, p value. | Available locally |
| eTable 8. Parametric covariate terms | Documents patient-level covariate terms included in the models. | Outcome, covariate, estimate, standard error or interval, p value. | Available locally |
| eTable 9. Sensitivity analyses | Reserved for planned 5-model EtCO2 sensitivity analyses. | Outcome, model variant, EtCO2 contrast, 95% CI, status. | Not reported; planned result directories are missing |

## Main Display Items Linked to the Supplement

| Main display | Supplementary support | Review asset |
| --- | --- | --- |
| Table 1. Cohort characteristics | eTables 1 and 2 | Main Table 1 XLSX and CSV |
| Table 2. Adjusted clinical-step contrasts | eTables 6 and 7 | Main Table 2 XLSX and CSV |
| Figure 1. Cohort assembly | eTable 1 | Figure 1 source CSV |
| Figure 2. Adjusted EtCO2-rSO2 curves | eTables 6 and 7 | Figure 2 source CSV |
| Figure 3. Clinical-step contrasts | Table 2 | Figure 3 source CSV |
| Supplementary Figure 1. EtCO2 local slopes | eTable 7 | Local-slope source CSV |

## Source Traceability

- eTables 1 and 2: `docs/manuscript_development/generated_assets/supplementary_etable1_2_cohort_characteristics.xlsx`; `docs/manuscript_development/generated_assets/supplementary_etable1_2_cohort_characteristics_long.csv`; source files under `results/manuscript_tables/`.
- eTables 3-5: `results/supplemental_etables/Supplemental_eTables3_5_CO2_rSO2.xlsx` and corresponding CSV files in `results/supplemental_etables/`.
- eTables 6-8: `results/supplemental_etables/Supplemental_eTables6_8_CO2_rSO2.xlsx` and corresponding CSV files in `results/supplemental_etables/`.
- Main manuscript tables and source data: `docs/manuscript_development/generated_assets/`.

## Terminology and Formatting Notes

- Use EtCO2 for end-tidal carbon dioxide.
- Use SctO2 for cerebral tissue oxygen saturation and SftO2 for forearm tissue oxygen saturation.
- Report `rSO2_Ch1` as left SctO2, `rSO2_Ch2` as right SctO2, and `rSO2_Ch3` as SftO2.
- Sex is reported as `Male, n (%)` in manuscript-facing assets; see `CO2_SEX_LABEL_AUDIT.md`.
- No sensitivity-analysis table is included in the current evidence package because all planned sensitivity result directories are marked as `missing_result_dir`; see `CO2_SENSITIVITY_DECISION.md`.
