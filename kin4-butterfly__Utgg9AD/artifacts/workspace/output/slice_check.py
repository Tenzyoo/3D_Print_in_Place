#!/usr/bin/env python3
"""Slicing checks with PrusaSlicer (profiles in /opt/slicer, 0.4 nozzle / 0.2 layer / PLA).

1. Slice model.stl with the no-support and the auto-support profile; collect warnings and
   locate every support extrusion (must be none inside the joint zones).
2. Slice the 3 parts as 3 separate objects at their true relative positions (shifted onto the
   bed), parse the G-code per object and measure in every layer, around each joint axis:
     - the minimum horizontal gap between body beads and wing beads (bead edges, using ;WIDTH),
     - whether a bead of one part is deposited directly on/under a bead of another part in an
       adjacent layer (would fuse), and the smallest vertical layer separation of overlapping beads.
Writes slice_report.json.
"""
import json, os, re, subprocess, tempfile
import numpy as np
import trimesh
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
J = json.load(open(os.path.join(HERE, "joints.json")))
PROF = {"nosupport": "/opt/slicer/p1s_pla_0.20mm_nosupport.ini",
        "autosupport": "/opt/slicer/p1s_pla_0.20mm_autosupport.ini"}
TMP = tempfile.mkdtemp(prefix="bfly_slice_")
SHIFT = np.array([128.0, 128.0, 0.0])          # model origin -> bed centre
report = {"tmp_dir": TMP}


def run(cmd):
    p = subprocess.run(cmd, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def parse_gcode(path):
    """Return list of extrusion segments: (obj, type, z, x0, y0, x1, y1, width)."""
    segs = []; x = y = z = 0.0; e_prev = 0.0; typ = None; width = 0.42; obj = None
    relE = False
    for line in open(path):
        if line.startswith(";TYPE:"): typ = line[6:].strip(); continue
        if line.startswith(";WIDTH:"): width = float(line[7:]); continue
        if line.startswith("; printing object"):
            obj = line.split("object", 1)[1].split(" id:")[0].strip(); continue
        if line.startswith("; stop printing object"): obj = None; continue
        if line.startswith("M83"): relE = True
        if line.startswith("M82"): relE = False
        if not (line.startswith("G1 ") or line.startswith("G0 ")): continue
        c = line.split(";")[0]
        vals = dict((m[0], float(m[1:])) for m in c.split()[1:] if m[0] in "XYZEF")
        nx, ny, nz = vals.get("X", x), vals.get("Y", y), vals.get("Z", z)
        ext = False
        if "E" in vals:
            de = vals["E"] if relE else vals["E"] - e_prev
            if not relE: e_prev = vals["E"]
            ext = de > 0 and (nx != x or ny != y)
        if ext:
            segs.append((obj, typ, nz, x, y, nx, ny, width))
        x, y, z = nx, ny, nz
    return segs


def joint_xy(jt):
    return np.array(jt["origin"][:2]) + SHIFT[:2]


# ------------------------------------------------------------------ 1. model.stl
model = trimesh.load(os.path.join(HERE, "model.stl"))
m_shift = model.copy(); m_shift.apply_translation(SHIFT)
mpath = os.path.join(TMP, "model_on_bed.stl"); m_shift.export(mpath)
for name, prof in PROF.items():
    out = os.path.join(TMP, f"model_{name}.gcode")
    rc, log = run(["prusa-slicer", "--export-gcode", "--dont-arrange", "--load", prof,
                   "--output", out, mpath])
    warn = [l.strip() for l in log.splitlines() if re.search(r"warning|error|issue|adhesion|support", l, re.I)]
    segs = parse_gcode(out) if rc == 0 else []
    sup = [s for s in segs if s[1] and "upport" in s[1]]
    sup_len = sum(np.hypot(s[5] - s[3], s[6] - s[4]) for s in sup)
    in_joint = 0.0
    for s in sup:
        mid = np.array([(s[3] + s[5]) / 2, (s[4] + s[6]) / 2])
        for jt in J["joints"]:
            if np.linalg.norm(mid - joint_xy(jt)) < 10.0:
                in_joint += np.hypot(s[5] - s[3], s[6] - s[4])
    sup_xy = np.array([[(s[3] + s[5]) / 2 - SHIFT[0], (s[4] + s[6]) / 2 - SHIFT[1], s[2]] for s in sup])
    rec = dict(return_code=rc, messages=warn, layers=len({s[2] for s in segs}),
               support_extrusion_length_mm=round(float(sup_len), 1),
               support_extrusion_length_in_joint_zones_mm=round(float(in_joint), 1))
    if len(sup_xy):
        rec["support_region_bbox_model_coords"] = [np.round(sup_xy.min(0), 1).tolist(), np.round(sup_xy.max(0), 1).tolist()]
    m = re.search(r"; estimated printing time \(normal mode\) = (.*)", open(out).read()) if rc == 0 else None
    fil = re.search(r"; filament used \[cm3\] = ([\d.]+)", open(out).read()) if rc == 0 else None
    rec["estimated_time"] = m.group(1) if m else None
    rec["filament_cm3"] = float(fil.group(1)) if fil else None
    rec["filament_g_PLA_1.24"] = round(1.24 * float(fil.group(1)), 1) if fil else None
    report["model_" + name] = rec

# brim test: would a brim enter the joint gaps? (it does -> print WITHOUT brim)
out = os.path.join(TMP, "model_brim5.gcode")
rc, log = run(["prusa-slicer", "--export-gcode", "--dont-arrange", "--load", PROF["nosupport"],
               "--brim-width", "5", "--output", out, mpath])
brim = [s for s in parse_gcode(out) if s[1] == "Skirt/Brim"]
dmin = min(min(np.linalg.norm(np.array(p) - joint_xy(jt)) for jt in J["joints"])
           for s in brim for p in ((s[3], s[4]), (s[5], s[6])))
report["brim_test_5mm"] = dict(return_code=rc,
    adhesion_warning="adhesion" in log.lower(),
    min_brim_distance_to_joint_axis_mm=round(float(dmin), 2),
    ring_outer_radius_mm=7.0, body_clearance_radius_mm=7.5,
    conclusion=("brim line enters the 7.0-7.5 mm ring/body gap -> DO NOT use a brim"
                if dmin < 7.5 + 0.21 else "brim stays outside the joint gaps"))

# ------------------------------------------------------------------ 2. per-part slicing
files = []
for p in J["parts"]:
    m = trimesh.load(os.path.join(HERE, p["file"])); m.apply_translation(SHIFT)
    f = os.path.join(TMP, p["id"] + ".stl"); m.export(f); files.append(f)
segs, rcs = [], {}
for p, f in zip(J["parts"], files):
    out = os.path.join(TMP, p["id"] + "_nosupport.gcode")
    rc, log = run(["prusa-slicer", "--export-gcode", "--dont-arrange", "--load", PROF["nosupport"],
                   "--output", out, f])
    rcs[p["id"]] = rc
    # same bed coordinates for every part (no arrange) -> tag segments with the part id
    segs += [(p["id"],) + s[1:] for s in parse_gcode(out)]
objs = sorted({s[0] for s in segs})
report["per_part_slice"] = dict(return_codes=rcs, objects=objs)
# sanity: G-code XY extents of each part must match its STL bbox (+SHIFT)
ext = {}
for p in J["parts"]:
    a = np.array([[s[3], s[4]] for s in segs if s[0] == p["id"]])
    ext[p["id"]] = [np.round(a.min(0) - SHIFT[:2], 1).tolist(), np.round(a.max(0) - SHIFT[:2], 1).tolist()]
report["per_part_slice"]["gcode_xy_extents_model_coords"] = ext


def samples(seglist, step=0.1):
    pts, w = [], []
    for s in seglist:
        n = max(2, int(np.hypot(s[5] - s[3], s[6] - s[4]) / step) + 1)
        t = np.linspace(0, 1, n)
        pts.append(np.c_[s[3] + t * (s[5] - s[3]), s[4] + t * (s[6] - s[4])]); w.append(np.full(n, s[7]))
    if not pts: return np.zeros((0, 2)), np.zeros(0)
    return np.vstack(pts), np.concatenate(w)


fixed = J["fixed_part"]
joint_res = {}
for jt in J["joints"]:
    c = joint_xy(jt); child = jt["child"]
    layers = sorted({round(s[2], 2) for s in segs})
    per_layer = {}
    data = {}
    for z in layers:
        for who in (fixed, child):
            sl = [s for s in segs if round(s[2], 2) == z and s[0] and s[0].startswith(who)
                  and min(np.hypot(s[3] - c[0], s[4] - c[1]), np.hypot(s[5] - c[0], s[6] - c[1])) < 11]
            data[(who, z)] = samples(sl)
    min_h = (1e9, None)
    for z in layers:
        (pb, wb), (pw, ww) = data[(fixed, z)], data[(child, z)]
        if len(pb) and len(pw):
            d, i = cKDTree(pb).query(pw)
            gap = d - ww / 2 - wb[i] / 2
            g = float(gap.min())
            per_layer[z] = round(g, 3)
            if g < min_h[0]: min_h = (g, z)
    # vertical: overlapping beads of different parts in nearby layers
    min_sep = None
    for k, z in enumerate(layers):
        for k2 in range(k + 1, min(k + 6, len(layers))):
            z2 = layers[k2]
            for a, b in ((fixed, child), (child, fixed)):
                (p1, w1), (p2, w2) = data[(a, z)], data[(b, z2)]
                if not len(p1) or not len(p2): continue
                d, i = cKDTree(p1).query(p2)
                if np.any(d < (w2 + w1[i]) / 2 - 0.05):
                    sep = round(z2 - z, 2)
                    min_sep = sep if min_sep is None else min(min_sep, sep)
    joint_res[jt["name"]] = dict(
        layers_with_both_parts=len(per_layer),
        min_horizontal_bead_gap_mm=round(min_h[0], 3), at_layer_z=min_h[1],
        min_vertical_distance_between_overlapping_beads_of_different_parts_mm=min_sep,
        note="vertical distance = difference of layer top heights; 0.2 would mean deposited directly on top (fusion)")
report["joint_gap_in_gcode"] = joint_res
report["joint_gap_in_gcode_ok"] = all(v["min_horizontal_bead_gap_mm"] > 0.15 and
                                      (v["min_vertical_distance_between_overlapping_beads_of_different_parts_mm"] or 9) > 0.2 + 1e-6
                                      for v in joint_res.values())
json.dump(report, open(os.path.join(HERE, "slice_report.json"), "w"), indent=1)
print(json.dumps(report, indent=1))
