# CO2-rSO2 Nature-Style Readiness Audit

Date checked: 2026-06-09

Status: near-complete manuscript-development package, not final submission-ready.

Target-journal assumption: generic Nature Portfolio clinical observational manuscript. A journal-specific audit still requires the chosen target journal.

## Evidence Inspected

- Main manuscript: `docs/manuscript_development/CO2_MANUSCRIPT_DRAFT_V1.md` and `.docx`
- Supplementary methods: `docs/manuscript_development/CO2_SUPPLEMENTARY_METHODS_DRAFT.md` and `.docx`
- Supplementary tables index: `docs/manuscript_development/CO2_SUPPLEMENTARY_TABLES_INDEX.md` and `.docx`
- Generated manuscript assets: `docs/manuscript_development/generated_assets/`
- Table 1/2 source outputs: `results/manuscript_tables/`
- Supplemental eTables 3-8: `results/supplemental_etables/`
- Manuscript package zip: `docs/manuscript_development/package_outputs/CO2_rSO2_manuscript_development_package.zip`

## Structural QA

| Item | Evidence | Status |
| --- | --- | --- |
| Main manuscript DOCX opens as valid OOXML | `zipfile.testzip()` returned ok; 18 OOXML entries | passed structurally |
| Supplementary methods DOCX opens as valid OOXML | `zipfile.testzip()` returned ok; 18 OOXML entries | passed structurally |
| Supplementary tables index DOCX opens as valid OOXML | `zipfile.testzip()` returned ok; 18 OOXML entries | passed structurally |
| Main manuscript size | 99 paragraphs, 0 embedded tables, approximately 3,168 whitespace-delimited words | adequate for draft review |
| Supplementary methods size | 70 paragraphs, 2 tables, approximately 1,130 whitespace-delimited words | adequate framework |
| Supplementary tables index size | 11 paragraphs, 2 tables, approximately 82 whitespace-delimited words | concise source index |
| Rendered visual QA | LibreOffice DOCX-to-PDF conversion timed out for the main manuscript; no PDF/PNG output was produced | not passed |

The DOCX files are structurally readable, but the required page-level visual review is still incomplete because LibreOffice conversion did not finish in the current Windows Codex session. Do not describe the DOCX package as visually QA-passed until conversion succeeds and page images are inspected.

## Manuscript Completeness

| Requirement | Current evidence | Readiness |
| --- | --- | --- |
| Observational physiology framing | Title, Abstract, Discussion, Conclusion all state association and interpretation rather than treatment effect | ready |
| Terminology consistency | Main draft uses EtCO2, left SctO2, right SctO2, and SftO2; `rSO2_Ch3` is mapped to SftO2 | ready |
| Main estimates | Table 2 asset has 9 rows and reports EtCO2, FiO2, and temperature contrasts by channel | ready |
| Table 1 cohort evidence | Table 1 asset has 19 rows and 4 columns; cohorts are left SctO2, right SctO2, and SftO2 | ready |
| Source data | Package zip contains 52 entries including `PACKAGE_MANIFEST.md`; manifest records build date 2026-06-09, branch `master`, source commit `2b8d3ba`, dirty status `no` | ready for development handoff |
| References | Seven references are listed in the main draft and separately documented in `CO2_REFERENCE_AUDIT.md` | traceable draft set |
| Supplementary methods | Cohort construction, variables, artifact ranges, missing-data handling, GAM description, contrasts, and sensitivity status are described | framework ready |
| Supplementary table index | eTables 1/2 and 3-8 are indexed with source files and status | framework ready |
| Author and regulatory statements | Main draft still has placeholders for authors, correspondence, ethics, funding, competing interests, contributions, data availability, code availability, and acknowledgements | not ready |
| Display item insertion | Main manuscript still has bracketed insertion notes for Table 1, Figures 1-4, and Table 2 | not ready as a final Word submission |
| Bootstrap/inference wording | Draft states model-based uncertainty and flags patient-clustered bootstrap details as pending | scientifically cautious but incomplete |
| Sensitivity analyses | Current package explicitly excludes sensitivity analyses because planned result directories are missing | acceptable only if the target journal accepts a narrower physiology paper |

## Table Readiness Against Nature-Style Expectations

| Table asset | Current shape | Nature-style status |
| --- | ---: | --- |
| `table1_cohort_characteristics.csv` | 19 rows x 4 columns | concise content ready; final Word table formatting still pending |
| `table2_clinical_step_contrasts.csv` | 9 rows x 5 columns | content ready; CI formatting should use the target journal's preferred punctuation in final layout |
| `supplementary_etable1_2_cohort_characteristics_long.csv` | 159 rows x 5 columns | appropriate as supplementary source/Excel material |
| `supplementary_model_diagnostics.csv` | 3 rows x 7 columns | appropriate for supplementary methods or supplement |

Nature-style table formatting still needs final layout work if the tables are embedded in a Word submission: no vertical rules, no colour in main-text tables, concise sentence-case titles, clear legends above tables, abbreviation definitions, and consistent numeric precision.

## Current Hard Stops Before Submission

1. Confirm author list, author order, affiliations, ORCID identifiers, and correspondence.
2. Confirm ethics approval, consent or waiver wording, study dates, and whether the Bottomline-CS parent-cohort language applies exactly to the CO2 analysis.
3. Confirm funding, competing interests, author contributions, acknowledgements, data availability, and code availability.
4. Decide whether to complete the planned 5-model sensitivity analyses before submission.
5. Replace display-item insertion notes with final tables, figures, captions, and legends in the Word manuscript.
6. Complete target-journal reference styling and figure/source-data naming.
7. Re-run DOCX visual QA after resolving the LibreOffice conversion timeout.

## Editorial Judgment

The current package is strong enough for expert coauthor review. It has a coherent central claim: EtCO2 is a nonlinear, clinically interpretable correlate of intraoperative cerebral tissue oxygenation during off-pump coronary bypass, with a smaller association in forearm tissue. The draft avoids causal language and does not claim an EtCO2 treatment target.

It is not yet a final submission package. The remaining gaps are mostly author-side statements, final Word display-item integration, journal-specific formatting, sensitivity-analysis choice, and rendered DOCX visual QA.
