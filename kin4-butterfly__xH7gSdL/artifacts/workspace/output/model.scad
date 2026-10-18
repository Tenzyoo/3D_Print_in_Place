// Print-in-place butterfly with two captive, independently rotating wings.
// All dimensions in mm. Export default assembly, or -D 'PART="body"/"left"/"right"'.
$fn = 64;
PART = "assembly";
// Basic print-fit parameters (PLA, 0.4 mm nozzle, 0.2 mm layers).
plate_t = 2.4;
wing_gap_z = 0.50;         // non-contact axial clearance above wing plates
shaft_r = 1.20;
bearing_r = 1.70;         // 0.50 mm radial shaft/bore clearance
bearing_outer_r = 4.15;
bearing_z0 = plate_t + wing_gap_z;
bearing_h = 2.20;
cap_gap = 0.50;
cap_r = 2.80;
cap_h = 1.20;
pivot_y = 8.0;
$fa = 4; $fs = 0.35;

// XY outline, local pivot at (0,0), outward direction is +Y.
module wing_plate(side=1) {
    mirror([0, side < 0 ? 1 : 0, 0])
    linear_extrude(height=plate_t)
    polygon(points=[
      [-4.0,0.8], [3.5,0.8], [9.0,5.0], [14.0,10.5],
      [15.0,17.0], [12.5,24.0], [9.0,31.0], [4.0,38.0],
      [-3.0,39.0], [-9.5,34.0], [-14.0,27.0], [-15.0,19.0],
      [-12.0,11.0], [-7.0,5.0]
    ]);
}

module wing(side=1) {
    translate([0, side*pivot_y, 0]) {
        wing_plate(side);
        // Shaft integral with the wing; enlarged top button captures it axially.
        cylinder(r=shaft_r, h=bearing_z0 + bearing_h + cap_gap - 0.05);
        translate([0,0,bearing_z0 + bearing_h + cap_gap - 0.05])
            cylinder(r=cap_r, h=cap_h);
        // Shallow raised veins are confined inside the wing outline.
        translate([0,0,plate_t-0.05])
        mirror([0, side < 0 ? 1 : 0, 0])
        linear_extrude(height=0.40)
            union() {
              for (a=[-1,1]) {
                hull() {
                  translate([0,8]) circle(r=0.35,$fn=12);
                  translate([a*9,23]) circle(r=0.35,$fn=12);
                }
                hull() {
                  translate([a*2,12]) circle(r=0.28,$fn=12);
                  translate([a*7,32]) circle(r=0.28,$fn=12);
                }
              }
            }
    }
}

module torso() {
    union() {
      // Body plate, longitudinal X axis.
      linear_extrude(height=plate_t)
        union() {
          hull() { translate([-19,0]) circle(r=4.0); translate([13,0]) circle(r=3.0); }
          // Head at forward (-X) end, with two printable antennae.
          translate([-23,0]) circle(r=5.0);
          hull() { translate([-26,3.5]) circle(r=0.65); translate([-31,7]) circle(r=0.55); }
          hull() { translate([-26,-3.5]) circle(r=0.65); translate([-31,-7]) circle(r=0.55); }
          // Small rear abdomen taper.
          polygon(points=[[10,-2.5],[23,-1.4],[27,0],[23,1.4],[10,2.5]]);
        }
      // Supported bearing rings. Undersides start above wing plates.
      for (s=[-1,1]) {
        translate([0,s*pivot_y,bearing_z0])
          difference() {
            cylinder(r=bearing_outer_r,h=bearing_h);
            translate([0,0,-0.02]) cylinder(r=bearing_r,h=bearing_h+0.04);
          }
        // Twin risers connect ring to spine, in the 0.5 mm axial gap zone.
        for (x=[-1.65,1.65])
          translate([x, s*4.0, plate_t])
            linear_extrude(height=wing_gap_z+0.05)
              hull() {
                circle(r=0.75,$fn=20);
                translate([0,s*2.0]) circle(r=0.75,$fn=20);
              }
      }
    }
}

module assembly() { torso(); wing(-1); wing(1); }
if (PART == "body") torso();
else if (PART == "left") wing(-1);
else if (PART == "right") wing(1);
else assembly();
