# CO2-rSO2 Source Data Package Index

Date checked: 2026-06-09

Status: manuscript-development source-data package. These files support the current main figures, main tables, and key supplementary table assets. Final submission may require renaming, journal-specific source-data templates, or separate upload files, but the current data sources are organized and traceable.

## Generation

Run from the repository root:

```powershell
& 'C:\Users\12080\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' docs\manuscript_development\generate_manuscript_assets.py
```

The script reads existing repository outputs and writes source-data files under:

```text
docs/manuscript_development/generated_assets/
```

No model fitting or large-data training is performed by this packaging script.

## Main Figure Source Data

| Display item | Source-data file | Rows | Source in repository | Notes |
| --- | --- | ---: | --- | --- |
| Figure 1. Cohort assembly by tissue oxygenation channel | `source_data_figure1_cohort_flow.csv` | 12 | `results/manuscript_tables/table1_2_co2_rso2_flow_counts.csv` | Channel-specific row and patient counts across filtering stages |
| Figure 2. Adjusted EtCO2-rSO2 response curves | `source_data_figure2_etco2_curves.csv` | 540 | `results/model_runs/.../ET_CO2/*_slice_median_curve_boot.csv` | Adjusted mean and bootstrap interval curves for left SctO2, right SctO2, and SftO2 |
| Figure 3. Clinical-step contrasts | `source_data_figure3_clinical_step.csv` | 9 | `code/analysis_bundle/output/tables/crossvar_effect_summary.csv` | EtCO2, FiO2, and temperature clinical-step contrasts with 95% CI |
| Supplementary Figure 1. EtCO2 local slopes | `source_data_figure4_etco2_local_slopes.csv` | 18 | `docs/manuscript_development/generated_assets/source_data_figure2_etco2_curves.csv` | EtCO2-only descriptive local slopes by 20-50 mmHg bins and channel |

## Main Table and Supplement Source Data

| Display item | Source-data file | Rows | Source in repository | Notes |
| --- | --- | ---: | --- | --- |
| Main Table 1. Cohort characteristics | `table1_cohort_characteristics.csv` | 19 | `results/manuscript_tables/table1_2_co2_rso2_wide.csv`; `table1_2_co2_rso2_flow_counts.csv` | Manuscript-facing concise cohort table |
| Main Table 2. Clinical-step contrasts | `table2_clinical_step_contrasts.csv` | 9 | `code/analysis_bundle/output/tables/crossvar_effect_summary.csv` | Same data as Figure 3, formatted as a table |
| Supplementary eTable 1/2. Baseline and intraoperative characteristics | `supplementary_etable1_2_cohort_characteristics_long.csv` | 159 | `results/manuscript_tables/table1_2_co2_rso2_long.csv` | Long-format supplementary table source |
| Supplementary model diagnostics | `supplementary_model_diagnostics.csv` | 3 | `results/supplemental_etables/supplemental_etable6_model_performance_co2_rso2.csv`; `supplemental_etable7_nonparametric_terms_co2_rso2.csv` | Model performance and EtCO2 smooth-term summary |

## File Checks

| File | Rows | Size, bytes | SHA-256 prefix |
| --- | ---: | ---: | --- |
| `source_data_figure1_cohort_flow.csv` | 12 | 592 | `4bc1308b5272` |
| `source_data_figure2_etco2_curves.csv` | 540 | 67,756 | `735befbfe5f7` |
| `source_data_figure3_clinical_step.csv` | 9 | 545 | `e40da8fce52f` |
| `source_data_figure4_etco2_local_slopes.csv` | 18 | 853 | `e29247ab28b9` |
| `table1_cohort_characteristics.csv` | 19 | 1,228 | `67006d7521aa` |
| `table2_clinical_step_contrasts.csv` | 9 | 545 | `e40da8fce52f` |
| `supplementary_etable1_2_cohort_characteristics_long.csv` | 159 | 12,238 | `281b24e6e590` |
| `supplementary_model_diagnostics.csv` | 3 | 261 | `0463f2538917` |

## Submission Notes

- Patient-level source data are not included in this package.
- Figure source data are aggregate or model-derived outputs suitable for manuscript development and journal source-data preparation.
- `source_data_figure3_clinical_step.csv` and `table2_clinical_step_contrasts.csv` are intentionally identical because Figure 3 visualizes Main Table 2.
- Before final submission, rename files according to the target journal's source-data convention and update this index with the final commit hash.
