// ============================================================================
// Print-in-Place Articulated Dinosaur Model (FDM 3D Printable)
// Overall Bounding Box: <= 100 x 50 x 60 mm (Actual: ~85.5 x 31.4 x 47.0 mm)
// Material & Process: PLA, 0.4mm nozzle, 0.2mm layer height, zero supports
// Structure:
//   - parts_1: Fixed main body (Head + Neck + Torso + 4 Legs + Joint 1 Socket)
//   - parts_2: Tail segment 1 (Joint 1 Pin + Segment Body + Joint 2 Socket)
//   - parts_3: Tail segment 2 (Joint 2 Pin + Segment Body + Joint 3 Socket)
//   - parts_4: Tail segment 3 (Joint 3 Pin + Distal Tail Tip)
// ============================================================================

$fn = 72;

// Part selector:
//   0 = Full assembled model in neutral pose (model.stl)
//   1 = Fixed main body (parts_1.stl)
//   2 = Tail segment 1 (parts_2.stl)
//   3 = Tail segment 2 (parts_3.stl)
//   4 = Tail segment 3 (parts_4.stl)
part_select = 0;

// Optional joint angles (deg) for kinematic visualization
j1_angle = 0;
j2_angle = 0;
j3_angle = 0;

// Joint X-axis positions along Y = 0 (all axes parallel to Z-axis [0, 0, 1])
j1_x = 0.0;
j2_x = 14.0;
j3_x = 28.0;

// Joint heights (mm)
j1_h = 15.5;
j2_h = 14.5;
j3_h = 13.5;

// Pin & Bore radial parameters (mm)
// Cylindrical shaft single-sided radial clearance = 3.00 - 2.50 = 0.50 mm (within 0.4-0.6 mm)
// Conical retention rim single-sided radial clearance = 3.95 - 3.45 = 0.50 mm (within 0.4-0.6 mm)
r_pin        = 2.50;
r_hole       = 3.00;
r_flare_pin  = 3.45;
r_flare_hole = 3.95;
r_soc_outer  = 5.50;
r_seg_clear  = 6.10; // 0.60 mm radial clearance to outer socket wall (5.50 mm)

// Axial retention cone heights (mm)
// Cone slope = atan(1.80 / 0.95) = 62.2 deg from horizontal (27.8 deg overhang from vertical)
// Bore cones shifted axially by 0.25 mm so 3D normal distance on cones is 0.56 mm
h_bot_pin  = 0.55;
h_bot_bore = 0.80;
h_cone     = 1.80;
h_top_pin  = 0.85;
h_top_bore = 1.10;

// Neck & Window parameters
z_neck_top = 4.20;
z_win_flat = 4.80; // 0.60 mm axial clearance above neck
alpha_neck = 20.5; // +/- 20.5 deg neck half-angle
alpha_win  = 52.0; // +/- 52.0 deg window half-angle -> +/- 31.5 deg rotation clearance

// ============================================================================
// Core Joint Modules (Z-axis Revolute Pin Joint with Double-Conical Retention)
// ============================================================================

// Axisymmetric double-conical spool pin centered at (0, 0) from Z = 0 to h_j
module joint_pin(h_j) {
    rotate_extrude(angle = 360, $fn = 72) {
        polygon(points = [
            [0.0,         0.0],
            [r_flare_pin, 0.0],
            [r_flare_pin, h_bot_pin],
            [r_pin,       h_bot_pin + h_cone],
            [r_pin,       h_j - h_top_pin - h_cone],
            [r_flare_pin, h_j - h_top_pin],
            [r_flare_pin, h_j],
            [0.0,         h_j]
        ]);
    }
}

// Axisymmetric double-conical bore subtracted from parent socket at (0, 0)
module joint_bore_cut(h_j) {
    translate([0, 0, -0.05])
    rotate_extrude(angle = 360, $fn = 72) {
        polygon(points = [
            [0.0,          0.0],
            [r_flare_hole, 0.0],
            [r_flare_hole, 0.05 + h_bot_bore],
            [r_hole,       0.05 + h_bot_bore + h_cone],
            [r_hole,       0.05 + h_j - h_top_bore - h_cone],
            [r_flare_hole, 0.05 + h_j - h_top_bore],
            [r_flare_hole, 0.05 + h_j + 12.0],
            [0.0,          0.05 + h_j + 12.0]
        ]);
    }
}

// Self-supporting 60.0-deg V-arch window cutout on +X side of socket
// Opens +/- alpha_win (52 deg) from Z = 0 to z_win_flat (4.80 mm),
// then closes with exact 3D overhang slope = 60.0 deg above horizontal.
module socket_window_cut() {
    s_a = sin(alpha_win);
    c_a = cos(alpha_win);
    t_v = tan(60.0); // 60.0 deg above horizontal (30.0 deg from vertical)
    r_max = 7.5;
    x_max = r_max;
    y_max = r_max * (s_a / c_a);
    z_peak = z_win_flat + r_max * s_a * t_v;

    polyhedron(
        points = [
            [0.0,    0.0,   -0.1],        // 0: bottom apex
            [x_max, -y_max, -0.1],        // 1: bottom right
            [x_max,  y_max, -0.1],        // 2: bottom left
            [0.0,    0.0,    z_win_flat], // 3: mid apex at start of arch
            [x_max, -y_max,  z_win_flat], // 4: mid right
            [x_max,  y_max,  z_win_flat], // 5: mid left
            [x_max,  0.0,    z_peak]      // 6: top peak at x = x_max, y = 0
        ],
        faces = [
            [0, 2, 1],       // bottom face
            [0, 1, 4, 3],    // lower right wedge face
            [0, 3, 5, 2],    // lower left wedge face
            [1, 2, 5, 4],    // lower front face (x = x_max)
            [3, 4, 6],       // upper right 60-deg self-supporting roof face
            [3, 6, 5],       // upper left 60-deg self-supporting roof face
            [4, 5, 6]        // upper front face (x = x_max)
        ],
        convexity = 4
    );
}

// Connecting neck from pin (r = r_pin) to child segment body (r = r_seg_clear)
module joint_neck() {
    r_end = r_seg_clear + 1.2;
    y_end = r_end * tan(alpha_neck);
    linear_extrude(height = z_neck_top) {
        polygon(points = [
            [0.0,   0.0],
            [r_end, -y_end],
            [r_end,  y_end]
        ]);
    }
}

// Complete parent socket at local origin (0, 0, 0)
module joint_socket(h_j) {
    difference() {
        cylinder(h = h_j, r = r_soc_outer, $fn = 72);
        joint_bore_cut(h_j);
        socket_window_cut();
    }
}

// ============================================================================
// Self-Supporting Geometric Primitives (All Overhangs >= 62 deg from horizontal)
// ============================================================================

// Elliptical cylinder from Z = z_cyl to z_cyl + h_cyl with a 62-deg conical bottom
// tapering down toward Z = 0 (truncated at Z = 0 if it reaches the build plate).
module cone_section(x, y, z_cyl, rx, ry, h_cyl) {
    rmax = max(rx, ry);
    h_taper = rmax * tan(63.0);
    z_apex = z_cyl - h_taper;
    intersection() {
        translate([x - rx - 2, y - ry - 2, 0])
            cube([2*(rx + 2), 2*(ry + 2), z_cyl + h_cyl + 2]);
        translate([x, y, z_apex])
        scale([rx / rmax, ry / rmax, 1.0])
        rotate_extrude(angle = 360, $fn = 48) {
            polygon(points = [
                [0.0,  0.0],
                [rmax, h_taper],
                [rmax, h_taper + h_cyl],
                [0.0,  h_taper + h_cyl]
            ]);
        }
    }
}

// Self-supporting diamond/teardrop bump (for eyes and nostrils, >= 63 deg bottom cone)
module teardrop_bump(x, y, z, r, h_top) {
    h_bot = r * tan(63.0);
    translate([x, y, z])
    rotate_extrude(angle = 360, $fn = 32) {
        polygon(points = [
            [0.0, -h_bot],
            [r,    0.0],
            [0.0,  h_top]
        ]);
    }
}

// Self-supporting dorsal plate/ridge (buried base, all slopes >= 62 deg)
module dorsal_ridge(x_c, z_base, len_x, width_y, height_z) {
    translate([x_c, 0, z_base])
    hull() {
        translate([-len_x/2, -width_y/2, 0])
            cube([len_x, width_y, 0.2]);
        translate([-len_x*0.20, -0.5, height_z])
            cube([len_x*0.40, 1.0, 0.2]);
    }
}

// Single sturdy dinosaur leg with flat foot on Z = 0 and 3 cute toes
// All upward/inward slopes >= 63 deg above horizontal
module dino_leg(x_foot, y_foot, side_sign, h_hip) {
    hull() {
        // Flat foot pad on build plate Z = 0
        translate([x_foot, y_foot, 0])
            cylinder(h = 2.0, r = 4.5, $fn = 48);
        // Upper hip attachment merging into torso (dx=0.5, dy=4.0 over dz=15.0 -> 74 deg)
        cone_section(x_foot + 0.5, side_sign * 7.2, h_hip, 4.3, 4.3, 3.0);
    }
    // Three front-facing (-X) toes resting directly on build plate Z = 0
    for (ang = [-28, 0, 28]) {
        hull() {
            translate([x_foot - 3.6 * cos(ang), y_foot + 3.6 * sin(ang), 0])
                cylinder(h = 1.2, r = 1.5, $fn = 28);
            translate([x_foot - 2.0 * cos(ang), y_foot + 2.0 * sin(ang), 0])
                cylinder(h = 3.2, r = 1.2, $fn = 24);
        }
    }
}

// ============================================================================
// Part 1: Fixed Main Body (Head + Neck + Torso + 4 Legs + Joint 1 Socket)
// ============================================================================
module part_1_fixed_body() {
    difference() {
        union() {
            // 1. Joint 1 Socket outer cylinder at (j1_x, 0, 0) = (0, 0, 0)
            translate([j1_x, 0, 0])
                cylinder(h = j1_h, r = r_soc_outer, $fn = 72);

            // 2. Pelvis pedestal on Z = 0 connecting Joint 1 socket to rear hip
            hull() {
                translate([-2.5, 0, 0])
                    cylinder(h = j1_h, r = 3.8, $fn = 48);
                translate([-9.5, 0, 0])
                    scale([1.0, 1.30, 1.0])
                    cylinder(h = 21.0, r = 5.4, $fn = 48);
            }

            // 3. Front sternum/chest pedestal on Z = 0 between front legs
            // Provides rock-solid bed adhesion and 63-deg arches to belly & neck
            hull() {
                translate([-24.5, 0, 0])
                    scale([1.0, 1.20, 1.0])
                    cylinder(h = 23.0, r = 5.0, $fn = 48);
                translate([-19.5, 0, 0])
                    cylinder(h = 18.0, r = 3.6, $fn = 48);
            }

            // 4. Main Torso with 63-deg self-supporting gothic arch over mid-belly
            hull() {
                // Rear hip column on Z = 0
                translate([-9.5, 0, 0])
                    scale([1.0, 1.25, 1.0])
                    cylinder(h = 21.5, r = 5.2, $fn = 48);
                // Rear upper hip width (63-deg conical bottom buried in pelvis/legs)
                cone_section(-9.5, 0, 12.5, 6.0, 9.2, 9.0);
                // Mid torso ribcage (63-deg conical bottom rising from pelvis & chest pedestals)
                cone_section(-17.0, 0, 14.5, 6.5, 9.8, 8.5);
                // Front upper chest width (63-deg conical bottom buried in front legs/sternum)
                cone_section(-24.5, 0, 13.0, 6.0, 9.2, 10.0);
                // Front sternum column on Z = 0
                translate([-24.5, 0, 0])
                    scale([1.0, 1.15, 1.0])
                    cylinder(h = 23.0, r = 4.8, $fn = 48);
            }

            // 5. Four distinct sturdy legs resting flat on Z = 0
            // Rear Left & Right Legs (X = -9.5, Y = +/- 11.2)
            dino_leg(-9.5,  11.2,  1, 13.5);
            dino_leg(-9.5, -11.2, -1, 13.5);
            // Front Left & Right Legs (X = -24.5, Y = +/- 11.2)
            dino_leg(-24.5,  11.2,  1, 14.0);
            dino_leg(-24.5, -11.2, -1, 14.0);

            // 6. Transverse hip & shoulder bridges (all bottom cones >= 63 deg)
            hull() {
                cone_section(-9.5,  7.5, 11.0, 3.6, 3.6, 8.0);
                cone_section(-9.5, -7.5, 11.0, 3.6, 3.6, 8.0);
                translate([-9.5, 0, 0]) cylinder(h = 20.0, r = 4.8, $fn = 36);
            }
            hull() {
                cone_section(-24.5,  7.5, 11.5, 3.6, 3.6, 8.5);
                cone_section(-24.5, -7.5, 11.5, 3.6, 3.6, 8.5);
                translate([-24.5, 0, 0]) cylinder(h = 21.0, r = 4.8, $fn = 36);
            }

            // 7. Neck rising at 65 deg above horizontal from front chest pedestal
            hull() {
                cone_section(-24.5, 0, 14.0, 5.4, 6.6, 10.0);
                cone_section(-29.0, 0, 23.5, 5.0, 6.0, 10.5);
                cone_section(-33.0, 0, 32.0, 5.0, 5.8, 10.5);
            }

            // 8. Head, Cranium & Snout (all underside slopes >= 63 deg above horizontal)
            hull() {
                cone_section(-33.0, 0, 32.0, 5.2, 6.2, 11.0);
                cone_section(-35.5, 0, 37.0, 5.2, 6.4, 7.5);
                cone_section(-39.0, 0, 41.0, 3.8, 4.2, 4.0);
            }

            // 9. Self-supporting brow ridges / eyes & nostril bumps (>= 63 deg bottom cones)
            for (sy = [-1, 1]) {
                teardrop_bump(-35.2, sy * 5.6, 40.5, 1.8, 2.2);
                teardrop_bump(-38.8, sy * 2.5, 43.2, 1.0, 1.4);
            }

            // 10. Cute dorsal plates along head, neck, and back
            dorsal_ridge(-34.0, 44.0, 5.2, 2.4, 3.0);
            dorsal_ridge(-28.0, 31.0, 5.8, 2.8, 3.6);
            dorsal_ridge(-17.0, 22.5, 7.2, 3.2, 4.2);
            dorsal_ridge(-9.0,  21.0, 6.0, 2.8, 3.6);
        }

        // Ensure Joint 1 bore, window, and top above socket stay 100% clear
        translate([j1_x, 0, 0]) {
            joint_bore_cut(j1_h);
            socket_window_cut();
            // Clear everything above z = j1_h for x >= -r_soc_outer + 1.2 so socket top is flat
            translate([-r_flare_hole - 0.5, -10, j1_h])
                cube([20, 20, 20]);
            // Keep outer clearance zone on +X side of Joint 1 clean
            difference() {
                translate([0, -15, -0.1]) cube([15, 30, 35]);
                cylinder(h = j1_h, r = r_soc_outer, $fn = 72);
            }
        }
    }
}

// ============================================================================
// Tail Segment Body Helper (connects Joint at x_in to Socket at x_out)
// ============================================================================
module tail_segment_link(x_in, h_in, x_out, h_out, ridge_h) {
    seg_len = x_out - x_in;
    translate([x_in, 0, 0])
    union() {
        // 1. Pin at upstream joint (0, 0, 0)
        joint_pin(h_in);

        // 2. Neck connecting pin to segment body (Z = 0 .. z_neck_top)
        difference() {
            joint_neck();
            translate([seg_len, 0, 0])
                joint_bore_cut(h_out + 2.0);
        }

        // 3. Main segment body + downstream socket at (seg_len, 0, 0)
        difference() {
            union() {
                // Downstream socket cylinder
                translate([seg_len, 0, 0])
                    cylinder(h = h_out, r = r_soc_outer, $fn = 72);

                // Smooth body connecting clearance boundary (r = r_seg_clear) to downstream socket
                hull() {
                    intersection() {
                        cylinder(h = h_out, r = r_seg_clear + 1.6, $fn = 72);
                        linear_extrude(height = h_out) {
                            polygon(points = [
                                [0, 0],
                                [10, -10 * tan(alpha_neck)],
                                [10,  10 * tan(alpha_neck)]
                            ]);
                        }
                    }
                    translate([seg_len, 0, 0])
                        cylinder(h = h_out, r = r_soc_outer, $fn = 72);
                }

                // Cute dorsal ridge on middle of tail segment (strictly between joints)
                dorsal_ridge(seg_len * 0.54, h_out - 0.3, 3.8, 2.2, ridge_h);
            }

            // Maintain exact r_seg_clear (6.10 mm) concave clearance around upstream socket (5.50 mm)
            translate([0, 0, -0.1])
                cylinder(h = h_in + 10.0, r = r_seg_clear, $fn = 72);

            // Subtract downstream joint bore and self-supporting V-arch window
            translate([seg_len, 0, 0]) {
                joint_bore_cut(h_out);
                socket_window_cut();
                // Keep top of downstream socket flat above h_out
                translate([-r_flare_hole - 0.4, -10, h_out])
                    cube([20, 20, 15]);
            }
        }
    }
}

// ============================================================================
// Part 2: Tail Segment 1 (Joint 1 at X=0 to Joint 2 at X=14)
// ============================================================================
module part_2_tail_1() {
    tail_segment_link(j1_x, j1_h, j2_x, j2_h, 2.6);
}

// ============================================================================
// Part 3: Tail Segment 2 (Joint 2 at X=14 to Joint 3 at X=28)
// ============================================================================
module part_3_tail_2() {
    tail_segment_link(j2_x, j2_h, j3_x, j3_h, 2.4);
}

// ============================================================================
// Part 4: Tail Segment 3 (Joint 3 at X=28 to Tail Tip at X=43.5)
// ============================================================================
module part_4_tail_3() {
    tip_len = 15.5;
    translate([j3_x, 0, 0])
    union() {
        // 1. Pin at Joint 3 (0, 0, 0)
        joint_pin(j3_h);

        // 2. Neck connecting pin to tail tip body
        joint_neck();

        // 3. Tapering distal tail tip body on Z = 0
        difference() {
            union() {
                hull() {
                    intersection() {
                        cylinder(h = j3_h - 0.5, r = r_seg_clear + 1.5, $fn = 72);
                        linear_extrude(height = j3_h - 0.5) {
                            polygon(points = [
                                [0, 0],
                                [10, -10 * tan(alpha_neck)],
                                [10,  10 * tan(alpha_neck)]
                            ]);
                        }
                    }
                    translate([9.5, 0, 0])
                        cylinder(h = 9.5, r = 4.2, $fn = 48);
                    translate([tip_len - 2.0, 0, 0])
                        cylinder(h = 5.5, r = 2.0, $fn = 36);
                }
                // Cute tail-tip dorsal fin/crest
                dorsal_ridge(9.2, 9.2, 4.6, 2.0, 2.4);
            }

            // Maintain exact r_seg_clear (6.10 mm) concave clearance around Joint 3 socket (5.50 mm)
            translate([0, 0, -0.1])
                cylinder(h = j3_h + 10.0, r = r_seg_clear, $fn = 72);
        }
    }
}

// ============================================================================
// Kinematic Assembly & Part Rendering
// ============================================================================
module render_part_2_posed() {
    translate([j1_x, 0, 0])
    rotate([0, 0, j1_angle])
    translate([-j1_x, 0, 0])
        part_2_tail_1();
}

module render_part_3_posed() {
    translate([j1_x, 0, 0])
    rotate([0, 0, j1_angle])
    translate([-j1_x, 0, 0])
    translate([j2_x, 0, 0])
    rotate([0, 0, j2_angle])
    translate([-j2_x, 0, 0])
        part_3_tail_2();
}

module render_part_4_posed() {
    translate([j1_x, 0, 0])
    rotate([0, 0, j1_angle])
    translate([-j1_x, 0, 0])
    translate([j2_x, 0, 0])
    rotate([0, 0, j2_angle])
    translate([-j2_x, 0, 0])
    translate([j3_x, 0, 0])
    rotate([0, 0, j3_angle])
    translate([-j3_x, 0, 0])
        part_4_tail_3();
}

if (part_select == 1) {
    part_1_fixed_body();
} else if (part_select == 2) {
    render_part_2_posed();
} else if (part_select == 3) {
    render_part_3_posed();
} else if (part_select == 4) {
    render_part_4_posed();
} else {
    part_1_fixed_body();
    render_part_2_posed();
    render_part_3_posed();
    render_part_4_posed();
}
