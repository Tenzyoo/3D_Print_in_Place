"""Slice-level check: measure the gap between the *extruded* paths of
neighbouring parts in every layer of the PrusaSlicer G-code.
Each extrusion move is turned into a strip of its declared ;WIDTH, assigned
to the part whose cross-section is nearest, and the minimum distance between
the strips of the two parts of each joint is reported."""
import sys, json, re, numpy as np, trimesh
from shapely.geometry import LineString
from shapely.ops import unary_union
from shapely.strtree import STRtree

gcode, root = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "/app/output")
J = json.load(open(f"{root}/joints.json"))
meshes = [trimesh.load(f"{root}/{p['file']}") for p in J["parts"]]

layers = {}          # z -> list of (x0,y0,x1,y1,w,type)
z = 0; x = y = e = 0.0; w = 0.42; typ = ""; erel = False
for ln in open(gcode):
    if ln.startswith(";Z:"): z = float(ln[3:]); continue
    if ln.startswith(";WIDTH:"): w = float(ln[7:]); continue
    if ln.startswith(";TYPE:"): typ = ln[6:].strip(); continue
    if ln.startswith("M83"): erel = True
    if ln.startswith("G92"):
        m = re.search(r"E([-\d.]+)", ln); e = float(m.group(1)) if m else e
    if not ln.startswith(("G1 ", "G0 ")): continue
    c = dict((k, float(v)) for k, v in re.findall(r"([XYZE])([-\d.]+)", ln.split(";")[0]))
    nx, ny = c.get("X", x), c.get("Y", y)
    de = 0.0
    if "E" in c:
        de = c["E"] if erel else c["E"] - e
        e = e + c["E"] if erel else c["E"]
    if de > 1e-5 and (nx, ny) != (x, y):
        layers.setdefault(round(z, 3), []).append((x, y, nx, ny, w, typ))
    x, y = nx, ny

# PrusaSlicer re-centres the object on the bed: undo that shift
allp = np.array([(a[0], a[1]) for zl, v in layers.items() if zl > 0.3 for a in v])
full = trimesh.util.concatenate(meshes)
shift = (allp.min(0) + allp.max(0)) / 2 - (full.bounds[0, :2] + full.bounds[1, :2]) / 2
layers = {zl: [(a[0]-shift[0], a[1]-shift[1], a[2]-shift[0], a[3]-shift[1], a[4], a[5]) for a in v]
          for zl, v in layers.items()}
jx = [jt["origin"][0] for jt in J["joints"]]
bridges_near_joint = sum(1 for zl, v in layers.items() for a in v if a[5].startswith("Bridge")
                         and min(np.hypot((a[0]+a[2])/2 - j, (a[1]+a[3])/2) for j in jx) < 12)
# every bridge must lie over solid material of the *same* part in the layer
# below (i.e. internal bridge over sparse infill), never over a joint gap
def section(m, zz):
    s_ = m.section(plane_origin=[0, 0, zz], plane_normal=[0, 0, 1])
    return None if s_ is None else unary_union(s_.to_2D(to_2D=np.eye(4))[0].polygons_full)
bridge_over_air = 0; bridge_total = 0; bridge_z = set()
for zl, v in layers.items():
    br = [a for a in v if a[5].startswith("Bridge")]
    if not br: continue
    below = [section(m, zl - 0.3) for m in meshes]
    here = [section(m, zl - 0.1) for m in meshes]
    for a in br:
        L = LineString([(a[0], a[1]), (a[2], a[3])])
        mid = L.interpolate(0.5, normalized=True)
        i = int(np.argmin([h.distance(mid) if h is not None else 1e9 for h in here]))
        bridge_total += 1; bridge_z.add(zl)
        if below[i] is None or not below[i].buffer(1e-3).contains(L):
            bridge_over_air += 1
worst = {jt["id"]: (9, None) for jt in J["joints"]}
first = {}
types = set()
for zl, segs in sorted(layers.items()):
    zc = zl - 0.1
    secs = []
    for m in meshes:
        s = m.section(plane_origin=[0, 0, zc], plane_normal=[0, 0, 1])
        secs.append(None if s is None else unary_union(s.to_2D(to_2D=np.eye(4))[0].polygons_full))
    strips = {i: [] for i in range(6)}
    for x0, y0, x1, y1, ww, t in segs:
        types.add(t)
        L = LineString([(x0, y0), (x1, y1)])
        mid = L.interpolate(0.5, normalized=True)
        d = [s.distance(mid) if s is not None else 1e9 for s in secs]
        strips[int(np.argmin(d))].append(L.buffer(ww / 2, cap_style=1))
    U = {i: unary_union(v) if v else None for i, v in strips.items()}
    for jt in J["joints"]:
        a, b = jt["parent_part"] - 1, jt["child_part"] - 1
        if U[a] is None or U[b] is None: continue
        g = U[a].distance(U[b])
        if g < worst[jt["id"]][0]: worst[jt["id"]] = (g, zl)
        if zl == min(layers): first[jt["id"]] = g

out = [f"G-code: {gcode}", f"bed shift removed: {np.round(shift,3).tolist()}",
       f"bridge extrusions within 12 mm of a joint axis: {bridges_near_joint}",
       f"bridge extrusions total: {bridge_total} at z={sorted(bridge_z)}; not fully over the same part's material below: {bridge_over_air}",
       f"support extrusions: {sum(1 for v in layers.values() for a in v if 'Support' in a[5])}", f"layers: {len(layers)}, extrusion types: {sorted(types)}"]
for k, (g, zl) in worst.items():
    out.append(f"joint {k}: min gap between extruded paths = {g:.3f} mm (layer z={zl}); first layer gap = {first.get(k, float('nan')):.3f} mm")
print("\n".join(out))
open(f"{root}/checks/gcode_gap_report.txt", "w").write("\n".join(out) + "\n")
