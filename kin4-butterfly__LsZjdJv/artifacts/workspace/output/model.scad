// ============================================================================
// Print-in-Place Articulated Butterfly Model (FDM 3D Printable)
// ============================================================================
// Coordinate System:
//   X-axis : Torso longitudinal direction (+X = Head/Antennae, -X = Abdomen)
//   Y-axis : Wing span direction (+Y = Left Wing, -Y = Right Wing)
//   Z-axis : Vertical print direction (Z = 0 is flat on the build plate)
//
// Structure:
//   3 Independent Rigid Bodies:
//     1. Fixed Torso (parts_1.stl): Head, compound eyes, clubbed antennae,
//        thorax, segmented abdomen, and left/right captive double-conical
//        pin joints with self-supporting gothic-arch bridges.
//     2. Left Wing (parts_2.stl): 360-degree captive bore hub + forewing/hindwing
//        with multi-level raised venation texture and decorative wing cells.
//     3. Right Wing (parts_3.stl): Mirror-symmetric right wing.
//
// Printing Parameters Target:
//   PLA, 0.4 mm nozzle, 0.2 mm layer height, no supports required.
//   Pin-to-bore single-side radial clearance: 0.50 mm (within 0.4 - 0.6 mm).
// ============================================================================

$fn = 72;

// ----------------------------
// Render / Export Control
// ----------------------------
// Options: "all", "torso", "left_wing", "right_wing"
part_select = "all";

// Wing rotation angles in degrees (Valid collision-free range: <= -30 to >= +30)
left_wing_angle  = 0;
right_wing_angle = 0;

// ----------------------------
// Core Joint Parameters (mm)
// ----------------------------
joint_x = 2.0;               // Joint axis X position
joint_y = 10.5;              // Joint axis |Y| position (Left = +10.5, Right = -10.5)

radial_clearance = 0.50;     // Single-side radial clearance (0.4 - 0.6 mm spec)
cone_z_clearance = 0.16;     // Extra axial clearance on conical retention faces

pin_shaft_r      = 3.90;     // Central cylindrical pin radius (D = 6.00 mm)
pin_flare_r      = 5.10;     // Bottom/top conical retention flare radius (D = 8.60 mm)
bore_shaft_r     = pin_shaft_r + radial_clearance; // 3.50 mm (D = 7.00 mm)
bore_flare_r     = pin_flare_r + radial_clearance; // 4.80 mm (D = 9.60 mm)

knuckle_outer_r  = 7.40;     // Outer radius of wing knuckle ring (D = 14.40 mm)
torso_clear_r    = knuckle_outer_r + radial_clearance; // 7.70 mm

// Z-height levels (aligned to 0.20 mm layer increments)
z_bed            = 0.00;
z_skirt_top      = 0.80;     // Vertical base skirt top
z_bot_cone_top   = 2.40;     // Bottom conical retention top (dZ = 1.60, dR = 1.30 -> 50.9 deg)
z_mid_cyl_top    = 4.20;     // Central cylindrical shaft top (height = 3.60 mm)
z_top_cone_top   = 5.80;     // Top conical retention top (dZ = 1.60, dR = 1.30 -> 50.9 deg)
z_knuckle_top    = 6.60;     // Top of wing knuckle roof
z_arch_merge     = 7.80;     // Gothic arch merge height (dZ = 2.20, dR = 1.70 -> 52.3 deg)
z_bridge_top     = 12.60;    // Top of torso shoulder bridge & pin cap

// Wing thickness parameters (multi-level relief)
wing_cell_floor_h = 1.40;    // Recessed translucent-style inner cell floor height
wing_base_h       = 2.80;    // Main wing membrane thickness
wing_vein_h       = 4.00;    // Raised decorative vein & border height

// ============================================================================
// Helper Modules
// ============================================================================

// Smooth 2D polygon rounding via offset
module smooth_2d(r_round = 1.5) {
    offset(r = r_round, $fn = 36)
    offset(r = -2 * r_round, $fn = 36)
    offset(r = r_round, $fn = 36)
        children();
}

// 2D capsule between two points with end radii r1, r2
module bar_2d(p1, p2, r1, r2 = -1) {
    r_end = (r2 < 0) ? r1 : r2;
    hull() {
        translate(p1) circle(r = r1, $fn = 32);
        translate(p2) circle(r = r_end, $fn = 32);
    }
}

// 2D smooth organic cell defined by hull of circles
module cell_3pt_2d(p1, r1, p2, r2, p3, r3) {
    hull() {
        translate(p1) circle(r = r1, $fn = 32);
        translate(p2) circle(r = r2, $fn = 32);
        translate(p3) circle(r = r3, $fn = 32);
    }
}

// 3D tapered capsule segment flat on Z=0 with 45-deg beveled top
module sculpted_segment(p1, p2, r1, r2, h1, h2) {
    hull() {
        translate([p1[0], p1[1], 0])
            cylinder(r1 = r1, r2 = max(0.8, r1 - 0.35 * h1), h = h1, $fn = 40);
        translate([p2[0], p2[1], 0])
            cylinder(r1 = r2, r2 = max(0.8, r2 - 0.35 * h2), h = h2, $fn = 40);
    }
}

// ============================================================================
// Joint Profiles & Modules
// ============================================================================

// 360-degree Captive Pin (Part of Fixed Torso)
module captive_pin() {
    rotate_extrude(angle = 360, $fn = 72) {
        polygon(points = [
            [0.00,               z_bed],
            [pin_flare_r,        z_bed],
            [pin_flare_r,        z_skirt_top - cone_z_clearance],
            [pin_shaft_r,        z_bot_cone_top - cone_z_clearance],
            [pin_shaft_r,        z_mid_cyl_top + cone_z_clearance],
            [pin_flare_r,        z_top_cone_top + cone_z_clearance],
            [pin_flare_r,        z_bridge_top - 0.80],
            [pin_flare_r - 0.80, z_bridge_top],
            [0.00,               z_bridge_top]
        ]);
    }
}

// Smooth Sculpted Torso Shoulder Bridge connecting the Captive Pin to the Thorax
// The gothic-arch underside is carved cleanly by wing_knuckle_clearance_cutout().
module torso_shoulder_arch(is_left = true) {
    sy = is_left ? 1 : -1;
    hull() {
        // Outer pin cap column at (joint_x, sy * joint_y)
        cylinder(r1 = pin_flare_r, r2 = pin_flare_r - 0.80, h = z_bridge_top, $fn = 72);
        // Inner shoulder column blending into thorax at (joint_x, sy * 2.5)
        translate([0, -sy * (joint_y - 2.5), 0])
            cylinder(r1 = 5.4, r2 = 4.2, h = z_bridge_top, $fn = 48);
    }
}

// Clearance cutout subtracted from the Torso around each joint before adding the Pin
module wing_knuckle_clearance_cutout() {
    rotate_extrude(angle = 360, $fn = 72) {
        polygon(points = [
            [0.00,              z_bed - 0.5],
            [torso_clear_r,     z_bed - 0.5],
            [torso_clear_r,     z_top_cone_top + cone_z_clearance],
            [6.50,              z_arch_merge],
            [pin_flare_r - 0.4, z_top_cone_top + cone_z_clearance],
            [0.00,              z_top_cone_top + cone_z_clearance]
        ]);
    }
}

// 360-degree Wing Knuckle Hub with Captive Double-Conical Bore (Part of Wing)
module wing_knuckle_solid() {
    rotate_extrude(angle = 360, $fn = 72) {
        polygon(points = [
            [bore_flare_r,    z_bed],
            [knuckle_outer_r, z_bed],
            [knuckle_outer_r, z_top_cone_top - cone_z_clearance],
            [6.80,            z_knuckle_top],
            [6.20,            z_knuckle_top],
            [bore_flare_r,    z_top_cone_top - cone_z_clearance],
            [bore_shaft_r,    z_mid_cyl_top - cone_z_clearance],
            [bore_shaft_r,    z_bot_cone_top + cone_z_clearance],
            [bore_flare_r,    z_skirt_top + cone_z_clearance]
        ]);
    }
}

// ============================================================================
// Part 1: Fixed Butterfly Torso (Head, Eyes, Antennae, Thorax, Abdomen, Pins)
// ============================================================================

module butterfly_torso() {
    union() {
        difference() {
            union() {
                // 1. Central Thorax (mesothorax & metathorax sculpted dome)
                sculpted_segment([-5.5, 0], [12.5, 0], 5.6, 6.2, 11.4, 12.8);
                sculpted_segment([0.0,  0], [7.5,  0], 6.6, 6.4, 13.4, 13.2);

                // 2. Left & Right Smooth Shoulder Bridges
                translate([joint_x,  joint_y, 0]) torso_shoulder_arch(is_left = true);
                translate([joint_x, -joint_y, 0]) torso_shoulder_arch(is_left = false);

                // 3. Prothorax Neck & Head Capsule (+X)
                sculpted_segment([12.5, 0], [18.5, 0], 4.8, 5.2, 10.6, 9.6);

                // Compound Eyes (left & right prominent domes integrated to bed)
                for (sy = [-1, 1]) {
                    sculpted_segment([18.8, sy * 3.2], [19.8, sy * 3.7], 2.5, 2.8, 7.8, 8.2);
                }

                // 4. Clubbed Antennae (flat on Z=0 for reliable bed adhesion)
                for (sy = [-1, 1]) {
                    linear_extrude(height = 3.4, scale = 0.88) {
                        union() {
                            bar_2d([20.5, sy * 2.0], [26.0, sy * 3.2], 1.35, 1.25);
                            bar_2d([26.0, sy * 3.2], [31.5, sy * 5.0], 1.25, 1.30);
                            bar_2d([31.5, sy * 5.0], [34.8, sy * 6.0], 1.30, 2.05);
                        }
                    }
                }

                // 5. Segmented Abdomen (-X, 7 anatomical segments tapering to tail)
                sculpted_segment([-5.5,  0], [-11.0, 0], 5.2, 5.0, 10.4, 9.8);
                sculpted_segment([-11.0, 0], [-16.5, 0], 5.1, 4.8, 9.7,  9.1);
                sculpted_segment([-16.5, 0], [-22.0, 0], 4.9, 4.5, 9.0,  8.4);
                sculpted_segment([-22.0, 0], [-27.5, 0], 4.6, 4.1, 8.3,  7.6);
                sculpted_segment([-27.5, 0], [-32.5, 0], 4.2, 3.5, 7.5,  6.8);
                sculpted_segment([-32.5, 0], [-37.0, 0], 3.6, 2.7, 6.7,  5.8);
                sculpted_segment([-37.0, 0], [-40.5, 0], 2.8, 1.8, 5.7,  4.6);

                // Abdominal annular ridges (textured rings on top of abdomen)
                for (i = [0 : 5]) {
                    seg_x = -8.5 - i * 5.2;
                    seg_r = 4.9 - i * 0.42;
                    seg_h = 10.1 - i * 0.72;
                    translate([seg_x, 0, 0])
                        cylinder(r1 = seg_r, r2 = seg_r - 1.2, h = seg_h, $fn = 36);
                }
            }

            // Subtract Wing Knuckle clearance envelope on both sides
            translate([joint_x,  joint_y, 0]) wing_knuckle_clearance_cutout();
            translate([joint_x, -joint_y, 0]) wing_knuckle_clearance_cutout();


        }

        // Add the Left and Right Captive Pins
        translate([joint_x,  joint_y, 0]) captive_pin();
        translate([joint_x, -joint_y, 0]) captive_pin();
    }
}

// ============================================================================
// Parts 2 & 3: Left and Right Movable Butterfly Wings
// ============================================================================

// Complete 2D Left Wing Silhouette (in global XY coordinates for neutral pose)
// Designed so every point outside the knuckle lies in polar angle [39 deg, 150 deg]
// relative to (joint_x, joint_y) = (2.0, 10.5), guaranteeing Y >= 10.5 mm throughout
// the entire [-30 deg, +30 deg] swing range!
module left_wing_outer_2d() {
    smooth_2d(r_round = 1.8) {
        polygon(points = [
            // Root hub attachment (centered at joint_x=2.0, joint_y=10.5)
            [ 2.0, 11.5],
            [ 6.4, 14.6],
            // Forewing costal (leading) margin (polar angle >= 39.5 deg)
            [14.5, 21.2],
            [25.0, 29.8],
            [34.5, 38.0],
            // Forewing rounded apex
            [40.2, 43.5],
            [39.0, 46.2],
            // Forewing outer scalloped margin (max Y <= 47.0 mm)
            [31.5, 47.0],
            [23.5, 45.8],
            [16.2, 43.4],
            [ 9.8, 39.6],
            // Forewing / Hindwing cleft notch
            [ 3.8, 33.8],
            // Hindwing outer scalloped margin
            [-3.0, 39.2],
            [-11.0, 40.8],
            [-19.0, 39.2],
            [-25.5, 36.0],
            // Swallowtail hindwing lobe
            [-32.0, 32.5],
            [-29.2, 28.8],
            // Hindwing inner (trailing) margin (polar angle <= 150 deg)
            [-23.5, 25.5],
            [-15.0, 20.6],
            [-7.5,  16.5],
            [-2.2,  14.2]
        ]);
    }
}

// Structural vein skeleton dividing the wing into anatomical discal & submarginal cells
module wing_vein_skeleton_2d() {
    union() {
        // Root hub reinforcement pad
        translate([2.5, 15.5]) circle(r = 6.8, $fn = 48);

        // Forewing Discal Cell Frame & Radial Veins
        bar_2d([5.5,  18.5], [22.5, 32.5], 1.15, 1.05); // Upper discal vein
        bar_2d([4.5,  20.0], [16.5, 35.5], 1.15, 1.05); // Lower discal vein
        bar_2d([22.5, 32.5], [16.5, 35.5], 1.05, 1.05); // Discal cross-vein

        // Forewing Radial Branches to Outer Margin
        bar_2d([22.5, 32.5], [39.5, 44.5], 1.05, 1.00); // R1 apical vein
        bar_2d([20.2, 33.8], [31.5, 46.8], 1.00, 0.95); // M1 vein
        bar_2d([18.0, 34.8], [22.5, 45.8], 1.00, 0.95); // M2 vein
        bar_2d([16.5, 35.5], [14.5, 43.2], 1.00, 0.95); // Cu1 vein
        bar_2d([11.5, 28.5], [ 8.5, 39.5], 1.00, 0.95); // Cu2 vein

        // Forewing / Hindwing Cleft Divider Vein
        bar_2d([3.0,  18.5], [ 3.8, 34.5], 1.25, 1.05);

        // Hindwing Discal Cell Frame & Radial Veins
        bar_2d([1.5,  19.5], [-6.5,  31.8], 1.10, 1.00); // Hind upper discal
        bar_2d([-1.5, 18.5], [-13.5, 29.5], 1.10, 1.00); // Hind lower discal
        bar_2d([-6.5, 31.8], [-13.5, 29.5], 1.00, 1.00); // Hind discal cross-vein

        // Hindwing Radial Branches to Outer Scalloped Margin
        bar_2d([-3.5,  27.5], [-2.5,  39.2], 1.00, 0.95);
        bar_2d([-6.5,  31.8], [-11.0, 40.8], 1.00, 0.95);
        bar_2d([-10.2, 30.5], [-19.5, 39.2], 1.00, 0.95);
        bar_2d([-13.5, 29.5], [-26.5, 35.5], 1.00, 0.95);
        bar_2d([-13.5, 29.5], [-31.5, 32.0], 1.05, 0.95); // Swallowtail vein
    }
}

// All filleted organic wing cells (automatically bounded >= 2.2 mm inside wing edge
// and separated by >= 2.0 mm smooth veins with 1.1 mm corner fillets)
module all_wing_cells_2d() {
    offset(r = 1.1, $fn = 32)
    offset(r = -1.1, $fn = 32)
    difference() {
        offset(r = -2.2, $fn = 36) left_wing_outer_2d();
        wing_vein_skeleton_2d();
    }
}

// Submarginal through-windows (outer ring of cells beyond the discal cross-veins)
module left_wing_through_windows_2d() {
    offset(r = 1.0, $fn = 32)
    offset(r = -1.0, $fn = 32)
    intersection() {
        all_wing_cells_2d();
        difference() {
            left_wing_outer_2d();
            // Keep inner discal zone as recessed membrane floor
            hull() {
                translate([4.0,  18.0]) circle(r = 6.0, $fn = 36);
                translate([21.5, 31.5]) circle(r = 4.2, $fn = 36);
                translate([15.5, 34.5]) circle(r = 4.2, $fn = 36);
                translate([-6.0, 31.0]) circle(r = 4.5, $fn = 36);
                translate([-14.0,28.5]) circle(r = 4.5, $fn = 36);
            }
        }
    }
}

// Clean 2D Venation Lattice formed directly by the wing contour minus all filleted cells,
// plus ornamental eye-spots on the forewing and hindwing discal cells.
module left_wing_vein_lattice_2d() {
    union() {
        difference() {
            left_wing_outer_2d();
            all_wing_cells_2d();
        }
        // Decorative raised eye-spot rings in the forewing and hindwing discal cells
        translate([13.2, 27.2])
        difference() {
            circle(r = 2.2, $fn = 40);
            circle(r = 0.9, $fn = 40);
        }
        translate([-5.2, 25.5])
        difference() {
            circle(r = 2.2, $fn = 40);
            circle(r = 0.9, $fn = 40);
        }
    }
}

// Complete Left Wing 3D Solid in Neutral Pose
module left_wing_neutral() {
    union() {
        // 1. 360-degree Captive Knuckle Hub centered at (joint_x, joint_y)
        translate([joint_x, joint_y, 0])
            wing_knuckle_solid();

        // 2. Wing Blade & Root Gusset (trimmed strictly outside the knuckle bore)
        difference() {
            union() {
                // Level 1: Continuous inner wing membrane floor (Z = 0 to 1.40 mm)
                linear_extrude(height = wing_cell_floor_h) {
                    difference() {
                        left_wing_outer_2d();
                        left_wing_through_windows_2d();
                    }
                }

                // Level 2: Main structural venation lattice & frame (Z = 0 to 2.80 mm)
                linear_extrude(height = wing_base_h) {
                    left_wing_vein_lattice_2d();
                }

                // Level 3: Beveled raised venation crest (Z = 0 to 4.00 mm)
                linear_extrude(height = wing_vein_h) {
                    offset(r = -0.35, $fn = 24)
                        left_wing_vein_lattice_2d();
                }

                // Level 4: Smoothly contoured root gusset (clamped strictly inside wing silhouette)
                intersection() {
                    linear_extrude(height = z_top_cone_top)
                        offset(r = -0.4, $fn = 32) left_wing_outer_2d();
                    hull() {
                        intersection() {
                            translate([joint_x, joint_y, 0])
                                cylinder(r = knuckle_outer_r - 0.1, h = z_top_cone_top - cone_z_clearance, $fn = 72);
                            translate([joint_x - 3.5, joint_y + 2.8, 0])
                                cube([9.0, 10.0, z_top_cone_top - cone_z_clearance]);
                        }
                        translate([3.5, 19.2, 0])
                            cylinder(r1 = 4.2, r2 = 2.6, h = 5.0, $fn = 40);
                    }
                }
            }

            // Ensure the bore and clearance around the pin & torso arch are 100% unobstructed
            translate([joint_x, joint_y, 0])
            rotate_extrude(angle = 360, $fn = 72) {
                polygon(points = [
                    [0.00,                   -1.0],
                    [knuckle_outer_r - 0.15, -1.0],
                    [knuckle_outer_r - 0.15, z_top_cone_top - cone_z_clearance + 0.05],
                    [6.80,                   z_knuckle_top + 0.05],
                    [knuckle_outer_r + 3.0,  z_knuckle_top + 0.05],
                    [knuckle_outer_r + 3.0,  z_bridge_top + 2.0],
                    [0.00,                   z_bridge_top + 2.0]
                ]);
            }
        }
    }
}

// Left Wing with rotation applied around (joint_x, +joint_y)
module left_wing_positioned(angle_deg = 0) {
    translate([joint_x, joint_y, 0])
    rotate([0, 0, angle_deg])
    translate([-joint_x, -joint_y, 0])
        left_wing_neutral();
}

// Right Wing with rotation applied around (joint_x, -joint_y)
// Exact mirror of Left Wing across the XZ plane (Y = 0)
module right_wing_positioned(angle_deg = 0) {
    translate([joint_x, -joint_y, 0])
    rotate([0, 0, angle_deg])
    translate([-joint_x, joint_y, 0])
    mirror([0, 1, 0])
        left_wing_neutral();
}

// ============================================================================
// Top-Level Assembly Dispatcher
// ============================================================================

if (part_select == "all") {
    butterfly_torso();
    left_wing_positioned(left_wing_angle);
    right_wing_positioned(right_wing_angle);
} else if (part_select == "torso") {
    butterfly_torso();
} else if (part_select == "left_wing") {
    left_wing_positioned(left_wing_angle);
} else if (part_select == "right_wing") {
    right_wing_positioned(right_wing_angle);
}
