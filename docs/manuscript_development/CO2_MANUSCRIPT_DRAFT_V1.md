# End-tidal carbon dioxide and cerebral tissue oxygenation during off-pump coronary bypass

Draft version: V1

Status: evidence-updated writing draft based on current repository outputs. Not submission-ready until the gap checklist is resolved.

## Title Page

### Title

End-tidal carbon dioxide and cerebral tissue oxygenation during off-pump coronary bypass

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
- Figure 1. Cohort assembly and intraoperative EtCO2/rSO2 distributions.
- Figure 2. Adjusted EtCO2-rSO2 response curves by tissue oxygenation channel.
- Figure 3. Clinical-step comparison of EtCO2, FiO2, and temperature.
- Figure 4. Local slope or threshold view of the adjusted EtCO2-rSO2 relationship.

## Abstract

Cerebral and peripheral tissue oxygenation can change rapidly during cardiac surgery, but the intraoperative physiology behind these changes is difficult to quantify because ventilation, hemodynamics, oxygen delivery, and temperature vary together. Carbon dioxide is a plausible driver because it affects cerebral vascular tone and is continuously monitored as end-tidal carbon dioxide (EtCO2) during anesthesia. Here we estimate the adjusted relationship between EtCO2 and regional tissue oxygenation during off-pump coronary bypass surgery using high-frequency intraoperative data. We analyzed approximately 1,800 patients with more than 20 million timestamp-level observations per oxygenation channel. Generalized additive models estimated nonlinear EtCO2-rSO2 relationships while adjusting for FiO2, temperature, mean arterial pressure, hemodynamic covariates, and patient-level factors; bootstrap resampling quantified uncertainty. A 5 mmHg higher EtCO2 was associated with higher rSO2 by 2.89 percentage points (95% CI, 2.41 to 3.33) in left SctO2, 2.98 percentage points (95% CI, 2.64 to 3.28) in right SctO2, and 0.92 percentage points (95% CI, 0.68 to 1.16) in SftO2. Comparable clinical-step changes in FiO2 and temperature were smaller and less consistent. These findings identify EtCO2 as a major modifiable correlate of intraoperative tissue oxygenation. They do not establish an optimal EtCO2 target or prove that EtCO2 manipulation improves outcomes.

## Introduction

Near-infrared spectroscopy gives anesthesiologists a continuous view of regional cerebral oxygenation during cardiac surgery. The monitor is clinically attractive because it changes before many downstream neurological outcomes can be observed, but the number itself is not self-explanatory. A fall in rSO2 may reflect changes in perfusion pressure, cardiac output, arterial oxygen content, cerebral metabolism, ventilation, temperature, sensor position, or several of these at once.

Carbon dioxide deserves separate attention. PaCO2 and EtCO2 affect cerebral blood flow through cerebrovascular reactivity, and EtCO2 is available continuously during anesthesia. In practice, however, EtCO2 is not a pure respiratory exposure. It also reflects ventilation-perfusion matching, pulmonary blood flow, and systemic perfusion. This makes EtCO2 clinically useful and analytically difficult: the same number can signal a ventilation change, a perfusion change, or both.

Controlled studies have shown that manipulating carbon dioxide can alter cerebral oxygen saturation. Healthy-volunteer experiments found graded cerebral oxygenation responses to end-tidal carbon dioxide, and perioperative studies have examined EtCO2-rSO2 relationships in selected surgical settings. Cardiac-surgery work has also explored whether NIRS reflects CO2-related physiology and whether mild hypercapnia can attenuate cerebral desaturation. These studies support biological plausibility, but most used small samples, controlled gas challenges, selected surgical settings, or intermittent measurements.

The missing piece is a high-frequency, adjusted description of the EtCO2-rSO2 relationship during the physiologically unstable period of off-pump coronary bypass surgery. We therefore modeled EtCO2 and tissue oxygenation continuously, using generalized additive models to estimate nonlinear relationships after adjustment for FiO2, temperature, hemodynamics, and patient factors. We also compared EtCO2 with other adjustable intraoperative variables using clinically interpretable exposure increments.

## Methods

### Study design and population

This retrospective observational study used high-frequency intraoperative physiologic data from patients undergoing off-pump coronary bypass surgery. The analytic dataset was derived from the same institutional data environment used for the prior MAP/CI tissue oxygenation manuscript, but this analysis focused on EtCO2 as the primary exposure. The prior MAP/CI manuscript describes the parent dataset as a prespecified secondary analysis of prospectively recorded intraoperative data from the Bottomline-CS randomized, assessor-blinded, single-center trial of elective off-pump coronary artery bypass surgery at Tianjin Chest Hospital (ClinicalTrials.gov identifier NCT04896736), conducted from 8 June 2021 to 27 December 2023. This parent-cohort language should be confirmed against the final CO2 cohort assembly before submission.

[Insert institutional review board statement, consent waiver if applicable, study dates, and exact inclusion/exclusion criteria.]

### Tissue oxygenation and intraoperative variables

The outcomes were regional tissue oxygenation channels recorded continuously during surgery. Current analysis files use `rSO2_Ch1`, `rSO2_Ch2`, and `rSO2_Ch3`, corresponding to left cerebral tissue oxygen saturation (left SctO2), right cerebral tissue oxygen saturation (right SctO2), and forearm tissue oxygen saturation (SftO2), respectively. A channel-naming audit found that the main CO2 Python and R model/plot scripts and the prior MAP/CI manuscript consistently map `rSO2_Ch3` to SftO2, while the CO2 supplemental eTable 3-5 generation path had used a conflicting `Frontal SctO2 cohort` label. The latter should be treated as a label bug and corrected before submission.

The primary exposure was EtCO2. Time-varying covariates included FiO2, temperature, mean arterial pressure, and hemodynamic variables. Patient-level covariates included demographic and clinical variables used in the prior tissue oxygenation models. Missing time-varying covariates were processed using the ordered imputation strategy described in the prior supplementary methods and documented in the CO2 supplemental eTables.

### Data cleaning and analytic cohorts

Timestamp-level outlier exclusions removed implausible EtCO2 and tissue oxygenation values. In the current outputs, the left and right SctO2 cohorts each include 1,792 patients, and the SftO2 cohort includes 1,789 patients. Each channel contains approximately 20.6 million available timestamp-level observations before the EtCO2 and tissue oxygenation exclusions reported in Supplementary Table 3.

Patient-level summaries showed mean EtCO2 near 30 mmHg across channels. Mean tissue oxygenation differed by channel, with patient-level means of 71.1% for left SctO2, 71.5% for right SctO2, and 75.6% for SftO2 in the current output.

### Generalized additive models

We used generalized additive models to estimate adjusted nonlinear relationships between EtCO2 and tissue oxygenation. The model included smooth terms for EtCO2, FiO2, temperature, mean arterial pressure, and hemodynamic covariates, plus parametric terms for patient-level factors. Separate models were fitted for left SctO2, right SctO2, and SftO2. The current archived model-performance tables report 100,000 sampled observations per channel, 17-18 model features, and total effective degrees of freedom of 51.14, 51.21, and 52.22 for left SctO2, right SctO2, and SftO2, respectively.

The prior MAP/CI analysis used a bootstrap framework to quantify uncertainty while keeping computation feasible for high-frequency intraoperative data. Current clinical-step contrasts use bootstrap-matrix confidence intervals. The CO2 manuscript should still state the final bootstrap sampling unit, sample size per replicate, number of replicates, smoothing parameters, and whether patient-level clustering was preserved during resampling.

### Clinical-step contrasts and local slopes

To make the nonlinear model clinically interpretable, we estimated expected rSO2 changes for common intraoperative exposure increments. The primary contrast was a 5 mmHg EtCO2 difference. Comparator contrasts included FiO2 and temperature increments defined in the analysis configuration. Local slopes were also summarized across exposure quantile bins.

### Statistical software

The analysis used Python and generalized additive modeling scripts archived in the CO2-rSO2 repository. The final manuscript should cite the exact commit hash and the scripts used to generate the tables and figures.

## Results

### Analytic cohorts and patient characteristics

The analytic cohorts included 1,792 patients for left SctO2 and right SctO2 and 1,789 patients for SftO2. The source time-series file contained 25,385,328 timestamp-level rows from 1,872 patients before outcome-specific filtering. After requiring nonmissing EtCO2 and the corresponding tissue oxygenation channel, applying the cohort-defining EtCO2 and tissue oxygenation screens, and excluding values outside the strict analytic ranges, the final usable timestamp counts were 20,021,703 for left SctO2, 20,075,597 for right SctO2, and 20,068,759 for SftO2.

The CO2-specific Table 1/2 generation script was run on the active `g24` compute node using the project Python environment. Baseline characteristics were similar across the three channel-specific cohorts. In the left SctO2 cohort, mean age was 68.7 years (SD, 5.3), mean BMI was 25.3 kg/m2 (SD, 3.2), mean baseline cardiac index was 2.5 L/min/m2 (SD, 0.8), mean baseline mean blood pressure was 90.0 mmHg (SD, 12.4), and mean hemoglobin was 132.1 g/L (SD, 15.5). Diabetes was present in 770 patients (43.0%), hypertension in 1,316 patients (73.4%), and drinking history in 458 patients (25.6%). Corresponding values were essentially unchanged in the right SctO2 cohort and differed only slightly in the SftO2 cohort because three fewer patients were included.

Patient-level EtCO2 summaries showed mean EtCO2 near 30 mmHg across channels. Mean tissue oxygenation differed by site, with patient-level means of 71.1% for left SctO2, 71.5% for right SctO2, and 75.6% for SftO2 in the current output.

[Insert Table 1/2 from `results/manuscript_tables/table1_2_co2_rso2.xlsx` after the generated files are pulled back into the local mirror.]

### EtCO2 showed the largest clinical-step association with cerebral oxygenation

Clinical-step contrasts showed a consistent positive association between EtCO2 and rSO2. A 5 mmHg higher EtCO2 was associated with 2.89 percentage-point higher left SctO2 (95% CI, 2.41 to 3.33) and 2.98 percentage-point higher right SctO2 (95% CI, 2.64 to 3.28). The corresponding estimate for SftO2 was 0.92 percentage points (95% CI, 0.68 to 1.16). In the same analysis, a 10 percentage-point higher FiO2 was associated with changes of -0.18 (95% CI, -0.49 to 0.12), -0.05 (95% CI, -0.46 to 0.37), and 0.30 (95% CI, 0.11 to 0.46) percentage points across left SctO2, right SctO2, and SftO2. A 0.5 C higher temperature was associated with changes of 0.10 (95% CI, -0.16 to 0.35), 0.55 (95% CI, 0.25 to 0.87), and 0.15 (95% CI, -0.03 to 0.30) percentage points.

This comparison supports EtCO2 as the strongest current respiratory correlate of cerebral oxygenation in the available model. The comparison should remain limited to EtCO2, FiO2, and temperature unless the missing all-intraop comparisons are completed.

[Insert Table 2: `generated_assets/table2_clinical_step_contrasts.xlsx`. Insert Figure 3: `generated_assets/figure3_clinical_step_contrasts.png`.]

### EtCO2-rSO2 response curves were nonlinear and channel-specific

The adjusted EtCO2 response curves showed increasing rSO2 across much of the observed EtCO2 range. Left and right SctO2 had similar curve shapes and effect sizes, while SftO2 showed higher baseline oxygenation and a smaller EtCO2-associated contrast. Local slope summaries supported this pattern. For left SctO2, the mean EtCO2 slope rose from 0.36 percentage points per mmHg in the lowest exposure decile to about 0.61 near the middle of the exposure distribution, then declined to 0.11 in the upper decile. Right SctO2 showed a similar mid-range peak, increasing from 0.16 to about 0.62 before tapering. SftO2 showed a more gradual decline from 0.29 in the lowest decile to 0.11 in the highest decile. Uncertainty widened near the upper exposure tail, consistent with fewer observations at higher EtCO2 values.

[Insert Figure 2: `generated_assets/figure2_etco2_adjusted_curves.png`.]

### Model diagnostics supported nonlinear adjustment

The current supplemental tables report model performance, effective degrees of freedom for smooth terms, and parametric covariate estimates. The models explained 23.2% of deviance for left SctO2, 21.9% for right SctO2, and 15.4% for SftO2. The EtCO2 smooth term had effective degrees of freedom of 8.42, 8.43, and 8.45 across the three channels, with all three smooth terms reported as p<0.001. These diagnostics support nonlinear adjustment but should be interpreted as model-description statistics rather than causal evidence.

### Sensitivity analyses remain incomplete

The repository includes planned sensitivity summaries, but the 5-model sensitivity analysis currently reports missing result directories for all planned model variants. The present draft therefore does not claim robustness across those sensitivity models. These analyses should either be completed before submission or removed from the manuscript and supplement.

## Discussion

This analysis identifies EtCO2 as the dominant respiratory correlate of regional tissue oxygenation in high-frequency data from off-pump coronary bypass surgery. The estimated association was clinically interpretable: a 5 mmHg higher EtCO2 corresponded to roughly a 3 percentage-point higher rSO2 in the left and right cerebral channels, with bootstrap confidence intervals that excluded zero. SftO2 showed a smaller association, consistent with tissue-bed differences between cerebral and forearm oxygenation.

The finding is physiologically plausible. Carbon dioxide changes cerebrovascular tone, and controlled studies have shown graded cerebral oxygenation responses to carbon dioxide. Our analysis adds a different piece of evidence: the relationship remains visible in routine intraoperative data after adjustment for oxygen concentration, temperature, mean arterial pressure, hemodynamic covariates, and patient factors. This does not make EtCO2 a causal treatment target. It does suggest that EtCO2 should be considered when interpreting rSO2 changes during off-pump coronary bypass.

The comparison with FiO2 and temperature helps define the clinical meaning of the EtCO2 result. These variables are adjustable during anesthesia, but their estimated clinical-step associations with rSO2 were smaller and less consistent in the current analysis. If this finding remains stable after sensitivity analyses, it will support a practical message: when cerebral oxygenation changes during off-pump coronary bypass, EtCO2 is not just a ventilation readout but a major physiologic correlate of the oxygenation signal.

Several limits matter. EtCO2 is not PaCO2. It is affected by ventilation, dead space, pulmonary blood flow, and cardiac output, so residual confounding by perfusion cannot be eliminated. The study is observational and cannot identify an optimal EtCO2 range. The current analysis also lacks completed sensitivity runs and outcome endpoints. The manuscript should therefore make a physiologic claim, not a therapeutic claim: EtCO2 is a major, continuously available correlate of intraoperative cerebral oxygenation, and prospective studies are needed to test whether EtCO2-guided management improves patient outcomes.

## Conclusion

In high-frequency intraoperative data from off-pump coronary bypass surgery, EtCO2 showed a consistent, nonlinear, and clinically interpretable association with regional tissue oxygenation. A 5 mmHg higher EtCO2 was associated with nearly 3 percentage points higher left and right SctO2, exceeding the comparable associations observed for FiO2 and temperature in the current analysis. SftO2 showed a smaller but positive association. These results support EtCO2 as an important variable for interpreting intraoperative tissue oxygenation, while leaving causal targets and patient-outcome effects to future prospective studies.

## References to verify and format

1. Chan, M. J., Chung, T., Glassford, N. J. & Bellomo, R. Near-Infrared Spectroscopy in Adult Cardiac Surgery Patients: A Systematic Review and Meta-Analysis. Journal of Cardiothoracic and Vascular Anesthesia 31, 1155-1165 (2017). https://doi.org/10.1053/j.jvca.2017.02.187
2. Mutch, W. A. C. et al. Cerebral oxygen saturation: graded response to carbon dioxide with isoxia and graded response to oxygen with isocapnia. PLoS ONE 8, e57881 (2013). https://pubmed.ncbi.nlm.nih.gov/23469096/
3. Park, C. S. et al. Near-infrared spectroscopy as a possible device for continuous monitoring of arterial carbon dioxide tension during cardiac surgery. Perfusion 26, 524-528 (2011). https://pubmed.ncbi.nlm.nih.gov/21844113/
4. Quantitative analysis of the effect of end-tidal carbon dioxide on regional cerebral oxygen saturation in patients undergoing carotid endarterectomy under general anaesthesia. https://pmc.ncbi.nlm.nih.gov/articles/PMC5777433/
5. A pilot randomized controlled study of mild hypercapnia during cardiac surgery with cardiopulmonary bypass. https://research.monash.edu/en/publications/a-pilot-randomized-controlled-study-of-mild-hypercapnia-during-ca
6. Prospective randomized pilot trial on the effects of mild hypercapnia on cerebral oxygen saturation in patients undergoing off-pump coronary artery bypass grafting. https://www.sciencedirect.com/science/article/pii/S1053077024001563

## Author-side items not filled

- final author list and order;
- corresponding author;
- funding statement;
- conflict of interest statement;
- ethics approval details;
- data availability statement;
- code availability statement;
- author contributions.
