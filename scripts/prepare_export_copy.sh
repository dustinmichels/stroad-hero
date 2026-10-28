#!/usr/bin/env bash
# Copy the project to $1 and enable the mesh_baker export plugin in the copy,
# so exports never touch the open editor's .godot/ or project.godot.
set -eu
work="$1"
rsync -a --delete --exclude .git --exclude build --exclude /site ./ "$work/"
if ! grep -q "addons/mesh_baker/plugin.cfg" "$work/project.godot"; then
    printf '\n[editor_plugins]\n\nenabled=PackedStringArray("res://addons/mesh_baker/plugin.cfg")\n' >> "$work/project.godot"
fi
