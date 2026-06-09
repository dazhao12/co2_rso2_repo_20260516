# End-tidal carbon dioxide is associated with cerebral tissue oxygenation during off-pump coronary bypass

Draft version: V1

Status: evidence-updated writing draft based on current repository outputs. Not submission-ready until the gap checklist is resolved.

## Title Page

### Title

End-tidal carbon dioxide is associated with cerebral tissue oxygenation during off-pump coronary bypass

### Authors

[Use confirmed author list from the current CO2 project. Do not copy the prior MAP/CI author block until the user confirms that the same authors and order apply.]

### Correspondence

[Confirm corresponding author and address.]

### Short title

EtCO2 and cerebral oxygenation during OPCAB

### Word count

[To calculate after finalization.]

### Tables and figures

Planned main display items:

- Table 1. Baseline and intraoperative characteristics of the CO2-rSO2 analytic cohort.
- Figure 1. Cohort assembly by tissue oxygenation channel.
- Figure 2. Adjusted EtCO2-rSO2 response curves by tissue oxygenation channel.
- Figure 3. Clinical-step comparison of EtCO2, FiO2, and temperature.
- Figure 4. Local slope or threshold view of the adjusted EtCO2-rSO2 relationship.

## Abstract

Near-infrared spectroscopy provides continuous tissue oxygenation data during cardiac surgery, but a change in rSO2 is difficult to interpret when ventilation, oxygen delivery, temperature, pressure, and flow change together. Carbon dioxide is a plausible contributor to this signal because it affects cerebrovascular tone, and end-tidal carbon dioxide (EtCO2) is recorded continuously during anesthesia. Here we modeled high-frequency intraoperative data from patients undergoing off-pump coronary bypass surgery to estimate adjusted nonlinear relationships between EtCO2 and regional tissue oxygenation. The analytic cohorts included 1,792 patients for left and right cerebral tissue oxygen saturation (SctO2) and 1,789 patients for forearm tissue oxygen saturation (SftO2), with more than 20 million usable timestamp-level observations per channel. We fitted generalized additive models separately for left SctO2, right SctO2, and SftO2, adjusting for FiO2, temperature, mean arterial pressure, cardiac index, other available covariates, and patient-level factors. A 5 mmHg higher EtCO2 was associated with 2.89 percentage points higher left SctO2 (95% CI, 2.41 to 3.33), 2.98 percentage points higher right SctO2 (95% CI, 2.64 to 3.28), and 0.92 percentage points higher SftO2 (95% CI, 0.68 to 1.16). Equivalent clinical-step contrasts for FiO2 and temperature were smaller and less consistent. EtCO2 therefore emerged as a strong, nonlinear, tissue-bed-specific correlate of intraoperative cerebral oxygenation. These data support using EtCO2 as context when interpreting cerebral oximetry during off-pump coronary bypass, but they do not establish PaCO2-mediated causality, define an EtCO2 target, or show that changing EtCO2 improves patient outcomes.

## Introduction

Near-infrared spectroscopy is used during cardiac surgery to monitor regional tissue oxygenation in real time.^1 Its clinical interpretation remains difficult. A low cerebral rSO2 value can reflect impaired oxygen delivery, altered venous volume, changes in cerebral metabolic demand, sensor factors, or systemic hemodynamic instability. During off-pump coronary bypass, these influences often occur together.

Carbon dioxide is one reason the signal is hard to interpret. PaCO2 changes cerebral blood flow through cerebrovascular reactivity, and controlled human experiments show graded cerebral oxygenation responses to carbon dioxide under isoxic conditions.^2 In the operating room, clinicians usually see EtCO2 rather than continuous PaCO2. EtCO2 is useful because it is available at every breath, but it is not a pure carbon dioxide exposure. It also reflects ventilation-perfusion matching, pulmonary blood flow, dead space, and systemic perfusion. The same EtCO2 value can therefore carry respiratory and circulatory information.

Prior perioperative work supports a relationship between carbon dioxide and cerebral oxygenation, but the evidence base is fragmented. EtCO2-rSO2 modeling has been reported in carotid endarterectomy.^3 Cardiac-surgery studies have linked arterial carbon dioxide tension to NIRS values and have tested mild hypercapnia during cardiopulmonary bypass or off-pump bypass.^4,5,6 These studies establish biological plausibility and clinical interest. They do not describe, at scale, how EtCO2 relates to cerebral and peripheral tissue oxygenation during routine off-pump coronary bypass after simultaneous adjustment for oxygen fraction, temperature, perfusion pressure, cardiac index, and patient factors.

We therefore used high-frequency intraoperative data to model EtCO2 and regional tissue oxygenation continuously during off-pump coronary bypass. We estimated nonlinear adjusted associations for left SctO2, right SctO2, and SftO2 using generalized additive models. We then placed EtCO2 on a clinical scale by comparing a 5 mmHg EtCO2 contrast with prespecified FiO2 and temperature contrasts. The goal was interpretive: to determine whether EtCO2 should be considered when clinicians read intraoperative cerebral oximetry, not to define a carbon dioxide treatment target.

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

[Insert Figure 1: `docs/manuscript_development/generated_assets/figure1_cohort_flow.png`. Source data: `docs/manuscript_development/generated_assets/source_data_figure1_cohort_flow.csv`.]

### EtCO2 showed the largest clinical-step association with cerebral oxygenation

Clinical-step contrasts showed a consistent positive association between EtCO2 and rSO2. A 5 mmHg higher EtCO2 was associated with 2.89 percentage-point higher left SctO2 (95% CI, 2.41 to 3.33) and 2.98 percentage-point higher right SctO2 (95% CI, 2.64 to 3.28). The corresponding estimate for SftO2 was 0.92 percentage points (95% CI, 0.68 to 1.16). In the same analysis, a 10 percentage-point higher FiO2 was associated with changes of -0.18 (95% CI, -0.49 to 0.12), -0.05 (95% CI, -0.46 to 0.37), and 0.30 (95% CI, 0.11 to 0.46) percentage points across left SctO2, right SctO2, and SftO2. A 0.5 C higher temperature was associated with changes of 0.10 (95% CI, -0.16 to 0.35), 0.55 (95% CI, 0.25 to 0.87), and 0.15 (95% CI, -0.03 to 0.30) percentage points.

Among the three prespecified clinical-step comparisons shown here, EtCO2 had the largest association with left and right SctO2. The comparison should remain limited to EtCO2, FiO2, and temperature unless the missing all-intraop comparisons are completed.

[Insert Table 2: `generated_assets/table2_clinical_step_contrasts.xlsx`. Insert Figure 3: `generated_assets/figure3_clinical_step_contrasts.png`.]

### EtCO2-rSO2 response curves were nonlinear and channel-specific

The adjusted EtCO2 response curves showed increasing rSO2 across much of the observed EtCO2 range. Left and right SctO2 had similar curve shapes and effect sizes, while SftO2 showed higher baseline oxygenation and a smaller EtCO2-associated contrast. Descriptive local-slope summaries suggested steeper EtCO2-rSO2 gradients in the central exposure range and flatter gradients near the upper tail, where data were sparser and uncertainty was wider.

[Insert Figure 2: `generated_assets/figure2_etco2_adjusted_curves.png`. Bands show uncertainty intervals derived from archived prediction matrices; the bootstrap construction and sampling unit are described in the Supplement.]

[Insert Figure 4: `generated_assets/figure4_etco2_local_slopes.png`. Source data: `generated_assets/source_data_figure4_etco2_local_slopes.csv`. Local slopes are descriptive model summaries from EtCO2 decile bins.]

### Model diagnostics supported nonlinear adjustment

The current supplemental tables report model performance, effective degrees of freedom for smooth terms, and parametric covariate estimates. The models explained 23.2% of deviance for left SctO2, 21.9% for right SctO2, and 15.4% for SftO2. The EtCO2 smooth term had effective degrees of freedom of 8.42, 8.43, and 8.45 across the three channels, with all three smooth terms reported as p<0.001. These diagnostics support nonlinear adjustment but should be interpreted as model-description statistics rather than causal evidence.

## Discussion

This study identifies EtCO2 as a strong adjusted correlate of cerebral tissue oxygenation during off-pump coronary bypass. A 5 mmHg higher EtCO2 was associated with nearly 3 percentage points higher left and right SctO2. The same contrast was associated with less than 1 percentage point higher SftO2. This pattern was consistent across the two cerebral channels and smaller in the forearm channel, indicating that EtCO2 is linked more closely to cerebral than peripheral oximetry in this setting.

The finding is physiologically plausible. Carbon dioxide changes cerebrovascular tone, and controlled experiments show graded cerebral oxygenation responses to carbon dioxide.^2 Our analysis extends that physiology into routine surgical data, where EtCO2, FiO2, temperature, pressure, cardiac index, and patient factors vary together. The EtCO2 association remained visible after adjustment for these concurrent variables. The result therefore supports a practical interpretation: a cerebral oximetry value during off-pump coronary bypass should be read with the EtCO2 trend in view.

The forearm channel strengthens the interpretation. If EtCO2 were acting only as a nonspecific marker of global signal quality or systemic oxygenation, similar contrasts might be expected across tissue beds. Instead, the cerebral contrasts were about three times larger than the SftO2 contrast. Forearm oximetry reflects skeletal muscle, skin, subcutaneous tissue, venous volume, local microvascular tone, and probe position. Cerebral oximetry is more directly exposed to carbon dioxide-mediated cerebrovascular reactivity. The smaller forearm association therefore supports tissue-bed specificity rather than a uniform rSO2 response.

The comparison with FiO2 and temperature gives the effect a clinical scale. In the current models, a 10 percentage-point higher FiO2 was not associated with a consistent increase in cerebral SctO2, and a 0.5 C higher temperature showed smaller channel-dependent associations. EtCO2 showed the largest and most consistent cerebral contrast among the evaluated respiratory and thermal variables. This does not mean that EtCO2 should be increased whenever SctO2 falls. It means that EtCO2 is a relevant explanatory variable when clinicians interpret low or changing cerebral oxygenation, particularly when arterial oxygen saturation is already high and hemodynamic variables are changing.

These results fit with prior carbon dioxide and NIRS studies but differ in scale and clinical context. Volunteer data showed graded cerebral oxygenation responses to carbon dioxide under controlled conditions.^2 Carotid endarterectomy data supported quantitative EtCO2-rSO2 modeling.^3 Cardiac-surgery studies linked PaCO2 to cerebral oximetry and tested mild hypercapnia during cardiopulmonary bypass or off-pump bypass.^4,5,6 The present analysis does not replace those mechanistic and interventional studies. It adds high-frequency observational evidence from routine off-pump coronary bypass and shows that the EtCO2-rSO2 relationship remains detectable after simultaneous adjustment for major intraoperative covariates.

The limitations define the claim. EtCO2 is not PaCO2. It is shaped by ventilation, dead space, pulmonary blood flow, cardiac output, and ventilation-perfusion matching. Residual confounding by perfusion and gas exchange is therefore unavoidable. The models used sampled timestamp-level data and model-based uncertainty intervals, so they should be interpreted as physiologic association models rather than patient-level causal estimates. The analysis did not test postoperative neurological outcomes, did not define an optimal EtCO2 range, and did not establish whether changing EtCO2 improves cerebral oxygenation in a given patient. Current reported comparisons are limited to EtCO2, FiO2, and temperature; broader ventilatory and hemodynamic sensitivity analyses remain a separate decision.

EtCO2 should be treated as context for cerebral oximetry, not as a therapeutic target derived from this dataset. The next step is prospective validation with paired PaCO2 measurement, prespecified ventilatory protocols, integrated hemodynamic monitoring, and outcome-linked endpoints. Until then, the main implication is interpretive: during off-pump coronary bypass, EtCO2 carries information that helps explain cerebral rSO2 variation.

## Conclusion

In high-frequency intraoperative data from off-pump coronary bypass surgery, EtCO2 showed a nonlinear and clinically interpretable association with regional tissue oxygenation. A 5 mmHg higher EtCO2 was associated with nearly 3 percentage points higher left and right SctO2, exceeding the comparable associations observed for FiO2 and temperature in the current analysis. SftO2 showed a smaller but positive association. These results support EtCO2 as context for interpreting intraoperative cerebral oximetry, while leaving causal targets and patient-outcome effects to future prospective studies.

## References

1. Chan, M. J., Chung, T., Glassford, N. J. & Bellomo, R. Near-Infrared Spectroscopy in Adult Cardiac Surgery Patients: A Systematic Review and Meta-Analysis. Journal of Cardiothoracic and Vascular Anesthesia 31, 1155-1165 (2017). https://doi.org/10.1053/j.jvca.2017.02.187
2. Mutch, W. A. C. et al. Cerebral oxygen saturation: graded response to carbon dioxide with isoxia and graded response to oxygen with isocapnia. PLoS ONE 8, e57881 (2013). https://doi.org/10.1371/journal.pone.0057881
3. Ki, S. H. et al. Quantitative analysis of the effect of end-tidal carbon dioxide on regional cerebral oxygen saturation in patients undergoing carotid endarterectomy under general anaesthesia. British Journal of Clinical Pharmacology 84, 292-300 (2018). https://doi.org/10.1111/bcp.13441
4. Park, C. S. et al. Near-infrared spectroscopy as a possible device for continuous monitoring of arterial carbon dioxide tension during cardiac surgery. Perfusion 26, 524-528 (2011). https://doi.org/10.1177/0267659111419034
5. Chan, M. J. et al. A Pilot Randomized Controlled Study of Mild Hypercapnia During Cardiac Surgery With Cardiopulmonary Bypass. Journal of Cardiothoracic and Vascular Anesthesia 33, 2968-2978 (2019). https://doi.org/10.1053/j.jvca.2019.03.012
6. Bhandari, C., Gandhi, H., Panwar, A., Haranal, M. & Pandya, H. Prospective Randomized Pilot Trial on the Effects of Mild Hypercapnia on Cerebral Oxygen Saturation in Patients Undergoing Off-Pump Coronary Artery Bypass Grafting. Journal of Cardiothoracic and Vascular Anesthesia 38, 1322-1327 (2024). https://doi.org/10.1053/j.jvca.2024.02.034
7. Han, J. et al. Care guided by tissue oxygenation and haemodynamic monitoring in off-pump coronary artery bypass grafting (Bottomline-CS): assessor blind, single centre, randomised controlled trial. BMJ 388, e082104 (2025). https://doi.org/10.1136/bmj-2024-082104

Reference verification status is documented in `docs/manuscript_development/CO2_REFERENCE_AUDIT.md`.

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
