# Print orientation and verification

Print `model.stl` in the supplied retracted pose, upright with the common tube
axis parallel to printer Z and the four lower rims on the build plate. Use PLA,
0.4 mm nozzle, 0.2 mm layer height, and disable supports. The tube bores and
inter-tube clearances are open along Z; the only bridges are the short 0.5 mm
radial gaps at the captive slider heads. No support material is needed in the
moving gaps.

The nominal sliding clearance between each tube OD and its parent tube ID is
0.5 mm radially. Each narrow slider stem has 0.6 mm side clearance in its 3 mm
retaining slot; each 4 mm head has 0.5 mm side clearance. The head sits 0.4 mm
away from the parent tube's outside wall. Deeper slider heads pass through
phase-shifted 5 mm relief slots in ancestor tubes; those slots are open at the
top and do not serve as retention stops. The retracted pose leaves 4 mm axial
clearance to the retraction end of each retaining slot. The extension stop is
at 70 mm per stage.
The tube lengths are 100 mm, giving a 100 mm collapsed assembly and a 310 mm
fully extended assembly (100 + 3 x 70 mm). Head-to-slot-end contact occurs only
at the designed travel limit.

The `parts/parts_1.stl` through `parts/parts_4.stl` files were exported from the
same OpenSCAD source with the same origin and retracted pose as `model.stl`.
Geometry and slicing checks used OpenSCAD CGAL rendering and PrusaSlicer 2.7.2
with `/opt/slicer/p1s_pla_0.20mm_nosupport.ini`. PrusaSlicer reports four
manifold parts in the assembled STL, 100 mm Z height, and completes a 500-layer
G-code export without support toolpaths. Its stability check warns of low bed
adhesion and loose extrusions; use a clean, well-leveled build plate and inspect
the first layers. A brim was not enabled because brim material could bridge the
0.5 mm gaps between the nested tube bases. The slicer check confirms geometric
feasibility only; first-article clearance should be validated on the target
printer because PLA shrinkage, flow calibration, and elephant foot affect
print-in-place motion.
