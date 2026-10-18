// Print-in-place articulated dinosaur
// Units: millimetres.  Build plate plane: z = 0.
// All parts are modelled in their neutral, assembled printing pose.
//
// Render the complete assembly:
//   openscad -o model.stl model.scad
// Render one part:
//   openscad -D 'part="body"'   -o parts/parts_1.stl model.scad
//   openscad -D 'part="tail1"'  -o parts/parts_2.stl model.scad
//   openscad -D 'part="tail2"'  -o parts/parts_3.stl model.scad
//   openscad -D 'part="tail3"'  -o parts/parts_4.stl model.scad

part = "all"; // [all, body, tail1, tail2, tail3]

/* ------------------------------------------------------------------ */
/*  Global dimensions and joint parameters                             */
/* ------------------------------------------------------------------ */

$fn = 72;

// Tail hinges, centres in the neutral pose (axis parallel to Z).
J1x = 22.0;
J2x = 35.5;
J3x = 49.0;

tail_t      = 7.0;    // thickness of a tail link (z = 0 .. 7)
pin_r       = 2.2;    // metal-free integral pin shaft radius
hole_r      = 2.7;    // child eye radius: 0.50 mm radial clearance
flange_r    = 3.8;    // lower retaining flange and upper retaining head
flange_cone = 1.5;    // height of the 45-degree lower retaining cone
head_start  = 7.5;    // lower face of captive head (0.50 mm above child top)
head_cone   = 1.6;    // 45-degree underside of captive head
head_top    = head_start + head_cone; // 9.1

c_outer     = 5.2;    // outside radius of the C-shaped child eye
c_gap_deg   = 130;    // angular opening in child eye, centred on -X
c_gap_half  = c_gap_deg / 2;
conn_w      = 3.0;    // width of parent web at its outer end
conn_w_tip  = 2.0;    // narrower web close to the pin (more angular clearance)
clear_rad   = 5.7;    // parent body is relieved to this radius at child
rc0         = 4.4;    // child bottom recess radius at z=0

/* ------------------------------------------------------------------ */
/*  Small geometry helpers                                             */
/* ------------------------------------------------------------------ */

module ell(c, r) {
    translate(c) scale(r) sphere(r = 1);
}

// An ellipsoid clipped by the build plate, giving a real flat pad instead
// of a point/tangent contact.  No geometry is placed below z = 0.
module flat_ell(c, r) {
    intersection() {
        ell(c, r);
        translate([c[0] - r[0] - 1, c[1] - r[1] - 1, 0])
            cube([2 * r[0] + 2, 2 * r[1] + 2, 80]);
    }
}

module sphere_at(c, r) {
    translate(c) sphere(r = r);
}

// Child eye outer sector (solid disk with a 130-degree opening to -X).
// The central hole is cut later so that the same cone removes any body
// material which would otherwise grow into the retaining recess.
module c_sector_2d() {
    difference() {
        circle(r = c_outer);
        polygon(points = [
            [0, 0],
            [40 * cos(180 - c_gap_half), 40 * sin(180 - c_gap_half)],
            [40 * cos(180 + c_gap_half), 40 * sin(180 + c_gap_half)]
        ]);
    }
}

// Integral pin belonging to the parent part.  The lower flange is printed
// on the bed and the upper head is a 45-degree self-supporting cone.
module parent_boss() {
    union() {
        // shaft, from bed to top of captive head
        cylinder(h = head_top, r = pin_r);
        // lower captive flange: 45-degree upper surface
        cylinder(h = flange_cone, r1 = flange_r, r2 = pin_r);
        // upper captive head: 45-degree underside (prints without support)
        translate([0, 0, head_start])
            cylinder(h = head_cone, r1 = pin_r, r2 = flange_r);
    }
}

// Full child link envelope around its west hinge, before the pin hole and
// conical retaining recess are subtracted.
module child_eye_sector() {
    linear_extrude(height = tail_t) c_sector_2d();
}

// Conical bottom recess plus through hole at a child eye.
module child_eye_cut() {
    // Through hole for the pin shaft.
    translate([0, 0, -0.05])
        cylinder(h = tail_t + 0.10, r = hole_r);
    // 45-degree bottom recess that captures the lower flange.
    translate([0, 0, 0])
        cylinder(h = flange_cone + 0.02, r1 = rc0, r2 = hole_r);
}

// Parent web passing through the child's C-shaped opening.  It tapers
// from 3.0 mm wide at the link body to 2.0 mm beside the pin, which keeps
// a >0.5 mm clearance to the C-eye edges even at the full +/-30 deg swing.
module parent_web(x0, x1) {
    linear_extrude(height = tail_t)
        polygon(points = [
            [x0, -conn_w / 2],
            [x1 - 2.2, -conn_w_tip / 2],
            [x1, -conn_w_tip / 2],
            [x1,  conn_w_tip / 2],
            [x1 - 2.2,  conn_w_tip / 2],
            [x0,  conn_w / 2]
        ]);
}

// A single soft dorsal scute on each tail segment.
module tail_scute(x) {
    translate([x, 0, 6.8]) scale([1.00, 0.62, 1.55]) sphere(r = 1);
}

/* ------------------------------------------------------------------ */
/*  Tail links                                                         */
/* ------------------------------------------------------------------ */

// One tail link.  jw = west (child) hinge, je = east (parent) hinge.
// A parent boss is always at the east end.  The last link has je = 0.
module tail_link(jw, je) {
    difference() {
        union() {
            // C-shaped eye around the previous link's pin.
            translate([jw, 0, 0]) child_eye_sector();

            // Tapered link body, relieved around the following child eye.
            linear_extrude(height = tail_t) {
                difference() {
                    union() {
                        // root blends into the C eye
                        hull() {
                            translate([jw + 2.6, 0]) circle(r = 4.5);
                            translate([jw + 6.3, 0]) circle(r = 3.35);
                        }
                        if (je > 0) {
                            // small web between the eye and the connector
                            translate([jw + 6.3, 0]) circle(r = 3.35);
                        } else {
                            // tapering last segment and rounded tip
                            hull() {
                                translate([jw + 6.0, 0]) circle(r = 3.2);
                                translate([jw + 10.0, 0]) circle(r = 1.10);
                            }
                        }
                    }
                    if (je > 0) {
                        // clearance around the next link's C eye
                        translate([je, 0]) circle(r = clear_rad);
                    }
                }
            }

            if (je > 0) {
                // Parent web through the 130-degree C opening.  It is
                // deliberately narrower than the opening at every radius.
                parent_web(je - 6.6, je);
                // The pin/head/flange at the east end.
                translate([je, 0, 0]) parent_boss();
            }

            // Dorsal scute at the middle of the segment.
            tail_scute(je > 0 ? (jw + je) / 2 : jw + 7.0);
        }

        // Captive eye bore and 45-degree undercut at the west end.
        translate([jw, 0, 0]) child_eye_cut();
    }
}

/* ------------------------------------------------------------------ */
/*  Fixed body: torso, head, four legs, tail stock, first pin          */
/* ------------------------------------------------------------------ */

module leg(x, y, toe_dir) {
    hull() {
        // upper haunch, buried in the torso
        ell([x, y, 15.0], [3.8, 3.3, 4.6]);
        // lower leg
        sphere_at([x, y, 7.0], 3.25);
        // foot pad, clipped flat on the build plate
        flat_ell([x + toe_dir * 0.7, y, 1.8], [4.4, 3.6, 2.4]);
    }
    // three rounded toes, also clipped flat on z=0
    for (dy = [-1.75, 0, 1.75]) {
        flat_ell([x + toe_dir * 3.6, y + dy, 0.9], [1.55, 1.05, 1.10]);
    }
}

module dorsal_plate(x, z, h, w = 1.35) {
    // flattened, rounded fin blended into the back
    translate([x, 0, z]) scale([1.25, w, h]) sphere(r = 1);
}

module fixed_body() {
    union() {
        // ---- torso -------------------------------------------------
        ell([-2.0, 0, 21.0], [16.0, 10.4, 10.5]);
        ell([10.0, 0, 21.5], [8.6, 10.2, 9.2]);
        ell([-14.0, 0, 23.5], [8.2, 9.0, 8.8]);

        // ---- neck --------------------------------------------------
        hull() {
            ell([-17.0, 0, 28.0], [6.8, 8.0, 6.8]);
            ell([-24.2, 0, 37.3], [6.2, 7.1, 6.2]);
        }

        // ---- head --------------------------------------------------
        ell([-28.5, 0, 44.0], [8.6, 8.3, 8.6]);
        // muzzle
        ell([-34.7, 0, 41.0], [4.5, 5.5, 4.1]);
        // lower jaw / chin
        ell([-34.5, 0, 38.5], [4.0, 4.8, 2.25]);
        // brow bumps
        ell([-30.0,  6.1, 49.3], [2.7, 2.0, 2.2]);
        ell([-30.0, -6.1, 49.3], [2.7, 2.0, 2.2]);
        // eyes (raised lenticular bosses)
        ell([-29.8,  7.6, 46.2], [1.65, 0.85, 1.65]);
        ell([-29.8, -7.6, 46.2], [1.65, 0.85, 1.65]);
        // nostrils
        ell([-37.9,  2.3, 43.1], [0.62, 0.70, 0.62]);
        ell([-37.9, -2.3, 43.1], [0.62, 0.70, 0.62]);
        // small rounded crest on the back of the head
        ell([-23.0, 0, 50.3], [2.1, 1.2, 2.6]);

        // ---- four legs --------------------------------------------
        leg(-11.0,  8.8, -1);
        leg(-11.0, -8.8, -1);
        leg(  9.5,  8.8, -1);
        leg(  9.5, -8.8, -1);

        // ---- dorsal plates ---------------------------------------
        dorsal_plate(-19.0, 31.6, 2.4, 1.10);
        dorsal_plate(-12.0, 32.4, 2.9, 1.20);
        dorsal_plate( -4.5, 32.4, 3.0, 1.25);
        dorsal_plate(  3.0, 31.9, 2.7, 1.20);
        dorsal_plate( 10.2, 31.0, 2.25, 1.05);

        // ---- tail stock down to the first hinge -------------------
        // A rounded rear pedestal.  It is part of the fixed body and
        // stops 0.60 mm short of the first child eye's swept circle.
        hull() {
            flat_ell([14.2, 0, 1.00], [1.85, 3.15, 1.35]);
            ell([14.2, 0, 14.8], [2.00, 4.20, 2.55]);
        }

        // Parent web from the tail stock through the C opening.
        parent_web(14.6, J1x);

        // First captive pin.
        translate([J1x, 0, 0]) parent_boss();
    }
}

/* ------------------------------------------------------------------ */
/*  Selection for complete model / individual part export              */
/* ------------------------------------------------------------------ */

module all_parts() {
    fixed_body();
    tail_link(J1x, J2x);
    tail_link(J2x, J3x);
    tail_link(J3x, 0);
}

if (part == "all") {
    all_parts();
} else if (part == "body") {
    fixed_body();
} else if (part == "tail1") {
    tail_link(J1x, J2x);
} else if (part == "tail2") {
    tail_link(J2x, J3x);
} else if (part == "tail3") {
    tail_link(J3x, 0);
} else {
    assert(false, str("Unknown part: ", part));
}

// Helpful for command-line regeneration/verification.
echo(str("part=", part, "  tail hinges at x=", J1x, ", ", J2x, ", ", J3x));
