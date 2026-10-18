#!/usr/bin/env python3
"""Geometry + kinematics + slicing checks for the 3-segment folding ruler.

Run:  python3 verify.py      (from /app/output; writes verify_report.json)
"""
import json, os, re, subprocess, sys, itertools
import numpy as np
import trimesh
import manifold3d as m3d
from scipy.spatial import cKDTree
from shapely.geometry import Polygon, MultiPolygon, Point, LineString
from shapely.ops import unary_union

HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)
J = json.load(open("joints.json"))
LAYER = 0.2
report = {}


def log(*a):
    print(*a, flush=True)


# ---------------------------------------------------------------- loading
parts = [trimesh.load(f"parts/parts_{i}.stl") for i in (1, 2, 3)]
model = trimesh.load("model.stl")


def to_manifold(tm):
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(tm.vertices, np.float32),
                                 tri_verts=np.asarray(tm.faces, np.uint32)))


M = [to_manifold(p) for p in parts]

# ---------------------------------------------------------------- 1. mesh checks
mesh_info = []
for i, p in enumerate(parts, 1):
    bodies = p.split(only_watertight=False)
    mesh_info.append(dict(part=i, watertight=bool(p.is_watertight), winding_consistent=bool(p.is_winding_consistent),
                          volume_mm3=round(float(p.volume), 2), bodies=len(bodies),
                          bbox_min=np.round(p.bounds[0], 3).tolist(), bbox_max=np.round(p.bounds[1], 3).tolist()))
union_vol = sum(p.volume for p in parts)
report["mesh"] = dict(parts=mesh_info, model_watertight=bool(model.is_watertight),
                      model_bodies=len(model.split(only_watertight=False)),
                      model_volume=round(float(model.volume), 2), sum_part_volume=round(float(union_vol), 2),
                      model_bbox=[np.round(model.bounds[0], 3).tolist(), np.round(model.bounds[1], 3).tolist()])
log("mesh:", json.dumps(report["mesh"], indent=1))

# ---------------------------------------------------------------- kinematics
def rot_about(origin, axis, deg):
    T = trimesh.transformations.rotation_matrix(np.radians(deg), axis, origin)
    return T


J1, J2 = J["joints"]


def pose(a1, a2):
    T1 = rot_about(J1["axis_origin"], J1["axis_direction"], a1)
    T2 = T1 @ rot_about(J2["axis_origin"], J2["axis_direction"], a2)
    return [np.eye(4), T1, T2]


def xf(man, T):
    return man.transform(np.asarray(T[:3, :4], dtype=np.float64))


def inter_vols(a1, a2, dz=(0, 0, 0)):
    Ts = pose(a1, a2)
    P = [xf(M[k], Ts[k]) for k in range(3)]
    out = {}
    for i, j in itertools.combinations(range(3), 2):
        out[(i + 1, j + 1)] = (P[i] ^ P[j]).volume()
    return out


# surface samples for clearance estimation
rng = np.random.default_rng(0)
SAMPLES = []
for p in parts:
    pts, _ = trimesh.sample.sample_surface_even(p, 120000, seed=1)
    SAMPLES.append(np.vstack([pts, p.vertices]))


def min_clear(a1, a2):
    Ts = pose(a1, a2)
    S = [trimesh.transform_points(SAMPLES[k], Ts[k]) for k in range(3)]
    out = {}
    for i, j in itertools.combinations(range(3), 2):
        d, _ = cKDTree(S[j]).query(S[i], k=1)
        out[(i + 1, j + 1)] = float(d.min())
    return out


# 2. unfolded pose
iv0 = inter_vols(0, 0)
mc0 = min_clear(0, 0)
report["pose_0_0"] = dict(intersection_mm3={f"{k}": v for k, v in iv0.items()},
                          min_clearance_mm_sampled={f"{k}": round(v, 3) for k, v in mc0.items()})
log("pose 0/0:", report["pose_0_0"])

# 3. joint sweeps (independent) + combined grid
TOL = 1e-3
sweep = {}
for name, f in (("joint_1", lambda a: inter_vols(a, 0)), ("joint_1_with_j2_at_180", lambda a: inter_vols(a, 180)),
                ("joint_2", lambda a: inter_vols(0, a)), ("joint_2_with_j1_at_180", lambda a: inter_vols(180, a))):
    worst = 0.0
    for a in np.arange(0, 180.0001, 1.0):
        worst = max(worst, max(f(a).values()))
    sweep[name] = dict(step_deg=1, max_intersection_mm3=worst, ok=worst < TOL)
grid_worst, grid_n = 0.0, 0
for a1 in np.arange(0, 180.0001, 7.5):
    for a2 in np.arange(0, 180.0001, 7.5):
        grid_worst = max(grid_worst, max(inter_vols(a1, a2).values()))
        grid_n += 1
sweep["combined_grid"] = dict(step_deg=7.5, poses=grid_n, max_intersection_mm3=grid_worst, ok=grid_worst < TOL)
clear_poses = {}
for a1, a2 in [(0, 0), (45, 45), (90, 0), (90, 90), (90, 180), (180, 0), (180, 90), (180, 180), (0, 180), (135, 135)]:
    clear_poses[f"{a1}/{a2}"] = {f"{k}": round(v, 3) for k, v in min_clear(a1, a2).items()}
sweep["min_clearance_mm_sampled"] = clear_poses
report["motion"] = sweep
log("motion:", json.dumps(sweep, indent=1))


# 4. hard stops (first colliding angle outside 0..180)
def first_hit(f, direction):
    a = 0.0
    while abs(a) < 30:
        a += 0.1 * direction
        if max(f(a).values()) > TOL:
            return round(a, 1)
    return None


report["hard_stops_deg"] = dict(
    joint_1_below_0=first_hit(lambda a: inter_vols(a, 0), -1),
    joint_1_above_180=round(180 + first_hit(lambda a: inter_vols(180 + a, 0), +1), 1),
    joint_2_below_0=first_hit(lambda a: inter_vols(0, a), -1),
    joint_2_above_180=round(180 + first_hit(lambda a: inter_vols(0, 180 + a), +1), 1))
log("hard stops:", report["hard_stops_deg"])


# 5. axial retention: translate child along Z / XY, find free travel
def free_travel(child, axis_vec, at_angle=0.0, step=0.02, limit=6.0):
    parent = child - 1
    jt = J["joints"][parent - 1]
    R = rot_about(jt["axis_origin"], jt["axis_direction"], at_angle)
    base = xf(M[child - 1], R)
    t = 0.0
    while t < limit:
        t += step
        moved = base.translate(tuple(np.array(axis_vec) * t))
        if (moved ^ M[parent - 1]).volume() > TOL:
            return round(t, 2)
    return None


ret = {}
for child in (2, 3):
    for ang in (0, 90, 180):
        ret[f"joint_{child-1}@{ang}deg"] = dict(up_Z_blocked_after_mm=free_travel(child, (0, 0, 1), ang),
                                               down_Z_blocked_after_mm=free_travel(child, (0, 0, -1), ang))
report["axial_retention"] = ret
log("retention:", ret)


# ---------------------------------------------------------------- 6. per-layer sections
def section_polys(tm, z):
    s = tm.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
    if s is None:
        return Polygon()
    p2, T = s.to_2D()
    polys = [Polygon(np.asarray(pl.exterior.coords), [np.asarray(h.coords) for h in pl.interiors]) for pl in p2.polygons_full]
    g = unary_union(polys)
    # back to world XY
    from shapely.affinity import affine_transform
    return affine_transform(g, [T[0, 0], T[0, 1], T[1, 0], T[1, 1], T[0, 3], T[1, 3]])


nl = int(round(5.0 / LAYER))
layers = []
min_xy_gap = 1e9
for L in range(nl):
    z = (L + 0.5) * LAYER
    S = [section_polys(p, z) for p in parts]
    gaps = [S[i].distance(S[j]) for i, j in itertools.combinations(range(3), 2)]
    g = min(gaps)
    min_xy_gap = min(min_xy_gap, g)
    layers.append(dict(layer=L + 1, z_mid=round(z, 2), min_gap_between_parts_mm=round(g, 3),
                       areas=[round(s.area, 1) for s in S]))
# vertical gap above the rings: cap (part k) over ring (part k+1)
vgap = {}
for k, jt in enumerate(J["joints"], 1):
    A, B = parts[k - 1], parts[k]
    occ = []
    px, py = jt["axis_origin"][:2]
    sgn = 1 if py > 0 else -1
    # sector of the annulus that lies inside the parent (A) band: x < px, sgn*y < sgn*py
    from shapely.geometry import box
    quad = box(px - 10, py - 10, px - 0.3, py - 0.3) if sgn > 0 else box(px - 10, py + 0.3, px - 0.3, py + 10)
    c = Point(px, py).buffer(4.9).difference(Point(px, py).buffer(3.8)).intersection(quad)
    for L in range(nl):
        z = (L + 0.5) * LAYER
        a = section_polys(A, z).intersection(c).area
        b = section_polys(B, z).intersection(c).area
        occ.append("A" if a > 0.5 and b < 0.5 else "B" if b > 0.5 and a < 0.5 else "AB" if a > 0.5 else "-")
    vgap[jt["name"]] = "".join(x[0] if x != "AB" else "X" for x in occ)
report["layers"] = dict(min_xy_gap_between_parts_mm=round(min_xy_gap, 3),
                        per_layer=layers,
                        joint_zone_layer_occupancy_bottom_to_top=vgap,
                        legend="layers 1..25 inside the joint annulus r=3.8..4.9 under the parent cap sector: B=ring of child only, '-'=empty gap layer, A=cap of parent only, X=both present in same layer (in the joint annulus, different sectors)")
log("min XY gap per layer:", round(min_xy_gap, 3), "joint stacks:", vgap)

# ---------------------------------------------------------------- 7. overhang classification
ovh = []
for i, p in enumerate(parts, 1):
    n = p.face_normals
    c = p.triangles_center
    down = (n[:, 2] < -1e-6) & (c[:, 2] > 1e-3)
    ang = np.degrees(np.arcsin(np.clip(-n[down, 2], 0, 1)))  # 90 = horizontal ceiling, 0 = vertical wall
    area = p.area_faces[down]
    # angle from horizontal of the downward surface = 90 - ang
    surf_from_h = 90 - ang
    ovh.append(dict(part=i,
                    horizontal_downfacing_area_mm2=round(float(area[surf_from_h < 1].sum()), 2),
                    horizontal_downfacing_z=sorted(set(np.round(c[down][surf_from_h < 1][:, 2], 2).tolist())),
                    sloped_downfacing_min_angle_from_horizontal_deg=(round(float(surf_from_h[surf_from_h >= 1].min()), 1)
                                                                    if (surf_from_h >= 1).any() else None),
                    sloped_downfacing_area_mm2=round(float(area[surf_from_h >= 1].sum()), 2)))
report["overhangs"] = ovh
log("overhangs:", ovh)

# ---------------------------------------------------------------- 8. PrusaSlicer
def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


slicer = {}
rc, out = run(["prusa-slicer", "--info", "model.stl"])
slicer["info"] = out.strip().splitlines()[-12:]
gc = {}
for prof in ("nosupport", "autosupport"):
    gpath = f"/tmp/ruler_{prof}.gcode"
    rc, out = run(["prusa-slicer", "--export-gcode", "--load", f"/opt/slicer/p1s_pla_0.20mm_{prof}.ini",
                   "--center", "128,128", "--output", gpath, "model.stl"])
    txt = open(gpath).read() if rc == 0 else ""
    types = {}
    for m in re.finditer(r";TYPE:(.+)", txt):
        types[m.group(1).strip()] = types.get(m.group(1).strip(), 0) + 1
    est = re.search(r"estimated printing time \(normal mode\) = (.+)", txt)
    fil = re.search(r"filament used \[cm3\] = (.+)", txt)
    gc[prof] = dict(returncode=rc, feature_types=types,
                    support_material_present=any("Support" in t for t in types),
                    est_time=est.group(1) if est else None, filament_cm3=fil.group(1) if fil else None,
                    filament_g_PLA_1p24=round(float(fil.group(1)) * 1.24, 1) if fil else None,
                    layers=txt.count(";LAYER_CHANGE"))
    log(prof, gc[prof])
slicer["gcode"] = gc


# 9. G-code path analysis (nosupport): every extrusion must lie on exactly one part's layer section
def parse_layers(path):
    z, x, y, e_abs = 0.0, None, None, True
    segs = {}
    cur_type = None
    for line in open(path):
        if line.startswith(";Z:"):
            z = round(float(line[3:]), 3)
            continue
        if line.startswith(";TYPE:"):
            cur_type = line[6:].strip()
            continue
        if not line.startswith(("G1", "G0")):
            continue
        parts_ = dict((w[0], float(w[1:])) for w in line.split(";")[0].split()[1:] if w[0] in "XYZE")
        nx, ny = parts_.get("X", x), parts_.get("Y", y)
        if "E" in parts_ and parts_["E"] > 0 and x is not None and line.startswith("G1"):
            segs.setdefault(z, []).append((x, y, nx, ny, cur_type))
        x, y = nx, ny
    return segs


segs = parse_layers("/tmp/ruler_nosupport.gcode")
allx = [s[0] for L in segs.values() for s in L] + [s[2] for L in segs.values() for s in L]
ally = [s[1] for L in segs.values() for s in L] + [s[3] for L in segs.values() for s in L]
off = np.array([128.0, 128.0]) - (model.bounds[0][:2] + model.bounds[1][:2]) / 2
gbb = [min(allx) - off[0], max(allx) - off[0], min(ally) - off[1], max(ally) - off[1]]
cross, stray, checked = 0, 0, 0
cross_examples = []
for z, L in sorted(segs.items()):
    zm = z - LAYER / 2
    S = [section_polys(p, zm) for p in parts]
    for (x0, y0, x1, y1, t) in L:
        a = np.array([x0, y0]) - off
        b = np.array([x1, y1]) - off
        n = max(2, int(np.linalg.norm(b - a) / 0.1) + 1)
        owners = set()
        for s in np.linspace(0, 1, n):
            q = Point(*(a + (b - a) * s))
            d = [Si.distance(q) for Si in S]
            k = int(np.argmin(d))
            if d[k] > 0.30:
                stray += 1
            owners.add(k) if d[k] < 0.05 else None
        checked += 1
        if len(owners) > 1:
            cross += 1
            if len(cross_examples) < 5:
                cross_examples.append(dict(z=z, type=t, a=a.round(2).tolist(), b=b.round(2).tolist()))
slicer["gcode_path_check"] = dict(
    extrusion_segments_checked=checked,
    segments_touching_two_parts=cross,
    sample_points_farther_than_0p3mm_from_any_part=stray,
    examples=cross_examples,
    gcode_bbox_in_model_coords=np.round(gbb, 2).tolist())
log("gcode path check:", slicer["gcode_path_check"])

# gap-layer check: no extrusion inside the ring/cap annulus of the joint in the 2 gap layers
gap_layers = {}
for jt in J["joints"]:
    c = np.array(jt["axis_origin"][:2])
    zone = Point(*c).buffer(4.9).difference(Point(*c).buffer(2.65))
    A_band = parts[jt["connects_parts"][0] - 1]
    cnt = {}
    for z in (2.6, 2.8):
        n_in = 0
        Sa = section_polys(A_band, z - 0.1)
        zoneA = zone.difference(section_polys(parts[jt["connects_parts"][1] - 1], z - 0.1).buffer(0.3))
        for (x0, y0, x1, y1, t) in segs.get(z, []):
            ln = LineString([tuple(np.array([x0, y0]) - off), tuple(np.array([x1, y1]) - off)])
            if ln.intersects(zoneA.buffer(-0.25)):
                n_in += 1
        cnt[f"z_top={z}"] = n_in
    gap_layers[jt["name"]] = cnt
slicer["gap_layer_extrusions_in_joint_clearance"] = gap_layers
log("gap layers:", gap_layers)
report["slicer"] = slicer

# ---------------------------------------------------------------- summary
ok = dict(
    parts_watertight=all(m["watertight"] and m["bodies"] == 1 for m in mesh_info),
    no_intersection_unfolded=max(iv0.values()) < TOL,
    joint_sweeps_ok=all(v["ok"] for k, v in sweep.items() if isinstance(v, dict) and "ok" in v),
    axial_retention_ok=all(v["up_Z_blocked_after_mm"] and v["down_Z_blocked_after_mm"] and
                           v["up_Z_blocked_after_mm"] < 1.0 and v["down_Z_blocked_after_mm"] < 1.0 for v in ret.values()),
    layer_gaps_open=min_xy_gap > 0.35,
    no_support_in_autosupport_slice=not gc["autosupport"]["support_material_present"],
    gcode_no_cross_part_extrusion=cross == 0,
)
report["summary"] = ok
log("SUMMARY:", ok)
json.dump(report, open("verify_report.json", "w"), indent=1, default=str)
