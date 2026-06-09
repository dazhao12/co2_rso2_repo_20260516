# CO2 Table 1/2 HPC Run Log

Status: generated on HPC and pulled into the local mirror.

## Run context

- Date: 2026-06-08
- Compute node/job: `g24`, Slurm job `9433432`
- Clean worktree used for run: `/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516_master_b5271a5`
- Commit: `b5271a5`
- Python environment: `/N/project/waveform_mortality/ZhaoZhang/timesfm311`
- Command:

```bash
cd /N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516_master_b5271a5
source /N/project/waveform_mortality/ZhaoZhang/timesfm311/bin/activate
python code/manuscript_tables/build_table1_2_co2_rso2.py
```

## Remote outputs

Remote output directory:

```text
/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516_master_b5271a5/results/manuscript_tables
```

Generated files:

- `table1_2_co2_rso2.xlsx`
- `table1_2_co2_rso2_available_columns.csv`
- `table1_2_co2_rso2_flow_counts.csv`
- `table1_2_co2_rso2_long.csv`
- `table1_2_co2_rso2_wide.csv`

Observed file sizes on HPC:

- `table1_2_co2_rso2.xlsx`: 14K
- `table1_2_co2_rso2_available_columns.csv`: 993 bytes
- `table1_2_co2_rso2_flow_counts.csv`: 1.1K
- `table1_2_co2_rso2_long.csv`: 12K
- `table1_2_co2_rso2_wide.csv`: 5.7K

## Local mirror

The files were transferred to the local repository on 2026-06-08:

```text
results/manuscript_tables/
```

Local files:

- `table1_2_co2_rso2.xlsx`
- `table1_2_co2_rso2_available_columns.csv`
- `table1_2_co2_rso2_flow_counts.csv`
- `table1_2_co2_rso2_long.csv`
- `table1_2_co2_rso2_wide.csv`

## Verified preview

The generated flow-count file reported:

| Outcome | Raw rows | Raw patients | Final usable rows | Final patients |
| --- | ---: | ---: | ---: | ---: |
| `rSO2_Ch1` / Left SctO2 | 25,385,328 | 1,872 | 20,021,703 | 1,792 |
| `rSO2_Ch2` / Right SctO2 | 25,385,328 | 1,872 | 20,075,597 | 1,792 |
| `rSO2_Ch3` / SftO2 | 25,385,328 | 1,872 | 20,068,759 | 1,789 |

The generated wide Table 1/2 preview reported the following baseline values:

| Characteristic | Left SctO2 | Right SctO2 | SftO2 |
| --- | ---: | ---: | ---: |
| Age, mean (SD), years | 68.7 (5.3) | 68.7 (5.3) | 68.7 (5.3) |
| BMI, mean (SD), kg/m2 | 25.3 (3.2) | 25.3 (3.2) | 25.3 (3.2) |
| Cardiac index, mean (SD), L/min/m2 | 2.5 (0.8) | 2.5 (0.8) | 2.5 (0.8) |
| Mean blood pressure, mean (SD), mmHg | 90.0 (12.4) | 90.0 (12.4) | 89.9 (12.4) |
| Hemoglobin, mean (SD), g/L | 132.1 (15.5) | 132.1 (15.5) | 132.1 (15.5) |
| Diabetes, n (%) | 770 (43.0%) | 770 (43.0%) | 768 (42.9%) |
| Hypertension, n (%) | 1,316 (73.4%) | 1,316 (73.4%) | 1,313 (73.4%) |
| Drinking history, n (%) | 458 (25.6%) | 458 (25.6%) | 458 (25.6%) |

## Archived transfer commands

The files are now available locally. The commands below are retained only as transfer provenance:

```powershell
scp -F "C:\Users\12080\.ssh\config.backup" -r `
  iu-quartz:/N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516_master_b5271a5/results/manuscript_tables `
  E:\BaiduSyncdisk\desktop_5_15\01_科研项目\GAM_CO2_SctO2_4_19_2026\co2_rso2_repo_20260516\results\
```

If `scp` is unstable in a future rerun, use a single SSH tar stream:

```powershell
ssh -F "C:\Users\12080\.ssh\config.backup" iu-quartz `
  "cd /N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516_master_b5271a5 && tar -czf - results/manuscript_tables" `
  > C:\tmp\co2_table1_2_zz86.tgz
tar -xzf C:\tmp\co2_table1_2_zz86.tgz -C E:\BaiduSyncdisk\desktop_5_15\01_科研项目\GAM_CO2_SctO2_4_19_2026\co2_rso2_repo_20260516
```
