"""Geometry / motion verification for the butterfly.
usage: verify.py OUTDIR RESULT.json [section,section,...]
sections: mesh sweep clear3d stops retention pin overhang"""
import sys, os, json, itertools, numpy as np, trimesh, manifold3d as m3d
from shapely.geometry import Polygon, Point, LineString
from shapely.ops import unary_union
from scipy.spatial import cKDTree
OUT, RES = sys.argv[1], sys.argv[2]
ONLY = sys.argv[3].split(",") if len(sys.argv) > 3 else None
want = lambda k: ONLY is None or k in ONLY
R = json.load(open(RES)) if os.path.exists(RES) else {}
J = json.load(open(f"{OUT}/joints.json"))
parts = {p["name"]: trimesh.load(f"{OUT}/{p['file']}") for p in J["parts"]}
joint = {j["child"]: j for j in J["joints"]}
WINGS = ["left_wing", "right_wing"]; NAMES = ["body"] + WINGS

def mf(m): return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(m.vertices, np.float32), tri_verts=np.asarray(m.faces, np.uint32)))
def T(child, ang, shift=(0, 0, 0)):
    j = joint[child]; M = trimesh.transformations.rotation_matrix(np.radians(ang), j["axis"], j["origin"])
    M[:3, 3] += shift; return M
def posed(child, ang, shift=(0, 0, 0)): return parts[child].copy().apply_transform(T(child, ang, shift))
def inter(a, b): return (mf(a) ^ mf(b)).volume()
def sec_poly(m, z):
    s = m.section([0, 0, 1], [0, 0, z])
    if s is None: return Polygon()
    p2, _ = s.to_2D(to_2D=np.eye(4)); return unary_union(list(p2.polygons_full)).buffer(0)

if want("mesh"):   # ---------- meshes / envelope ----------
    model = trimesh.load(f"{OUT}/model.stl"); ext = model.bounds[1] - model.bounds[0]
    R["parts"] = {n: dict(watertight=bool(m.is_watertight), winding_consistent=bool(m.is_winding_consistent),
                          shells=len(m.split(only_watertight=False)), volume_mm3=round(m.volume, 2),
                          bounds=m.bounds.round(3).tolist()) for n, m in parts.items()}
    R["model"] = dict(watertight=bool(model.is_watertight), shells=len(model.split(only_watertight=False)),
                      volume_mm3=round(model.volume, 2), sum_part_volumes=round(sum(m.volume for m in parts.values()), 2),
                      bounds=model.bounds.round(3).tolist(), size_xyz=ext.round(3).tolist(),
                      within_120x100x30=bool(ext[0] <= 120 and ext[1] <= 100 and ext[2] <= 30))

if want("sweep"):  # ---------- motion sweep: exact boolean + per-layer 2D gaps ----------
    zs = np.round(np.arange(0.1, 11.0, 0.2), 2); sweep = []; worst = {}
    grid = [-30, -20, -10, 0, 10, 20, 30]
    cases = sorted(set([(a, 0) for a in range(-30, 31, 5)] + [(0, a) for a in range(-30, 31, 5)] + list(itertools.product(grid, grid))))
    for aL, aR in cases:
        ms = {"body": parts["body"], "left_wing": posed("left_wing", aL), "right_wing": posed("right_wing", aR)}
        iv = {f"{a}|{b}": inter(ms[a], ms[b]) for a, b in itertools.combinations(NAMES, 2)}
        g = {k: 1e9 for k in iv}
        for z in zs:
            P = {n: sec_poly(ms[n], z) for n in NAMES}
            for a, b in itertools.combinations(NAMES, 2):
                if not P[a].is_empty and not P[b].is_empty: g[f"{a}|{b}"] = min(g[f"{a}|{b}"], P[a].distance(P[b]))
        sweep.append(dict(left=aL, right=aR, max_intersection_mm3=max(iv.values()), min_layer_gap={k: round(v, 3) for k, v in g.items()}))
        for k in g: worst[k] = min(worst.get(k, 1e9), g[k])
    R["motion_sweep"] = dict(cases=len(sweep), layer_z=[float(zs[0]), float(zs[-1]), 0.2],
                             max_intersection_mm3=max(s["max_intersection_mm3"] for s in sweep),
                             min_xy_gap_over_all_cases={k: round(v, 3) for k, v in worst.items()}, detail=sweep)

if want("clear3d"):  # ---------- 3D clearance (incl. vertical gaps at the cones), dense samples ----------
    def samp(m, n=250000): return np.vstack([trimesh.sample.sample_surface(m, n, seed=1)[0], m.vertices])
    def rloc(p, child): o = np.array(joint[child]["origin"]); return np.hypot(p[:, 0] - o[0], p[:, 1] - o[1])
    Bp = samp(parts["body"]); tree = cKDTree(Bp); d3 = {}
    for c in WINGS:
        Wl = samp(parts[c]); mn = mn_far = 1e9
        for a in range(-30, 31, 5):
            Wp = trimesh.transform_points(Wl, T(c, a)); d, i = tree.query(Wp); mn = min(mn, d.min())
            far = (rloc(Wp, c) > 6.0) | (rloc(Bp[i], c) > 6.0); mn_far = min(mn_far, d[far].min())
        d3[c] = dict(min_3d_gap_any=round(mn, 3), min_3d_gap_outside_pin_bore=round(mn_far, 3))
    R["clearance_3d_sampled"] = d3

if want("stops"):  # ---------- first contact beyond the range (0.5 deg steps) ----------
    def first_contact(c, sgn):
        a = 30.0
        while a < 90:
            if inter(parts["body"], posed(c, sgn * a)) > 1e-3: return a
            a += 0.5
    R["hard_stop_deg"] = {c: dict(neg=-first_contact(c, -1), pos=first_contact(c, +1)) for c in WINGS}

if want("retention"):  # ---------- translate the wing along a path, report travel until it hits the body ----------
    B = mf(parts["body"])
    def free_travel(c, d, lim=8.0, step=0.05):
        for t in np.arange(step, lim + 1e-9, step):
            if (B ^ mf(posed(c, 0, np.array(d, float) * t))).volume() > 1e-4: return round(float(t), 3)
        return None   # no contact along the whole path -> part would come off
    R["retention_free_travel_mm"] = {c: {k: free_travel(c, d) for k, d in
        {"+Z (pull off upward)": (0, 0, 1), "-Z (push down)": (0, 0, -1),
         "outboard": (0, 1 if c == "left_wing" else -1, 0), "+X": (1, 0, 0), "-X": (-1, 0, 0)}.items()} for c in WINGS}

if want("pin"):  # ---------- pin / bore radial clearance on rays away from the web ----------
    pc = {}
    for c in WINGS:
        o = np.array(joint[c]["origin"][:2]); sy = 1 if c == "left_wing" else -1; rows = []
        for z in [0.1, 0.7, 1.3, 2.0, 2.6, 3.4, 4.1, 4.7, 5.3, 6.0, 6.5, 6.9]:
            pb, pw = sec_poly(parts["body"], z), sec_poly(parts[c], z); rp, rb = [], []
            for t in np.radians(np.arange(-80, 81, 10)):
                ray = LineString([o, o + 9 * np.array([np.sin(t), sy * np.cos(t)])])
                ip, iw = ray.intersection(pb), ray.intersection(pw)
                rp.append(max(Point(o).distance(Point(q)) for g in getattr(ip, "geoms", [ip]) for q in g.coords))
                rb.append(Point(o).distance(iw))
            rows.append(dict(z=z, pin_r=round(float(np.mean(rp)), 3), bore_r=round(float(np.mean(rb)), 3),
                             radial_gap=round(float(np.min(np.array(rb) - np.array(rp))), 3)))
        pc[c] = rows
    R["pin_bore_sections"] = pc

if want("overhang"):  # ---------- downward faces above the bed ----------
    oh = {}
    for n, m in parts.items():
        nz = m.face_normals[:, 2]; zc = m.triangles_center[:, 2]; A = m.area_faces
        down = (zc > 0.05) & (nz < -0.05)
        ang = np.degrees(np.arcsin(np.clip(-nz, 0, 1)))       # 0 = vertical wall, 90 = flat ceiling
        steep = down & (ang > 45.5)
        oh[n] = dict(down_facing_area_mm2=round(A[down].sum(), 2), steep_gt45_area_mm2=round(A[steep].sum(), 3),
                     max_overhang_deg_from_vertical=round(float(ang[down].max()), 2) if down.any() else 0,
                     steep_face_centers=m.triangles_center[steep].round(2).tolist()[:20])
    R["overhangs"] = oh

json.dump(R, open(RES, "w"), indent=1)
print(json.dumps({k: v for k, v in R.items() if k not in ("motion_sweep",)}, indent=1)[:6000])
if "motion_sweep" in R: print(json.dumps({k: v for k, v in R["motion_sweep"].items() if k != "detail"}))
