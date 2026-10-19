"""Builds the stylized Pickup Truck model into cars/bodies/pickup.blend.

Run inside Blender or via CLI:
blender -b --python art/cars/build_pickup.py

Geometry is authored in Godot space:
  +X = Forward
  +Y = Up
  +Z = Left (driver side in US)
  -Z = Right (passenger side in US)
and converted to Blender coordinates on mesh creation.
"""

import math
import sys
import bpy
import bmesh
from mathutils import Vector, Matrix

COLLECTION_NAME = "Pickup"
OUT_BLEND_PATH = "cars/bodies/pickup.blend"

# Standard car dimensions
WHEEL_RADIUS = 0.35
WHEEL_WIDTH = 0.28
WHEELBASE_F = 1.30
WHEELBASE_R = -1.35
TRACK_Z = 0.98
WHEEL_Y = 0.35


def srgb_to_linear(c: float) -> float:
    return (c / 12.92) if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def col_srgb_to_linear(rgb: tuple) -> tuple:
    return (
        srgb_to_linear(rgb[0]),
        srgb_to_linear(rgb[1]),
        srgb_to_linear(rgb[2]),
        rgb[3] if len(rgb) > 3 else 1.0,
    )


# Palette in sRGB; converted to linear for Blender Principled BSDF
PALETTE_SRGB = {
    "paint": ((0.18, 0.38, 0.24, 1.0), 0.32, 0.15),      # Forest Green base (overridden at runtime in Godot)
    "glass": ((0.10, 0.14, 0.20, 1.0), 0.10, 0.40),      # Tinted dark glass
    "chrome": ((0.85, 0.86, 0.88, 1.0), 0.20, 0.85),     # Polished chrome bumper & grille
    "dark_trim": ((0.12, 0.13, 0.15, 1.0), 0.75, 0.05),  # Rugged plastic / steps / underbody
    "bed_liner": ((0.15, 0.16, 0.18, 1.0), 0.85, 0.0),   # Tough bed liner
    "headlight": ((1.00, 0.98, 0.85, 1.0), 0.20, 0.0),   # Headlight lens (emissive)
    "taillight": ((0.90, 0.10, 0.10, 1.0), 0.20, 0.0),   # Taillight lens (emissive)
    "tire": ((0.10, 0.10, 0.11, 1.0), 0.90, 0.0),        # Rubber
    "rim": ((0.75, 0.77, 0.80, 1.0), 0.25, 0.80),         # Alloy rim
}


def gd_to_bl(v: Vector) -> Vector:
    """Convert Godot vector (+X fwd, +Y up, +Z left) to Blender (+X fwd/right, +Y back, +Z up)."""
    return Vector((v.x, -v.z, v.y))


def get_or_create_material(name: str):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        bsdf = nodes.get("Principled BSDF")
        srgb_color, roughness, metallic = PALETTE_SRGB[name]
        linear_color = col_srgb_to_linear(srgb_color)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = linear_color
            bsdf.inputs["Roughness"].default_value = roughness
            bsdf.inputs["Metallic"].default_value = metallic
            if name == "headlight":
                bsdf.inputs["Emission Color"].default_value = linear_color
                bsdf.inputs["Emission Strength"].default_value = 2.0
            elif name == "taillight":
                bsdf.inputs["Emission Color"].default_value = linear_color
                bsdf.inputs["Emission Strength"].default_value = 1.5
    return mat


def create_box(bm: bmesh.types.BMesh, min_pt: Vector, max_pt: Vector):
    """Create a 3D axis-aligned box between min_pt and max_pt in Godot space."""
    verts = [
        bm.verts.new(gd_to_bl(Vector((min_pt.x, min_pt.y, min_pt.z)))),
        bm.verts.new(gd_to_bl(Vector((max_pt.x, min_pt.y, min_pt.z)))),
        bm.verts.new(gd_to_bl(Vector((max_pt.x, max_pt.y, min_pt.z)))),
        bm.verts.new(gd_to_bl(Vector((min_pt.x, max_pt.y, min_pt.z)))),
        bm.verts.new(gd_to_bl(Vector((min_pt.x, min_pt.y, max_pt.z)))),
        bm.verts.new(gd_to_bl(Vector((max_pt.x, min_pt.y, max_pt.z)))),
        bm.verts.new(gd_to_bl(Vector((max_pt.x, max_pt.y, max_pt.z)))),
        bm.verts.new(gd_to_bl(Vector((min_pt.x, max_pt.y, max_pt.z)))),
    ]
    faces = [
        [verts[0], verts[1], verts[2], verts[3]],  # -Z
        [verts[7], verts[6], verts[5], verts[4]],  # +Z
        [verts[4], verts[0], verts[3], verts[7]],  # -X
        [verts[1], verts[5], verts[6], verts[2]],  # +X
        [verts[4], verts[5], verts[1], verts[0]],  # -Y
        [verts[3], verts[2], verts[6], verts[7]],  # +Y
    ]
    created_faces = []
    for f in faces:
        try:
            created_faces.append(bm.faces.new(f))
        except ValueError:
            pass
    return created_faces


def build_body_mesh() -> bpy.types.Mesh:
    """Builds the main painted sheet metal for the pickup truck."""
    me = bpy.data.meshes.new("body")
    bm = bmesh.new()

    # 1. Lower chassis / rocker & floor base
    create_box(bm, Vector((-2.35, 0.44, -0.96)), Vector((2.10, 0.65, 0.96)))

    # 2. Front Hood & Fenders
    create_box(bm, Vector((0.85, 0.65, -0.98)), Vector((2.15, 1.05, 0.98)))
    # Hood scoop / center bulge for rugged truck look
    create_box(bm, Vector((0.95, 1.05, -0.55)), Vector((2.00, 1.09, 0.55)))
    # Wheel arch flare F-Left
    create_box(bm, Vector((0.90, 0.60, 0.96)), Vector((1.70, 0.92, 1.03)))
    # Wheel arch flare F-Right
    create_box(bm, Vector((0.90, 0.60, -1.03)), Vector((1.70, 0.92, -0.96)))

    # 3. Cab Outer Shell (roof, pillars, door sills)
    create_box(bm, Vector((-0.65, 0.65, -0.98)), Vector((0.85, 1.05, 0.98)))
    # Roof with subtle visor overhang
    create_box(bm, Vector((-0.66, 1.55, -0.91)), Vector((0.18, 1.62, 0.91)))
    # A-Pillars (slanted)
    p1 = Vector((0.82, 1.04, 0.88))
    p2 = Vector((0.15, 1.58, 0.88))
    create_box(bm, Vector((p2.x - 0.05, p1.y, p1.z - 0.04)), Vector((p1.x, p2.y, p1.z + 0.04)))
    create_box(bm, Vector((p2.x - 0.05, p1.y, -p1.z - 0.04)), Vector((p1.x, p2.y, -p1.z + 0.04)))
    # C-Pillars (rear cab wall outer pillars)
    create_box(bm, Vector((-0.66, 1.05, 0.82)), Vector((-0.55, 1.58, 0.91)))
    create_box(bm, Vector((-0.66, 1.05, -0.91)), Vector((-0.55, 1.58, -0.82)))
    # Rear cab wall below window
    create_box(bm, Vector((-0.66, 1.05, -0.82)), Vector((-0.61, 1.25, 0.82)))

    # 4. Truck Bed Outer Walls & Tailgate
    create_box(bm, Vector((-2.35, 0.65, 0.84)), Vector((-0.65, 1.18, 0.98)))
    create_box(bm, Vector((-2.35, 0.65, -0.98)), Vector((-0.65, 1.18, -0.84)))
    # Rear wheel flare Left
    create_box(bm, Vector((-1.75, 0.60, 0.96)), Vector((-0.95, 0.92, 1.03)))
    # Rear wheel flare Right
    create_box(bm, Vector((-1.75, 0.60, -1.03)), Vector((-0.95, 0.92, -0.96)))
    # Tailgate
    create_box(bm, Vector((-2.42, 0.65, -0.85)), Vector((-2.35, 1.18, 0.85)))

    # 5. Side Mirrors (painted outer housing)
    create_box(bm, Vector((0.45, 1.12, 1.00)), Vector((0.60, 1.24, 1.14)))
    create_box(bm, Vector((0.45, 1.12, -1.14)), Vector((0.60, 1.24, -1.00)))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()

    me.materials.append(get_or_create_material("paint"))
    return me


def build_windows_mesh() -> bpy.types.Mesh:
    """Builds the glass windows (windshield, rear cab window, side door windows)."""
    me = bpy.data.meshes.new("windows")
    bm = bmesh.new()

    # Windshield (raked glass)
    create_box(bm, Vector((0.16, 1.05, -0.84)), Vector((0.80, 1.55, 0.84)))
    # Side glass Left
    create_box(bm, Vector((-0.55, 1.08, 0.84)), Vector((0.15, 1.54, 0.86)))
    # Side glass Right
    create_box(bm, Vector((-0.55, 1.08, -0.86)), Vector((0.15, 1.54, -0.84)))
    # Rear cab glass
    create_box(bm, Vector((-0.64, 1.25, -0.76)), Vector((-0.62, 1.54, 0.76)))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()

    me.materials.append(get_or_create_material("glass"))
    return me


def build_trim_mesh() -> bpy.types.Mesh:
    """Builds bumpers, front grille, side steps, and trim details."""
    me = bpy.data.meshes.new("trim")
    bm = bmesh.new()

    # Front Bumper (heavy duty truck bumper)
    create_box(bm, Vector((2.15, 0.42, -1.02)), Vector((2.26, 0.72, 1.02)))
    # Front Bumper lower air dam / skid plate
    create_box(bm, Vector((2.12, 0.30, -0.70)), Vector((2.24, 0.42, 0.70)))

    # Front Grille (bold horizontal bars)
    create_box(bm, Vector((2.15, 0.75, -0.72)), Vector((2.20, 1.02, 0.72)))
    # Horizontal grille slats (chrome bars)
    create_box(bm, Vector((2.18, 0.80, -0.68)), Vector((2.22, 0.84, 0.68)))
    create_box(bm, Vector((2.18, 0.90, -0.68)), Vector((2.22, 0.94, 0.68)))

    # Rear Bumper (step bumper)
    create_box(bm, Vector((-2.48, 0.44, -1.00)), Vector((-2.36, 0.68, 1.00)))
    # Hitch receiver
    create_box(bm, Vector((-2.54, 0.46, -0.10)), Vector((-2.48, 0.54, 0.10)))

    # Side Steps (running boards)
    create_box(bm, Vector((-0.50, 0.35, 0.98)), Vector((0.70, 0.40, 1.10)))
    create_box(bm, Vector((-0.50, 0.35, -1.10)), Vector((0.70, 0.40, -0.98)))

    # Mirror glass
    create_box(bm, Vector((0.44, 1.14, 1.02)), Vector((0.46, 1.22, 1.12)))
    create_box(bm, Vector((0.44, 1.14, -1.12)), Vector((0.46, 1.22, -1.02)))

    # Tailgate handle
    create_box(bm, Vector((-2.44, 1.05, -0.15)), Vector((-2.42, 1.12, 0.15)))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()

    me.materials.append(get_or_create_material("chrome"))
    return me


def build_bed_liner_mesh() -> bpy.types.Mesh:
    """Builds the interior bed liner (floor and inside walls)."""
    me = bpy.data.meshes.new("bed_liner")
    bm = bmesh.new()

    # Bed floor
    create_box(bm, Vector((-2.34, 0.65, -0.84)), Vector((-0.66, 0.68, 0.84)))
    # Bed front bulkhead (behind cab)
    create_box(bm, Vector((-0.68, 0.68, -0.84)), Vector((-0.65, 1.17, 0.84)))
    # Bed inner side walls
    create_box(bm, Vector((-2.34, 0.68, 0.82)), Vector((-0.68, 1.17, 0.84)))
    create_box(bm, Vector((-2.34, 0.68, -0.84)), Vector((-0.68, 1.17, -0.82)))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()

    me.materials.append(get_or_create_material("bed_liner"))
    return me


def build_centered_light_mesh(name: str, mat_name: str, size: Vector) -> bpy.types.Mesh:
    """Builds a light marker box centered at local origin (0, 0, 0)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    half = size * 0.5
    create_box(bm, -half, half)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(get_or_create_material(mat_name))
    return me


def build_wheel_mesh(name: str) -> bpy.types.Mesh:
    """Builds a wheel centered at local origin (0, 0, 0).
    Local cylinder axis is Y in Godot/Blender convention for wheels so that
    BASE_WHEEL_BASIS * Basis(Vector3.UP, angle) rolls the wheel along X!
    """
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()

    tire_mat = get_or_create_material("tire")
    rim_mat = get_or_create_material("rim")
    me.materials.append(tire_mat)
    me.materials.append(rim_mat)

    segments = 24
    outer_radius = WHEEL_RADIUS
    inner_radius = outer_radius * 0.62
    hub_radius = outer_radius * 0.28
    half_width = WHEEL_WIDTH * 0.5

    ring_outer_pos = []
    ring_outer_neg = []
    ring_rim_pos = []
    ring_rim_neg = []
    ring_hub_pos = []
    ring_hub_neg = []

    for i in range(segments):
        angle = (2.0 * math.pi * i) / segments
        ca = math.cos(angle)
        sa = math.sin(angle)
        # Local coords: X fwd, Y lateral axle, Z radial up
        ring_outer_pos.append(bm.verts.new(gd_to_bl(Vector((ca * outer_radius, half_width, sa * outer_radius)))))
        ring_outer_neg.append(bm.verts.new(gd_to_bl(Vector((ca * outer_radius, -half_width, sa * outer_radius)))))
        ring_rim_pos.append(bm.verts.new(gd_to_bl(Vector((ca * inner_radius, half_width * 0.9, sa * inner_radius)))))
        ring_rim_neg.append(bm.verts.new(gd_to_bl(Vector((ca * inner_radius, -half_width * 0.9, sa * inner_radius)))))
        ring_hub_pos.append(bm.verts.new(gd_to_bl(Vector((ca * hub_radius, half_width * 0.95, sa * hub_radius)))))
        ring_hub_neg.append(bm.verts.new(gd_to_bl(Vector((ca * hub_radius, -half_width * 0.95, sa * hub_radius)))))

    # Tire tread
    for i in range(segments):
        ni = (i + 1) % segments
        f = bm.faces.new([ring_outer_neg[i], ring_outer_neg[ni], ring_outer_pos[ni], ring_outer_pos[i]])
        f.material_index = 0

    # Tire sidewalls
    for i in range(segments):
        ni = (i + 1) % segments
        f_out = bm.faces.new([ring_outer_pos[i], ring_outer_pos[ni], ring_rim_pos[ni], ring_rim_pos[i]])
        f_out.material_index = 0
        f_in = bm.faces.new([ring_rim_neg[i], ring_rim_neg[ni], ring_outer_neg[ni], ring_outer_neg[i]])
        f_in.material_index = 0

    # Rim faces on both sides (symmetric alloy wheel)
    for i in range(segments):
        ni = (i + 1) % segments
        f_rim_out = bm.faces.new([ring_rim_pos[i], ring_rim_pos[ni], ring_hub_pos[ni], ring_hub_pos[i]])
        f_rim_out.material_index = 1
        f_rim_in = bm.faces.new([ring_hub_neg[i], ring_hub_neg[ni], ring_rim_neg[ni], ring_rim_neg[i]])
        f_rim_in.material_index = 1

    # Center hub caps on both sides
    hub_center_pos = bm.verts.new(gd_to_bl(Vector((0.0, half_width * 1.02, 0.0))))
    hub_center_neg = bm.verts.new(gd_to_bl(Vector((0.0, -half_width * 1.02, 0.0))))
    for i in range(segments):
        ni = (i + 1) % segments
        f_hub_out = bm.faces.new([ring_hub_pos[i], ring_hub_pos[ni], hub_center_pos])
        f_hub_out.material_index = 1
        f_hub_in = bm.faces.new([hub_center_neg, ring_hub_neg[ni], ring_hub_neg[i]])
        f_hub_in.material_index = 1

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return me


def build_pickup():
    coll = bpy.data.collections.get(COLLECTION_NAME)
    if coll is None:
        coll = bpy.data.collections.new(COLLECTION_NAME)
        bpy.context.scene.collection.children.link(coll)
    else:
        for obj in list(coll.objects):
            coll.objects.unlink(obj)
            bpy.data.objects.remove(obj)

    body_mesh = build_body_mesh()
    windows_mesh = build_windows_mesh()
    trim_mesh = build_trim_mesh()
    bed_liner_mesh = build_bed_liner_mesh()

    # Headlight & Taillight meshes centered at origin
    hl_mesh = build_centered_light_mesh("headlight_mesh", "headlight", Vector((0.10, 0.20, 0.28)))
    tl_mesh = build_centered_light_mesh("taillight_mesh", "taillight", Vector((0.10, 0.30, 0.16)))

    # Reusable wheel mesh
    wheel_mesh = build_wheel_mesh("wheel_mesh")

    # Static body objects
    body_obj = bpy.data.objects.new("Body", body_mesh)
    windows_obj = bpy.data.objects.new("Windows", windows_mesh)
    trim_obj = bpy.data.objects.new("Trim", trim_mesh)
    bed_liner_obj = bpy.data.objects.new("BedLiner", bed_liner_mesh)

    for o in [body_obj, windows_obj, trim_obj, bed_liner_obj]:
        coll.objects.link(o)

    # Headlights placed at exact locator positions matching Godot
    hl_l_obj = bpy.data.objects.new("HeadlightL", hl_mesh)
    hl_l_obj.location = gd_to_bl(Vector((2.18, 0.88, 0.74)))
    coll.objects.link(hl_l_obj)

    hl_r_obj = bpy.data.objects.new("HeadlightR", hl_mesh)
    hl_r_obj.location = gd_to_bl(Vector((2.18, 0.88, -0.74)))
    coll.objects.link(hl_r_obj)

    # Taillights placed at exact locator positions matching Godot
    tl_l_obj = bpy.data.objects.new("TaillightL", tl_mesh)
    tl_l_obj.location = gd_to_bl(Vector((-2.44, 1.12, 0.93)))
    coll.objects.link(tl_l_obj)

    tl_r_obj = bpy.data.objects.new("TaillightR", tl_mesh)
    tl_r_obj.location = gd_to_bl(Vector((-2.44, 1.12, -0.93)))
    coll.objects.link(tl_r_obj)

    # Wheels at exact wheel positions
    wheel_positions = {
        "Wheel_FL": Vector((WHEELBASE_F, WHEEL_Y, TRACK_Z)),
        "Wheel_FR": Vector((WHEELBASE_F, WHEEL_Y, -TRACK_Z)),
        "Wheel_RL": Vector((WHEELBASE_R, WHEEL_Y, TRACK_Z)),
        "Wheel_RR": Vector((WHEELBASE_R, WHEEL_Y, -TRACK_Z)),
    }

    for name, pos in wheel_positions.items():
        w_obj = bpy.data.objects.new(name, wheel_mesh)
        w_obj.location = gd_to_bl(pos)
        coll.objects.link(w_obj)

    print("Successfully built Pickup truck collection in Blender!")


if __name__ == "__main__":
    build_pickup()
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND_PATH)
    print("Saved %s" % OUT_BLEND_PATH)
