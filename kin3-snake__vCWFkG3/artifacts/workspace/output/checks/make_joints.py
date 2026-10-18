"""Write joints.json (values mirror the parameters in model.scad)."""
import json, math, sys
out = sys.argv[1] if len(sys.argv) > 1 else "/app/output/joints.json"
n_body, pitch, tip_r, tail_len = 5, 22, 1.6, 32
clr, R_pin, bulge, cone, H = 0.5, 5.5, 1.2, 60, 12
JX = lambda k: tip_r + tail_len + (n_body - k) * pitch
names = ["head"] + [f"body_{i}" for i in range(1, 6)]
parts = [{"id": i + 1, "name": names[i], "file": f"parts/parts_{i+1}.stl",
          "role": "head" if i == 0 else ("body segment %d" % i + (" (tail tip)" if i == 5 else ""))}
         for i in range(6)]
joints = []
for k in range(1, 6):
    joints.append({
        "id": k, "name": f"joint_{k}",
        "type": "revolute",
        "parent_part": k, "child_part": k + 1,
        "parent_file": f"parts/parts_{k}.stl", "child_file": f"parts/parts_{k+1}.stl",
        "parent_feature": "C-shaped socket ring with profiled bore",
        "child_feature": "vertical pin with 60deg double-cone retention collar + neck",
        "axis": [0, 0, 1],
        "origin": [JX(k), 0.0, 0.0],
        "axis_line": {"point": [JX(k), 0.0, 0.0], "direction": [0, 0, 1],
                      "z_range": [0.0, H]},
        "neutral_angle_deg": 0.0,
        "range_deg": [-30.0, 30.0],
        "hard_stop_deg_measured": [-37.1, 37.1],
        "moving_parts_when_rotated": list(range(k + 1, 7)),
        "radial_clearance_mm": clr,
        "pin_radius_mm": R_pin, "bore_radius_mm": R_pin + clr,
        "collar_radius_mm": R_pin + bulge, "collar_bore_radius_mm": R_pin + bulge + clr,
        "axial_play_mm": round(clr * math.tan(math.radians(cone)), 3),
        "axial_retention": "pin collar (double cone) captured inside the matching bore groove; "
                           "socket wraps >180deg around the pin",
    })
doc = {
    "units": "mm", "coordinate_system": "same as model.stl; Z up = print direction, bed at z=0",
    "pose": "neutral, straight (all joint angles 0)",
    "kinematic_tree": "serial chain rooted at the head (part 1); rotating joint k moves parts k+1..6 rigidly",
    "rotation_sign": "right-hand rule about +Z (positive = child swings counter-clockwise seen from above)",
    "parts": parts, "joints": joints,
}
json.dump(doc, open(out, "w"), indent=2)
print("wrote", out)
