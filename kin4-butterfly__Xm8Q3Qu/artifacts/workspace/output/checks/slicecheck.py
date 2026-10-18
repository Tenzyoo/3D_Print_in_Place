"""Slice model.stl with PrusaSlicer and check the toolpaths.  usage: slicecheck.py OUTDIR RESULT.json"""
import sys, re, json, subprocess, numpy as np, trimesh
from shapely.geometry import Polygon, Point
from shapely.ops import unary_union
from shapely import prepared
from scipy.spatial import cKDTree
OUT, RES = sys.argv[1], sys.argv[2]
J = json.load(open(f"{OUT}/joints.json"))
parts = {p["name"]: trimesh.load(f"{OUT}/{p['file']}") for p in J["parts"]}
model = trimesh.load(f"{OUT}/model.stl")
axes = [np.array(j["origin"][:2]) for j in J["joints"]]
C = np.array([128.0, 128.0]); shift = C - (model.bounds[0][:2] + model.bounds[1][:2]) / 2
R = {}

def run(args):
    p = subprocess.run(["prusa-slicer"] + args, capture_output=True, text=True); return p.returncode, p.stdout + p.stderr
rc, info = run(["--info", f"{OUT}/model.stl"]); R["prusa_info"] = info.strip().splitlines()

def slice_(ini, out):
    rc, log = run(["--export-gcode", "--load", ini, "--center", "128,128", "--output", out, f"{OUT}/model.stl"])
    return rc, log.strip().splitlines()[-3:]

def parse(path):
    """-> list of (z, type, width, [(x0,y0,x1,y1)...]) extrusion moves"""
    segs = []; x = y = z = 0.0; e = 0.0; rel = False; typ = None; w = None
    for line in open(path):
        if line.startswith(";TYPE:"): typ = line[6:].strip(); continue
        if line.startswith(";WIDTH:"): w = float(line[7:]); continue
        if line.startswith(";Z:"): z = float(line[3:]); continue
        if line.startswith("M83"): rel = True
        if line.startswith("M82"): rel = False
        if line.startswith("G92"):
            m = re.search(r"E([-\d.]+)", line); e = float(m.group(1)) if m else e; continue
        if not (line.startswith("G1 ") or line.startswith("G0 ")): continue
        c = line.split(";")[0]
        nx = re.search(r"X([-\d.]+)", c); ny = re.search(r"Y([-\d.]+)", c); ne = re.search(r"E([-\d.]+)", c); nz = re.search(r"Z([-\d.]+)", c)
        x1 = float(nx.group(1)) if nx else x; y1 = float(ny.group(1)) if ny else y
        de = 0.0
        if ne: v = float(ne.group(1)); de = v if rel else v - e; e = e + v if rel else v
        if de > 0 and (x1 != x or y1 != y): segs.append((z, typ, w, x, y, x1, y1))
        x, y = x1, y1
    return segs

def sec(m, z):
    s = m.section([0, 0, 1], [0, 0, z])
    if s is None: return Polygon()
    p2, _ = s.to_2D(to_2D=np.eye(4)); return unary_union(list(p2.polygons_full)).buffer(0)

# ---- slice without supports (the intended print) ----
g_ns = "/tmp/butterfly_model_nosupport.gcode"
rc, log = slice_("/opt/slicer/p1s_pla_0.20mm_nosupport.ini", g_ns); R["nosupport_slice"] = dict(rc=rc, log=log)
txt = open(g_ns).read()
for k in ["estimated printing time (normal mode)", "filament used [g]", "filament used [mm]"]:
    m = re.search(r"; " + re.escape(k) + r" = (.+)", txt); R["nosupport_slice"][k] = m.group(1) if m else None
segs = parse(g_ns)
R["nosupport_slice"]["layers"] = len(set(s[0] for s in segs))
R["nosupport_slice"]["support_extrusions"] = sum(1 for s in segs if s[1] and "Support" in s[1])

# ---- per-layer toolpath ownership + printed gap between parts ----
names = list(parts)
by_z = {}
for s in segs: by_z.setdefault(round(s[0], 3), []).append(s)
cross = 0; stray_pts = 0; tot_pts = 0; min_center_gap = {}; worst = {}
for z, L in sorted(by_z.items()):
    zc = z - 0.1
    polys = {n: sec(parts[n], zc) for n in names}
    prep = {n: prepared.prep(p.buffer(0.12)) for n, p in polys.items() if not p.is_empty}
    pts_by_part = {n: [] for n in names}
    for (_, typ, w, x0, y0, x1, y1) in L:
        n_s = max(2, int(np.hypot(x1 - x0, y1 - y0) / 0.15) + 1)
        P = np.column_stack([np.linspace(x0, x1, n_s), np.linspace(y0, y1, n_s)]) - shift
        owners = set()
        for p in P:
            tot_pts += 1
            hit = [n for n, pr in prep.items() if pr.contains(Point(p))]
            if not hit: stray_pts += 1
            owners.update(hit)
            for n in hit: pts_by_part[n].append((p[0], p[1], w or 0.45))
        if len(owners) > 1: cross += 1
    # nearest toolpath centreline distance between different parts, minus half widths
    for a in range(len(names)):
        for b in range(a + 1, len(names)):
            A, B = np.array(pts_by_part[names[a]]), np.array(pts_by_part[names[b]])
            if len(A) == 0 or len(B) == 0: continue
            d, i = cKDTree(B[:, :2]).query(A[:, :2]); k = d.argmin()
            gap = d[k] - A[k, 2] / 2 - B[i[k], 2] / 2
            key = f"{names[a]}|{names[b]}"
            if gap < worst.get(key, (9e9,))[0]: worst[key] = (round(float(gap), 3), z, (A[k, :2]).round(2).tolist())
R["toolpath_check"] = dict(layers_checked=len(by_z), extrusion_sample_points=tot_pts,
                           points_outside_every_part=stray_pts, segments_joining_two_parts=cross,
                           min_printed_gap_between_parts_mm={k: dict(gap=v[0], layer_z=v[1], at_xy=v[2]) for k, v in worst.items()})

# ---- slice with automatic supports: does the slicer want any support, and where? ----
g_as = "/tmp/butterfly_model_autosupport.gcode"
rc, log = slice_("/opt/slicer/p1s_pla_0.20mm_autosupport.ini", g_as); R["autosupport_slice"] = dict(rc=rc, log=log)
sup = [s for s in parse(g_as) if s[1] and "Support" in s[1]]
near = 0; length = 0.0; locs = []
for (z, typ, w, x0, y0, x1, y1) in sup:
    p = (np.array([x0 + x1, y0 + y1]) / 2) - shift; length += np.hypot(x1 - x0, y1 - y0)
    if min(np.linalg.norm(p - a) for a in axes) < 10: near += 1
    locs.append([round(p[0], 1), round(p[1], 1), z])
R["autosupport_slice"].update(support_segments=len(sup), support_length_mm=round(length, 1),
                              support_segments_within_10mm_of_a_joint_axis=near, sample_locations=locs[:15])
json.dump(R, open(RES, "w"), indent=1); print(json.dumps(R, indent=1))
