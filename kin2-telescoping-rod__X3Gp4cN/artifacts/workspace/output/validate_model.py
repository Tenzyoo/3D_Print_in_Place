#!/usr/bin/env python3
"""Geometry / clearance / motion checks for the print-in-place telescoping rod.

Run from /app/output:
    python3 validate_model.py

Outputs validation_report.json and section_check.png.
All dimensions are millimetres.
"""
import json
import math
from pathlib import Path

import numpy as np
import trimesh
from shapely.ops import unary_union
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon as MplPolygon

ROOT = Path(__file__).resolve().parent
OUT = ROOT
GAP = 0.50
STROKES = [80.0, 70.0, 70.0]
GLOBAL_EXT = [0.0, 80.0, 150.0, 220.0]
COLLAPSED_LEN = 110.0
EXTENDED_LEN = 320.0
MAX_OD = 24.8


def load_parts():
    return [trimesh.load(ROOT / "parts" / f"parts_{i}.stl", force="mesh")
            for i in range(1, 5)]


def section_poly(mesh, z):
    sec = mesh.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
    if sec is None:
        return None
    p2, _ = sec.to_2D()
    if not p2.polygons_full:
        return None
    return unary_union(p2.polygons_full)


def shifted(meshes, offsets):
    out = []
    for mesh, dz in zip(meshes, offsets):
        m = mesh.copy()
        m.apply_translation([0, 0, dz])
        out.append(m)
    return out


def scan_state(meshes, z_values, record_all=False):
    """Return list of pairwise section-overlap records."""
    records = []
    z_values = list(z_values)
    for z in z_values:
        polys = [section_poly(m, z) for m in meshes]
        for i in range(4):
            for j in range(i + 1, 4):
                if polys[i] is None or polys[j] is None:
                    continue
                inter = polys[i].intersection(polys[j]).area
                if inter > 1e-6 or record_all:
                    records.append({
                        "z": round(float(z), 4),
                        "pair": f"T{i+1}-T{j+1}",
                        "overlap_area_mm2": round(float(inter), 6),
                        "boundary_distance_mm": round(float(polys[i].distance(polys[j])), 6),
                    })
    return records


def max_overlap(records):
    return max((r["overlap_area_mm2"] for r in records), default=0.0)


def plot_sections(parts):
    fig, axes = plt.subplots(1, 2, figsize=(12, 6))
    colors = ["#2b8cbe", "#f0a030", "#31a354", "#c51b8a"]
    for ax, z, title in [(axes[0], 2.0, "z = 2 mm: lower keys in keyways"),
                         (axes[1], 50.0, "z = 50 mm: cylindrical sliding fit")]:
        for i, m in enumerate(parts):
            p = section_poly(m, z)
            if p is None:
                continue
            geoms = list(p.geoms) if hasattr(p, "geoms") else [p]
            for g in geoms:
                if g.is_empty:
                    continue
                xy = np.asarray(g.exterior.coords)
                ax.add_patch(MplPolygon(xy, closed=True, facecolor=colors[i],
                                        edgecolor="black", linewidth=0.4,
                                        alpha=0.45, label=f"T{i+1}"))
                for hole in g.interiors:
                    hxy = np.asarray(hole.coords)
                    ax.add_patch(MplPolygon(hxy, closed=True, facecolor="white",
                                            edgecolor="black", linewidth=0.3))
        ax.set_aspect("equal")
        ax.set_xlim(-13.2, 13.2)
        ax.set_ylim(-13.2, 13.2)
        ax.set_title(title)
        ax.grid(True, linewidth=0.3, alpha=0.5)
        ax.set_xlabel("X (mm)")
        ax.set_ylabel("Y (mm)")
    handles, labels = axes[1].get_legend_handles_labels()
    by_label = dict(zip(labels, handles))
    fig.legend(by_label.values(), by_label.keys(), loc="lower center", ncol=4)
    fig.tight_layout(rect=(0, 0.07, 1, 1))
    fig.savefig(OUT / "section_check.png", dpi=180)
    plt.close(fig)


def main():
    model = trimesh.load(ROOT / "model.stl", force="mesh")
    parts = load_parts()

    model_components = model.split(only_watertight=False)
    part_match = []
    used = set()
    for idx, p in enumerate(parts):
        best = None
        for k, c in enumerate(model_components):
            if k in used:
                continue
            err = abs(c.volume - p.volume) + float(np.linalg.norm(c.centroid - p.centroid))
            if best is None or err < best[0]:
                best = (err, k)
        used.add(best[1])
        part_match.append(abs(model_components[best[1]].volume - p.volume) < 1e-6)

    # Collapsed: all four tubes occupy z = 0..100 or 0..110.
    collapsed = shifted(parts, [0, 0, 0, 0])
    collapsed_scan = scan_state(collapsed, np.arange(0.05, 110.0, 0.5))
    collapsed_max = max_overlap(collapsed_scan)

    # Fully extended: global positions 0, 80, 150, 220.
    full = shifted(parts, GLOBAL_EXT)
    full_scan = scan_state(full, np.arange(0.05, 320.0, 0.5))
    full_max = max_overlap(full_scan)

    # Overtravel each joint independently by +0.25 mm.  A positive section
    # overlap proves the key has hit the keyway roof and cannot pass through.
    overtravel = {}
    for j in range(3):
        offs = list(GLOBAL_EXT)
        offs[j + 1] += 0.25
        state = shifted(parts, offs)
        z_stop = [84.0, 154.0, 224.0][j]
        zz = np.arange(z_stop - 0.30, z_stop + 0.30, 0.05)
        rec = scan_state(state, zz, record_all=True)
        # only the moving pair is expected to overlap
        pair_name = f"T{j+1}-T{j+2}"
        pair_rec = [r for r in rec if r["pair"] == pair_name]
        overtravel[f"J{j+1}"] = {
            "additional_child_offset_mm": 0.25,
            "max_overlap_area_mm2": round(max_overlap(pair_rec), 6),
            "blocked": max_overlap(pair_rec) > 1e-4,
        }

    # Section distances at key height and plain cylindrical height.
    gap_samples = {}
    for z, name in [(2.0, "key_height_z2"), (50.0, "cylindrical_z50"),
                    (90.0, "upper_cylindrical_z90")]:
        polys = [section_poly(m, z) for m in collapsed]
        vals = {}
        for i in range(3):
            if polys[i] is not None and polys[i + 1] is not None:
                vals[f"T{i+1}-T{i+2}"] = round(float(polys[i].distance(polys[i + 1])), 6)
        gap_samples[name] = vals

    plot_sections(parts)

    all_gap_values = [v for d in gap_samples.values() for v in d.values()]
    passed = (
        model.is_watertight and model.is_winding_consistent and
        len(model_components) == 4 and all(part_match) and
        abs(model.extents[0] - MAX_OD) < 1e-6 and
        abs(model.extents[1] - MAX_OD) < 1e-6 and
        abs(model.extents[2] - COLLAPSED_LEN) < 1e-6 and
        collapsed_max < 1e-4 and full_max < 1e-4 and
        all(o["blocked"] for o in overtravel.values()) and
        all(0.40 <= v <= 0.60 for v in all_gap_values)
    )

    report = {
        "units": "mm",
        "passed": bool(passed),
        "assembly_stl": {
            "file": "model.stl",
            "watertight": bool(model.is_watertight),
            "winding_consistent": bool(model.is_winding_consistent),
            "components": len(model_components),
            "facets": int(len(model.faces)),
            "volume_mm3": round(float(model.volume), 3),
            "bounds_min": [round(float(v), 4) for v in model.bounds[0]],
            "bounds_max": [round(float(v), 4) for v in model.bounds[1]],
            "extents": [round(float(v), 4) for v in model.extents],
        },
        "part_stls": [
            {
                "file": f"parts/parts_{i+1}.stl",
                "watertight": bool(p.is_watertight),
                "volume_mm3": round(float(p.volume), 3),
                "bounds_min": [round(float(v), 4) for v in p.bounds[0]],
                "bounds_max": [round(float(v), 4) for v in p.bounds[1]],
                "matches_assembly_component": bool(part_match[i]),
            }
            for i, p in enumerate(parts)
        ],
        "dimensions": {
            "collapsed_length": COLLAPSED_LEN,
            "extended_length": EXTENDED_LEN,
            "max_outer_diameter": MAX_OD,
            "inner_bore_diameter": 7.0,
        },
        "joints": {
            "order_outer_to_inner": ["T1", "T2", "T3", "T4"],
            "axis": [0, 0, 1],
            "strokes": STROKES,
            "global_extended_z": GLOBAL_EXT,
            "engagement_at_full_extension": [30.0, 30.0, 30.0],
            "key_height": 4.0,
            "key_radial_depth": 1.10,
            "key_radial_catch": 0.60,
        },
        "clearance_checks": {
            "nominal_body_and_key_gap": GAP,
            "measured_section_boundary_distances": gap_samples,
            "min_measured_mm": round(min(all_gap_values), 6),
            "max_measured_mm": round(max(all_gap_values), 6),
        },
        "motion_checks": {
            "collapsed_pair_overlap_max_mm2": round(float(collapsed_max), 6),
            "full_extension_pair_overlap_max_mm2": round(float(full_max), 6),
            "overtravel_tests": overtravel,
        },
        "notes": [
            "The 0.497-0.500 mm faceted-polygon values are the 0.50 mm CAD clearance; polygon faceting accounts for the small deviation.",
            "At a hard stop the key and keyway roof intentionally touch; during printing and normal sliding they are separated.",
        ],
    }
    (OUT / "validation_report.json").write_text(json.dumps(report, indent=2) + "\n")

    print(json.dumps(report, indent=2))
    print("\npass:", passed)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
