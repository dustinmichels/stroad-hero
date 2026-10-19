"""Builds the Mats player model into the "Mats" collection of the open .blend.

Run inside Blender (Text Editor > Run Script, or `blender --python build_mats.py`);
re-running replaces the collection. Geometry is authored in Godot space
(x = Mats' left, y = up, z = forward) and converted to Blender space on mesh
creation. Each object's origin is the Godot node it maps to in
player/mats.tscn, and mesh datablock names become the .res file names written
by import_mats.gd.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

COLLECTION = "Mats"

LEG_PIVOT = Vector((0.072, 0.60, 0.0))  # hip
KNEE = Vector((0.0, -0.28, 0.0))  # relative to the hip
ARM_PIVOT = Vector((0.155, 0.975, 0.0))  # shoulder
ELBOW = Vector((0.0, -0.19, 0.0))  # relative to the shoulder
HEAD_PIVOT = Vector((0.0, 1.08, 0.0))  # chin
HEAD_SCALE = 1.12  # face, hair, and cap are scaled up around the chin for kid proportions
ANKLE = Vector((0.0, -0.25, 0.0))  # relative to the knee; shoes rotate here
GROUND = -(LEG_PIVOT.y + KNEE.y + ANKLE.y)  # floor height in ankle space

# name: (sRGB color, roughness, metallic). Backpack and shoe upper are tinted at runtime.
PALETTE = {
    "jacket": ((0.96, 0.48, 0.10), 0.7, 0.0),
    "jacket_trim": ((0.78, 0.35, 0.07), 0.75, 0.0),
    "zipper": ((0.86, 0.87, 0.89), 0.4, 0.6),
    "skin": ((0.94, 0.75, 0.62), 0.6, 0.0),
    "eye": ((0.08, 0.06, 0.05), 0.4, 0.0),
    "eye_shine": ((1.0, 1.0, 1.0), 0.3, 0.0),
    "blush": ((0.95, 0.62, 0.56), 0.6, 0.0),
    "brow": ((0.45, 0.31, 0.16), 0.9, 0.0),
    "lip": ((0.66, 0.34, 0.31), 0.6, 0.0),
    "hair": ((0.70, 0.52, 0.28), 0.9, 0.0),
    "pants": ((0.18, 0.28, 0.50), 0.8, 0.0),
    "shoe_upper": ((0.80, 0.14, 0.12), 0.75, 0.0),
    "shoe_white": ((0.95, 0.95, 0.92), 0.8, 0.0),
    "strap": ((0.15, 0.16, 0.18), 0.85, 0.0),
    "backpack": ((0.20, 0.55, 0.30), 0.8, 0.0),
    "cap": ((0.80, 0.12, 0.10), 0.75, 0.0),
    "cap_brim": ((0.62, 0.08, 0.07), 0.75, 0.0),
}

X = Vector((1.0, 0.0, 0.0))
Y = Vector((0.0, 1.0, 0.0))
Z = Vector((0.0, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Shape primitives (all in Godot space)


def _se(value: float, exponent: float) -> float:
    return math.copysign(abs(value) ** (2.0 / exponent), value)


def ring(center, u, v, a, b, n, p=2.0, p_low=None):
    """Superellipse loop around `center` in the u/v plane; `p_low` shapes the -v half."""
    points = []
    for i in range(n):
        t = 2.0 * math.pi * i / n
        c, s = math.cos(t), math.sin(t)
        e = p if p_low is None or s >= 0.0 else p_low
        points.append(center + u * (a * _se(c, e)) + v * (b * _se(s, e)))
    return points


def hring(y, cx, cz, hw, hd, n, p=2.0):
    """Horizontal loop; index n/4 sits at the front (+z)."""
    return ring(Vector((cx, y, cz)), X, Z, hw, hd, n, p)


def _catmull(p0, p1, p2, p3, t):
    return 0.5 * (
        2.0 * p1
        + (p2 - p0) * t
        + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
        + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t
    )


class Profile:
    """Stack of horizontal sections (y, cx, cz, hw, hd, p), ascending y, Catmull-Rom smoothed."""

    def __init__(self, rows, sub=2):
        self.rows = rows
        count = (len(rows) - 1) * sub + 1
        self.dense = [self._sample(i / sub) for i in range(count)]

    def _sample(self, u):
        rows = self.rows
        i = min(int(u), len(rows) - 2)
        f = u - i
        p0, p1 = rows[max(i - 1, 0)], rows[i]
        p2, p3 = rows[i + 1], rows[min(i + 2, len(rows) - 1)]
        return tuple(_catmull(p0[k], p1[k], p2[k], p3[k], f) for k in range(len(p1)))

    def at(self, y):
        d = self.dense
        y = min(max(y, d[0][0]), d[-1][0])
        for a, b in zip(d, d[1:]):
            if y <= b[0]:
                f = (y - a[0]) / (b[0] - a[0]) if b[0] > a[0] else 0.0
                return tuple(a[k] + (b[k] - a[k]) * f for k in range(len(a)))
        return d[-1]

    def point(self, theta, y, off=0.0):
        _, cx, cz, hw, hd, p = self.at(y)
        c, s = math.cos(theta), math.sin(theta)
        return Vector((cx + (hw + off) * _se(c, p), y, cz + (hd + off) * _se(s, p)))

    def normal(self, theta, y, off=0.0):
        e = 1e-3
        d_theta = self.point(theta + e, y, off) - self.point(theta - e, y, off)
        d_y = self.point(theta, y + e, off) - self.point(theta, y - e, off)
        n = d_theta.cross(d_y).normalized()
        _, cx, cz, *_ = self.at(y)
        outward = self.point(theta, y, off) - Vector((cx, y, cz))
        return n if n.dot(outward) >= 0.0 else -n

    def rings(self, n, off=0.0):
        return [hring(r[0], r[1], r[2], r[3] + off, r[4] + off, n, r[5]) for r in self.dense]

    def band(self, y0, y1, n, off):
        return [hring(y, r[1], r[2], r[3] + off, r[4] + off, n, r[5]) for y in (y0, y1) for r in [self.at(y)]]


def ellipsoid(center, radii, n=10, lat=5, rot=None):
    rot = rot or Matrix.Identity(3)
    rings = [[center + rot @ Vector((0.0, -radii.y, 0.0))]]
    for k in range(1, lat):
        phi = -math.pi / 2.0 + math.pi * k / lat
        local = ring(Vector(), X, Z, radii.x * math.cos(phi), radii.z * math.cos(phi), n)
        rings.append([center + rot @ (p + Vector((0.0, radii.y * math.sin(phi), 0.0))) for p in local])
    rings.append([center + rot @ Vector((0.0, radii.y, 0.0))])
    return rings


def tube(points, radii, n):
    """Round tube through `points`; a zero radius closes the end to a point."""
    rings = []
    for i, p in enumerate(points):
        t = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        u = t.cross(X if abs(t.x) < 0.9 else Y).normalized()
        v = t.cross(u)
        rings.append([p] if radii[i] == 0.0 else ring(p, u, v, radii[i], radii[i], n))
    return rings


def strip(points, normals, width, thickness):
    """Flat band (strap, zipper) lying on a surface: rectangles swept along `points`."""
    rings = []
    for i, (p, nrm) in enumerate(zip(points, normals)):
        t = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        side = t.cross(nrm).normalized()
        up = side.cross(t).normalized()
        if up.dot(nrm) < 0.0:
            up = -up
        c = p + up * (thickness * 0.5)
        w, h = side * (width * 0.5), up * (thickness * 0.5)
        rings.append([c + w + h, c - w + h, c - w - h, c + w - h])
    return rings


class Geo:
    """Face soup with per-face material names."""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.face_mats = []

    def _face(self, face, mat):
        self.faces.append(tuple(face))
        self.face_mats.append(mat)

    def loft(self, rings, mat):
        """Skin consecutive loops (a 1-point loop is a pole); open ends get n-gon caps."""
        idx = []
        for r in rings:
            start = len(self.verts)
            self.verts.extend(r)
            idx.append(list(range(start, start + len(r))))
        for a, b in zip(idx, idx[1:]):
            if len(a) == 1:
                for j in range(len(b)):
                    self._face((a[0], b[(j + 1) % len(b)], b[j]), mat)
            elif len(b) == 1:
                for j in range(len(a)):
                    self._face((a[j], a[(j + 1) % len(a)], b[0]), mat)
            else:
                n = len(a)
                for j in range(n):
                    self._face((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]), mat)
        for end in (idx[0], idx[-1]):
            if len(end) > 2:
                self._face(end, mat)

    def slab(self, grid, thickness, mat):
        """Closed plate from a rows x cols grid of top-surface points, extruded down."""
        rows, cols = len(grid), len(grid[0])
        start = len(self.verts)
        self.verts.extend(p for row in grid for p in row)
        self.verts.extend(p - Y * thickness for row in grid for p in row)

        def top(r, c):
            return start + r * cols + c

        def bottom(r, c):
            return top(r, c) + rows * cols

        for r in range(rows - 1):
            for c in range(cols - 1):
                self._face((top(r, c), top(r, c + 1), top(r + 1, c + 1), top(r + 1, c)), mat)
                self._face((bottom(r, c), bottom(r + 1, c), bottom(r + 1, c + 1), bottom(r, c + 1)), mat)
        border = (
            [(0, c) for c in range(cols)]
            + [(r, cols - 1) for r in range(1, rows)]
            + [(rows - 1, c) for c in range(cols - 2, -1, -1)]
            + [(r, 0) for r in range(rows - 2, 0, -1)]
        )
        for (r0, c0), (r1, c1) in zip(border, border[1:] + border[:1]):
            self._face((top(r0, c0), bottom(r0, c0), bottom(r1, c1), top(r1, c1)), mat)


# ---------------------------------------------------------------------------
# Body parts: a ~9-year-old, about 1.40 m tall with a big head (~4.7 heads).

TORSO = Profile(
    [
        (0.585, 0.0, 0.005, 0.140, 0.108, 2.4),
        (0.640, 0.0, 0.010, 0.140, 0.110, 2.4),
        (0.720, 0.0, 0.014, 0.138, 0.112, 2.4),
        (0.820, 0.0, 0.012, 0.140, 0.108, 2.5),
        (0.910, 0.0, 0.006, 0.142, 0.100, 2.7),
        (0.975, 0.0, 0.000, 0.134, 0.090, 3.0),
        (1.025, 0.0, -0.004, 0.098, 0.074, 2.6),
        (1.055, 0.0, -0.006, 0.062, 0.058, 2.2),
    ]
)

HEAD = Profile(
    [
        (0.000, 0.0, 0.030, 0.030, 0.022, 2.0),
        (0.016, 0.0, 0.024, 0.066, 0.058, 2.0),
        (0.045, 0.0, 0.014, 0.092, 0.088, 2.2),
        (0.085, 0.0, 0.006, 0.106, 0.104, 2.3),
        (0.130, 0.0, 0.000, 0.112, 0.116, 2.3),
        (0.180, 0.0, -0.006, 0.114, 0.124, 2.3),
        (0.225, 0.0, -0.012, 0.106, 0.118, 2.3),
        (0.262, 0.0, -0.016, 0.086, 0.098, 2.3),
        (0.287, 0.0, -0.018, 0.054, 0.064, 2.1),
        (0.298, 0.0, -0.018, 0.024, 0.030, 2.0),
    ]
)
HEAD_TOP = Vector((0.0, 0.301, -0.018))

BACKPACK_Z = -0.168


def _front(theta):
    return max(0.0, math.sin(theta))


def _back(theta):
    return max(0.0, -math.sin(theta))


def hair_offset(theta, y):
    quiff = 0.018 * math.exp(-(((y - 0.262) / 0.035) ** 2)) * _front(theta) ** 2 * (1.0 + 0.4 * math.cos(theta))
    return 0.013 + quiff + 0.004 * _back(theta)


def hairline(theta):
    jag = 0.007 * math.sin(7.0 * theta) * (_front(theta) + 1.4 * _back(theta))
    return 0.165 + 0.060 * _front(theta) ** 1.3 - 0.065 * _back(theta) + jag


def cap_edge(theta):
    return 0.198 + 0.024 * _front(theta) - 0.012 * _back(theta)


def cap_offset(theta, y):
    dome = 0.008 * math.exp(-(((y - 0.26) / 0.05) ** 2))
    return hair_offset(theta, y) + 0.011 + dome + 0.004 * _front(theta)


def shell_point(theta, y, off):
    return HEAD.point(theta, y) + HEAD.normal(theta, y) * off


def head_shell(n, rows, bottom, offset, inner_offset):
    """Shell hugging the skull from a per-angle bottom edge to the crown."""
    thetas = [2.0 * math.pi * j / n for j in range(n)]
    top_y = HEAD.rows[-1][0]
    loops = [[shell_point(t, bottom(t), inner_offset(t)) for t in thetas]]
    for k in range(rows + 1):
        v = k / rows
        loop = []
        for t in thetas:
            y = bottom(t) + (top_y - bottom(t)) * v**0.85
            loop.append(shell_point(t, y, offset(t, y)))
        loops.append(loop)
    loops.append([HEAD_TOP + Y * offset(math.pi / 2.0, HEAD_TOP.y)])
    return loops


def build_torso():
    g = Geo()
    g.loft(TORSO.rings(16), "jacket")
    g.loft(TORSO.band(0.582, 0.622, 16, 0.006), "jacket_trim")
    g.loft(
        [hring(1.020, 0.0, -0.006, 0.072, 0.066, 16, 2.2), hring(1.085, 0.0, -0.008, 0.058, 0.054, 16, 2.0)],
        "jacket_trim",
    )
    zip_ys = [0.59 + (1.05 - 0.59) * i / 10 for i in range(11)]
    front = math.pi / 2.0
    g.loft(
        strip(
            [TORSO.point(front, y, 0.002) for y in zip_ys],
            [TORSO.normal(front, y) for y in zip_ys],
            0.013,
            0.006,
        ),
        "zipper",
    )
    # Seat of the pants, filling the crotch below the jacket hem.
    g.loft(
        Profile([(0.53, 0.0, 0.0, 0.112, 0.078, 2.4), (0.60, 0.0, 0.004, 0.124, 0.088, 2.4), (0.68, 0.0, 0.008, 0.122, 0.090, 2.4)]).rings(16),
        "pants",
    )
    g.loft(
        Profile([(1.00, 0.0, -0.010, 0.042, 0.042, 2.0), (1.07, 0.0, -0.010, 0.040, 0.040, 2.0), (1.13, 0.0, -0.008, 0.040, 0.040, 2.0)]).rings(10),
        "skin",
    )
    # Backpack straps: over the shoulder, down the chest, under the arm into the pack.
    path = [(-62, 0.93), (-58, 0.995), (-40, 1.02), (-12, 1.035), (18, 1.03), (48, 1.008), (62, 0.965), (64, 0.89), (64, 0.79), (60, 0.70), (35, 0.675), (0, 0.665), (-35, 0.67), (-55, 0.68)]
    for side in (1.0, -1.0):
        thetas = [math.radians(a) if side > 0 else math.pi - math.radians(a) for a, _ in path]
        ys = [y for _, y in path]
        g.loft(
            strip(
                [TORSO.point(t, y, 0.003) for t, y in zip(thetas, ys)],
                [TORSO.normal(t, y) for t, y in zip(thetas, ys)],
                0.034,
                0.011,
            ),
            "strap",
        )
    sternum = [math.radians(a) for a in range(62, 120, 8)]
    g.loft(strip([TORSO.point(t, 0.89, 0.015) for t in sternum], [TORSO.normal(t, 0.89) for t in sternum], 0.018, 0.007), "strap")
    z = BACKPACK_Z
    handle = [Vector((-0.04, 1.04, z)), Vector((-0.027, 1.07, z)), Vector((0.0, 1.08, z)), Vector((0.027, 1.07, z)), Vector((0.04, 1.04, z))]
    g.loft(tube(handle, [0.008] * len(handle), 6), "strap")
    return g


def build_backpack():
    """Oversized for a kid: shoulder blades to below the waist."""
    g = Geo()
    z = BACKPACK_Z
    g.loft(
        Profile(
            [
                (0.620, 0.0, z, 0.112, 0.048, 4.0),
                (0.635, 0.0, z, 0.128, 0.060, 4.0),
                (0.680, 0.0, z, 0.136, 0.066, 4.0),
                (0.930, 0.0, z, 0.136, 0.066, 4.0),
                (0.995, 0.0, z, 0.124, 0.062, 4.0),
                (1.035, 0.0, z + 0.004, 0.096, 0.054, 3.5),
                (1.055, 0.0, z + 0.006, 0.055, 0.038, 3.0),
            ]
        ).rings(16),
        "backpack",
    )
    pz = z - 0.080
    g.loft(
        Profile(
            [
                (0.655, 0.0, pz + 0.004, 0.090, 0.016, 4.0),
                (0.675, 0.0, pz, 0.104, 0.025, 4.0),
                (0.800, 0.0, pz, 0.104, 0.025, 4.0),
                (0.820, 0.0, pz + 0.004, 0.090, 0.016, 4.0),
            ],
            sub=1,
        ).rings(16),
        "backpack",
    )
    return g


# Limb segments overlap with domed ends around each joint so bending never opens a gap.
THIGH = Profile(
    [
        (-0.312, 0.0, 0.000, 0.036, 0.040, 2.0),
        (-0.280, 0.0, 0.002, 0.054, 0.058, 2.0),
        (-0.230, 0.0, 0.002, 0.058, 0.062, 2.0),
        (-0.120, 0.0, 0.000, 0.068, 0.074, 2.0),
        (0.000, 0.0, 0.000, 0.066, 0.076, 2.0),
        (0.060, 0.0, 0.000, 0.054, 0.064, 2.0),
    ]
)
SHIN = Profile(
    [
        (-0.250, 0.0, 0.004, 0.054, 0.060, 2.0),
        (-0.235, 0.0, 0.004, 0.054, 0.060, 2.0),
        (-0.190, 0.0, 0.000, 0.047, 0.053, 2.0),
        (-0.100, 0.0, -0.004, 0.051, 0.058, 2.0),
        (0.000, 0.0, 0.002, 0.053, 0.057, 2.0),
        (0.025, 0.0, 0.002, 0.042, 0.046, 2.0),
    ]
)


def build_thigh():
    g = Geo()
    g.loft([[Vector((0.0, -0.322, 0.0))]] + THIGH.rings(14), "pants")
    return g


def build_shin():
    g = Geo()
    g.loft(SHIN.rings(14) + [[Vector((0.0, 0.038, 0.002))]], "pants")
    return g


# (z, half width, bottom, top) in ankle space above GROUND. Chunky kid sneakers.
SHOE_UPPER = [
    (-0.070, 0.020, 0.025, 0.077),
    (-0.064, 0.036, 0.023, 0.090),
    (-0.047, 0.043, 0.023, 0.099),
    (-0.016, 0.047, 0.023, 0.101),
    (0.023, 0.050, 0.023, 0.088),
    (0.066, 0.050, 0.023, 0.068),
    (0.109, 0.047, 0.023, 0.052),
    (0.140, 0.038, 0.023, 0.043),
    (0.156, 0.023, 0.025, 0.036),
    (0.162, 0.007, 0.027, 0.031),
]
SHOE_SOLE = [
    (-0.076, 0.027, 0.004, 0.028),
    (-0.070, 0.043, 0.000, 0.030),
    (-0.047, 0.050, 0.000, 0.030),
    (0.023, 0.054, 0.000, 0.028),
    (0.094, 0.054, 0.002, 0.030),
    (0.133, 0.047, 0.007, 0.035),
    (0.156, 0.032, 0.014, 0.040),
    (0.167, 0.014, 0.021, 0.042),
]


def _shoe_loops(sections, n, p, p_low):
    return [
        ring(Vector((0.0, GROUND + (lo + hi) * 0.5, z)), X, Y, hw, (hi - lo) * 0.5, n, p, p_low)
        for z, hw, lo, hi in sections
    ]


def _upper_top(z):
    for a, b in zip(SHOE_UPPER, SHOE_UPPER[1:]):
        if z <= b[0]:
            f = (z - a[0]) / (b[0] - a[0])
            return a[3] + (b[3] - a[3]) * f
    return SHOE_UPPER[-1][3]


def build_shoe_upper():
    g = Geo()
    g.loft(_shoe_loops(SHOE_UPPER, 16, 2.4, 8.0), "shoe_upper")
    return g


def build_shoe_sole():
    """Sole, toe bumper, and two velcro straps across the instep."""
    g = Geo()
    g.loft(_shoe_loops(SHOE_SOLE, 16, 6.0, 8.0), "shoe_white")
    for z in (0.012, 0.050):
        slope = (_upper_top(z + 0.01) - _upper_top(z - 0.01)) / 0.02
        rot = Matrix.Rotation(math.atan(-slope), 3, "X")
        center = Vector((0.0, GROUND + _upper_top(z) - 0.002, z))
        g.loft(ellipsoid(center, Vector((0.050, 0.008, 0.015)), 10, 4, rot), "shoe_white")
    return g


UPPER_ARM = Profile(
    [
        (-0.215, 0.0, 0.000, 0.026, 0.028, 2.0),
        (-0.190, 0.0, 0.000, 0.038, 0.040, 2.0),
        (-0.160, 0.0, 0.000, 0.040, 0.042, 2.0),
        (-0.060, 0.0, 0.000, 0.044, 0.046, 2.0),
        (0.000, 0.0, 0.000, 0.046, 0.047, 2.0),
        (0.020, 0.0, 0.000, 0.040, 0.041, 2.0),
        (0.033, 0.0, 0.000, 0.024, 0.025, 2.0),
    ]
)


def build_upper_arm():
    g = Geo()
    g.loft([[Vector((0.0, -0.228, 0.0))]] + UPPER_ARM.rings(14) + [[Vector((0.0, 0.040, 0.0))]], "jacket")
    return g


def build_forearm(side):
    """Elbow-space forearm and hand; side = +1 for the left arm (+x). The forearm angles
    out so the wrist clears the hips, and the hand curls toward the body."""
    g = Geo()
    out = side
    sleeve = Profile(
        [
            (-0.165, out * 0.026, 0.006, 0.034, 0.036, 2.0),
            (-0.150, out * 0.024, 0.006, 0.034, 0.036, 2.0),
            (-0.080, out * 0.012, 0.003, 0.036, 0.038, 2.0),
            (0.000, 0.0, 0.000, 0.038, 0.040, 2.0),
            (0.020, 0.0, 0.000, 0.030, 0.032, 2.0),
        ]
    )
    g.loft(sleeve.rings(14) + [[Vector((0.0, 0.030, 0.0))]], "jacket")
    g.loft(sleeve.band(-0.172, -0.136, 14, 0.005), "jacket_trim")
    inward = -side
    wrist = side * 0.027
    hand = Profile(
        [
            (-0.262, wrist + inward * 0.002, 0.012, 0.007, 0.015, 2.0),
            (-0.248, wrist + inward * 0.004, 0.012, 0.016, 0.030, 2.0),
            (-0.218, wrist + inward * 0.005, 0.011, 0.021, 0.037, 2.0),
            (-0.185, wrist + inward * 0.005, 0.009, 0.023, 0.036, 2.0),
            (-0.160, wrist, 0.006, 0.022, 0.028, 2.0),
        ]
    )
    g.loft(hand.rings(10), "skin")
    thumb = [
        Vector((wrist + inward * 0.012, -0.180, 0.030)),
        Vector((wrist + inward * 0.016, -0.200, 0.043)),
        Vector((wrist + inward * 0.017, -0.217, 0.049)),
        Vector((wrist + inward * 0.017, -0.225, 0.050)),
    ]
    g.loft(tube(thumb, [0.011, 0.010, 0.008, 0.0], 8), "skin")
    return g


def build_face():
    """Round cheeks, low-set big eyes with highlights, button nose, small smile."""
    g = Geo()
    g.loft(HEAD.rings(20) + [[HEAD_TOP]], "skin")
    for side in (1.0, -1.0):
        ear_rot = Matrix.Rotation(side * 0.25, 3, "Y")
        g.loft(ellipsoid(Vector((side * 0.110, 0.122, -0.012)), Vector((0.018, 0.032, 0.024)), 8, 4, ear_rot), "skin")
        g.loft(ellipsoid(Vector((side * 0.045, 0.125, 0.107)), Vector((0.015, 0.020, 0.008)), 10, 5), "eye")
        g.loft(ellipsoid(Vector((side * 0.045 + 0.005, 0.132, 0.114)), Vector((0.0045, 0.0045, 0.003)), 6, 3), "eye_shine")
        brow_rot = Matrix.Rotation(-side * 0.08, 3, "Z")
        g.loft(ellipsoid(Vector((side * 0.046, 0.160, 0.110)), Vector((0.019, 0.0045, 0.007)), 8, 3, brow_rot), "brow")
        blush_rot = Matrix.Rotation(side * 0.75, 3, "Y")
        g.loft(ellipsoid(Vector((side * 0.070, 0.078, 0.083)), Vector((0.018, 0.011, 0.005)), 8, 3, blush_rot), "blush")
    smile = []
    for i in range(7):
        x = -0.019 + 0.038 * i / 6
        y = 0.054 + 16.0 * x * x
        _, _, cz, hw, hd, p = HEAD.at(y)
        z = cz + hd * (1.0 - (abs(x) / hw) ** p) ** (1.0 / p)
        smile.append(Vector((x, y, z + 0.001)))
    g.loft(tube(smile, [0.0, 0.0028, 0.0034, 0.0036, 0.0034, 0.0028, 0.0], 6), "lip")
    g.loft(ellipsoid(Vector((0.0, 0.092, 0.110)), Vector((0.012, 0.012, 0.010)), 8, 4), "skin")
    return g


def build_hair():
    g = Geo()
    g.loft(head_shell(28, 6, hairline, hair_offset, lambda t: 0.001), "hair")
    return g


def build_cap():
    g = Geo()
    g.loft(head_shell(24, 5, cap_edge, cap_offset, lambda t: hair_offset(t, cap_edge(t)) - 0.003), "cap")
    rows, cols = 5, 11
    grid = []
    for r in range(rows):
        t = r / (rows - 1)
        row = []
        for c in range(cols):
            s = -1.0 + 2.0 * c / (cols - 1)
            theta = math.pi / 2.0 + s * 1.0
            y = cap_edge(theta) + 0.004
            inner = shell_point(theta, y, cap_offset(theta, y))
            reach = 0.105 * math.sqrt(max(0.0, 1.0 - s * s))
            direction = Vector((0.25 * s, 0.0, 1.0)).normalized()
            row.append(inner + direction * (reach * t) - Y * ((0.012 + 0.018 * s * s) * t))
        grid.append(row)
    g.slab(grid, 0.010, "cap_brim")
    top = HEAD_TOP + Y * (cap_offset(math.pi / 2.0, HEAD_TOP.y) - 0.001)
    g.loft(ellipsoid(top, Vector((0.011, 0.005, 0.011)), 8, 3), "cap")
    return g


# ---------------------------------------------------------------------------
# Blender scene assembly


def gd_to_bl(v):
    return Vector((v.x, -v.z, v.y))


def _srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name):
    mat_name = "Mats_" + name
    mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
    color, roughness, metallic = PALETTE[name]
    linear = [_srgb_to_linear(c) for c in color] + [1.0]
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = linear
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = linear
    mat.roughness = roughness
    mat.metallic = metallic
    return mat


def make_mesh(mesh_name, geo, sharp_angle=35.0, scale=1.0):
    old = bpy.data.meshes.get(mesh_name)
    if old:
        bpy.data.meshes.remove(old)
    me = bpy.data.meshes.new(mesh_name)
    me.from_pydata([gd_to_bl(v * scale) for v in geo.verts], [], geo.faces)
    names = list(dict.fromkeys(geo.face_mats))
    for name in names:
        me.materials.append(material(name))
    for poly, name in zip(me.polygons, geo.face_mats):
        poly.material_index = names.index(name)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(sharp_angle))
    return me


def add_object(coll, name, data, parent=None, location=Vector()):
    obj = bpy.data.objects.new(name, data)
    coll.objects.link(obj)
    if data is None:
        obj.empty_display_size = 0.05
    obj.parent = parent
    obj.location = gd_to_bl(location)
    return obj


def build():
    coll = bpy.data.collections.get(COLLECTION)
    if coll is None:
        coll = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(coll)
    for obj in list(coll.objects):
        bpy.data.objects.remove(obj)

    root = add_object(coll, "Visual", None)
    add_object(coll, "Torso", make_mesh("torso", build_torso()), root)
    add_object(coll, "Backpack", make_mesh("backpack", build_backpack()), root)

    thigh = make_mesh("thigh", build_thigh())
    shin = make_mesh("shin", build_shin())
    shoe_upper = make_mesh("shoe_upper", build_shoe_upper())
    shoe_sole = make_mesh("shoe_sole", build_shoe_sole())
    upper_arm = make_mesh("upper_arm", build_upper_arm())
    for prefix, side in (("Left", 1.0), ("Right", -1.0)):
        hip = add_object(coll, prefix + "LegPivot", None, root, Vector((side * LEG_PIVOT.x, LEG_PIVOT.y, 0.0)))
        add_object(coll, prefix + "Thigh", thigh, hip)
        knee = add_object(coll, prefix + "Knee", None, hip, KNEE)
        add_object(coll, prefix + "Shin", shin, knee)
        shoe = add_object(coll, prefix + "Shoe", None, knee, ANKLE)
        add_object(coll, prefix + "ShoeSole", shoe_sole, shoe)
        add_object(coll, prefix + "ShoeUpper", shoe_upper, shoe)

        shoulder = add_object(coll, prefix + "ArmPivot", None, root, Vector((side * ARM_PIVOT.x, ARM_PIVOT.y, 0.0)))
        add_object(coll, prefix + "UpperArm", upper_arm, shoulder)
        elbow = add_object(coll, prefix + "Elbow", None, shoulder, ELBOW)
        add_object(coll, prefix + "Forearm", make_mesh("forearm_" + prefix.lower(), build_forearm(side)), elbow)

    head = add_object(coll, "Head", None, root, HEAD_PIVOT)
    add_object(coll, "Face", make_mesh("face", build_face(), scale=HEAD_SCALE), head)
    add_object(coll, "Hair", make_mesh("hair", build_hair(), 30.0, HEAD_SCALE), head)
    hat = add_object(coll, "Hat", None, head)
    add_object(coll, "Cap", make_mesh("cap", build_cap(), 30.0, HEAD_SCALE), hat)
    for name in ("leg", "arm_left", "arm_right"):  # meshes from the unjointed model
        stale = bpy.data.meshes.get(name)
        if stale and stale.users == 0:
            bpy.data.meshes.remove(stale)
    return coll


build()
