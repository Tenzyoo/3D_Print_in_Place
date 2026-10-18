// Print-in-place articulated snake. Units: mm.
// Set part_id to 0..5 to export one rigid link; -1 exports the full assembly.
part_id = -1;

$fn = 64;
segment_pitch = 25;
link_count = 6;
body_height = 10;
shaft_radius = 2.5;
socket_radius = 3.0;
radial_clearance = socket_radius - shaft_radius;
retainer_radius = 4.5;
socket_outer_radius = 5.2;
socket_height = 7.2;
retainer_start_z = 7.3;
retainer_height = 2.0;
pivot_offset = segment_pitch / 2;
neck_width = 3.4;

module rounded_body() {
    hull() {
        translate([-2, 0]) circle(r=5.5);
        translate([ 2, 0]) circle(r=5.5);
    }
}

module head_outline() {
    hull() {
        translate([-8, 0]) circle(r=4);
        translate([-5, 0]) circle(r=7);
        translate([ 0, 0]) circle(r=7);
        translate([ 1.5, 0]) circle(r=4);
    }
}

module neck_to(pivot_x) {
    hull() {
        translate([pivot_x > 0 ? 7 : -7, 0]) circle(d=neck_width);
        translate([pivot_x, 0]) circle(d=neck_width);
    }
}

module socket(pivot_x) {
    translate([pivot_x, 0, 0]) difference() {
        difference() {
            cylinder(r=socket_outer_radius, h=socket_height);
            translate([0, 0, -0.1]) cylinder(r=socket_radius, h=socket_height + 0.2);
        }
        // A 130-degree opening lets the pin's supporting stem sweep through +/-25 degrees.
        linear_extrude(height=socket_height + 0.2)
            polygon(points=[[0,0], [7*cos(115),7*sin(115)], [7*cos(180),7*sin(180)], [7*cos(245),7*sin(245)]]);
    }
}

module socket_support(pivot_x) {
    hull() {
        translate([pivot_x + 4.8, 0]) circle(d=neck_width);
        translate([pivot_x + 7.8, 0]) circle(d=neck_width);
    }
}

module pin(pivot_x) {
    translate([pivot_x, 0, 0]) union() {
        cylinder(r=shaft_radius, h=retainer_start_z + 0.01);
        // 45-degree underside keeps the retaining flange self-supporting.
        translate([0, 0, retainer_start_z]) cylinder(r1=shaft_radius, r2=retainer_radius, h=retainer_height);
    }
}

module head_link() {
    linear_extrude(height=body_height) head_outline();
    // The low pin stem clears the receiver ring while passing through its open sector.
    linear_extrude(height=4.8) hull() {
        translate([5.2, 0]) circle(d=neck_width);
        translate([pivot_offset, 0]) circle(d=neck_width);
    }
    pin(pivot_offset);
}

module body_link(last=false) {
    linear_extrude(height=body_height) rounded_body();
    linear_extrude(height=4.8) socket_support(-pivot_offset);
    if (!last) linear_extrude(height=4.8) neck_to(pivot_offset);
    socket(-pivot_offset);
    if (!last) pin(pivot_offset);
}

module one_link(id) {
    translate([id * segment_pitch, 0, 0]) {
        if (id == 0) head_link();
        else body_link(last=(id == link_count - 1));
    }
}

if (part_id < 0) {
    for (id=[0:link_count-1]) one_link(id);
} else if (part_id >= 0 && part_id < link_count) {
    one_link(part_id);
}
