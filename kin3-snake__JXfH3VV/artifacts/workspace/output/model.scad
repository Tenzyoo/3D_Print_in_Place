// ============================================================================
// Parametric Print-in-Place Articulated Snake Model for FDM 3D Printing
// ============================================================================
// Structure:
//   - 6 rigid body parts: 1 Head (parts_1) + 5 Body Segments (parts_2 .. parts_6)
//   - 5 Z-axis revolute pin joints with double-conical (spool) axial retention
//   - Designed for PLA, 0.4 mm nozzle, 0.2 mm layer height, zero supports
//   - Overall bounding box in neutral pose: 150.0 x 29.6 x 19.2 mm (<= 160x50x40 mm)
// ============================================================================

// --- Export & Pose Control Parameters ---
// part_id = 0 : Full assembled model in neutral straight pose (model.stl)
// part_id = 1 : Head (parts_1.stl)
// part_id = 2 : Body segment 1 (parts_2.stl)
// part_id = 3 : Body segment 2 (parts_3.stl)
// part_id = 4 : Body segment 3 (parts_4.stl)
// part_id = 5 : Body segment 4 (parts_5.stl)
// part_id = 6 : Body segment 5 / Tail (parts_6.stl)
part_id = 0;

// Optional joint angles (deg) for visualization/pose verification [J1, J2, J3, J4, J5]
// Each joint supports at least [-32, +32] deg collision-free rotation (req: +/-25 deg)
joint_angles = [0, 0, 0, 0, 0];

// --- FDM Printing & Clearance Parameters ---
nozzle_diam      = 0.40;
layer_height     = 0.20;
radial_clearance = 0.52;   // Single-sided radial clearance in [0.4, 0.6] mm
                           // Gives 0.52 mm horizontal radial gap and 0.441 mm 3D normal gap on 32-deg cones
cup_clearance    = 0.85;   // Clearance between outer socket nose and anterior concave cup

// --- Joint Retention & Angular Geometry Parameters ---
cone_angle_deg   = 33.0;   // Cone slope from vertical Z axis (57 deg from horizontal build plate -> self-supporting)
cone_height      = 2.50;   // Vertical height of each conical retention ramp (mm)
rim_height       = 1.20;   // Vertical cylindrical rim height at top and bottom of joint (mm)
pin_flare        = cone_height * tan(cone_angle_deg); // ~1.624 mm radial flare per side (3.25 mm diametral retention)

neck_half_angle  = 13.0;   // Half-angle of anterior pin neck (deg) -> 26 deg total width
throat_half_angle= 49.0;   // Half-angle of posterior socket throat opening (deg) -> 262 deg socket wrap
                           // Angular margin = 49.0 - 13.0 = 36 deg per side (supports +/-30 deg rotation)
cheek_cut_angle  = 96.0;   // Rear cup cheek opening half-angle on anterior segment (deg)

// --- Kinematic Layout & Segment Dimensions ---
// 5 Joint X coordinates (mm), spaced by 24.0 mm pitch along X axis
joint_x          = [-45.0, -21.0, 3.0, 27.0, 51.0];

// Joint heights Z (mm) at each of the 5 joints
joint_h          = [15.6, 14.8, 14.0, 13.2, 12.4];

// Pin central cylindrical shaft radii (mm) at each joint
pin_r_shaft      = [4.10, 3.95, 3.80, 3.65, 3.50];

// Posterior socket nose outer radii (mm) at each joint
nose_r           = [9.00, 8.70, 8.40, 8.05, 7.70];

// Segment maximum half-widths in Y (mm) and dorsal heights in Z (mm) for parts 1..6
seg_half_w       = [14.8, 12.2, 11.6, 10.9, 10.2, 9.4];
seg_max_h        = [19.2, 16.8, 15.9, 15.0, 14.1, 13.0];

snout_tip_x      = -71.0;  // Front snout center of Head (part 1), actual front tip at X = -75.0 mm
tail_tip_x       =  75.0;  // Rear tip of Tail (part 6) at X = +75.0 mm

// Mesh resolution
$fn = 64;
eps = 0.01;

// ============================================================================
// Helper Functions
// ============================================================================

// Pin flange radius at joint index j (0..4)
function get_pin_r_flange(j) = pin_r_shaft[j] + pin_flare;

// Cup inner radius on anterior segment at joint index j (0..4)
function get_cup_r(j) = nose_r[j] + cup_clearance;

// 2D sector polygon centered at origin from angle a1 to a2 (deg) with radius R
module sector_2d(r, a1, a2, steps = 32) {
    pts = concat(
        [[0, 0]],
        [for (i = [0 : steps])
            let(a = a1 + (a2 - a1) * i / steps)
            [r * cos(a), r * sin(a)]
        ]
    );
    polygon(pts);
}

// ============================================================================
// Joint Building Blocks (Z-axis Revolute Spool-Pin & Omega-Socket)
// ============================================================================

// 1. Spool Pin + Neck (attached to the rear of anterior part j+1 at joint j)
module joint_pin_and_neck(j) {
    jx       = joint_x[j];
    jh       = joint_h[j];
    r_shaft  = pin_r_shaft[j];
    r_flange = get_pin_r_flange(j);
    r_cup    = get_cup_r(j);

    z1 = rim_height;
    z2 = rim_height + cone_height;
    z3 = jh - rim_height - cone_height;
    z4 = jh - rim_height;

    translate([jx, 0, 0]) {
        union() {
            // Spool-shaped pin of revolution around Z axis
            // Bottom flange + 32-deg bottom cone + central cylindrical shaft + 32-deg top cone + top flange
            rotate_extrude(convexity = 6) {
                polygon([
                    [0,              0],
                    [r_flange,       0],
                    [r_flange,       z1],
                    [r_shaft,        z2],
                    [r_shaft,        z3],
                    [r_flange,       z4],
                    [r_flange,       jh - 0.35],
                    [r_flange - 0.35, jh],
                    [0,              jh]
                ]);
            }

            // Anterior neck web connecting the pin forward (-X, 180 deg) into the anterior body segment
            // Spans [180 - neck_half_angle, 180 + neck_half_angle] and embeds deep into anterior segment
            intersection() {
                linear_extrude(height = jh, convexity = 4) {
                    sector_2d(r_cup + 3.5, 180.0 - neck_half_angle, 180.0 + neck_half_angle, 16);
                }
                // Chamfer top outer edge slightly to match pin top
                cylinder(r1 = r_cup + 5.0, r2 = r_cup + 4.5, h = jh);
            }
        }
    }
}

// 2. Rear Cup Cutout (subtracted from the rear of anterior part j+1 before adding pin+neck)
module anterior_cup_cutout(j) {
    jx    = joint_x[j];
    jh    = joint_h[j];
    r_cup = get_cup_r(j);
    max_z = 30.0;

    translate([jx, 0, 0]) {
        union() {
            // Main cylindrical cup recess around the posterior segment's nose
            translate([0, 0, -1.0])
                cylinder(r = r_cup, h = max_z);

            // Self-supporting 45-deg bevel above joint height jh so dorsal scales/ridge transition cleanly
            translate([0, 0, jh])
                cylinder(r1 = r_cup, r2 = r_cup + (max_z - jh), h = max_z - jh);

            // Rear cheek clearance sector [-cheek_cut_angle, +cheek_cut_angle] for wide rotation
            translate([0, 0, -1.0])
                linear_extrude(height = max_z + 2.0, convexity = 4)
                    sector_2d(30.0, -cheek_cut_angle, cheek_cut_angle, 32);
        }
    }
}

// 3. Socket Bore + Throat Opening Cutout (subtracted from the front of posterior part j+2 at joint j)
module posterior_socket_cutout(j) {
    jx       = joint_x[j];
    jh       = joint_h[j];
    r_shaft  = pin_r_shaft[j] + radial_clearance;
    r_flange = get_pin_r_flange(j) + radial_clearance;
    r_nose   = nose_r[j];

    z1 = rim_height;
    z2 = rim_height + cone_height;
    z3 = jh - rim_height - cone_height;
    z4 = jh - rim_height;

    translate([jx, 0, 0]) {
        union() {
            // Spool-shaped bore matching the pin with exact radial_clearance (0.52 mm)
            rotate_extrude(convexity = 6) {
                polygon([
                    [0,        -0.5],
                    [r_flange, -0.5],
                    [r_flange,  z1],
                    [r_shaft,   z2],
                    [r_shaft,   z3],
                    [r_flange,  z4],
                    [r_flange,  jh + 1.0],
                    [0,         jh + 1.0]
                ]);
            }

            // Front throat opening facing -X (180 +/- throat_half_angle)
            translate([0, 0, -0.5])
                linear_extrude(height = jh + 10.0, convexity = 4)
                    sector_2d(r_nose + 3.0, 180.0 - throat_half_angle, 180.0 + throat_half_angle, 24);
        }
    }
}

// 4. Posterior Nose Envelope Trim (ensures the front of posterior part j+2 stays strictly inside
//    nose_r[j] and height jh within the cup zone, guaranteeing collision-free rotation)
module posterior_nose_trim(j) {
    jx     = joint_x[j];
    jh     = joint_h[j];
    r_nose = nose_r[j];
    r_cup  = get_cup_r(j);

    translate([jx, 0, 0]) {
        union() {
            // Remove anything in front of the nose cylinder or outside nose_r within the cup zone
            difference() {
                translate([-r_cup - 5.0, -25.0, -1.0])
                    cube([r_cup + 5.0 + r_nose * cos(42.0), 50.0, 35.0]);
                // Keep the nose cylinder up to height jh (with subtle top bevel)
                union() {
                    cylinder(r = r_nose, h = jh - 0.35);
                    translate([0, 0, jh - 0.35])
                        cylinder(r1 = r_nose, r2 = r_nose - 0.35, h = 0.35);
                }
            }
            // Also trim height above jh inside radius r_cup + 0.4 so dorsal arch never touches anterior cup
            translate([0, 0, jh])
                cylinder(r1 = r_cup + 0.4, r2 = r_cup - 2.0, h = 15.0);
        }
    }
}

// ============================================================================
// Cross-Sectional Body Primitives (Flat Belly + Organic Arched Dorsal Profile)
// ============================================================================

// Creates an organic snake body slice at position x with half-width w, height h, and length dx
// Wide flat bottom on Z = 0, steep (>72 deg) lower flanks, arched back with dorsal keel
module snake_cross_section(x, w, h, dx = 0.8) {
    // Bottom flat width is 86% of max width for large bed adhesion and >72 deg flank angle
    w_flat = w * 0.86;
    z_mid  = h * 0.38;
    r_top  = w * 0.56;

    translate([x, 0, 0]) {
        hull() {
            // Flat belly plate on build plate Z = 0
            translate([-dx/2, -w_flat, 0])
                cube([dx, 2 * w_flat, 1.2]);

            // Mid-flank widest part (slope from w_flat at z=1.2 to w at z_mid is >72 deg from horizontal)
            translate([-dx/2, -w, z_mid])
                cube([dx, 2 * w, 0.8]);

            // Upper dorsal arch
            translate([0, 0, h - r_top * 0.62])
                rotate([0, 90, 0])
                    cylinder(r = r_top, h = dx, center = true);

            // Dorsal ridge keel at the crown
            translate([-dx/2, -w * 0.16, h - 0.6])
                cube([dx, w * 0.32, 0.6]);
        }
    }
}

// Sculpted dorsal scales along the top spine (100% upward-facing, zero overhang)
module body_scale_details(x_start, x_end, w_front, w_rear, h_front, h_rear) {
    seg_len = x_end - x_start;
    // 3 overlapping dorsal diamond scale crests along the top spine
    for (k = [0 : 2]) {
        t  = (k + 0.5) / 3.0;
        xk = x_start + seg_len * (0.20 + 0.60 * t);
        wk = w_front * (1 - t) + w_rear * t;
        hk = h_front * (1 - t) + h_rear * t;

        translate([xk, 0, hk - 1.1]) {
            hull() {
                translate([-2.5, 0, 0])
                    scale([1.0, 0.72, 0.50])
                        cylinder(r1 = wk * 0.38, r2 = wk * 0.12, h = 1.6, $fn = 6);
                translate([1.8, 0, -0.2])
                    scale([1.0, 0.52, 0.40])
                        cylinder(r1 = wk * 0.30, r2 = 0.4, h = 1.4, $fn = 6);
            }
        }
    }
}

// Self-supporting vertical diamond scale grooves on flanks (top & bottom taper at >68 deg)
module biconical_groove_cutter(r_xy, h_mid, h_tip) {
    union() {
        cylinder(r = r_xy, h = h_mid, center = true, $fn = 4);
        translate([0, 0, h_mid/2])
            cylinder(r1 = r_xy, r2 = 0.01, h = h_tip, $fn = 4);
        translate([0, 0, -h_mid/2 - h_tip])
            cylinder(r1 = 0.01, r2 = r_xy, h = h_tip, $fn = 4);
    }
}

module lateral_scale_grooves(x_start, x_end, w_avg, h_avg) {
    seg_len = x_end - x_start;
    for (side = [-1, 1]) {
        for (k = [-1, 0, 1]) {
            xg = (x_start + x_end) * 0.5 + k * (seg_len * 0.22);
            translate([xg, side * (w_avg + 0.25), h_avg * 0.42])
                biconical_groove_cutter(0.75, h_avg * 0.26, 1.8);
        }
    }
}

// ============================================================================
// Part 1: Sculpted Viper/Python Head (parts_1.stl)
// ============================================================================
module part_1_head() {
    j = 0; // Joint 1 at index 0 (x = -45.0)
    jx = joint_x[j];
    jh = joint_h[j];

    difference() {
        union() {
            // Main sculpted head loft from snout tip (-75.0) to Joint 1 (-45.0)
            // Section 1: Snout -> Brow (steep >75 deg snout wall from Z=0)
            hull() {
                translate([snout_tip_x, 0, 0]) {
                    cylinder(r1 = 3.7, r2 = 4.0, h = 6.5);
                    translate([0, 0, 6.5])
                        cylinder(r1 = 4.0, r2 = 2.8, h = 3.2);
                }
                // Nostril region at X = -69.0
                snake_cross_section(-69.0, 7.8, 12.8, 1.0);
                // Eye / Supraocular brow region at X = -62.5
                snake_cross_section(-62.5, 11.8, 17.2, 1.2);
            }

            // Section 2: Brow -> Broad Temporal Venom Cheeks
            hull() {
                snake_cross_section(-62.5, 11.8, 17.2, 1.2);
                snake_cross_section(-54.5, seg_half_w[0], seg_max_h[0], 1.6);
            }

            // Section 3: Temporal Cheeks -> Neck at Joint 1
            hull() {
                snake_cross_section(-54.5, seg_half_w[0], seg_max_h[0], 1.6);
                snake_cross_section(jx - 2.0, seg_half_w[1] + 0.5, jh + 1.0, 1.2);
                translate([jx, 0, 0])
                    cylinder(r = get_cup_r(j) + 1.6, h = jh);
            }

            // Sculpted Parietal Head Crown Shield (top of cranium, upward-facing)
            translate([-55.5, 0, seg_max_h[0] - 0.8])
                scale([6.5, 4.8, 1.2])
                    cylinder(r1 = 1.0, r2 = 0.45, h = 1.0, $fn = 6);

            // Self-supporting Supraocular Brow Ridges (hulled cleanly from mid-cheek)
            for (side = [-1, 1]) {
                hull() {
                    translate([-62.5, side * 8.4, 14.5])
                        scale([4.2, 2.0, 1.2])
                            cylinder(r1 = 1.0, r2 = 0.4, h = 1.0, $fn = 24);
                    translate([-62.5, side * 7.5, 10.5])
                        cylinder(r = 2.0, h = 0.5, $fn = 16);
                }
            }
        }

        // --- Subtracted Self-Supporting Features on Head ---
        // 1. Shallow Vertical Slit-Pupil Eye Grooves (biconical >68 deg roofs, zero overhang)
        for (side = [-1, 1]) {
            translate([-63.0, side * 11.3, 11.5])
                scale([1.8, 0.75, 1.0])
                    biconical_groove_cutter(1.2, 1.8, 2.2);
        }

        // 2. Upward-facing Nostril Pits near snout top
        for (side = [-1, 1]) {
            translate([-69.5, side * 3.8, 12.2])
                cylinder(r1 = 0.3, r2 = 1.1, h = 2.0, center = true, $fn = 24);
        }

        // 3. Steep (>68 deg ceiling) Mouth Seam Groove along snout & cheeks
        for (side = [-1, 1]) {
            hull() {
                translate([snout_tip_x + 0.2, side * 3.8, 4.0])
                    scale([1.0, 0.7, 1.8])
                        rotate([45, 0, 0])
                            cube([1.0, 0.9, 0.9], center = true);
                translate([-62.5, side * 11.6, 5.2])
                    scale([1.0, 0.7, 1.8])
                        rotate([45, 0, 0])
                            cube([1.0, 1.0, 1.0], center = true);
            }
            hull() {
                translate([-62.5, side * 11.6, 5.2])
                    scale([1.0, 0.7, 1.8])
                        rotate([45, 0, 0])
                            cube([1.0, 1.0, 1.0], center = true);
                translate([-54.5, side * (seg_half_w[0] - 0.1), 6.2])
                    scale([1.0, 0.7, 1.8])
                        rotate([45, 0, 0])
                            cube([1.0, 0.9, 0.9], center = true);
            }
        }

        // 4. Subtract Rear Joint 1 Cup Cutout
        anterior_cup_cutout(j);

        // 5. Ensure flat bottom on Z = 0
        translate([-90, -30, -10])
            cube([180, 60, 10]);
    }

    // Add Joint 1 Spool Pin + Neck at the rear of the Head
    joint_pin_and_neck(j);
}

// ============================================================================
// Parts 2..5: Intermediate Articulated Body Segments (idx = 1..4)
// Connects Joint (idx-1) at front [Socket] to Joint (idx) at rear [Pin]
// ============================================================================
module body_segment_mid(idx) {
    j_front = idx - 1;
    j_rear  = idx;

    x_front = joint_x[j_front];
    x_rear  = joint_x[j_rear];
    h_front = joint_h[j_front];
    h_rear  = joint_h[j_rear];
    r_nose  = nose_r[j_front];
    r_cup   = get_cup_r(j_rear);

    w_seg   = seg_half_w[idx];
    h_seg   = seg_max_h[idx];
    x_mid   = (x_front + x_rear) * 0.5;

    difference() {
        union() {
            // Front half of body segment: Socket Nose cylinder -> Mid-segment cross section
            hull() {
                translate([x_front, 0, 0])
                    cylinder(r = r_nose, h = h_front);
                snake_cross_section(x_mid - 1.5, w_seg, h_seg, 1.2);
            }

            // Rear half of body segment: Mid-segment cross section -> Rear Cup cylinder
            hull() {
                snake_cross_section(x_mid - 1.5, w_seg, h_seg, 1.2);
                snake_cross_section(x_rear - 2.5, w_seg - 0.4, h_rear + 1.0, 1.2);
                translate([x_rear, 0, 0])
                    cylinder(r = r_cup + 1.5, h = h_rear);
            }

            // Sculpted dorsal diamond scales on the spine between joints
            body_scale_details(x_front + r_nose * 0.6, x_rear - r_cup * 0.6, w_seg, w_seg - 0.5, h_seg, h_seg - 0.6);
        }

        // 1. Trim front nose envelope so it rotates freely inside anterior segment's cup
        posterior_nose_trim(j_front);

        // 2. Subtract front Socket Bore + Throat Opening at Joint (idx-1)
        posterior_socket_cutout(j_front);

        // 3. Subtract rear Cup Cutout at Joint (idx)
        anterior_cup_cutout(j_rear);

        // 4. Carve subtle lateral scale grooves on flanks
        lateral_scale_grooves(x_front + 6.0, x_rear - 6.0, w_seg - 0.3, h_seg);

        // 5. Ensure flat bottom on Z = 0
        translate([-90, -30, -10])
            cube([180, 60, 10]);
    }

    // Add rear Joint (idx) Spool Pin + Neck
    joint_pin_and_neck(j_rear);
}

// ============================================================================
// Part 6: Posterior Body Segment 5 / Sculpted Tail (parts_6.stl)
// Connects Joint 5 (index 4) at front [Socket] and tapers to tail_tip_x (+75.0)
// ============================================================================
module part_6_tail() {
    j_front = 4; // Joint 5 at x = +51.0
    x_front = joint_x[j_front];
    h_front = joint_h[j_front];
    r_nose  = nose_r[j_front];

    w_seg   = seg_half_w[5];
    h_seg   = seg_max_h[5];

    difference() {
        union() {
            // Section 1: Front Socket Nose at Joint 5 -> Anterior Tail Body
            hull() {
                translate([x_front, 0, 0])
                    cylinder(r = r_nose, h = h_front);
                snake_cross_section(x_front + 7.5, w_seg, h_seg, 1.2);
            }

            // Section 2: Anterior Tail Body -> Mid Tail Taper
            hull() {
                snake_cross_section(x_front + 7.5, w_seg, h_seg, 1.2);
                snake_cross_section(x_front + 16.0, w_seg * 0.66, h_seg * 0.72, 1.0);
            }

            // Section 3: Mid Tail Taper -> Rounded Tail Tip resting on build plate Z = 0
            hull() {
                snake_cross_section(x_front + 16.0, w_seg * 0.66, h_seg * 0.72, 1.0);
                translate([tail_tip_x - 2.4, 0, 0]) {
                    cylinder(r = 2.4, h = 2.6);
                    translate([0, 0, 2.6])
                        cylinder(r1 = 2.4, r2 = 1.0, h = 1.8);
                }
            }

            // Sculpted dorsal tail scales / rattle ridges
            for (k = [0 : 2]) {
                t  = k / 3.0;
                xk = x_front + 6.5 + k * 4.5;
                wk = w_seg * (1 - 0.45 * t);
                hk = h_seg * (1 - 0.38 * t);
                translate([xk, 0, hk - 0.8])
                    scale([1.1, 0.7, 0.45])
                        cylinder(r1 = wk * 0.35, r2 = wk * 0.12, h = 1.3, $fn = 6);
            }
        }

        // 1. Trim front nose envelope at Joint 5
        posterior_nose_trim(j_front);

        // 2. Subtract front Socket Bore + Throat Opening at Joint 5
        posterior_socket_cutout(j_front);

        // 3. Carve subtle lateral tail grooves
        lateral_scale_grooves(x_front + 5.0, tail_tip_x - 6.0, w_seg * 0.75, h_seg * 0.8);

        // 4. Ensure flat bottom on Z = 0
        translate([-90, -30, -10])
            cube([180, 60, 10]);
    }
}

// ============================================================================
// Part Selector & Kinematic Chain Assembly
// ============================================================================

// Render a single rigid part (p = 1..6) in its neutral coordinate frame
module render_single_part(p) {
    if (p == 1) {
        part_1_head();
    } else if (p >= 2 && p <= 5) {
        body_segment_mid(p - 1);
    } else if (p == 6) {
        part_6_tail();
    }
}

// Recursive kinematic chain for previewing articulated poses when joint_angles != [0,0,0,0,0]
module render_kinematic_chain(p = 1) {
    render_single_part(p);
    if (p < 6) {
        jx = joint_x[p - 1];
        ang = joint_angles[p - 1];
        translate([jx, 0, 0])
            rotate([0, 0, ang])
                translate([-jx, 0, 0])
                    render_kinematic_chain(p + 1);
    }
}

// Top-level entry point
if (part_id == 0) {
    // Full assembled model (all 6 parts)
    render_kinematic_chain(1);
} else if (part_id >= 1 && part_id <= 6) {
    // Individual part in neutral coordinates (parts_1.stl .. parts_6.stl)
    render_single_part(part_id);
}
