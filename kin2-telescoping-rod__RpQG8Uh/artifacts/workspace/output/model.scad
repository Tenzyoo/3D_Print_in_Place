// Print-in-place, four-stage telescoping tube assembly.
// Units: mm. Print upright on the common Z axis, with supports disabled.

$fn = 128;

stage_count = 4;
tube_length = 100;
wall = 1.2;
radial_clearance = 0.5;
outer_diameter = 22;
diameter_step = 2 * wall + 2 * radial_clearance;
slot_width = 3.0;
stem_width = 1.8;
head_width = 3.5;
lug_height = 4.0;
slot_start = 14;
slot_end = 92;
lug_start = 18;
max_travel = 70;
stem_outer_clearance = 0.4;
head_radial_thickness = 0.9;
export_part = -1; // -1: assembled model; 0..3: one stage, numbered from outside.

function stage_od(i) = outer_diameter - i * diameter_step;
function stage_id(i) = stage_od(i) - 2 * wall;
function phase(i) = i * 40;

module radial_box(angle, r0, radial_size, tangential_size, z0, z_size) {
    rotate([0, 0, angle])
        translate([r0, -tangential_size / 2, z0])
            cube([radial_size, tangential_size, z_size]);
}

module stage(i) {
    od = stage_od(i);
    id = stage_id(i);
    outer_r = od / 2;
    inner_r = id / 2;

    difference() {
        union() {
            difference() {
                cylinder(d=od, h=tube_length);
                translate([0, 0, -0.01])
                    cylinder(d=id, h=tube_length + 0.02);
            }

            // T-head sliders pass through the parent's slots and remain captive.
            if (i > 0) {
                parent_r = stage_od(i - 1) / 2;
                cap_inner_r = parent_r + stem_outer_clearance;
                stem_r0 = outer_r - 0.1;
                stem_r1 = cap_inner_r + 0.01;
                for (k = [0 : 2]) {
                    a = phase(i - 1) + 120 * k;
                    radial_box(a, stem_r0, stem_r1 - stem_r0, stem_width,
                               lug_start, lug_height);
                    radial_box(a, cap_inner_r, head_radial_thickness,
                               head_width, lug_start, lug_height);
                }
            }
        }

        // The immediate child uses a narrow retained slot. Deeper sliders
        // pass through wider, phase-shifted relief slots in ancestor walls.
        if (i < stage_count - 1) {
            slot_r0 = inner_r - head_width - 1.0;
            slot_r1 = outer_r + 0.02;
            for (k = [0 : 2]) {
                a = phase(i) + 120 * k;
                radial_box(a, slot_r0, slot_r1 - slot_r0, slot_width,
                           slot_start, slot_end - slot_start);
            }
        }
        if (i < stage_count - 2) {
            slot_r0 = inner_r - head_width - 1.0;
            slot_r1 = outer_r + 0.02;
            for (k = [0 : 2]) {
                a = phase(i + 1) + 120 * k;
                radial_box(a, slot_r0, slot_r1 - slot_r0,
                           head_width + 1.0, slot_start,
                           tube_length - slot_start);
            }
        }
        if (i < stage_count - 3) {
            slot_r0 = inner_r - head_width - 1.0;
            slot_r1 = outer_r + 0.02;
            for (k = [0 : 2]) {
                a = phase(i + 2) + 120 * k;
                radial_box(a, slot_r0, slot_r1 - slot_r0,
                           head_width + 1.0, slot_start,
                           tube_length - slot_start);
            }
        }
    }
}

module assembled() {
    for (i = [0 : stage_count - 1])
        stage(i);
}

if (export_part < 0)
    assembled();
else
    stage(export_part);
