#!/usr/bin/env python3
"""Generate YouTube chapters from new video (1 SUCC + 1 FAIL structure)."""
import subprocess, csv, glob

ROOT = "/workspace/RLDX-1"

TASKS = [
    "TurnSinkSpout","TurnOnStove","TurnOnSinkFaucet","TurnOnMicrowave",
    "TurnOffStove","TurnOffSinkFaucet","TurnOffMicrowave",
    "PnPStoveToCounter","PnPSinkToCounter","PnPMicrowaveToCounter",
    "PnPCounterToStove","PnPCounterToSink","PnPCounterToMicrowave",
    "PnPCounterToCab","PnPCabToCounter",
    "OpenSingleDoor","OpenDrawer","OpenDoubleDoor",
    "CoffeeSetupMug","CoffeeServeMug","CoffeePressButton",
    "CloseSingleDoor","CloseDrawer","CloseDoubleDoor",
]

results = {}
with open(f"{ROOT}/results_v2.csv") as f:
    for row in csv.DictReader(f):
        results[row['task']] = int(row['rate_pct'])

def dur(p):
    r = subprocess.run(["ffprobe","-v","error","-show_entries","format=duration",
                        "-of","csv=p=0",p], capture_output=True, text=True)
    return float(r.stdout.strip())

clips = sorted(glob.glob(f"{ROOT}/output_final/demo/intermediate/clip_*.mp4"))
durations = [dur(p) for p in clips]

print("# YouTube Chapters (copy into description)\n")
print("0:00 Intro")

cum = durations[0]  # after intro
fifteen_count = 0

for i, d in enumerate(durations[1:], start=1):
    if abs(d - 1.5) < 0.2:
        if fifteen_count % 2 == 0:
            # task start card
            task_idx = fifteen_count // 2
            if task_idx < len(TASKS):
                task = TASKS[task_idx]
                rate = results.get(task, 0)
                m, s = int(cum // 60), int(cum % 60)
                print(f"{m}:{s:02d} [{task_idx+1:02d}/24] {task} ({rate}%)")
        fifteen_count += 1
    cum += d

# Outro
outro_start = cum - durations[-1]
m, s = int(outro_start // 60), int(outro_start % 60)
print(f"{m}:{s:02d} Final Results")

total = sum(durations)
print(f"\nTotal length: {int(total//60)}m {int(total%60):02d}s")
