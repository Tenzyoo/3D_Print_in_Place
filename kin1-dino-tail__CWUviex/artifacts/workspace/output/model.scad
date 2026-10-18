// ============================================================================
// Print-in-Place Articulated Small Dinosaur Model (OpenSCAD)
// Process: FDM 3D Printing (PLA, 0.4 mm nozzle, 0.2 mm layer height)
// Overall Bounding Box: 92.7 x 34.0 x 54.5 mm (<= 100 x 50 x 60 mm)
// Structure:
//   - parts_1 (Fixed Main Body): Head, Neck, Torso, Four Legs, Joint 1 Pin
//   - parts_2 (Tail Segment 1): Joint 1 Bore Housing, Segment 1 Body, Joint 2 Pin
//   - parts_3 (Tail Segment 2): Joint 2 Bore Housing, Segment 2 Body, Joint 3 Pin
//   - parts_4 (Tail Segment 3): Joint 3 Bore Housing, Tapered Tail Tip
// Joints:
//   - 3 Z-axis rotational pin joints at (-4.0, 0), (-19.5, 0), (-34.0, 0)
//   - Single-side radial clearance between cylindrical pin and bore: 0.50 mm
//   - Bidirectional (+Z / -Z) conical axial retention structures (51.1 deg slope)
//   - 100% self-supporting geometry (zero support material required)
// ============================================================================

$fn = 64;

// Render selector:
//   0 = Complete neutral-pose assembly (model.stl)
//   1 = Fixed main body (parts/parts_1.stl)
//   2 = Tail segment 1 (parts/parts_2.stl)
//   3 = Tail segment 2 (parts/parts_3.stl)
//   4 = Tail segment 3 (parts/parts_4.stl)
part_select = 0;

// Joint X coordinates along Y = 0 centerline, heights, and pin shaft radii
J1_X = -4.0;   J1_H = 19.5;  J1_RPIN = 2.6;
J2_X = -19.5;  J2_H = 17.5;  J2_RPIN = 2.4;
J3_X = -34.0;  J3_H = 15.5;  J3_RPIN = 2.2;

// Clearance and retention parameters
C_RAD     = 0.50;  // Single-side radial clearance on cylindrical pin/bore (0.4 - 0.6 mm)
DR_FLANGE = 1.25;  // Conical axial retention radial flare (mm)
DZ_CONE   = 1.55;  // Conical axial retention vertical height (slope = 51.1 deg from horizontal)
DZ_OFF    = 0.20;  // Vertical offset on bore cones for >= 0.50 mm 3D normal clearance

// Derived joint dimensions
function r_bore(r_pin)        = r_pin + C_RAD;
function r_flange(r_pin)      = r_pin + DR_FLANGE;
function r_bore_flange(r_pin) = r_bore(r_pin) + DR_FLANGE;
function r_ring(r_pin)        = r_bore(r_pin) + 2.2;
function r_body_cut(r_pin)    = r_ring(r_pin) + 0.50;

function bridge_x1(r_pin)    = r_pin - 0.8;
function bridge_z1(H)        = H - 3.0;
function bridge_x2(r_pin)    = r_body_cut(r_pin) + 0.1;
function bridge_z2(H, r_pin) = bridge_z1(H) - 1.25 * (bridge_x2(r_pin) - bridge_x1(r_pin));

function z_ring_outer(H, r_pin) = bridge_z2(H, r_pin) + 1.25 * (bridge_x2(r_pin) - r_ring(r_pin)) - 0.76;
function z_ring_inner(H, r_pin) = bridge_z2(H, r_pin) + 1.25 * (bridge_x2(r_pin) - r_bore_flange(r_pin)) - 0.76;

function z_bot_flat()           = 1.2;
function z_cyl_bot()            = z_bot_flat() + DZ_CONE;
function z_cap_bot(H, r_pin)    = z_ring_inner(H, r_pin) + 0.55;
function z_cyl_top(H, r_pin)    = z_cap_bot(H, r_pin) - DZ_CONE;

// Helper module: vertical cylinder topped with a smooth rounded frustum crown (zero overhang)
module domed_cylinder(h_total, r, h_dome) {
    h_cyl = max(0.2, h_total - h_dome);
    cylinder(h = h_cyl, r = r);
    translate([0, 0, h_cyl])
        cylinder(h = h_dome * 0.60, r1 = r, r2 = r * 0.76);
    translate([0, 0, h_cyl + h_dome * 0.60])
        cylinder(h = h_dome * 0.40, r1 = r * 0.76, r2 = r * 0.36);
}

// 1. Upstream Pin + Self-Supporting Top Bridge at Joint (centered at origin, upstream on +X)
module joint_pin_and_bridge(H, r_pin) {
    rf   = r_flange(r_pin);
    zb   = z_bot_flat();
    zcb  = z_cyl_bot();
    zct  = z_cyl_top(H, r_pin);
    zcap = z_cap_bot(H, r_pin);
    x1   = bridge_x1(r_pin);
    z1   = bridge_z1(H);
    x2   = bridge_x2(r_pin);
    z2   = bridge_z2(H, r_pin);
    wb   = r_pin - 0.35;

    union() {
        // Central Z-axis Pin with bottom & top conical axial retention flanges
        cylinder(h = zb + 0.01, r = rf);
        translate([0, 0, zb])  cylinder(h = DZ_CONE + 0.01, r1 = rf, r2 = r_pin);
        translate([0, 0, zcb]) cylinder(h = zct - zcb + 0.01, r = r_pin);
        translate([0, 0, zct]) cylinder(h = DZ_CONE + 0.01, r1 = r_pin, r2 = rf);
        translate([0, 0, zcap]) cylinder(h = H - zcap, r = rf);

        // Self-supporting 51.3-deg top bridge connecting upstream body (+X) to pin top cap
        hull() {
            translate([x1, -wb, z1]) cube([1.0, 2 * wb, H - z1]);
            translate([x2, -wb, z2]) cube([1.6, 2 * wb, H - z2]);
        }
    }
}

// Cylindrical + angular sector cutout subtracted from upstream body at Joint
module joint_upstream_cutout(H, r_pin) {
    rcut = r_body_cut(r_pin);
    translate([0, 0, -0.1]) cylinder(h = H + 12.0, r = rcut);
    translate([0, 0, -0.1])
    linear_extrude(height = H + 12.0)
        polygon(points = [
            [0, 0],
            [-2.8,  11.5],
            [-16.0, 11.5],
            [-16.0, -11.5],
            [-2.8, -11.5]
        ]);
}

// 2. Downstream Bore Ring + Smooth Top Ramp Solid (before bore subtraction)
module joint_bore_housing_solid(H, r_pin) {
    rr  = r_ring(r_pin);
    rbf = r_bore_flange(r_pin);
    zro = z_ring_outer(H, r_pin);
    zri = z_ring_inner(H, r_pin);
    wb  = r_pin - 0.35;

    union() {
        // 360-deg Bore Ring around pin
        cylinder(h = zro + 0.01, r = rr);
        translate([0, 0, zro]) cylinder(h = zri - zro, r1 = rr, r2 = rbf);

        // Self-supporting ramp on -X connecting Bore Ring to segment top
        hull() {
            translate([-rr + 0.1, -wb, 0]) cube([1.0, 2 * wb, zro]);
            translate([-rr - 1.8, -wb, 0]) cube([1.4, 2 * wb, H]);
        }
    }
}

// Coaxial Bore cutout subtracted from downstream segment at Joint
module joint_bore_cutout(H, r_pin) {
    rb   = r_bore(r_pin);
    rbf  = r_bore_flange(r_pin);
    zb   = z_bot_flat();
    zcb  = z_cyl_bot();
    zct  = z_cyl_top(H, r_pin);
    zcap = z_cap_bot(H, r_pin);

    union() {
        translate([0, 0, -0.1])          cylinder(h = zb + DZ_OFF + 0.11, r = rbf);
        translate([0, 0, zb + DZ_OFF])   cylinder(h = DZ_CONE + 0.01, r1 = rbf, r2 = rb);
        translate([0, 0, zcb + DZ_OFF])  cylinder(h = zct - zcb - 2 * DZ_OFF + 0.01, r = rb);
        translate([0, 0, zct - DZ_OFF])  cylinder(h = DZ_CONE + 0.01, r1 = rb, r2 = rbf);
        translate([0, 0, zcap - DZ_OFF]) cylinder(h = H - zcap + 12.0, r = rbf);
    }
}

// Self-supporting dorsal spine / back plate (all overhangs >= 55 deg from horizontal)
module dorsal_plate(x_center, z_base, length_x, width_y, height_z) {
    hull() {
        translate([x_center - length_x/2, -width_y/2, z_base])
            cube([length_x, width_y, 0.5]);
        translate([x_center - length_x*0.16, -0.5, z_base + height_z])
            cube([length_x*0.32, 1.0, 0.5]);
    }
}

// Sculpted Dinosaur Leg (flat foot on Z=0 with 3 toes, muscular leg rising into torso)
module dino_leg(x_foot, y_foot, x_hip, y_hip, r_foot, r_hip, h_hip) {
    side = (y_foot > 0) ? 1 : -1;
    union() {
        // Main leg column from flat foot on build plate (Z=0) to hip with rounded shoulder/hip dome
        hull() {
            translate([x_foot, y_foot, 0]) cylinder(h = 2.0, r = r_foot);
            translate([x_hip, y_hip, 0]) domed_cylinder(h_hip + 3.5, r_hip, 3.0);
        }
        // 3 sculpted toes at front/side of foot on Z=0
        for (ang = [-24, 0, 24]) {
            hull() {
                translate([x_foot + (r_foot - 0.6) * cos(ang), y_foot + side * 0.7 + (r_foot - 0.6) * sin(ang), 0])
                    domed_cylinder(2.2, 1.65, 1.0);
                translate([x_foot, y_foot, 0])
                    cylinder(h = 4.5, r = 2.2);
            }
        }
    }
}

// ============================================================================
// PART 1: FIXED MAIN BODY (Head + Neck + Torso + 4 Legs + Joint 1 Pin)
// ============================================================================
module part_1_body() {
    union() {
        difference() {
            union() {
                // 1. Four Sturdy Muscular Legs on Z=0
                // Rear Left & Right Legs
                dino_leg(5.5,  11.8, 5.2,  8.0, 5.2, 5.8, 17.5);
                dino_leg(5.5, -11.8, 5.2, -8.0, 5.2, 5.8, 17.5);
                // Front Left & Right Legs
                dino_leg(22.0,  11.2, 20.5,  7.5, 5.0, 5.5, 18.5);
                dino_leg(22.0, -11.2, 20.5, -7.5, 5.0, 5.5, 18.5);

                // 2. Plump Rounded Torso & Self-Supporting Belly Keel
                hull() {
                    // Smooth tail-base transition into Joint 1 at X = -4.0
                    translate([-1.5, 0, 0]) cylinder(h = J1_H, r = r_body_cut(J1_RPIN) + 0.2);
                    translate([5.0, 0, 0]) domed_cylinder(24.5, 6.2, 3.5);
                    translate([5.5,  7.2, 12.0]) domed_cylinder(12.5, 5.5, 3.0);
                    translate([5.5, -7.2, 12.0]) domed_cylinder(12.5, 5.5, 3.0);
                    // Central belly keel on Z=0
                    translate([13.5, 0, 0]) cylinder(h = 25.0, r = 4.6);
                    // Plump rounded ribcage & back dome
                    translate([13.5, 0, 14.5]) domed_cylinder(14.5, 9.8, 4.5);
                    // Front chest & shoulders
                    translate([20.5, 0, 0]) domed_cylinder(26.5, 5.8, 3.5);
                    translate([20.5,  6.5, 11.5]) domed_cylinder(14.5, 5.2, 3.0);
                    translate([20.5, -6.5, 11.5]) domed_cylinder(14.5, 5.2, 3.0);
                }

                // 3. Graceful Sculpted Neck rising at 58 deg from Chest to Head
                hull() {
                    translate([20.5, 0, 0]) cylinder(h = 26.5, r = 5.6);
                    translate([20.5, 0, 12.0]) domed_cylinder(16.0, 7.2, 3.0);
                    translate([26.5, 0, 22.0]) domed_cylinder(15.5, 6.0, 3.0);
                    translate([31.5, 0, 31.5]) domed_cylinder(13.5, 5.2, 2.5);
                }

                // 4. Sculpted Dinosaur Head (Rounded Cranium, Snout, Crown Crest, Eyes & Nostrils)
                hull() {
                    translate([31.5, 0, 31.5]) domed_cylinder(16.5, 5.2, 3.0);
                    translate([34.0, 0, 35.5]) domed_cylinder(16.5, 6.1, 3.5);
                    // Rounded Snout Muzzle (56-deg self-supporting lower jaw)
                    translate([40.8, 0, 43.2]) domed_cylinder(7.2, 3.9, 2.2);
                }
                // Brachiosaurus Crown Crest (smooth domed crest at top of head)
                hull() {
                    translate([32.0, 0, 42.0]) domed_cylinder(11.5, 5.0, 3.0);
                    translate([34.8, 0, 44.0]) domed_cylinder(10.5, 4.6, 2.8);
                    translate([30.5, 0, 47.0]) domed_cylinder(7.5, 3.2, 2.0);
                }
                // Sculpted Eyes & Brow Ridges on Left & Right of Head
                hull() {
                    translate([34.8,  5.1, 44.2]) domed_cylinder(3.6, 1.65, 1.2);
                    translate([34.2,  3.0, 39.5]) domed_cylinder(8.8, 1.9, 1.2);
                }
                hull() {
                    translate([34.8, -5.1, 44.2]) domed_cylinder(3.6, 1.65, 1.2);
                    translate([34.2, -3.0, 39.5]) domed_cylinder(8.8, 1.9, 1.2);
                }
                // Sculpted Nostril Bulges on Snout
                hull() {
                    translate([39.8,  1.8, 46.5]) domed_cylinder(4.2, 1.5, 1.0);
                    translate([41.6,  1.5, 46.5]) domed_cylinder(3.6, 1.2, 0.8);
                }
                hull() {
                    translate([39.8, -1.8, 46.5]) domed_cylinder(4.2, 1.5, 1.0);
                    translate([41.6, -1.5, 46.5]) domed_cylinder(3.6, 1.2, 0.8);
                }

                // 5. Dorsal Back Plates along Torso & Neck
                dorsal_plate(4.5,  22.5, 5.5, 2.8, 4.5);
                dorsal_plate(12.0, 27.5, 6.5, 3.2, 5.2);
                dorsal_plate(19.2, 26.8, 5.8, 3.0, 4.8);
                dorsal_plate(25.8, 35.5, 5.0, 2.5, 4.0);
            }

            // Subtract Joint 1 upstream keepout at (J1_X, 0)
            translate([J1_X, 0, 0]) joint_upstream_cutout(J1_H, J1_RPIN);

            // Subtract shallow Nostril dimples on top of snout (vertical, zero overhang)
            translate([41.2,  1.6, 49.3]) cylinder(h = 2.0, r1 = 0.4, r2 = 0.85);
            translate([41.2, -1.6, 49.3]) cylinder(h = 2.0, r1 = 0.4, r2 = 0.85);
        }

        // Add Joint 1 Pin & Self-Supporting Top Bridge at (J1_X, 0)
        translate([J1_X, 0, 0]) joint_pin_and_bridge(J1_H, J1_RPIN);
    }
}

// ============================================================================
// PART 2: TAIL SEGMENT 1 (Joint 1 Bore -> Segment 1 Body -> Joint 2 Pin)
// ============================================================================
module part_2_tail_1() {
    zro1  = z_ring_outer(J1_H, J1_RPIN);
    rr1   = r_ring(J1_RPIN);
    rcut2 = r_body_cut(J2_RPIN);

    union() {
        difference() {
            union() {
                // 1. Anterior Bore Ring + Ramp at Joint 1 (J1_X = -4.0)
                translate([J1_X, 0, 0]) joint_bore_housing_solid(J1_H, J1_RPIN);

                // 2. Smooth Continuous Lower Tail Body (merges seamlessly with Bore Ring up to z = zro1)
                hull() {
                    translate([J1_X - 2.0, 0, 0]) cylinder(h = zro1, r = rr1 - 0.3);
                    translate([(J1_X + J2_X)/2, 0, 0]) cylinder(h = zro1, r = rr1 - 0.1);
                    translate([J2_X + 2.5, 0, 0]) cylinder(h = zro1, r = rcut2 + 0.1);
                }

                // 3. Smooth Continuous Full-Height Tail Body
                hull() {
                    translate([J1_X - rr1 - 1.6, 0, 0]) cylinder(h = J1_H, r = 3.5);
                    translate([(J1_X + J2_X)/2 - 0.5, 0, 0]) cylinder(h = (J1_H + J2_H)/2 + 0.5, r = 4.9);
                    translate([J2_X + 2.8, 0, 0]) cylinder(h = J2_H, r = rcut2 + 0.1);
                    translate([J1_X - 2.8, 0, 0]) cylinder(h = zro1, r = 4.5);
                }

                // 4. Dorsal Spine on Tail Segment 1
                dorsal_plate((J1_X + J2_X)/2 - 1.2, (J1_H + J2_H)/2, 5.8, 2.8, 4.2);
            }

            // Subtract Joint 1 Bore at (J1_X, 0)
            translate([J1_X, 0, 0]) joint_bore_cutout(J1_H, J1_RPIN);

            // Subtract Joint 2 Upstream Cutout at (J2_X, 0)
            translate([J2_X, 0, 0]) joint_upstream_cutout(J2_H, J2_RPIN);
        }

        // Add Joint 2 Pin & Top Bridge at (J2_X, 0)
        translate([J2_X, 0, 0]) joint_pin_and_bridge(J2_H, J2_RPIN);
    }
}

// ============================================================================
// PART 3: TAIL SEGMENT 2 (Joint 2 Bore -> Segment 2 Body -> Joint 3 Pin)
// ============================================================================
module part_3_tail_2() {
    zro2  = z_ring_outer(J2_H, J2_RPIN);
    rr2   = r_ring(J2_RPIN);
    rcut3 = r_body_cut(J3_RPIN);

    union() {
        difference() {
            union() {
                // 1. Anterior Bore Ring + Ramp at Joint 2 (J2_X = -19.5)
                translate([J2_X, 0, 0]) joint_bore_housing_solid(J2_H, J2_RPIN);

                // 2. Smooth Continuous Lower Tail Body (merges seamlessly with Bore Ring up to z = zro2)
                hull() {
                    translate([J2_X - 2.0, 0, 0]) cylinder(h = zro2, r = rr2 - 0.3);
                    translate([(J2_X + J3_X)/2, 0, 0]) cylinder(h = zro2, r = rr2 - 0.1);
                    translate([J3_X + 2.4, 0, 0]) cylinder(h = zro2, r = rcut3 + 0.1);
                }

                // 3. Smooth Continuous Full-Height Tail Body
                hull() {
                    translate([J2_X - rr2 - 1.5, 0, 0]) cylinder(h = J2_H, r = 3.3);
                    translate([(J2_X + J3_X)/2 - 0.5, 0, 0]) cylinder(h = (J2_H + J3_H)/2 + 0.5, r = 4.5);
                    translate([J3_X + 2.6, 0, 0]) cylinder(h = J3_H, r = rcut3 + 0.1);
                    translate([J2_X - 2.6, 0, 0]) cylinder(h = zro2, r = 4.2);
                }

                // 4. Dorsal Spine on Tail Segment 2
                dorsal_plate((J2_X + J3_X)/2 - 1.0, (J2_H + J3_H)/2, 5.2, 2.5, 3.6);
            }

            // Subtract Joint 2 Bore at (J2_X, 0)
            translate([J2_X, 0, 0]) joint_bore_cutout(J2_H, J2_RPIN);

            // Subtract Joint 3 Upstream Cutout at (J3_X, 0)
            translate([J3_X, 0, 0]) joint_upstream_cutout(J3_H, J3_RPIN);
        }

        // Add Joint 3 Pin & Top Bridge at (J3_X, 0)
        translate([J3_X, 0, 0]) joint_pin_and_bridge(J3_H, J3_RPIN);
    }
}

// ============================================================================
// PART 4: TAIL SEGMENT 3 / TAIL TIP (Joint 3 Bore -> Tapered Tail Tip)
// ============================================================================
module part_4_tail_3() {
    zro3 = z_ring_outer(J3_H, J3_RPIN);
    rr3  = r_ring(J3_RPIN);

    difference() {
        union() {
            // 1. Anterior Bore Ring + Ramp at Joint 3 (J3_X = -34.0)
            translate([J3_X, 0, 0]) joint_bore_housing_solid(J3_H, J3_RPIN);

            // 2. Smooth Continuous Tapered Tail Tip (from X = -34.0 to X = -48.0)
            hull() {
                translate([J3_X - 2.0, 0, 0]) cylinder(h = zro3, r = rr3 - 0.3);
                translate([J3_X - rr3 - 1.5, 0, 0]) domed_cylinder(J3_H, 3.4, 2.0);
                translate([J3_X - 8.2, 0, 0]) domed_cylinder(13.2, 3.9, 2.5);
                translate([-46.2, 0, 0]) domed_cylinder(7.5, 1.8, 1.8);
            }

            // 3. Dorsal Fin / Spine on Tail Tip
            dorsal_plate(J3_X - 8.2, 12.2, 5.2, 2.2, 3.2);
        }

        // Subtract Joint 3 Bore at (J3_X, 0)
        translate([J3_X, 0, 0]) joint_bore_cutout(J3_H, J3_RPIN);
    }
}

// ============================================================================
// TOP-LEVEL RENDER DISPATCH
// ============================================================================
if (part_select == 1) {
    part_1_body();
} else if (part_select == 2) {
    part_2_tail_1();
} else if (part_select == 3) {
    part_3_tail_2();
} else if (part_select == 4) {
    part_4_tail_3();
} else {
    part_1_body();
    part_2_tail_1();
    part_3_tail_2();
    part_4_tail_3();
}
