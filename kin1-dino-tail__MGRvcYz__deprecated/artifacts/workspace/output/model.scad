// ============================================================================
// Print-in-Place Articulated Dinosaur Model for FDM 3D Printing
// Material: PLA | Nozzle: 0.4mm | Layer Height: 0.2mm
// Bounding Box: <= 100 x 50 x 60 mm (Actual: ~83.2 x 29.8 x 45.0 mm)
// Components:
//   part_id = 0 : Complete assembled model in neutral pose (model.stl)
//   part_id = 1 : Fixed Main Body - Head, Neck, Torso, 4 Legs (parts_1.stl)
//   part_id = 2 : Tail Segment 1 - Anterior tail section (parts_2.stl)
//   part_id = 3 : Tail Segment 2 - Middle tail section (parts_3.stl)
//   part_id = 4 : Tail Segment 3 - Posterior tail tip (parts_4.stl)
// Joints:
//   joint_1 : Z-axis revolute pin joint at (-5.0, 0, Z), range >= +/-30 deg
//   joint_2 : Z-axis revolute pin joint at (-18.0, 0, Z), range >= +/-30 deg
//   joint_3 : Z-axis revolute pin joint at (-31.0, 0, Z), range >= +/-30 deg
// ============================================================================

$fn = 48;

// Part selector (0 = all parts, 1 = body, 2 = tail_1, 3 = tail_2, 4 = tail_3)
part_id = 0;

// Optional pose angles (degrees) for visualization/kinematic testing
j1_angle = 0;
j2_angle = 0;
j3_angle = 0;

// Joint X coordinates along the central symmetry plane (Y = 0)
J1_X = -5.0;
J2_X = -18.0;
J3_X = -31.0;

// Joint Heights (mm)
J1_H = 17.0;
J2_H = 15.5;
J3_H = 14.0;

// Standardized Print-in-Place Pin Joint Clearances & Radii (mm)
R_PIN    = 2.10;  // Cylindrical pin shaft radius (diameter = 4.20 mm)
R_HOLE   = 2.60;  // Cylindrical bore hole radius (diameter = 5.20 mm)
                  // -> Single-side radial clearance = 0.50 mm (within 0.4-0.6 mm)
R_RING   = 4.50;  // Child knuckle outer ring radius (wall thickness = 1.90 mm)
C_OUTER  = 0.50;  // Outer radial clearance between knuckle ring and parent cavity
R_CAVITY = R_RING + C_OUTER; // 5.00 mm parent cavity radius
C_Z      = 0.55;  // Axial vertical clearance at horizontal/conical transitions
Z_BOT    = 1.80;  // Parent bottom clevis yoke thickness on build plate

// ============================================================================
// Reusable Z-Axis Captured Pin Joint Modules (Support-Free 60-deg Cones)
// ============================================================================

// Parent pin + retention collars + top/bottom clevis arms centered at (0,0,0)
module joint_parent_pin(h) {
    z_top_ring  = h - 3.60;
    z_cap_start = z_top_ring + C_Z;
    h_cap       = h - z_cap_start;

    union() {
        // 1. Coaxial vertical cylindrical pin shaft (Z = 0 to h)
        cylinder(h = h, r = R_PIN);

        // 2. Bottom axial retention collar (R = 3.20 mm > R_HOLE = 2.60 mm)
        //    Prevents child bore from disengaging in -Z direction.
        //    60-deg self-supporting taper from r = 3.20 mm to r = 2.10 mm.
        cylinder(h = 0.60, r = R_PIN + 1.10);
        translate([0, 0, 0.60])
            cylinder(h = 1.90, r1 = R_PIN + 1.10, r2 = R_PIN);

        // 3. Top axial retention cap (flares from R_PIN = 2.10 to 3.87 mm > R_HOLE = 2.60 mm)
        //    Prevents child bore from disengaging in +Z direction.
        translate([0, 0, z_cap_start])
            cylinder(h = h_cap, r1 = R_PIN, r2 = R_PIN + h_cap * 0.58);

        // 4. Bottom clevis yoke arm on +X side (Z = 0 to Z_BOT, +/-17 deg sector)
        linear_extrude(height = Z_BOT)
            polygon(points = [
                [0, 0],
                [R_CAVITY + 2.5, -(R_CAVITY + 2.5) * tan(17)],
                [R_CAVITY + 2.5,  (R_CAVITY + 2.5) * tan(17)]
            ]);
    }
}

// Cavity subtracted from the parent body around (0,0,0) to house the child knuckle
module joint_parent_cavity(h) {
    z_top_ring  = h - 3.60;
    z_cap_start = z_top_ring + C_Z;
    h_cap       = h - z_cap_start;

    union() {
        // 1. Main cylindrical cavity for child knuckle ring (r = 5.00 mm)
        translate([0, 0, -0.10])
            cylinder(h = z_cap_start + 0.11, r = R_CAVITY);

        // 2. Self-supporting 60-deg conical roof tapering inward to merge with top pin cap
        translate([0, 0, z_cap_start])
            cylinder(h = h_cap + 0.05, r1 = R_CAVITY, r2 = R_CAVITY - h_cap * 0.58);

        // 3. Rear angular clearance sector (+/-78 deg around -X axis) so child neck
        //    can swing >= +/-30 deg around Z-axis without wall collision
        translate([0, 0, -0.10])
            linear_extrude(height = h + 0.20)
                polygon(points = [
                    [0, 0],
                    [-12.0, -12.0 * tan(78)],
                    [-12.0,  12.0 * tan(78)]
                ]);
    }
}

// Child knuckle ring outer solid centered at (0,0,0) before bore subtraction
module joint_child_knuckle_Blank(h) {
    z_top_ring = h - 3.60;
    cylinder(h = z_top_ring, r = R_RING);
}

// Bore hole and self-supporting clevis arch cutout subtracted from child knuckle at (0,0,0)
module joint_child_cuts(h) {
    z_arch_start = Z_BOT + C_Z; // 2.35 mm
    z_top_ring   = h - 3.60;

    union() {
        // 1. Precision coaxial cylindrical bore hole (r = 2.60 mm, 0.50 mm radial gap to pin)
        translate([0, 0, -0.10])
            cylinder(h = h + 0.20, r = R_HOLE);

        // 2. Matching bottom conical bore clearance (r = 3.70 -> 2.60 mm, 0.50 mm radial gap)
        translate([0, 0, -0.05])
            cylinder(h = 1.19, r = R_HOLE + 1.10);
        translate([0, 0, 1.14])
            cylinder(h = 1.90, r1 = R_HOLE + 1.10, r2 = R_HOLE);

        // 3. +X lower sector cutout (+/-50 deg) for parent bottom clevis + +/-30 deg rotation,
        //    closing into a full 360-deg ring via a self-supporting >58-deg sloped arch!
        hull() {
            translate([0, 0, -0.10])
                linear_extrude(height = z_arch_start + 0.10)
                    polygon(points = [
                        [0, 0],
                        [4.80, -4.80 * tan(50)],
                        [4.80,  4.80 * tan(50)]
                    ]);
            translate([4.80, 0, z_arch_start + 4.80 * 1.55])
                cube([0.04, 0.04, 0.04], center = true);
        }

        // 4. Flat top clearance above z_top_ring
        translate([0, 0, z_top_ring])
            cylinder(h = h, r = R_RING + 0.20);
    }
}

// ============================================================================
// Part 1: Fixed Main Body (Head, Neck, Torso, 4 Legs, Joint 1 Parent Pin)
// ============================================================================

module dino_foot(x_c, y_c, r_foot) {
    // Flat-bottomed foot pad + 3 sculpted forward-pointing toes on Z = 0
    hull() {
        translate([x_c, y_c, 0])
            cylinder(h = 2.4, r1 = r_foot, r2 = r_foot - 0.5);
        translate([x_c + 2.2, y_c, 0])
            cylinder(h = 1.8, r1 = r_foot * 0.75, r2 = r_foot * 0.55);
    }
    for (ang = [-28, 0, 28]) {
        hull() {
            translate([x_c + 1.5, y_c, 0])
                cylinder(h = 1.8, r1 = 1.3, r2 = 0.9);
            translate([x_c + 1.5 + 3.2 * cos(ang), y_c + 3.2 * sin(ang), 0])
                cylinder(h = 1.2, r1 = 1.1, r2 = 0.6);
        }
    }
}

module dino_leg_pair(x_foot, y_foot, r_foot, x_hip, y_hip, z_hip, r_hip) {
    for (side = [-1, 1]) {
        // Foot on build plate Z = 0
        dino_foot(x_foot, side * y_foot, r_foot);

        // Lower-to-upper leg column (self-supporting ~70 deg slope from horizontal)
        hull() {
            translate([x_foot, side * y_foot, 0])
                cylinder(h = 2.0, r = r_foot);
            translate([x_foot - 0.3, side * (y_foot - 1.5), 7.5])
                cylinder(h = 2.0, r = r_foot * 0.92);
            translate([x_hip, side * y_hip, z_hip])
                cylinder(h = 3.0, r = r_hip);
        }
    }
}

module part_1_main_body() {
    union() {
        // A. Torso + Pelvis housing with Joint 1 cavity removed
        difference() {
            union() {
                // 1. Pelvis / tail-base block around Joint 1 (X = -5.0 to +4.0)
                hull() {
                    translate([J1_X + 2.0, 0, 0])
                        cylinder(h = J1_H, r = 6.2);
                    translate([3.5, 0, 0])
                        scale([1.0, 1.12, 1.0])
                            cylinder(h = J1_H + 2.0, r = 6.8);
                }

                // 2. Central Torso (sits on Z = 0 via a sturdy keel base and flares out at 62 deg)
                hull() {
                    // Build plate keel base (Z = 0, Y in [-4.5, +4.5])
                    translate([2.0, -4.4, 0])
                        cube([21.5, 8.8, 1.0]);
                    // Mid-torso full width at Z = 9.0 to 21.0 (slope = 9.0 / 4.1 = 65.5 deg!)
                    translate([4.5, 0, 9.0])
                        scale([1.0, 1.25, 1.0])
                            cylinder(h = 11.5, r = 6.8);
                    translate([20.5, 0, 9.5])
                        scale([1.0, 1.20, 1.0])
                            cylinder(h = 12.0, r = 6.6);
                    // Tapered dorsal back ridge
                    translate([6.0, 0, 20.5])
                        cylinder(h = 3.0, r1 = 4.5, r2 = 2.2);
                    translate([19.5, 0, 21.5])
                        cylinder(h = 3.0, r1 = 4.5, r2 = 2.4);
                }

                // 3. Four Legs (Hind pair at X = +4.5, Front pair at X = +21.5)
                dino_leg_pair(x_foot = 4.5,  y_foot = 11.0, r_foot = 3.6,
                              x_hip  = 4.5,  y_hip  = 6.8,  z_hip  = 11.5, r_hip = 4.2);
                dino_leg_pair(x_foot = 21.5, y_foot = 10.2, r_foot = 3.4,
                              x_hip  = 20.5, y_hip  = 6.4,  z_hip  = 11.5, r_hip = 4.0);

                // 4. Neck (rising at >= 62 deg above horizontal from chest to head)
                hull() {
                    translate([19.5, 0, 10.0])
                        scale([1.0, 1.05, 1.0])
                            cylinder(h = 12.5, r = 5.8);
                    translate([25.5, 0, 21.5])
                        cylinder(h = 10.5, r = 5.0);
                    translate([28.5, 0, 28.0])
                        cylinder(h = 9.0, r = 4.4);
                }

                // 5. Head, Snout & Brow Ridges (all undersides sloped at >= 61 deg from horizontal)
                hull() {
                    // Neck-to-head base
                    translate([26.5, 0, 24.0])
                        cylinder(h = 12.0, r = 4.8);
                    // Upper cranium
                    translate([29.0, 0, 31.0])
                        scale([1.0, 1.12, 1.0])
                            cylinder(h = 10.5, r = 4.8);
                    // Snout bridge & tip (sloping up from X=29,Z=24 to X=37.2,Z=37.5 -> 58.7 deg!)
                    translate([35.5, 0, 35.0])
                        scale([1.15, 0.85, 1.0])
                            cylinder(h = 5.2, r1 = 3.2, r2 = 2.2);
                    // Crown crest
                    translate([27.5, 0, 41.5])
                        cylinder(h = 3.5, r1 = 3.4, r2 = 1.4);
                }

                // 6. Sculpted Supraorbital Eye Ridges / Eyes (left & right on head, 65-deg base slope)
                for (side = [-1, 1]) {
                    hull() {
                        translate([29.5, side * 3.8, 33.0])
                            cylinder(h = 1.0, r = 1.2);
                        translate([30.2, side * 5.0, 36.5])
                            cylinder(h = 3.2, r1 = 1.8, r2 = 1.0);
                        translate([28.5, side * 4.2, 39.5])
                            cylinder(h = 1.5, r1 = 1.2, r2 = 0.6);
                    }
                }

                // 7. Dorsal Spines along Back and Neck (characteristic dinosaur plates)
                // Spine 1 (Pelvis/lumbar)
                hull() {
                    translate([-0.5, -1.6, 15.0])
                        cube([5.5, 3.2, 2.0]);
                    translate([1.5, -0.8, 22.5])
                        cube([2.5, 1.6, 1.0]);
                }
                // Spine 2 (Mid-back)
                hull() {
                    translate([7.5, -1.8, 19.5])
                        cube([6.0, 3.6, 2.0]);
                    translate([9.5, -0.9, 26.5])
                        cube([2.8, 1.8, 1.0]);
                }
                // Spine 3 (Shoulders)
                hull() {
                    translate([15.5, -1.8, 20.5])
                        cube([6.0, 3.6, 2.0]);
                    translate([17.5, -0.9, 28.0])
                        cube([2.8, 1.8, 1.0]);
                }
                // Spine 4 (Neck)
                hull() {
                    translate([22.0, -1.5, 26.0])
                        cube([4.5, 3.0, 4.0]);
                    translate([23.0, -0.8, 34.5])
                        cube([2.2, 1.6, 1.5]);
                }
            }

            // Subtract Joint 1 parent cavity at (J1_X, 0, 0)
            translate([J1_X, 0, 0])
                joint_parent_cavity(J1_H);
        }

        // B. Add Joint 1 parent pin + retention collars + bottom clevis at (J1_X, 0, 0)
        translate([J1_X, 0, 0])
            joint_parent_pin(J1_H);
    }
}

// ============================================================================
// Part 2: Tail Segment 1 (Connects Joint 1 at X=-5.0 to Joint 2 at X=-18.0)
// ============================================================================

module part_2_tail_1() {
    union() {
        difference() {
            union() {
                // 1. Child knuckle ring at Joint 1 (X = -5.0)
                translate([J1_X, 0, 0])
                    joint_child_knuckle_Blank(J1_H);

                // 2. Segment 1 body bridging from Joint 1 ring to Joint 2 parent housing
                hull() {
                    translate([J1_X - 3.2, -3.1, 0])
                        cube([1.5, 6.2, J1_H - 3.6]);
                    translate([J2_X + 2.0, 0, 0])
                        cylinder(h = J2_H, r = 5.7);
                }

                // 3. Dorsal tail spine on Segment 1
                hull() {
                    translate([J1_X - 9.5, -1.5, J2_H - 1.5])
                        cube([5.2, 3.0, 1.5]);
                    translate([J1_X - 8.0, -0.7, J1_H + 3.0])
                        cube([2.4, 1.4, 1.0]);
                }
            }

            // Subtract Joint 1 child bore & self-supporting arch cutout
            translate([J1_X, 0, 0])
                joint_child_cuts(J1_H);

            // Subtract Joint 2 parent cavity at (J2_X, 0, 0)
            translate([J2_X, 0, 0])
                joint_parent_cavity(J2_H);
        }

        // Add Joint 2 parent pin + retention collars + bottom clevis at (J2_X, 0, 0)
        translate([J2_X, 0, 0])
            joint_parent_pin(J2_H);
    }
}

// ============================================================================
// Part 3: Tail Segment 2 (Connects Joint 2 at X=-18.0 to Joint 3 at X=-31.0)
// ============================================================================

module part_3_tail_2() {
    union() {
        difference() {
            union() {
                // 1. Child knuckle ring at Joint 2 (X = -18.0)
                translate([J2_X, 0, 0])
                    joint_child_knuckle_Blank(J2_H);

                // 2. Segment 2 body bridging from Joint 2 ring to Joint 3 parent housing
                hull() {
                    translate([J2_X - 3.2, -3.0, 0])
                        cube([1.5, 6.0, J2_H - 3.6]);
                    translate([J3_X + 2.0, 0, 0])
                        cylinder(h = J3_H, r = 5.5);
                }

                // 3. Dorsal tail spine on Segment 2
                hull() {
                    translate([J2_X - 9.5, -1.4, J3_H - 1.5])
                        cube([5.0, 2.8, 1.5]);
                    translate([J2_X - 8.0, -0.7, J2_H + 2.5])
                        cube([2.2, 1.4, 1.0]);
                }
            }

            // Subtract Joint 2 child bore & self-supporting arch cutout
            translate([J2_X, 0, 0])
                joint_child_cuts(J2_H);

            // Subtract Joint 3 parent cavity at (J3_X, 0, 0)
            translate([J3_X, 0, 0])
                joint_parent_cavity(J3_H);
        }

        // Add Joint 3 parent pin + retention collars + bottom clevis at (J3_X, 0, 0)
        translate([J3_X, 0, 0])
            joint_parent_pin(J3_H);
    }
}

// ============================================================================
// Part 4: Tail Segment 3 (Connects Joint 3 at X=-31.0 to Tail Tip at X=-45.0)
// ============================================================================

module part_4_tail_3() {
    difference() {
        union() {
            // 1. Child knuckle ring at Joint 3 (X = -31.0)
            translate([J3_X, 0, 0])
                joint_child_knuckle_Blank(J3_H);

            // 2. Tapered tail tip resting flat on Z = 0 out to X = -45.0
            hull() {
                translate([J3_X - 3.2, -2.9, 0])
                    cube([1.5, 5.8, J3_H - 3.6]);
                translate([J3_X - 8.5, 0, 0])
                    cylinder(h = 8.5, r1 = 2.8, r2 = 1.6);
                translate([J3_X - 13.0, 0, 0])
                    cylinder(h = 4.5, r1 = 1.4, r2 = 0.7);
            }

            // 3. Dorsal tail spine on Segment 3
            hull() {
                translate([J3_X - 9.5, -1.2, 6.5])
                    cube([5.5, 2.4, 2.0]);
                translate([J3_X - 7.5, -0.6, J3_H + 1.5])
                    cube([2.2, 1.2, 1.0]);
            }
        }

        // Subtract Joint 3 child bore & self-supporting arch cutout
        translate([J3_X, 0, 0])
            joint_child_cuts(J3_H);
    }
}

// ============================================================================
// Top-Level Assembly & Kinematic Hierarchy
// ============================================================================

module render_dinosaur() {
    if (part_id == 1) {
        part_1_main_body();
    } else if (part_id == 2) {
        translate([J1_X, 0, 0])
            rotate([0, 0, j1_angle])
                translate([-J1_X, 0, 0])
                    part_2_tail_1();
    } else if (part_id == 3) {
        translate([J1_X, 0, 0])
            rotate([0, 0, j1_angle])
                translate([J2_X - J1_X, 0, 0])
                    rotate([0, 0, j2_angle])
                        translate([-J2_X, 0, 0])
                            part_3_tail_2();
    } else if (part_id == 4) {
        translate([J1_X, 0, 0])
            rotate([0, 0, j1_angle])
                translate([J2_X - J1_X, 0, 0])
                    rotate([0, 0, j2_angle])
                        translate([J3_X - J2_X, 0, 0])
                            rotate([0, 0, j3_angle])
                                translate([-J3_X, 0, 0])
                                    part_4_tail_3();
    } else {
        // Complete assembly (part_id == 0)
        part_1_main_body();
        translate([J1_X, 0, 0])
            rotate([0, 0, j1_angle])
                translate([-J1_X, 0, 0]) {
                    part_2_tail_1();
                    translate([J2_X, 0, 0])
                        rotate([0, 0, j2_angle])
                            translate([-J2_X, 0, 0]) {
                                part_3_tail_2();
                                translate([J3_X, 0, 0])
                                    rotate([0, 0, j3_angle])
                                        translate([-J3_X, 0, 0])
                                            part_4_tail_3();
                            }
                }
    }
}

render_dinosaur();
