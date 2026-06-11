# CO2-rSO2 Manuscript Package Index

Date prepared: 2026-06-09

Status: manuscript-development package. This package is organized for review, coauthor editing, and target-journal preparation, but it is not a final submission-ready package.

## Output

The package builder writes:

```text
docs/manuscript_development/package_outputs/CO2_rSO2_manuscript_development_package.zip
```

The zip contains an internal `PACKAGE_MANIFEST.md` with the build date, git branch, git commit, working-tree status, included file list, file sizes, and SHA-256 prefixes.

## Build Command

Run from the repository root:

```powershell
& 'C:\Users\12080\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' docs\manuscript_development\build_manuscript_package.py
```

The script only packages existing repository outputs. It does not fit models, train anything, or read patient-level raw data beyond already generated manuscript assets.

## Included Groups

- `main/`: current manuscript draft in DOCX and Markdown.
- `supplement/`: supplementary methods and supplementary tables index in DOCX and Markdown.
- `tables/`: manuscript-facing tables, source table workbooks, supplemental eTables 3-8, and model diagnostics.
- `figures/`: current manuscript-development PNG/SVG figure assets.
- `source_data/`: source-data CSV files for the main figures.
- `documentation/`: audits, source-data index, sensitivity decision, author statement template, literature positioning, and development logs.

## Current Limits

- Author, ethics, funding, competing-interest, data-availability, code-availability, contribution, and acknowledgement statements still require confirmed author-side information.
- The planned 5-model EtCO2 sensitivity package is not reported because the result directories are unavailable.
- Final journal submission still needs target-journal figure sizing, reference styling, source-data upload formatting, and rendered DOCX visual QA.
