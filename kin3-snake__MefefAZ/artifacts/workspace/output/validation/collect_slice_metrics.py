#!/usr/bin/env python3
"""Collect reproducible slicing metrics from the delivered G-code and logs."""
import json
import re

OUT = "/app/output"
lines = open(f"{OUT}/model.gcode", errors="ignore").read().splitlines()

header = {}
for line in lines:
    if line.startswith("; ") and " = " in line:
        k, v = line[2:].split(" = ", 1)
        header[k] = v

info_lines = open(f"{OUT}/validation/prusa_info_model.log").read().splitlines()
info = {}
for line in info_lines:
    if " = " in line:
        k, v = line.split(" = ", 1)
        info[k.strip()] = v.strip()

metrics = {
    "gcode": "model.gcode",
    "slicer": "PrusaSlicer 2.7.2",
    "profile": "/opt/slicer/p1s_pla_0.20mm_nosupport.ini",
    "nozzle_diameter_mm": float(header["nozzle_diameter"]),
    "layer_height_mm": float(header["layer_height"]),
    "perimeters": int(header["perimeters"]),
    "fill_density": header["fill_density"],
    "support_material": int(header["support_material"]),
    "brim_width_mm": float(header["brim_width"]),
    "layer_count": sum(1 for l in lines if l.startswith(";LAYER_CHANGE")),
    "max_z_mm": max(float(l.split(":")[1]) for l in lines if l.startswith(";Z:")),
    "support_toolpath_markers": sum(1 for l in lines if l.startswith(";TYPE:Support")),
    "brim_toolpath_markers": sum(1 for l in lines if l.startswith(";TYPE:Brim")),
    "skirt_toolpath_markers": sum(1 for l in lines if l.startswith(";TYPE:Skirt")),
    "estimated_print_time": header["estimated printing time (normal mode)"],
    "estimated_first_layer_time": header["estimated first layer printing time (normal mode)"],
    "filament_used_mm": float(header["filament used [mm]"]),
    "filament_used_cm3": float(header["filament used [cm3]"]),
    "model_info": {
        "file": "model.stl",
        "size_mm": [float(info["size_x"]), float(info["size_y"]), float(info["size_z"])],
        "min_mm": [float(info["min_x"]), float(info["min_y"]), float(info["min_z"])],
        "max_mm": [float(info["max_x"]), float(info["max_y"]), float(info["max_z"])],
        "manifold": info["manifold"],
        "number_of_parts": int(info["number_of_parts"]),
        "facets": int(info["number_of_facets"]),
        "volume_mm3": float(info["volume"]),
    },
}
with open(f"{OUT}/validation/slice_metrics.json", "w") as f:
    json.dump(metrics, f, indent=2)
print(json.dumps(metrics, indent=2))
