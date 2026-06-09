# Prior MAP/CI Manuscript Framework Extract

Source files reviewed:

- `MAP_CI_Tissue O2_Manuscript_Clean_R4_5_21_2026.docx`
- `MAP_CI_Tissue O2_Supplemental Digital Content_R4_5_21_2026.docx`
- `MAP_CI_Tissue O2_Supplementary methods_R2_3_11_2026.docx`
- `MAP_CI_Tissue O2_Table 1_R3_5_5_2026.docx`

## Reusable article architecture

The prior MAP/CI manuscript uses this sequence:

1. Title page, authors, affiliations, correspondence, funding, conflicts, author contributions.
2. Word/element counts.
3. Data/code availability.
4. Abbreviations.
5. Summary statement.
6. Structured abstract: Background, Methods, Results, Conclusions.
7. Keywords.
8. Introduction: clinical problem, physiologic rationale, analytic gap, study aim.
9. Methods: study design, setting, participants, variables, data processing, data source, study size, statistical analysis.
10. Results: cohort/data size, adjusted model outputs, clinically interpretable slices/contrasts, subgroup analyses.
11. Discussion: principal finding, clinical interpretation, trial-context caution, physiologic plausibility, limitations.

The CO2 manuscript should follow this structure but simplify the Results around EtCO2-focused contrasts and curves rather than MAP-CI response surfaces.

## Parent cohort language to adapt

The prior manuscript describes the data source as a prespecified secondary analysis of prospectively recorded intraoperative data from the Bottomline-CS randomized, assessor-blinded, single-center trial of elective off-pump coronary artery bypass surgery at Tianjin Chest Hospital, with ClinicalTrials.gov registration `NCT04896736`.

The prior setting paragraph gives the study dates as 8 June 2021 to 27 December 2023.

For the CO2 manuscript, this language can be reused only if the final CO2 cohort is confirmed to derive from the same parent trial and dates.

## Channel terminology from prior manuscript

The prior manuscript defines:

- `SctO2`: cerebral tissue oxygen saturation
- `SftO2`: forearm tissue oxygen saturation
- outcomes: left cerebral tissue oxygen saturation, right cerebral tissue oxygen saturation, and forearm tissue oxygen saturation

The prior supplementary methods state that tissue oxygenation was modeled separately as left cerebral tissue oxygen saturation, right SctO2, and forearm tissue oxygen saturation.

This supports the old MAP/CI framework using a forearm third tissue bed. Together with the current CO2 model and plotting scripts, it supports using SftO2 as the manuscript label for `rSO2_Ch3`. The earlier `Frontal SctO2 cohort` label in CO2 eTables 3-5 has been corrected in the local manuscript package.

## Prior supplement table structure

The prior Supplemental Digital Content used:

- eTable 1: intraoperative management characteristics in the left cerebral tissue oxygen saturation analytic cohort.
- eTable 2: baseline patient characteristics in the left cerebral tissue oxygen saturation analytic cohort.
- eTable 3: timestamp-level outlier exclusions in the left cerebral, right cerebral, and forearm tissue oxygen saturation analytic cohorts.
- eTable 4: missingness and imputation of intraoperative time-varying covariates.
- eTable 5: patient-level summary of intraoperative MAP, CI, and tissue oxygenation.
- eTables 6-8: GAM model performance, nonparametric terms, and parametric terms.

The CO2 supplement should preserve this logic but replace MAP-CI-specific displays with EtCO2-focused artifact, missingness, patient-level, model-performance, nonparametric-term, and parametric-term tables.

## Prior main-results style to adapt

The prior manuscript avoids claiming treatment targets. It presents model-derived relationships as physiologic interpretation, uses clinically interpretable slices, and states that observed slope changes may reflect physiology but should not be read as practice-changing intervention evidence.

The CO2 manuscript should use the same caution:

- Say `associated with`, `adjusted difference`, or `model-estimated`.
- Do not say EtCO2 manipulation improves rSO2 or outcomes.
- Do not identify an optimal EtCO2 target from this observational analysis.
- Frame findings as an interpretation aid for intraoperative tissue oxygenation signals.
