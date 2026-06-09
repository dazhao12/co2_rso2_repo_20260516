# CO2-rSO2 Manuscript Review Log

Date: 2026-06-08

This log records the manuscript-development rounds used to convert the current CO2-rSO2 analysis into an English manuscript package. It is a development record, not a journal supplement.

## Round 1. Project evidence audit

Reviewed manuscript-development files, generated assets, supplemental eTables, model-output summaries, and the Table 1/2 HPC run log. Current evidence supports approximately 1,800 patients and more than 20 million usable timestamp-level observations per tissue oxygenation channel after outcome-specific filtering. The main interpretable estimates are the clinical-step EtCO2 contrasts: +2.89 percentage points for left SctO2, +2.98 for right SctO2, and +0.92 for SftO2 per 5 mmHg higher EtCO2.

## Round 2. Prior MAP/CI framework extraction

The prior MAP/CI manuscript structure was used for article architecture: title page, abstract, Introduction, Methods, Results, Discussion, references, author-side statements, supplemental methods, and supplemental tables. The old wording was not mechanically reused because the CO2 analysis has a different exposure, different model outputs, and a narrower observational physiology claim.

## Round 3. Core argument and title

Current title: "End-tidal carbon dioxide and regional tissue oxygenation during off-pump coronary bypass." The center of the paper is that EtCO2 is a continuously available, nonlinear, adjusted correlate of cerebral tissue oxygenation during OPCAB, with a smaller forearm association. The paper does not claim an EtCO2 treatment target or outcome benefit.

## Round 4. Main manuscript drafting

The main manuscript draft now includes a complete Abstract, Introduction, Methods, Results, Discussion, Conclusion, traceable reference list, and author-side placeholder list. Results use current cohort counts, Table 1/2 preview values from the HPC run, clinical-step effect estimates, and model diagnostics from existing outputs.

## Round 5. Discussion revision

The Discussion was rewritten around seven claims: principal finding, biological plausibility, tissue-bed specificity, clinical scale versus FiO2 and temperature, relationship to prior carbon dioxide and NIRS studies, interpretation boundary, and prospective-study needs. Causal language was reduced after review.

## Round 6. Supplementary methods and table framework

The supplementary methods now describe cohort construction, channel mapping, exposure definition, current covariate set, clipping, imputation, generalized additive models, clinical-step contrasts, model-based uncertainty, and reproducibility requirements. The supplementary table index maps eTables 1/2 through 8 to current sources and status. Sensitivity analyses are not reported in the current evidence package.

## Round 7. Literature integration

The reference list includes traceable sources supporting cardiac-surgery NIRS monitoring, graded carbon dioxide responses, EtCO2-rSO2 modeling in carotid endarterectomy, cardiac-surgery PaCO2/NIRS work, mild hypercapnia trials, the 2024 off-pump CABG pilot trial, and the Bottomline-CS parent trial. References still require final journal formatting and author confirmation.

## Round 8. Nature-style language pass

The draft was edited to remove inflated claims, formulaic transitions, repeated three-adjective constructions, and treatment-target language. The Abstract now states that EtCO2 is not a direct substitute for PaCO2 and does not establish causality, an optimal target, or benefit from manipulation.

## Round 9. Statistical boundary pass

The manuscript and supplement now state that clinical-step contrasts come from the 10,000-row `map_ci_te` analysis run and archived bootstrap prediction matrices. Current intervals should be treated as model-based uncertainty intervals unless a patient-level bootstrap is finalized. The planned 5-model sensitivity outputs are unavailable, so the current manuscript does not report sensitivity analyses and does not make a robustness claim.

## Round 10. Remaining submission gates

The package is close to a manuscript-development draft but not submission-ready. Remaining gates are: confirmed author list and affiliations, ethics and consent wording, funding and competing interests, author contributions, data/code availability, optional sensitivity rerun before journal submission, final figure formatting, journal-specific reference formatting, and optional rendered DOCX page-level visual QA. `CO2_AUTHOR_SUBMISSION_STATEMENTS_TEMPLATE.md` now centralizes the author-side fields that must be filled from confirmed project information. The source-coded `SEX=1` row is supported as male in manuscript-facing tables by `CO2_SEX_LABEL_AUDIT.md`.
