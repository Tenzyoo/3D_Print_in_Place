// Print-in-place articulated dinosaur, PLA / 0.4 mm nozzle / 0.2 mm layers
// Units: millimetres. Z is the build direction; all parts have flat bed-side faces.
// part=0: complete assembly; part=1 body; part=2 tail segment 1;
// part=3 tail segment 2; part=4 tail segment 3.
part = 0;

$fn = 48;

// Joint design values. The 0.50 mm radial gap is intentionally explicit.
shaft_r = 1.70;
bore_r = 2.20;       // shaft-to-bore radial clearance = 0.50
ring_r = 3.50;
ring_z0 = 3.80;
ring_h = 2.30;
base_h = 3.20;
cap_r = 2.70;
cap_cone_h = 0.60;
cap_top_h = 0.80;

p1 = 24;
p2 = 38;
p3 = 52;

a = 0.001; // robust Boolean overlap epsilon

module ellipsoid(pos, scale_) {
    translate(pos) scale(scale_) sphere(r=1);
}

module leg(x, y, lean=0) {
    // The wide foot and tapered upright are one continuous solid with the torso.
    translate([x + lean, y, 0]) cylinder(r1=2.35, r2=1.65, h=2.4);
    translate([x, y, 1.8]) cylinder(r1=1.95, r2=1.45, h=7.0);
    translate([x + lean*0.45, y, 7.4]) ellipsoid([0,0,0], [2.2,2.0,2.2]);
}

module captive_ring(x) {
    // Receiver ring is above the tail bases, leaving a 0.60 mm vertical air gap.
    // The small external bridge/post anchors this ring to the upstream part.
    translate([x,0,ring_z0])
        difference() {
            cylinder(r=ring_r, h=ring_h);
            translate([0,0,-a]) cylinder(r=bore_r, h=ring_h+2*a);
        }
}

module body_ring_support() {
    // Outer-side bridge only: it does not enter the bore or touch the pin.
    translate([18.0,-1.2,3.8]) cube([2.8,2.4,4.0]);
}

module tail_ring_support(x) {
    // Tail endpoint is x-4.0. A vertical post grows from that endpoint;
    // the bridge ends in the outer wall of the ring, outside its bore.
    translate([x-4.2,-1.0,3.0]) cube([1.25,2.0,3.15]);
}

module pin_and_keeper(x) {
    // Stem is integral with the downstream tail segment. The conical shoulder
    // prints without support and transitions to the captive top keeper.
    // Lower integral stop prevents the receiver from sliding down over the hub.
    translate([x,0,0]) cylinder(r=cap_r, h=0.80);
    translate([x,0,0]) cylinder(r=shaft_r, h=6.0);
    translate([x,0,6.0]) cylinder(r1=shaft_r, r2=cap_r, h=cap_cone_h);
    translate([x,0,6.6]) cylinder(r=cap_r, h=cap_top_h);
}

module dinosaur_body() {
    union() {
        // Torso, neck, head and snout form one fixed manifold.
        hull() {
            ellipsoid([-4,0,11], [15.5,10.5,7.0]);
            ellipsoid([11,0,11], [11.0,9.5,6.2]);
        }
        ellipsoid([-16.2,0,17.0], [7.0,6.5,6.2]);
        ellipsoid([-21.7,0,16.2], [4.0,5.0,3.7]);
        ellipsoid([-10.8,0,14.0], [5.3,5.4,5.2]);

        // Four fixed legs, two front and two rear.
        leg(-9,-7,-0.7);
        leg(-9, 7,-0.7);
        leg( 9,-7, 0.5);
        leg( 9, 7, 0.5);

        // First receiver is fixed to the body.
        captive_ring(p1);
        body_ring_support();
    }
}

module tail_core(x) {
    // Slender tapered horizontal segment. Its rear tip stops well short of
    // the next pivot, avoiding contact during +/-20 degree yaw.
    hull() {
        translate([x,0,0]) cylinder(r=1.60, h=base_h);
        translate([x+6.2,0,0]) cylinder(r=1.85, h=base_h);
        translate([x+10.0,0,0]) cylinder(r=0.95, h=base_h);
    }
}

module tail_segment_1() {
    union() {
        tail_core(p1);
        pin_and_keeper(p1);
        captive_ring(p2);
        tail_ring_support(p2);
    }
}

module tail_segment_2() {
    union() {
        tail_core(p2);
        pin_and_keeper(p2);
        captive_ring(p3);
        tail_ring_support(p3);
    }
}

module tail_segment_3() {
    union() {
        tail_core(p3);
        pin_and_keeper(p3);
    }
}

if (part == 0) {
    // Keep the four print-in-place solids separate in the exported STL.
    dinosaur_body();
    tail_segment_1();
    tail_segment_2();
    tail_segment_3();
} else if (part == 1) {
    dinosaur_body();
} else if (part == 2) {
    tail_segment_1();
} else if (part == 3) {
    tail_segment_2();
} else if (part == 4) {
    tail_segment_3();
}
