"""Geometry / kinematics check of the telescoping rod STLs."""
import json, sys, numpy as np, trimesh, manifold3d as m3d
from shapely.geometry import Polygon, MultiPolygon, LineString
from shapely.ops import unary_union

OUT = "/app/output"
parts = [trimesh.load(f"{OUT}/parts/parts_{k}.stl") for k in range(1, 5)]
model = trimesh.load(f"{OUT}/model.stl")
res = {}

def to_man(m):
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(m.vertices, np.float32),
                                 tri_verts=np.asarray(m.faces, np.uint32)))
def inter_vol(a, b):
    return (a ^ b).volume()   # ^ = intersection in manifold3d

# 1. mesh validity
print("== 1. mesh validity")
for k, p in enumerate(parts, 1):
    b = p.bounds
    print(f"tube {k}: watertight={p.is_watertight} bodies={len(p.split(only_watertight=False))} "
          f"vol={p.volume:.1f} mm3  OD={b[1,0]-b[0,0]:.2f}  z=[{b[0,2]:.2f},{b[1,2]:.2f}]")
mb = model.bounds
print(f"model: watertight={model.is_watertight} bodies={len(model.split(only_watertight=False))} "
      f"vol={model.volume:.1f} (sum parts {sum(p.volume for p in parts):.1f}) "
      f"size={np.round(mb[1]-mb[0],2)}")
res["collapsed_length"] = float(mb[1,2]-mb[0,2]); res["max_od"] = float(mb[1,0]-mb[0,0])

# 2. static interference
print("== 2. static interference (assembled/printed state)")
M = [to_man(p) for p in parts]
for i in range(4):
    for j in range(i+1, 4):
        v = inter_vol(M[i], M[j])
        print(f"tube {i+1} & tube {j+1}: intersection volume = {v:.6f}")
        assert v < 1e-6

# 3. clearances from an axial section (XZ half plane, x>0)
print("== 3. clearances in axial section")
def section_polys(mesh):
    s = mesh.section(plane_origin=[0,0,0], plane_normal=[0,1,0])
    polys = [Polygon(d[:, [0, 2]]) for d in s.discrete]          # (r=x, z)
    polys = [q.buffer(0) for q in polys if q.centroid.x > 0]
    # nested loops -> even/odd fill
    out = polys[0]
    for q in polys[1:]: out = out.symmetric_difference(q)
    return out
secs = [section_polys(p) for p in parts]
for k, s in enumerate(secs, 1):
    print(f"tube {k} section bounds (r,z) = {np.round(s.bounds,3)}")
min_gap = {}
for i in range(3):
    d = secs[i].distance(secs[i+1]); min_gap[f"{i+1}-{i+2}"] = d
    print(f"min gap tube {i+1} <-> tube {i+2}: {d:.3f} mm")
# radial sliding gaps measured with horizontal probe lines
def radial_gap(sa, sb, z):
    ln = LineString([(0, z), (20, z)])
    ia, ib = sa.intersection(ln), sb.intersection(ln)
    xa = [c[0] for g in getattr(ia, 'geoms', [ia]) for c in g.coords]
    xb = [c[0] for g in getattr(ib, 'geoms', [ib]) for c in g.coords]
    # inner part (b) max r and outer part (a) min r
    return min(xa) - max(xb)
slide = {}
for i in range(3):
    zc = 10.0                                   # collar zone (collar vs bore)
    zl = parts[i].bounds[1,2] - 1.0             # lip zone (lip vs inner tube body)
    g1, g2 = radial_gap(secs[i], secs[i+1], zc), radial_gap(secs[i], secs[i+1], zl)
    slide[f"{i+1}-{i+2}"] = (g1, g2)
    print(f"tube {i+1}/{i+2}: collar-bore gap @z={zc}: {g1:.3f}  lip-body gap @z={zl}: {g2:.3f}")
    assert 0.4 - 0.01 <= g1 <= 0.6 + 0.01 and 0.4 - 0.01 <= g2 <= 0.6 + 0.01
res["min_gap"] = min_gap; res["sliding_gap"] = slide

# 4. kinematics: sweep child along z, find free range
print("== 4. motion sweep")
def blocked(i, dz, dx=0.0):
    return inter_vol(M[i], M[i+1].translate([dx, 0, dz])) > 1e-4
def find_limit(i, a, b):          # a free, b blocked -> bisection
    for _ in range(30):
        m = (a+b)/2
        a, b = (m, b) if not blocked(i, m) else (a, m)
    return a
limits = {}
for i in range(3):
    zs = np.arange(0.0, 140.0, 0.5)
    first_block = next(z for z in zs if blocked(i, z))
    up = find_limit(i, first_block - 0.5, first_block)          # free up to here
    a_, b_ = 0.0, -5.0
    for _ in range(30):
        m = (a_+b_)/2
        a_, b_ = (m, b_) if not blocked(i, m) else (a_, m)
    lo = a_
    # stop robustness beyond each limit, also with worst-case lateral shift of the child
    shift = 0.49
    hold_up = all(blocked(i, up + d, dx) for d in (0.3, 2, 5, 10, 15) for dx in (0, shift, -shift))
    hold_lo = all(blocked(i, lo - d, dx) for d in (0.3, 2, 5, 20) for dx in (0, shift, -shift))
    limits[i] = (lo, up)
    print(f"tube {i+2} in tube {i+1}: free stroke z = [{lo:.3f}, {up:.3f}] mm "
          f"(stroke {up-lo:.2f}, swept every 0.5 mm collision-free); "
          f"pull-out stop holds: {hold_up}; push-through stop holds: {hold_lo}")
    assert hold_up and hold_lo
res["limits"] = {f"{i+1}-{i+2}": limits[i] for i in range(3)}

# 5. fully extended assembly: no collision between any pair, total length
print("== 5. fully extended state")
off = [0.0]
for i in range(3): off.append(off[-1] + limits[i][1] - 0.05)
Mx = [M[k].translate([0, 0, off[k]]) for k in range(4)]
for i in range(4):
    for j in range(i+1, 4):
        assert inter_vol(Mx[i], Mx[j]) < 1e-6
zmax = max(parts[k].bounds[1,2] + off[k] for k in range(4))
print(f"offsets {np.round(off,2)}; extended length = {zmax:.2f} mm, all pairs collision-free")
overlap = [parts[i].bounds[1,2] - off[i+1] + off[i] for i in range(3)]
print("overlap at full extension:", np.round(overlap, 2))
res["extended_length"] = float(zmax); res["overlap_at_full_ext"] = overlap

# 6. overhang analysis
print("== 6. overhangs (down-facing surfaces, excluding bed contact z=0)")
for k, p in enumerate(parts, 1):
    n = p.face_normals; c = p.triangles_center
    down = (n[:, 2] < -1e-3) & (c[:, 2] > 0.05)
    ang = np.degrees(np.arccos(np.clip(-n[down, 2], -1, 1)))   # 0 = flat ceiling
    tilt = 90 - ang.max() if down.any() else 90.0   # surface angle from horizontal
    print(f"tube {k}: {down.sum()} down-facing faces above bed, flattest one is "
          f"{tilt:.1f} deg from horizontal (>=45 deg = self-supporting)")
    assert tilt >= 44.5
    flat = (n[:, 2] < -0.99) & (c[:, 2] > 0.05)
    print(f"        flat (unsupported) ceilings: {flat.sum()}")
    assert flat.sum() == 0
json.dump(res, open(f"{OUT}/checks/geom_result.json", "w"), indent=1, default=float)
print("ALL GEOMETRY CHECKS PASSED")
