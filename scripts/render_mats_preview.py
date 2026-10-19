#!/usr/bin/env python3
"""Render multi-view character previews of Mats from player/mats.blend.

Renders front, side, back, walk, and kneel views to /tmp (or a specified directory)
using Blender EEVEE, and stitches them into a composite contact sheet for reviews.
"""

import argparse
import os
import shutil
import subprocess
import sys

DEFAULT_BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
DEFAULT_BLEND = "player/mats.blend"
DEFAULT_OUT_DIR = "/tmp"

try:
    import bpy
    IN_BLENDER = True
except ImportError:
    IN_BLENDER = False


def _parse_args(args=None):
    parser = argparse.ArgumentParser(
        description="Render Mats character preview views (front, side, back, walk, kneel)."
    )
    parser.add_argument(
        "--blend",
        default=DEFAULT_BLEND,
        help="Path to mats.blend file (default: %(default)s)",
    )
    parser.add_argument(
        "--out-dir",
        default=DEFAULT_OUT_DIR,
        help="Output directory for rendered PNGs (default: %(default)s)",
    )
    parser.add_argument(
        "--views",
        default="front,side,back,walk,kneel",
        help="Comma-separated views to render (default: %(default)s)",
    )
    parser.add_argument(
        "--headwear",
        choices=["cap", "beanie", "hair"],
        default="cap",
        help="Headwear variant to preview (default: %(default)s)",
    )
    parser.add_argument(
        "--width",
        type=int,
        default=720,
        help="Width of each rendered view (default: %(default)s)",
    )
    parser.add_argument(
        "--height",
        type=int,
        default=960,
        help="Height of each rendered view (default: %(default)s)",
    )
    parser.add_argument(
        "--no-sheet",
        action="store_true",
        help="Skip generating the stitched composite contact sheet",
    )
    return parser.parse_args(args)


# ---------------------------------------------------------------------------
# Blender-internal rendering logic
# ---------------------------------------------------------------------------

def _render_in_blender(opts):
    import math
    from mathutils import Euler, Vector

    def get_obj(name):
        return bpy.data.objects.get(name)

    cam = get_obj("PreviewCamera")
    if not cam:
        cam_data = bpy.data.cameras.new("PreviewCamera")
        cam = bpy.data.objects.new("PreviewCamera", cam_data)
        bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.data.lens = 50.0

    # Expand ground plane so horizon remains clean across camera angles
    pg = get_obj("PreviewGround")
    if pg:
        pg.scale = Vector((20.0, 20.0, 1.0))
        pg.hide_render = False

    # Key light
    sun = get_obj("PreviewSun")
    if not sun:
        sun_data = bpy.data.lights.new(name="PreviewSun", type="SUN")
        sun = bpy.data.objects.new("PreviewSun", sun_data)
        bpy.context.scene.collection.objects.link(sun)
    sun.data.energy = 3.2

    # Fill light
    fill = get_obj("PreviewFill")
    if not fill:
        fill_data = bpy.data.lights.new(name="PreviewFill", type="SUN")
        fill = bpy.data.objects.new("PreviewFill", fill_data)
        bpy.context.scene.collection.objects.link(fill)
    fill.data.energy = 1.0

    # Configure headwear
    cap = get_obj("Cap")
    beanie = get_obj("Beanie")
    if cap:
        cap.hide_render = (opts.headwear != "cap")
    if beanie:
        beanie.hide_render = (opts.headwear != "beanie")

    # Joint references
    visual = get_obj("Visual")
    l_hip = get_obj("LeftLegPivot")
    r_hip = get_obj("RightLegPivot")
    l_knee = get_obj("LeftKnee")
    r_knee = get_obj("RightKnee")
    l_ankle = get_obj("LeftShoe")
    r_ankle = get_obj("RightShoe")
    l_arm = get_obj("LeftArmPivot")
    r_arm = get_obj("RightArmPivot")
    l_elbow = get_obj("LeftElbow")
    r_elbow = get_obj("RightElbow")
    head = get_obj("Head")

    def reset_pose():
        if visual:
            visual.location = Vector((0.0, 0.0, 0.0))
            visual.rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
        for joint in [
            l_hip, r_hip, l_knee, r_knee, l_ankle, r_ankle,
            l_arm, r_arm, l_elbow, r_elbow, head
        ]:
            if joint:
                joint.rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
        bpy.context.view_layer.update()

    def set_camera_and_lights(dist, angle_deg, target_z=0.70, elevation_deg=3.0):
        rad = math.radians(angle_deg)
        elev_rad = math.radians(elevation_deg)

        d_xy = dist * math.cos(elev_rad)
        cam_x = d_xy * math.sin(rad)
        cam_y = -d_xy * math.cos(rad)
        cam_z = target_z + dist * math.sin(elev_rad)

        cam.location = Vector((cam_x, cam_y, cam_z))
        direction = Vector((0.0, 0.0, target_z)) - cam.location
        rot_quat = direction.to_track_quat("-Z", "Y")
        cam.rotation_euler = rot_quat.to_euler()

        # Key light: 35 deg offset from camera azimuth, 48 deg elevation
        key_yaw = rad + math.radians(35)
        sun.rotation_euler = Euler((math.radians(48), 0.0, key_yaw + math.pi), "ZXY")

        # Fill light: -40 deg offset from camera azimuth, 30 deg elevation
        fill_yaw = rad - math.radians(40)
        fill.rotation_euler = Euler((math.radians(30), 0.0, fill_yaw + math.pi), "ZXY")

    scene = bpy.context.scene
    scene.render.resolution_x = opts.width
    scene.render.resolution_y = opts.height

    os.makedirs(opts.out_dir, exist_ok=True)
    views = [v.strip().lower() for v in opts.views.split(",") if v.strip()]

    for view in views:
        reset_pose()
        if view == "front":
            set_camera_and_lights(dist=2.8, angle_deg=0.0, target_z=0.70, elevation_deg=3.0)
        elif view == "side":
            set_camera_and_lights(dist=2.8, angle_deg=-90.0, target_z=0.70, elevation_deg=3.0)
        elif view == "back":
            set_camera_and_lights(dist=2.8, angle_deg=180.0, target_z=0.70, elevation_deg=3.0)
        elif view == "walk":
            # Peak walk stride
            leg_swing = 0.6
            arm_swing = 0.5
            if l_hip:
                l_hip.rotation_euler = Euler((-leg_swing, 0.0, 0.0), "XYZ")
            if r_hip:
                r_hip.rotation_euler = Euler((leg_swing * 0.8, 0.0, 0.0), "XYZ")
            if l_knee:
                l_knee.rotation_euler = Euler((0.15, 0.0, 0.0), "XYZ")
            if r_knee:
                r_knee.rotation_euler = Euler((0.85, 0.0, 0.0), "XYZ")
            if l_ankle:
                l_ankle.rotation_euler = Euler((0.35, 0.0, 0.0), "XYZ")
            if r_ankle:
                r_ankle.rotation_euler = Euler((-0.40, 0.0, 0.0), "XYZ")
            if l_arm:
                l_arm.rotation_euler = Euler((arm_swing, 0.0, 0.0), "XYZ")
            if r_arm:
                r_arm.rotation_euler = Euler((-arm_swing, 0.0, 0.0), "XYZ")
            if l_elbow:
                l_elbow.rotation_euler = Euler((-0.3, 0.0, 0.0), "XYZ")
            if r_elbow:
                r_elbow.rotation_euler = Euler((-0.7, 0.0, 0.0), "XYZ")
            if visual:
                visual.rotation_euler = Euler((-0.08, 0.0, 0.0), "XYZ")
                visual.location = Vector((0.0, 0.0, -0.04))
            bpy.context.view_layer.update()
            set_camera_and_lights(dist=2.8, angle_deg=-35.0, target_z=0.70, elevation_deg=3.0)
        elif view == "kneel":
            # Kneeling pose as in shopping cart
            if l_knee:
                l_knee.rotation_euler = Euler((math.pi / 2.0, 0.0, 0.0), "XYZ")
            if r_knee:
                r_knee.rotation_euler = Euler((math.pi / 2.0, 0.0, 0.0), "XYZ")
            if l_ankle:
                l_ankle.rotation_euler = Euler((math.pi / 2.0, 0.0, 0.0), "XYZ")
            if r_ankle:
                r_ankle.rotation_euler = Euler((math.pi / 2.0, 0.0, 0.0), "XYZ")
            if l_arm:
                l_arm.rotation_euler = Euler((-0.60, 0.0, 0.0), "XYZ")
            if r_arm:
                r_arm.rotation_euler = Euler((-0.60, 0.0, 0.0), "XYZ")
            if l_elbow:
                l_elbow.rotation_euler = Euler((-0.20, 0.0, 0.0), "XYZ")
            if r_elbow:
                r_elbow.rotation_euler = Euler((-0.20, 0.0, 0.0), "XYZ")
            if visual:
                visual.location = Vector((0.0, 0.0, -0.27))
            bpy.context.view_layer.update()
            set_camera_and_lights(dist=2.6, angle_deg=-35.0, target_z=0.55, elevation_deg=3.0)
        else:
            print(f"Warning: Unknown view '{view}', skipping")
            continue

        out_path = os.path.join(opts.out_dir, f"mats_{view}.png")
        scene.render.filepath = out_path
        bpy.ops.render.render(write_still=True)
        print(f"Rendered: {out_path}")


# ---------------------------------------------------------------------------
# Host-side entry point
# ---------------------------------------------------------------------------

def _build_composite_sheet(out_dir, views_list, sheet_path):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("Note: PIL/Pillow not available on host; skipping composite sheet.")
        return

    images = []
    labels = []
    for view in views_list:
        p = os.path.join(out_dir, f"mats_{view}.png")
        if os.path.isfile(p):
            images.append(Image.open(p))
            labels.append(view.upper())

    if not images:
        return

    w, h = images[0].size
    label_bar = 50
    sheet_w = w * len(images)
    sheet_h = h + label_bar
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (240, 243, 246, 255))
    draw = ImageDraw.Draw(sheet)

    for idx, (img, label) in enumerate(zip(images, labels)):
        x = idx * w
        sheet.paste(img, (x, 0))
        bbox = draw.textbbox((0, 0), label)
        tw = bbox[2] - bbox[0]
        draw.text((x + (w - tw) // 2, h + 15), label, fill=(40, 50, 60, 255))

    sheet.save(sheet_path)
    print(f"Composite sheet saved: {sheet_path}")


def main():
    if IN_BLENDER:
        # Running inside Blender: parse arguments passed after '--'
        argv = sys.argv
        if "--" in argv:
            argv = argv[argv.index("--") + 1:]
        else:
            argv = []
        opts = _parse_args(argv)
        _render_in_blender(opts)
        return

    # Running outside Blender
    opts = _parse_args()

    blender_bin = os.environ.get("BLENDER_BIN") or shutil.which("blender") or DEFAULT_BLENDER
    if not os.path.isfile(blender_bin) and not shutil.which(blender_bin):
        print(f"Error: Blender executable not found at '{blender_bin}'.", file=sys.stderr)
        print("Please install Blender or set BLENDER_BIN.", file=sys.stderr)
        sys.exit(1)

    if not os.path.isfile(opts.blend):
        print(f"Error: Blend file not found at '{opts.blend}'.", file=sys.stderr)
        sys.exit(1)

    script_path = os.path.abspath(__file__)
    blend_path = os.path.abspath(opts.blend)

    cmd = [
        blender_bin,
        "-b",
        blend_path,
        "-P",
        script_path,
        "--",
    ] + sys.argv[1:]

    print(f"Launching Blender preview render ({opts.views})...")
    res = subprocess.run(cmd)
    if res.returncode != 0:
        print(f"Blender preview render failed with exit code {res.returncode}.", file=sys.stderr)
        sys.exit(res.returncode)

    if not opts.no_sheet:
        views_list = [v.strip().lower() for v in opts.views.split(",") if v.strip()]
        sheet_path = os.path.join(opts.out_dir, "mats_preview.png")
        _build_composite_sheet(opts.out_dir, views_list, sheet_path)

    print(f"Done! Mats preview renders ready in {opts.out_dir}")


if __name__ == "__main__":
    main()
