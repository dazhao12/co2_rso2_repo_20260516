# CO2-rSO2 manuscript development package

This folder converts the current CO2-rSO2 analysis into a manuscript draft using the prior MAP/CI tissue oxygenation manuscript as the structural template.

## Start here

1. `CO2_MANUSCRIPT_DRAFT_V1.docx`
   Word version of the current manuscript draft.

2. `CO2_MANUSCRIPT_DRAFT_V1.md`
   Editable Markdown source for the Word draft.

3. `CO2_SUBMISSION_GAP_CHECKLIST.md`
   Hard-stop checklist before calling the manuscript submission-ready.

4. `CO2_TABLES_AND_FIGURES_DRAFT.md`
   Draft main table, model diagnostics table, and figure plan using current result files.

5. `CO2_TABLE1_2_HPC_RUN_LOG.md`
   HPC run log for generated Table 1/2 outputs and verified preview values.

6. `CO2_SUPPLEMENTARY_METHODS_DRAFT.md`
   Draft supplementary methods adapted from the prior MAP/CI supplement and current CO2 scripts.

7. `CO2_SUPPLEMENTARY_TABLES_INDEX.md`
   Source-backed index for all main and supplementary tables.

8. `generated_assets/`
   Manuscript-ready tables, source data, and clean figure files generated from current analysis outputs.

9. `CO2_CHANNEL_NAMING_AUDIT.md`
   Evidence and adjudication for the current `rSO2_Ch3` label conflict.

10. `CO2_TABLE1_EXTRACTION_SPEC.md`
   HPC-oriented specification for generating CO2-specific Table 1 and intraoperative characteristics.

11. `CO2_MANUSCRIPT_BLUEPRINT.md`
   Full article logic, old MAP/CI-to-CO2 adaptation plan, and recommended display-item layout.

12. `CO2_PRIOR_MAPCI_FRAMEWORK_EXTRACT.md`
   Extracted structure, terminology, and table layout from the prior MAP/CI manuscript files.

13. `CO2_LITERATURE_AND_POSITIONING.md`
   Literature anchors and claim boundaries.

14. `CO2_NATURE_STYLE_DRAFT_SKELETON.md`
   Earlier prose skeleton retained for comparison.

15. `CO2_10_ROUND_MANUSCRIPT_REVIEW_LOG.md`
   Development log documenting the 10-round review and integration process.

16. `CO2_SENSITIVITY_DECISION.md`
   Current decision to exclude unavailable sensitivity analyses from the reported evidence package and avoid robustness claims.

17. `CO2_SEX_LABEL_AUDIT.md`
   Evidence supporting the manuscript-facing `Male, n (%)` label for the source-coded `SEX=1` Table 1 row.

## Current manuscript stance

The manuscript should currently be framed as a high-frequency observational physiology study:

> EtCO2 is a nonlinear, clinically available correlate of intraoperative cerebral tissue oxygenation during off-pump coronary bypass surgery, but the current analysis is observational and does not establish PaCO2-mediated causality or an EtCO2 treatment target.

Avoid therapeutic or causal claims. The current package also avoids robustness claims because the planned sensitivity-analysis result directories are unavailable.

## Immediate next actions

1. Replace author-side placeholders: author order, ethics, funding, competing interests, data availability, code availability, and author contributions.
2. Decide whether to run the planned 5-model sensitivity package before journal submission.
3. Remake the main figures without empty/missing all-intraop panels if figures are prioritized later.
4. Complete optional rendered DOCX page-level visual QA.

## Build the Word draft

Run from the repository root:

```powershell
& 'C:\Users\12080\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' docs\manuscript_development\build_manuscript_docx.py
```

The script reads `CO2_MANUSCRIPT_DRAFT_V1.md` and writes `CO2_MANUSCRIPT_DRAFT_V1.docx`.

## Generate manuscript tables and figures

Run from the repository root:

```powershell
& 'C:\Users\12080\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' docs\manuscript_development\generate_manuscript_assets.py
```

Main generated outputs:

- `generated_assets/table1_cohort_characteristics.xlsx`
- `generated_assets/supplementary_etable1_2_cohort_characteristics.xlsx`
- `generated_assets/table2_clinical_step_contrasts.xlsx`
- `generated_assets/supplementary_model_diagnostics.xlsx`
- `generated_assets/figure2_etco2_adjusted_curves.png`
- `generated_assets/figure3_clinical_step_contrasts.png`
- source-data CSV files for both figures.

## Generate CO2 Table 1/2 on HPC

After pushing the local script to the HPC repo, run on a compute node or inside the active Slurm job:

```bash
cd /N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516
source /N/project/waveform_mortality/ZhaoZhang/timesfm311/bin/activate
python code/manuscript_tables/build_table1_2_co2_rso2.py
```

Expected outputs are written under `results/manuscript_tables/`. A clean HPC run generated these files in `/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516_master_b5271a5/results/manuscript_tables`, and the output files are now available in the local mirror under `results/manuscript_tables/`.
