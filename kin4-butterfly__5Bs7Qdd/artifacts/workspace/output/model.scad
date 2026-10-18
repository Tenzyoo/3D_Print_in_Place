// Print-in-place articulated butterfly for FDM (PLA, 0.4 mm nozzle).
// Coordinate system: X is head-to-abdomen, Y is wing span, Z is vertical.
// The three solids are: torso (including both captive pins), left wing, right wing.

$fn = 72;

// ---------- User-facing parameters ----------
wing_angle_left  = 0;       // degrees, -30..30
wing_angle_right = 0;       // degrees, -30..30
radial_clearance = 0.50;    // mm, one-sided shaft-to-hole clearance
shaft_r = 2.00;
hole_r = shaft_r + radial_clearance;
pivot_x = 8.0;
pivot_y = 11.5;
wing_outer_r = 5.0;
wing_h = 3.40;
// Set positive to enable optional recessed decorative ribs.  The delivered
// default is 0 for a clean, warning-free manifold export.
wing_rib_h = 0;
wing_hub_taper_h = 1.65;

// Set with: openscad -D 'part="all"' model.scad
// Valid values: all, torso, left, right.
part = "all";

// ---------- 2D silhouettes ----------
module torso_outline_2d() {
    union() {
        // Head, thorax and tapered abdomen.
        translate([-25, 0]) circle(r = 6.5);
        translate([-14, 0]) circle(r = 7.0);
        translate([-3, 0]) scale([1.15, 0.86]) circle(r = 7.0);
        translate([11, 0]) scale([1.80, 0.62]) circle(r = 8.8);
        translate([26, 0]) scale([1.25, 0.48]) circle(r = 6.5);

        // Antennae are part of the fixed torso and remain within the X envelope.
        hull() {
            translate([-29,  3.5]) circle(r = 1.15);
            translate([-37,  7.5]) circle(r = 0.65);
        }
        hull() {
            translate([-29, -3.5]) circle(r = 1.15);
            translate([-37, -7.5]) circle(r = 0.65);
        }
        // Small tail point for a recognizable abdomen.
        polygon(points = [[31, -2.5], [36, 0], [31, 2.5]]);
    }
}

// The pin is joined to the torso above the moving wing.  This keeps the
// complete annular activity gap open at the bed-facing layers.
module torso_top_bridge_2d() {
    union() {
        for (sy = [-1, 1]) {
            hull() {
                translate([pivot_x, sy * 5.0]) circle(r = 1.9);
                translate([pivot_x, sy * pivot_y]) circle(r = 2.0);
            }
        }
    }
}

module wing_outline_2d() {
    union() {
        // Hub circle plus a narrow root that opens into the broad upper/lower lobes.
        circle(r = wing_outer_r);
        polygon(points = [
            [-2.0,  3.2], [ 2.0,  3.2], [ 3.0,  6.0],
            [ 3.0, 10.5], [ 7.0, 15.0], [14.0, 20.5],
            [23.0, 26.5], [33.0, 31.0], [39.0, 29.0],
            [37.0, 23.5], [32.0, 17.0], [25.0, 11.5],
            [17.0,  7.5], [ 9.0,  4.8], [ 4.0,  3.5]
        ]);
        // Lower lobe gives the characteristic butterfly silhouette.
        polygon(points = [
            [-1.5,  5.0], [ 2.5,  5.0], [ 5.0,  8.0],
            [ 8.0, 11.0], [12.0, 13.0], [16.0, 12.0],
            [18.0,  8.0], [13.0,  5.0], [ 6.0,  3.5]
        ]);
    }
}

module wing_ribs_2d() {
    // Raised decorative ribs are kept outside the hub and its motion envelope.
    polygon(points = [[8, 15], [9.0, 15.8], [32, 27.8], [31.5, 29.0]]);
    polygon(points = [[11, 11.5], [11.8, 12.5], [29, 20.5], [28.5, 21.8]]);
    polygon(points = [[14, 8.2], [14.8, 9.0], [24, 13.0], [23.5, 14.2]]);
    // Small raised accent near the outer lobe.
    translate([32, 27]) circle(r = 1.25);
}

// ---------- Fixed torso and captive pins ----------
module joint_pin(sy) {
    // Shaft and bottom collar are fixed to the torso.  The bottom collar is
    // surrounded by the wing's enlarged bottom opening with 0.8 mm clearance.
    translate([pivot_x, sy * pivot_y, 0]) {
        cylinder(r = shaft_r, h = 4.25);
        cylinder(r = 2.80, h = 0.80);

        // Self-supporting upper transition and anti-drop cap.
        translate([0, 0, 4.20]) cylinder(r1 = shaft_r, r2 = 3.35, h = 0.95);
        translate([0, 0, 5.15]) cylinder(r = 3.35, h = 0.30);
    }
}

module torso() {
    union() {
        linear_extrude(height = 4.80, convexity = 10) torso_outline_2d();
        // This bridge is above the 3.75 mm wing/rib top surface, leaving a
        // 0.45 mm axial gap while keeping both pins part of the torso.
        translate([0, 0, 4.15])
            linear_extrude(height = 0.65, convexity = 10) torso_top_bridge_2d();

        // Low-relief head and abdomen bands make the body readable without
        // introducing unsupported overhangs.
        translate([-25, 0, 4.80]) cylinder(r = 4.7, h = 0.35);
        translate([11, 0, 4.80]) scale([1.25, 0.48, 1]) cylinder(r = 6.8, h = 0.35);

        joint_pin(1);
        joint_pin(-1);
    }
}

// ---------- Moving wings ----------
module one_wing(sy = 1, angle = 0) {
    // Build the wing in +Y local coordinates and mirror for the right side.
    translate([pivot_x, sy * pivot_y, 0])
        rotate([0, 0, angle])
            scale([1, sy, 1]) {
                difference() {
                    difference() {
                        linear_extrude(height = wing_h, convexity = 10)
                            wing_outline_2d();
                        // Enlarged bottom opening tapers inward over 1.65 mm.
                        // This is a 45-degree self-supporting transition.
                        translate([0, 0, -0.01])
                            cylinder(r1 = 4.10, r2 = hole_r, h = wing_hub_taper_h + 0.01);
                        translate([0, 0, wing_hub_taper_h - 0.01])
                            cylinder(r = hole_r, h = wing_h - wing_hub_taper_h + 0.03);
                    }
                    // Shallow recessed ribs are subtractive, so the wing remains
                    // one rigid solid and no coplanar added body is created.
                    if (wing_rib_h > 0)
                        translate([0, 0, wing_h - 0.32])
                            linear_extrude(height = 0.42, convexity = 5)
                                wing_ribs_2d();
                }
            }
}

// ---------- Export selector ----------
if (part == "torso") {
    torso();
} else if (part == "left") {
    one_wing(1, wing_angle_left);
} else if (part == "right") {
    one_wing(-1, wing_angle_right);
} else {
    torso();
    one_wing(1, wing_angle_left);
    one_wing(-1, wing_angle_right);
}
