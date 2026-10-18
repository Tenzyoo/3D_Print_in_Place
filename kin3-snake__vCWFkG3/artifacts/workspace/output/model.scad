// =====================================================================
//  Print-in-place articulated snake  (1 head + 5 body segments)
//  PLA / 0.4 mm nozzle / 0.2 mm layers, printed flat (Z up), no supports
//
//  Joint type: vertical (Z-axis) pin-in-socket.
//    * The rear part of every joint carries a vertical "pin" (knob) that is
//      joined to its body by a neck; the front part carries a C-shaped
//      socket ring around the pin.
//    * The pin has a 60-degree double-cone collar (bulge) in its middle;
//      the socket bore follows the same profile offset radially by
//      `clr` -> axial retention in both directions (pin cannot slide out
//      along Z), and radial retention because the socket wraps > 180 deg.
//    * Every surface in the joint is vertical or at 60 deg from horizontal
//      (30 deg from vertical), so nothing in the clearance needs support.
//
//  Usage:  openscad -D part=0 -o model.stl model.scad   (all parts)
//          openscad -D part=k -o parts_k.stl model.scad  (k = 1..6)
//  part 1 = head, parts 2..6 = body segments 1..5 (6 = tail tip)
//  Joint k (k=1..5) connects part k (front, socket) and part k+1 (rear, pin)
// =====================================================================

part = 0;                 // 0 = whole model, 1..6 = single part

/* ---------- global ---------- */
n_body     = 5;           // body segments
pitch      = 22;          // joint-to-joint distance  [mm]
H          = 12;          // body / joint height      [mm]
top_round  = 5;           // radius of rounded top edges of the body
$fn        = 128;

/* ---------- joint ---------- */
clr        = 0.5;         // radial clearance pin <-> bore, per side (0.4..0.6)
gap_body   = 0.6;         // radial gap socket ring <-> rear body
R_pin      = 5.5;         // pin radius (cylindrical bearing zones)
bulge      = 1.2;         // radial height of the retention collar
cone_ang   = 60;          // collar flank angle from horizontal (>=45 printable)
z_cone0    = 2.4;         // height where the lower collar flank starts
wall       = 2.4;         // min. socket wall thickness (at collar level)
neck_w     = 4.0;         // width of the neck that carries the pin
swing      = 34;          // free swing each side before the neck hits the socket
keep_ang   = 55;          // rear body is kept inside +/- keep_ang around -X

h_cone     = bulge * tan(cone_ang);                 // vertical size of a flank
R_ring     = R_pin + bulge + clr + wall;            // socket outer radius
W          = 2 * R_ring;                            // body width

/* ---------- head / tail ---------- */
tail_len   = 32;          // joint 5 -> tail tip centre
tip_r      = 1.6;
tip_h      = 5;           // height at the tail tip
head_ax    = [16, 12.5, 14.5];  // head ellipsoid semi-axes
head_dx    = 12;          // ellipsoid centre in front of joint 1
eye_r      = 2.2;
eye_pos    = [16, 7.8];   // relative to joint 1

/* ---------- derived positions ---------- */
// joint k (1..n_body) X position; tail tip touches x = 0
function JX(k) = tip_r + tail_len + (n_body - k) * pitch;

// =====================================================================
//  2D helpers
// =====================================================================
module at(k) translate([JX(k), 0]) children();

// pin profile (r, z) -- used for the pin and (offset by clr) for the bore
function pin_profile(off, z_lo, z_hi) = [
    [0, z_lo],
    [R_pin + off, z_lo],
    [R_pin + off, z_cone0],
    [R_pin + bulge + off, z_cone0 + h_cone],
    [R_pin + bulge + off, H - z_cone0 - h_cone],
    [R_pin + off, H - z_cone0],
    [R_pin + off, z_hi],
    [0, z_hi]
];

// neck rectangle in joint-local coordinates (pointing to -X)
module neck_2d(extra = 0)
    translate([-(R_ring + gap_body + 4), -(neck_w / 2 + extra)])
        square([R_ring + gap_body + 4, neck_w + 2 * extra]);

// region swept by the neck (+clearance) over +/- swing  -> socket opening
module sweep_2d() {
    st = 2;
    for (a = [-swing : st : swing - st])
        hull() {
            rotate(a)      neck_2d(clr);
            rotate(a + st) neck_2d(clr);
        }
}

// region in which the rear part may exist around its front joint
module rear_keep_2d()
    difference() {
        polygon([[0, 0], [-80, -80 * tan(keep_ang)], [-80, 80 * tan(keep_ang)]]);
        circle(r = R_ring + gap_body);
    }

// =====================================================================
//  3D helpers
// =====================================================================
// rounded-top "loaf" cross-section, extruded along X over the whole snake
module loaf(w = W, h = H, r = top_round)
    rotate([90, 0, 90]) translate([0, 0, -10])
        linear_extrude(300)
            hull() {
                translate([-w / 2, 0]) square([w, 0.01]);
                for (s = [-1, 1]) translate([s * (w / 2 - r), h - r]) circle(r);
            }

module pin_3d()
    rotate_extrude() polygon(pin_profile(0, 0, H + 1));

module bore_3d()
    rotate_extrude() polygon(pin_profile(clr, -1, H + 2));

// socket ring at joint k (belongs to part k)
module socket(k)
    translate([JX(k), 0, 0])
        difference() {
            linear_extrude(H) circle(r = R_ring);
            bore_3d();
            translate([0, 0, -1]) linear_extrude(H + 2) sweep_2d();
        }

// pin + neck at joint k (belongs to part k+1)
module pin_neck(k)
    translate([JX(k), 0, 0]) {
        pin_3d();
        linear_extrude(H) neck_2d();
    }

// =====================================================================
//  Parts
// =====================================================================
module head() {
    J = JX(1);
    difference() {
        union() {
            intersection() { socket(1); loaf(); }
            // ellipsoid skull, kept clear of the socket bore
            difference() {
                intersection() {
                    translate([J + head_dx, 0, 0]) scale(head_ax) sphere(1, $fn = 64);
                    translate([J - 30, -30, 0]) cube([80, 60, 40]);
                }
                translate([J, 0, -1]) cylinder(r = R_ring - 0.5, h = 50);
            }
            // eyes: vertical posts with domed tops (no overhang)
            for (s = [-1, 1]) {
                p = [eye_pos[0] - head_dx, s * eye_pos[1]];
                zt = head_ax[2] * sqrt(1 - pow(p[0] / head_ax[0], 2)
                                         - pow(p[1] / head_ax[1], 2)) + 0.6;
                translate([J + eye_pos[0], s * eye_pos[1], 0]) {
                    cylinder(r = eye_r, h = zt, $fn = 32);
                    translate([0, 0, zt]) sphere(eye_r, $fn = 32);
                }
            }
        }
        // keep the socket opening free over the full head height
        translate([J, 0, -1]) linear_extrude(50) sweep_2d();
    }
}

// body segment i = 1..n_body  (part i+1); front joint i, rear joint i+1
module body(i) {
    union() {
        intersection() {
            linear_extrude(H)
                intersection() {
                    hull() {
                        at(i) circle(r = R_ring);
                        if (i < n_body) at(i + 1) circle(r = R_ring);
                        else translate([tip_r, 0]) circle(r = tip_r, $fn = 24);
                    }
                    at(i) rear_keep_2d();
                }
            loaf();
            if (i == n_body)   // tail slopes down towards the tip
                hull() {
                    translate([JX(i) - R_ring - gap_body - 2, -15, 0])
                        cube([40, 30, H]);
                    translate([0, -15, 0]) cube([0.01, 30, tip_h]);
                }
        }
        // pin + neck of joint i
        intersection() { pin_neck(i); loaf(); }
        // socket ring of joint i+1 (rear end)
        if (i < n_body) intersection() { socket(i + 1); loaf(); }
    }
}

// body ring area is hollow (bore) -> subtract the bore of the rear joint
module body_part(i)
    difference() {
        body(i);
        if (i < n_body)
            translate([JX(i + 1), 0, 0]) {
                bore_3d();
                translate([0, 0, -1]) linear_extrude(H + 2) sweep_2d();
            }
    }

module snake_part(p) {
    if (p == 1) head();
    else body_part(p - 1);
}

if (part == 0) for (p = [1 : n_body + 1]) snake_part(p);
else snake_part(part);
