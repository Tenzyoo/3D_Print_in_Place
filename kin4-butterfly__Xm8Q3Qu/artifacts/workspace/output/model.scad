// =====================================================================
//  Print-in-place butterfly with two independently swinging wings
//  - 3 rigid parts: body (fixed), left wing (+Y), right wing (-Y)
//  - 2 revolute pin joints, axes parallel to Z, range >= +/-30 deg
//  - Printed flat in the assembled pose (Z up, bottom face on bed)
//  Units: mm.  X = body axis (head at +X), Y = span, Z = up.
//
//  Render one part:  openscad -D 'part="body"'  -o body.stl model.scad
//  part = "all" | "body" | "left" | "right"
// =====================================================================

part        = "all";
left_angle  = 0;      // preview only: wing rotation about its joint (deg)
right_angle = 0;

$fn = 72;

// ---------------- joint ----------------
joint_x   = 12;       // joint axis position along body
joint_y   = 12.5;     // |Y| of the two joint axes
joint_h   = 7.0;      // joint (pin / ring) height, from bed
pin_r     = 3.5;      // pin shaft radius
pin_clr   = 0.5;      // radial clearance pin <-> bore (one side), 0.4..0.6
gap       = 0.6;      // clearance ring OD <-> body notch
cone_ang  = 50;       // retention cone angle from horizontal (>45 => self supporting)
flare_dr  = 1.2;      // bottom flare: radial step (axial retention, -Z)
head_dr   = 1.4;      // countersunk head: radial step (axial retention, +Z)
head_len  = 1.6;      // cylindrical part of the head
ring_wall = 2.0;      // minimum ring wall at the head
ring_r    = pin_r + head_dr + pin_clr + ring_wall;   // wing ring outer radius
notch_r   = ring_r + gap;                            // body cut-out around ring
open_half = 57;       // half angle of the C-ring opening (toward body)
web_w     = 2.4;      // width of the web tying the pin to the body

// ---------------- motion clearance ----------------
swing          = 30;  // required range +/- swing
swing_margin   = 4;   // extra sweep used for clearing the wing outline
sweep_step     = 1;
wing_body_gap  = 0.8; // XY clearance wing plate <-> body over the sweep

// ---------------- wing ----------------
wing_t  = 2.4;        // plate thickness
deco_h  = 0.8;        // raised decoration on top of the plate
rim_w   = 1.2;
vein_w  = 0.9;

// ---------------- body ----------------
head_c   = [28.5, 0, 3.5];  head_r = 5.5;
eye_c    = [31, 4.3, 4.6];  eye_r  = 2.2;
thorax_c = [13, 0, 2];      thorax_rad = [11.5, 6.5, 9];
abd_n    = 7;               // abdomen segments
antenna_pts = [[31,1.5],[37,2.6],[43,3.9],[48,5.4],[52,7.4]];
antenna_w = 1.4;  antenna_h = 1.6;  club_r = 1.8;  club_h = 2.4;

function abd_seg(i) = [ [4 - i*6.2, 0, 1.0],                       // centre
                        [4.6, 5.2 - 0.45*i, 6.2 - 0.5*i] ];        // radii
function tz(dr) = dr * tan(cone_ang);

// pin profile in (r, z), extended beyond [0, joint_h] so the bore cuts through
z_hc = joint_h - head_len - tz(head_dr);
pin_profile = [
    [0, -3], [pin_r + flare_dr + 3/tan(cone_ang), -3],
    [pin_r + flare_dr, 0], [pin_r, tz(flare_dr)],
    [pin_r, z_hc], [pin_r + head_dr, z_hc + tz(head_dr)],
    [pin_r + head_dr, joint_h + 3], [0, joint_h + 3] ];

// ===================== joint geometry (local frame) =====================
// Local frame: origin on the joint axis, +Y = outboard (wing side).

module pin() {
    intersection() {
        rotate_extrude() polygon(pin_profile);
        translate([-20, -20, 0]) cube([40, 40, joint_h]);
    }
}

// bore = pin profile shifted outward by pin_clr: every layer sees the same
// 0.5 mm radial gap; the cones get a vertical gap of pin_clr*tan(cone_ang)
module pin_bore() {
    rotate_extrude() polygon([for (p = pin_profile) [p.x > 0 ? p.x + pin_clr : 0, p.y]]);
}

module opening_2d() {         // C-ring opening, centred on -Y (toward the body)
    polygon(concat([[0, 0]],
        [for (t = [-open_half : open_half/12 : open_half]) 3*ring_r*[sin(t), -cos(t)]]));
}

module web_2d() { translate([-web_w/2, -(notch_r + 2)]) square([web_w, notch_r + 2]); }

module wing_ring() {
    difference() {
        cylinder(r = ring_r, h = joint_h);
        pin_bore();
        translate([0, 0, -1]) linear_extrude(joint_h + 2) opening_2d();
    }
}

// ===================== body =====================
module ellipsoid(c, r) { translate(c) scale(r) sphere(1, $fn = 48); }

module antenna_2d() {
    for (i = [0 : len(antenna_pts) - 2])
        hull() { translate(antenna_pts[i]) circle(d = antenna_w, $fn = 16);
                 translate(antenna_pts[i+1]) circle(d = antenna_w, $fn = 16); }
}

module body_raw_3d() {
    intersection() {
        union() {
            translate(head_c) sphere(head_r, $fn = 48);
            for (s = [1, -1]) translate([eye_c.x, s*eye_c.y, eye_c.z])
                hull() { sphere(eye_r, $fn = 32);                         // eye with a
                         translate([0, 0, -(eye_c.z + 0.5)]) sphere(0.2, $fn = 8); } // cone down to the bed
            ellipsoid(thorax_c, thorax_rad);
            for (i = [0 : abd_n - 1]) ellipsoid(abd_seg(i)[0], abd_seg(i)[1]);
            ellipsoid([-36, 0, 0.8], [5, 2.6, 3.4]);                   // tail tip
        }
        translate([-100, -100, 0]) cube([200, 200, 50]);
    }
    for (s = [1, -1]) mirror([0, s < 0 ? 1 : 0, 0]) {
        linear_extrude(antenna_h) antenna_2d();
        translate(antenna_pts[len(antenna_pts) - 1]) cylinder(r = club_r, h = club_h, $fn = 32);
    }
}

// XY footprint of body_raw_3d (largest section of every primitive)
module body_raw_2d() {
    translate([head_c.x, head_c.y]) circle(head_r, $fn = 48);
    for (s = [1, -1]) translate([eye_c.x, s*eye_c.y]) circle(eye_r, $fn = 32);
    translate([thorax_c.x, thorax_c.y]) scale([thorax_rad.x, thorax_rad.y]) circle(1, $fn = 48);
    for (i = [0 : abd_n - 1]) translate([abd_seg(i)[0].x, 0])
        scale([abd_seg(i)[1].x, abd_seg(i)[1].y]) circle(1, $fn = 48);
    translate([-36, 0]) scale([5, 2.6]) circle(1, $fn = 32);
    for (s = [1, -1]) mirror([0, s < 0 ? 1 : 0]) {
        antenna_2d();
        translate(antenna_pts[len(antenna_pts) - 1]) circle(r = club_r, $fn = 32);
    }
}

module body_2d() {
    difference() {
        body_raw_2d();
        for (s = [1, -1]) translate([joint_x, s*joint_y]) circle(notch_r);
    }
    for (s = [1, -1]) translate([joint_x, s*joint_y]) mirror([0, s < 0 ? 1 : 0]) web_2d();
}

module body() {
    difference() {
        body_raw_3d();
        for (s = [1, -1]) translate([joint_x, s*joint_y, -1]) cylinder(r = notch_r, h = 60);
    }
    for (s = [1, -1]) translate([joint_x, s*joint_y, 0]) mirror([0, s < 0 ? 1 : 0, 0]) {
        pin();
        linear_extrude(joint_h) web_2d();
    }
}

// ===================== wing (local frame of the left joint) =====================
// (v, u) = (forward, outboard) relative to the joint axis
wing_outline_pts = [
    // root / leading edge of the forewing
    [0, 4.5], [3, 6], [9, 9.5], [16, 14], [22, 19.5], [26, 25], [28.5, 30], [29, 34],
    // forewing tip and outer margin
    [27, 36.6], [21, 36.9], [14, 36], [9, 34.2], [5, 31.8], [2.5, 29.5],
    // hindwing outer margin and swallow tail
    [0, 29.5], [-4, 30.6], [-9, 30.4], [-14, 28.4], [-18.5, 25], [-21.5, 21],
    [-23.5, 17.5], [-27, 14.5], [-31, 12], [-30, 9.4], [-25, 8.3], [-19, 7.2],
    [-12, 6], [-6, 5], [-3, 4.5] ];

module wing_outline_2d() {
    offset(r = 1.5) offset(delta = -1.5)          // round convex corners
    offset(r = -2)  offset(delta = 2)             // round concave corners
        polygon(wing_outline_pts);
}

// everything the plate may never touch: the body footprint (plus clearance)
// rotated through the full swing about this joint, seen from the wing frame
module sweep_clear_2d() {
    for (a = [-(swing + swing_margin) : sweep_step : swing + swing_margin])
        rotate(-a) translate([-joint_x, -joint_y]) offset(r = wing_body_gap) body_2d();
}

module wing_plate_2d() {
    difference() {
        wing_outline_2d();
        circle(r = ring_r - 0.5);                 // ring replaces the plate here
        sweep_clear_2d();
    }
}

module wing_deco_2d() {
    intersection() {
        offset(delta = -0.01) wing_plate_2d();
        union() {
            difference() { wing_plate_2d(); offset(r = -rim_w) wing_plate_2d(); }   // rim
            // veins radiating from the root
            for (p = [[28, 34], [22, 37], [15, 36.5], [8, 34], [-4, 31], [-11, 30],
                      [-18, 26], [-24, 18], [-30, 11]])
                hull() { translate([0.25*p.x, 7.5]) circle(d = vein_w, $fn = 12);
                         translate(p) circle(d = vein_w, $fn = 12); }
            // discal cell
            difference() { translate([3, 16]) scale([9, 6]) circle(1, $fn = 40);
                           translate([3, 16]) scale([9 - vein_w, 6 - vein_w]) circle(1, $fn = 40); }
            // eye spots
            for (e = [[16, 29, 3.6], [-15, 22, 3.2]]) translate([e.x, e.y]) {
                difference() { circle(e[2], $fn = 40); circle(e[2] - 1.0, $fn = 40); }
                circle(e[2] * 0.4, $fn = 24);
            }
            // margin dots
            for (d = [[22, 34.3], [17.5, 34.1], [12.5, 33.4], [-7, 28.3], [-12.5, 26.4], [-17, 23.2]])
                translate(d) circle(0.9, $fn = 16);
        }
    }
}

module wing_local() {
    wing_ring();
    linear_extrude(wing_t) wing_plate_2d();
    translate([0, 0, wing_t - 0.01]) linear_extrude(deco_h + 0.01) wing_deco_2d();
}

// v,u frame -> joint frame (x = v, y = u)
module left_wing()  { translate([joint_x,  joint_y, 0]) rotate([0, 0, left_angle])  wing_local(); }
module right_wing() { mirror([0, 1, 0]) translate([joint_x, joint_y, 0]) rotate([0, 0, -right_angle]) wing_local(); }

if (part == "body")  body();
if (part == "left")  left_wing();
if (part == "right") right_wing();
if (part == "all")   { body(); left_wing(); right_wing(); }
