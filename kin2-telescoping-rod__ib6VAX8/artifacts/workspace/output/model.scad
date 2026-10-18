// =====================================================================
// 4-stage print-in-place telescoping rod (FDM, PLA, 0.4 nozzle, 0.2 layer)
// All four tubes are printed nested, coaxial, standing upright (axis = +Z),
// every tube starting on the build plate (z = 0).  No supports needed:
// every downward-facing surface is either on the bed or a 45 deg cone.
//
// Stage i (outer tube i, inner tube i+1):
//   * sliding fit A : bottom lip / top lip bore of tube i  <->  wall of tube i+1
//   * sliding fit B : counterbore of tube i                 <->  collar of tube i+1
//     both with radial clearance g (single side)
//   * extension stop: 45 deg top cone of collar(i+1) hits 45 deg underside of top lip(i)
//   * collapse  stop: 45 deg underside of collar(i+1) hits 45 deg top of bottom lip(i)
//     (print-state normal gap = dv/sqrt(2), horizontal gap per layer = dv)
//
// part = 0 : whole assembly, 1..4 : single tube (same coordinate system)
// ext  = 0 : as printed (collapsed); 0..1 : preview of extension fraction
// =====================================================================

part = 0;
ext  = 0;

$fn = 128;

// ---------------- parameters ----------------
g     = 0.5;    // radial clearance on all sliding surfaces (single side)
t     = 1.2;    // minimum wall thickness of a tube (counterbore region)
h     = 1.3;    // collar radial height = depth of counterbore step
dv    = 0.85;   // vertical offset of parallel 45deg cones at the collapse stop
b     = 3.0;    // height of bottom lip (cylindrical part)
cL    = 10.0;   // cylindrical length of collar
lipL  = 10.0;   // length of top lip (guide length at full extension)
ch    = 0.4;    // 45deg bottom chamfers (elephant-foot relief at z=0)
tc    = 0.4;    // top edge chamfers
R1    = 12.4;   // outer radius of tube 1 (OD 24.8 <= 25)
rb4   = 1.4;    // bore radius of innermost tube 4
L     = [110, 113, 116, 119];   // tube lengths (tube 4 top = collapsed length)

step  = t + h + g;                       // radius reduction per stage
function Ro(i) = R1 - (i-1)*step;        // outer radius of tube i (1..4)
z0    = b - g + dv;                      // start of collar underside cone
function zt(i) = L[i-1] - lipL;          // bottom of cylindrical top lip, tube i
// travel of tube i+1 relative to tube i until extension stop
function stroke(i) = zt(i) + g - z0 - 2*h - cL;

// ---------------- profile of tube i in (r,z) ----------------
function outer_pts(i) =
    let(R = Ro(i), Lz = L[i-1])
    (i == 1)
    ? [ [R-ch, 0], [R, ch], [R, Lz-tc], [R-tc, Lz] ]
    : [ [R-ch, 0], [R, ch],
        [R, z0], [R+h, z0+h],                 // collar underside (45deg)
        [R+h, z0+h+cL], [R, z0+2*h+cL],       // collar top (45deg) = stop face
        [R, Lz-tc], [R-tc, Lz] ];

function inner_pts(i) =
    let(Lz = L[i-1])
    (i == 4)
    ? [ [rb4+tc, Lz], [rb4, Lz-tc], [rb4, ch], [rb4+ch, 0] ]
    : let(rl = Ro(i+1) + g, Rc = Ro(i+1) + h + g)
      [ [rl+tc, Lz], [rl, Lz-tc],
        [rl, zt(i)], [Rc, zt(i)-h],            // top lip underside (45deg) = stop face
        [Rc, b+h], [rl, b],                    // bottom lip top (45deg) = collapse stop
        [rl, ch], [rl+ch, 0] ];

module tube(i) {
    rotate_extrude(convexity = 6)
        polygon(concat(outer_pts(i), inner_pts(i)));
}

// cumulative offset of tube i for preview of extension
function offs(i) = (i <= 1) ? 0 : offs(i-1) + ext*stroke(i-1);

echo(str("OD tube1..4 = ", [for (i=[1:4]) 2*Ro(i)]));
echo(str("strokes = ", [for (i=[1:3]) stroke(i)]));
echo(str("collapsed length = ", L[3], "  extended length = ",
         L[3] + stroke(1) + stroke(2) + stroke(3)));

if (part == 0) {
    for (i = [1:4]) translate([0, 0, offs(i)]) tube(i);
} else {
    translate([0, 0, offs(part)]) tube(part);
}
