# Print orientation and checks

## Print orientation

Print the combined `model.stl` in its supplied orientation with the flat body bottoms on the build plate. The link bodies lie in the XY plane and all five joint axes are vertical (Z). Use PLA, a 0.4 mm nozzle, 0.2 mm layer height, and supports disabled. The pin flange underside is a 45-degree cone; the open C-bearing slots and the gaps under the retainers remain free of support material. Do not split or rearrange the six bodies before printing.

## Geometry and slicing checks

- OpenSCAD 2021.01 rendered the full assembly and all six individual link exports from `model.scad`.
- PrusaSlicer 2.7.2 `--info` reports the combined STL as manifold with 6 parts and dimensions 144.5 x 14.0 x 10.0 mm. Each `parts_*.stl` is manifold and has 1 connected part.
- A mesh boolean intersection check was run on every adjacent pair at -25, 0, and +25 degrees. All 15 cases have zero intersection volume.
- Joint radial shaft-to-bore clearance is 3.0 - 2.5 = 0.5 mm. The retainer underside has 0.6 mm nominal axial clearance above the 7.2 mm socket wall. The 230-degree bearing arc and 130-degree stem slot leave a path for the pin stem over the specified range.
- The combined STL was sliced with `/opt/slicer/p1s_pla_0.20mm_nosupport.ini` (PLA, 0.4 mm nozzle, 0.2 mm layers, supports off). PrusaSlicer exported G-code successfully as 50 layers; no support material is configured or generated.

The listed angular checks validate each joint independently while adjacent links remain neutral. Printer calibration and first-layer quality still affect the feel of print-in-place joints; the designed clearances are nominal CAD dimensions.
