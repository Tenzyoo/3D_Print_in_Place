import re, numpy as np
def parse(path):
    """returns list of (z, type, x0, y0, x1, y1) extrusion segments"""
    segs = []; x = y = z = 0.0; e_abs = None; typ = None; rel_e = False
    for line in open(path):
        if line.startswith(';TYPE:'):
            typ = line[6:].strip(); continue
        if line.startswith('M83'): rel_e = True
        if line.startswith('M82'): rel_e = False
        if not (line.startswith('G1') or line.startswith('G0')): continue
        c = line.split(';')[0].split()
        nx, ny, nz, ne = x, y, z, None
        for t in c[1:]:
            if t[0] == 'X': nx = float(t[1:])
            elif t[0] == 'Y': ny = float(t[1:])
            elif t[0] == 'Z': nz = float(t[1:])
            elif t[0] == 'E': ne = float(t[1:])
        extr = ne is not None and (ne > 0 if rel_e else (e_abs is not None and ne > e_abs))
        if not rel_e and ne is not None: e_abs = ne
        if extr and (nx != x or ny != y):
            segs.append((round(nz, 3), typ, x, y, nx, ny))
        x, y, z = nx, ny, nz
    return segs
