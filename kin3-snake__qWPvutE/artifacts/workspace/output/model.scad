// ============================================================================
// Print-in-Place Articulated Snake Model for FDM 3D Printing
// ============================================================================
// Structure:
//   - 6 Independent Rigid Parts:
//       Part 1 (parts_1.stl): Sculpted Snake Head (anterior)
//       Part 2 (parts_2.stl): Body Segment 1
//       Part 3 (parts_3.stl): Body Segment 2
//       Part 4 (parts_4.stl): Body Segment 3
//       Part 5 (parts_5.stl): Body Segment 4
//       Part 6 (parts_6.stl): Body Segment 5 / Tapered Tail (posterior)
//   - 5 Z-Axis Revolute Pin Joints (joint_1 .. joint_5):
//       Located at X = [-46, -23, 0, 23, 46] mm, Y = 0 mm, rotating around Z.
//       Each joint features:
//         * Vertical cylindrical pin (R = 2.60 mm) & cylindrical bore (R = 3.10 mm)
//           -> Single-side radial clearance = 0.50 mm (within 0.4 - 0.6 mm).
//         * Bidirectional Z-axis axial retention via 45-degree self-supporting
//           bottom retention cone (R_base = 4.20 mm > R_hole = 3.10 mm) and
//           top captured bridge + 45-degree conical roof.
//         * >= +/-35 deg horizontal rotation range (exceeding +/-25 deg requirement).
//         * All overhangs <= 45 deg from vertical; zero support material required.
// ============================================================================

$fn = 96;

// --- Export Control ---
// part_index = 0 : Complete assembly in neutral posture (model.stl)
// part_index = 1..6 : Individual rigid parts (parts_1.stl .. parts_6.stl)
part_index = 0;

// Optional joint angles (deg) for kinematic pose visualization when part_index == 0
joint_angles = [0, 0, 0, 0, 0];

// --- Global Dimensional Parameters ---
num_parts       = 6;
num_joints      = 5;
segment_pitch   = 23.0;                         // Distance between adjacent joint axes (mm)
joint_x_coords  = [-46.0, -23.0, 0.0, 23.0, 46.0];
body_height     = 14.0;                         // Nominal height at joints (mm)

// --- Joint Clearance & Pin Parameters (PLA, 0.4mm nozzle, 0.2mm layer) ---
radial_clearance = 0.50;                        // Single-side pin-to-bore radial gap (0.4-0.6 mm)
cone_z_extra     = 0.22;                        // Extra vertical shift on 45-deg cones so 3D perp gap = 0.509 mm
shoulder_gap     = 0.60;                        // Radial clearance at outer cheek/shoulder arc (mm)

pin_shaft_r      = 2.60;                        // Cylindrical pin shaft radius (mm)
bore_shaft_r     = pin_shaft_r + radial_clearance; // 3.10 mm cylindrical hole radius

pin_base_r       = 4.20;                        // Bottom axial retention flange radius (mm)
pin_base_h       = 0.80;                        // Vertical foot height at bottom of pin (mm)
pin_cone_top_z   = pin_base_h + (pin_base_r - pin_shaft_r); // 0.80 + 1.60 = 2.40 mm (45-deg taper)

bore_base_r      = pin_base_r + radial_clearance; // 4.70 mm bottom bore radius
bore_base_h      = pin_base_h + cone_z_extra;     // 1.02 mm
bore_cone_top_z  = bore_base_h + (bore_base_r - bore_shaft_r); // 1.02 + 1.60 = 2.62 mm (45-deg)

// Top retention & bridge parameters (all 45-deg self-supporting slopes)
pin_flare_bot_z  = 9.08;                        // Start of top 45-deg outward pin flare (mm)
pin_cap_r        = 3.80;                        // Top pin cap radius (mm)
pin_flare_top_z  = pin_flare_bot_z + (pin_cap_r - pin_shaft_r); // 9.08 + 1.20 = 10.28 mm

bore_flare_bot_z = pin_flare_bot_z - cone_z_extra; // 8.86 mm
neck_inner_r     = pin_cap_r + radial_clearance;   // 4.30 mm upper neck inner radius
bore_flare_top_z = bore_flare_bot_z + (neck_inner_r - bore_shaft_r); // 8.86 + 1.20 = 10.06 mm

socket_outer_r   = 6.20;                        // Outer radius of female socket ring (mm)
socket_roof_top_z = 9.16;                       // Top flat rim Z of socket ring (mm)
socket_roof_top_r = 3.80;                       // Outer radius of socket flat top rim (mm)
socket_roof_bot_z = socket_roof_top_z - (socket_outer_r - socket_roof_top_r); // 6.76 mm (45-deg)

pocket_inner_r   = socket_outer_r + radial_clearance; // 6.70 mm inner pocket radius
bridge_corbel_bot_z = socket_roof_bot_z + cone_z_extra; // 6.98 mm
bridge_merge_r   = 3.60;                        // Radius where bridge meets pin flare (< pin_cap_r)
bridge_corbel_top_z = bridge_corbel_bot_z + (pocket_inner_r - bridge_merge_r); // 10.08 mm

cheek_outer_r    = 9.00;                        // Outer radius of male cheek wall around joint (mm)
shoulder_inner_r = cheek_outer_r + shoulder_gap; // 9.60 mm inner concave radius of next segment

// Angular sector parameters (deg) for rotation range
neck_half_angle   = 25.0;                       // Posterior neck half-angle (+/-25 deg)
pocket_open_angle = 68.0;                       // Anterior pocket opening half-angle (+/-68 deg)
// Physical collision-free angular swing = 68 - 25 = +/-43 deg (> +/-38 deg with 0.5mm margin)

// Segment width profile (half-widths in mm for Parts 1..6)
seg_half_widths = [13.2, 10.8, 10.3, 9.8, 9.3, 8.6];

// ============================================================================
// Helper Modules: Chamfered Self-Supporting Cylinders & Prisms
// ============================================================================

// Vertical cylinder with 45-deg bottom bevel and 45-deg top bevel, flat on Z=0
module beveled_disk(r_mid, h, bevel_bot = 1.6, bevel_top = 1.8) {
    r_bot = max(0.5, r_mid - bevel_bot);
    r_top = max(0.5, r_mid - bevel_top);
    rotate_extrude(angle = 360)
        polygon(points = [
            [0,     0],
            [r_bot, 0],
            [r_mid, bevel_bot],
            [r_mid, h - bevel_top],
            [r_top, h],
            [0,     h]
        ]);
}

// Raised dorsal scale chevron / ridge (all slopes <= 45 deg)
module dorsal_scale(x_center, width_y, length_x, base_z = 12.2, peak_z = 14.8) {
    dz = peak_z - base_z;
    hull() {
        translate([x_center - length_x * 0.35, 0, base_z])
            scale([1.0, width_y / (2 * dz + 1.2), 1.0])
                cylinder(r1 = dz + 0.6, r2 = 0.6, h = dz, $fn = 36);
        translate([x_center + length_x * 0.35, 0, base_z])
            cylinder(r1 = dz + 0.4, r2 = 0.4, h = dz * 0.85, $fn = 36);
    }
}

// ============================================================================
// Joint Building Blocks (Centered at Local Origin [0, 0, 0])
// ============================================================================

// 1. Male Central Pin (belongs to Anterior Part at joint)
module joint_male_pin() {
    rotate_extrude(angle = 360)
        polygon(points = [
            [0.00,        0.00],
            [pin_base_r,  0.00],
            [pin_base_r,  pin_base_h],
            [pin_shaft_r, pin_cone_top_z],
            [pin_shaft_r, pin_flare_bot_z],
            [pin_cap_r,   pin_flare_top_z],
            [pin_cap_r,   body_height],
            [0.00,        body_height]
        ]);
}

// 2. Male Pocket Cavity & Neck Swing Cutout (subtracted from Anterior Part)
module joint_male_cutout() {
    union() {
        // 360-deg revolved pocket cavity for the female socket ring
        rotate_extrude(angle = 360)
            polygon(points = [
                [0.00,           -0.20],
                [pocket_inner_r, -0.20],
                [pocket_inner_r, bridge_corbel_bot_z],
                [bridge_merge_r, bridge_corbel_top_z],
                [0.00,           bridge_corbel_top_z]
            ]);

        // Open angular sector [-pocket_open_angle, +pocket_open_angle] on +X side
        // allowing the posterior segment's neck to swing +/-38 deg freely
        rotate([0, 0, -pocket_open_angle])
            rotate_extrude(angle = 2 * pocket_open_angle)
                polygon(points = [
                    [0.00, -0.20],
                    [15.0, -0.20],
                    [15.0, body_height + 2.50],
                    [0.00, body_height + 2.50]
                ]);

        // Trim any exterior material beyond cheek_outer_r on the +X half
        difference() {
            translate([0, -20, -0.20])
                cube([20, 40, body_height + 3.0]);
            cylinder(r = cheek_outer_r, h = body_height + 3.5, $fn = 96);
        }
    }
}

// 3. Female Socket Ring + Neck Solid (added to Posterior Part at joint)
module joint_female_add(neck_reach_r = 11.8) {
    union() {
        // 360-deg Socket Ring Blank
        rotate_extrude(angle = 360)
            polygon(points = [
                [0.00,              0.00],
                [socket_outer_r,    0.00],
                [socket_outer_r,    socket_roof_bot_z],
                [socket_roof_top_r, socket_roof_top_z],
                [0.00,              socket_roof_top_z]
            ]);

        // Posterior Neck Sector [-neck_half_angle, +neck_half_angle] around +X
        // Connects socket ring into the posterior segment's main body
        rotate([0, 0, -neck_half_angle])
            rotate_extrude(angle = 2 * neck_half_angle)
                polygon(points = [
                    [0.00,         0.00],
                    [neck_reach_r, 0.00],
                    [neck_reach_r, body_height],
                    [neck_inner_r, body_height],
                    [neck_inner_r, bore_flare_top_z],
                    [3.10,         bore_flare_bot_z],
                    [0.00,         bore_flare_bot_z]
                ]);
    }
}

// 4. Female Bore Cutout (subtracted from Posterior Part at joint)
module joint_female_bore() {
    rotate_extrude(angle = 360)
        polygon(points = [
            [0.00,         -0.20],
            [bore_base_r,  -0.20],
            [bore_base_r,  bore_base_h],
            [bore_shaft_r, bore_cone_top_z],
            [bore_shaft_r, bore_flare_bot_z],
            [neck_inner_r, bore_flare_top_z],
            [neck_inner_r, body_height + 2.00],
            [0.00,         body_height + 2.00]
        ]);
}

// 5. Female Anterior Shoulder Clearance Cutout (subtracted from Posterior Part body)
module joint_female_shoulder_cut() {
    translate([0, 0, -0.20])
        cylinder(r = shoulder_inner_r, h = body_height + 3.0, $fn = 96);
}

// ============================================================================
// Part 1: Snake Head (parts_1.stl)
// Snout at X = -74.0 mm, Joint 1 (Male Pin + Pocket) at X = -46.0 mm
// ============================================================================
module part_1_head() {
    j1_x = joint_x_coords[0]; // -46.0 mm
    union() {
        difference() {
            // Sculpted biomimetic head outer shell
            union() {
                // Snout to temples main hull
                hull() {
                    // Rounded snout tip at X = -69.5 (radius 4.5 -> min X = -74.0 mm)
                    translate([-69.5, 0, 0])
                        beveled_disk(r_mid = 4.5, h = 10.5, bevel_bot = 1.2, bevel_top = 2.0);
                    // Anterior jaw widening
                    translate([-63.0, -4.2, 0])
                        beveled_disk(r_mid = 5.0, h = 12.2, bevel_bot = 1.5, bevel_top = 2.2);
                    translate([-63.0,  4.2, 0])
                        beveled_disk(r_mid = 5.0, h = 12.2, bevel_bot = 1.5, bevel_top = 2.2);
                    // Wide cheek / temporal region (max Y = +/-13.2 mm, width = 26.4 mm)
                    translate([-55.5, -5.2, 0])
                        beveled_disk(r_mid = 8.0, h = 14.2, bevel_bot = 1.8, bevel_top = 2.2);
                    translate([-55.5,  5.2, 0])
                        beveled_disk(r_mid = 8.0, h = 14.2, bevel_bot = 1.8, bevel_top = 2.2);
                }

                // Temples tapering into Joint 1 cheek cylinder at X = -46.0 mm
                hull() {
                    translate([-55.5, -5.2, 0])
                        beveled_disk(r_mid = 8.0, h = 14.2, bevel_bot = 1.8, bevel_top = 2.2);
                    translate([-55.5,  5.2, 0])
                        beveled_disk(r_mid = 8.0, h = 14.2, bevel_bot = 1.8, bevel_top = 2.2);
                    translate([j1_x, 0, 0])
                        beveled_disk(r_mid = cheek_outer_r, h = body_height, bevel_bot = 0.0, bevel_top = 1.1);
                }

                // Supraorbital brow ridges & crown shield
                hull() {
                    translate([-61.5, -3.6, 11.5])
                        cylinder(r1 = 2.4, r2 = 0.8, h = 2.6, $fn = 36);
                    translate([-55.0, -4.5, 12.0])
                        cylinder(r1 = 3.0, r2 = 1.0, h = 3.2, $fn = 36);
                    translate([-54.0, 0, 12.5])
                        cylinder(r1 = 3.2, r2 = 1.2, h = 3.0, $fn = 36);
                    translate([-55.0,  4.5, 12.0])
                        cylinder(r1 = 3.0, r2 = 1.0, h = 3.2, $fn = 36);
                    translate([-61.5,  3.6, 11.5])
                        cylinder(r1 = 2.4, r2 = 0.8, h = 2.6, $fn = 36);
                }

                // Parietal dorsal head crest
                dorsal_scale(x_center = -51.5, width_y = 8.0, length_x = 6.5, base_z = 12.8, peak_z = 15.2);
            }

            // Sculpted nostril indents (45-deg self-supporting conical pits on top of snout)
            for (side = [-1, 1]) {
                translate([-68.0, side * 2.4, 9.6])
                    cylinder(r1 = 0.3, r2 = 1.3, h = 1.5, $fn = 32);

                // Shallow self-supporting eye socket bevels on upper flanks
                translate([-60.0, side * 7.8, 10.2])
                    rotate([side * 25, 0, side * (-18)])
                        cylinder(r1 = 0.8, r2 = 2.6, h = 2.2, $fn = 36);
            }

            // Subtract Male Pocket & Neck Swing Cutout at Joint 1
            translate([j1_x, 0, 0])
                joint_male_cutout();
        }

        // Add Raised Pupils inside Eye Sockets (self-supporting conical domes)
        for (side = [-1, 1]) {
            translate([-60.0, side * 7.3, 9.6])
                cylinder(r1 = 1.6, r2 = 0.5, h = 1.8, $fn = 32);
        }

        // Add Male Central Pin at Joint 1
        translate([j1_x, 0, 0])
            joint_male_pin();
    }
}

// ============================================================================
// Parts 2..5: Intermediate Body Segments 1..4 (parts_2.stl .. parts_5.stl)
// Segment k (k = 1..4) connects Anterior Joint k to Posterior Joint k+1
// ============================================================================
module body_segment(seg_idx) {
    // seg_idx in {1, 2, 3, 4} corresponds to Part (seg_idx + 1)
    jx_front = joint_x_coords[seg_idx - 1];
    jx_back  = joint_x_coords[seg_idx];
    x_mid    = 0.5 * (jx_front + jx_back);
    half_w   = seg_half_widths[seg_idx];
    lobe_y   = max(0.6, half_w - 8.2);

    union() {
        difference() {
            union() {
                // Main sculpted body core between front shoulder and back joint
                difference() {
                    union() {
                        hull() {
                            // Front body lobes (just behind front shoulder arc)
                            translate([jx_front + 10.5, -lobe_y, 0])
                                beveled_disk(r_mid = 8.2, h = body_height, bevel_bot = 1.4, bevel_top = 1.6);
                            translate([jx_front + 10.5,  lobe_y, 0])
                                beveled_disk(r_mid = 8.2, h = body_height, bevel_bot = 1.4, bevel_top = 1.6);

                            // Mid-segment widest cross-section
                            translate([x_mid, -lobe_y, 0])
                                beveled_disk(r_mid = 8.2, h = body_height, bevel_bot = 1.4, bevel_top = 1.6);
                            translate([x_mid,  lobe_y, 0])
                                beveled_disk(r_mid = 8.2, h = body_height, bevel_bot = 1.4, bevel_top = 1.6);

                            // Rear cylinder centered at jx_back (radius = cheek_outer_r = 9.0 mm)
                            translate([jx_back, 0, 0])
                                beveled_disk(r_mid = cheek_outer_r, h = body_height, bevel_bot = 0.0, bevel_top = 1.1);
                        }

                        // Dorsal biomimetic scale ridge on the back of the segment
                        dorsal_scale(x_center = x_mid + 0.8, width_y = half_w * 1.05, length_x = 7.5, base_z = 12.6, peak_z = 14.8);
                    }

                    // Clear out the front shoulder zone (r < shoulder_inner_r = 9.60 mm) around jx_front
                    translate([jx_front, 0, 0])
                        joint_female_shoulder_cut();
                }

                // Add Female Socket Ring + Neck at jx_front
                translate([jx_front, 0, 0])
                    joint_female_add(neck_reach_r = 12.0);
            }

            // Subtract Female Bore at jx_front
            translate([jx_front, 0, 0])
                joint_female_bore();

            // Subtract Male Pocket & Neck Swing Cutout at jx_back
            translate([jx_back, 0, 0])
                joint_male_cutout();
        }

        // Add Male Central Pin at jx_back
        translate([jx_back, 0, 0])
            joint_male_pin();
    }
}

// ============================================================================
// Part 6: Body Segment 5 / Tapered Tail (parts_6.stl)
// Connects Anterior Joint 5 at X = +46.0 mm to Tail Tip at X = +74.0 mm
// ============================================================================
module part_6_tail() {
    jx_front = joint_x_coords[4]; // +46.0 mm
    difference() {
        union() {
            // Main tapered tail body outside front shoulder cut
            difference() {
                union() {
                    // Anterior tail body to mid-tail
                    hull() {
                        translate([jx_front + 10.5, -0.6, 0])
                            beveled_disk(r_mid = 8.0, h = body_height, bevel_bot = 1.4, bevel_top = 1.6);
                        translate([jx_front + 10.5,  0.6, 0])
                            beveled_disk(r_mid = 8.0, h = body_height, bevel_bot = 1.4, bevel_top = 1.6);
                        translate([jx_front + 17.5, 0, 0])
                            beveled_disk(r_mid = 6.2, h = 12.2, bevel_bot = 1.2, bevel_top = 1.6);
                    }

                    // Mid-tail tapering smoothly to rounded tail tip at X = +74.0 mm
                    hull() {
                        translate([jx_front + 17.5, 0, 0])
                            beveled_disk(r_mid = 6.2, h = 12.2, bevel_bot = 1.2, bevel_top = 1.6);
                        translate([70.5, 0, 0])
                            beveled_disk(r_mid = 3.5, h = 8.5, bevel_bot = 0.8, bevel_top = 1.5);
                    }

                    // Dorsal tail scales
                    dorsal_scale(x_center = jx_front + 12.5, width_y = 8.5, length_x = 6.0, base_z = 12.2, peak_z = 14.4);
                    dorsal_scale(x_center = jx_front + 19.0, width_y = 6.5, length_x = 5.0, base_z = 10.8, peak_z = 12.8);
                }

                // Clear out front shoulder zone around Joint 5
                translate([jx_front, 0, 0])
                    joint_female_shoulder_cut();
            }

            // Add Female Socket Ring + Neck at Joint 5
            translate([jx_front, 0, 0])
                joint_female_add(neck_reach_r = 12.0);
        }

        // Subtract Female Bore at Joint 5
        translate([jx_front, 0, 0])
            joint_female_bore();
    }
}

// ============================================================================
// Part Selector & Kinematic Assembly
// ============================================================================
module render_part(idx) {
    if (idx == 1) {
        part_1_head();
    } else if (idx >= 2 && idx <= 5) {
        body_segment(idx - 1);
    } else if (idx == 6) {
        part_6_tail();
    }
}

// Recursive kinematic chain for visualizing articulated poses around joint_x_coords
module render_kinematic_chain(idx) {
    render_part(idx);
    if (idx < num_parts) {
        jx = joint_x_coords[idx - 1];
        ang = joint_angles[idx - 1];
        translate([jx, 0, 0])
            rotate([0, 0, ang])
                translate([-jx, 0, 0])
                    render_kinematic_chain(idx + 1);
    }
}

if (part_index == 0) {
    render_kinematic_chain(1);
} else {
    render_part(part_index);
}
