# End-tidal carbon dioxide and regional tissue oxygenation during off-pump coronary bypass

Draft version: V1

Status: evidence-updated writing draft based on current repository outputs. Not submission-ready until the gap checklist is resolved.

## Title Page

### Title

End-tidal carbon dioxide and regional tissue oxygenation during off-pump coronary bypass

### Authors

[Use confirmed author list from the current CO2 project. Do not copy the prior MAP/CI author block until the user confirms that the same authors and order apply.]

### Correspondence

[Confirm corresponding author and address.]

### Short title

EtCO2 and tissue oxygenation during OPCAB

### Word count

[To calculate after finalization.]

### Tables and figures

Planned main display items:

- Table 1. Baseline and intraoperative characteristics of the CO2-rSO2 analytic cohort.
- Figure 1. Cohort assembly and intraoperative EtCO2/rSO2 distributions.
- Figure 2. Adjusted EtCO2-rSO2 response curves by tissue oxygenation channel.
- Figure 3. Clinical-step comparison of EtCO2, FiO2, and temperature.
- Figure 4. Local slope or threshold view of the adjusted EtCO2-rSO2 relationship.

## Abstract

Near-infrared spectroscopy tracks tissue oxygenation during cardiac surgery, but changes in rSO2 are difficult to attribute because ventilation, oxygen delivery, temperature, blood pressure, and flow vary together. Carbon dioxide is a plausible contributor because it affects cerebrovascular tone and is continuously available as end-tidal carbon dioxide (EtCO2) during anesthesia. We used high-frequency intraoperative data from approximately 1,800 patients undergoing off-pump coronary bypass surgery to estimate adjusted nonlinear relationships between EtCO2 and regional tissue oxygenation. EtCO2 was analyzed as a continuously available clinical marker of ventilation-perfusion and perfusion physiology, not as a direct substitute for PaCO2. Generalized additive models were fitted separately for left cerebral tissue oxygen saturation (left SctO2), right SctO2, and forearm tissue oxygen saturation (SftO2), with adjustment for FiO2, temperature, mean arterial pressure, cardiac index, other available covariates, and patient-level factors. A 5 mmHg higher EtCO2 was associated with higher tissue oxygenation by 2.89 percentage points (95% CI, 2.41 to 3.33) for left SctO2, 2.98 percentage points (95% CI, 2.64 to 3.28) for right SctO2, and 0.92 percentage points (95% CI, 0.68 to 1.16) for SftO2. Comparable clinical-step changes in FiO2 and temperature were smaller and less consistent. These findings identify EtCO2 as an adjusted correlate of intraoperative cerebral oxygenation, but they do not establish PaCO2-mediated causality, an optimal EtCO2 target, or benefit from EtCO2 manipulation.

## Introduction

Near-infrared spectroscopy gives anesthesiologists a continuous view of regional tissue oxygenation during cardiac surgery.^1 The signal precedes clinical neurological or systemic outcomes, but its physiological source is often ambiguous. A fall in rSO2 may reflect changes in perfusion pressure, cardiac output, arterial oxygen content, cerebral metabolism, ventilation, temperature, sensor position, or several of these at once.

Carbon dioxide is a plausible contributor because PaCO2 changes cerebral blood flow through cerebrovascular reactivity, and EtCO2 is recorded continuously during anesthesia.^2 In practice, however, EtCO2 is not a pure respiratory exposure. It also reflects ventilation-perfusion matching, pulmonary blood flow, and systemic perfusion. This makes EtCO2 clinically useful and analytically difficult: the same number can signal a ventilation change, a perfusion change, or both.

Controlled studies have shown that manipulating carbon dioxide can alter cerebral oxygen saturation. Healthy-volunteer experiments found graded cerebral oxygenation responses to end-tidal carbon dioxide, and perioperative studies have examined EtCO2-rSO2 relationships in selected surgical settings.^2,3 Cardiac-surgery work has also explored whether NIRS reflects CO2-related physiology and whether mild hypercapnia can attenuate cerebral desaturation.^4,5 These studies support biological plausibility, but most used small samples, controlled gas challenges, selected surgical settings, or intermittent measurements.

Few data describe the adjusted EtCO2-rSO2 relationship at high temporal resolution during off-pump coronary bypass. We therefore modeled EtCO2 and tissue oxygenation continuously, using generalized additive models to estimate nonlinear relationships after adjustment for FiO2, temperature, hemodynamics, and patient factors. We also compared EtCO2 with FiO2 and temperature using clinically interpretable exposure increments, and we examined whether the association differed between cerebral and forearm tissue beds.

## Methods

### Study design and population

This retrospective observational study used high-frequency intraoperative physiologic data from patients undergoing off-pump coronary bypass surgery. The analytic dataset was derived from the same institutional data environment used for the prior MAP/CI tissue oxygenation manuscript, but this analysis focused on EtCO2 as the primary exposure. The prior MAP/CI manuscript describes the parent dataset as a prespecified secondary analysis of prospectively recorded intraoperative data from the Bottomline-CS randomized, assessor-blinded, single-center trial of elective off-pump coronary artery bypass surgery at Tianjin Chest Hospital (ClinicalTrials.gov identifier NCT04896736), conducted from 8 June 2021 to 27 December 2023. This parent-cohort language should be confirmed against the final CO2 cohort assembly before submission.

[Insert institutional review board statement, consent waiver if applicable, study dates, and exact inclusion/exclusion criteria.]

### Tissue oxygenation and intraoperative variables

The outcomes were regional tissue oxygenation channels recorded continuously during surgery. Current analysis files use `rSO2_Ch1`, `rSO2_Ch2`, and `rSO2_Ch3`, corresponding to left cerebral tissue oxygen saturation (left SctO2), right cerebral tissue oxygen saturation (right SctO2), and forearm tissue oxygen saturation (SftO2), respectively. The third NIRS channel was analyzed as SftO2 according to the channel mapping used in the primary modeling and plotting scripts.

The primary exposure was EtCO2. EtCO2 was treated as a continuously available clinical marker rather than a direct PaCO2 measurement. The primary model adjusted for hemodynamic status using MAP and cardiac index, in addition to smooth terms for EtCO2, FiO2, temperature, and prespecified patient-level covariates. Missing time-varying covariates were processed using ordered within-patient and median imputation, as described in the Supplementary Methods and documented in the CO2 supplemental eTables.

### Data cleaning and analytic cohorts

Timestamp-level outlier exclusions removed implausible EtCO2 and tissue oxygenation values. In the current outputs, the left and right SctO2 cohorts each include 1,792 patients, and the SftO2 cohort includes 1,789 patients. Each channel contains approximately 20.6 million available timestamp-level observations before the EtCO2 and tissue oxygenation exclusions reported in Supplementary Table 3.

Patient-level summaries showed mean EtCO2 near 30 mmHg across channels. Mean tissue oxygenation differed by channel, with patient-level means of 71.1% for left SctO2, 71.5% for right SctO2, and 75.6% for SftO2 in the current output.

### Generalized additive models

We used generalized additive models to estimate adjusted nonlinear relationships between EtCO2 and tissue oxygenation. The model included smooth terms for EtCO2, FiO2, temperature, mean arterial pressure, and hemodynamic covariates, plus parametric terms for patient-level factors. Separate models were fitted for left SctO2, right SctO2, and SftO2. The current archived model-performance tables report 100,000 sampled observations per channel, 17-18 model features, and total effective degrees of freedom of 51.14, 51.21, and 52.22 for left SctO2, right SctO2, and SftO2, respectively.

The prior MAP/CI analysis used a bootstrap framework to quantify uncertainty while keeping computation feasible for high-frequency intraoperative data. Current clinical-step contrasts use bootstrap-matrix confidence intervals. The CO2 manuscript should still state the final bootstrap sampling unit, sample size per replicate, number of replicates, smoothing parameters, and whether patient-level clustering was preserved during resampling.

### Clinical-step contrasts and local slopes

To make the nonlinear model clinically interpretable, we estimated expected rSO2 changes for common intraoperative exposure increments. The primary contrast was a 5 mmHg EtCO2 difference. Comparator contrasts included FiO2 and temperature increments defined in the analysis configuration. Local slopes were also summarized across exposure quantile bins.

Clinical-step contrasts were estimated from the 10,000-row `map_ci_te` analysis run, with 95% confidence intervals derived from archived bootstrap prediction matrices. These intervals are treated as model-based uncertainty intervals unless a patient-level bootstrap is finalized.

### Statistical software

The analysis used Python and generalized additive modeling scripts archived in the CO2-rSO2 repository. The final manuscript should cite the exact commit hash and the scripts used to generate the tables and figures.

## Results

### Analytic cohorts and patient characteristics

The analytic cohorts included 1,792 patients for left SctO2 and right SctO2 and 1,789 patients for SftO2. The source time-series file contained 25,385,328 timestamp-level rows from 1,872 patients before outcome-specific filtering. After requiring nonmissing EtCO2 and the corresponding tissue oxygenation channel, applying the cohort-defining EtCO2 and tissue oxygenation screens, and excluding values outside the strict analytic ranges, the final usable timestamp counts were 20,021,703 for left SctO2, 20,075,597 for right SctO2, and 20,068,759 for SftO2.

The CO2-specific Table 1/2 generation script was run on the active `g24` compute node using the project Python environment. Baseline characteristics were similar across the three channel-specific cohorts. In the left SctO2 cohort, mean age was 68.7 years (SD, 5.3), mean BMI was 25.3 kg/m2 (SD, 3.2), mean baseline cardiac index was 2.5 L/min/m2 (SD, 0.8), mean baseline mean blood pressure was 90.0 mmHg (SD, 12.4), and mean hemoglobin was 132.1 g/L (SD, 15.5). Diabetes was present in 770 patients (43.0%), hypertension in 1,316 patients (73.4%), and drinking history in 458 patients (25.6%). Corresponding values were essentially unchanged in the right SctO2 cohort and differed only slightly in the SftO2 cohort because three fewer patients were included.

Patient-level EtCO2 summaries showed mean EtCO2 near 30 mmHg across channels. Mean tissue oxygenation differed by site, with patient-level means of 71.1% for left SctO2, 71.5% for right SctO2, and 75.6% for SftO2 in the current output.

[Insert Table 1 from `docs/manuscript_development/generated_assets/table1_cohort_characteristics.xlsx`. The full baseline, intraoperative, and flow-count tables are available as Supplementary eTable 1/2 in `docs/manuscript_development/generated_assets/supplementary_etable1_2_cohort_characteristics.xlsx`. The sex label audit supports reporting the source-coded `SEX=1` row as male.]

### EtCO2 showed the largest clinical-step association with cerebral oxygenation

Clinical-step contrasts showed a consistent positive association between EtCO2 and rSO2. A 5 mmHg higher EtCO2 was associated with 2.89 percentage-point higher left SctO2 (95% CI, 2.41 to 3.33) and 2.98 percentage-point higher right SctO2 (95% CI, 2.64 to 3.28). The corresponding estimate for SftO2 was 0.92 percentage points (95% CI, 0.68 to 1.16). In the same analysis, a 10 percentage-point higher FiO2 was associated with changes of -0.18 (95% CI, -0.49 to 0.12), -0.05 (95% CI, -0.46 to 0.37), and 0.30 (95% CI, 0.11 to 0.46) percentage points across left SctO2, right SctO2, and SftO2. A 0.5 C higher temperature was associated with changes of 0.10 (95% CI, -0.16 to 0.35), 0.55 (95% CI, 0.25 to 0.87), and 0.15 (95% CI, -0.03 to 0.30) percentage points.

Among the three prespecified clinical-step comparisons shown here, EtCO2 had the largest association with left and right SctO2. The comparison should remain limited to EtCO2, FiO2, and temperature unless the missing all-intraop comparisons are completed.

[Insert Table 2: `generated_assets/table2_clinical_step_contrasts.xlsx`. Insert Figure 3: `generated_assets/figure3_clinical_step_contrasts.png`.]

### EtCO2-rSO2 response curves were nonlinear and channel-specific

The adjusted EtCO2 response curves showed increasing rSO2 across much of the observed EtCO2 range. Left and right SctO2 had similar curve shapes and effect sizes, while SftO2 showed higher baseline oxygenation and a smaller EtCO2-associated contrast. Descriptive local-slope summaries suggested steeper EtCO2-rSO2 gradients in the central exposure range and flatter gradients near the upper tail, where data were sparser and uncertainty was wider.

[Insert Figure 2: `generated_assets/figure2_etco2_adjusted_curves.png`. Bands show uncertainty intervals derived from archived prediction matrices; the bootstrap construction and sampling unit are described in the Supplement.]

### Model diagnostics supported nonlinear adjustment

The current supplemental tables report model performance, effective degrees of freedom for smooth terms, and parametric covariate estimates. The models explained 23.2% of deviance for left SctO2, 21.9% for right SctO2, and 15.4% for SftO2. The EtCO2 smooth term had effective degrees of freedom of 8.42, 8.43, and 8.45 across the three channels, with all three smooth terms reported as p<0.001. These diagnostics support nonlinear adjustment but should be interpreted as model-description statistics rather than causal evidence.

## Discussion

This high-frequency intraoperative analysis identifies EtCO2 as a clinically interpretable correlate of tissue oxygenation during off-pump coronary bypass surgery. The association was largest in the two cerebral channels: a 5 mmHg higher EtCO2 corresponded to approximately 3 percentage points higher left and right SctO2, with bootstrap confidence intervals that excluded zero. The corresponding association with SftO2 was positive but smaller. This site-specific pattern argues against treating cerebral and forearm oximetry channels as interchangeable. Cerebral and forearm sensors appear to carry related but distinct physiologic information.

The cerebral finding is biologically plausible. Carbon dioxide is a potent regulator of cerebrovascular tone, and controlled human studies show graded cerebral oxygenation responses to changes in end-tidal or arterial carbon dioxide.^2 Rather than studying a controlled gas challenge, this analysis estimates the EtCO2-rSO2 relationship in routine intraoperative data, during a procedure in which ventilation, perfusion, oxygen delivery, vasoactive treatment, and temperature vary simultaneously. The association remained visible after adjustment for FiO2, temperature, mean arterial pressure, hemodynamic covariates, and patient-level factors. These data indicate that EtCO2 should be considered alongside hemodynamic and oxygenation variables when interpreting cerebral oximetry changes during off-pump coronary bypass.

The smaller SftO2 association supports tissue-bed specificity rather than a uniform oximetry response across sensor sites. Forearm tissue oxygenation reflects skeletal muscle, skin, subcutaneous tissue, venous volume, local microvascular tone, and probe-specific factors. These determinants differ from those of cerebral oxygenation, where carbon dioxide-mediated cerebrovascular reactivity is expected to be more prominent. The observed pattern is consistent with a stronger CO2-linked signal in cerebral tissue than in the peripheral tissue bed. It also supports using paired cerebral and peripheral oximetry cautiously: concordant changes may suggest shared systemic physiology, whereas disproportionate cerebral changes may prompt closer review of cerebral perfusion, ventilation, and carbon dioxide measurements.

The FiO2 and temperature contrasts place the EtCO2 association on a clinical scale. FiO2, temperature, and ventilation are all adjustable during anesthesia, but their modeled clinical-step associations with rSO2 were not equivalent. In the current analysis, EtCO2 showed the largest and most consistent association with left and right SctO2 among the evaluated respiratory and thermal variables. This does not mean that EtCO2 should be manipulated automatically whenever rSO2 falls. It suggests that EtCO2 is a relevant contextual variable when clinicians interpret low or falling cerebral rSO2. A low or falling rSO2 value may not be interpretable without knowing whether EtCO2 has changed, particularly when arterial oxygen saturation is already high and perfusion variables are changing at the same time.

Prior studies tested carbon dioxide under controlled or selected perioperative conditions; this analysis examines routine off-pump bypass data at timestamp level. In carotid endarterectomy, EtCO2-rSO2 pharmacodynamic modeling showed that rSO2 tended to increase as EtCO2 increased.^3 In cardiac surgery, PaCO2 changes have been linked to changes in cerebral oxygenation during controlled conditions, and pilot trials have tested mild hypercapnia during cardiopulmonary bypass or off-pump bypass.^4,5 The present analysis differs in scale and design. It uses millions of timestamp-level observations from off-pump coronary bypass surgery and models nonlinear adjusted relationships rather than relying on intermittent measurements or selected gas targets. This design is useful for physiologic interpretation, but it is not a substitute for a prospective trial.

The claim has clear limits. EtCO2 is not PaCO2. It is influenced by ventilation, dead space, pulmonary blood flow, cardiac output, and ventilation-perfusion matching, so residual confounding by perfusion and gas exchange cannot be eliminated. The study is observational, and the modeled association should not be interpreted as proof that raising EtCO2 will raise cerebral oxygenation in a given patient. The analysis does not identify an optimal EtCO2 range and does not test postoperative neurological outcomes. Current comparisons are limited to EtCO2, FiO2, and temperature; broader comparisons with all intraoperative hemodynamic and ventilatory variables would require completed all-intraoperative models. The manuscript should therefore make a physiologic and interpretive claim, not a therapeutic claim.

EtCO2 provides clinically available context for interpreting intraoperative cerebral oxygenation during off-pump coronary bypass. If the association is supported by sensitivity analyses and external cohorts, EtCO2 may become a useful component of physiology-guided interpretation of cerebral oximetry. Prospective studies with PaCO2 measurement, prespecified EtCO2 protocols, and clinical endpoints are needed before this approach can be tested as a management strategy.

## Conclusion

In high-frequency intraoperative data from off-pump coronary bypass surgery, EtCO2 showed a nonlinear and clinically interpretable association with regional tissue oxygenation. A 5 mmHg higher EtCO2 was associated with nearly 3 percentage points higher left and right SctO2, exceeding the comparable associations observed for FiO2 and temperature in the current analysis. SftO2 showed a smaller but positive association. These results support EtCO2 as context for interpreting intraoperative cerebral oximetry, while leaving causal targets and patient-outcome effects to future prospective studies.

## References to verify and format

1. Chan, M. J., Chung, T., Glassford, N. J. & Bellomo, R. Near-Infrared Spectroscopy in Adult Cardiac Surgery Patients: A Systematic Review and Meta-Analysis. Journal of Cardiothoracic and Vascular Anesthesia 31, 1155-1165 (2017). https://doi.org/10.1053/j.jvca.2017.02.187
2. Mutch, W. A. C. et al. Cerebral oxygen saturation: graded response to carbon dioxide with isoxia and graded response to oxygen with isocapnia. PLoS ONE 8, e57881 (2013). https://doi.org/10.1371/journal.pone.0057881
3. Ki, S. H. et al. Quantitative analysis of the effect of end-tidal carbon dioxide on regional cerebral oxygen saturation in patients undergoing carotid endarterectomy under general anaesthesia. British Journal of Clinical Pharmacology 84, 292-300 (2018). https://doi.org/10.1111/bcp.13441
4. Park, C. S. et al. Near-infrared spectroscopy as a possible device for continuous monitoring of arterial carbon dioxide tension during cardiac surgery. Perfusion 26, 524-528 (2011). https://doi.org/10.1177/0267659111419034
5. Chan, M. J. et al. A Pilot Randomized Controlled Study of Mild Hypercapnia During Cardiac Surgery With Cardiopulmonary Bypass. Journal of Cardiothoracic and Vascular Anesthesia 33, 2968-2978 (2019). https://doi.org/10.1053/j.jvca.2019.03.012
6. Bhandari, C., Gandhi, H., Panwar, A., Haranal, M. & Pandya, H. Prospective Randomized Pilot Trial on the Effects of Mild Hypercapnia on Cerebral Oxygen Saturation in Patients Undergoing Off-Pump Coronary Artery Bypass Grafting. Journal of Cardiothoracic and Vascular Anesthesia 38, 1322-1327 (2024). https://doi.org/10.1053/j.jvca.2024.02.034
7. Han, J. et al. Care guided by tissue oxygenation and haemodynamic monitoring in off-pump coronary artery bypass grafting (Bottomline-CS): assessor blind, single centre, randomised controlled trial. BMJ 388, e082104 (2025). https://doi.org/10.1136/bmj-2024-082104

## Author Information and Declarations

### Author list and affiliations

[Insert the confirmed CO2 manuscript author list, order, affiliations, and ORCID identifiers. Do not copy the prior MAP/CI author block unless the author group and order are confirmed.]

### Ethics approval and consent to participate

[Insert the institutional review board name, approval number, approval date, and consent/waiver wording for the CO2 analysis. The current draft uses parent-cohort language from the prior MAP/CI manuscript and Bottomline-CS trial registration (`NCT04896736`), but the exact ethics statement must be confirmed before submission.]

### Funding

[Insert the confirmed funding statement for the CO2 manuscript. The prior MAP/CI manuscript reported institutional/departmental support at Tianjin Chest Hospital, affiliated with Tianjin University and Indiana University School of Medicine, with no other funding sources; use that wording only if it applies to the CO2 analysis.]

### Competing interests

[Insert the confirmed competing-interests statement. Do not state that the authors have no competing interests until all authors have confirmed.]

### Author contributions

[Insert contribution roles after the author list is final. Suggested role categories: conceptualization, data curation, formal analysis, methodology, software, validation, visualization, writing-original draft, writing-review and editing, supervision, and project administration.]

### Data availability

[Insert the confirmed data availability statement. Patient-level intraoperative data are expected to be restricted because they derive from clinical records; state the access pathway, approval requirements, and contact point only after confirmation.]

### Code availability

[Insert the confirmed code availability statement. Archive the CO2-rSO2 repository at the final submission commit hash and state whether the repository is public, private, or available on reasonable request.]

### Acknowledgements

[Insert acknowledgements after author and funding confirmation.]
