// Three-link print-in-place folding ruler. Units are millimetres.
$fn = 64;

link_length = 40;
link_width = 12;
link_thickness = 5;
joint_clearance = 0.5;       // radial clearance around each 3 mm pin
pin_radius = 1.5;
eye_inner_radius = pin_radius + joint_clearance;
eye_outer_radius = 3.4;
axis_offset = 13;
pin_arm_z = 2.0;
pin_arm_thickness = 1.2;
eye_arm_z = 0;
eye_arm_thickness = 1.6;
eye_z = 0;
eye_thickness = 1.6;
pin_shaft_bottom = 0;
pin_shaft_top = 2.8;
cap_base_z = 2.2;
cap_top_z = 7.2;
fold_angle_1 = 0;             // 0 = straight, positive folds link 2 clockwise
fold_angle_2 = 0;
export_part = 0;              // 0 = assembled, 1..3 = individual link

module link_body(x_offset=0) {
    // Narrow, pointed ends provide clearance near the rotating axes.
    translate([x_offset,0,0]) linear_extrude(height=link_thickness)
        polygon(points=[
            [0,-0.35], [6,-6], [34,-6], [40,-0.35],
            [40,0.35], [34,6], [6,6], [0,0.35]
        ]);
}

module arm_to_axis(x, axis_y) {
    hull() {
        translate([x-1,0,pin_arm_z])
            linear_extrude(height=pin_arm_thickness) circle(r=0.7, $fn=24);
        translate([x-1.4,axis_y,pin_arm_z])
            linear_extrude(height=pin_arm_thickness) circle(r=0.7, $fn=24);
    }
}

module eye_arm_to_axis(x, axis_y) {
    hull() {
        translate([x+1.7,0,eye_arm_z])
            linear_extrude(height=eye_arm_thickness) circle(r=0.7, $fn=24);
        translate([x+3,axis_y,eye_arm_z])
            linear_extrude(height=eye_arm_thickness) circle(r=0.7, $fn=24);
    }
}

module pin_joint(x, axis_y) {
    arm_to_axis(x, axis_y);
    translate([x,axis_y,pin_shaft_bottom])
        cylinder(r=pin_radius,h=pin_shaft_top-pin_shaft_bottom);
    // The 45-degree underside of the cap is self-supporting above the eye.
    translate([x,axis_y,cap_base_z])
        cylinder(r1=pin_radius,r2=2.9,h=1.4);
}

module eye_joint(x, axis_y) {
    eye_arm_to_axis(x, axis_y);
    translate([x,axis_y,eye_z])
        difference() {
            cylinder(r=eye_outer_radius,h=eye_thickness);
            translate([0,0,-0.05])
                cylinder(r=eye_inner_radius,h=eye_thickness+0.1);
        }
}

module link1() {
    union() {
        link_body();
        pin_joint(link_length,-axis_offset);
    }
}

module link2() {
    union() {
        link_body(0.4);
        eye_joint(0,-axis_offset);
        pin_joint(link_length,axis_offset);
    }
}

module link3() {
    union() {
        link_body(0.8);
        eye_joint(0,axis_offset);
    }
}

module pose_link2() {
    translate([link_length,-axis_offset,0])
        rotate([0,0,-fold_angle_1])
            translate([0,axis_offset,0]) link2();
}

module pose_link3() {
    translate([link_length,-axis_offset,0])
        rotate([0,0,-fold_angle_1])
            translate([0,axis_offset,0])
                translate([link_length,axis_offset,0])
                    rotate([0,0,fold_angle_2])
                        translate([-link_length,-axis_offset,0])
                            translate([link_length,0,0]) link3();
}

if (export_part == 1) link1();
else if (export_part == 2) pose_link2();
else if (export_part == 3) pose_link3();
else {
    link1();
    pose_link2();
    pose_link3();
}
