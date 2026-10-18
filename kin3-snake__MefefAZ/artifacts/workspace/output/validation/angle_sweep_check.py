#!/usr/bin/env python3
"""Sweep each joint from -35 to +35 deg in 5 deg steps and check all pairs."""
import json

import numpy as np
import trimesh
from trimesh.transformations import rotation_matrix

OUT = "/app/output"
parts = [trimesh.load(f"{OUT}/parts/parts_{i}.stl", process=True) for i in range(1, 7)]
joint_x = [28.0, 54.0, 80.0, 106.0, 132.0]
report = []
for j, x in enumerate(joint_x, start=1):
    bad = []
    for ang in range(-35, 36, 5):
        T = rotation_matrix(np.deg2rad(ang), (0, 0, 1), (x, 0, 0))
        for ia, a0 in enumerate(parts):
            if ia < j:
                continue
            a = a0.copy()
            a.apply_transform(T)
            for ib, b in enumerate(parts[:j]):
                inter = trimesh.boolean.intersection([a, b], engine="manifold")
                v = 0.0 if inter is None or inter.is_empty else float(inter.volume)
                if v > 1e-6:
                    bad.append({"angle_deg": ang, "moved_part": ia + 1, "fixed_part": ib + 1, "volume_mm3": v})
    report.append({"joint": j, "angles_deg": list(range(-35, 36, 5)), "collisions": bad})
    print(f"joint {j}: {len(bad)} collisions")
open(f"{OUT}/validation/angle_sweep_check.json", "w").write(json.dumps(report, indent=2))
assert all(not r["collisions"] for r in report)
