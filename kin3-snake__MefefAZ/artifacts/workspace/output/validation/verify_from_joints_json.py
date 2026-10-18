#!/usr/bin/env python3
"""Independent motion check driven only by the delivered joints.json."""
import json
import os

import numpy as np
import trimesh
from trimesh.transformations import rotation_matrix

OUT = "/app/output"
data = json.load(open(f"{OUT}/joints.json"))
parts = {}
for p in data["parts"]:
    parts[p["id"]] = trimesh.load(os.path.join(OUT, p["file"]), process=True)

results = []
ok = True
for j in data["joints"]:
    axis = np.array(j["axis"], dtype=float)
    origin = np.array(j.get("origin", j.get("origin_mm")), dtype=float)
    child_ids = j["child_chain_part_ids"]
    fixed_ids = [pid for pid in parts if pid not in child_ids]
    for angle in (j["min_deg"], j["max_deg"]):
        T = rotation_matrix(np.deg2rad(angle), axis, origin)
        moved = {}
        for pid in child_ids:
            q = parts[pid].copy()
            q.apply_transform(T)
            moved[pid] = q
        collisions = []
        maxv = 0.0
        for ca, a in moved.items():
            for fb in fixed_ids:
                inter = trimesh.boolean.intersection([a, parts[fb]], engine="manifold")
                v = 0.0 if inter is None or inter.is_empty else float(inter.volume)
                maxv = max(maxv, v)
                if v > 1e-6:
                    collisions.append({"child_part": ca, "fixed_part": fb, "volume_mm3": v})
        entry = {
            "joint_id": j["id"],
            "angle_deg": angle,
            "axis": axis.tolist(),
            "origin_mm": origin.tolist(),
            "collisions": collisions,
            "max_collision_volume_mm3": maxv,
        }
        results.append(entry)
        ok = ok and not collisions

out = {
    "source": "joints.json",
    "parts_loaded": len(parts),
    "joints_checked": len(data["joints"]),
    "angles_per_joint": [data["joints"][0]["min_deg"], data["joints"][0]["max_deg"]],
    "all_declared_ranges_interference_free": bool(ok),
    "results": results,
}
open(f"{OUT}/validation/joints_json_motion_check.json", "w").write(json.dumps(out, indent=2))
print(json.dumps({k: v for k, v in out.items() if k != "results"}, indent=2))
assert ok
