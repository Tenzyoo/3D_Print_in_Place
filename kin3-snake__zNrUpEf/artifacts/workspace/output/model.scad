// Articulated one-piece-print snake, PLA / 0.4 mm nozzle / 0.2 mm layers
// Units: mm. Print flat with Z vertical. Neutral assembly lies along +X.
$fn = 64;

// Core layout
segment_count = 6;
pitch = 22;
body_width = 14;
body_height = 8;
body_start = 8.0;
body_end = 14.0;

// Captive Z-axis pin joint. Designed radial clearance = 0.50 mm.
shaft_r = 1.50;
pin_head_r = 3.00;
socket_inner_r = 3.50;
socket_outer_r = 4.80;
radial_clearance = socket_inner_r - pin_head_r; // 0.50
pin_shaft_z0 = 0.45;
pin_shaft_z1 = 1.55;
pin_head_z0 = 1.55;
pin_head_z1 = 2.10;
retainer_bottom_z = 2.60;
retainer_top_z = 3.20;
axial_clearance = retainer_bottom_z - pin_head_z1; // 0.50
socket_bottom_z = 0.55;
socket_wall_top_z = 2.70;
retainer_inner_r_top = 2.90;
opening_half_angle = 20; // 40-degree throat; connectivity-validated

// Render selector: 0 = full neutral assembly; 1..6 = individual link, same global coordinates
part = 0;

module ellipsoid_at(x,y,z,rx,ry,rz) {
    translate([x,y,z]) scale([rx,ry,rz]) sphere(r=1);
}
module body_shell(i) {
    if (i == 0) {
        hull() {
            ellipsoid_at(body_start+1,0,body_height/2,2.7,body_width/2,body_height/2);
            ellipsoid_at(body_end-1.5,0,body_height/2,3.5,body_width/2,body_height/2);
            translate([body_end+1.0,0,body_height/2]) scale([0.62,0.58,0.65]) sphere(r=4.1);
        }
        for (s=[-1,1]) translate([body_end-1.0,s*3.8,body_height-0.75])
            scale([1,0.72,0.42]) sphere(r=1.25);
    } else {
        hull() {
            ellipsoid_at(body_start+1,0,body_height/2,2.5,body_width/2,body_height/2);
            ellipsoid_at(body_end-1,0,body_height/2,3.5,body_width/2,body_height/2);
        }
    }
}
module male_pin() {
    hull() {
        translate([7.0,0,0.35]) scale([4.0,0.8,0.35]) sphere(r=1);
        translate([pitch,0,0.35]) scale([1.7,0.8,0.35]) sphere(r=1);
    }
    translate([pitch,0,pin_shaft_z0]) cylinder(r=shaft_r,h=pin_shaft_z1-pin_shaft_z0);
    translate([pitch,0,pin_head_z0]) cylinder(r=pin_head_r,h=pin_head_z1-pin_head_z0);
    translate([pitch,0,pin_shaft_z1-0.01]) cylinder(r1=shaft_r,r2=pin_head_r,h=0.30);
}
module female_socket() {
    difference() {
        union() {
            translate([0,0,socket_bottom_z]) linear_extrude(height=socket_wall_top_z-socket_bottom_z)
                difference() { circle(r=socket_outer_r); circle(r=socket_inner_r); }
            translate([0,0,retainer_bottom_z]) linear_extrude(height=retainer_top_z-retainer_bottom_z)
                difference() { circle(r=socket_outer_r); circle(r=retainer_inner_r_top); }
            hull() {
                translate([2.8,0,3.1]) cylinder(r=1.7,h=0.6,center=true);
                translate([5.0,0,body_height/2]) scale([2.0,2.5,1.6]) sphere(r=1);
            }
        }
        // Remove the radial throat from both C-shaped annular tiers.
        for (z=[socket_bottom_z,retainer_bottom_z])
            translate([0,0,z]) linear_extrude(height=(z==socket_bottom_z ? socket_wall_top_z-socket_bottom_z : retainer_top_z-retainer_bottom_z))
                polygon(points=[[0,0],[-(socket_outer_r+1)*cos(opening_half_angle),-(socket_outer_r+1)*sin(opening_half_angle)],[-(socket_outer_r+1)*cos(opening_half_angle),(socket_outer_r+1)*sin(opening_half_angle)]]);
    }
}
module link(i) {
    union() {
        body_shell(i);
        if (i > 0) female_socket();
        if (i < segment_count-1) male_pin();
    }
}
module assembly() {
    for (i=[0:segment_count-1]) translate([i*pitch,0,0]) link(i);
}
if (part == 0) assembly();
else if (part >= 1 && part <= segment_count) translate([(part-1)*pitch,0,0]) link(part-1);

// Neutral envelope about 136 x 28 x 8 mm. Five captive Z-yaw joints, +/-25 degrees nominal.
