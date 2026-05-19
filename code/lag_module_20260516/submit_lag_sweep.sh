#!/usr/bin/env python3
import argparse
import csv
import subprocess
from datetime import datetime
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description="Submit lag sweeps to Slurm")
    parser.add_argument("--model", choices=["A", "B", "both"], default="B", help="Model type: A (map_ci_te) or B (map_sv_smooth) or both (default: B)")
    parser.add_argument("--boot", type=int, default=200, help="Number of bootstrap resamples (default: 200)")
    parser.add_argument("--subsample", type=int, default=10000, help="Subsample size (default: 10000)")
    parser.add_argument("--validate", action="store_true", help="Shortcut for --boot 2 to perform quick validation run")
    args = parser.parse_args()

    boot = 2 if args.validate else args.boot
    models = ["map_ci_te", "map_sv_smooth"] if args.model == "both" else (["map_ci_te"] if args.model == "A" else ["map_sv_smooth"])

    ws = Path(__file__).resolve().parent
    matrix_fp = ws / 'lag_run_matrix.csv'
    out_dir = ws / 'output' / 'logs'
    out_dir.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_fp = out_dir / f'lag_job_ids_{timestamp}.csv'

    rows_out = []
    lags = []
    with matrix_fp.open('r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for r in reader:
            if int(r.get('enabled', '0')) == 1:
                lags.append((r['run_key'].strip(), int(r['lag_seconds'])))

    for hemo in models:
        model_label = "modelA" if hemo == "map_ci_te" else "modelB"
        for run_key, lag_seconds in lags:
            outdir_tag = f"lag{lag_seconds}_{model_label}_n{args.subsample}_b{boot}"
            job_name = f"lag_{lag_seconds}s_{model_label}"
            
            cmd = [
                'sbatch',
                '--job-name', job_name,
                '--export', f'ALL,LAG_SECONDS={lag_seconds},HEMO_ADJUST={hemo},N_BOOT={boot},SUBSAMPLE_SIZE={args.subsample},OUTDIR_TAG={outdir_tag}',
                'submit_one_lag.sbatch',
            ]
            
            p = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                check=True,
                cwd=str(ws)
            )
            txt = (p.stdout or '').strip()
            job_id = txt.split()[-1] if txt else ''
            print(f'Submitted {run_key} ({model_label}, lag={lag_seconds}s) => Slurm Job ID: {job_id}')

            rows_out.append({
                'model': model_label,
                'run_key': run_key,
                'lag_seconds': lag_seconds,
                'outdir_tag': outdir_tag,
                'job_id': job_id,
            })

    with out_fp.open('w', encoding='utf-8', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['model', 'run_key', 'lag_seconds', 'outdir_tag', 'job_id'])
        w.writeheader()
        w.writerows(rows_out)
    
    print(f'Sweep submission list saved to: {out_fp}')

if __name__ == '__main__':
    main()
