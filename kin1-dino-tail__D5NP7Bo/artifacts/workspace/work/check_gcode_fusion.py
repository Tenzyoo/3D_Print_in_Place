"""Per-layer check on sliced G-code: are extruded tracks of different parts ever
connected (in-layer) or stacked on each other (adjacent layers)?"""
import sys, json, numpy as np, trimesh
from shapely.geometry import MultiLineString, Polygon, MultiPolygon
from shapely.ops import unary_union
from shapely.strtree import STRtree
from gcode_parse import parse

gc = sys.argv[1]
parts = [trimesh.load(f'/app/output/parts/parts_{i}.stl') for i in range(1, 5)]
allb = np.vstack([p.bounds for p in parts])
cx = (allb[:, 0].min() + allb[:, 0].max()) / 2; cy = (allb[:, 1].min() + allb[:, 1].max()) / 2
off = np.array([128 - cx, 128 - cy])
W = 0.45                                     # track width (perimeters 0.42-0.45)
segs = parse(gc)
layers = {}
for z, t, x0, y0, x1, y1 in segs:
    if t in ('Support material', 'Support material interface'): continue
    layers.setdefault(z, []).append(((x0 - off[0], y0 - off[1]), (x1 - off[0], y1 - off[1])))
zs = sorted(layers)

def section(m, z):
    s = m.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
    if s is None: return Polygon()
    p2, T = s.to_2D(to_2D=np.eye(4)) if "to_2D" in s.to_2D.__code__.co_varnames else s.to_planar(to_2D=np.eye(4))
    return unary_union([Polygon(p.exterior.coords, [i.coords for i in p.interiors]) for p in p2.polygons_full]).buffer(0)

def comps(g):
    if g.is_empty: return []
    return list(g.geoms) if isinstance(g, MultiPolygon) else [g]

fused = []; stacked = []; min_gap = {}; mat_by_part_prev = None
align = []
for z in zs:
    mat = unary_union(MultiLineString(layers[z]).buffer(W / 2, cap_style=1, join_style=1))
    secs = [section(p, z - 0.1) for p in parts]
    mat_parts = [[] for _ in parts]
    for c in comps(mat):
        ov = [c.intersection(s.buffer(0.1)).area for s in secs]
        owners = [i for i, a in enumerate(ov) if a > 0.02]
        if len(owners) > 1: fused.append((z, owners, [round(ov[i], 3) for i in owners]))
        if owners: mat_parts[int(np.argmax(ov))].append(c)
    mp = [unary_union(m) if m else Polygon() for m in mat_parts]
    tot = sum(s.area for s in secs)
    if tot > 0: align.append(sum(mp[i].intersection(secs[i]).area for i in range(4)) / max(mat.area, 1e-9))
    for i in range(4):
        for j in range(i + 1, 4):
            if mp[i].is_empty or mp[j].is_empty: continue
            d = mp[i].distance(mp[j])
            key = f'{i+1}-{j+1}'
            if d < min_gap.get(key, (1e9,))[0]: min_gap[key] = (round(d, 3), z)
    if mat_by_part_prev is not None:
        for i in range(4):
            for j in range(4):
                if i == j or mp[i].is_empty or mat_by_part_prev[j].is_empty: continue
                a = mp[i].intersection(mat_by_part_prev[j]).area
                if a > 0.01: stacked.append((z, i + 1, j + 1, round(a, 3)))
    mat_by_part_prev = mp
res = {'gcode': gc, 'layers': len(zs), 'mean_track_to_mesh_alignment': round(float(np.mean(align)), 4),
       'in_layer_fused_components': fused[:20], 'n_in_layer_fused': len(fused),
       'stacked_on_other_part': stacked[:20], 'n_stacked': len(stacked),
       'min_in_layer_gap_between_parts_mm (gap,z)': min_gap}
print(json.dumps(res, indent=1))
json.dump(res, open(gc + '.fusion.json', 'w'), indent=1)
