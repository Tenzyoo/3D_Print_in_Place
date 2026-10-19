// ============================================================================
// Print-in-Place 4-Stage Telescopic Rod (一体化 3D 打印四级伸缩棒)
// Material: PLA | Nozzle: 0.4 mm | Layer Height: 0.2 mm
// Orientation: Vertical along +Z axis, base flat on build plate (z = 0)
// ============================================================================

/* [Export & Visualization Control] */
// 0 = full assembly (model.stl), 1..4 = individual tube (parts_1..parts_4.stl)
part_id = 0;

// Extension per stage in mm [stage1_2, stage2_3, stage3_4] (0 = collapsed, 70 = extended)
extension = [0.0, 0.0, 0.0];

// Uniform extension factor (0.0 = collapsed, 1.0 = fully extended; overrides extension if > 0)
extend_factor = 0.0;

/* [Global Geometric Parameters] */
// Number of nested tubular stages
num_stages = 4;

// Collapsed length of each tube (mm) - requirement: <= 120 mm
tube_length = 115.0;

// Outermost tube outer diameter (mm) - requirement: <= 25 mm
max_outer_diameter = 24.0;

// Main cylindrical tube wall thickness (mm) - 3 perimeters with 0.4 mm nozzle
wall_thickness = 1.2;

// Single-side radial sliding clearance between mating surfaces (mm) - requirement: 0.4-0.6 mm
radial_clearance = 0.50;

// Radial protrusion height of retaining stop collars (mm)
// Gives stop overlap = stop_lip_height - radial_clearance = 0.50 mm per side (1.00 mm diametral)
stop_lip_height = 1.00;

// Axial height of conical transition ramps (mm)
// Overhang angle from vertical = atan(1.0 / 1.5) = 33.69 deg (56.31 deg from horizontal -> support-free)
ramp_height = 1.50;

/* [Stop & Bearing Axial Layout Parameters] */
// Bottom retaining lip flat height on outer tube inner wall (mm)
bot_lip_flat_z = 2.50;

// Axial clearance shift at bottom stop in collapsed state (mm)
// Gives 0.693 mm normal clearance between bottom conical faces during print-in-place
bot_axial_gap = 0.50;

// Top end of bottom piston cylindrical bearing on inner tube (mm)
piston_top_z = 22.50;

// Bottom start of top neck conical stop ramp on outer tube (mm)
neck_ramp_start_z = 92.00;

// Nominal extension stroke per stage (mm)
// Exact conical stop contact occurs at neck_ramp_start_z - piston_top_z + radial_clearance * (ramp_height / stop_lip_height)
// = 92.00 - 22.50 + 0.75 = 70.25 mm; nominal stroke = 70.00 mm -> total extended length = 115 + 3*70 = 325 mm >= 300 mm
nominal_stroke = 70.00;

/* [Resolution] */
$fn = 128;

// ============================================================================
// Derived Helper Functions (Stage index i in 1..num_stages, 1 = outermost)
// ============================================================================

// Radial pitch from stage i to stage i+1
function stage_radial_step() = wall_thickness + radial_clearance + stop_lip_height;

// Main shaft outer radius of stage i
function r_shaft_out(i) = (max_outer_diameter / 2.0) - (i - 1) * stage_radial_step();

// Bottom piston collar outer radius of stage i (for i >= 2)
function r_piston_out(i) = (i == 1) ? r_shaft_out(1) : (r_shaft_out(i) + stop_lip_height);

// Main bore inner radius of stage i
function r_bore_in(i) = r_shaft_out(i) - wall_thickness;

// Top/bottom retaining neck inner radius of stage i (for i <= num_stages - 1)
function r_neck_in(i) = (i == num_stages) ? r_bore_in(num_stages) : (r_bore_in(i) - stop_lip_height);

// Cumulative axial Z offset of stage i
function stage_z_offset(i) =
    (i <= 1) ? 0.0 :
    let(s = (extend_factor > 0.0) ? (extend_factor * nominal_stroke) : extension[i - 2])
    stage_z_offset(i - 1) + s;

// ============================================================================
// 2D Cross-Section Profile of Stage i in the (r, z) Plane
// ============================================================================
module stage_profile_2d(i) {
    r_out_main   = r_shaft_out(i);
    r_out_piston = r_piston_out(i);
    r_in_main    = r_bore_in(i);
    r_in_neck    = r_neck_in(i);

    z0 = 0.0;
    z_bot_in_ramp_start  = bot_lip_flat_z;                        // 2.50
    z_bot_in_ramp_end    = bot_lip_flat_z + ramp_height;          // 4.00
    z_bot_out_ramp_start = bot_lip_flat_z + bot_axial_gap;        // 3.00
    z_bot_out_ramp_end   = z_bot_out_ramp_start + ramp_height;    // 4.50
    z_piston_top         = piston_top_z;                          // 22.50
    z_piston_ramp_end    = piston_top_z + ramp_height;            // 24.00
    z_neck_ramp_start    = neck_ramp_start_z;                     // 92.00
    z_neck_ramp_end      = neck_ramp_start_z + ramp_height;       // 93.50
    z_top                = tube_length;                           // 115.00

    // Outer boundary points from bottom (z = 0) to top (z = tube_length)
    outer_pts = (i == 1) ? [
        [r_out_main, z0],
        [r_out_main, z_top]
    ] : [
        [r_out_main,   z0],
        [r_out_main,   z_bot_out_ramp_start],
        [r_out_piston, z_bot_out_ramp_end],
        [r_out_piston, z_piston_top],
        [r_out_main,   z_piston_ramp_end],
        [r_out_main,   z_top]
    ];

    // Inner boundary points from top (z = tube_length) down to bottom (z = 0)
    inner_pts = (i == num_stages) ? [
        [r_in_main, z_top],
        [r_in_main, z0]
    ] : [
        [r_in_neck, z_top],
        [r_in_neck, z_neck_ramp_end],
        [r_in_main, z_neck_ramp_start],
        [r_in_main, z_bot_in_ramp_end],
        [r_in_neck, z_bot_in_ramp_start],
        [r_in_neck, z0]
    ];

    polygon(points = concat(outer_pts, inner_pts));
}

// ============================================================================
// 3D Module for Stage i
// ============================================================================
module telescopic_stage(i) {
    translate([0, 0, stage_z_offset(i)])
        rotate_extrude(angle = 360, convexity = 6)
            stage_profile_2d(i);
}

// ============================================================================
// Top-Level Render Dispatch
// ============================================================================
if (part_id >= 1 && part_id <= num_stages) {
    telescopic_stage(part_id);
} else {
    for (i = [1 : num_stages]) {
        telescopic_stage(i);
    }
}
