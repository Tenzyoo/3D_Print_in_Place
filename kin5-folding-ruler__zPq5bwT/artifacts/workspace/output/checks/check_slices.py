"""切片检查：
 A. 按 0.2 mm 层高对各零件 STL 截面 (层中心 z = 0.1, 0.3, ...)：
    - 同一层内不同零件截面之间的最小水平间隙；
    - 每个零件相对自身下一层的悬垂：本层截面 − 下一层截面外扩 0.21 mm (= 半线宽，约 45°) 的剩余面积。
 B. 解析 PrusaSlicer 生成的 G-code：把每条挤出线按线宽展开为面域，检查
    - 是否有挤出线落入另一个零件 (跨越间隙熔接)；
    - 同一层内属于不同零件的挤出面域之间的最小实际间隙；
    - 支撑 (TYPE:Support*) 是否存在；Bridge infill 是否都位于本零件下一层实体之上 (内部桥接)。
用法: python3 check_slices.py <output_dir> <gcode>"""
import sys, re, json, numpy as np, trimesh
from pathlib import Path
from shapely.geometry import LineString, Polygon
from shapely.ops import unary_union

OUT = Path(sys.argv[1]); GC = Path(sys.argv[2])
J = json.loads((OUT / "joints.json").read_text())
names = [f"parts_{p['index']}" for p in J["parts"]]
meshes = {n: trimesh.load(OUT / f"parts/{n}.stl") for n in names}
LH = 0.2; ZTOP = max(m.bounds[1][2] for m in meshes.values())
zs = np.round(np.arange(LH / 2, ZTOP, LH), 4)

def section(mesh, z):
    p = mesh.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
    if p is None: return Polygon()
    p2, _ = p.to_2D(to_2D=np.eye(4))        # 单位变换：保持原 XY 坐标
    return unary_union(list(p2.polygons_full)).buffer(0)

S = {n: [section(meshes[n], z) for z in zs] for n in names}
rep = {"layers": len(zs)}

# ---- A. 截面检查 ----
gapA = (1e9, None); over = {}
for i, z in enumerate(zs):
    for a in range(len(names)):
        for b in range(a + 1, len(names)):
            d = S[names[a]][i].distance(S[names[b]][i])
            if d < gapA[0]: gapA = (d, [float(z), names[a], names[b]])
for n in names:
    worst = (0.0, None)
    for i in range(1, len(zs)):
        un = S[n][i].difference(S[n][i - 1].buffer(0.21))
        area = sum(g.area for g in getattr(un, "geoms", [un]) if g.area > 0)
        if area > worst[0]: worst = (area, float(zs[i]))
    over[n] = {"max_unsupported_area_mm2": round(worst[0], 4), "at_z": worst[1]}
rep["A_section_min_gap_between_parts_mm"] = {"gap": round(gapA[0], 4), "where": gapA[1]}
rep["A_overhang_beyond_45deg_per_part"] = over

# ---- B. G-code 检查 ----
model = trimesh.util.concatenate(list(meshes.values()))
c = (model.bounds[0][:2] + model.bounds[1][:2]) / 2
off = np.array([128.0, 128.0]) - c              # 切片时使用 --center 128,128
layers = {}; z = 0.0; x = y = None; e_abs = None; width = 0.42; typ = None
for line in GC.read_text().splitlines():
    if line.startswith(";Z:"): z = float(line[3:])
    elif line.startswith(";WIDTH:"): width = float(line[7:])
    elif line.startswith(";TYPE:"): typ = line[6:]
    elif line.startswith("G1") or line.startswith("G0"):
        p = dict((k, float(v)) for k, v in re.findall(r"([XYZE])([-\d.]+)", line.split(";")[0]))
        nx, ny = p.get("X", x), p.get("Y", y)
        if "E" in p and p["E"] > 0 and x is not None and (nx, ny) != (x, y):
            layers.setdefault(round(z, 3), []).append((x, y, nx, ny, width, typ))
        x, y = nx, ny
types = sorted({s[5] for L in layers.values() for s in L})
support = sum(1 for L in layers.values() for s in L if s[5] and s[5].startswith("Support"))
foreign = []; gapB = (1e9, None); bridge_bad = 0; bridge_total = 0; bridge_info = []
for zl, segs in sorted(layers.items()):
    i = int(round((zl - LH / 2) / LH - 0.5));  i = min(max(i, 0), len(zs) - 1)  # 层中心 = zl - 0.1
    secs = [S[n][i] for n in names]
    per = {n: [] for n in names}
    for (x0, y0, x1, y1, w, t) in segs:
        fp = LineString([(x0 - off[0], y0 - off[1]), (x1 - off[0], y1 - off[1])]).buffer(w / 2, cap_style=2)
        ov = [fp.intersection(s).area for s in secs]
        k = int(np.argmax(ov)); per[names[k]].append(fp)
        others = [o for j, o in enumerate(ov) if j != k]
        if others and max(others) > 1e-3:
            foreign.append({"z": zl, "type": t, "area": round(max(others), 4)})
        if t == "Bridge infill":
            bridge_total += 1
            below = S[names[k]][i - 1] if i > 0 else None
            un = fp.difference(below.buffer(0.05)) if below is not None else fp
            if un.area > 0.05 * fp.area:
                bridge_bad += 1
                d_other = min(S[n][i - 1].distance(un) for n in names if n != names[k])
                bridge_info.append({"z": zl, "part": names[k], "unsupported_area_mm2": round(un.area, 4),
                                    "dist_to_other_part_below_mm": round(d_other, 3)})
    U = {n: unary_union(v) for n, v in per.items() if v}
    ks = list(U)
    for a in range(len(ks)):
        for b in range(a + 1, len(ks)):
            d = U[ks[a]].distance(U[ks[b]])
            if d < gapB[0]: gapB = (d, [zl, ks[a], ks[b]])
rep["B_gcode"] = {"file": GC.name, "layers": len(layers), "extrusion_types": types,
                  "support_segments": support, "extrusions_into_other_part": len(foreign),
                  "foreign_examples": foreign[:5],
                  "min_printed_gap_between_parts_mm": {"gap": round(gapB[0], 4), "where": gapB[1]},
                  "bridge_infill_segments": bridge_total, "bridge_infill_not_over_own_part": bridge_bad,
                  "bridge_not_over_own_part_details": bridge_info}
print(json.dumps(rep, indent=1, ensure_ascii=False))
(OUT / f"checks/slice_report_{GC.stem}.json").write_text(json.dumps(rep, indent=1, ensure_ascii=False))
