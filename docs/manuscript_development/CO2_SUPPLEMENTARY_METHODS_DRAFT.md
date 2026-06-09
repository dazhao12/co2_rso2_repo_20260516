# Supplementary Methods: CO2-rSO2 Analysis

Draft status: methods-ready skeleton based on current repository scripts and the prior MAP/CI supplementary methods. Author-side regulatory details and final source-data paths still need confirmation before submission.

## Study Design and Data Source

This study is a secondary analysis of prospectively recorded intraoperative physiologic data from patients undergoing off-pump coronary artery bypass surgery. The parent study and institutional setting should match the final CO2 cohort assembly. The current main manuscript uses the prior MAP/CI manuscript language describing the parent dataset as the Bottomline-CS randomized, assessor-blinded, single-center trial at Tianjin Chest Hospital, registered as `NCT04896736`, with recruitment from 8 June 2021 to 27 December 2023. This text must be checked against the final CO2 cohort source before submission.

High-frequency intraoperative time-series data were synchronized across monitors. Each timestamp represented a set of concurrent measurements for EtCO2, tissue oxygenation, and available intraoperative covariates. Patient-level baseline covariates were merged into the time-series analytic table using available stay or patient identifiers.

## Tissue Oxygenation Outcomes

Three tissue oxygenation outcomes were analyzed separately:

- Left cerebral tissue oxygen saturation (`rSO2_Ch1`; left SctO2)
- Right cerebral tissue oxygen saturation (`rSO2_Ch2`; right SctO2)
- Forearm tissue oxygen saturation (`rSO2_Ch3`; SftO2)

The third NIRS channel was analyzed as SftO2 according to the channel mapping used in the primary modeling and plotting scripts. Earlier development outputs used a conflicting third-channel label; all manuscript-facing tables should use SftO2 for `rSO2_Ch3`.

## Primary Exposure and Covariates

The primary exposure was end-tidal carbon dioxide (`ET_CO2`, mmHg). EtCO2 was treated as a continuously available clinical marker of ventilation-perfusion and perfusion physiology, not as a direct substitute for PaCO2. The primary reported model adjusted for:

- FiO2 (`FiO2_new`)
- Temperature (`TEMP`)
- Mean arterial pressure (`MAP`)
- Cardiac index (`CI`)
- Patient-level continuous covariates: age, body mass index, baseline cardiac index, baseline mean blood pressure, hemoglobin, and baseline tissue oxygenation covariates not overlapping with the modeled outcome
- Patient-level categorical covariates: sex, smoking status, drinking status, diabetes status, hypertension, carotid artery disease, and statin use

The current archived clinical-step result set is labeled `map_ci_te`. Additional ventilatory variables, including total respiratory rate (`RRtotal`), inspired tidal volume (`TVinsp`), and mean airway pressure (`Pmean`), were present in some project scripts or planned sensitivity specifications but are not part of the current main reported Table 2 asset unless the final model is regenerated.

Baseline tissue oxygenation covariates were excluded when they represented the same tissue bed as the outcome or another cerebral channel likely to create direct outcome leakage. The current exclusion map was:

- Left SctO2 model: excludes right SctO2 and SftO2 baseline covariates
- Right SctO2 model: excludes left SctO2 and SftO2 baseline covariates
- SftO2 model: excludes left and right SctO2 baseline covariates

## Cohort Construction and Outlier Handling

Outcome-specific cohorts were built for each tissue oxygenation channel. Timestamps were first required to have nonmissing EtCO2 and the corresponding tissue oxygenation value. Cohort-defining screens then applied the primary analytic EtCO2 range and tissue oxygenation range. The current strict analytic ranges were:

- EtCO2: greater than 20 mmHg and less than 50 mmHg
- Tissue oxygenation: greater than 25% and less than 95%

Additional physiologic clipping was applied to nuisance covariates before imputation. The current reported missingness and imputation table covers TEMP, FiO2, MAP, SV, HR, and CI, although the primary reported model uses MAP and CI as its hemodynamic adjustment variables:

- Temperature: 34.0 to 37.5 C
- FiO2: 30 to 100%
- MAP: 20 to 160 mmHg
- SV: 20 to 180 mL
- HR: 35 to 160 beats/min
- CI: 0.5 to 8.0 L/min/m2

Values outside these covariate ranges were set to missing for covariate processing rather than used directly in model fitting.

## Missing Data Handling

After physiologic clipping, missing time-varying covariates were imputed in the following order: forward fill within patient after ordering by intraoperative time, patient-specific median imputation for remaining missing values, and global median imputation for residual missingness. EtCO2 and the modeled rSO2 outcome were not imputed for cohort entry. Missingness and imputation summaries are reported in the supplemental eTables.

Patient-level covariates were read from the static baseline tables used by the model scripts. Variables not available in the CO2 analytic source should be reported as unavailable rather than reconstructed from unrelated sources.

## Generalized Additive Models

Separate generalized additive models were fit for left SctO2, right SctO2, and SftO2. The primary reported model adjusted for hemodynamic status using MAP and cardiac index, in addition to smooth terms for EtCO2, FiO2, temperature, and prespecified patient-level covariates. Smooth terms used penalized spline bases as implemented in the current Python modeling scripts.

The current model diagnostics reported:

| Outcome | Sampled rows | Model features | Effective DOF | Deviance explained | EtCO2 EDF | EtCO2 p value |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Left SctO2 | 100,000 | 17 | 51.14 | 0.232 | 8.42 | <0.001 |
| Right SctO2 | 100,000 | 17 | 51.21 | 0.219 | 8.43 | <0.001 |
| SftO2 | 100,000 | 18 | 52.22 | 0.154 | 8.45 | <0.001 |

These statistics describe model fit and nonlinear terms. They should not be interpreted as causal evidence.

## Bootstrap and Clinical-Step Contrasts

Clinical-step contrasts were estimated from the 10,000-row `map_ci_te` analysis run, and 95% confidence intervals were derived from the archived bootstrap prediction matrices. Because the current bootstrap was implemented on sampled timestamp-level prediction curves, these intervals should be interpreted as model-based uncertainty intervals rather than fully patient-clustered inferential intervals unless a patient-level bootstrap is finalized. The current manuscript reports clinical-step contrasts for:

- EtCO2: +5 mmHg
- FiO2: +10 percentage points
- Temperature: +0.5 C

The primary contrast was the adjusted difference in tissue oxygenation associated with a 5 mmHg higher EtCO2. Current estimates were:

| Outcome | EtCO2 contrast | Adjusted difference | 95% CI |
| --- | --- | ---: | --- |
| Left SctO2 | +5 mmHg | +2.89 percentage points | +2.41 to +3.33 |
| Right SctO2 | +5 mmHg | +2.98 percentage points | +2.64 to +3.28 |
| SftO2 | +5 mmHg | +0.92 percentage points | +0.68 to +1.16 |

Before submission, the final supplement should state the bootstrap sampling unit, whether replacement was used at the row or patient level, the number of bootstrap repetitions, and the sample size per repetition. If patient-level clustering was not preserved, the manuscript should keep the current wording of model-based uncertainty rather than cluster-robust inference.

## Supplementary Tables

The current supplemental table package should include:

- eTable 1/2: CO2 cohort baseline and intraoperative characteristics, generated by `code/manuscript_tables/build_table1_2_co2_rso2.py`
- eTable 3: timestamp-level artifact and outlier summaries for EtCO2 and tissue oxygenation
- eTable 4: missingness and imputation for time-varying intraoperative covariates
- eTable 5: patient-level summaries of EtCO2 and tissue oxygenation
- eTable 6: model performance and goodness-of-fit statistics
- eTable 7: nonparametric smooth-term estimates
- eTable 8: parametric covariate estimates

The generated Table 1/2 files were produced on HPC under:

```text
/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516_master_b5271a5/results/manuscript_tables
```

The output set includes `table1_2_co2_rso2.xlsx`, `table1_2_co2_rso2_available_columns.csv`, `table1_2_co2_rso2_flow_counts.csv`, `table1_2_co2_rso2_long.csv`, and `table1_2_co2_rso2_wide.csv`. These files have been pulled into the local mirror under `results/manuscript_tables/`. The run log is saved in `CO2_TABLE1_2_HPC_RUN_LOG.md`.

## Sensitivity Analyses

The repository includes planned 5-model sensitivity summaries, but the current analysis bundle reports missing result directories for all planned sensitivity variants. Until these analyses are completed, the manuscript should not claim robustness across alternative model specifications.

Recommended sensitivity checks before submission:

- Alternative EtCO2 analytic ranges
- Alternative tissue oxygenation inclusion ranges
- Patient-level or case-level bootstrap if not already used
- Models with broader intraoperative covariate adjustment
- Lagged EtCO2 analyses, if clinically justified
- Subgroup analyses by age, sex, and preoperative hypertension status

## Statistical Software and Reproducibility

Analyses were performed in Python using scripts archived in the CO2-rSO2 repository. The final submission should report the repository commit hash, the exact table/figure generation scripts, and the availability conditions for patient-level data and code.
