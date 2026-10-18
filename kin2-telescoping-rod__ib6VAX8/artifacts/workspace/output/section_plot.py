#!/usr/bin/env python3
"""Axial cross-section (plane y=0) of the 4 tubes, collapsed and fully extended."""
import json, os, trimesh, matplotlib
matplotlib.use("Agg"); import matplotlib.pyplot as plt
OUT = os.path.dirname(os.path.abspath(__file__))
J = json.load(open(os.path.join(OUT, "joints.json")))
parts = [trimesh.load(os.path.join(OUT, "parts", f"parts_{i}.stl")) for i in range(1, 5)]
cols = ["tab:blue", "tab:orange", "tab:green", "tab:red"]
def draw(ax, offs, xl=None, yl=None, title=""):
    for p, c, o in zip(parts, cols, offs):
        s = p.section(plane_origin=[0, 0, 0], plane_normal=[0, 1, 0])
        for d in s.discrete:
            ax.fill(d[:, 0], d[:, 2] + o, color=c, alpha=0.85, lw=0.3, ec="k")
    ax.set_aspect("equal"); ax.set_title(title, fontsize=9); ax.grid(alpha=0.3)
    if xl: ax.set_xlim(*xl)
    if yl: ax.set_ylim(*yl)
mx = [j["travel_mm"]["max"] for j in J["joints"]]
ext = [0, mx[0], mx[0] + mx[1], mx[0] + mx[1] + mx[2]]
fig, ax = plt.subplots(1, 4, figsize=(16, 10), gridspec_kw={"width_ratios": [1, 1, 1.4, 1.4]})
draw(ax[0], [0] * 4, title="collapsed (as printed)")
draw(ax[1], ext, title="fully extended")
draw(ax[2], [0] * 4, (2, 13), (-0.5, 18), "detail: bottom lips / collars / collapse stops")
draw(ax[3], [0, mx[0], mx[0], mx[0]], (2, 13), (mx[0] + 0, mx[0] + 18), "detail: J1 at extension stop")
plt.tight_layout(); plt.savefig(os.path.join(OUT, "checks", "section.png"), dpi=110)
