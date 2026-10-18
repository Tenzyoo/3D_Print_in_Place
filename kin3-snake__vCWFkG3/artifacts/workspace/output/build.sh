#!/bin/sh
# Rebuild all deliverables and re-run the checks
set -e
cd "$(dirname "$0")"
mkdir -p parts
for k in 1 2 3 4 5 6; do openscad -D part=$k -o parts/parts_$k.stl model.scad & done
openscad -D part=0 -o model.stl model.scad &
wait
python3 checks/make_joints.py joints.json
python3 checks/verify_geometry.py .
prusa-slicer --export-gcode --load /opt/slicer/p1s_pla_0.20mm_nosupport.ini   --output /tmp/snake_nosup.gcode   model.stl
prusa-slicer --export-gcode --load /opt/slicer/p1s_pla_0.20mm_autosupport.ini --output /tmp/snake_autosup.gcode model.stl
grep -c "TYPE:Support" /tmp/snake_autosup.gcode || true
python3 checks/verify_gcode_gaps.py /tmp/snake_nosup.gcode .
