#!/usr/bin/env python3
"""Slice-level check: parse PrusaSlicer G-code of model.stl and verify that, on
every layer, the deposited material (extrusion centre-lines buffered by their
line width) of two jointed parts never touches, and that no support material
was generated.

Usage: python3 slice_check.py /tmp/snake_auto.gcode
"""
import sys, json, re
import numpy as np
import trimesh
from shapely.geometry import LineString, Point
from shapely.ops import unary_union

gfile = sys.argv[1]
J = json.load(open("joints.json"))
parts = {p["id"]: trimesh.load(p["file"]) for p in J["parts"]}

layers = {}           # z -> list of (type, width, x0,y0,x1,y1)
z = 0.0; typ = None; width = 0.42; x = y = 0.0; rel_e = False; e_last = 0.0
types_seen = set()
for line in open(gfile):
    if line.startswith(";Z:"):
        z = float(line[3:]); continue
    if line.startswith(";TYPE:"):
        typ = line[6:].strip(); types_seen.add(typ); continue
    if line.startswith(";WIDTH:"):
        width = float(line[7:]); continue
    if line.startswith("M83"): rel_e = True
    if line.startswith("M82"): rel_e = False
    if line.startswith("G92"):
        m = re.search(r"E([-\d.]+)", line)
        if m: e_last = float(m.group(1))
    if not (line.startswith("G1 ") or line.startswith("G0 ")): continue
    c = line.split(";")[0]
    mx = re.search(r"X([-\d.]+)", c); my = re.search(r"Y([-\d.]+)", c); me = re.search(r"E([-\d.]+)", c)
    nx = float(mx.group(1)) if mx else x; ny = float(my.group(1)) if my else y
    extr = False
    if me:
        ev = float(me.group(1))
        extr = ev > 0 if rel_e else ev > e_last
        if not rel_e: e_last = ev
    if extr and (nx, ny) != (x, y) and typ not in ("Custom", None):
        layers.setdefault(round(z, 2), []).append((typ, width, x, y, nx, ny))
    x, y = nx, ny

# G-code is placed on the bed: find XY shift from the model frame
allpts = np.array([[s[2], s[3]] for L in layers.values() for s in L])
model = trimesh.load("model.stl")
shift = (allpts.min(0) + allpts.max(0)) / 2 - (model.bounds[0][:2] + model.bounds[1][:2]) / 2


def section(m, zz):
    s = m.section(plane_origin=[0, 0, zz], plane_normal=[0, 0, 1])
    if s is None: return None
    p2, _ = s.to_2D(to_2D=np.eye(4))
    return unary_union(list(p2.polygons_full))


worst = {jt["id"]: 1e9 for jt in J["joints"]}
worst_z = {}
unassigned = 0
for zl, segs in sorted(layers.items()):
    secs = {pid: section(m, zl - 0.1) for pid, m in parts.items()}
    geo = {pid: [] for pid in parts}
    for typ, w, x0, y0, x1, y1 in segs:
        a = np.array([x0, y0]) - shift; b = np.array([x1, y1]) - shift
        mid = Point(*(a + b) / 2)
        best = min(((secs[p].distance(mid) if secs[p] is not None else 1e9, p) for p in parts))
        if best[0] > 0.5: unassigned += 1
        geo[best[1]].append(LineString([a, b]).buffer(w / 2, cap_style=1, resolution=4))
    mat = {p: unary_union(g) if g else None for p, g in geo.items()}
    for jt in J["joints"]:
        A, B = mat[jt["parent"]], mat[jt["child"]]
        if A is None or B is None: continue
        d = A.distance(B)
        if d < worst[jt["id"]]: worst[jt["id"]] = d; worst_z[jt["id"]] = zl

res = dict(gcode=gfile, layers=len(layers), extrusion_types=sorted(types_seen),
           support_material_present=any("Support" in t for t in types_seen),
           min_material_gap_between_jointed_parts_mm={k: round(v, 3) for k, v in worst.items()},
           at_layer_z=worst_z, unassigned_segments=unassigned)
print(json.dumps(res, indent=1))
json.dump(res, open("slice_report.json", "w"), indent=1)
