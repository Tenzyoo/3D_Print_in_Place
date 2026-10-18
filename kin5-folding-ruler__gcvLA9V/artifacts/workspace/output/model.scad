// Three-section print-in-place folding ruler, PLA/FDM optimized
// Units: millimetres. Hinge axes are parallel to +Z and motion is in XY.
// The 6 mm Z staggering is intentional: it gives the 12 mm wide leaves
// a positive vertical clearance while they pass through the 90 degree sweep.

$fn = 64;

// Principal required dimensions
body_length = 40;
body_width  = 12;
body_thickness = 5;

// Assembly / clearance dimensions
axis_y = -0.8;              // axis just beyond the lower edge of a leaf
leaf_gap = 3;               // body-to-axis offset at each end
axis2_x = 46;               // 3 + 40 + 3, in section-2 local coordinates
z_step = 6;                 // 1 mm clearance between adjacent 5 mm leaves
shaft_r = 1.6;              // 3.2 mm shaft diameter
bore_r = 2.1;               // 4.2 mm bore: 0.5 mm radial clearance
barrel_r = 2.8;
collar_r = 2.35;
barrel_z0 = 0.8;
barrel_z1 = 4.2;

// Set these from the command line for motion studies or part export.
angle1 = 0;                 // 0 = straight; 180 = fold-back at joint 1
angle2 = 0;                 // relative to section 2; 0 = straight
part_to_export = 0;         // 0=assembly, 1..3=one rigid body

module leaf_body_at(x0, z0) {
    translate([x0, 0, z0])
        cube([body_length, body_width, body_thickness]);
}
module leaf_body(z0) {
    leaf_body_at(leaf_gap, z0);
}

// Low, wide stem: it is attached to the pin leaf and is below the moving barrel.
module pin_stem(z0) {
    translate([-leaf_gap-0.25, axis_y-1.0, z0])
        cube([leaf_gap+0.25, 1.8, 0.9]);
}

// A pin belongs to the leaf on its left.  The next leaf's barrel is six mm
// higher.  The two collars are captive axially, with a deliberate 0.30 mm
// axial air gap to the barrel ends.
module captive_pin(z0) {
    target = z0 + z_step;
    // shaft, joined to the stem and extending through the next barrel
    translate([0, axis_y, z0+0.25])
        cylinder(r=shaft_r, h=target+4.5-(z0+0.25));
    // lower anti-drop collar (below the barrel's lower end)
    translate([0, axis_y, target-0.8])
        cylinder(r=collar_r, h=0.6);
    // printable 45-ish degree upper anti-drop collar
    translate([0, axis_y, target+4.45])
        cylinder(r1=shaft_r, r2=collar_r, h=0.75);
}

// Barrel belongs to the leaf on the right.  It starts above the lower collar
// and is supported by the outside connector; its bore never contains support.
module barrel_and_connector(z0) {
    translate([0, axis_y, z0+barrel_z0])
        difference() {
            cylinder(r=barrel_r, h=barrel_z1-barrel_z0);
            cylinder(r=bore_r, h=barrel_z1-barrel_z0+0.04);
        }
    // Connector is outside the active annular clearance and joins the body.
    translate([2.45, axis_y-1.0, z0])
        cube([leaf_gap-2.45+0.80, 2.0, body_thickness]);
}

// Section 1: left leaf plus the pin at its right joint.
module section1() {
    union() {
        leaf_body_at(-body_length-leaf_gap, 0); // x = -43 .. -3, z=0..5
        pin_stem(0);
        captive_pin(0);
    }
}

// Section 2 local coordinates: barrel at x=0 and pin at x=46.
module section2_local() {
    union() {
        leaf_body(z_step);               // x = 3 .. 43, z=6..11
        barrel_and_connector(z_step);
        // move pin geometry from the left axis to the right axis
        translate([axis2_x, 0, 0]) {
            pin_stem(z_step);
            captive_pin(z_step);
        }
    }
}

// Section 3 local coordinates: barrel at x=0, body x=3..43.
module section3_local() {
    union() {
        leaf_body(2*z_step);             // z=12..17
        barrel_and_connector(2*z_step);
    }
}

// Base transforms keep the two joints independent.  Section 3 uses the
// cumulative orientation, as expected for two serial relative joints.
module section1_world() {
    section1();
}
module section2_world() {
    // rotate section 2 about the fixed joint-1 axis (0, axis_y)
    translate([0, axis_y, 0])
        rotate([0,0,angle1])
            translate([0, -axis_y, 0]) section2_local();
}
module section3_world() {
    // Rotate section 3 about joint 2's local axis, then carry joint 2
    // around the fixed joint-1 axis.  The two angles remain independent.
    translate([0, axis_y, 0])
        rotate([0,0,angle1])
            translate([0, -axis_y, 0])
                translate([axis2_x, 0, 0])
                    translate([0, axis_y, 0])
                        rotate([0,0,angle2])
                            translate([0, -axis_y, 0]) section3_local();
}

// The assembled STL is a multi-solid STL by design: each rigid body remains
// independently movable and the clearances are not boolean-unioned away.
module assembly() {
    section1_world();
    section2_world();
    section3_world();
}

if (part_to_export == 1) section1_world();
else if (part_to_export == 2) section2_world();
else if (part_to_export == 3) section3_world();
else assembly();
