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

light = events["toggle theme (-> light)"] - rec0
dark = events["toggle theme (-> dark)"] - rec0

def frame(name, t, crop="null", width=360):
    run(["-ss", f"{max(0, t):.3f}", "-i", str(out / "run.mp4"), "-vf", f"{crop},scale={width}:-2",
         "-frames:v", "1", "-q:v", "4", str(out / name)])

# Infinity loader on Profile (dark), the 1.6s just before the first theme toggle: 16 frames.
sheet("infinity.jpg", light - 2.0, 1.6, 10, "crop=iw*0.5:ih*0.25:0:ih*0.68", 300, 4, 4)
# Tab bar: dark before the toggle, light after it, dark again after the second toggle.
frame("tab1-dark.jpg", light - 0.5)
frame("tab2-light.jpg", light + 2.0)
frame("tab3-light-late.jpg", dark - 0.3)
frame("tab4-dark-again.jpg", dark + 2.0)
# Fly-to-cart for the 4th row: right 40% / top half of the screen, 15 fps over 2s.
t = events["add offer 3"] - rec0
sheet("fly3.jpg", t - 0.8, 2.0, 15, "crop=iw*0.4:ih*0.5:iw*0.6:0", 160, 10, 3)
# Confetti burst still plays: 6 frames 0.25s apart from confetti-on.
sheet("confetti.jpg", events["confetti on"] - rec0, 1.5, 4, "null", 240, 6, 1)
for jpg in sorted(out.glob("*.jpg")):
    data = base64.b64encode(jpg.read_bytes()).decode()
    print(f"=====BEGIN {jpg.name} {len(data)}=====")
    for i in range(0, len(data), 3000):
        print(data[i:i + 3000])
    print(f"=====END {jpg.name}=====")
