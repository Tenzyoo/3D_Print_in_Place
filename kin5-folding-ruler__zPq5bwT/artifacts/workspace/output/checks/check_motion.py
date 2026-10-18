"""几何与运动干涉检查：读取 parts/*.stl 与 joints.json，按运动链对 (θ1, θ2) 网格扫描，
计算两两零件的最小间隙 (manifold3d.min_gap) 与相交体积。"""
import json, sys, itertools, numpy as np, trimesh, manifold3d as m3d
from pathlib import Path

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "/app/output")
J = json.loads((OUT / "joints.json").read_text())
names = [f"parts_{p['index']}" for p in J["parts"]]
meshes = {n: trimesh.load(OUT / f"parts/{n}.stl") for n in names}
report = {}

def to_manifold(tm):
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(tm.vertices, np.float32),
                                 tri_verts=np.asarray(tm.faces, np.uint32)))

# ---------- 1. 网格质量 ----------
model = trimesh.load(OUT / "model.stl")
report["mesh"] = {}
for n, tm in meshes.items():
    report["mesh"][n] = dict(watertight=bool(tm.is_watertight), winding_consistent=bool(tm.is_winding_consistent),
                             bodies=len(tm.split(only_watertight=False)), volume_mm3=round(float(tm.volume), 2),
                             bbox=np.round(tm.bounds, 3).tolist())
report["mesh"]["model.stl"] = dict(watertight=bool(model.is_watertight), bodies=len(model.split(only_watertight=False)),
                                   volume_mm3=round(float(model.volume), 2),
                                   sum_parts_volume_mm3=round(sum(t.volume for t in meshes.values()), 2),
                                   bbox=np.round(model.bounds, 3).tolist())
M = {n: to_manifold(t) for n, t in meshes.items()}
for n in names:
    assert M[n].status() == m3d.Error.NoError if hasattr(m3d, "Error") else True

# ---------- 2. 运动链 ----------
def rot(origin, axis, deg):
    return trimesh.transformations.rotation_matrix(np.radians(deg), axis, origin)

joints = J["joints"]
def poses(angles):
    """angles: {joint_name: deg} -> {part: 4x4}"""
    P = {names[0]: np.eye(4)}
    for j in joints:  # 链式：子段位姿 = 父段位姿 · 关节旋转(装配坐标系下)
        R = rot(j["axis_origin"], j["axis_direction"], angles.get(j["name"], 0.0))
        P[j["child"]] = P[j["parent"]] @ R
    return P

def place(n, T):
    return M[n].transform(T[:3, :4])

SEARCH = 1.0
def check(angles):
    P = poses(angles); placed = {n: place(n, P[n]) for n in names}
    res = {}
    for a, b in itertools.combinations(names, 2):
        inter = (placed[a] ^ placed[b]).volume()
        gap = placed[a].min_gap(placed[b], SEARCH)
        res[f"{a}-{b}"] = (gap, inter)
    return res

step = float(sys.argv[2]) if len(sys.argv) > 2 else 5.0
grid = np.arange(0, 180 + 1e-9, step)
worst = {}
cases = {"J1_only": [(t, 0) for t in grid], "J2_only": [(0, t) for t in grid],
         "both_grid": [(a, b) for a in grid for b in grid]}
for cname, lst in cases.items():
    w = {}
    for t1, t2 in lst:
        for pair, (gap, inter) in check({"J1": t1, "J2": t2}).items():
            if pair not in w or gap < w[pair]["min_gap_mm"]:
                w[pair] = dict(min_gap_mm=round(gap, 4), at_deg=[float(t1), float(t2)], intersection_mm3=inter)
            w[pair]["max_intersection_mm3"] = max(w[pair].get("max_intersection_mm3", 0.0), inter)
    worst[cname] = w
report["motion_scan_step_deg"] = step
report["motion_scan"] = worst
# 关节限位处的间隙
report["limit_poses"] = {f"{a},{b}": {k: round(v[0], 4) for k, v in check({"J1": a, "J2": b}).items()}
                         for a, b in [(0, 0), (180, 0), (0, 180), (180, 180), (90, 90)]}
# 超出范围的检查（验证 0° 与 180° 外有实体止挡）
over = {}
for jn, ang in [("J1", -4), ("J1", 184), ("J2", -4), ("J2", 184)]:
    r = check({jn: ang}); over[f"{jn}={ang}"] = {k: round(v[1], 3) for k, v in r.items()}
report["beyond_range_intersection_mm3"] = over
print(json.dumps(report, indent=1, ensure_ascii=False))
(OUT / "checks/motion_report.json").write_text(json.dumps(report, indent=1, ensure_ascii=False))
