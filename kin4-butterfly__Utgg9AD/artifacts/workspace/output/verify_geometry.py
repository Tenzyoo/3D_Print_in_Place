#!/usr/bin/env python3
"""Geometry verification for the articulated butterfly.

Checks: mesh validity / connectivity, neutral bounding box, pin/hole radial clearance,
interference + minimum gap of all part pairs over the joint ranges (independent and
simultaneous motion), axial retention, overhangs in the joint zones.
Writes verification_report.json next to this script.
"""
import json, itertools, os, sys
import numpy as np
import trimesh
import manifold3d as m3d

HERE = os.path.dirname(os.path.abspath(__file__))
J = json.load(open(os.path.join(HERE, "joints.json")))
parts = {p["id"]: p for p in J["parts"]}
meshes = {pid: trimesh.load(os.path.join(HERE, p["file"])) for pid, p in parts.items()}
report = {}


def to_manifold(tm):
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(tm.vertices, np.float32),
                                 tri_verts=np.asarray(tm.faces, np.uint32)))


def rot_z(deg, origin):
    T = trimesh.transformations.rotation_matrix(np.radians(deg), [0, 0, 1], origin)
    return T


# ---------------------------------------------------------------- 1. mesh validity
validity = {}
for pid, m in meshes.items():
    comps = m.split(only_watertight=False)
    validity[pid] = dict(watertight=bool(m.is_watertight), winding_consistent=bool(m.is_winding_consistent),
                         volume_mm3=round(float(m.volume), 1), components=len(comps),
                         bbox_min=np.round(m.bounds[0], 2).tolist(), bbox_max=np.round(m.bounds[1], 2).tolist())
report["parts"] = validity

full = trimesh.util.concatenate(list(meshes.values()))
ext = full.bounds[1] - full.bounds[0]
report["neutral_bbox_mm"] = np.round(ext, 2).tolist()
report["neutral_bbox_ok"] = bool(ext[0] <= 120 and ext[1] <= 100 and ext[2] <= 30)
model = trimesh.load(os.path.join(HERE, "model.stl"))
report["model_stl_volume_vs_parts"] = [round(float(model.volume), 1), round(float(full.volume), 1)]

# ---------------------------------------------------------------- 2. pin / hole clearance
body = meshes[J["fixed_part"]]
clear = {}
for jt in J["joints"]:
    o = np.array(jt["origin"]); child = meshes[jt["child"]]
    def radii(m, z):
        sec = m.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
        v = sec.vertices
        r = np.hypot(v[:, 0] - o[0], v[:, 1] - o[1])
        return r[r < 6]
    rows = []
    for z in (2.5, 3.5, 4.5):                              # cylindrical shaft section
        rp = radii(body, z); rh = radii(child, z)
        rows.append((rp.min(), rp.max(), rh.min(), rh.max()))
    rows = np.array(rows)
    clear[jt["name"]] = dict(pin_radius_min_max=np.round([rows[:, 0].min(), rows[:, 1].max()], 3).tolist(),
                            hole_radius_min_max=np.round([rows[:, 2].min(), rows[:, 3].max()], 3).tolist(),
                            radial_clearance_min=round(float(rows[:, 2].min() - rows[:, 1].max()), 3),
                            radial_clearance_max=round(float(rows[:, 3].max() - rows[:, 0].min()), 3))
report["pin_hole_clearance"] = clear

# ---------------------------------------------------------------- 3. motion sweep
mf = {pid: to_manifold(m) for pid, m in meshes.items()}
jl, jr = J["joints"]


def posed(jt, ang):
    T = rot_z(ang, jt["origin"])
    return mf[jt["child"]].transform(T[:3, :4])


def pair_stats(a, b):
    inter = (a ^ b).volume()
    gap = a.min_gap(b, 3.0)
    return inter, gap


angles = list(range(-30, 31, 5))
results = []
worst = dict(inter=0.0, gap=1e9)
B = mf[J["fixed_part"]]
# (a) independent: one wing moves, the other stays at neutral / at its limits
cases = [(a, b) for a in angles for b in (-30, 0, 30)] + [(b, a) for a in angles for b in (-30, 0, 30)]
# (b) simultaneous: full grid of both wings
cases += list(itertools.product(range(-30, 31, 10), repeat=2))
cases = sorted(set(cases))
for aL, aR in cases:
    L = posed(jl, aL); R = posed(jr, aR)
    rec = dict(left=aL, right=aR)
    for name, (x, y) in dict(body_left=(B, L), body_right=(B, R), left_right=(L, R)).items():
        iv, g = pair_stats(x, y)
        rec[name] = dict(intersection_mm3=round(iv, 4), min_gap_mm=round(g, 3))
        worst["inter"] = max(worst["inter"], iv); worst["gap"] = min(worst["gap"], g)
    results.append(rec)
report["motion_cases"] = len(results)
report["motion_max_intersection_mm3"] = round(worst["inter"], 5)
report["motion_min_gap_mm"] = round(worst["gap"], 3)
report["motion_ok"] = bool(worst["inter"] < 1e-6 and worst["gap"] > 0.3)
neutral = [r for r in results if r["left"] == 0 and r["right"] == 0][0]
report["neutral_pairs"] = neutral

# physical rotation limit of each wing (other wing at neutral): first contact angle
limits = {}
for jt in J["joints"]:
    other = jr if jt is jl else jl
    O = posed(other, 0)
    lim = {}
    for sgn, key in ((1, "positive"), (-1, "negative")):
        hit = None
        for a in range(31, 120):
            W = posed(jt, sgn * a)
            if (B ^ W).volume() > 1e-4 or (O ^ W).volume() > 1e-4:
                hit = sgn * a; break
        lim[key + "_first_contact_deg"] = hit
    limits[jt["name"]] = lim
report["rotation_first_contact"] = limits

# minimum gap wing <-> body outside the joint zone (r > 9 mm from axis) at the range limits
far = {}
for jt in J["joints"]:
    o = jt["origin"]
    cyl = m3d.Manifold.cylinder(40, 9.0, 9.0, 128).translate([o[0], o[1], -5])
    rec = {}
    for a in (-30, -15, 0, 15, 30):
        W = posed(jt, a) - cyl                              # wing without its eye / root zone
        rec[str(a)] = round(B.min_gap(W, 15.0), 2)           # vs. complete body
    far[jt["name"]] = rec
report["min_gap_outside_joint_zone_mm"] = far

# ---------------------------------------------------------------- 4. axial retention
# translate each wing along +Z / -Z: it must collide with the body within a few mm
ret = {}
for jt in J["joints"]:
    w = mf[jt["child"]]; out = {}
    for sgn, key in ((1, "up"), (-1, "down")):
        hit = None
        for dz in np.arange(0.05, 6.0, 0.05):
            if (B ^ w.translate([0, 0, sgn * dz])).volume() > 1e-3:
                hit = round(float(dz), 2); break
        out[key + "_travel_until_contact_mm"] = hit
    ret[jt["name"]] = out
report["axial_retention"] = ret

# ---------------------------------------------------------------- 5. overhangs (>45 deg, off the bed)
ov = {}
for pid, m in meshes.items():
    n = m.face_normals; c = m.triangles_center; a = m.area_faces
    down = (n[:, 2] < -0.72) & (c[:, 2] > 0.25)     # steeper than ~46 deg from vertical, not on bed
    near_joint = np.zeros(len(c), bool)
    for jt in J["joints"]:
        o = jt["origin"]; near_joint |= np.hypot(c[:, 0] - o[0], c[:, 1] - o[1]) < 9.0
    ov[pid] = dict(overhang_area_total_mm2=round(float(a[down].sum()), 2),
                   overhang_area_in_joint_zone_mm2=round(float(a[down & near_joint].sum()), 2))
report["overhangs_gt45deg"] = ov

json.dump(report, open(os.path.join(HERE, "verification_report.json"), "w"), indent=1)
print(json.dumps({k: v for k, v in report.items() if k != "motion_cases_detail"}, indent=1))
