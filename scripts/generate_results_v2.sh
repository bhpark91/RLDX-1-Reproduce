#!/usr/bin/env bash
set -euo pipefail
: "${RLDX_ROOT:?Set RLDX_ROOT to your upstream RLDX-1 checkout}"
RLDX_ROOT=$(cd "$RLDX_ROOT" && pwd)
export OUTPUT_ROOT="${OUTPUT_ROOT:-$RLDX_ROOT/output_final/robocasa/reproduce_v2}"
export RESULTS_CSV="${RESULTS_CSV:-$RLDX_ROOT/results_v2.csv}"
python3 - <<'PYTHON'
import csv
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

TASKS = ['TurnSinkSpout', 'TurnOnStove', 'TurnOnSinkFaucet', 'TurnOnMicrowave', 'TurnOffStove', 'TurnOffSinkFaucet', 'TurnOffMicrowave', 'PnPStoveToCounter', 'PnPSinkToCounter', 'PnPMicrowaveToCounter', 'PnPCounterToStove', 'PnPCounterToSink', 'PnPCounterToMicrowave', 'PnPCounterToCab', 'PnPCabToCounter', 'OpenSingleDoor', 'OpenDrawer', 'OpenDoubleDoor', 'CoffeeSetupMug', 'CoffeeServeMug', 'CoffeePressButton', 'CloseSingleDoor', 'CloseDrawer', 'CloseDoubleDoor']
root = Path(os.environ['OUTPUT_ROOT']).resolve()
dest = Path(os.environ['RESULTS_CSV']).resolve()
if not root.is_dir():
    sys.exit(f"Missing output directory: {root}")
if dest == root or root in dest.parents:
    sys.exit("RESULTS_CSV must be outside OUTPUT_ROOT to protect raw results")
rows = []
missing = []
def warn(message):
    print(f"WARNING: {message}", file=sys.stderr)

for task in TASKS:
    directory = root / task
    source = directory / 'simulation_results.csv'
    videos = list(directory.rglob('*.mp4')) if directory.is_dir() else []
    if not source.is_file() or not videos:
        warn(f"{task}: missing simulation_results.csv or episode videos; omitted")
        missing.append(task)
        continue
    # Same marker convention as the historical aggregation, restricted to video basenames.
    # Use only raw episode videos, not edited/duplicated demo clips.
    success = sum('success' in video.name for video in videos)
    total = len(videos)
    steps = []
    try:
        with source.open(newline='') as handle:
            reader = csv.reader(handle)
            next(reader, None)
            for row in reader:
                if not row:
                    continue
                value = float(row[4])  # Historical upstream CSV: fifth field is sim steps.
                if not __import__('math').isfinite(value) or value < 0:
                    raise ValueError('invalid sim-step value')
                steps.append(value)
    except (OSError, IndexError, ValueError, csv.Error) as exc:
        warn(f"{task}: cannot parse fifth CSV column ({exc}); omitted")
        missing.append(task)
        continue
    if not steps or len(steps) != total:
        warn(f"{task}: CSV rows ({len(steps)}) differ from episode videos ({total}); omitted")
        missing.append(task)
        continue
    category = next((c for c in ('Turn', 'PnP', 'Open', 'Close', 'Coffee') if task.startswith(c)), 'Other')
    log = root / '_logs' / f'{task}.log'
    text = log.read_text(errors='replace') if log.is_file() else ''
    matches = re.findall(r'Collecting\s+\d+\s+episodes\s+took\s+([0-9]+(?:\.[0-9]+)?)\s+seconds', text)
    wall_time = matches[-1] if matches else ''
    if not wall_time:
        warn(f"{task}: task wall time unavailable; left blank")
    rows.append([task, category, success, total, f'{100 * success / total:.1f}', f'{sum(steps)/len(steps):.1f}', f'{max(steps):g}', wall_time])
if not rows:
    sys.exit('No valid task results; existing RESULTS_CSV was not changed')
dest.parent.mkdir(parents=True, exist_ok=True)
with dest.open('w', newline='') as handle:
    writer = csv.writer(handle)
    writer.writerow(['task', 'category', 'success', 'total', 'rate_pct', 'avg_sim_steps', 'max_sim_steps', 'task_wall_time_sec'])
    writer.writerows(rows)
print(f'Results: {dest} ({len(rows)}/{len(TASKS)} tasks)')
categories = defaultdict(lambda: [0, 0])
for task, category, success, total, rate, *_ in rows:
    print(f'{task}: {success}/{total} = {rate}%')
    categories[category][0] += success
    categories[category][1] += total
for category, (success, total) in sorted(categories.items()):
    print(f'{category}: {success}/{total} = {100 * success / total:.1f}%')
success = sum(row[2] for row in rows)
total = sum(row[3] for row in rows)
print(f'TOTAL (available tasks): {success}/{total} = {100 * success / total:.1f}%')
if missing:
    warn('INCOMPLETE: aggregate is not the full 24-task benchmark score')
    sys.exit(1)
PYTHON
