#!/usr/bin/env python3
"""RLDX-1 RoboCasa Demo Video v2 — 1536x480 final."""

import os, csv, subprocess, sys, re
from pathlib import Path

ROOT = "/workspace/RLDX-1"
REPRODUCE_DIR = f"{ROOT}/output_final/robocasa/reproduce_v2"
OUTPUT_DIR = f"{ROOT}/output_final/demo"
INTERMEDIATE_DIR = f"{OUTPUT_DIR}/intermediate"
FINAL_VIDEO = f"{OUTPUT_DIR}/RLDX1_RoboCasa_Demo_V2.mp4"

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

WIDTH = 1536
CAM_H = 360
TOP_PAD = 60
BOT_PAD = 60
HEIGHT = TOP_PAD + CAM_H + BOT_PAD
FPS = 20

TASKS = [
    ("TurnSinkSpout","Turn"),("TurnOnStove","Turn"),("TurnOnSinkFaucet","Turn"),
    ("TurnOnMicrowave","Turn"),("TurnOffStove","Turn"),("TurnOffSinkFaucet","Turn"),
    ("TurnOffMicrowave","Turn"),
    ("PnPStoveToCounter","PnP"),("PnPSinkToCounter","PnP"),("PnPMicrowaveToCounter","PnP"),
    ("PnPCounterToStove","PnP"),("PnPCounterToSink","PnP"),("PnPCounterToMicrowave","PnP"),
    ("PnPCounterToCab","PnP"),("PnPCabToCounter","PnP"),
    ("OpenSingleDoor","Open"),("OpenDrawer","Open"),("OpenDoubleDoor","Open"),
    ("CoffeeSetupMug","Coffee"),("CoffeeServeMug","Coffee"),("CoffeePressButton","Coffee"),
    ("CloseSingleDoor","Close"),("CloseDrawer","Close"),("CloseDoubleDoor","Close"),
]

INSTRUCTIONS = {
    "TurnSinkSpout":         "Rotate the sink spout",
    "TurnOnStove":           "Turn on the stove burner",
    "TurnOnSinkFaucet":      "Turn on the sink faucet",
    "TurnOnMicrowave":       "Turn on the microwave",
    "TurnOffStove":          "Turn off the stove burner",
    "TurnOffSinkFaucet":     "Turn off the sink faucet",
    "TurnOffMicrowave":      "Turn off the microwave",
    "PnPStoveToCounter":     "Pick from stove, place on counter",
    "PnPSinkToCounter":      "Pick from sink, place on counter",
    "PnPMicrowaveToCounter": "Pick from microwave, place on counter",
    "PnPCounterToStove":     "Pick from counter, place on stove",
    "PnPCounterToSink":      "Pick from counter, place in sink",
    "PnPCounterToMicrowave": "Pick from counter, place in microwave",
    "PnPCounterToCab":       "Pick from counter, place in cabinet",
    "PnPCabToCounter":       "Pick from cabinet, place on counter",
    "OpenSingleDoor":        "Open the cabinet door",
    "OpenDrawer":            "Open the drawer",
    "OpenDoubleDoor":        "Open the double doors",
    "CoffeeSetupMug":        "Place the mug in the coffee machine",
    "CoffeeServeMug":        "Serve coffee into the mug",
    "CoffeePressButton":     "Press the coffee machine button",
    "CloseSingleDoor":       "Close the cabinet door",
    "CloseDrawer":           "Close the drawer",
    "CloseDoubleDoor":       "Close the double doors",
}


def load_results():
    out = {}
    with open(f"{ROOT}/results_v2.csv") as f:
        for row in csv.DictReader(f):
            out[row['task']] = {
                'success': int(row['success']),
                'total': int(row['total']),
                'rate': int(row['rate_pct']),
                'avg_steps': float(row['avg_steps']),
            }
    return out


def esc(s):
    return (s.replace("\\", "\\\\").replace(":", "\\:")
             .replace("'", "\u2019").replace(",", "\\,")
             .replace("[", "\\[").replace("]", "\\]"))


def make_card(lines, duration, out_path):
    n = len(lines)
    line_h = 60
    start_y = (HEIGHT - n * line_h) // 2
    filters = []
    for i, (txt, sz, col) in enumerate(lines):
        if not txt.strip():
            continue
        y = start_y + i * line_h
        filters.append(
            f"drawtext=fontfile={FONT}:text='{esc(txt)}':"
            f"expansion=none:fontcolor={col}:fontsize={sz}:x=(w-tw)/2:y={y}"
        )
    vf = ",".join(filters) if filters else "null"
    cmd = ["ffmpeg","-y","-f","lavfi",
           "-i",f"color=c=black:s={WIDTH}x{HEIGHT}:d={duration}:r={FPS}",
           "-vf",vf,
           "-c:v","libx264","-pix_fmt","yuv420p","-preset","fast",
           "-an", out_path]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"FAIL card: {r.stderr[-500:]}", file=sys.stderr)
        sys.exit(1)


def process_episode(input_path, output_path, label, instruction):
    label_e = esc(label)
    instr_e = esc(instruction)
    fc = (
        f"[0:v]crop=256:180:0:0,scale=512:360:flags=lanczos[l];"
        f"[0:v]crop=256:180:512:0,scale=512:360:flags=lanczos[r];"
        f"[0:v]crop=256:180:1024:0,scale=512:360:flags=lanczos[w];"
        f"[l][r][w]hstack=inputs=3[cam];"
        f"[cam]pad={WIDTH}:{HEIGHT}:0:{TOP_PAD}:color=black[padded];"
        f"[padded]drawtext=fontfile={FONT}:text='{label_e}':"
        f"expansion=none:fontcolor=white:fontsize=44:x=(w-tw)/2:y=8[top];"
        f"[top]drawtext=fontfile={FONT}:text='{instr_e}':"
        f"expansion=none:fontcolor=white:fontsize=44:x=(w-tw)/2:y={TOP_PAD + CAM_H + 8}[v]"
    )
    cmd = ["ffmpeg","-y","-i",input_path,
           "-filter_complex",fc, "-map","[v]",
           "-c:v","libx264","-pix_fmt","yuv420p","-preset","fast",
           "-r",str(FPS),"-an", output_path]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"FAIL ep ({input_path}): {r.stderr[-500:]}", file=sys.stderr)


def find_episodes(task, n=None):
    """1 success + 1 failure (lowest episode index)."""
    d = Path(REPRODUCE_DIR) / task
    def get_idx(p):
        m = re.search(r"episode_(\d+)", p.name)
        return int(m.group(1)) if m else 999
    s_files = sorted(d.glob("*-episode_*-success.mp4"), key=get_idx)
    f_files = sorted(d.glob("*-episode_*-failure.mp4"), key=get_idx)
    result = []
    if s_files:
        result.append((get_idx(s_files[0]), s_files[0]))
    if f_files:
        result.append((get_idx(f_files[0]), f_files[0]))
    return result


def main():
    os.makedirs(INTERMEDIATE_DIR, exist_ok=True)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    results = load_results()
    clips, idx = [], 0
    
    def nxt():
        nonlocal idx
        p = f"{INTERMEDIATE_DIR}/clip_{idx:04d}.mp4"
        idx += 1
        return p
    
    # Intro (8 sec)
    print("[1/3] Intro card...")
    c = nxt(); clips.append(c)
    make_card([
        ("RLDX-1 RoboCasa Kitchen Reproduction", 56, "white"),
        ("24 tasks x 50 episodes = 1200 trials", 40, "white"),
        ("", 1, "white"),
        ("Overall: 67.8%   (RLWRLD reported: 70.6%)", 48, "yellow"),
        ("", 1, "white"),
        ("Turn 75% | PnP 49% | Open 69% | Coffee 72% | Close 96%", 32, "white"),
    ], 8, c)
    
    # Per-task
    print("[2/3] Processing 24 tasks...")
    for ti, (task, cat) in enumerate(TASKS):
        r = results.get(task, {'success':0,'total':0,'rate':0,'avg_steps':0})
        instruction = INSTRUCTIONS.get(task, task)
        print(f"  [{ti+1:2d}/24] {task} ({r['success']}/{r['total']})")
        
        # Task start card
        c = nxt(); clips.append(c)
        make_card([
            (f"[{ti+1}/24]  {task}", 56, "white"),
            ("", 1, "white"),
            (f"Category: {cat}    Avg steps: {r['avg_steps']:.1f}", 40, "white"),
            (f"Success: {r['success']}/{r['total']}  ({r['rate']}%)", 48, "yellow"),
        ], 1.5, c)
        
        # Episodes (1 SUCC + 1 FAIL)
        for ep_i, ep_p in find_episodes(task):
            res = "SUCC" if "success" in str(ep_p) else "FAIL"
            label = f"{task} | EP{ep_i} | {res} | {r['rate']}%"
            c = nxt(); clips.append(c)
            process_episode(str(ep_p), c, label, instruction)
        
        # Task end card
        c = nxt(); clips.append(c)
        make_card([
            (f"{task}: {r['success']}/{r['total']} ({r['rate']}%)", 48, "white"),
        ], 1.5, c)
    
    # Outro (no v1)
    print("[3/3] Outro card...")
    c = nxt(); clips.append(c)
    make_card([
        ("Final Results", 56, "white"),
        ("", 1, "white"),
        ("Our result:        67.8%", 44, "yellow"),
        ("RLWRLD reported:   70.6%", 44, "white"),
        ("", 1, "white"),
        ("Difference: 2.8%p (GPU + seed variance)", 36, "white"),
    ], 10, c)
    
    # Concat
    print(f"[Final] Concatenating {len(clips)} clips...")
    concat_list = f"{INTERMEDIATE_DIR}/concat.txt"
    with open(concat_list, "w") as f:
        for cp in clips:
            f.write(f"file '{cp}'\n")
    
    cmd = ["ffmpeg","-y","-f","concat","-safe","0","-i",concat_list,
           "-c:v","libx264","-pix_fmt","yuv420p","-preset","medium",
           "-crf","23","-r",str(FPS),"-an", FINAL_VIDEO]
    r = subprocess.run(cmd)
    if r.returncode == 0:
        size_mb = os.path.getsize(FINAL_VIDEO) / 1024 / 1024
        print(f"\n✓ Done: {FINAL_VIDEO} ({size_mb:.1f} MB)")
    else:
        print(f"FAIL concat", file=sys.stderr); sys.exit(1)


if __name__ == "__main__":
    main()
