// Print-in-place dinosaur with three captive, vertical-axis tail pivots.
// Units are millimetres. part_id: 0=assembly, 1=body, 2..4=tail links.
$fn = 64;
part_id = 0;

body_h = 8.0;
tail_h = 6.0;
pin_r = 1.8;
bore_r = 2.3;       // 0.5 mm radial clearance around the pin
flange_r = 3.1;
chamber_r = 3.7;    // 0.6 mm radial clearance around the flange
hub_r = 4.3;
slot_a = 130;
slot_b = 230;
hinges = [14.8, 31.0, 44.0];

module ellipse2(x, y, rx, ry) {
    translate([x,y]) scale([rx,ry]) circle(r=1);
}

module hull_ellipses(a, b) {
    hull() {
        ellipse2(a[0],a[1],a[2],a[3]);
        ellipse2(b[0],b[1],b[2],b[3]);
    }
}

module dinosaur_outline() {
    union() {
        ellipse2(0.5,0,9.5,8.0);
        hull_ellipses([-9,0,5.2,4.5],[-17,0,4.0,4.0]);
        hull_ellipses([-16,0,4.2,4.0],[-23,0,5.2,3.5]);
        hull_ellipses([-22,0,4.2,3.5],[-29,0,3.0,2.8]);
        // Four tapered legs and broad feet, arranged in two pairs.
        for (sx=[-1,1], x=[-4.8,5.5]) {
            hull_ellipses([x,sy(sx)*5.5,2.5,2.2],[x+sx*0.5,sy(sx)*12.0,2.0,2.2]);
            ellipse2(x+sx*0.5,sy(sx)*14.2,3.0,3.0);
        }
    }
}

function sy(s) = s;

module eyes() {
    for (s=[-1,1])
        translate([-24.1,s*2.15,body_h]) cylinder(r=0.78,h=0.65);
}

module body_anchor() {
    // The short bed-level web remains inside the moving socket's angular relief.
    translate([8.5,-0.55,0]) cube([hinges[0]-8.5,1.1,0.8]);
}

module male_pin(x) {
    translate([x,0,0]) union() {
        cylinder(r=pin_r,h=5.6);
        translate([0,0,2.2]) cylinder(r=flange_r,h=0.7);
    }
}

module socket_slot_2d(r) {
    polygon(points=concat([[0,0]], [for (a=[slot_a:2:slot_b]) [r*cos(a),r*sin(a)]], [[r*cos(slot_b),r*sin(slot_b)]]));
}

module socket_void() {
    union() {
        rotate_extrude(convexity=10)
            polygon(points=[
                [0,0],[bore_r,0],[bore_r,0.55],[chamber_r,1.95],
                [chamber_r,3.3],[bore_r,4.7],[bore_r,tail_h],[0,tail_h]
            ]);
        linear_extrude(height=tail_h) socket_slot_2d(hub_r+0.2);
    }
}

module female_socket(x) {
    translate([x,0,0]) union() {
        difference() {
            cylinder(r=hub_r,h=tail_h);
            // A revolved profile forms bearing lands, 45-degree transitions, and the capture shoulder.
            socket_void();
        }
    }
}

module link1_shape() {
    polygon(points=[
        [18.7,-2.35],[26.2,-1.55],[26.2,1.55],[18.7,2.35]
    ]);
}
module link2_shape() {
    polygon(points=[
        [34.9,-1.65],[39.35,-1.15],[39.35,1.15],[34.9,1.65]
    ]);
}
module tail_tip_shape() {
    hull() {
        translate([48.2,0]) circle(r=1.0);
        translate([51.8,0]) circle(r=0.25);
    }
}

module shallow_anchor(x0,x1) {
    translate([x0,-0.55,0]) cube([x1-x0,1.1,0.8]);
}

module fixed_body() {
    union() {
        linear_extrude(height=body_h) dinosaur_outline();
        eyes();
        body_anchor();
        male_pin(hinges[0]);
    }
}

module tail1() {
    union() {
        linear_extrude(height=tail_h) link1_shape();
        female_socket(hinges[0]);
        shallow_anchor(25.8,hinges[1]);
        male_pin(hinges[1]);
    }
}

module tail2() {
    union() {
        linear_extrude(height=tail_h) link2_shape();
        female_socket(hinges[1]);
        shallow_anchor(38.95,hinges[2]);
        male_pin(hinges[2]);
    }
}

module tail3() {
    union() {
        female_socket(hinges[2]);
        translate([0,0,0]) linear_extrude(height=tail_h) tail_tip_shape();
    }
}

if (part_id == 0) {
    fixed_body();
    tail1();
    tail2();
    tail3();
} else if (part_id == 1) {
    fixed_body();
} else if (part_id == 2) {
    tail1();
} else if (part_id == 3) {
    tail2();
} else if (part_id == 4) {
    tail3();
}
