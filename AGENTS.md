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
- Run tests: `mise run test` (lean inner suite), `mise run test --extended` (long simulations), or `mise run test -- <flag>`
- Run manual performance measurements separately with `mise run bench`
- Check for gdscript warnings and errors and clear them before completing a task (`<godot> --headless --path . -d --ignore-error-breaks --check-only -s res://<file>.gd`)

## Changelog

- When wrapping up a task, consider adding it to CHANGELOG.md
- No need to add minor changes
- If adding, re-write today's entry as needed to ensure it compactly reflects signifigant changes from today.

## Testing policy

- Keep `mise run test` fast (target under ~3 seconds). It is the inner loop for core contracts (obstacle detection, traffic priority, exit yielding).
- Put slower tests, secondary systems, and full-scene simulations in `mise run test --extended`. Consolidate destination variants into shared, data-driven scenarios instead of copying the same state machine.
- Add a permanent test only when it catches a plausible player-visible regression. Prefer behavior, boundaries, state transitions, and failure cases.
- Do not pin visual implementation details such as exact colors, fonts, joint angles, mesh types, animation frames, coordinates, tween timing, or copy text unless that exact value is an accessibility or gameplay contract.
- Do not duplicate coverage across unit and scenario tests. Keep the smallest test that proves the behavior; move any unique assertion before deleting a duplicate.
- Keep test state and command-line branches in `tests/`, not production scripts such as `main.gd`.
- Benchmarks belong to `mise run bench`, run serially, and are not tests unless they enforce an explicit regression threshold.
