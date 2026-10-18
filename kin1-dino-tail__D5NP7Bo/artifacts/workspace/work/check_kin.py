import sys, json, itertools, numpy as np, trimesh, manifold3d as mf
d = sys.argv[1] if len(sys.argv) > 1 else '/app/work'
names = ['body', 'tail_1', 'tail_2', 'tail_3']
ms = [trimesh.load(f'{d}/p{i+1}.stl') for i in range(4)]
J = [(46, 0), (31, 0), (16, 0)]          # joint i: parent i, child i+1

def to_mf(m):
    return mf.Manifold(mf.Mesh(vert_properties=np.asarray(m.vertices, np.float32),
                               tri_verts=np.asarray(m.faces, np.uint32)))
MF = [to_mf(m) for m in ms]

def rotz(deg, c):
    T = trimesh.transformations.rotation_matrix(np.radians(deg), [0, 0, 1], [c[0], c[1], 0])
    return T

def pose(angles, dz=None):
    """4x4 transforms of each part for joint angles (deg) (+ optional extra z shift of one part)"""
    Ts = [np.eye(4)]
    for i, a in enumerate(angles):
        # joint origin moves with parent
        Ts.append(Ts[-1] @ rotz(a, J[i]))
    return Ts

def tf(m, T):
    return m.transform(T[:3, :].tolist()) if False else m.transform(np.asarray(T[:3, :]))

def inter_vol(a, b):
    return (a ^ b).volume()

def min_dist(i, Ti, j, Tj, radius=None):
    """approx min distance between parts (vertices of each to surface of other)"""
    A = ms[i].copy(); A.apply_transform(Ti)
    B = ms[j].copy(); B.apply_transform(Tj)
    best = 1e9
    for P, Q in ((A, B), (B, A)):
        v = P.vertices
        # prefilter to vertices near Q bbox
        lo, hi = Q.bounds[0] - 2, Q.bounds[1] + 2
        v = v[np.all((v > lo) & (v < hi), axis=1)]
        if len(v) == 0: continue
        _, dist, _ = trimesh.proximity.closest_point(Q, v)
        best = min(best, dist.min())
    return best

def collide(angles, extra=None):
    Ts = pose(angles)
    if extra: Ts[extra[0]] = extra[1] @ Ts[extra[0]]
    parts = [MF[i].transform(np.asarray(Ts[i][:3, :])) for i in range(4)]
    vol = 0; pairs = []
    for i, j in itertools.combinations(range(4), 2):
        v = inter_vol(parts[i], parts[j])
        if v > 1e-4: pairs.append((names[i], names[j], round(v, 4)))
        vol += v
    return vol, pairs

res = {}
# neutral clearances
neutral = {}
for i, j in [(0, 1), (1, 2), (2, 3)]:
    neutral[f'{names[i]}-{names[j]}'] = round(min_dist(i, np.eye(4), j, np.eye(4)), 3)
res['neutral_min_distance_mm'] = neutral
res['neutral_intersection'] = collide([0, 0, 0])
print('neutral', neutral, res['neutral_intersection'])

# single-joint sweeps
sweeps = {}
for k in range(3):
    ok = []; first_hit = {}
    for sgn in (1, -1):
        a = 0.0
        hit = None
        while a <= 80:
            ang = [0, 0, 0]; ang[k] = sgn * a
            v, p = collide(ang)
            if v > 1e-4:
                hit = a; break
            a += 1.0
        first_hit['+' if sgn > 0 else '-'] = hit
    # clearance at +-20, +-30
    cl = {}
    for a in (-30, -20, 20, 30):
        ang = [0, 0, 0]; ang[k] = a
        Ts = pose(ang)
        cl[str(a)] = round(min(min_dist(i, Ts[i], j, Ts[j]) for i, j in [(k, k+1)] +
                               ([(k-1, k+1)] if k > 0 else []) + ([(k, k+2)] if k + 2 < 4 else [])), 3)
    sweeps[f'J{k+1}'] = {'first_contact_deg': first_hit, 'min_distance_at': cl}
    print(f'J{k+1}', sweeps[f'J{k+1}'])
res['single_joint_sweeps'] = sweeps

# combined extremes
comb = []
for ang in itertools.product((-30, 0, 30), repeat=3):
    v, p = collide(list(ang))
    comb.append({'angles': ang, 'intersection_mm3': round(v, 4)})
res['combined_pose_check'] = {'poses': 27, 'max_intersection_mm3': max(c['intersection_mm3'] for c in comb),
                              'colliding': [c for c in comb if c['intersection_mm3'] > 1e-4]}
print('combined', res['combined_pose_check']['max_intersection_mm3'], res['combined_pose_check']['colliding'])

# axial retention: move the child of each joint continuously along +/-Z (and XY)
# relative to its parent and find the first contact distance (0.05 mm steps)
axial = {}
def first_contact(k, vec, maxd=15.0, step=0.05):
    child = k + 1
    t = step
    while t <= maxd:
        T = np.eye(4); T[:3, 3] = np.asarray(vec) * t
        if inter_vol(MF[child].transform(np.asarray(T[:3, :])), MF[k]) > 1e-4:
            return round(t, 2)
        t += step
    return None
for k in range(3):
    out = {}
    for lab, vec in (('+z', (0, 0, 1)), ('-z', (0, 0, -1)), ('+x', (1, 0, 0)), ('-x', (-1, 0, 0)),
                     ('+y', (0, 1, 0)), ('-y', (0, -1, 0))):
        out[lab] = first_contact(k, vec)
    axial[f'J{k+1}'] = out
    print('first contact translation', k + 1, out)
res['translation_first_contact_mm'] = axial
json.dump(res, open(f'{d}/kin_results.json', 'w'), indent=1, default=str)
