#!/usr/bin/env python3
"""Geometry + motion + slicing verification for the 4-stage telescoping rod.
Run from /app/output:  python3 verify.py   (writes verify_report.json)"""
import json, re, subprocess, sys, os
import numpy as np
import trimesh
import manifold3d as m3d

OUT = os.path.dirname(os.path.abspath(__file__))
J = json.load(open(os.path.join(OUT, "joints.json")))
G = 0.5
rep = {"checks": [], "ok": True}


def check(name, cond, **info):
    rep["checks"].append({"name": name, "pass": bool(cond), **info})
    if not cond:
        rep["ok"] = False
    print(("PASS " if cond else "FAIL ") + name, info if info else "")


def to_manifold(tm):
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(tm.vertices, np.float32),
                                 tri_verts=np.asarray(tm.faces, np.uint32)))


parts = [trimesh.load(os.path.join(OUT, "parts", f"parts_{i}.stl")) for i in range(1, 5)]
model = trimesh.load(os.path.join(OUT, "model.stl"))
mans = [to_manifold(p) for p in parts]

# ---------- 1. per-part integrity ----------
for i, p in enumerate(parts, 1):
    nb = len(p.split(only_watertight=False))
    check(f"part{i} watertight single body", p.is_watertight and p.is_winding_consistent and nb == 1 and p.volume > 0,
          volume_mm3=round(p.volume, 1), bodies=nb, bbox=np.round(p.bounds, 3).tolist())

# ---------- 2. model == union of parts ----------
vsum = sum(p.volume for p in parts)
check("model.stl = parts combined (volume, bbox, 4 bodies)",
      abs(model.volume - vsum) < 1e-3 * vsum and np.allclose(model.bounds, trimesh.util.concatenate(parts).bounds, atol=1e-4)
      and len(model.split(only_watertight=False)) == 4,
      model_volume=round(model.volume, 2), parts_volume=round(vsum, 2))

ext = model.bounds[1] - model.bounds[0]
od = max(ext[0], ext[1])
check("collapsed length <= 120 mm", ext[2] <= 120.0, length=round(ext[2], 3))
check("max outer diameter <= 25 mm", od <= 25.0, od=round(od, 3))

# coaxial: all parts' bbox centers on the same Z axis
cent = [((p.bounds[0] + p.bounds[1]) / 2)[:2] for p in parts]
check("all tubes coaxial (axis x=y=0)", max(np.linalg.norm(c) for c in cent) < 1e-3,
      centers=[np.round(c, 5).tolist() for c in cent])


def radial_extent(mesh, z):
    s = mesh.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
    r = np.linalg.norm(s.vertices[:, :2], axis=1)
    return r.min(), r.max()


# ---------- 3. no interference in print state, all pairs ----------
for a in range(4):
    for b in range(a + 1, 4):
        v = m3d.Manifold.batch_boolean([mans[a], mans[b]], m3d.OpType.Intersect).volume()
        check(f"print state: no overlap part{a+1}/part{b+1}", v < 1e-6, overlap_mm3=v)

# ---------- 4. clearances between adjacent tubes ----------
rng = np.random.default_rng(0)
for i in range(3):
    outer, inner = parts[i], parts[i + 1]
    # radial gap on the sliding surfaces at representative heights
    slices = {}
    for z, label in [(1.8, "bottom lip vs inner wall"), (12.0, "counterbore vs collar"),
                     (outer.bounds[1][2] - 5, "top lip vs inner wall")]:
        so = outer.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
        ro = np.linalg.norm(so.vertices[:, :2], axis=1).min()       # bore radius of outer
        si = inner.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
        ri = np.linalg.norm(si.vertices[:, :2], axis=1).max()        # outer radius of inner
        slices[label] = round(ro - ri, 4)
    mind = float(mans[i].min_gap(mans[i + 1], 3.0))   # exact mesh-to-mesh gap (manifold3d)
    check(f"stage {i+1}: min 3D clearance part{i+1}<->part{i+2} > 0.4 mm (non-fusing)", mind >= 0.4 - 1e-3,
          min_clearance_mm=round(mind, 4))
    check(f"stage {i+1}: sliding radial clearance in 0.4..0.6 mm", all(0.4 - 1e-3 <= v <= 0.6 + 1e-3 for v in slices.values()),
          radial_gaps_mm=slices)

# ---------- 5. motion simulation per stage ----------
for jt in J["joints"]:
    i = jt["parent_part"] - 1
    lo, hi = jt["travel_mm"]["min"], jt["travel_mm"]["max"]
    A = mans[i]
    zs = np.unique(np.concatenate([np.linspace(lo + 0.02, hi - 0.02, 60), [lo + 0.02, 0.0, hi - 0.02]]))
    worst = 0.0
    for s in zs:
        B = mans[i + 1].translate([0, 0, float(s)])
        worst = max(worst, m3d.Manifold.batch_boolean([A, B], m3d.OpType.Intersect).volume())
    over_hi = m3d.Manifold.batch_boolean([A, mans[i + 1].translate([0, 0, hi + 0.3])], m3d.OpType.Intersect).volume()
    over_lo = m3d.Manifold.batch_boolean([A, mans[i + 1].translate([0, 0, lo - 0.3])], m3d.OpType.Intersect).volume()
    # far beyond stop: still blocked (cannot be pulled out)
    far = m3d.Manifold.batch_boolean([A, mans[i + 1].translate([0, 0, hi + 5])], m3d.OpType.Intersect).volume()
    check(f"joint {jt['name']}: free slide over [{lo}, {hi}] mm", worst < 1e-6, samples=len(zs), max_overlap_mm3=worst)
    check(f"joint {jt['name']}: extension stop at +{hi} mm blocks separation", over_hi > 1e-3 and far > 1e-3,
          overlap_at_stop_plus_0p3=round(over_hi, 4), overlap_at_stop_plus_5=round(far, 3))
    check(f"joint {jt['name']}: collapse stop at {lo} mm", over_lo > 1e-4, overlap_at_stop_minus_0p3=round(over_lo, 4))
    # remaining guide overlap at full extension
    top_parent = parts[i].bounds[1][2]
    bot_child = parts[i + 1].bounds[0][2] + hi
    rep.setdefault("overlap_at_full_extension_mm", {})[jt["name"]] = round(top_parent - bot_child, 3)

# full extension of the whole rod
off, ext_parts = 0.0, []
for k in range(4):
    if k > 0:
        off += J["joints"][k - 1]["travel_mm"]["max"] - 0.02
    ext_parts.append(mans[k].translate([0, 0, off]))
clash = max(m3d.Manifold.batch_boolean([ext_parts[a], ext_parts[a + 1]], m3d.OpType.Intersect).volume() for a in range(3))
bb = [p.bounding_box() for p in ext_parts]
zmax = max(b[5] for b in bb)
zmin = min(b[2] for b in bb)
check("fully extended length >= 300 mm, no collisions", (zmax - zmin) >= 300 and clash < 1e-6,
      extended_length_mm=round(zmax - zmin, 3), max_overlap_mm3=clash)
trimesh.util.concatenate([trimesh.Trimesh(vertices=e.to_mesh().vert_properties[:, :3], faces=e.to_mesh().tri_verts)
                          for e in ext_parts]).export(os.path.join(OUT, "checks", "extended_state.stl"))

# ---------- 6. overhang analysis (support-free) ----------
for i, p in enumerate(parts, 1):
    n = p.face_normals
    zc = p.triangles_center[:, 2]
    down = n[:, 2] < -np.cos(np.radians(45)) - 1e-3       # steeper than 45deg overhang
    bad = down & (zc > 1e-3)                              # exclude bed contact faces
    check(f"part{i}: no overhang beyond 45deg (except bed face)", bad.sum() == 0,
          bad_faces=int(bad.sum()), min_downward_face_angle_from_horizontal_deg=
          round(float(np.degrees(np.arccos(np.clip(-n[(n[:, 2] < -1e-6) & (zc > 1e-3), 2], -1, 1))).min()), 2)
          if ((n[:, 2] < -1e-6) & (zc > 1e-3)).any() else None)

# ---------- 7. slicing ----------
def slice_(ini, out):
    r = subprocess.run(["prusa-slicer", "--export-gcode", "--load", ini, "--output", out,
                        os.path.join(OUT, "model.stl")], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


rc, log = slice_("/opt/slicer/p1s_pla_0.20mm_nosupport.ini", "/tmp/rod_nosupport.gcode")
check("PrusaSlicer slice (no-support profile) succeeds", rc == 0, log_tail=log.strip().splitlines()[-3:])
rc2, log2 = slice_("/opt/slicer/p1s_pla_0.20mm_autosupport.ini", "/tmp/rod_autosupport.gcode")
gs = open("/tmp/rod_autosupport.gcode").read() if rc2 == 0 else ""
nsup = len(re.findall(r";TYPE:Support material", gs))
check("auto-support profile generates no support material (design is self-supporting)", rc2 == 0 and nsup == 0,
      support_blocks=nsup)

# parse gcode: extrusion segments per layer
g = open("/tmp/rod_nosupport.gcode").read().splitlines()
layers = {}
x = y = z = e = 0.0
w = 0.42
typ = ""
for ln in g:
    if ln.startswith(";Z:"):
        z = round(float(ln[3:]), 3)
    elif ln.startswith(";WIDTH:"):
        w = float(ln[7:])
    elif ln.startswith(";TYPE:"):
        typ = ln[6:]
    elif ln.startswith("G92"):
        m = re.search(r"E([-\d.]+)", ln)
        if m: e = float(m.group(1))
    elif ln.startswith("G1") or ln.startswith("G0"):
        c = ln.split(";")[0]
        nx, ny, ne = x, y, e
        for k, v in re.findall(r"([XYZE])([-\d.]+)", c):
            v = float(v)
            if k == "X": nx = v
            elif k == "Y": ny = v
            elif k == "E": ne = v
        if ne > e + 1e-6 and (nx != x or ny != y):
            layers.setdefault(z, []).append((x, y, nx, ny, w))
        x, y, e = nx, ny, ne
zl = sorted(layers)
allp = np.array([[s[0], s[1]] for zz in zl for s in layers[zz]])
cx, cy = (allp.min(0) + allp.max(0)) / 2
check("G-code layer count / height", abs(zl[-1] - model.bounds[1][2]) < 0.25, layers=len(zl), top_z=zl[-1])


def layer_radii(segs):
    out = []
    for x0, y0, x1, y1, ww in segs:
        L = np.hypot(x1 - x0, y1 - y0)
        n = max(2, int(L / 0.1) + 1)
        t = np.linspace(0, 1, n)
        px, py = x0 + (x1 - x0) * t - cx, y0 + (y1 - y0) * t - cy
        r = np.hypot(px, py)
        out.append(np.stack([r - ww / 2, r + ww / 2], 1))
    return np.vstack(out)


# for every layer and every stage: gap between material edges of the two tubes
sl = {}
worst_same, worst_cross = {}, {}
prev = None
for zz in zl:
    R = layer_radii(layers[zz])
    zc = zz - 0.1
    for i in range(3):
        if zc > parts[i].bounds[1][2] or zc < 0:
            continue
        ro_in, _ = radial_extent(parts[i], zc)          # bore of outer tube
        _, ri_out = radial_extent(parts[i + 1], zc)     # outer surface of inner tube
        rm = (ro_in + ri_out) / 2
        inner_edge = R[(R[:, 1] < rm + 0.0) & (R[:, 0] > rm - 6) & ((R[:, 0] + R[:, 1]) / 2 < rm), 1]
        outer_edge = R[((R[:, 0] + R[:, 1]) / 2 > rm) & (R[:, 0] < rm + 6), 0]
        if len(inner_edge) and len(outer_edge):
            gap = outer_edge.min() - inner_edge.max()
            if i not in worst_same or gap < worst_same[i][0]:
                worst_same[i] = (gap, zz)
        if prev is not None and len(inner_edge):
            # inner tube on this layer vs outer tube on layer below (stacking/fusing check)
            Rp = prev
            oe = Rp[((Rp[:, 0] + Rp[:, 1]) / 2 > rm) & (Rp[:, 0] < rm + 6), 0]
            ie = Rp[((Rp[:, 0] + Rp[:, 1]) / 2 < rm) & (Rp[:, 0] > rm - 6), 1]
            if len(oe):
                gc = oe.min() - inner_edge.max()        # child above parent
                gc2 = (outer_edge.min() - ie.max()) if len(ie) and len(outer_edge) else 9
                gmin = min(gc, gc2)
                if i not in worst_cross or gmin < worst_cross[i][0]:
                    worst_cross[i] = (gmin, zz)
    prev = R
for i in range(3):
    check(f"G-code stage {i+1}: open gap between extrusions on every layer", worst_same[i][0] > 0.3,
          min_gap_same_layer_mm=round(worst_same[i][0], 3), at_z=worst_same[i][1],
          min_gap_vs_layer_below_mm=round(worst_cross[i][0], 3), at_z_cross=worst_cross[i][1])
    check(f"G-code stage {i+1}: no stacking of one tube on the other's layer below", worst_cross[i][0] > 0.2,
          min_gap_vs_layer_below_mm=round(worst_cross[i][0], 3))
m = re.search(r"; estimated printing time \(normal mode\) = (.+)", open("/tmp/rod_nosupport.gcode").read())
fil = re.search(r"; filament used \[g\] = (.+)", open("/tmp/rod_nosupport.gcode").read())
rep["slicer"] = {"time": m.group(1) if m else None, "filament_g": fil.group(1) if fil else None}
print(rep["slicer"], rep.get("overlap_at_full_extension_mm"))
json.dump(rep, open(os.path.join(OUT, "checks", "verify_report.json"), "w"), indent=2, default=float)
print("ALL PASS" if rep["ok"] else "SOME CHECKS FAILED")
sys.exit(0 if rep["ok"] else 1)
