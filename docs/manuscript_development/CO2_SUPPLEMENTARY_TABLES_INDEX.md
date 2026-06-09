# CO2 Supplementary Tables Index

Draft status: source-backed index for the supplement. This is not a formatted journal supplement yet.

## Generated or available tables

| Table | Current source | Status | Notes |
| --- | --- | --- | --- |
| eTable 1/2. Baseline and intraoperative characteristics | `docs/manuscript_development/generated_assets/supplementary_etable1_2_cohort_characteristics.xlsx` and `supplementary_etable1_2_cohort_characteristics_long.csv`; source files under `results/manuscript_tables/` | available locally | Generated from the local Table 1/2 workbook; includes wide, long, and flow-count sheets |
| eTable 3. Timestamp-level artifact/outlier summaries | `results/supplemental_etables/supplemental_etable3_artifact_co2_rso2.csv` and `Supplemental_eTables3_5_CO2_rSO2.xlsx` | available locally | `rSO2_Ch3` is adjudicated as SftO2 in manuscript-facing outputs; workbook title uses forearm tissue oxygenation |
| eTable 4. Missingness and imputation of intraoperative covariates | `results/supplemental_etables/supplemental_etable4_missingness_imputation_other_intraop.csv` and `Supplemental_eTables3_5_CO2_rSO2.xlsx` | available locally | Covers TEMP, FiO2, MAP, SV, HR, and CI |
| eTable 5. Patient-level EtCO2 and tissue oxygenation summary | `results/supplemental_etables/supplemental_etable5_patient_level_co2_rso2.csv` and `Supplemental_eTables3_5_CO2_rSO2.xlsx` | available locally | Reports patients, observations, mean EtCO2, and tissue oxygenation |
| eTable 6. Model performance | `results/supplemental_etables/supplemental_etable6_model_performance_co2_rso2.csv` and `Supplemental_eTables6_8_CO2_rSO2.xlsx` | available locally | Includes sampled rows, features, EDOF, deviance explained, RMSE |
| eTable 7. Nonparametric terms | `results/supplemental_etables/supplemental_etable7_nonparametric_terms_co2_rso2.csv` and `Supplemental_eTables6_8_CO2_rSO2.xlsx` | available locally | Includes EtCO2 EDF and p values |
| eTable 8. Parametric terms | `results/supplemental_etables/supplemental_etable8_parametric_terms_co2_rso2.csv` and `Supplemental_eTables6_8_CO2_rSO2.xlsx` | available locally | Includes categorical patient-level covariate terms |

## Main manuscript table candidates

| Display item | Source | Recommendation |
| --- | --- | --- |
| Main Table 1 | `docs/manuscript_development/generated_assets/table1_cohort_characteristics.xlsx` | Use concise patient/cohort characteristics in main manuscript; full baseline/intraoperative rows remain in supplementary eTable 1/2 |
| Main Table 2 | `docs/manuscript_development/generated_assets/table2_clinical_step_contrasts.xlsx` | Use as a compact clinical-step contrast table |
| Supplementary model diagnostics | `docs/manuscript_development/generated_assets/supplementary_model_diagnostics.xlsx` | Keep in supplement unless target journal wants model diagnostics in Methods |

## Formatting TODO

- Format all abbreviations consistently: EtCO2, FiO2, SctO2, SftO2, MAP, CI, SV, HR.
- Replace repository paths with journal-facing supplement captions before submission.
- No sensitivity-analysis table is included in the current evidence package because the planned result directories are unavailable; see `CO2_SENSITIVITY_DECISION.md`.
- Sex is reported as `Male, n (%)` in manuscript-facing table assets; see `CO2_SEX_LABEL_AUDIT.md`.
