# CO2-rSO2 Organized Workspace (2026-05-16)

This repository is a clean, standalone workspace split from:
`/N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025`

## Goal
- Keep CO2 vs rSO2 code and key outputs in one place.
- Preserve legacy folder untouched.
- Maintain a clean Git history for cloud sync.

## Structure
- `code/python/`: upstream modeling and submission scripts.
- `code/r/`: PPT/plot R scripts.
- `code/analysis_bundle/`: cross-variable analysis and sensitivity/mediation scripts.
- `results/model_runs/`: key run outputs (overall/subgroup/modelB n10000).
- `results/fig_output/`: key figure/PPT output folders.
- `docs/`: metadata and migration notes.
- `scripts/`: sync/maintenance scripts.

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
- This repo only includes selected key outputs to keep versioning manageable.
