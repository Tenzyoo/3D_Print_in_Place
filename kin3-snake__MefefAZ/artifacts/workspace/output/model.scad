// ============================================================================
//  Print-in-place articulated snake
//  6 rigid parts: 1 head + 5 body links, 5 revolute joints about +Z
//  Units: mm.  Neutral (straight) printing pose = world pose.
//
//  EXPORT SWITCH
//    export_part = 0  -> complete model (all six parts, neutral pose)
//    export_part = 1  -> head
//    export_part = 2  -> body link 1
//    ...
//    export_part = 6  -> body link 5
//
//  Designed for PLA / 0.4 mm nozzle / 0.2 mm layers, no support.
//  Nominal one-sided radial shaft/hole clearance = 0.55 mm.
//  Nominal retaining-flange / counterbore radial clearance = 0.50 mm.
//  The flanges capture the socket in BOTH axial directions; measured first
//  axial contact is at about +0.75 mm and -1.00 mm relative displacement.
// ============================================================================

/* [Export] */
export_part = 0;       // [0:All, 1:Head, 2:Body1, 3:Body2, 4:Body3, 5:Body4, 6:Body5]

/* [Main dimensions] */
T          = 10.0;     // part thickness (Z)
L          = 26.0;     // joint pitch / nominal body-link length
HEAD_JOINT = 28.0;     // X of joint 1
N_BODY     = 5;
BODY_W     = 18.0;     // body width (Y)
BODY_R     = 2.0;      // body corner radius
ARM_W      = 5.0;      // width of the arm that passes through the C-mouth

/* [Head / tail decoration] */
HEAD_ARM_X1   = 17.0;  // start of the head's rear arm
HEAD_SNOUT_X  = 2.0;
HEAD_SNOUT_R  = 2.0;
HEAD_SKULL_X  = 10.0;
HEAD_SKULL_R  = 10.0;
HEAD_REAR_X   = 12.0;
HEAD_REAR_R   = 8.0;
EYE_X         = 8.0;
EYE_Y         = 6.8;
TAIL_FULL_X   = 16.0;  // tail taper start
TAIL_MID_X    = 21.0;
TAIL_MID_HALF = 6.0;

/* [Joint dimensions] */
R_PIN      = 3.5;      // pin waist radius
R_HOLE     = 4.05;     // socket narrow-hole radius  (0.55 radial clearance)
R_FLANGE   = 5.0;      // bottom pin retaining-flange radius
R_FLANGE_T = 5.0;      // top pin retaining-flange radius
R_CB       = 5.5;      // socket counterbore radius (0.5 radial clearance)
R_TOP_START= 4.2;      // radius where the upper socket cone starts
R_RING     = 7.5;      // outside radius of the C-shaped socket ring
R_SEP      = 8.0;      // body clearance radius around a neighbouring joint
Z_FLANGE   = 2.0;      // bottom retaining flange top
Z_CB_BOT   = 2.25;     // bottom counterbore height
Z_LIP_BOT  = 3.75;     // bottom conical shoulder ends / narrow lip starts
Z_LIP_TOP  = 6.5;      // narrow lip ends / top conical shoulder starts
Z_CB_TOP   = 7.9;      // top counterbore starts
Z_PIN_TCONE_END = 8.1; // top flange cylinder starts
Z_PIN_TCONE= 6.6;      // start of self-supporting top flange cone
MOUTH_HALF = 80.0;     // half angle of C-ring mouth (deg), opening faces -X
MOUTH_CUT_R= 50.0;     // radial extent of the mouth cutting wedge
NECK_X1    = 6.4;      // socket-ring-to-body neck start
NECK_X2    = 10.0;     // socket-ring-to-body neck end
NECK_W     = 6.0;
EYE_R      = 1.7;
EYE_H      = 0.8;

$fn = 72;

// ----------------------------------------------------------------------------
// helpers
// ----------------------------------------------------------------------------
function joint_x(i) = HEAD_JOINT + (i-1)*L;   // i = 1..5

module rounded_rect_2d(x1, x2, halfw, r) {
    hull() {
        translate([x1+r, -halfw+r]) circle(r=r, $fn=48);
        translate([x2-r, -halfw+r]) circle(r=r, $fn=48);
        translate([x1+r,  halfw-r]) circle(r=r, $fn=48);
        translate([x2-r,  halfw-r]) circle(r=r, $fn=48);
    }
}

// vertical pin: bottom flange + waist + self-supporting conical top flange
module pin_solid() {
    rotate_extrude(convexity=10, $fn=96)
        polygon(points=[
            [0,0],
            [R_FLANGE,0],
            [R_FLANGE,Z_FLANGE],
            [R_PIN,Z_FLANGE],
            [R_PIN,Z_PIN_TCONE],
            [R_FLANGE_T,Z_PIN_TCONE_END],
            [R_FLANGE_T,T],
            [0,T]
        ]);
}

// volume to subtract from the mating part (socket)
module socket_cavity() {
    rotate_extrude(convexity=10, $fn=96)
        polygon(points=[
            [0,0],
            [R_CB,0],
            [R_CB,Z_CB_BOT],
            [R_HOLE,Z_LIP_BOT],
            [R_HOLE,Z_LIP_TOP],
            [R_TOP_START,Z_LIP_TOP],
            [R_CB,Z_CB_TOP],
            [R_CB,T],
            [0,T]
        ]);
}

// C-ring mouth, opening towards -X.  Subtract through the full thickness.
module mouth_cut() {
    translate([0,0,-1])
        linear_extrude(height=T+2, convexity=10)
            polygon(points=concat(
                [[0,0]],
                [for (a=[180-MOUTH_HALF:2.5:180+MOUTH_HALF])
                    [MOUTH_CUT_R*cos(a), MOUTH_CUT_R*sin(a)]]
            ));
}

module arm_2d(x1, x2) {
    hull() {
        translate([x1, -ARM_W/2+1]) circle(r=1, $fn=32);
        translate([x1,  ARM_W/2-1]) circle(r=1, $fn=32);
        translate([x2, -ARM_W/2+1]) circle(r=1, $fn=32);
        translate([x2,  ARM_W/2-1]) circle(r=1, $fn=32);
    }
}

module neck_2d() {
    hull() {
        translate([NECK_X1, -NECK_W/2+1]) circle(r=1, $fn=32);
        translate([NECK_X1,  NECK_W/2-1]) circle(r=1, $fn=32);
        translate([NECK_X2, -NECK_W/2+1]) circle(r=1, $fn=32);
        translate([NECK_X2,  NECK_W/2-1]) circle(r=1, $fn=32);
    }
}

// ----------------------------------------------------------------------------
// head (part 1)
// ----------------------------------------------------------------------------
module head_body_2d() {
    hull() {
        translate([HEAD_SNOUT_X,0]) circle(r=HEAD_SNOUT_R, $fn=72); // snout
        translate([HEAD_SKULL_X,0]) circle(r=HEAD_SKULL_R, $fn=96); // skull
        translate([HEAD_REAR_X,0])  circle(r=HEAD_REAR_R,  $fn=96); // rear taper
    }
}

module head_part() {
    union() {
        linear_extrude(height=T, convexity=10) head_body_2d();
        linear_extrude(height=T, convexity=10) arm_2d(HEAD_ARM_X1, HEAD_JOINT);
        translate([HEAD_JOINT,0,0]) pin_solid();
        // low, non-functional eye bumps on the top surface
        translate([EYE_X, EYE_Y, T]) cylinder(h=EYE_H, r=EYE_R, $fn=48);
        translate([EYE_X,-EYE_Y, T]) cylinder(h=EYE_H, r=EYE_R, $fn=48);
    }
}

// ----------------------------------------------------------------------------
// body links (parts 2..6), local X=0 is the front joint
// ----------------------------------------------------------------------------
module body_block_2d() {
    rounded_rect_2d(R_SEP, L-R_SEP, BODY_W/2, BODY_R);
}

module tail_2d() {
    polygon(points=[
        [R_SEP, -BODY_W/2],
        [TAIL_FULL_X, -BODY_W/2],
        [TAIL_MID_X,  -TAIL_MID_HALF],
        [L,            0.0],
        [TAIL_MID_X,   TAIL_MID_HALF],
        [TAIL_FULL_X,  BODY_W/2],
        [R_SEP,  BODY_W/2]
    ]);
}

module body_part(idx) {
    difference() {
        union() {
            // C-shaped female socket at the front
            cylinder(h=T, r=R_RING, $fn=96);
            linear_extrude(height=T, convexity=10) neck_2d();

            // main link body
            if (idx < N_BODY)
                linear_extrude(height=T, convexity=10) body_block_2d();
            else
                linear_extrude(height=T, convexity=10) tail_2d();

            // male pin at the rear (not on the last link)
            if (idx < N_BODY) {
                linear_extrude(height=T, convexity=10) arm_2d(L-R_SEP, L);
                translate([L,0,0]) pin_solid();
            }
        }
        socket_cavity();
        mouth_cut();
    }
}

// ----------------------------------------------------------------------------
// export selection
// ----------------------------------------------------------------------------
module complete_model() {
    head_part();
    for (i=[1:N_BODY])
        translate([joint_x(i),0,0]) body_part(i);
}

if (export_part == 0) {
    complete_model();
} else if (export_part == 1) {
    head_part();
} else if (export_part >= 2 && export_part <= 6) {
    i = export_part - 1;
    translate([joint_x(i),0,0]) body_part(i);
}
