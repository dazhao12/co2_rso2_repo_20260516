# Supplementary Methods

*End-tidal carbon dioxide and tissue oxygenation during off-pump coronary bypass surgery*

## Study design and data source

This study was a secondary analysis of prospectively recorded intraoperative physiologic data from adults undergoing off-pump coronary artery bypass surgery. High-frequency time-series measurements were synchronized across intraoperative monitors and linked with patient-level baseline variables using available patient or stay identifiers.

Each analytic record represented a concurrent intraoperative timestamp containing end-tidal carbon dioxide (EtCO2), tissue oxygenation, and available covariates. Analyses were performed at the timestamp level, while cohort construction and descriptive summaries retained patient identifiers to document the number of contributing patients for each tissue oxygenation channel.

## Tissue oxygenation outcomes

Tissue oxygenation was analyzed separately for three monitoring channels: left cerebral tissue oxygen saturation (left SctO2; rSO2_Ch1), right cerebral tissue oxygen saturation (right SctO2; rSO2_Ch2), and forearm tissue oxygen saturation (SftO2; rSO2_Ch3). Each channel had an outcome-specific analytic cohort because missingness and signal availability differed by tissue bed.

For cohort entry, timestamps were required to have nonmissing EtCO2 and nonmissing tissue oxygenation for the modeled outcome channel. The third channel was treated as SftO2 according to the final manuscript-facing channel mapping.

## Exposure and covariates

The primary exposure was EtCO2, modeled as a continuous intraoperative variable in mmHg. EtCO2 was interpreted as a clinically available marker related to ventilation, perfusion, and carbon dioxide physiology, not as a direct replacement for arterial PaCO2.

The primary adjusted model included intraoperative fraction of inspired oxygen (FiO2), temperature, mean arterial pressure, and cardiac index. Patient-level covariates included age, body mass index, baseline cardiac index, baseline mean blood pressure, hemoglobin, sex, smoking status, drinking history, diabetes, hypertension, carotid artery disease, and statin use, subject to availability in the analytic data source.

Baseline tissue oxygenation covariates were handled to avoid direct outcome leakage. For a given tissue oxygenation outcome, baseline values representing the same tissue bed or closely related tissue oxygenation channels were excluded from that model rather than entered as adjustment covariates.

## Cohort construction and physiologic screening

Outcome-specific cohorts were constructed in a reproducible sequence. Timestamps first had to contain the primary exposure and the relevant outcome. Physiologic range checks were then applied to reduce the influence of signal artifacts and implausible monitor values.

The primary analytic EtCO2 range was greater than 20 mmHg and less than 50 mmHg. Tissue oxygenation values were retained when greater than 25% and less than 95%. Additional covariate range checks were applied before imputation: temperature 34.0 to 37.5 C, FiO2 30% to 100%, mean arterial pressure 20 to 160 mmHg, stroke volume 20 to 180 mL, heart rate 35 to 160 beats/min, and cardiac index 0.5 to 8.0 L/min/m2.

Values outside these ranges were masked as missing for covariate processing. EtCO2 and the modeled tissue oxygenation outcome were not imputed for cohort entry.

## Missing data handling

Dynamic intraoperative covariates were processed using an ordered imputation strategy designed to preserve time-series information while avoiding unnecessary case deletion. After physiologic screening, missing dynamic covariate values were first carried forward within patient after sorting by intraoperative time. Remaining gaps were filled with the patient-specific median when available, followed by the global cohort median for residual missingness.

Static continuous covariates were summarized and imputed using cohort medians when required. Static categorical covariates were encoded for modeling and imputed using the most frequent observed category when required. No imputed value was used to create eligibility for EtCO2 or the modeled tissue oxygenation outcome.

## Generalized additive model framework

Separate generalized additive models were fit for left SctO2, right SctO2, and SftO2. The models were specified to allow nonlinear exposure-response relationships between intraoperative physiologic variables and tissue oxygenation while adjusting for patient-level characteristics.

Continuous intraoperative predictors, including EtCO2, FiO2, temperature, mean arterial pressure, and cardiac index, were modeled with penalized spline smooth terms. Patient-level categorical covariates entered the model as parametric terms, and patient-level continuous covariates were included on their original clinical scales or after the preprocessing used by the modeling script.

In notation, each model estimated E[Y_c(t)] as a sum of smooth functions for the continuous intraoperative predictors and parametric terms for baseline covariates, where Y_c(t) denotes tissue oxygenation for channel c at timestamp t. Smoothness was controlled by the penalization procedures implemented in the archived Python modeling workflow.

## Clinical-step contrasts

Model-based clinical-step contrasts were used to summarize adjusted associations on clinically interpretable scales. The primary contrast was the adjusted difference in tissue oxygenation associated with a 5 mmHg higher EtCO2 across the final model-input range. Secondary descriptive contrasts used 5 percentage points for FiO2 and 0.5 C for temperature.

For each exposure and outcome channel, the model-input 5th to 95th percentile range was divided into 20 equal-width segments. The segment-specific adjusted curve slope was multiplied by the prespecified clinical increment, and the reported clinical-step summary was the median of these segment effects with the interquartile range across segments. This approach follows the manuscript display strategy while avoiding interpretation of a single local slope as a universal treatment effect.

## Bootstrap resampling and uncertainty estimation

The high-frequency dataset contained millions of timestamp-level observations, making fully specified covariance modeling computationally impractical. To estimate adjusted mean functions and their uncertainty, the archived workflow used repeated bootstrap model fitting on sampled timestamp-level analysis sets and generated prediction curves over the working exposure domains.

For each bootstrap replicate, the same model specification was refit and the adjusted prediction curve was stored. Mean curves and interval estimates were obtained by aggregating across bootstrap prediction curves. Percentile intervals were calculated from the empirical bootstrap distribution of predictions or derived clinical-step contrasts.

Because the archived bootstrap workflow was based on sampled timestamp-level prediction curves rather than a finalized patient-clustered bootstrap, uncertainty intervals should be interpreted as model-based uncertainty intervals. The analysis is observational and does not establish causal effects, PaCO2-mediated mechanisms, or an optimal EtCO2 treatment target.

## Software and reproducibility

Data preparation, model fitting, bootstrap prediction, clinical-step summaries, and manuscript display assets were generated using the archived CO2-rSO2 analysis repository. The final manuscript should cite the repository location, commit identifier, and the version of the modeling and table-generation scripts used for the submitted analysis.
