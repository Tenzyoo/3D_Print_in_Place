import json, hashlib, numpy as np, trimesh
O = '/app/output'; W = '/app/work'
kin = json.load(open(f'{W}/kin_results.json'))
fus_n = json.load(open(f'{W}/model_nosupport.gcode.fusion.json'))
fus_a = json.load(open(f'{W}/model_autosupport.gcode.fusion.json'))

ids = ['body', 'tail_1', 'tail_2', 'tail_3']
desc = ['fixed main body: head, neck, torso and four legs (one rigid piece)',
        'tail segment 1 (nearest the body)', 'tail segment 2 (middle)', 'tail segment 3 (tail tip)']
J = [[46.0, 0.0, 0.0], [31.0, 0.0, 0.0], [16.0, 0.0, 0.0]]
# joint geometry (must match model.scad)
clr, rp, be, zb0, sh, Rc, Rm, Rs, Htop = 0.5, 2.0, 1.2, 0.4, 1.6, 5.5, 7.0, 8.0, 11.0
zh0 = zb0 + 2 * be + sh

parts = []
for i, n in enumerate(ids):
    f = f'{O}/parts/parts_{i+1}.stl'
    m = trimesh.load(f)
    parts.append({
        'id': n, 'file': f'parts/parts_{i+1}.stl', 'description': desc[i],
        'role': 'fixed' if i == 0 else 'moving',
        'sha256': hashlib.sha256(open(f, 'rb').read()).hexdigest(),
        'triangles': int(len(m.faces)), 'watertight': bool(m.is_watertight),
        'volume_mm3': round(float(m.volume), 2), 'surface_area_mm2': round(float(m.area), 2),
        'bbox_min_mm': np.round(m.bounds[0], 3).tolist(), 'bbox_max_mm': np.round(m.bounds[1], 3).tolist(),
        'centroid_mm': np.round(m.center_mass, 3).tolist(),
    })
# identifying features per part
parts[0]['features'] = {'pin_of_joint': 'J1', 'pin_axis_xy': J[0][:2]}
for i in (1, 2, 3):
    f = {'hole_of_joint': f'J{i}', 'hole_axis_xy': J[i-1][:2], 'knuckle_ring_outer_radius': Rc,
         'hole_radius': rp + clr}
    if i < 3: f.update({'pin_of_joint': f'J{i+1}', 'pin_axis_xy': J[i][:2]})
    parts[i]['features'] = f

sw = kin['single_joint_sweeps']
joints = []
for k in range(3):
    s = sw[f'J{k+1}']
    joints.append({
        'name': f'J{k+1}', 'type': 'revolute', 'parent': ids[k], 'child': ids[k+1],
        'moving_parts': ids[k+1:],
        'axis_direction': [0.0, 0.0, 1.0], 'axis_origin_mm': J[k],
        'axis_note': 'vertical line through axis_origin; origin moves with the parent part',
        'neutral_angle_deg': 0.0,
        'expected_range_deg': [-30.0, 30.0],
        'required_min_range_deg': [-20.0, 20.0],
        'measured_first_contact_deg': [-s['first_contact_deg']['-'], s['first_contact_deg']['+']],
        'min_clearance_mm_at_angle': s['min_distance_at'],
        'pin': {'owner': ids[k], 'shaft_radius_mm': rp, 'bead_radius_mm': rp + be,
                'bead_z_mm': [zb0, zb0 + 2 * be], 'mushroom_cap_radius_mm': Rm,
                'cap_cone_start_z_mm': zh0, 'top_z_mm': Htop},
        'hole': {'owner': ids[k+1], 'radius_mm': rp + clr, 'groove_for_bead': True,
                 'countersunk_top_under_cap': True, 'knuckle_outer_radius_mm': Rc},
        'radial_clearance_mm': clr,
        'axial_retention': ('pin carries a 45 deg diamond bead (r=%.1f) sitting in a matching groove of the '
                            'child hole (hole r=%.1f, overlap %.1f mm) -> blocks child moving -Z; a 45 deg '
                            'mushroom cap (r=%.1f) over the countersunk knuckle top blocks +Z.'
                            % (rp + be, rp + clr, be - clr, Rm)),
        'measured_translation_to_first_contact_mm': kin['translation_first_contact_mm'][f'J{k+1}'],
    })
out = {
    'units': 'mm',
    'coordinate_system': '+X toward the head, +Y left, +Z up (print direction), bed plane Z=0; '
                         'all STLs share this frame, neutral pose',
    'model_file': 'model.stl', 'source_file': 'model.scad',
    'fixed_body': 'body',
    'kinematic_chain': ['body', 'J1', 'tail_1', 'J2', 'tail_2', 'J3', 'tail_3'],
    'parts': parts, 'joints': joints,
    'pose_convention': 'pose(q1,q2,q3): T_body=I; T_tail_k = T_tail_(k-1) * RotZ(q_k about axis_origin of J_k). '
                       'Positive angle = counter-clockwise seen from +Z (tail swings toward -Y, because the tail lies on the -X side of each axis).',
}
json.dump(out, open(f'{O}/joints.json', 'w'), indent=2, ensure_ascii=False)

basic = open(f'{W}/basic_log.txt').read()
allm = trimesh.load(f'{O}/model.stl')
size = (allm.bounds[1] - allm.bounds[0]).round(2).tolist()
report = {
    'model': 'print-in-place sauropod dinosaur, 1 fixed body + 3 tail segments, 3 Z-axis pin joints',
    'envelope_mm': {'size_xyz': size, 'limit_xyz': [100, 50, 60], 'ok': bool(size[0] <= 100 and size[1] <= 50 and size[2] <= 60),
                    'note': 'neutral (as printed) pose; checked also with the tail swung: all joints at +30 deg gives Y extent 49.6 mm, still < 50'},
    'print_settings_assumed': {'material': 'PLA', 'nozzle_mm': 0.4, 'layer_mm': 0.2,
                               'orientation': 'as modelled, legs and whole tail flat on the bed, no rotation',
                               'recommended_profile': '/opt/slicer/p1s_pla_0.20mm_nosupport.ini (supports OFF)'},
    'joint_design': {
        'type': 'vertical pin (part of parent) through a knuckle ring (part of child); pin is a single body of revolution grown from the bed and fused into the parent at its mushroom cap',
        'radial_clearance_mm': clr,
        'other_moving_surfaces': 'the child cavity is the exact 2D offset (r=0.5 mm) of the pin profile, so bead/groove, countersink/cap and cap rim all have a 0.5 mm normal gap (0.71 mm vertical on 45 deg flanks); socket wall to knuckle 0.5 mm; arm-to-socket faces 5.5 mm at neutral',
        'self_supporting': 'every surface inside the joint gaps is vertical or a 45 deg cone; both parts start on the bed, so no support is needed in or under any joint gap',
    },
    'checks': [
        {'name': 'mesh validity', 'method': 'trimesh + prusa-slicer --info', 'result': 'all 4 parts watertight/manifold, 1 shell each; model.stl volume equals sum of parts (26510.6 mm3), 4 shells'},
        {'name': 'envelope', 'method': 'bounding box of model.stl', 'result': f'{size} mm <= 100 x 50 x 60'},
        {'name': 'overhang analysis', 'method': 'faces with downward normal flatter than 45 deg (above bed) and isolated local-minimum vertices',
         'result': 'none in any part (0.00 mm2), no floating islands'},
        {'name': 'neutral clearance', 'method': 'vertex-to-surface distance between adjacent parts', 'result': kin['neutral_min_distance_mm']},
        {'name': 'neutral interference', 'method': 'manifold3d boolean intersection of all part pairs', 'result': 'zero volume'},
        {'name': 'single joint sweep', 'method': 'rotate child subtree about each joint axis in 1 deg steps until first boolean intersection; clearance measured at +-20/+-30 deg',
         'result': {k: v for k, v in kin['single_joint_sweeps'].items()}},
        {'name': 'combined poses', 'method': 'all 27 combinations of (-30, 0, +30) deg on J1..J3, pairwise intersection of all 4 parts',
         'result': f"max intersection {kin['combined_pose_check']['max_intersection_mm3']} mm3, colliding poses: {len(kin['combined_pose_check']['colliding'])}"},
        {'name': 'axial / radial retention', 'method': 'translate each child continuously (0.05 mm steps) relative to its parent along +-Z, +-X, +-Y until first contact',
         'result': kin['translation_first_contact_mm'],
         'interpretation': 'child is captured: it can move only by the clearance (0.75 mm along Z = 0.5*sqrt2 on 45 deg flanks, 0.55 mm radially) before pin bead/cap block it; separation would need the 0.7 mm bead overlap to be forced past the lip'},
        {'name': 'slicing (no supports)', 'method': 'prusa-slicer 2.7 with p1s_pla_0.20mm_nosupport.ini',
         'result': 'slices without error, 280 layers, ~12.3 cm3 filament, ~1h48m'},
        {'name': 'slicing (auto supports)', 'method': 'prusa-slicer with p1s_pla_0.20mm_autosupport.ini',
         'result': 'support generated only under the body belly arches (model X 59-76 mm, Z<=16.4 mm), >=13 mm from the nearest joint axis and outside every joint gap; nothing in/near the tail joints'},
        {'name': 'G-code fusion check', 'method': 'per layer: extrusion tracks buffered to 0.45 mm width, matched to mesh sections of each part; flag any track region touching two parts in-layer, or one part printed on top of another part in the previous layer',
         'result': {'nosupport': {'layers': fus_n['layers'], 'in_layer_fused': fus_n['n_in_layer_fused'], 'stacked': fus_n['n_stacked'],
                                  'min_gap_between_tracks_mm': {k: v[0] for k, v in fus_n['min_in_layer_gap_between_parts_mm (gap,z)'].items()}},
                    'autosupport': {'in_layer_fused': fus_a['n_in_layer_fused'], 'stacked': fus_a['n_stacked']}}},
    ],
    'limitations': [
        'All 3 joints are real, separately meshed rotating parts; no joint is faked. Motion/retention was verified geometrically and on sliced G-code only, not by a physical print.',
        'Rotation is limited by the arm-to-socket hard stop at about +-39..41 deg; the declared working range is +-30 deg (requirement +-20 deg).',
        'Axial retention relies on a 0.7 mm radial bead overlap; a strong pull could snap the knuckle off the bead (PLA). Not a load-bearing joint.',
        'The 0.5 mm gaps assume a calibrated printer; strong elephant-foot on the first layer could tack the knuckle rings, pins and socket walls (all start on the bed) - enable elephant-foot compensation or break the joints loose gently after printing.',
        'The tail lies flat on the bed (required so every joint starts on the bed and needs no support); it cannot be raised/lowered, only swung in the XY plane.',
        'PrusaSlicer auto-support flags the pointed-arch apex under the belly (two 45 deg cones meeting); the model is designed for the no-support profile, where that apex prints as a self-supporting gothic arch. If supports are enabled anyway they stay under the belly, away from the joints.',
        'The 100x50x60 mm limit is checked for the neutral, as-printed pose (94.99 x 26.2 x 55.99 mm). Swung to all +30 deg the width is 49.6 mm; beyond about +-30 deg on all joints together it would exceed 50 mm in Y.',
        'Mesh-based clearance numbers are vertex-to-surface approximations (faceting $fn=96 on joint surfaces).',
    ],
}
json.dump(report, open(f'{O}/report.json', 'w'), indent=2, ensure_ascii=False, default=str)
print('ok', size)
