# Agent Guidelines

Godot 4.7 project (GDScript). The user usually has the Godot editor open while you work, so these rules keep you from crashing it or having your changes silently overwritten.

## Running Godot

- Binary: `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH).
- Always pass `--headless`. Without it, startup errors open a native alert that crashes the process.
- Never start the GUI editor, and never run `--editor` or `--import`: a second editor writing `.godot/` alongside the open one can corrupt the cache.
- Check a script: `<godot> --headless --path . --check-only -s res://<file>.gd`
- Smoke-run the main scene: `<godot> --headless --path . --quit`

## Editing files

- Prefer editing `.gd` files. The editor hot-reloads scripts safely.
- Never invent `uid://` values. Reference resources by `res://` path; Godot assigns UIDs on its next save.
- Write temp/scratch files to `/tmp`, never inside the project. Godot scans and imports every new file under `res://`.
