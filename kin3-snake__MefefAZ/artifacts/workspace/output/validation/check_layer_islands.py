#!/usr/bin/env python3
"""Check that the sliced G-code keeps the six parts as six separate islands.

The check buffers each layer's extrusion centre-lines by half an extrusion
width (0.21 mm) and counts the resulting connected road islands.  This is a
conservative test: two parts joined by a printed road would become one island.
Layers above Z=10.0 contain only the two raised eye bumps and are ignored.
"""
import json
import re

from shapely.geometry import LineString
from shapely.ops import unary_union

GCODE = "/app/output/model.gcode"
OUT = "/app/output/validation/layer_island_check.json"

layers = []          # (z, [LineString, ...])
z = None
cur = []
last_xy = None
last_e = None
seen_layer = False

for raw in open(GCODE, errors="ignore"):
    line = raw.strip()
    if line.startswith(";LAYER_CHANGE"):
        if seen_layer:
            layers.append((z, cur))
        seen_layer = True
        cur = []
        last_xy = None
        continue
    if line.startswith(";Z:"):
        z = float(line.split(":", 1)[1])
        continue
    if line.startswith("G92 E"):
        try:
            last_e = float(line.split("E", 1)[1])
        except ValueError:
            pass
        continue
    m = re.match(r"G1 X([-\d.]+) Y([-\d.]+)(?: E([-\d.]+))?", line)
    if not m:
        continue
    x, y = float(m.group(1)), float(m.group(2))
    e = float(m.group(3)) if m.group(3) is not None else None
    if last_xy is not None and e is not None and last_e is not None and e > last_e + 1e-9:
        if (x, y) != last_xy:
            cur.append(LineString([last_xy, (x, y)]))
    if e is not None:
        last_e = e
    last_xy = (x, y)
if seen_layer:
    layers.append((z, cur))

rows = []
for z, segs in layers:
    if z is None or z > 10.0001:
        continue
    buf = unary_union([s.buffer(0.21, resolution=4) for s in segs])
    polys = list(buf.geoms) if buf.geom_type == "MultiPolygon" else [buf]
    polys = [p for p in polys if p.area > 0.5]
    rows.append(
        {
            "z_mm": round(z, 2),
            "extrusion_segments": len(segs),
            "road_islands": len(polys),
            "island_areas_mm2": [round(float(p.area), 2) for p in sorted(polys, key=lambda q: q.centroid.x)],
        }
    )

counts = sorted(set(r["road_islands"] for r in rows))
result = {
    "gcode": GCODE,
    "layers_checked_z_le_10": len(rows),
    "expected_parts": 6,
    "island_counts_observed": counts,
    "all_layers_have_6_islands": all(r["road_islands"] == 6 for r in rows),
    "layers": rows,
}
with open(OUT, "w") as f:
    json.dump(result, f, indent=2)
print(json.dumps({k: v for k, v in result.items() if k != "layers"}, indent=2))
