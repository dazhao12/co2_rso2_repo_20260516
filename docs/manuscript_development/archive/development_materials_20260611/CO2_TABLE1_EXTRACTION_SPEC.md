# CO2-rSO2 Table 1 and Table 2 Extraction Spec

Status: draft extraction plan. Do not run high-volume data extraction on the login node.

## Purpose

Generate manuscript-ready baseline and intraoperative characteristics for the final CO2-rSO2 analytic cohort, using the prior MAP/CI manuscript table structure as the style template but the current CO2 cohort as the data source.

## Current evidence

The current local repository contains CO2 model outputs and supplemental eTables, but the scripts that build patient-level analytic pools point to HPC project data:

- CO2 local mirror: `E:\BaiduSyncdisk\desktop_5_15\01_科研项目\GAM_CO2_SctO2_4_19_2026\co2_rso2_repo_20260516`
- HPC CO2 repo path: `/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516`
- Source legacy working path referenced by scripts: `/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025`
- Environment: `source /N/project/waveform_mortality/ZhaoZhang/timesfm311/bin/activate`

The relevant CO2 model scripts define patient-level covariates:

- Continuous covariates: `Age`, `BMI`, `Cardiac_index`, `Mean_blood_pressure`, `Hb`
- Categorical covariates: `SEX`, `Smoking_new`, `Drinking_status`, `Diabetes_status`, `Hypertension`, `Carotid_artery_disease`, `Statin_1`
- Subgroup/static variables: `Hypertension_140_90`, `Sex`, `Age`
- Time-varying/intraoperative variables used in CO2 outputs: `ET_CO2`, `FiO2_new`, `TEMP`, `MAP`, `SV`, `HR`, `CI`

## Proposed manuscript tables

### Table 1. Baseline patient characteristics

Rows should mirror the prior MAP/CI baseline eTable where possible:

- N patients by channel/cohort
- Age
- Sex
- Height
- Weight
- BMI
- Beta blocker
- ACEI
- Calcium channel blocker
- Isosorbide mononitrate
- Diuretic
- Antidiabetic agent
- Angiotensin receptor blocker
- Statin use
- Smoking status
- Drinking status
- Diabetes categories if available
- Hypertension categories if available
- Arrhythmia
- Carotid artery stenosis or carotid artery disease
- Age-adjusted Charlson comorbidity index
- ASA physical status
- NYHA functional class
- MET score
- EuroSCORE
- MoCA score
- Baseline stroke volume
- Baseline systemic vascular resistance
- Baseline heart rate
- Baseline cardiac index
- Baseline systolic, diastolic, and mean arterial pressure
- Baseline tissue oxygenation by channel
- Hemoglobin
- Creatinine
- Troponin T
- CK-MB
- BNP
- Left ventricular ejection fraction
- Guided care group, if applicable to the parent trial design

If a variable is not present in the CO2 analytic source table, mark it as unavailable rather than silently dropping it.

### Table 2. Intraoperative management characteristics

The prior supplement's intraoperative management table included:

- Midazolam
- Propofol
- Sevoflurane
- Cisatracurium
- Sufentanil
- Noradrenaline
- Epinephrine
- Metaraminol
- Milrinone
- Nicardipine
- Urapidil
- Esmolol
- Dexmedetomidine
- Tranexamic acid
- Crystalloid
- Colloid
- Autologous blood
- Blood loss
- Urine output
- Lowest hemoglobin
- Highest lactate
- Highest glucose
- Surgery time
- Number of bypass grafts

Use this table if the CO2 cohort source has medication/management fields. Otherwise, keep these rows in a missing-variable audit and do not fabricate them from model covariates.

### Table 3 or Supplementary Table. Intraoperative physiologic characteristics

Rows should include CO2 analysis variables:

- Baseline cardiac index, if this is a preoperative/static variable in source data
- Baseline mean blood pressure, if this is a preoperative/static variable in source data
- EtCO2, patient-level mean
- EtCO2, timestamp-level median and IQR
- FiO2
- Temperature
- MAP
- Stroke volume
- Heart rate
- Cardiac index
- rSO2 by channel
- Observation count and patient count by channel

Suggested columns:

- Overall CO2-rSO2 analytic cohort
- Left SctO2
- Right SctO2
- SftO2

If channel-specific cohorts differ only minimally, include a single overall table plus a short footnote with channel-specific patient counts.

Suggested summaries:

- Continuous patient-level values: mean (SD) and median (IQR)
- Binary/categorical values: n (%)
- Timestamp-level values: median (IQR), with patient-level N and timestamp N clearly separated

## HPC execution guardrails

If no compute node or Slurm job is supplied, first check active jobs:

```bash
ssh -F "C:\Users\老铁666\.ssh\config" iu-quartz "squeue -u zz86 -o '%i %P %j %u %T %M %l %D %R'"
```

Run high-volume extraction only on a compute node or inside an active Slurm allocation. Preferred command pattern when a node is available:

```bash
ssh -F "C:\Users\老铁666\.ssh\config" -J iu-quartz zz86@<node> "cd /N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516 && source /N/project/waveform_mortality/ZhaoZhang/timesfm311/bin/activate && python <table1_script>.py"
```

## Implementation notes

Use the existing model-loading path rather than reimplementing cohort definitions. The local script `code/manuscript_tables/build_table1_2_co2_rso2.py` reuses functions and constants from the current CO2 model script, then collapses the analytic pool to one row per patient for baseline variables and summarizes timestamp-level variables separately.

Run from the HPC CO2 repo root on a compute node:

```bash
source /N/project/waveform_mortality/ZhaoZhang/timesfm311/bin/activate
python code/manuscript_tables/build_table1_2_co2_rso2.py
```

Required output files:

- `results/manuscript_tables/table1_2_co2_rso2_long.csv`
- `results/manuscript_tables/table1_2_co2_rso2_wide.csv`
- `results/manuscript_tables/table1_2_co2_rso2_flow_counts.csv`
- `results/manuscript_tables/table1_2_co2_rso2_available_columns.csv`
- `results/manuscript_tables/table1_2_co2_rso2.xlsx`

After these files exist, copy or pull them into the local mirror and update:

- `docs/manuscript_development/CO2_MANUSCRIPT_DRAFT_V1.md`
- `docs/manuscript_development/CO2_TABLES_AND_FIGURES_DRAFT.md`
- `docs/manuscript_development/generated_assets/`
