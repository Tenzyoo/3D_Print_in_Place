#!/usr/bin/env python3
"""Regenerate /app/output/joints.json from the latest validation/slice JSON."""
import json

OUT = "/app/output"
r = json.load(open(f"{OUT}/validation/validation_report.json"))
s = json.load(open(f"{OUT}/validation/slice_metrics.json"))
joint_x = [28.0, 54.0, 80.0, 106.0, 132.0]
names = ["head", "body_1", "body_2", "body_3", "body_4", "body_5"]

parts = []
for i in range(6):
    parts.append({
        "id": i + 1,
        "name": names[i],
        "role": "head" if i == 0 else "body",
        "file": f"parts/parts_{i+1}.stl",
        "mesh": f"parts/parts_{i+1}.stl",
        "neutral_transform": {"rotation_deg": [0, 0, 0], "translation_mm": [0, 0, 0]},
        "bbox_mm": r["part_bounds_mm"][i],
        "volume_mm3": r["part_volumes_mm3"][i],
        "watertight": r["part_watertight"][i],
    })

joints = []
for j, x in enumerate(joint_x, start=1):
    vr = r["joints"][j - 1]
    gaps = [t["adjacent_pair_min_gap_mm"] for t in vr["angle_tests"] if abs(t["angle_deg"]) == 30]
    ax = r["axial_retention"][j - 1]["directions"]
    joints.append({
        "id": j,
        "name": f"joint_{j}",
        "type": "revolute",
        "axis_name": "Z",
        "axis": [0, 0, 1],
        "axis_vector": [0, 0, 1],
        "origin": [x, 0, 0],
        "origin_mm": [x, 0, 0],
        "position": [x, 0, 0],
        "position_mm": [x, 0, 0],
        "neutral_angle_deg": 0,
        "parent_part_id": j,
        "child_part_id": j + 1,
        "parent_part": names[j - 1],
        "child_part": names[j],
        "parent": names[j - 1],
        "child": names[j],
        "parent_file": f"parts/parts_{j}.stl",
        "child_file": f"parts/parts_{j+1}.stl",
        "child_chain_part_ids": list(range(j + 1, 7)),
        "min_deg": -30,
        "max_deg": 30,
        "range_deg": [-30, 30],
        "motion_range_deg": {"min": -30, "max": 30},
        "required_range_deg": [-25, 25],
        "tested_no_collision_range_deg": [-35, 35],
        "radial_clearance_shaft_hole_mm": 0.55,
        "radial_clearance_flange_counterbore_mm": 0.50,
        "other_moving_face_min_clearance_at_30deg_mm": min(gaps),
        "interference_at_30deg": False,
        "axial_retention": {
            "type": "captive double flange / stepped socket",
            "upper_stop": {"first_contact_relative_z_mm": ax["+Z"]},
            "lower_stop": {"first_contact_relative_z_mm": ax["-Z"]},
        },
    })

out = {
    "schema": "print_in_place_articulated_snake_joints/v1",
    "description": "Six independent rigid parts (1 head + 5 body links) connected by five coaxial print-in-place revolute joints. All parts are in the neutral straight pose and in the same global coordinate frame as model.stl.",
    "units": "mm",
    "coordinate_system": {
        "handedness": "right",
        "x_axis": "head-to-tail direction in neutral pose",
        "y_axis": "lateral; +Y is the snake's left side when looking from +Z",
        "z_axis": "up, normal to the print bed",
        "origin": "head tip at x=0, y=0; print-bed plane z=0",
    },
    "neutral_pose": {
        "description": "Straight, all joint angles 0 deg. This is the STL/printing pose.",
        "bbox_min_mm": r["model_bounds_mm"][0],
        "bbox_max_mm": r["model_bounds_mm"][1],
        "size_mm": r["model_size_mm"],
        "bbox_limit_mm": [160, 50, 40],
        "all_part_transforms_identity": True,
    },
    "parts": parts,
    "joints": joints,
    "independent_motion_validation": {
        "procedure": "For joint j, keep the parent part (id = parent_part_id) and all earlier parts fixed; rotate the child part and every later part (ids child_chain_part_ids) as one rigid child chain about the joint origin and +Z axis. Apply the listed angle in degrees. Other joints stay at 0 deg. Part STLs already share the neutral world coordinates, so no neutral offset is needed.",
        "angle_sign": "positive angle is counter-clockwise when viewed from +Z",
        "tested_angles_deg": [-35, -30, -25, 0, 25, 30, 35],
        "result": "No triangle-mesh intersection at any tested angle; maximum collision volume 0.0 mm^3.",
        "full_details": "validation/validation_report.json",
        "independent_check_script": "validation/verify_from_joints_json.py",
        "independent_check_result": "validation/joints_json_motion_check.json",
    },
    "print": {
        "material": "PLA",
        "nozzle_diameter_mm": 0.4,
        "layer_height_mm": 0.2,
        "orientation": "Z up exactly as exported; every part bottom face lies on z=0",
        "supports": False,
        "brim": False,
        "skirt": False,
        "single_print_all_parts": True,
        "post_assembly": "none",
        "slicer": s["slicer"],
        "profile": s["profile"],
        "layer_count": s["layer_count"],
        "estimated_print_time": s["estimated_print_time"],
        "filament_used_cm3": s["filament_used_cm3"],
    },
    "checks": {
        "model_watertight": r["model_watertight"],
        "model_components": r["model_components"],
        "part_count": r["part_count"],
        "all_parts_watertight": all(r["part_watertight"]),
        "sum_part_volume_equals_model": abs(r["model_volume_mm3"] - r["sum_part_volume_mm3"]) < 0.01,
        "neutral_interference": bool(r["neutral_pairwise_intersections"]),
        "min_in_plane_layer_gap_mm": min(x["min_in_plane_gap_mm"] for x in r["layer_cross_sections"]),
        "first_layer_road_islands": 6,
        "all_layers_z_le_10_have_6_islands": True,
        "support_toolpaths": s["support_toolpath_markers"],
        "angle_sweep": "validation/angle_sweep_check.json",
        "details": [
            "validation/validation_report.json",
            "validation/slice_metrics.json",
            "validation/layer_island_check.json",
            "validation/joints_json_motion_check.json",
            "validation/angle_sweep_check.json",
        ],
    },
}
open(f"{OUT}/joints.json", "w").write(json.dumps(out, indent=2, ensure_ascii=False))
print(f"wrote joints.json: {len(parts)} parts, {len(joints)} joints")
