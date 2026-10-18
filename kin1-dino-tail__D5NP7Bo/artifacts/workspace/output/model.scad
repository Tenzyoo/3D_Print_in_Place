// Print-in-place articulated dinosaur (sauropod) — OpenSCAD source
// Fixed body (head + torso + 4 legs) and 3 tail segments, joined by
// 3 Z-axis pin joints. All parts print together in the assembled pose,
// flat on the bed, PLA / 0.4 mm nozzle / 0.2 mm layers, no supports.
//
// Coordinate system (mm): +X = toward head, +Y = left, +Z = up (build
// direction), bed at Z = 0. Tail tip near X = 0.
//
// Render a single part with:  openscad -D part=N -o parts_N.stl model.scad
//   part = 0 : complete model (all parts, assembled, neutral pose)
//   part = 1 : fixed body (head, neck, torso, 4 legs)
//   part = 2 : tail segment 1 (child of joint J1, parent of J2)
//   part = 3 : tail segment 2 (child of J2, parent of J3)
//   part = 4 : tail segment 3 / tail tip (child of J3)

part = 0;

// ---------------------------------------------------------------- quality
$fn  = 48;          // organic shapes
fnj  = 96;          // joint surfaces (pin, hole, cones)

// ---------------------------------------------------------------- joint
clr  = 0.5;         // radial / normal clearance between moving surfaces
rp   = 2.0;         // pin shaft radius (4 mm pin)
be   = 1.2;         // retaining bead radial height on the pin
zb0  = 0.4;         // bead starts 2 layers above the bed
sh   = 1.6;         // straight shaft between bead and mushroom cone
ka   = 45;          // cone / bead flank angle from horizontal (self-supporting)
k    = tan(ka);
zh0  = zb0 + 2*be*k + sh;   // height where the mushroom cone starts
Rc   = 5.5;         // child ring (knuckle) outer radius
Rm   = 7.0;         // mushroom cap radius (> Rc + clr, overlaps socket wall)
Rs   = 8.0;         // parent socket collar outer radius
Htop = 11.0;        // joint / collar top height
dp   = 1.5;         // parent material only at local x >= +dp
dc   = 4.0;         // child arm material only at local x <= -dc

// joint axes (all parallel to +Z, through (x, y, 0))
J = [[46, 0], [31, 0], [16, 0]];

// ---------------------------------------------------------------- joint 2D profiles (r, z)
// parent pin: shaft + diamond retaining bead + 45 deg mushroom cone + cap
module pin2d(top, zbot = 0) {
    polygon([[0, zbot], [rp, zbot], [rp, zb0], [rp + be, zb0 + be*k],
             [rp, zb0 + 2*be*k], [rp, zh0], [Rm, zh0 + (Rm - rp)*k],
             [Rm, top], [0, top]]);
}
// region the child must stay out of = pin profile grown by clr (normal offset)
module cavity2d() {
    intersection() {
        offset(r = clr, $fn = 64) pin2d(200, -5);
        translate([0, -10]) square([50, 300]);
    }
}
// socket hollow in the parent around the child ring, ceiling = mushroom cone
module hollow2d() {
    re = Rc + clr;
    polygon([[0, -1], [re, -1], [re, zh0 + (re - rp)*k + 0.02],
             [rp, zh0 + 0.02], [0, zh0 + 0.02]]);
}

module at(j) translate([J[j][0], J[j][1], 0]) children();

module pin(j)    at(j) rotate_extrude($fn = fnj) pin2d(Htop);
module cavity(j) at(j) rotate_extrude($fn = fnj) cavity2d();
module hollow(j) at(j) rotate_extrude($fn = fnj) hollow2d();
module ring(j)   at(j) cylinder(r = Rc, h = Htop + 4, $fn = fnj);
module collar(j) at(j) intersection() {
    cylinder(r = Rs, h = Htop, $fn = fnj);
    translate([dp, -50, -1]) cube([100, 100, 100]);
}
// half-spaces used to keep parent / child arm clear of each other
module parent_side(j) at(j) translate([dp, -60, -1]) cube([200, 120, 100]);
module child_side(j)  at(j) translate([-dc - 200, -60, -1]) cube([200, 120, 100]);

// parent side of joint j applied to children()
module jparent(j) {
    union() {
        difference() {
            union() { children(); collar(j); }
            hollow(j);
        }
        pin(j);
    }
}
// child side of joint j applied to children()
module jchild(j) {
    difference() {
        union() { children(); ring(j); }
        cavity(j);
    }
}

// ---------------------------------------------------------------- shape helpers
// "loaf": vertical walls to half height then elliptical dome; widest at the
// bed, so hulls of loaves never overhang
module loaf(p, w, h, l = -1) {
    ll = l < 0 ? w : l;
    translate([p[0], p[1], 0]) scale([ll, w, h]) hull() {
        cylinder(r = 1, h = 0.5);
        translate([0, 0, 0.5]) scale([1, 1, 0.5]) intersection() {
            sphere(1);
            translate([-2, -2, 0]) cube(4);
        }
    }
}
// teardrop: sphere with a 45 deg cone underneath (self-supporting blob)
module drop(p, r) translate(p) hull() {
    sphere(r);
    translate([0, 0, -r*sqrt(2)]) cylinder(r1 = 0.01, r2 = 0.01, h = 0.01);
}

// ---------------------------------------------------------------- body
legs = [[55, 8.5], [55, -8.5], [69, 8.5], [69, -8.5]];
leg_top = 12;

module core() {
    hull() {
        translate([61, 0, 27]) scale([15, 12, 9.5]) sphere(1);
        translate([72, 0, 27]) sphere(8.5);
    }
}
// core with its shadow: vertical flanks down to the bed
module core_env() {
    hull() {
        core();
        translate([61, 0, 0]) scale([15, 12, 0.01]) sphere(1);
        translate([72, 0, 0]) scale([8.5, 8.5, 0.01]) sphere(1);
        loaf([50, 0], 8.6, 13, 6);
    }
}
// 45 deg "printability" cones rising from every supported base (leg tops and
// the tail root on the bed). Body material is limited to their union, which
// carves self-supporting arches between the legs.
body_ka = 45;       // arch flank angle from horizontal
module support_cones() {
    g = 60 / tan(body_ka);
    for (p = legs) translate([p[0], p[1], leg_top - 0.01])
        cylinder(r1 = 4.1, r2 = 4.1 + g, h = 60);
    at(0) cylinder(r1 = Rs, r2 = Rs + g, h = 60);
}
module leg(p) {
    translate([p[0], p[1], 0]) cylinder(r1 = 4.6, r2 = 4.1, h = leg_top);
    // toes
    for (a = [-35, 0, 35])
        translate([p[0] + 4.2*cos(a), p[1] + 4.2*sin(a), 0])
            scale([1.6, 1.6, 2.0]) intersection() {
                sphere(1);
                translate([-2, -2, 0]) cube(4);
            }
}
module torso() {
    intersection() { core_env(); support_cones(); }
    for (p = legs) leg(p);
}
module neck_head() {
    C2 = [82, 0, 46];
    S  = [91, 0, 52];
    hull() { translate([72, 0, 27]) sphere(8.5); translate(C2) sphere(6); }
    hull() { translate(C2) sphere(6); translate(S) sphere(4); }
    // eyes (teardrop bumps)
    for (s = [-1, 1]) drop([86.5, s*4.6, 51], 1.5);
}
module body_shape() {
    intersection() {
        union() { torso(); neck_head(); }
        parent_side(0);
    }
}

// ---------------------------------------------------------------- tail
// envelope = chain of hulls between consecutive loaves (x, half-width, height)
tail_pts = [[50, 8.6, 12.5], [38, 8.3, 11.6], [24, 8.1, 11.2],
            [12, 7.0, 9.0], [5, 4.2, 5.5], [1.2, 1.2, 2.2]];
module tail_env() {
    for (i = [0 : len(tail_pts) - 2]) hull() {
        loaf([tail_pts[i][0], 0], tail_pts[i][1], tail_pts[i][2]);
        loaf([tail_pts[i+1][0], 0], tail_pts[i+1][1], tail_pts[i+1][2]);
    }
}
// raw arm of tail segment i (0-based): between joint i (child) and joint i+1
module tail_arm(i) {
    intersection() {
        tail_env();
        child_side(i);
        if (i < 2) parent_side(i + 1);
    }
}

// ---------------------------------------------------------------- parts
module part_body()  jparent(0) body_shape();
module part_tail(i) {
    if (i < 2) jchild(i) jparent(i + 1) tail_arm(i);
    else       jchild(i) tail_arm(i);
}

if (part == 0 || part == 1) part_body();
if (part == 0 || part == 2) part_tail(0);
if (part == 0 || part == 3) part_tail(1);
if (part == 0 || part == 4) part_tail(2);
