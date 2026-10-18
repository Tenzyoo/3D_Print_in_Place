#!/usr/bin/env python3
"""Plot the Y=0 cross-section of joint 1 in the final neutral pose."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import trimesh
from matplotlib.patches import Polygon as MplPoly

parts = [trimesh.load(f"/app/output/parts/parts_{i}.stl", process=True) for i in (1, 2)]
fig, ax = plt.subplots(figsize=(12, 5))
colors = ["#1f77b4", "#ff7f0e"]
labels = ["head", "body_1"]
for idx, part in enumerate(parts):
    sec = part.section(plane_origin=[0, 0, 0], plane_normal=[0, 1, 0])
    first = True
    for loop in sec.discrete:
        xy = loop[:, [0, 2]]
        ax.add_patch(
            MplPoly(
                xy,
                closed=True,
                facecolor=colors[idx],
                edgecolor="k",
                linewidth=0.4,
                alpha=0.75,
                label=labels[idx] if first else None,
            )
        )
        first = False
ax.set_aspect("equal")
ax.set_xlim(18, 38)
ax.set_ylim(-1, 11)
ax.axhline(0, color="k", lw=0.5)
ax.grid(alpha=0.25)
ax.set_xlabel("X (mm)")
ax.set_ylabel("Z (mm)")
ax.set_title("Joint 1 cross-section at Y=0 (neutral pose)")
handles, labels = ax.get_legend_handles_labels()
by_label = dict(zip(labels, handles))
ax.legend(by_label.values(), by_label.keys(), loc="upper right")
plt.tight_layout()
plt.savefig("/app/output/validation/joint1_cross_section.png", dpi=200)
print("saved validation/joint1_cross_section.png")
