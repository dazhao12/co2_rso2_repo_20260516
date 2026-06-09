# CO2-rSO2 Manuscript Blueprint

Date: 2026-06-08

Purpose: turn the current CO2-rSO2 analysis into a manuscript using the prior MAP/CI tissue oxygenation paper as the structural template, while keeping the scientific story specific to end-tidal carbon dioxide (EtCO2).

## Working conclusion

The CO2 paper is writeable now as an observational, high-frequency intraoperative physiology manuscript. The strongest current claim is not that mild hypercapnia improves clinical outcomes. The defensible claim is:

> In off-pump coronary bypass surgery, EtCO2 shows a consistent, nonlinear, and clinically larger association with cerebral/regional tissue oxygenation than FiO2 or temperature after adjustment for major hemodynamic and intraoperative covariates.

Do not frame the paper as a ventilation intervention trial unless a targeted hypercapnia analysis is added. Do not claim outcome benefit without postoperative neurological or clinical outcome analyses.

## Best manuscript angle

Recommended title direction:

1. End-tidal carbon dioxide and cerebral tissue oxygenation during off-pump coronary bypass
2. Adjusted intraoperative relationships between end-tidal carbon dioxide and cerebral tissue oxygenation
3. Nonlinear association of end-tidal carbon dioxide with cerebral oxygenation during off-pump coronary bypass

Nature-style title preference: option 1 is shortest and clearest. Option 2 matches the prior MAP/CI paper more closely. Option 3 emphasizes the GAM contribution.

## Relationship to the prior MAP/CI manuscript

Prior MAP/CI framework:

- Main manuscript title: adjusted relationships between mean arterial pressure, cardiac index, and tissue oxygenation during off-pump coronary bypass.
- Main paper structure: title page, abstract, introduction, methods, statistical analysis, results, discussion, key results, conclusion.
- Display strategy: 1 main table and 4 main figures.
- Supplementary file: eTables 1-9 plus eFigures, including data preparation, model performance, nonparametric terms, parametric terms, and adjusted slopes.

CO2 adaptation:

- Exposure changes from MAP/CI joint hemodynamics to EtCO2 as the primary respiratory/vascular exposure.
- Outcome remains tissue oxygenation: left cerebral rSO2, right cerebral rSO2, and forearm tissue oxygenation (SftO2).
- Core model should be described as a multivariable GAM including EtCO2, temperature, FiO2, MAP, cardiac index/stroke volume-related hemodynamic variables, and patient-level covariates.
- The central plot should be one-dimensional EtCO2 response curves by channel, not a MAP-CI response surface.
- The main table should quantify clinically interpretable EtCO2 increments, such as 5 mmHg changes, with uncertainty.

## Current evidence available in the repository

Local evidence sources:

- `results/supplemental_etables/supplemental_etable3_artifact_co2_rso2.csv`
- `results/supplemental_etables/supplemental_etable4_missingness_imputation_other_intraop.csv`
- `results/supplemental_etables/supplemental_etable5_patient_level_co2_rso2.csv`
- `results/supplemental_etables/supplemental_etable6_model_performance_co2_rso2.csv`
- `results/supplemental_etables/supplemental_etable7_nonparametric_terms_co2_rso2.csv`
- `results/supplemental_etables/supplemental_etable8_parametric_terms_co2_rso2.csv`
- `code/analysis_bundle/output/tables/crossvar_effect_by_channel.csv`
- `code/analysis_bundle/output/tables/crossvar_slope_bins.csv`
- `code/analysis_bundle/output/figures/figure_A_delta_bar.png`
- `code/analysis_bundle/output/figures/figure_B_slope_heatmap.png`
- `code/analysis_bundle/output/figures/figure_C_threshold_turning.png`

Key current numbers:

- Analytic cohorts include 1,792 patients for left and right cerebral rSO2 and 1,789 patients for SftO2.
- Available timestamp-level observations before EtCO2/tissue oxygen filtering are about 20.7 million per channel.
- Patient-level mean EtCO2 is about 30.0 mmHg with SD 2.6.
- Patient-level mean tissue oxygenation is 71.1% for left cerebral rSO2, 71.5% for right cerebral rSO2, and 75.6% for SftO2.
- A 5 mmHg EtCO2 step is associated with higher rSO2 by about 2.89 percentage points in left SctO2, 2.98 in right SctO2, and 0.92 in SftO2.
- Comparable clinical-step effects for FiO2 and temperature are smaller and less consistent in the current cross-variable table.

## Proposed article structure

### Abstract

Single unstructured paragraph if targeting Nature Communications or Nature-style writing. Use 180-220 words. Required elements:

- Cardiac surgery patients are exposed to rapid changes in ventilation, hemodynamics, and cerebral oxygenation.
- EtCO2 is physiologically tied to cerebral vascular tone, but its continuous intraoperative relationship with regional tissue oxygenation has not been well quantified at scale.
- State the dataset: off-pump coronary bypass, high-frequency intraoperative EtCO2 and rSO2, three tissue oxygenation channels, about 1,800 patients and 20 million timestamp-level observations.
- State method: generalized additive models with bootstrap uncertainty, adjusted for FiO2, temperature, MAP, hemodynamic covariates, and patient factors.
- State result: 5 mmHg EtCO2 increase corresponds to about 2.9 percentage-point higher left/right cerebral rSO2 and about 0.9 percentage-point higher SftO2.
- End with a cautious implication: EtCO2 is a major modifiable correlate of intraoperative cerebral oxygenation, but outcome and intervention studies are needed.

### Introduction

Three paragraphs:

1. Clinical problem: cerebral oxygen desaturation during cardiac surgery is monitored with NIRS, but actionable physiologic drivers remain incompletely quantified.
2. Why CO2 matters: CO2 affects cerebral blood flow and oxygenation; EtCO2 is continuously available, unlike intermittent PaCO2, but it is influenced by ventilation and perfusion.
3. Study gap and aim: prior work has tested controlled gas changes or small cohorts; this study estimates adjusted, nonlinear EtCO2-rSO2 relationships from high-frequency off-pump CABG data.

### Results

Recommended subheadings:

1. Analytic cohorts and intraoperative EtCO2 distributions
2. EtCO2 showed the largest clinical-step association with cerebral rSO2
3. EtCO2-rSO2 curves were nonlinear and channel-specific
4. Model diagnostics supported the adjusted GAM framework
5. Sensitivity analyses and limitations of the current analysis

### Discussion

Argument:

- Main message: EtCO2 was the dominant respiratory correlate of rSO2 in the current model.
- Physiological interpretation: the association is compatible with CO2-mediated cerebral vasoreactivity, but EtCO2 also reflects ventilation-perfusion and cardiac output.
- Clinical interpretation: EtCO2 may be an interpretable target when rSO2 declines, but the current study cannot define an optimal EtCO2 target or prove benefit.
- Contrast with FiO2 and temperature: FiO2 and temperature were included because they are clinically adjustable; their smaller observed effects make EtCO2 stand out.
- Limitations: observational design, single surgical population, EtCO2 rather than PaCO2, channel/sensor naming, residual confounding, missing sensitivity runs, no outcome endpoint yet.

## Figure and table plan

Main display items:

- Table 1: baseline and intraoperative characteristics, adapted from the prior MAP/CI Table 1 workflow.
- Figure 1: study cohort, timestamp filtering, and EtCO2/rSO2 distributions.
- Figure 2: adjusted EtCO2-rSO2 curves by channel with uncertainty bands.
- Figure 3: clinical-step effect bar plot comparing EtCO2, FiO2, and temperature.
- Supplementary Figure 1: descriptive local-slope view across EtCO2 20-50 mmHg bins, if retained as a model-shape check.

Supplementary display items:

- Supplementary Table 1: intraoperative management characteristics.
- Supplementary Table 2: baseline patient characteristics.
- Supplementary Table 3: outlier exclusions.
- Supplementary Table 4: missingness and imputation.
- Supplementary Table 5: patient-level EtCO2 and rSO2 summary.
- Supplementary Table 6: model performance.
- Supplementary Table 7: nonparametric GAM terms.
- Supplementary Table 8: parametric GAM terms.
- Supplementary Table 9: clinically interpretable EtCO2 slopes or zone-specific contrasts.

## Current hard stops before a full submission draft

1. Keep the final channel labels consistent: `rSO2_Ch1` = left SctO2, `rSO2_Ch2` = right SctO2, and `rSO2_Ch3` = SftO2. Carry the corrected eTable 3-5 label map into the final regenerated supplement.
2. Finish or intentionally drop the all-intraop variable comparison. Current all-intraop output expects 27 rows and has 18 missing entries for MAP, SV, HR, RRtotal, TVinsp, and Pmean.
3. Finish or explicitly remove the 5-model sensitivity analysis. The current summary marks all planned sensitivity result directories as missing.
4. Generate CO2-specific Table 1 and Table 2. The current repository has supplemental eTables 3-8 but not baseline/intraoperative characteristics in manuscript-ready form.
5. Decide whether outcome analyses are in scope. Without outcome analyses, the paper should stay mechanistic/physiologic and avoid outcome-benefit claims.
