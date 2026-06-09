# Nature-Style CO2-rSO2 Draft Skeleton

This is a prose scaffold, not a final manuscript. It follows the prior MAP/CI manuscript structure but rewrites the scientific story for EtCO2.

## Title

End-tidal carbon dioxide and cerebral tissue oxygenation during off-pump coronary bypass

Alternative:

Adjusted intraoperative relationships between end-tidal carbon dioxide and cerebral tissue oxygenation

## Abstract draft

Cerebral tissue oxygenation can change rapidly during cardiac surgery, but the intraoperative physiology behind these changes is difficult to quantify because ventilation, hemodynamics, oxygen delivery, and temperature vary together. Carbon dioxide is a plausible driver because it affects cerebral vascular tone and is continuously monitored as end-tidal carbon dioxide during anesthesia. Here we estimate the adjusted relationship between end-tidal carbon dioxide and regional tissue oxygenation during off-pump coronary bypass surgery using high-frequency intraoperative data. We analyzed approximately 1,800 patients with more than 20 million timestamp-level observations per cerebral oxygenation channel. Generalized additive models estimated nonlinear EtCO2-rSO2 relationships while adjusting for FiO2, temperature, mean arterial pressure, hemodynamic covariates, and patient-level factors; bootstrap resampling quantified uncertainty. A 5 mmHg higher EtCO2 was associated with higher rSO2 by 2.89 percentage points in the left cerebral channel, 2.98 percentage points in the right cerebral channel, and 0.92 percentage points in the third channel. Comparable clinical-step changes in FiO2 and temperature were smaller and less consistent. These findings identify EtCO2 as a major modifiable correlate of intraoperative cerebral oxygenation. They do not establish an optimal EtCO2 target or prove that EtCO2 manipulation improves outcomes.

## Introduction draft

Near-infrared spectroscopy gives anesthesiologists a continuous view of regional cerebral oxygenation during cardiac surgery. The monitor is clinically attractive because it changes before many downstream neurological outcomes can be observed, but the number itself is not self-explanatory. A fall in rSO2 may reflect changes in perfusion pressure, cardiac output, arterial oxygen content, cerebral metabolism, ventilation, temperature, sensor position, or several of these at once.

Carbon dioxide deserves separate attention. PaCO2 and EtCO2 affect cerebral blood flow through cerebrovascular reactivity, and EtCO2 is available continuously during anesthesia. In practice, however, EtCO2 is not a pure respiratory exposure. It also reflects ventilation-perfusion matching, pulmonary blood flow, and systemic perfusion. This makes EtCO2 clinically useful and analytically difficult: the same number can signal a ventilation change, a perfusion change, or both.

Prior studies have shown that manipulating carbon dioxide can alter cerebral oxygen saturation, but most used small samples, controlled gas challenges, selected surgical settings, or intermittent measurements. The missing piece is a high-frequency, adjusted description of the EtCO2-rSO2 relationship during the physiologically unstable period of off-pump coronary bypass surgery. We therefore modeled EtCO2 and tissue oxygenation continuously, using generalized additive models to estimate nonlinear relationships after adjustment for FiO2, temperature, hemodynamics, and patient factors.

## Results skeleton

### Analytic cohorts and intraoperative exposure range

The analytic cohorts included 1,792 patients for the left and right cerebral oxygenation channels and 1,789 patients for the third oxygenation channel. Before filtering, each channel contained about 20.6 million timestamp-level observations. After EtCO2 and tissue oxygenation exclusions, patient-level mean EtCO2 was approximately 30 mmHg. Mean patient-level rSO2 differed by channel, with lower values in the left and right cerebral channels and higher values in the third channel.

Required insertions before final draft:

- Exact final cohort counts after all exclusions.
- A cohort flow diagram.
- Baseline and intraoperative characteristics table.

### EtCO2 had the largest clinical-step association with cerebral oxygenation

The clinical-step analysis compared expected changes in rSO2 for common intraoperative changes in EtCO2, FiO2, and temperature. A 5 mmHg higher EtCO2 was associated with a 2.89 percentage-point increase in the left cerebral channel and a 2.98 percentage-point increase in the right cerebral channel. The corresponding estimate for the third channel was 0.92 percentage points. In the same analysis, FiO2 and temperature showed smaller and less consistent changes.

Suggested figure:

- `code/analysis_bundle/output/figures/figure_A_delta_bar.png`

Manuscript caution:

- Use "associated with", not "increased" or "improved", unless an intervention design is added.

### EtCO2-rSO2 curves were nonlinear and channel-specific

The adjusted EtCO2 curves showed a monotonic rise in rSO2 across much of the observed EtCO2 range, with wider uncertainty near the upper tail. The left and right cerebral channels showed similar curve shapes and effect sizes. The third channel had higher baseline oxygenation and a smaller EtCO2-associated change, suggesting site- or sensor-specific physiology.

Suggested figure:

- Use the EtCO2 panels from `figure_C_threshold_turning.png`, but crop or remake the figure so that panels with missing MAP/SV/HR/RR/TV/Pmean data are not shown as empty boxes in the main manuscript.

### Model diagnostics and covariate structure

The GAM used smooth terms for EtCO2, temperature, FiO2, MAP, and hemodynamic covariates, plus parametric patient-level factors. The current supplemental model-performance and term tables support the methods section, but the final manuscript needs a concise model diagnostics paragraph.

Required insertions before final draft:

- Deviance explained by channel from Supplementary Table 6.
- Effective degrees of freedom for EtCO2 and other key smooth terms from Supplementary Table 7.
- Bootstrap count and sampling design.

### Sensitivity analyses are incomplete

The repository currently contains planned sensitivity summaries, but the 5-model sensitivity output is marked as missing. This should be handled before submission in one of two ways:

- rerun and include sensitivity analyses; or
- remove those planned claims and present the paper as a primary adjusted model with clearly labeled exploratory cross-variable comparisons.

## Discussion draft

This analysis identifies EtCO2 as the dominant respiratory correlate of cerebral tissue oxygenation in high-frequency data from off-pump coronary bypass surgery. The estimated effect was clinically interpretable: a 5 mmHg higher EtCO2 corresponded to roughly a 3 percentage-point higher rSO2 in the left and right cerebral channels. The third channel showed a smaller association, which may reflect sensor location, tissue bed, or baseline oxygenation differences.

The finding is physiologically plausible. Carbon dioxide changes cerebrovascular tone, and controlled studies have shown graded cerebral oxygenation responses to carbon dioxide. Our analysis adds a different piece of evidence: the relationship remains visible in routine intraoperative data after adjustment for oxygen concentration, temperature, MAP, and hemodynamic covariates. This does not make EtCO2 a causal treatment target. It does suggest that EtCO2 should be considered when interpreting rSO2 changes during off-pump coronary bypass.

The smaller FiO2 and temperature associations help define the clinical meaning of the EtCO2 result. FiO2, temperature, and ventilation are all adjustable during anesthesia. In the current model, EtCO2 showed the largest and most consistent clinical-step association with left and right cerebral rSO2. That comparison may help clinicians prioritize the physiologic search when cerebral oxygenation falls, especially when arterial oxygen saturation is already high.

Several limits matter. EtCO2 is not PaCO2. It is affected by ventilation, dead space, pulmonary blood flow, and cardiac output, so residual confounding by perfusion cannot be eliminated. The study is observational and cannot identify an optimal EtCO2 range. The current analysis also lacks completed sensitivity runs and outcome endpoints. The manuscript should therefore make a physiologic claim, not a therapeutic claim: EtCO2 is a major, continuously available correlate of intraoperative cerebral oxygenation, and prospective studies are needed to test whether EtCO2-guided management improves patient outcomes.

## Methods adaptation from prior MAP/CI manuscript

Reusable from the prior supplementary methods:

- data preparation and imputation strategy;
- GAM framework;
- bootstrap resampling and uncertainty estimation;
- visualization of response curves and slopes;
- software and computing environment.

Must be rewritten:

- primary exposure is EtCO2, not MAP/CI;
- MAP and CI/hemodynamic variables become covariates or comparison variables;
- response surfaces should become EtCO2 response curves and clinical-step contrasts;
- slope tables should be EtCO2-zone specific rather than MAP/CI-zone specific, and should remain supplementary unless they add a clear clinical message.

## Nature-style language rules for this manuscript

Use:

- "We estimated..."
- "EtCO2 was associated with..."
- "The analysis does not establish..."
- "These data support..."

Avoid:

- "EtCO2 improves cerebral oxygenation"
- "optimal EtCO2 target"
- "causal effect"
- "novel and comprehensive"
- "significantly important"
