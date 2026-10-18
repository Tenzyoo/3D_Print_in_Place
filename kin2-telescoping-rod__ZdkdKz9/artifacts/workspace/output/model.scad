// =====================================================================
// 4-stage print-in-place telescoping rod (FDM, PLA, 0.4 nozzle, 0.2 layer)
// Units: mm. Axis = +Z. Printed upright, collapsed, every tube on the bed.
//
// Tube 1 = outermost ... tube 4 = innermost.
// Each inner tube k (k>=2) carries
//   * a bottom COLLAR that slides in the bore of tube k-1 and hits the
//     top LIP of tube k-1 at full extension  (pull-out stop),
//   * a top FLANGE that rests above the top face of tube k-1
//     (push-through stop, also a finger grip).
// Each outer tube k (k<=3) carries a top inward LIP.
// All overhangs (lip underside, flange underside, bottom chamfers) are
// 45 deg cones, so no support material is needed anywhere.
//
// part = 0 -> whole assembly, part = 1..4 -> single tube
// =====================================================================

part = 0;

/* ---------------- parameters ---------------- */
N        = 4;          // number of tubes
OD_max   = 25;         // outer diameter of tube 1
wall     = 1.2;        // tube wall thickness (3 x 0.4 lines)
clr      = 0.5;        // radial sliding clearance, per side (0.4-0.6 spec)
stop_dep = 1.4;        // radial depth of collar / lip (engagement = stop_dep - clr)
L1       = 107;        // length of tube 1
step_L   = 4;          // each inner tube is this much longer (protrudes above)
collar_h = 18;         // collar height incl. 45 deg top cone
lip_h    = 4;          // lip height incl. 45 deg bottom cone
flange_r = 2.0;        // radial overhang of top flange over tube below
flange_gz= 0.6;        // axial gap flange underside <-> top of outer tube (3 layers)
ef       = 0.4;        // 45 deg bottom chamfers (elephant-foot relief)
eps      = 0.01;
$fn      = 160;

/* ---------------- derived ---------------- */
pitch = wall + clr + stop_dep;                 // radius step between tubes
function r_out(k) = OD_max/2 - (k-1)*pitch;    // tube body outer radius
function r_in(k)  = r_out(k) - wall;           // bore radius
function len(k)   = L1 + (k-1)*step_L;
function r_col(k) = r_in(k-1) - clr;           // collar outer radius (k>=2)
function r_lip(k) = r_out(k+1) + clr;          // lip inner radius (k<=N-1)
function r_fl(k)  = r_out(k) + flange_r;       // flange outer radius (k>=2)
// travel of tube k+1 inside tube k until collar cone meets lip cone
function travel(k) = len(k) - lip_h - collar_h + (r_in(k) - r_out(k+1));
// drop of tube k+1 until its flange cone touches tube k top inner edge
function drop(k)   = flange_gz + clr;

total_ext = len(N) + travel(1) + travel(2) + travel(3);
echo(str("collapsed length = ", len(N), " mm, max OD = ", 2*r_out(1),
         " mm (flanges r=", r_fl(2), ")"));
echo(str("travel 1-2/2-3/3-4 = ", travel(1), " / ", travel(2), " / ", travel(3),
         " mm, extended length = ", total_ext, " mm"));
echo(str("radial stop engagement = ", stop_dep - clr, " mm, innermost ID = ",
         2*r_in(N), " mm"));

assert(2*r_out(1) <= 25, "OD too large");
assert(r_fl(2) <= OD_max/2, "flange exceeds max OD");
assert(len(N) <= 120, "collapsed length too long");
assert(total_ext >= 300, "extended length too short");
assert(clr >= 0.4 && clr <= 0.6, "clearance out of spec");
assert(r_in(N) > 0.5, "innermost tube has no bore");

/* ---------------- 2D half-profile (r,z) of tube k ---------------- */
module profile(k) {
    Ro = r_out(k); Ri = r_in(k); L = len(k);
    difference() {
        union() {
            // body wall
            translate([Ri, 0]) square([wall, L]);
            // bottom collar (k>=2): 45 deg bottom chamfer, 45 deg top cone
            if (k >= 2) {
                rc = r_col(k);
                polygon([[Ro - eps, 0], [rc - ef, 0], [rc, ef],
                         [rc, collar_h - (rc - Ro)], [Ro - eps, collar_h]]);
            }
            // top inward lip (k<=N-1): 45 deg cone underneath
            if (k <= N - 1) {
                rl = r_lip(k);
                polygon([[Ri + eps, L - lip_h], [Ri + eps, L], [rl, L],
                         [rl, L - lip_h + (Ri - rl)]]);
            }
            // top outward flange (k>=2): 45 deg cone underneath
            if (k >= 2) {
                z0 = len(k-1) + flange_gz;
                rf = r_fl(k);
                polygon([[Ro - eps, z0], [rf, z0 + (rf - Ro)], [rf, L],
                         [Ro - eps, L]]);
            }
        }
        // 45 deg chamfer at the bottom edge of the bore
        polygon([[Ri - 1, -1], [Ri + ef + 1, -1], [Ri, ef]]);
        // 45 deg chamfer at the bottom outer edge of tube 1
        if (k == 1) polygon([[Ro + 1, -1], [Ro - ef - 1, -1], [Ro, ef]]);
    }
}

module tube(k) rotate_extrude(convexity = 6) profile(k);

if (part == 0) for (k = [1:N]) tube(k);
else tube(part);
