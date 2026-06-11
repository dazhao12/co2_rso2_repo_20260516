# CO2-rSO2 Channel Naming Audit

Status: adjudicated and locally synchronized for manuscript drafting.

## Question

The current CO2 manuscript must define the clinical identity of `rSO2_Ch3` consistently. The repository initially contained conflicting labels for the same outcome channel.

## Evidence found in current repository

### Earlier files that labelled `rSO2_Ch3` as frontal SctO2

- `code/supplemental_etables/build_supplemental_etables_3_5_co2_rso2.py`
  - Earlier local versions used `Frontal SctO2 cohort` for `rSO2_Ch3`.
- `results/supplemental_etables/supplemental_etable3_artifact_co2_rso2.csv`
  - Earlier local versions used `Frontal SctO2 cohort` for `rSO2_Ch3`.
- `results/supplemental_etables/supplemental_etable4_missingness_imputation_other_intraop.csv`
  - Earlier local versions used `Frontal SctO2 cohort` for `rSO2_Ch3`.
- `results/supplemental_etables/supplemental_etable5_patient_level_co2_rso2.csv`
  - Earlier local versions contained `Frontal SctO2 cohort,rSO2_Ch3,1789,...,75.6 (5.0),2.8 (1.4),20068989`.

### Files labeling `rSO2_Ch3` as SftO2

- `code/supplemental_etables/build_supplemental_etables_3_5_co2_rso2.py`
  - Current local version uses `SftO2 cohort` for `rSO2_Ch3`.
  - Current workbook titles refer to left cerebral, right cerebral, and forearm tissue oxygenation cohorts.
- `results/supplemental_etables/supplemental_etable3_artifact_co2_rso2.csv`
  - Rows for `rSO2_Ch3` use `SftO2 cohort`.
- `results/supplemental_etables/supplemental_etable4_missingness_imputation_other_intraop.csv`
  - Rows for `rSO2_Ch3` use `SftO2 cohort`.
- `results/supplemental_etables/supplemental_etable5_patient_level_co2_rso2.csv`
  - Rows for `rSO2_Ch3` use `SftO2 cohort`.
- `results/supplemental_etables/Supplemental_eTables3_5_CO2_rSO2.xlsx`
  - Sheet headers use `SftO2 cohort`; sheet titles now refer to forearm tissue oxygenation cohorts.
- `code/supplemental_etables/build_supplemental_etables_6_8_co2_rso2.py`
  - `rSO2_Ch3`: `SftO2 cohort`
  - `rSO2_Ch3`: `SftO2 model`
- `results/supplemental_etables/supplemental_etable6_model_performance_co2_rso2.csv`
  - Rows for `rSO2_Ch3` use `SftO2 cohort` and `SftO2 model`.
- `results/supplemental_etables/supplemental_etable7_nonparametric_terms_co2_rso2.csv`
  - Rows for `rSO2_Ch3` use `SftO2 cohort` and `SftO2 model`.
- `results/supplemental_etables/supplemental_etable8_parametric_terms_co2_rso2.csv`
  - Rows for `rSO2_Ch3` use `SftO2 cohort` and `SftO2 model`.

## Evidence from prior MAP/CI manuscript files

The prior MAP/CI manuscript framework consistently defines the third tissue bed as forearm tissue oxygen saturation:

- `MAP_CI_Tissue O2_Manuscript_Clean_R4_5_21_2026.docx`
  - Defines `SctO2 = cerebral tissue oxygen saturation`.
  - Defines `SftO2 = forearm tissue oxygen saturation`.
  - Describes outcomes as left cerebral tissue oxygen saturation, right SctO2, and forearm tissue oxygen saturation.
- `MAP_CI_Tissue O2_Supplemental Digital Content_R4_5_21_2026.docx`
  - eTable titles repeatedly refer to left cerebral, right cerebral, and forearm tissue oxygen saturation cohorts.
- `MAP_CI_Tissue O2_Supplementary methods_R2_3_11_2026.docx`
  - States that left cerebral tissue oxygen saturation, right SctO2, and forearm tissue oxygen saturation were studied and modeled separately.
- `MAP_CI_Tissue O2_Table 1_R3_5_5_2026.docx`
  - Defines `SftO2` as forearm tissue oxygen saturation.

This prior-manuscript evidence supports the older MAP/CI framework using a forearm third channel. It does not by itself prove that the CO2 `rSO2_Ch3` source mapping is identical, because the current CO2 files contain conflicting labels.

## Adjudication

Use the following manuscript labels:

- `rSO2_Ch1`: left cerebral tissue oxygen saturation (`Left SctO2`)
- `rSO2_Ch2`: right cerebral tissue oxygen saturation (`Right SctO2`)
- `rSO2_Ch3`: forearm tissue oxygen saturation (`SftO2`)

Rationale: the main CO2 Python model scripts, multiple CO2 R plotting scripts, and the prior MAP/CI manuscript all map `rSO2_Ch3` to `SftO2`. The earlier `Frontal SctO2 cohort` label was limited to the supplemental eTable 3-5 generation path and is treated as a label bug.

## Current resolution

The local manuscript package now uses the same channel map in manuscript prose, generated Table 1 assets, supplemental eTable 3-8 CSV files, and the formatted supplemental eTable 3-5/6-8 workbooks:

| Analysis variable | Final clinical label | Evidence source |
| --- | --- | --- |
| `rSO2_Ch1` | Left SctO2 | CO2 model/plot scripts and supplemental outputs |
| `rSO2_Ch2` | Right SctO2 | CO2 model/plot scripts and supplemental outputs |
| `rSO2_Ch3` | SftO2 | CO2 model/plot scripts, prior MAP/CI manuscript, and supplemental outputs |

If an external raw monitor/export data dictionary later contradicts this mapping, update this audit, the supplemental eTable scripts, and all generated manuscript-facing outputs before submission.
