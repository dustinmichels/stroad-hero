# Agent Guidelines

Godot 4.7 project (GDScript). The user usually has the Godot editor open while you work, so these rules keep you from crashing it or having your changes silently overwritten.

## Running Godot

- Binary: `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH).
- Prefer `--headless`
- Check a script: `<godot> --headless --path . -d --ignore-error-breaks --check-only -s res://<file>.gd`
- Smoke-run the main scene: `<godot> --headless --path . --quit`

## Editing files

- Prefer editing `.gd` files
- Never invent `uid://` values. Reference resources by `res://` path; Godot assigns UIDs on its next save.
- Write temp/scratch files to `/tmp`, never inside the project. Godot scans and imports every new file under `res://`.

## Conventions

- Run `mise run fmt` periodically
- Run tests: `mise run test` (all tests in parallel, ~45s), `mise run test --fast` (unit tests, < 3s), or `mise run test -- <flag>`
- Check for gdscript warnings and errors and clear them before completing a task (`<godot> --headless --path . -d --ignore-error-breaks --check-only -s res://<file>.gd`)
