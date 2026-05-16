#!/bin/bash
set -euo pipefail

cd /N/project/waveform_mortality/ZhaoZhang/contour_zhao_all_9_15_2025/analysis_crossvar_bundle_20260513
mkdir -p output/logs

python3 - <<'PY'
import csv, subprocess
from datetime import datetime
from pathlib import Path

matrix = Path('code/sensitivity5_run_matrix.csv')
out = Path('output/logs') / f"sensitivity5_job_ids_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"

rows_out = []
with matrix.open('r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for r in reader:
        if int(r.get('enabled', '0')) != 1:
            continue
        run_key = r['run_key'].strip()
        outdir_tag = r['outdir_tag'].strip()
        intraop = r.get('intraop_smooth_covars', '').strip()
        cmd = [
            'sbatch',
            '--job-name', f'sens_{run_key}',
            '--export', f'ALL,RUN_KEY={run_key},OUTDIR_TAG={outdir_tag},INTRAOP_SMOOTH_COVARS={intraop}',
            'code/submit_one_sensitivity_modelB.sbatch',
        ]
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, check=True)
        txt = (p.stdout or '').strip()
        job_id = txt.split()[-1] if txt else ''
        print(f'submitted {run_key} => {job_id}')
        rows_out.append({
            'run_key': run_key,
            'outdir_tag': outdir_tag,
            'intraop_smooth_covars': intraop,
            'job_id': job_id,
        })

with out.open('w', encoding='utf-8', newline='') as f:
    w = csv.DictWriter(f, fieldnames=['run_key','outdir_tag','intraop_smooth_covars','job_id'])
    w.writeheader()
    w.writerows(rows_out)
print(f'job list: {out}')
PY
