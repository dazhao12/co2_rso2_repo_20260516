#!/bin/bash
set -euo pipefail

cd /N/project/waveform_mortality/ZhaoZhang/co2_rso2_repo_20260516/code/lag_module_20260516
mkdir -p output/logs output/tables output/figures

python3 - << 'PY'
import csv
import subprocess
from datetime import datetime
from pathlib import Path

matrix_fp = Path('lag_run_matrix.csv')
out_fp = Path('output/logs') / f'lag_job_ids_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'

rows_out = []
with matrix_fp.open('r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for r in reader:
        if int(r.get('enabled', '0')) != 1:
            continue
        run_key = r['run_key'].strip()
        lag_seconds = int(r['lag_seconds'])
        outdir_tag = r['outdir_tag'].strip()

        cmd = [
            'sbatch',
            '--job-name', f'lag_{lag_seconds}s',
            '--export', f'ALL,LAG_SECONDS={lag_seconds},OUTDIR_TAG={outdir_tag}',
            'submit_one_lag_modelB.sbatch',
        ]
        p = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            check=True,
        )
        txt = (p.stdout or '').strip()
        job_id = txt.split()[-1] if txt else ''
        print(f'submitted {run_key} (lag={lag_seconds}s) => {job_id}')

        rows_out.append({
            'run_key': run_key,
            'lag_seconds': lag_seconds,
            'outdir_tag': outdir_tag,
            'job_id': job_id,
        })

with out_fp.open('w', encoding='utf-8', newline='') as f:
    w = csv.DictWriter(f, fieldnames=['run_key', 'lag_seconds', 'outdir_tag', 'job_id'])
    w.writeheader()
    w.writerows(rows_out)

print(f'job list: {out_fp}')
PY
