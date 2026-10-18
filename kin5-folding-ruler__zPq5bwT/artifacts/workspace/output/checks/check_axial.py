"""轴向防脱检查：在多个关节角下，把子段沿关节轴 ±Z 平移，求与父段首次发生实体干涉的位移
（若子段可沿轴线自由脱出，则平移 > 5 mm 仍无干涉）。"""
import json, sys, numpy as np, trimesh, manifold3d as m3d
from pathlib import Path
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "/app/output")
J = json.loads((OUT / "joints.json").read_text())
def mf(n):
    t = trimesh.load(OUT / f"parts/{n}.stl")
    return m3d.Manifold(m3d.Mesh(vert_properties=np.asarray(t.vertices, np.float32), tri_verts=np.asarray(t.faces, np.uint32)))
res = {}
for j in J["joints"]:
    P, C = mf(j["parent"]), mf(j["child"])
    for ang in [0, 90, 180]:
        R = trimesh.transformations.rotation_matrix(np.radians(ang), j["axis_direction"], j["axis_origin"])
        Cr = C.transform(R[:3, :4])
        for sgn in (+1, -1):
            hit = None
            for dz in np.arange(0.05, 6.01, 0.05):
                if (P ^ Cr.translate((0, 0, sgn * dz))).volume() > 1e-3: hit = round(float(dz), 2); break
            res[f"{j['name']} @{ang}deg child {'+Z' if sgn > 0 else '-Z'}"] = hit
print(json.dumps(res, indent=1, ensure_ascii=False))
(OUT / "checks/axial_report.json").write_text(json.dumps(res, indent=1, ensure_ascii=False))
