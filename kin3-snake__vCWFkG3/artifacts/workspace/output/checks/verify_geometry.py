"""Geometry / kinematics verification of the snake STLs (reads joints.json)."""
import json, math, sys, itertools
import numpy as np, trimesh, manifold3d as mf
from shapely.geometry import Point

ROOT = sys.argv[1] if len(sys.argv) > 1 else "/app/output"
J = json.load(open(f"{ROOT}/joints.json"))
meshes = [trimesh.load(f"{ROOT}/{p['file']}") for p in J["parts"]]
M = [mf.Manifold(mf.Mesh(vert_properties=np.asarray(m.vertices, np.float32),
                         tri_verts=np.asarray(m.faces, np.uint32))) for m in meshes]
EPS = 1e-3   # mm^3 – boolean noise threshold
rep = []
def log(s=""):
    print(s); rep.append(s)

def rot(man, origin, ang):
    return man.translate([-origin[0], -origin[1], 0]).rotate([0, 0, ang]).translate([origin[0], origin[1], 0])

def inter_vol(a, b):
    return (a ^ b).volume()

def gap(a, b, search=3.0):
    return a.min_gap(b, search)

# ---------------- 1. parts ----------------
log("== 1. Parts ==")
for p, m, man in zip(J["parts"], meshes, M):
    log(f"part {p['id']} {p['name']:8s} watertight={m.is_watertight} winding_ok={m.is_winding_consistent} "
        f"shells={len(m.split(only_watertight=False))} manifold_status={man.status().name} "
        f"vol={m.volume:8.1f} mm3 bbox={np.round(m.bounds,2).tolist()}")
full = trimesh.load(f"{ROOT}/model.stl")
ext = full.bounds[1] - full.bounds[0]
log(f"model.stl: watertight={full.is_watertight} shells={len(full.split(only_watertight=False))} "
    f"vol={full.volume:.1f} (sum parts {sum(m.volume for m in meshes):.1f})")
log(f"overall extents X×Y×Z = {ext[0]:.2f} × {ext[1]:.2f} × {ext[2]:.2f} mm (limit 160×50×40) "
    f"-> {'OK' if (ext <= [160, 50, 40]).all() else 'FAIL'}")
same = np.allclose(np.sort(full.vertices, axis=0)[[0, -1]],
                   np.sort(np.vstack([m.vertices for m in meshes]), axis=0)[[0, -1]])
log(f"model.stl and parts share coordinate frame: {same}")

# ---------------- 2. neutral pose ----------------
log("\n== 2. Neutral pose: pairwise interference / minimum gap ==")
for i, j in itertools.combinations(range(6), 2):
    v = inter_vol(M[i], M[j]); g = gap(M[i], M[j], 5.0)
    if v > EPS or g < 5.0:
        log(f"parts {i+1}-{j+1}: overlap={v:.4f} mm3  min_gap={g:.3f} mm")

# ---------------- 3. radial clearance from cross-sections ----------------
log("\n== 3. Radial clearance pin/bore measured on horizontal sections ==")
for jt in J["joints"]:
    o = np.array(jt["origin"][:2]); par, ch = meshes[jt["parent_part"]-1], meshes[jt["child_part"]-1]
    res = []
    for z in [1.0, 2.0, 3.5, 6.0, 8.5, 10.0, 11.0]:
        rs = []
        for mesh in (ch, par):
            sec = mesh.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
            pts = np.vstack([e for e in sec.discrete]) [:, :2] - o
            r = np.hypot(*pts.T); a = np.degrees(np.arctan2(pts[:, 1], pts[:, 0]))
            keep = (np.abs(a) < 100) & (r < 7.6)          # away from the neck/opening
            rs.append(r[keep])
        res.append((z, rs[0].max(), rs[1].min(), rs[1].min() - rs[0].max()))
    log(f"joint {jt['id']}: " + "  ".join(f"z={z:4.1f}: pin r={a:.3f} bore r={b:.3f} clr={c:.3f}" for z, a, b, c in res[:7:2]))
    log(f"         min/max radial clearance over sections = {min(r[3] for r in res):.3f} / {max(r[3] for r in res):.3f} mm")

# ---------------- 4. joint rotation sweeps ----------------
log("\n== 4. Joint rotation sweep (child subtree rotated, rest fixed) ==")
stops = {}
for jt in J["joints"]:
    k = jt["id"]; o = jt["origin"]
    fixed = mf.Manifold.batch_boolean([M[i] for i in range(k)], mf.OpType.Add)
    mov = mf.Manifold.batch_boolean([M[i-1] for i in jt["moving_parts_when_rotated"]], mf.OpType.Add)
    lo, hi = jt["range_deg"]
    worst = (1e9, None)
    for a in np.arange(lo, hi + 1e-9, 1.0):
        mm = rot(mov, o, a)
        v = inter_vol(fixed, mm)
        g = gap(fixed, mm, 3.0)
        if v > EPS: log(f"  joint {k} angle {a:+.0f}: INTERFERENCE {v:.4f} mm3")
        worst = min(worst, (g, a))
    # find hard stop each side
    st = []
    for sgn in (+1, -1):
        a = hi if sgn > 0 else lo
        while abs(a) < 90 and inter_vol(fixed, rot(mov, o, a)) <= EPS:
            a += sgn * 0.1
        st.append(round(a, 1))
    stops[k] = st
    log(f"joint {k}: range {lo:+.0f}..{hi:+.0f} deg collision-free; min gap in range {worst[0]:.3f} mm "
        f"(at {worst[1]:+.0f} deg); first contact at {st[0]:+.1f} / {st[1]:+.1f} deg")

# combined poses (all joints at limits simultaneously)
log("\n== 5. Combined poses (all 5 joints at once) ==")
for name, angs in [("all +30", [30]*5), ("all -30", [-30]*5), ("alternating ±30", [30, -30, 30, -30, 30])]:
    T = [M[0]]
    acc = M[1:]
    posed = list(M)
    # apply from the tail to the head so that each joint rotation is about its neutral axis
    for jt, a in reversed(list(zip(J["joints"], angs))):
        for i in jt["moving_parts_when_rotated"]:
            posed[i-1] = rot(posed[i-1], jt["origin"], a)
    bad = [(i+1, j+1, round(inter_vol(posed[i], posed[j]), 4))
           for i, j in itertools.combinations(range(6), 2) if inter_vol(posed[i], posed[j]) > EPS]
    mg = min(gap(posed[i], posed[j], 3.0) for i, j in itertools.combinations(range(6), 2))
    log(f"{name:16s}: interferences={bad if bad else 'none'}  min gap between any parts={mg:.3f} mm")

# ---------------- 6. axial / radial retention ----------------
log("\n== 6. Retention: rigid translation of the child subtree until contact ==")
for jt in J["joints"]:
    k = jt["id"]
    fixed = M[k-1]
    mov = mf.Manifold.batch_boolean([M[i-1] for i in jt["moving_parts_when_rotated"]], mf.OpType.Add)
    out = []
    for lab, d in [("+Z", (0, 0, 1)), ("-Z", (0, 0, -1)), ("-X(pull)", (-1, 0, 0)), ("+Y", (0, 1, 0))]:
        t = 0.0
        while t < 20 and inter_vol(fixed, mov.translate([d[0]*t, d[1]*t, d[2]*t])) <= EPS:
            t += 0.02
        v1 = inter_vol(fixed, mov.translate([d[0]*(t+1), d[1]*(t+1), d[2]*(t+1)]))
        out.append(f"{lab}: contact after {t:.2f} mm (overlap {v1:.1f} mm3 at +1 mm more)")
    log(f"joint {k}: " + "; ".join(out))

# ---------------- 7. overhang analysis ----------------
log("\n== 7. Overhang analysis (print direction +Z, bed z=0) ==")
for p, m in zip(J["parts"], meshes):
    n = m.face_normals; zc = m.triangles_center[:, 2]; A = m.area_faces
    down = (n[:, 2] < -1e-3) & (zc > 0.05)
    # overhang angle measured from vertical: 90 = flat ceiling
    ang = np.degrees(np.arcsin(np.clip(-n[:, 2], 0, 1)))
    steep = down & (ang > 45.0 + 0.5)
    log(f"part {p['id']}: downward faces above bed: area {A[down].sum():7.1f} mm2, max angle from vertical "
        f"{ang[down].max() if down.any() else 0:.1f} deg; faces steeper than 45deg: {A[steep].sum():.2f} mm2")

json.dump({"hard_stops": stops}, open("/tmp/stops.json", "w"))
open(f"{ROOT}/checks/geometry_report.txt", "w").write("\n".join(rep) + "\n")
