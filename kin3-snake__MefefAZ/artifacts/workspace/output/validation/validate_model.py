#!/usr/bin/env python3
"""Geometric validation for the print-in-place snake.

Loads the six delivered part STLs in the delivered (neutral) coordinate
system, checks manifoldness/assembly consistency, neutral interference,
and interference-free rotation at the intended +/-30 deg range (plus a
+/-35 deg margin check).  Also measures the first relative Z displacement
at which the retaining flanges collide, i.e. the axial pull-out stop.
"""
import json
import os

import numpy as np
import trimesh
from shapely.geometry import Polygon
from shapely.ops import unary_union
from trimesh.proximity import closest_point
from trimesh.transformations import rotation_matrix

OUT = "/app/output"
PART_FILES = [f"{OUT}/parts/parts_{i}.stl" for i in range(1, 7)]
JOINT_X = [28.0, 54.0, 80.0, 106.0, 132.0]
ANGLES = [-35, -30, -25, 0, 25, 30, 35]


def collision_volume(a, b):
    inter = trimesh.boolean.intersection([a, b], engine="manifold")
    if inter is None or inter.is_empty:
        return 0.0
    return float(inter.volume)


def min_gap(a, b, nsamples=6000, seed=1234):
    # Surface sampling + closest-point both ways gives a stable upper bound
    # on the true minimum distance for these triangulated planar/axial shapes.
    trimesh.util.attach_to_log()
    pts_a, _ = trimesh.sample.sample_surface(a, nsamples, seed=seed)
    pts_b, _ = trimesh.sample.sample_surface(b, nsamples, seed=seed + 1)
    da = closest_point(a, pts_b)[1]
    db = closest_point(b, pts_a)[1]
    return float(min(da.min(), db.min()))


parts = [trimesh.load(f, process=True) for f in PART_FILES]
model = trimesh.load(f"{OUT}/model.stl", process=True)

report = {
    "units": "mm",
    "part_files": [os.path.basename(f) for f in PART_FILES],
    "part_count": len(parts),
    "part_volumes_mm3": [round(float(p.volume), 3) for p in parts],
    "part_watertight": [bool(p.is_watertight) for p in parts],
    "part_bounds_mm": [np.round(p.bounds, 3).tolist() for p in parts],
    "model_file": "model.stl",
    "model_bounds_mm": np.round(model.bounds, 3).tolist(),
    "model_size_mm": np.round(model.bounds[1] - model.bounds[0], 3).tolist(),
    "model_watertight": bool(model.is_watertight),
    "model_volume_mm3": round(float(model.volume), 3),
    "sum_part_volume_mm3": round(float(sum(p.volume for p in parts)), 3),
    "model_components": len(model.split(only_watertight=False)),
    "neutral_pairwise_intersections": [],
    "joints": [],
    "layer_cross_sections": [],
    "axial_retention": [],
    "limits": {"required_deg": 25, "functional_range_deg": 30, "margin_tested_deg": 35},
}

for i in range(6):
    for j in range(i + 1, 6):
        v = collision_volume(parts[i], parts[j])
        if v > 1e-6:
            report["neutral_pairwise_intersections"].append(
                {"part_a": i + 1, "part_b": j + 1, "volume_mm3": v}
            )

for j, x in enumerate(JOINT_X, start=1):
    joint = {
        "joint": j,
        "origin_mm": [x, 0.0, 0.0],
        "axis": [0, 0, 1],
        "proximal_part": j,
        "distal_part": j + 1,
        "angle_tests": [],
    }
    for ang in ANGLES:
        T = rotation_matrix(np.deg2rad(ang), (0, 0, 1), (x, 0, 0))
        moved = []
        fixed = list(range(j))
        for idx, p in enumerate(parts):
            if idx >= j:
                q = p.copy()
                q.apply_transform(T)
                moved.append((idx, q))
        bad = []
        maxv = 0.0
        for ia, a in moved:
            for ib in fixed:
                v = collision_volume(a, parts[ib])
                maxv = max(maxv, v)
                if v > 1e-6:
                    bad.append({"moved_part": ia + 1, "fixed_part": ib + 1, "volume_mm3": v})
        # Adjacent pair gap: only meaningful for the two parts at this joint.
        a0 = parts[j - 1]
        b0 = parts[j]
        if ang == 0:
            a, b = a0, b0
        else:
            a = a0.copy()
            a.apply_transform(T)
            b = b0
        gap = min_gap(a, b)
        joint["angle_tests"].append(
            {
                "angle_deg": ang,
                "collisions": bad,
                "max_collision_volume_mm3": maxv,
                "adjacent_pair_min_gap_mm": round(gap, 4),
            }
        )
    report["joints"].append(joint)

# Actual 0.2 mm-layer midplane cross-sections: in-plane gap / overlap checks.
def section_union(mesh, z):
    sec = mesh.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
    if sec is None:
        return unary_union([])
    polys = []
    for loop in sec.discrete:
        if len(loop) < 3:
            continue
        poly = Polygon(loop[:, :2])
        if not poly.is_valid:
            poly = poly.buffer(0)
        if not poly.is_empty:
            polys.append(poly)
    return unary_union(polys)

for j, x in enumerate(JOINT_X, start=1):
    a, b = parts[j - 1], parts[j]
    best = (1e9, None)
    overlaps = []
    for z in np.arange(0.1, T if False else 10.0, 0.2):
        pa = section_union(a, float(z))
        pb = section_union(b, float(z))
        ov = pa.intersection(pb).area
        if ov > 1e-6:
            overlaps.append({"z_mm": round(float(z), 2), "area_mm2": float(ov)})
        d = pa.distance(pb)
        if d < best[0]:
            best = (float(d), float(z))
    report["layer_cross_sections"].append(
        {
            "joint": j,
            "layer_midplanes_z_mm": "0.1 to 9.9 step 0.2",
            "min_in_plane_gap_mm": round(best[0], 4),
            "at_z_mm": round(best[1], 2),
            "overlaps": overlaps,
        }
    )

# Axial pull-out stop: move the distal part only, in +/-Z, until contact.
for j, x in enumerate(JOINT_X, start=1):
    a = parts[j - 1]
    b0 = parts[j]
    entry = {"joint": j, "directions": {}}
    for sign, name in ((1, "+Z"), (-1, "-Z")):
        first = None
        for d in np.arange(0.25, 3.01, 0.25):
            b = b0.copy()
            b.apply_translation([0, 0, sign * d])
            if collision_volume(a, b) > 1e-6:
                first = float(sign * d)
                break
        entry["directions"][name] = first
    report["axial_retention"].append(entry)

assert report["part_count"] == 6
assert report["model_components"] == 6
assert all(report["part_watertight"])
assert report["model_watertight"]
assert abs(report["model_volume_mm3"] - report["sum_part_volume_mm3"]) < 0.01
assert max(report["model_size_mm"][0], report["model_size_mm"][1], report["model_size_mm"][2]) <= 160
assert report["model_size_mm"][0] <= 160 and report["model_size_mm"][1] <= 50 and report["model_size_mm"][2] <= 40
assert not report["neutral_pairwise_intersections"]
for layer in report["layer_cross_sections"]:
    assert not layer["overlaps"], layer
    assert layer["min_in_plane_gap_mm"] > 0.45, layer
for joint in report["joints"]:
    for test in joint["angle_tests"]:
        assert not test["collisions"], (joint["joint"], test["angle_deg"], test["collisions"])
        if abs(test["angle_deg"]) <= 30:
            assert test["adjacent_pair_min_gap_mm"] > 0.35

with open(f"{OUT}/validation/validation_report.json", "w") as f:
    json.dump(report, f, indent=2)
print(json.dumps(report, indent=2))
