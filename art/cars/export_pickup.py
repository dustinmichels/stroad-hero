"""Exports the "Pickup" collection to glTF: blender -b pickup.blend --python export_pickup.py -- <out.glb>"""

import sys
import bpy

bpy.ops.export_scene.gltf(
    filepath=sys.argv[sys.argv.index("--") + 1],
    collection="Pickup",
    export_format="GLB",
    export_yup=True,
)
