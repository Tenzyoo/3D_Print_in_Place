"""Parse PrusaSlicer G-code and verify that, on every layer, the extrusion paths of
neighbouring tubes stay separated (bead edge to bead edge) -> tubes cannot fuse."""
import re, sys, json, numpy as np
path = sys.argv[1]
layers = {}; z = None; w = 0.42; typ = ""; x = y = e = 0.0
for ln in open(path):
    if ln.startswith(";Z:"): z = round(float(ln[3:]), 2); continue
    if ln.startswith(";WIDTH:"): w = float(ln[7:]); continue
    if ln.startswith(";TYPE:"): typ = ln[6:].strip(); continue
    if not ln.startswith(("G1 ", "G0 ")): continue
    d = dict((m[0], float(m[1:])) for m in ln.split(";")[0].split()[1:] if m[0] in "XYZE")
    nx, ny, ne = d.get("X", x), d.get("Y", y), d.get("E", e)
    if "E" in d and ne > e and ("X" in d or "Y" in d) and z is not None:
        layers.setdefault(z, []).append((x, y, nx, ny, w, typ))
    x, y = nx, ny
    if "E" in d: e = ne
    if ln.startswith("G92"): pass
zs = sorted(layers)
# centre from first-layer extents
P = np.array([(s[0], s[1]) for s in layers[zs[0]]] + [(s[2], s[3]) for s in layers[zs[0]]])
cx, cy = (P.min(0) + P.max(0)) / 2
def seg_r(s):
    a, b = np.array(s[:2]) - (cx, cy), np.array(s[2:4]) - (cx, cy)
    t = np.clip(-a @ (b - a) / max((b - a) @ (b - a), 1e-12), 0, 1)
    return np.linalg.norm(a + t * (b - a)), max(np.linalg.norm(a), np.linalg.norm(b))
worst = []; summary = {}
for zz in zs:
    iv = sorted((rmin - s[4] / 2, rmax + s[4] / 2) for s in layers[zz] for rmin, rmax in [seg_r(s)])
    bands = [list(iv[0])]
    for a, b in iv[1:]:
        if a <= bands[-1][1] + 1e-6: bands[-1][1] = max(bands[-1][1], b)
        else: bands.append([a, b])
    gaps = [bands[i + 1][0] - bands[i][1] for i in range(len(bands) - 1)]
    summary[zz] = (len(bands), gaps, bands)
    worst.append((min(gaps) if gaps else 9e9, zz))
nb = [summary[z][0] for z in zs]
print(f"{path}: {len(zs)} layers, centre=({cx:.2f},{cy:.2f})")
print("bands per layer: min", min(nb), "max", max(nb))
for zz in [zs[0], zs[1], 0.6, 10.0, 18.0, 50.0, 105.0, 107.6, 108.0, 110.0, 111.6, 113.0, 116.0, 118.0, zs[-1]]:
    if zz in summary:
        n, g, b = summary[zz]
        print(f"z={zz:6.2f}: {n} bands  r-ranges={[tuple(round(v,2) for v in x) for x in b]}  gaps={[round(v,3) for v in g]}")
worst.sort()
print("smallest bead-to-bead radial gaps (gap, z):", [(round(g,3), z) for g, z in worst[:6]])
# where are bridges / which layers have < 4 separated bands (expected: z>107 has fewer tubes)
br = sorted({z for z in zs for s in layers[z] if s[5] == "Bridge infill"})
print("bridge-infill layers:", br)
for zb in br:
    rr = [seg_r(s) for s in layers[zb] if s[5] == "Bridge infill"]
    print(f"  bridge at z={zb}: r in [{min(r[0] for r in rr):.2f},{max(r[1] for r in rr):.2f}]")
json.dump({"layers": len(zs), "min_gap": worst[0][0], "min_gap_z": worst[0][1]},
          open(path + ".check.json", "w"))
