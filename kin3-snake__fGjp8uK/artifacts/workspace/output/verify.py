#!/usr/bin/env python3
"""Geometry verification for the print-in-place snake.

Usage: python3 verify.py  (run inside /app/output)
Writes verify_report.json and prints a summary.
"""
import json, math, itertools
import numpy as np
import trimesh
import manifold3d as m3d
from shapely.geometry import Polygon, MultiPolygon
from shapely.ops import unary_union

OUT = "."
J = json.load(open(f"{OUT}/joints.json"))
parts = {p["id"]: trimesh.load(f"{OUT}/{p['file']}") for p in J["parts"]}
order = [p["id"] for p in J["parts"]]
rep = {}


def to_man(tm):
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(tm.vertices, np.float32),
                                 tri_verts=np.asarray(tm.faces, np.uint32)))


def xform(tm, axis_pt, ang_deg, dz=0.0):
    T = trimesh.transformations.rotation_matrix(math.radians(ang_deg), [0, 0, 1], axis_pt)
    T[2, 3] += dz
    m = tm.copy(); m.apply_transform(T); return m


def inter_vol(a, b):
    return (to_man(a) ^ to_man(b)).volume()


# ---- 1. mesh sanity + overall size
rep["parts"] = {}
for pid, m in parts.items():
    rep["parts"][pid] = dict(watertight=bool(m.is_watertight), volume_mm3=round(float(m.volume), 1),
                             bodies=len(m.split(only_watertight=False)),
                             bounds=np.round(m.bounds, 2).tolist())
model = trimesh.load(f"{OUT}/model.stl")
ext = model.bounds[1] - model.bounds[0]
rep["model_extent_xyz"] = np.round(ext, 2).tolist()
rep["model_within_160x50x40"] = bool(ext[0] <= 160 and ext[1] <= 50 and ext[2] <= 40)
rep["model_bodies"] = len(model.split(only_watertight=False))
rep["model_volume_vs_sum_parts"] = [round(float(model.volume), 1),
                                    round(sum(float(m.volume) for m in parts.values()), 1)]

# ---- 2. neutral: no pairwise overlap
ov = {}
for a, b in itertools.combinations(order, 2):
    v = inter_vol(parts[a], parts[b])
    if v > 1e-6: ov[f"{a}-{b}"] = v
rep["neutral_overlaps"] = ov


# ---- 3. per-layer clearance between different parts (what the slicer sees)
def section(m, z):
    s = m.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
    if s is None: return None
    p2, _ = s.to_2D(to_2D=np.eye(4))
    polys = [Polygon(p) for p in p2.polygons_full]
    return unary_union(polys) if polys else None


Hmax = model.bounds[1][2]
layer_min = []
for z in np.arange(0.1, Hmax, 0.2):
    secs = {pid: section(m, z) for pid, m in parts.items()}
    dmin = 1e9
    for jt in J["joints"]:
        a, b = secs.get(jt["parent"]), secs.get(jt["child"])
        if a is None or b is None: continue
        dmin = min(dmin, a.distance(b))
    layer_min.append((round(float(z), 2), round(dmin, 3)))
rep["min_xy_gap_between_jointed_parts_per_layer_min"] = min(d for _, d in layer_min)
rep["layer_gap_table"] = layer_min


# ---- 4. pin radial clearance measured on sections
def pin_gap(jt, z):
    c = np.array(jt["origin"][:2])
    a = section(parts[jt["parent"]], z); b = section(parts[jt["child"]], z)
    from shapely.geometry import Point
    disk = Point(*c).buffer(9.0, 256)
    return round(a.intersection(disk).distance(b.intersection(disk)), 3)


rep["pin_gap_at_z"] = {jt["id"]: {str(z): pin_gap(jt, z) for z in (1.0, 2.5, 7.0, 12.0)} for jt in J["joints"]}


# ---- 5. motion sweep per joint (rear sub-chain rotates, rest fixed)
def chain_after(jt):
    i = order.index(jt["child"]); return order[i:], order[:i]


rep["motion"] = {}
for jt in J["joints"]:
    moving, fixed = chain_after(jt)
    o = jt["origin"]
    fixed_m = to_man(trimesh.util.concatenate([parts[p] for p in fixed]))
    free = {}
    for sgn in (1, -1):
        last_ok = 0
        for ang in np.arange(1, 46, 1):
            mv = to_man(trimesh.util.concatenate([xform(parts[p], o, sgn * ang) for p in moving]))
            if (fixed_m ^ mv).volume() > 1e-4: break
            last_ok = ang
        free["+" if sgn > 0 else "-"] = int(last_ok)
    # fine check over the declared range (0.5 deg) for the child only vs parent
    lo, hi = jt["range_deg"]
    worst = 0.0
    for ang in np.arange(lo, hi + 1e-9, 0.5):
        worst = max(worst, inter_vol(parts[jt["parent"]], xform(parts[jt["child"]], o, ang)))
    # axial retention: smallest lift/drop of the child that causes interference
    def first_hit(sign):
        for dz in np.arange(0.05, 3.0, 0.05):
            if inter_vol(parts[jt["parent"]], xform(parts[jt["child"]], o, 0, sign * dz)) > 1e-3:
                return round(float(dz), 2)
        return None
    def first_hit_x(dx_sign):
        for dx in np.arange(0.05, 5.0, 0.05):
            m = parts[jt["child"]].copy(); m.apply_translation([dx_sign * dx, 0, 0])
            if inter_vol(parts[jt["parent"]], m) > 1e-3:
                return round(float(dx), 2)
        return None
    rep["motion"][jt["id"]] = dict(collision_free_deg=free,
                                   pull_out_rear_dx=first_hit_x(-1),
                                   max_overlap_in_declared_range=worst,
                                   axial_lock_up_dz=first_hit(1), axial_lock_down_dz=first_hit(-1))


# ---- 6. combined poses (all joints at once, forward kinematics)
def pose(angles):
    meshes = {}
    T = np.eye(4)
    meshes[order[0]] = parts[order[0]].copy()
    for jt, a in zip(J["joints"], angles):
        R = trimesh.transformations.rotation_matrix(math.radians(a), [0, 0, 1], jt["origin"])
        T = T @ R
        m = parts[jt["child"]].copy(); m.apply_transform(T); meshes[jt["child"]] = m
    tot = 0.0
    for a, b in itertools.combinations(order, 2):
        tot += inter_vol(meshes[a], meshes[b])
    return tot


rep["combined_poses_overlap_mm3"] = {str(p): pose(p) for p in
                                     ([25] * 5, [-25] * 5, [30] * 5, [-30] * 5, [25, -25, 25, -25, 25])}


# ---- 7. overhang check: downward faces flatter than 45 deg above the bed
def overhang(m, tol_deg=1.0):
    n = m.face_normals; c = m.triangles_center
    lim = -math.cos(math.radians(45 - tol_deg))
    bad = (n[:, 2] < lim) & (c[:, 2] > 0.05)
    ledge = bad & (c[:, 2] <= 0.21)          # 0.2 mm first-layer relief ledge
    return dict(first_layer_relief_ledge=round(float(m.area_faces[ledge].sum()), 3),
                above_first_layer=round(float(m.area_faces[bad & ~ledge].sum()), 3))


rep["overhang_area_gt45_mm2"] = {pid: overhang(m) for pid, m in parts.items()}

json.dump(rep, open(f"{OUT}/verify_report.json", "w"), indent=1)
short = {k: v for k, v in rep.items() if k != "layer_gap_table"}
print(json.dumps(short, indent=1))
