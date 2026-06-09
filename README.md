# CO2-rSO2 Organized Workspace (2026-05-16)

This repository is a clean, standalone workspace split from:
`/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025`

## Goal
- Keep CO2 vs rSO2 code and key outputs in one place.
- Preserve legacy folder untouched.
- Maintain a clean Git history for cloud sync.

## Structure
- `code/`: analysis, modeling, plotting, and table-building code only.
- `docs/`: documentation, manuscript drafts, and project notes.
- `scripts/`: sync and maintenance scripts.
- `outputs_local/`: local generated outputs, including data extracts, tables, figures, PPT/DOCX exports, and QA renders. This directory is ignored by Git.

## Git Workflow
- Main branch: `master`
- Recommended cycle:
  1. `git checkout master`
  2. `bash scripts/sync_from_legacy.sh` (optional incremental refresh)
  3. `git status`
  4. `git add -A && git commit -m "..."`
  5. `git push origin master`

## Notes
- Legacy data remains in the original folder.
- Generated tables, data, figures, presentations, and document exports should stay under `outputs_local/` unless explicitly selected for submission or sharing.
