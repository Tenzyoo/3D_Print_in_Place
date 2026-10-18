// ============================================================================
//  PRINT-IN-PLACE FLAPPING BUTTERFLY
//  Parametric OpenSCAD source - FDM / PLA / 0.4 mm nozzle / 0.2 mm layer
// ============================================================================
//
//  Three rigid bodies, printed in their assembled state in one job:
//    1. torso       (fixed; includes both joint pins and both axial caps)
//    2. left wing   (+Y; revolute joint about +Z at (0, +PIVOT_Y))
//    3. right wing  (-Y; revolute joint about +Z at (0, -PIVOT_Y))
//
//  Delivery / neutral pose:
//    X = body longitudinal axis, head towards +X
//    Y = left/right wing span, +Y = left wing
//    Z = vertical direction = build direction
//    Both wings are at 0 deg.  Each wing can swing independently at least
//    -30 deg .. +30 deg in the XY plane.
//
//  Print orientation:
//    Flat on the build plate, Z up.  Every body starts at Z = 0.
//    No support material is used anywhere, and in particular no support is
//    present in any joint clearance.
//
//  Joint construction (both sides identical, mirrored):
//    * fixed vertical pin (R = 2.50 mm) on the torso
//    * wing bearing bore (R = 3.00 mm), giving 0.50 mm radial clearance
//    * lower flange on the pin + shoulder inside the wing = lower axial stop
//    * mushroom cap on top of the pin, overlapping the wing top = upper
//      axial stop.  The wing is therefore mechanically captive in Z and
//      cannot be pulled straight off the pin.
//    * the pin is tied to the torso by a 0.80 mm high bed-level shoulder;
//      a 130 deg lower-root relief in the wing clears this shoulder through
//      the whole +-30 deg stroke.
//    * the wing's 45 deg bearing shoulder is self-supporting, so the joint
//      gap is pure air and never depends on support material.
//
// ============================================================================

// ------------------------------- export part -------------------------------
// "all" | "torso" | "left_wing" | "right_wing"
PART = "all";

// -------------------------------- process ----------------------------------
LAYER_H       = 0.20;   // mm
NOZZLE_D      = 0.40;   // mm
$fn           = 96;

// --------------------------- joint clearances ------------------------------
RADIAL_CLEAR  = 0.50;   // mm per side, pin/bore (requirement: 0.40..0.60)
AXIAL_TOP     = 0.60;   // mm, wing top to underside of mushroom cap
AXIAL_BOT     = 0.55;   // mm, wing shoulder to top of lower flange

// ------------------------------ torso envelope -----------------------------
BODY_Z        = 3.20;   // mm, main torso plate thickness
THORAX_Z      = 5.00;   // mm, highest point of the raised thorax
BODY_HALF_W   = 5.80;   // mm, thorax half width at the wing roots
HEAD_X        = 24.0;   // mm, head centre
HEAD_R        = 5.20;   // mm
ABDOMEN_X     = -23.0;  // mm
ABDOMEN_RX    = 15.50;  // mm
ABDOMEN_RY    = 5.20;   // mm

// ------------------------------ wing / joint -------------------------------
PIVOT_Y       = 13.50;  // mm, |Y| of each wing pivot
PIN_R         = 2.50;   // mm, fixed torso pin
WING_HOLE_R   = PIN_R + RADIAL_CLEAR;       // 3.00 mm
FLANGE_R      = 4.20;   // mm, lower axial-retaining flange
CBORE_R       = FLANGE_R + RADIAL_CLEAR;    // 4.70 mm
FLANGE_H      = 0.80;   // mm, lower flange height (4 layers)
CBORE_H       = FLANGE_H + AXIAL_BOT - RADIAL_CLEAR;  // 0.85 mm
WING_T        = 3.20;   // mm, wing plate thickness
HUB_R         = 6.20;   // mm, circular rotating root hub
SHOULDER_RISE = CBORE_R - WING_HOLE_R;      // 1.70 mm (45 deg)

// Upper mushroom cap: 45 deg self-supporting underside, then flat top.
CAP_Z0        = WING_T + AXIAL_TOP;         // 3.80 mm
CAP_R         = 4.20;   // mm, cap rim radius (> WING_HOLE_R)
CAP_CONE_H    = 1.70;   // mm (45 deg from horizontal)
CAP_TOP_H     = 0.70;   // mm
CAP_TOP_Z     = CAP_Z0 + CAP_CONE_H + CAP_TOP_H;  // 6.20 mm

// Bed-level shoulder linking pin to torso, and wing-root relief angle.
ARM_R_BODY    = 2.20;   // mm
ARM_R_PIVOT   = 1.60;   // mm
CUT_HALF_ANG  = 65;     // deg; 130 deg relief facing inboard (-Y)

// Wing outline in local (v,u) coordinates:
//   v = local X; u = distance outward from the pivot (+Y for the left wing)
WING_OUTLINE = [
    [  2.5,  4.0], [  8.0,  8.5], [ 16.0, 12.0], [ 24.0, 16.5],
    [ 30.0, 22.0], [ 31.0, 27.5], [ 28.0, 32.2], [ 22.0, 35.2],
    [ 14.0, 35.8], [  7.0, 34.0], [  3.0, 29.0], [ -4.0, 33.0],
    [-12.0, 33.5], [-20.0, 30.0], [-27.0, 24.0], [-29.0, 18.0],
    [-26.0, 12.0], [-19.0,  8.0], [ -9.0,  6.0], [ -2.5,  4.0]
];

// ------------------------------- 2D helpers --------------------------------
module ellipse2d(cx, cy, rx, ry) {
    translate([cx, cy]) scale([rx, ry]) circle(r = 1);
}

module wing_root_relief_2d() {
    // 130 deg sector facing inboard.  It removes the lower/inner part of the
    // hub ring so the fixed bed-level shoulder can pass through while the
    // wing rotates.  The remaining 230 deg ring still carries the bearing
    // shoulder and the upper retaining cap.
    pts = concat(
        [[0, 0]],
        [for (a = [-90 - CUT_HALF_ANG : 5 : -90 + CUT_HALF_ANG])
            [12 * cos(a), 12 * sin(a)]]
    );
    polygon(points = pts);
}

module wing_vein_grooves_2d() {
    // Recessed top decoration only.  It starts at u >= 10 mm, well outside
    // the cap radius and the pin, so it cannot influence joint motion.
    vein = 0.55;
    segs = [
        [[  2.0, 10.5], [ 12.0, 18.0]], [[ 12.0, 18.0], [ 25.0, 27.0]],
        [[  0.0, 11.0], [  8.0, 21.0]], [[  8.0, 21.0], [ 19.0, 32.0]],
        [[ -2.5, 11.0], [  1.0, 22.0]], [[  1.0, 22.0], [  7.0, 32.0]],
        [[ -5.0, 10.5], [ -7.0, 21.0]], [[ -7.0, 21.0], [-10.0, 30.0]],
        [[ -6.5, 10.0], [-15.0, 17.0]], [[-15.0, 17.0], [-25.0, 22.5]],
        [[  4.0, 24.0], [ 12.0, 26.0]], [[ 12.0, 26.0], [ 20.0, 29.0]],
        [[ -8.0, 24.0], [ -4.0, 26.0]], [[ -4.0, 26.0], [  2.0, 27.5]]
    ];
    for (s = segs) {
        hull() {
            translate(s[0]) circle(d = vein);
            translate(s[1]) circle(d = vein);
        }
    }
    for (p = [[13.5, 27.0, 1.05], [20.5, 30.0, 0.90], [-14.5, 24.0, 0.95]]) {
        translate([p[0], p[1]]) circle(r = p[2]);
    }
}

module wing_outline_2d() {
    polygon(points = WING_OUTLINE);
}

// ============================================================================
//  TORSO - fixed body, including both pins, flanges, bed shoulders and caps
// ============================================================================
module torso_footprint_2d() {
    union() {
        ellipse2d(ABDOMEN_X, 0, ABDOMEN_RX, ABDOMEN_RY);  // abdomen
        ellipse2d( -9.0, 0, 8.00, 4.80);                 // waist
        ellipse2d(  0.0, 0, 10.0, BODY_HALF_W);          // thorax
        ellipse2d(  9.0, 0, 5.20, 4.20);                 // neck
        ellipse2d(HEAD_X, 0, HEAD_R, HEAD_R);             // head
        // solid neck bridge, so head + torso are one rigid body
        hull() {
            ellipse2d(  9.0, 0, 5.20, 4.20);
            ellipse2d(HEAD_X, 0, HEAD_R, HEAD_R);
        }
        // flat antennae, kept inside |Y| < 6.8 mm
        for (s = [-1, 1]) {
            hull() {
                translate([27.5, s * 2.20]) circle(d = 0.90);
                translate([33.5, s * 5.20]) circle(d = 0.70);
            }
            hull() {
                translate([33.5, s * 5.20]) circle(d = 0.70);
                translate([39.8, s * 4.40]) circle(d = 0.80);
            }
            translate([39.8, s * 4.40]) circle(d = 2.60);
        }
    }
}

module torso() {
    difference() {
        union() {
            // main torso plate
            linear_extrude(height = BODY_Z) torso_footprint_2d();

            // raised, stepped thorax (self-supporting inset steps)
            translate([0, 0, BODY_Z])
                linear_extrude(height = 0.60) ellipse2d(0, 0, 9.80, 5.45);
            translate([0, 0, BODY_Z + 0.60])
                linear_extrude(height = THORAX_Z - (BODY_Z + 0.60))
                    ellipse2d(0, 0, 8.80, 4.80);

            // raised compound eyes
            for (s = [-1, 1])
                translate([HEAD_X + 2.0, s * 3.0, BODY_Z - 0.30])
                    cylinder(h = 0.55, r = 1.15);

            // two mirror-identical pin / flange / cap assemblies
            for (s = [-1, 1]) {
                // lower axial retaining flange, on the build plate
                translate([0, s * PIVOT_Y, 0])
                    cylinder(h = FLANGE_H, r = FLANGE_R);

                // bed-level shoulder: ties the pin to the fixed torso and
                // stays below the wing while the wing swings.  It is printed
                // directly on the bed, so it needs no support.
                translate([0, 0, 0])
                    linear_extrude(height = FLANGE_H)
                        hull() {
                            translate([0, s * 4.80]) circle(r = ARM_R_BODY);
                            translate([0, s * PIVOT_Y]) circle(r = ARM_R_PIVOT);
                        }

                // fixed pin, from the bed to the top of the mushroom cap
                translate([0, s * PIVOT_Y, 0])
                    cylinder(h = CAP_TOP_Z, r = PIN_R);

                // upper axial retainer: 45 deg self-supporting cone + rim
                translate([0, s * PIVOT_Y, CAP_Z0]) {
                    cylinder(h = CAP_CONE_H, r1 = PIN_R, r2 = CAP_R);
                    translate([0, 0, CAP_CONE_H])
                        cylinder(h = CAP_TOP_H, r = CAP_R);
                }
            }
        }

        // abdomen segmentation grooves (decoration, 0.30 mm deep)
        for (x = [-31.0, -26.0, -21.0, -16.0])
            translate([x, 0, BODY_Z - 0.30])
                cube([0.65, 13.0, 0.32], center = true);

        // eye pupils
        for (s = [-1, 1])
            translate([HEAD_X + 2.0, s * 3.0, BODY_Z + 0.02])
                cylinder(h = 0.34, r = 0.62);
    }
}

// ============================================================================
//  LEFT WING (+Y); the right wing is an exact mirror
// ============================================================================
module left_wing() {
    difference() {
        union() {
            translate([0, PIVOT_Y, 0])
                linear_extrude(height = WING_T) wing_outline_2d();
            translate([0, PIVOT_Y, 0])
                cylinder(h = WING_T, r = HUB_R);
        }

        // Bearing bore: counterbore over the lower flange, 45 deg
        // self-supporting shoulder, then the 3.00 mm running bore.
        translate([0, PIVOT_Y, 0]) {
            cylinder(h = CBORE_H + 0.01, r = CBORE_R);
            translate([0, 0, CBORE_H])
                cylinder(h = SHOULDER_RISE,
                         r1 = CBORE_R, r2 = WING_HOLE_R);
            translate([0, 0, CBORE_H + SHOULDER_RISE - 0.01])
                cylinder(h = WING_T - CBORE_H - SHOULDER_RISE + 0.02,
                         r = WING_HOLE_R);
        }

        // inboard relief for the fixed bed shoulder; open through the full
        // wing thickness so no unsupported bridge is created in the gap
        translate([0, PIVOT_Y, -0.01])
            linear_extrude(height = WING_T + 0.02)
                wing_root_relief_2d();

        // recessed wing veins and spots (0.35 mm deep)
        translate([0, PIVOT_Y, WING_T - 0.35])
            linear_extrude(height = 0.36) wing_vein_grooves_2d();
    }
}

module right_wing() {
    mirror([0, 1, 0]) left_wing();
}

// ============================================================================
//  EXPORT SELECTION
// ============================================================================
if (PART == "all") {
    torso();
    left_wing();
    right_wing();
} else if (PART == "torso") {
    torso();
} else if (PART == "left_wing") {
    left_wing();
} else if (PART == "right_wing") {
    right_wing();
} else {
    assert(false, "PART must be all, torso, left_wing or right_wing");
}
