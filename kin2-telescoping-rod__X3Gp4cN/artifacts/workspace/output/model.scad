// -----------------------------------------------------------------------------
// Print-in-place, four-stage telescoping round rod
// Units: millimetres.  Coordinate system: rod axis = +Z, collapsed bottom = Z=0.
//
// Four coaxial round tubes are printed simultaneously in their collapsed state.
// Each inner tube has four radial keys at its lower end.  Those keys run in four
// longitudinal keyways in the next outer tube and abut the keyway roof at full
// extension, so no stage can pull apart.
//
// FDM process assumption:
//   PLA, 0.4 mm nozzle, 0.2 mm layer height, vertical build, no supports.
//   Nominal cylindrical sliding clearance = 0.50 mm per side.
//   Key / keyway clearance = 0.50 mm on the loaded faces.
//
// Exports:
//   openscad -o model.stl model.scad
//   openscad -D 'PART_INDEX=0' -o parts/parts_1.stl model.scad   // outermost
//   openscad -D 'PART_INDEX=1' -o parts/parts_2.stl model.scad
//   openscad -D 'PART_INDEX=2' -o parts/parts_3.stl model.scad
//   openscad -D 'PART_INDEX=3' -o parts/parts_4.stl model.scad   // innermost
// -----------------------------------------------------------------------------

$fn = 144;                         // smooth circular geometry

// ------------------------------ primary sizes -------------------------------
GAP             = 0.50;            // radial sliding clearance, per side
KEY_DEPTH       = 1.10;            // radial depth of each key/keyway
KEY_HEIGHT      = 4.0;             // axial height of the lower key
N_KEYS          = 4;               // equally spaced keys
KEYWAY_HALF_ANG = 17.0;            // half-angle of each keyway (deg)
KEYWAY_TOP      = [84.0, 74.0, 74.0, 0.0]; // keyway roof, tube-local Z
TUBE_LENGTH     = [110.0, 100.0, 100.0, 100.0];

// Tube outside / inside radii.  RO[i] - RI[i] = wall thickness.
// The inside radius of tube i is set from the outside radius of tube i+1:
//   RI[i] = RO[i+1] + GAP
RO = [12.40, 9.90, 7.50, 5.20];
RI = [10.40, 8.00, 5.70, 3.50];

EPS = 0.02;                        // boolean overlap / through-cut margin

// ------------------------------ derived values ------------------------------
function deg(a) = a * 180 / PI;

// Half-angle of a key so that its side clearance is >= GAP at the tube OD.
function key_half_angle(i) =
    KEYWAY_HALF_ANG - deg(GAP / RO[i]);

// Annular sector used for both additive keys and subtractive keyways.
// The polygon is intentionally closed and is extruded in +Z only.
module annular_sector(r_in, r_out, h, half_angle) {
    n = max(4, ceil($fn * half_angle / 180));
    a0 = -half_angle;
    a1 =  half_angle;
    linear_extrude(height = h, convexity = 4)
        polygon(points = concat(
            [for (k = [0 : n])
                let (a = a0 + (a1 - a0) * k / n)
                [r_out * cos(a), r_out * sin(a)]],
            [for (k = [0 : n])
                let (a = a1 - (a1 - a0) * k / n)
                [r_in * cos(a), r_in * sin(a)]]
        ));
}

// One complete tube.  i=0 is outermost, i=3 is innermost.
module tube(i) {
    L  = TUBE_LENGTH[i];
    Ro = RO[i];
    Ri = RI[i];

    has_keyway = (i <= 2);
    has_key    = (i >= 1);

    difference() {
        union() {
            // Main circular tube wall.
            difference() {
                cylinder(h = L, r = Ro);
                translate([0, 0, -EPS])
                    cylinder(h = L + 2 * EPS, r = Ri);
            }

            // Four lower-end radial keys.  They overlap the tube wall by
            // 0.20 mm so that the union is a single manifold solid.
            if (has_key) {
                for (a = [0 : N_KEYS - 1]) {
                    rotate([0, 0, a * 360 / N_KEYS])
                        annular_sector(
                            r_in  = Ro - 0.20,
                            r_out = Ro + KEY_DEPTH,
                            h     = KEY_HEIGHT,
                            half_angle = key_half_angle(i)
                        );
                }
            }
        }

        // Four axial keyways cut radially into the inner wall.  The floor of
        // a keyway is at Ri + KEY_DEPTH, which leaves GAP between it and the
        // mating key OD (RO[i+1] + KEY_DEPTH).
        if (has_keyway) {
            for (a = [0 : N_KEYS - 1]) {
                rotate([0, 0, a * 360 / N_KEYS])
                    annular_sector(
                        r_in  = Ri - EPS,
                        r_out = Ri + KEY_DEPTH,
                        h     = KEYWAY_TOP[i],
                        half_angle = KEYWAY_HALF_ANG
                    );
            }
        }
    }
}

// ------------------------------- output mode --------------------------------
// PART_INDEX = -1  : complete collapsed assembly (model.stl)
// PART_INDEX = 0..3: one tube only, in the same position (parts_N.stl)
PART_INDEX = -1;

if (PART_INDEX < 0) {
    union() {
        for (i = [0 : 3]) tube(i);
    }
} else {
    tube(PART_INDEX);
}
