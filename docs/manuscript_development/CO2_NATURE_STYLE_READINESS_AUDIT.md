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
| Main manuscript display items | Review-ready DOCX contains 2 embedded tables and 4 embedded figures; no Table/Figure insertion placeholders remain in the DOCX | passed for coauthor review |
| Main manuscript size | 116 paragraphs, 2 embedded tables, 4 embedded figures | adequate for draft review |
| Supplementary methods size | 70 paragraphs, 2 tables, approximately 1,130 whitespace-delimited words | adequate framework |
| Supplementary tables index | Journal-facing review index with eTable purpose, key contents, status, main-display linkage, and source traceability | ready for coauthor review |
| Rendered visual QA | Windows-compatible DOCX renderer produced 12 main-manuscript pages, 5 supplementary-methods pages, and 3 supplementary-table-index pages under local `docs/manuscript_development/render_qa/*_review_ready/`; all rendered pages were nonblank by pixel check | passed for review-ready artifacts |

The DOCX files are structurally readable and visually renderable in the current Windows Codex session through the compatibility renderer. Manual inspection of representative main-manuscript pages found the title page, Table 1, Figure 1, Table 2 continuation, Figure 3, Figure 2, and declarations pages readable without obvious clipping or overlap. Rendered PNG/PDF files are treated as local QA intermediates and are intentionally not versioned. The local-slope plot is now treated as a supplementary model-shape display rather than a main-text figure. The supplementary tables index now uses short journal-facing table descriptions, with exact repository paths moved to a traceability section.

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
| Display item insertion | Main manuscript DOCX now embeds Table 1, Figure 1, Table 2, Figure 3, and Figure 2 from generated assets; the local-slope plot is retained as a supplementary display | ready for coauthor review |
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
5. Complete target-journal reference styling and figure/source-data naming.
6. Convert the supplementary table plan into final target-journal captions or workbook tab names after the journal is chosen.

## Editorial Judgment

The current package is strong enough for expert coauthor review. It has a coherent central claim: EtCO2 is a nonlinear, clinically interpretable correlate of intraoperative cerebral tissue oxygenation during off-pump coronary bypass, with a smaller association in forearm tissue. The draft avoids causal language and does not claim an EtCO2 treatment target.

It is not yet a final submission package. The remaining gaps are mostly author-side statements, final Word display-item integration, journal-specific formatting, sensitivity-analysis choice, and rendered DOCX visual QA.
