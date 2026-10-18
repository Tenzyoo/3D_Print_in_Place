import sys, numpy as np, trimesh
d = sys.argv[1] if len(sys.argv) > 1 else '/app/work'
names = ['body', 'tail_1', 'tail_2', 'tail_3']
ms = [trimesh.load(f'{d}/p{i+1}.stl') for i in range(4)]
allv = np.vstack([m.vertices for m in ms])
print('model bbox', allv.min(0).round(2), allv.max(0).round(2), 'size', (allv.max(0)-allv.min(0)).round(2))
for n, m in zip(names, ms):
    print(n, 'watertight', m.is_watertight, 'vol %.1f' % m.volume, 'bodies', len(m.split(only_watertight=False)),
          'bbox', m.bounds.round(2).tolist())
    # overhang: downward faces flatter than 45deg (normal_z < -cos45), not on bed
    fn = m.face_normals; c = m.triangles_center; a = m.area_faces
    bad = (fn[:, 2] < -np.cos(np.radians(44))) & (c[:, 2] > 0.05)
    print('   overhang<45 area %.2f mm2' % a[bad].sum())
    if bad.any():
        # cluster report
        pts = c[bad]; ar = a[bad]
        import scipy.cluster.hierarchy as h
        if len(pts) > 1:
            lab = h.fcluster(h.linkage(pts, 'single'), 3.0, 'distance')
        else:
            lab = np.array([1])
        for l in np.unique(lab):
            s = lab == l
            if ar[s].sum() > 0.05:
                print('     cluster area %.2f at' % ar[s].sum(), pts[s].mean(0).round(1), 'zmin %.2f' % pts[s][:, 2].min(),
                      'min angle %.1f' % np.degrees(np.arccos(-fn[bad][s][:, 2].min())))
    # local minima vertices (islands) above bed
    v = m.vertices; nb = m.vertex_neighbors
    lm = [i for i in range(len(v)) if v[i, 2] > 0.05 and all(v[j, 2] > v[i, 2] + 1e-6 for j in nb[i])]
    print('   local-min vertices above bed:', len(lm), v[lm][:8].round(2).tolist())
