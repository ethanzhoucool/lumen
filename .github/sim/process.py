#!/usr/bin/env python3
"""TEMPORARY: turn the simulator recording into small contact sheets and print them
base64-encoded into the job log (artifact downloads aren't reachable from the reviewer's
sandbox). Usage: process.py <ffmpeg> <outdir>"""
import base64, re, subprocess, sys, pathlib

ff, out = sys.argv[1], pathlib.Path(sys.argv[2])
rec = (out / "rec.txt").read_text()
m = re.search(r"^([0-9.]+) Recording started", rec, re.M)
rec0 = float(m.group(1))
events = {}
for line in (out / "stdout.txt").read_text().splitlines():
    mm = re.match(r"\[Harness\] epoch=([0-9.]+) t=[0-9.]+ (.*)", line)
    if mm:
        events.setdefault(mm.group(2), float(mm.group(1)))
print("rec0", rec0)
for k, v in events.items():
    print(f"event {v - rec0:7.2f}s  {k}")
start = events["start (profile tab)"] - rec0

def run(args):
    r = subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-y"] + args)
    if r.returncode:
        print("ffmpeg failed", args)

def sheet(name, t, dur, fps, crop, width, cols, rows):
    run(["-ss", f"{max(0, t):.3f}", "-t", f"{dur:.3f}", "-i", str(out / "run.mp4"),
         "-vf", f"fps={fps},{crop},scale={width}:-2,tile={cols}x{rows}:padding=4:color=red",
         "-frames:v", "1", "-q:v", "5", str(out / name)])

# Infinity loader on Profile (dark), before any theme toggle: 16 frames, 0.1s apart.
sheet("infinity.jpg", start + 1.0, 1.6, 10, "crop=iw*0.5:ih*0.25:0:ih*0.68", 300, 4, 4)
# Fly-to-cart, top half of the screen, 20 fps.
for key, name in [("add offer 0", "fly0.jpg"), ("add offer 3", "fly3.jpg")]:
    t = events[key] - rec0
    sheet(name, t - 0.15, 1.2, 20, "crop=iw:ih*0.5:0:0", 240, 6, 4)
# Confetti burst still plays (fixed build): 6 frames 0.25s apart from confetti-on.
sheet("confetti.jpg", events["confetti on"] - rec0, 1.5, 4, "null", 240, 6, 1)
# Screenshots, downscaled.
for png in sorted(out.glob("*.png")):
    run(["-i", str(png), "-vf", "scale=360:-2", "-q:v", "5", str(out / (png.stem + ".jpg"))])

for jpg in sorted(out.glob("*.jpg")):
    data = base64.b64encode(jpg.read_bytes()).decode()
    print(f"=====BEGIN {jpg.name} {len(data)}=====")
    for i in range(0, len(data), 3000):
        print(data[i:i + 3000])
    print(f"=====END {jpg.name}=====")
