# CO2-rSO2 Tables and Figures Draft

Date: 2026-06-08

This file translates current repository outputs into manuscript display items. It should be revised after channel naming, Table 1 generation, and sensitivity analyses are finalized.

Generated manuscript assets are stored under `generated_assets/`.

## Main Table 1: cohort characteristics

Status: not yet generated in the current CO2 repository.

Recommended source and structure:

- Use the prior MAP/CI Table 1 and Supplemental Digital Content as the format template.
- Generate from the final CO2 analytic cohort.
- Include baseline demographics, comorbidities, operative variables, and intraoperative management variables.
- Report missing counts in the rightmost column, following the prior manuscript style.

Do not copy MAP/CI values into the CO2 paper unless the analytic cohort is confirmed identical.

## Main Table 2: clinical-step adjusted contrasts

Candidate table title:

Adjusted changes in tissue oxygenation associated with clinically interpretable intraoperative exposure increments

| Outcome channel | Exposure | Clinical increment | Adjusted rSO2 difference, percentage points | 95% CI | Interpretation |
|---|---:|---:|---:|---:|---|
| rSO2_Ch1 | EtCO2 | +5 mmHg | +2.89 | +2.41 to +3.33 | strongest positive association |
| rSO2_Ch2 | EtCO2 | +5 mmHg | +2.98 | +2.64 to +3.28 | strongest positive association |
| SftO2 | EtCO2 | +5 mmHg | +0.92 | +0.68 to +1.16 | smaller positive association |
| rSO2_Ch1 | FiO2 | +10 percentage points | -0.18 | -0.49 to +0.12 | weak/inconsistent |
| rSO2_Ch2 | FiO2 | +10 percentage points | -0.05 | -0.46 to +0.37 | weak/inconsistent |
| SftO2 | FiO2 | +10 percentage points | +0.30 | +0.11 to +0.46 | small positive association |
| rSO2_Ch1 | Temperature | +0.5 C | +0.10 | -0.16 to +0.35 | weak/inconsistent |
| rSO2_Ch2 | Temperature | +0.5 C | +0.55 | +0.25 to +0.87 | modest positive association |
| SftO2 | Temperature | +0.5 C | +0.15 | -0.03 to +0.30 | weak/inconsistent |

Source:

- `code/analysis_bundle/output/tables/crossvar_effect_summary.csv`
- current run: `n10000_overall_mapci_te_boot200`

Generated files:

- `generated_assets/table2_clinical_step_contrasts.csv`
- `generated_assets/table2_clinical_step_contrasts.xlsx`

Manuscript note:

- Use "adjusted difference" or "associated with", not "effect" in prose unless causal language is explicitly justified.

## Supplementary Table: model diagnostics

Candidate table title:

Generalized additive model performance and EtCO2 smooth-term diagnostics

| Outcome channel | Sampled observations | Model features | Effective DOF | Deviance explained | EtCO2 smooth EDF | EtCO2 smooth p value |
|---|---:|---:|---:|---:|---:|---:|
| rSO2_Ch1 | 100,000 | 17 | 51.14 | 0.232 | 8.42 | <0.001 |
| rSO2_Ch2 | 100,000 | 17 | 51.21 | 0.219 | 8.43 | <0.001 |
| SftO2 | 100,000 | 18 | 52.22 | 0.154 | 8.45 | <0.001 |

Sources:

- `results/supplemental_etables/supplemental_etable6_model_performance_co2_rso2.csv`
- `results/supplemental_etables/supplemental_etable7_nonparametric_terms_co2_rso2.csv`

Generated files:

- `generated_assets/supplementary_model_diagnostics.csv`
- `generated_assets/supplementary_model_diagnostics.xlsx`

## Figure 1: cohort and distributions

Status: not yet manuscript-ready.

Recommended panels:

- Panel a: cohort assembly and filtering.
- Panel b: EtCO2 distribution by channel.
- Panel c: rSO2 distribution by channel.
- Panel d: patient-level EtCO2 and rSO2 summary.

Candidate source tables:

- `results/supplemental_etables/supplemental_etable3_artifact_co2_rso2.csv`
- `results/supplemental_etables/supplemental_etable5_patient_level_co2_rso2.csv`

## Figure 2: adjusted EtCO2-rSO2 curves

Status: strongest main figure candidate, but should be remade.

Recommended panels:

- Three horizontally aligned panels, one per outcome channel.
- X-axis: EtCO2, mmHg.
- Y-axis: adjusted rSO2, percentage.
- Show bootstrap 95% CI bands.
- Mark clinically relevant EtCO2 values, for example 35 and 40 mmHg, if justified.

Current source:

- EtCO2 panels from `code/analysis_bundle/output/figures/figure_C_threshold_turning.png`

Generated clean figure:

- `generated_assets/figure2_etco2_adjusted_curves.png`
- `generated_assets/figure2_etco2_adjusted_curves.svg`
- `generated_assets/source_data_figure2_etco2_curves.csv`

Required cleanup:

- Remove missing MAP/SV/HR/RRtotal/TVinsp/Pmean panels.
- Use final clinical labels: `Left SctO2`, `Right SctO2`, and `SftO2`.

## Figure 3: clinical-step contrasts

Status: usable concept, needs cleanup.

Recommended panels:

- Either one grouped bar plot with outcome channel as color/facet and exposure as x-axis, or three channel-specific panels.
- Include only EtCO2, FiO2, and temperature unless the missing all-intraop comparisons are completed.

Current source:

- `code/analysis_bundle/output/figures/figure_A_delta_bar.png`
- `code/analysis_bundle/output/figures/figure_A_delta_bar_all_intraop_n10000_mapci_te.png`

Generated clean figure:

- `generated_assets/figure3_clinical_step_contrasts.png`
- `generated_assets/figure3_clinical_step_contrasts.svg`
- `generated_assets/source_data_figure3_clinical_step.csv`

Required cleanup:

- Remove variables marked missing.
- Use human-readable labels: EtCO2, FiO2, Temperature.
- Make uncertainty intervals visible at publication scale.

## Figure 4: local slope or threshold interpretation

Status: optional.

The local slope heatmap is useful for analysts but may be too abstract for a clinical journal. If used, restrict it to EtCO2 and make the y-axis channel labels clinical.

Alternative:

- A small table or line plot of EtCO2 local slopes by exposure decile.
- Main message: left and right SctO2 show the largest slope in the mid-range EtCO2 distribution and taper at high EtCO2; SftO2 shows a smaller, gradually declining slope.

Source:

- `code/analysis_bundle/output/tables/crossvar_slope_bins.csv`

## Figure legend draft for Figure 2

Adjusted relationship between end-tidal carbon dioxide and regional tissue oxygenation. Generalized additive models estimated adjusted rSO2 across the observed EtCO2 range for each oxygenation channel. Solid lines show model-estimated mean rSO2 and shaded bands show bootstrap 95% confidence intervals. Models adjusted for FiO2, temperature, mean arterial pressure, hemodynamic covariates, and patient-level factors. EtCO2, end-tidal carbon dioxide; rSO2, regional tissue oxygen saturation.

## Figure legend draft for Figure 3

Adjusted tissue oxygenation differences associated with clinically interpretable intraoperative exposure increments. Bars show the estimated rSO2 difference for a 5 mmHg higher EtCO2, 10 percentage-point higher FiO2, or 0.5 C higher temperature. Error bars show bootstrap 95% confidence intervals. Comparisons are associative and do not imply causal effects of changing ventilation or temperature.
