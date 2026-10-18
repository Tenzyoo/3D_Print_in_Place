// Four-stage, print-in-place telescoping rod. Units: mm.
// Export defaults to the collapsed assembly. Set export_part=1..4 to export
// an individual tube at its collapsed-state coordinates for motion checking.
$fn = 128;

stages = 4;
base_outer_r = 12.5;
wall = 1.6;
slide_gap = 0.5;          // radial clearance: Ri-wall - R(i+1)
outer_r = [for (i=[0:stages-1]) base_outer_r - i*(wall+slide_gap)];
retainer_clear = 0.20;     // radial clearance: tube OD to retaining aperture
stop_overlap = 0.15;      // radial capture overlap of collar and lip
collar_radial = retainer_clear + stop_overlap; // 0.35 beyond shaft OD
length = 110;
travel = 64;              // per adjacent pair; full extension = 110+3*64=302
lip_h = 3.2;
collar_h = 1.6;
collar_top_gap = 0.40;    // axial clearance between collar and lip at hard stop
$fa = 2;
$fs = 0.35;

// Revolved continuous wall profile. Inner radius is straight except for the
// inward retaining lip at the distal end. The moving tube's collar stays
// radially clear of both shaft and bore; only the axial stop faces oppose it.
module tube(i) {
    R = outer_r[i-1];
    inner = R - wall;
    shaft = (i < stages) ? outer_r[i] : inner - slide_gap;
    aperture = (i < stages) ? shaft + retainer_clear : inner;
    radial_bulge = (i > 1) ? collar_radial : 0;
    lip_bottom = length - lip_h;
    lip_top = length - 0.35;
    collar_z = lip_bottom - travel - collar_top_gap - collar_h/2;
    collar_lo = collar_z - collar_h/2;
    collar_hi = collar_z + collar_h/2;

    rotate_extrude(convexity=10)
        polygon(points=concat(
            // outer contour, bottom to top, with chamfered collar edges
            [[R,0], [R,collar_lo-0.4], [R+radial_bulge,collar_lo],
             [R+radial_bulge,collar_hi], [R,collar_hi+0.4], [R,lip_bottom],
             [R, length], [R-0.35,length]],
            // inner contour, top to bottom. 45-degree internal lip ramps.
            [[aperture, length-0.35], [aperture, lip_top],
             [inner, length-0.35], [inner, lip_bottom+0.35],
             [aperture, lip_bottom], [inner, lip_bottom-0.35],
             [inner,0]]
        ));
}

// Default geometry is collapsed. Tubes are concentric, share z=0..110,
// and remain separate shells with captured collars (no fused cylinders).
// export_part is supplied on the CLI for separate part STL exports.
export_part = is_undef(export_part) ? 0 : export_part;
if (export_part == 0) {
    for (i=[1:stages]) tube(i);
} else {
    assert(export_part >= 1 && export_part <= stages, "export_part must be 1..4");
    tube(export_part);
}
