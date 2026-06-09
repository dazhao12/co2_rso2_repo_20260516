# CO2-rSO2 Sex Label Audit

Date: 2026-06-08

## Question

Can the Table 1 source-coded row `SEX=1, n (%)` be relabelled as `Male, n (%)` in manuscript-facing tables?

## Current evidence

The current CO2 analysis code defines sex subgroups as:

```text
Male: Sex == 1
Female: Sex == 0
```

This mapping appears in both the primary analysis script and the archived analysis-bundle script:

- `code/python/contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95.py`
- `code/analysis_bundle/code/contour_5_6_2026_rev2_20260506_co2tempfio2_main_hemo_adj_boot20_rso2_25_95_slicevars.py`

The model-run subgroup cache also records the same mapping:

```text
Male: Sex == 1
Female: Sex == 0
```

In `results/model_runs/v5_6_2026_rev2_20260506_co2tempfio2_hemo_adj_boot20_rso2_25_95_full_20260513_154630_subgroup_modelB_sec1_n10000_boot200_rowreplace/pool_cache_summary.csv`, the male subgroup patient counts are 1,255, 1,255, and 1,254 for the left SctO2, right SctO2, and SftO2 analytic cohorts. These match the Table 1 source-coded `SEX=1` counts.

## Decision

For manuscript-facing tables, relabel the row as:

```text
Male, n (%)
```

The raw source table files under `results/manuscript_tables/` can retain `SEX, n (%)` as a source-code label. Generated manuscript assets under `docs/manuscript_development/generated_assets/` should use the journal-facing `Male, n (%)` label.

## Remaining caution

This audit is based on the current analysis code and model-run outputs. If an external data dictionary later contradicts this mapping, update the generated manuscript tables and this audit before submission.
