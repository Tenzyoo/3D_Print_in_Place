# Print-in-place articulated snake

This directory contains the final deliverables for a 6-part, 5-joint
print-in-place snake.

- `model.scad` — parametric OpenSCAD source (`export_part=0` = all, `1` = head,
  `2..6` = body links 1..5)
- `model.stl` — complete model in the neutral straight pose
- `parts/parts_1.stl` … `parts/parts_6.stl` — the six rigid parts in the same
  world coordinates/pose as `model.stl`
- `joints.json` — revolute joint declarations and motion ranges
- `PRINT_ORIENTATION_AND_CHECKS.md` — Chinese report: print orientation,
  clearances, axial retention, geometry checks and actual slicing checks
- `model.gcode` — actual PrusaSlicer output for the stated PLA / 0.4 mm /
  0.2 mm no-support condition
- `validation/` — reproducible validation scripts and JSON reports

Part numbering: 1 = head, 2 = body 1, 3 = body 2, 4 = body 3, 5 = body 4,
6 = body 5. Joint 1 is head–body1; joints 2–5 are body1–body2 … body4–body5.
All joint axes are +Z at x = 28, 54, 80, 106, 132 mm, y = z = 0.

Neutral overall size is 158 × 20 × 10.8 mm. Functional range is ±30° per joint
(requirement ±25°), with ±35° tested collision-free. Radial shaft/hole
clearance is 0.55 mm; flange/counterbore radial clearance is 0.50 mm.
