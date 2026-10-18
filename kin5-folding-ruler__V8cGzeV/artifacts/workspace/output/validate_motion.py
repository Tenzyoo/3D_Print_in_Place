#!/usr/bin/env python3
"""Motion / interference check for the print-in-place folding ruler.

The joint data (origins, axes, fold signs and ranges) is read from
joints.json.  Three STL meshes are transformed with the serial-chain
kinematics documented in that file and checked for pairwise overlap with
manifold3d.  Intended to be run from the output directory:

    python3 validate_motion.py --step 5
    python3 validate_motion.py --step 2 --output collision_check.json

Requires: numpy, trimesh, manifold3d.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import trimesh
from trimesh.transformations import rotation_matrix

BASE = Path(__file__).resolve().parent
TOL = 1e-6


def rotation_about(axis_direction, angle_deg, origin):
    """Homogeneous rotation about an arbitrary axis line through origin."""
    axis = np.asarray(axis_direction, dtype=float)
    axis = axis / np.linalg.norm(axis)
    origin = np.asarray(origin, dtype=float)
    T = np.eye(4)
    T[:3, :3] = rotation_matrix(np.radians(angle_deg), axis)[:3, :3]
    T[:3, 3] = origin - T[:3, :3] @ origin
    return T


def overlap_volume(a, b):
    """Absolute boolean intersection volume of two meshes."""
    solid = trimesh.boolean.intersection([a, b], engine="manifold")
    return 0.0 if solid is None else abs(float(solid.volume))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--step", type=float, default=5.0,
                    help="angle increment in degrees (default 5)")
    ap.add_argument("--output", type=Path, default=None,
                    help="optional JSON report path")
    args = ap.parse_args()

    with (BASE / "joints.json").open(encoding="utf-8") as fh:
        data = json.load(fh)

    parts = {}
    for record in data["parts"]:
        path = BASE / record["file"]
        parts[record["part"]] = trimesh.load(path, force="mesh")
        if not parts[record["part"]].is_watertight:
            print(f"ERROR: {path} is not watertight", file=sys.stderr)
            return 2

    j1, j2 = data["joints"]
    J1 = np.asarray(j1["axis"]["origin_mm"], dtype=float)
    J2 = np.asarray(j2["axis"]["origin_mm"], dtype=float)
    A1 = j1["axis"]["direction"]
    A2 = j2["axis"]["direction"]
    s1 = float(j1["fold_sign"])
    s2 = float(j2["fold_sign"])

    # Basic static checks: all parts present, same volume as the assembly.
    model = trimesh.load(BASE / "model.stl", force="mesh")
    volume_sum = sum(p.volume for p in parts.values())
    print(f"parts: {sorted(parts)}")
    print(f"model volume: {model.volume:.3f} mm^3")
    print(f"sum of parts: {volume_sum:.3f} mm^3  (diff {model.volume-volume_sum:+.3e})")
    print(f"model components: {len(model.split(only_watertight=False))}")

    # The smallest static gap at 0 degrees (vertex-to-surface on both meshes).
    from trimesh.proximity import ProximityQuery

    def min_gap(a, b):
        d_ab = ProximityQuery(b).on_surface(a.vertices)[1].min()
        d_ba = ProximityQuery(a).on_surface(b.vertices)[1].min()
        return float(min(d_ab, d_ba))

    print("0 deg minimum gaps:")
    for i in (1, 2):
        for j in range(i + 1, 4):
            print(f"  part {i} <-> part {j}: {min_gap(parts[i], parts[j]):.4f} mm")

    if args.step <= 0 or args.step > 45:
        print("ERROR: --step must be in (0, 45]", file=sys.stderr)
        return 2

    n = int(round(180.0 / args.step))
    angles = np.linspace(0.0, 180.0, n + 1)
    start = time.time()
    max_overlap = 0.0
    failures = []

    for a1 in angles:
        T1 = rotation_about(A1, s1 * a1, J1)
        p2 = parts[2].copy()
        p2.apply_transform(T1)
        for a2 in angles:
            T2 = rotation_about(A2, s2 * a2, J2)
            p3 = parts[3].copy()
            p3.apply_transform(T1 @ T2)
            overlaps = (
                overlap_volume(parts[1], p2),
                overlap_volume(p2, p3),
                overlap_volume(parts[1], p3),
            )
            worst = max(overlaps)
            max_overlap = max(max_overlap, worst)
            if worst > TOL:
                failures.append(
                    {"joint_1_deg": float(a1), "joint_2_deg": float(a2),
                     "overlap_mm3": [float(v) for v in overlaps]}
                )

    result = {
        "step_deg": args.step,
        "poses": int(len(angles) ** 2),
        "max_overlap_volume_mm3": float(max_overlap),
        "failure_count": len(failures),
        "failures": failures[:20],
        "elapsed_s": round(time.time() - start, 2),
        "convention": "joint angles are non-negative; fold_sign is applied about the declared +Z axis",
    }
    print(json.dumps(result, indent=2))

    if args.output is not None:
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {args.output}")

    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
