// ============================================================
//  Print-in-place three-section folding ruler
//  Units: millimetres.  Print orientation: ruler lies flat,
//  hinge axes parallel to Z, z=0 on the build plate.
//  Print model.stl as one object, no supports (see README.md).
//
//  Rigid parts:
//    1 : left outer leaf  (pin at its right/top corner)
//    2 : middle leaf      (ring at left/top, pin at right/bottom)
//    3 : right outer leaf (ring at its left/bottom corner)
//
//  Joint 1: part 1 -> part 2, axis +Z at (0, +6.3)
//  Joint 2: part 2 -> part 3, axis +Z at (40.5, -6.3)
//  See joints.json for the joint records and folding directions.
// ============================================================

$fn = 96;

// ---------------- main ruler dimensions ----------------
seg_len      = 40.0;   // length of each leaf body
seg_w        = 12.0;   // width of each leaf body
seg_t        = 5.0;    // thickness of each leaf body
edge_gap     = 0.5;    // longitudinal gap between adjacent leaf bodies at 0 deg
hinge_out    = 0.3;    // joint axis distance outside the leaf edge

// ---------------- revolute joint dimensions ----------------
pin_r        = 1.2;    // integral pin radius
axle_hole_r  = 1.7;    // pin hole radius -> 0.50 mm radial clearance
knuckle_r    = 3.0;    // retaining / bearing knuckle at bottom and top of pin
ring_r       = 2.8;    // rotating ring (middle leaf)
ring_chamfer_r = 2.2;  // outer radius at the bottom of the ring (45 deg lead-in)
body_hole_r  = 3.2;    // clearance in pin leaf around rotating ring: 0.40 mm radial
body_hole_r2 = 3.6;    // clearance in ring leaf around retaining knuckle: 0.60 mm radial

// ---------------- Z stack (total = seg_t) ----------------
z_knuckle    = 1.0;    // thickness of each retaining knuckle
z_gap        = 0.40;   // axial running gap on both sides of rotating ring
z_ring_bot   = z_knuckle + z_gap;          // 1.40
z_ring_top   = seg_t - z_knuckle - z_gap;  // 3.60
ring_chamfer_h = 0.6;  // 45-degree underside lead-in
z_ring_cyl   = z_ring_bot + ring_chamfer_h; // 2.00

// ---------------- joint locations / body extents ----------------
x1a = -seg_len;      x1b = 0.0;
x2a = edge_gap;      x2b = x2a + seg_len;    // 0.5 .. 40.5
x3a = x2b + edge_gap; x3b = x3a + seg_len;   // 41.0 .. 81.0
y_half = seg_w/2;
J1 = [x1b,       y_half + hinge_out];        // (0, 6.3)
J2 = [x2b,      -y_half - hinge_out];        // (40.5, -6.3)

// ---------------- helpers ----------------
module body_rect(xa, xb) {
    translate([xa, -y_half, 0])
        cube([xb-xa, seg_w, seg_t], center=false);
}

module pin_cylinder(z0=0, z1=seg_t) {
    translate([0,0,z0]) cylinder(h=z1-z0, r=pin_r, center=false);
}

module retaining_knuckle(z0) {
    translate([0,0,z0]) cylinder(h=z_knuckle, r=knuckle_r, center=false);
}

// A rotating ring at the B side of a joint.  It is printed in place
// around the pin.  The 45-degree underside lets the first ring layer
// grow outward without supports; the trapped inner radius is 1.7 mm.
module rotating_ring() {
    difference() {
        union() {
            translate([0,0,z_ring_bot])
                cylinder(h=ring_chamfer_h, r1=ring_chamfer_r, r2=ring_r, center=false);
            translate([0,0,z_ring_cyl])
                cylinder(h=z_ring_top-z_ring_cyl, r=ring_r, center=false);
        }
        translate([0,0,-1]) cylinder(h=seg_t+2, r=axle_hole_r, center=false);
    }
}

// ============================================================
//  PART 1 : left leaf, pin side of joint 1
// ============================================================
module part1() {
    difference() {
        union() {
            body_rect(x1a, x1b);
            translate(J1) {
                retaining_knuckle(0);
                retaining_knuckle(seg_t-z_knuckle);
            }
        }
        // relief so the rotating ring of part 2 can turn freely
        translate(J1) translate([0,0,z_knuckle])
            cylinder(h=seg_t-2*z_knuckle, r=body_hole_r, center=false);
    }
    translate(J1) pin_cylinder();
}

// ============================================================
//  PART 2 : middle leaf
//  - left end: rotating ring around part 1 pin (joint 1)
//  - right end: pin with retaining knuckles (joint 2)
// ============================================================
module part2() {
    difference() {
        union() {
            body_rect(x2a, x2b);
            translate(J1) rotating_ring();
            translate(J2) {
                retaining_knuckle(0);
                retaining_knuckle(seg_t-z_knuckle);
            }
        }
        // Joint 1: clearance for part 1 retaining knuckles + pin bore
        translate(J1) {
            translate([0,0,-1])
                cylinder(h=z_ring_bot+1, r=body_hole_r2, center=false);
            translate([0,0,z_ring_top])
                cylinder(h=seg_t-z_ring_top+1, r=body_hole_r2, center=false);
            translate([0,0,-1]) cylinder(h=seg_t+2, r=axle_hole_r, center=false);
        }
        // Joint 2: relief so part 3 rotating ring can turn freely
        translate(J2) translate([0,0,z_knuckle])
            cylinder(h=seg_t-2*z_knuckle, r=body_hole_r, center=false);
    }
    translate(J2) pin_cylinder();
}

// ============================================================
//  PART 3 : right leaf, ring side of joint 2
// ============================================================
module part3() {
    difference() {
        union() {
            body_rect(x3a, x3b);
            translate(J2) rotating_ring();
        }
        translate(J2) {
            translate([0,0,-1])
                cylinder(h=z_ring_bot+1, r=body_hole_r2, center=false);
            translate([0,0,z_ring_top])
                cylinder(h=seg_t-z_ring_top+1, r=body_hole_r2, center=false);
            translate([0,0,-1]) cylinder(h=seg_t+2, r=axle_hole_r, center=false);
        }
    }
}

// ============================================================
//  Assembly / export selection
//  PART_SELECT = 0 -> complete model
//                1,2,3 -> individual rigid part
// ============================================================
PART_SELECT = 0;   // [0:assembly, 1:part 1, 2:part 2, 3:part 3]

if (PART_SELECT == 0) {
    part1();
    part2();
    part3();
} else if (PART_SELECT == 1) {
    part1();
} else if (PART_SELECT == 2) {
    part2();
} else if (PART_SELECT == 3) {
    part3();
}
