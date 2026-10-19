"""Exports the "Mats" collection to glTF: blender -b mats.blend --python export_mats.py -- <out.glb>"""

import sys

import bpy

bpy.ops.export_scene.gltf(
    filepath=sys.argv[sys.argv.index("--") + 1],
    collection="Mats",
    export_format="GLB",
    export_yup=True,
)
