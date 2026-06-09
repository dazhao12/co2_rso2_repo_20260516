# CO2-rSO2 Sensitivity Analysis Decision

Date: 2026-06-08

## Current evidence

The current sensitivity summary file is:

```text
code/analysis_bundle/output/tables/etco2_sensitivity_5model_summary.csv
```

It contains 15 planned rows:

- 5 planned model variants
- 3 outcome channels per variant
- status for every row: `missing_result_dir`

The planned variants are:

- `base`
- `rrtotal_only`
- `tvinsp_only`
- `pmean_only`
- `all_three`

## Manuscript decision

The current manuscript package does not report sensitivity-analysis results and does not make a robustness claim across alternative ventilatory or hemodynamic specifications.

This is the safest current manuscript posture because no completed sensitivity result directories are available in the local evidence package. The main manuscript therefore reports the primary `map_ci_te` clinical-step analysis and model diagnostics only.

## How this is reflected in the package

- The main manuscript no longer has a Results subsection titled "Sensitivity analyses remain incomplete."
- The Discussion states the observational and model-scope limits without claiming robustness.
- The Supplementary Methods state that no sensitivity analyses are reported in the current evidence package.
- The submission gap checklist retains sensitivity analysis as a pre-submission decision.

## Future options

Before final journal submission, choose one:

1. Run and include the planned 5-model sensitivity analyses, then add a supplementary sensitivity table.
2. Keep the current narrower manuscript scope and submit without a robustness claim, provided the target journal accepts the physiology-focused evidence package.

If option 1 is chosen, sensitivity outputs should use the same channel terminology as the main manuscript:

- `rSO2_Ch1`: left SctO2
- `rSO2_Ch2`: right SctO2
- `rSO2_Ch3`: SftO2
