// =====================================================================
//  Print-in-place articulated butterfly  (PLA, 0.4 mm nozzle, 0.2 mm layer)
//  3 rigid parts : 1 = body (fixed), 2 = left wing (+Y), 3 = right wing (-Y)
//  2 revolute joints, axes parallel to +Z, wings swing in the XY plane.
//  Frame: X = body axis (head at +X), Y = wing span (left = +Y), Z = up.
//  Print orientation: exactly as modelled, Z up, everything on the bed (z = 0).
// =====================================================================

/* ---------------- render control ---------------- */
part    = 0;    // 0 = full assembly, 1 = body, 2 = left wing, 3 = right wing
angle_L = 0;    // left  wing rotation about its joint axis (+Z, right-hand rule), deg
angle_R = 0;    // right wing rotation about its joint axis (+Z, right-hand rule), deg

/* ---------------- joint parameters --------------- */
joint_x     = 0;     // joint axis X position
joint_y     = 11;    // joint axis |Y| position (left +, right -)
pin_r       = 2.5;   // pin shaft radius (D 5 mm)
clr         = 0.5;   // radial / normal clearance pin <-> wing eye (0.4..0.6 required)
flange_c    = 1.5;   // lower anti-drop flange: radial over-size of the pin foot
flange_foot = 0.4;   // vertical foot of the flange (avoid knife edge on layer 1)
ring_r      = 7;     // wing eye (ring) outer radius
ring_h      = 5;     // wing eye height
cap_gap     = 0.3;   // shaft extension above the ring before the 45 deg cap cone
cap_r       = 7.5;   // retaining cap max radius
cap_top     = 13;    // retaining cap top height
void_clr    = 0.5;   // clearance between ring outer surface and body
sweep_max   = 34;    // body is kept clear of the wing sweep over +-sweep_max deg
sweep_step  = 2;
sweep_clr   = 0.8;   // extra XY clearance around the swept wing envelope

/* ---------------- wing parameters ---------------- */
wing_t   = 2.0;      // wing plate thickness (10 layers)
deco_h   = 0.6;      // raised vein / pattern height (3 layers)
vein_w   = 1.0;
rim_w    = 1.4;

$fn = 48;
fj  = 128;           // facet count for joint surfaces

JL = [joint_x,  joint_y];
JR = [joint_x, -joint_y];

/* =====================================================================
   Joint profiles (r,z half-sections, revolved about the joint axis)
   ===================================================================== */
// Pin (part of the body): 45deg flange foot - shaft - 45deg cap cone - cap
module pin_profile() {
    polygon([[0, 0],
             [pin_r + flange_c, 0],
             [pin_r + flange_c, flange_foot],
             [pin_r, flange_foot + flange_c],
             [pin_r, ring_h + cap_gap],
             [cap_r, ring_h + cap_gap + (cap_r - pin_r)],
             [cap_r, cap_top - 1],
             [cap_r - 1, cap_top],
             [0, cap_top]]);
}
// Pin grown by the clearance -> removed from the wing (hole + cap clearance)
module pin_clear_profile() {
    intersection() {
        offset(r = clr, $fn = 64) pin_profile();
        translate([0, -5]) square([40, 40]);
    }
}
// Space reserved around the wing eye inside the body: cylinder + 45deg spire
module void_profile() {
    R = ring_r + void_clr;
    Z = ring_h + void_clr;
    polygon([[0, -1], [R, -1], [R, Z], [0, Z + R]]);
}

/* =====================================================================
   Wing (left wing, neutral pose, global coordinates)
   ===================================================================== */
wing_pts = [
    [3, 14], [5, 17], [12, 21.5], [22, 28], [32, 35], [40, 41.5], [44, 45.5],
    [43, 48.2], [38, 49.2], [30, 49.3], [20, 48.8], [10, 47.8], [3, 46.5],
    [0, 45],                                           // fore / hind wing notch
    [-4, 46.8], [-12, 48.6], [-22, 49.2], [-31, 48], [-38, 45.5], [-43, 43.8],
    [-49, 45.6], [-53, 45.2], [-54.5, 42.8], [-51, 40.2], [-45, 38],  // swallow tail
    [-38, 34], [-28, 28], [-18, 22.5], [-10, 18.5], [-5, 17], [-3, 14]];

module wing2d() { offset(r = 1.2) offset(delta = -1.2) polygon(wing_pts); }

vein_root = [0, 15.5];
vein_ends = [[41, 45], [34, 47.6], [25, 47.6], [15, 46.6], [6, 45.4],
             [-7, 46.4], [-17, 47.6], [-28, 46.8], [-38, 43.2], [-51, 42.6],
             [-36, 37], [24, 31]];

module seg2d(a, b, w) { hull() { translate(a) circle(d = w); translate(b) circle(d = w); } }
module ring2d(c, ro, w) { translate(c) difference() { circle(r = ro); circle(r = ro - w); } }

module wing_deco2d() {
    intersection() {
        offset(delta = -0.2) wing2d();
        union() {
            difference() { wing2d(); offset(delta = -rim_w) wing2d(); }   // border rim
            for (e = vein_ends) seg2d(vein_root, e, vein_w);              // radial veins
            seg2d([8, 24], [-8, 24], vein_w);                             // discal bar
            seg2d([20, 33], [3, 41], vein_w);                             // cross veins
            seg2d([-14, 31], [-26, 38], vein_w);
            ring2d([30, 42.5], 3.6, 1.0); translate([30, 42.5]) circle(r = 1.4);   // fore eyespot
            ring2d([-30, 41.5], 4.2, 1.0); translate([-30, 41.5]) circle(r = 1.8); // hind eyespot
            for (p = [[38, 46.2], [33.5, 47.6], [18, 46.2], [10, 45.3], [-11, 46.5], [-21, 46.9]])
                translate(p) circle(r = 1.0);                            // marginal dots
            translate([-51.8, 43.3]) circle(r = 1.2);                     // tail spot
        }
    }
}

// Tapered root gusset between the eye (h = ring_h) and the plate (h = wing_t)
module wing_gusset() {
    gusset_len = 5;                                   // gusset reaches plate height 5 mm outside the eye
    r_far = ring_r + ring_h * gusset_len / (ring_h - wing_t);   // cone radius at z = 0
    intersection() {
        linear_extrude(ring_h) wing2d();
        translate([JL[0], JL[1], 0]) cylinder(h = ring_h, r1 = r_far, r2 = ring_r, $fn = fj);
    }
}

module wing_left_neutral() {
    difference() {
        union() {
            linear_extrude(wing_t) wing2d();
            translate([0, 0, wing_t - 0.01]) linear_extrude(deco_h + 0.01) wing_deco2d();
            wing_gusset();
            translate([JL[0], JL[1], 0]) cylinder(r = ring_r, h = ring_h, $fn = fj);
        }
        translate([JL[0], JL[1], 0]) rotate_extrude($fn = fj) pin_clear_profile();
    }
}

module wing_left(a)  { translate([JL[0], JL[1], 0]) rotate([0, 0, a]) translate([-JL[0], -JL[1], 0]) wing_left_neutral(); }
module wing_right(a) { translate([JR[0], JR[1], 0]) rotate([0, 0, a]) translate([-JR[0], -JR[1], 0])
                         mirror([0, 1, 0]) wing_left_neutral(); }

// XY footprint swept by the left wing over +-sweep_max (eye itself excluded)
module sweep_left2d() {
    offset(delta = sweep_clr)
    difference() {
        union() for (a = [-sweep_max : sweep_step : sweep_max])
            translate(JL) rotate(a) translate(-JL) wing2d();
        translate(JL) circle(r = ring_r + void_clr, $fn = fj);
    }
}

/* =====================================================================
   Body (fixed part)
   ===================================================================== */
// sphere with a conical underside (cone half-angle 30deg from vertical -> self-supporting)
module drop(c, r, half_angle = 30) {
    translate(c) hull() { sphere(r = r); translate([0, 0, -r / sin(half_angle)]) sphere(r = 0.01, $fn = 8); }
}
module ellipsoid(c, s) { translate(c) scale(s) sphere(r = 1); }

module antenna(sy) {
    pts = [[21, 2, 9.5], [29, 3.8, 6.5], [37, 6.0, 4.4], [44, 8.6, 3.2], [48.5, 10.4, 2.6]];
    for (i = [0 : len(pts) - 2])
        hull() for (p = [pts[i], pts[i + 1]])
            translate([p[0], sy * p[1], 0]) cylinder(d = 1.6, h = p[2], $fn = 16);
    // low foot strip under the antenna (bed adhesion), 3.2 mm wide, 2 layers
    for (i = [0 : len(pts) - 2])
        hull() for (p = [pts[i], pts[i + 1]])
            translate([p[0], sy * p[1], 0]) cylinder(d = 3.2, h = 0.4, $fn = 16);
    translate([49.5, sy * 10.9, 0]) cylinder(r1 = 2.4, r2 = 1.6, h = 3.0, $fn = 32);  // club
}

module body_shell() {
    // thorax
    ellipsoid([0, 0, 5], [13, 9, 9.5]);
    // thorax dorsal tufts (decorative ridge)
    for (x = [-6, 0, 6]) ellipsoid([x, 0, 12.2], [3.2, 2.2, 2.6]);
    // head + compound eyes
    drop([18, 0, 5.5], 6.2);
    for (sy = [1, -1]) drop([21, sy * 3.9, 7.0], 2.9, 40);     // cone apex ends inside the head
    // abdomen: 8 tapering segments
    for (i = [0 : 7]) {
        R = 5.6 - 0.4 * i;
        ellipsoid([-12.5 - 4.6 * i, 0, 0.6 * R], [1.3 * R, R, R]);
    }
    // low ventral keel joining the segment footprints (bed adhesion), 1 mm high
    for (i = [0 : 6]) hull() for (k = [i, i + 1]) {
        R = 5.6 - 0.4 * k;
        translate([-12.5 - 4.6 * k, 0, 0]) scale([1.2, 1, 1]) cylinder(r = 0.7 * R, h = 1.0);
    }
    // antennae (standing walls, no overhang)
    for (sy = [1, -1]) antenna(sy);
}

module body() {
    union() {
        difference() {
            body_shell();
            for (J = [JL, JR]) translate([J[0], J[1], 0]) rotate_extrude($fn = fj) void_profile();
            translate([0, 0, -1]) linear_extrude(60) sweep_left2d();
            translate([0, 0, -1]) linear_extrude(60) mirror([0, 1, 0]) sweep_left2d();
            translate([-200, -200, -50]) cube([400, 400, 50]);       // flat bottom z = 0
        }
        for (J = [JL, JR]) translate([J[0], J[1], 0]) rotate_extrude($fn = fj) pin_profile();
    }
}

/* =====================================================================
   Output
   ===================================================================== */
if (part == 0 || part == 1) body();
if (part == 0 || part == 2) wing_left(angle_L);
if (part == 0 || part == 3) wing_right(angle_R);
