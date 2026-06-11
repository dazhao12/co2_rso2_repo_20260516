# CO2-rSO2 manuscript text sources

This folder keeps manuscript text in Markdown as the working source format.

## Active text files

- `CO2_MANUSCRIPT_DRAFT_V1.md`: main manuscript text source.
- `CO2_SUPPLEMENTARY_METHODS_DRAFT.md`: supplementary methods text source.
- `CO2_SUPPLEMENTARY_TABLES_INDEX.md`: supplementary table index text source.

## Current editing rule

Text-related manuscript edits should be made in `.md` first because Markdown is easier to track, compare, and review in Git.

Word files are not the active editing source for now. Existing `.docx` versions were moved to:

`archive/word_versions_20260611/`

## Archived materials

- Development logs, audits, checklists, build scripts, source-data notes, and extraction plans:
  `archive/development_materials_20260611/`
- Older Markdown-source archive:
  `archive/markdown_sources_20260611/`

## Generated deliverables

Generated DOCX, PDF, table, figure, and package outputs should stay under:

`../../outputs_local/`

When a Word file is needed for sharing or submission, regenerate it from the current Markdown source and save the generated version outside the active text-source root unless explicitly requested.
