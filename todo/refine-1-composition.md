# Refinement plan: composition, startup, and scene contracts

## Assessment

Stroad Hero has good asset-level scene organization, but the boundaries between world layout, UI, and startup orchestration need refinement. Scenes frequently rely on specific parent trees, hardcoded descendant paths, and test-mode flags embedded in production startup.

The items in this document establish explicit composition boundaries, stable gameplay destination anchors, and clean test isolation. Completing these items provides the foundation needed before extracting deeper simulation or controller logic.

### What is already working

- Feature folders (`traffic/`, `cars/`, `player/`, `objectives/`, `ui/`, `buildings/`, `props/`) make ownership discoverable.
- `main.tscn:3–33` composes external player, HUD, menu, building, and prop scenes rather than embedding every asset.
- Objective lifecycle signals and `HUD.set_objective_manager()` provide an existing pattern for explicit dependency wiring (`objectives/objective_manager.gd:12–16`, `ui/hud.gd:471–488`).
- Detailed authoring scenes and baked runtime meshes serve different purposes; the mesh-baking pipeline and active-variant instantiation should be preserved.
- The test runner separates three fast traffic contracts from extended scenarios and benchmarks (`scripts/run_tests.py:18–48`).

---

## Action items

### 1. Give objectives stable destination anchors, not mesh paths

**Evidence:** `objectives/mats_objectives.json:24–57` addresses visual descendants such as `Props/BoogerKingSite/Building/Building/Tower/Doors`. `ObjectiveManager.get_target_position()` falls back to hardcoded world coordinates and item IDs (`objectives/objective_manager.gd:308–341`); the same location paths appear in its default data (`551–625`).

**Problem:** Renaming or reorganizing a doorway mesh changes a gameplay dependency. If lookup fails after a building moves, fallback coordinates can keep an objective at the old site instead of exposing the broken connection. The fallback is documented as useful for isolated tests, but it also hides production layout mistakes.

**Plan:**

- [x] Add one explicit gameplay destination anchor to each relevant building/site scene, outside replaceable visual geometry.
- [x] At world setup, bind existing location IDs to those anchors. Keep item/dialogue content in the existing JSON; do not create a second content system.
  - _Handoff:_ `ObjectiveManager.register_destination(id, node)` and `bind_destinations(dict)` register anchors. `ObjectiveManager._setup()` automatically registers standard location IDs (`walgroins`, `booger_king`, `taco_hell`, `smell`) by discovering anchors under `Props/*` or via explicit bindings.
- [x] Resolve objectives through that binding rather than internal mesh names. Supply explicit anchors/positions in isolated tests instead of depending on production coordinate fallbacks.
- [x] Migrate the JSON, default-data path handling, objective manager, affected tests, and `docs/objectives.md` together. Remove obsolete coordinate and item-name location switches once callers have migrated.
- [x] Ensure the baker preserves these anchors and their world transforms; verify both baked and unbaked scenes.

**Acceptance:** Moving a site moves its objective. Renaming a decorative door does not affect arrival detection. An unbound destination is reported and cannot silently complete at a fallback location. Existing objective selection, call flow, and arrival behavior remain intact.

**If skipped:** Art/layout edits continue to require knowledge of objective-manager internals.

---

### 2. Make cross-scene dependencies explicit at composition boundaries

**Evidence:** `buildings/taco_hell_drive_thru.gd:76–105` searches `/root/Main/TrafficManager` and `/root/Main/Mats`, then tries current-scene fallbacks. `ObjectiveManager` mixes exported paths, sibling names, groups, and deferred setup (`objectives/objective_manager.gd:64–135`). HUD independently discovers the manager through groups and sibling names (`ui/hud.gd:461–488`).

**Problem:** Scenes look reusable in the filesystem but rely on a particular parent tree and initialization order. Moving gameplay under a world container or opening an interaction scene independently requires preserving hidden names or adding more fallback lookup paths.

**Plan:**

- [x] Let the containing scene wire required player, traffic, objective, and UI references using typed exported references or existing setters.
- [x] Use scene-local names for a component's own children. Keep existing groups where discovery is genuinely intended, but do not replace all hardcoded paths with another implicit global singleton lookup.
- [x] Cache interaction dependencies during setup rather than rediscovering them in update loops.
- [x] Connect menu-start and objective-start behavior at the composition boundary so the objective state machine does not need to locate a `StartScreen` sibling or inspect its visibility.
- [x] Remove redundant fallback searches as each consumer is migrated; keep optional preview dependencies explicitly optional.

**Acceptance:** The gameplay assembly works under a differently named root/container. A drive-thru can be exercised with explicitly supplied player/traffic dependencies. Objective setup and HUD signal connections happen once, with no duplicated callbacks after teardown/recreation.

**If skipped:** Adding another containing scene or changing initialization order remains unnecessarily fragile.

---

### 3. Remove test-mode behavior from production startup

**Evidence:** `main.gd:337–343` swaps its own script when it sees test/benchmark flags, although `tests/main_tests.tscn:1–7` already supplies the test script and the runner explicitly launches that scene (`scripts/run_tests.py:16,63–75`). `ObjectiveManager._is_test_mode()` starts calls differently (`85–111`); `StartScreen` has another test-mode branch (`ui/start_screen.gd:91–105`). Traffic also checks test/benchmark flags (`traffic/traffic_manager.gd:482–489`).

**Problem:** Production startup knows about the test harness, while tests alter the initialization behavior they are meant to exercise. New flags and fixtures need changes in unrelated production components. This also conflicts with repository policy to keep test command-line branches in `tests/`.

**Plan:**

- [x] Make the existing dedicated test scene the only test entry point and remove production script replacement.
- [ ] Move test/benchmark argument interpretation and fixture setup into `tests/`; inventory all production test-mode branches before changing them.
- [ ] Use ordinary component configuration/start methods for deterministic fixtures. Keep a startup scenario that exercises normal warmup, menu gating, and first-call timing rather than skipping them.
- [ ] Split `tests/main_tests.gd` by responsibility into traffic contracts, traffic scenarios, player interactions, objectives/UI, and benchmarks, with one small dispatcher. Move existing assertions; do not duplicate them or add a new testing framework.
- [ ] Preserve the existing data-driven destination scenarios and fast/extended/benchmark task boundaries.

**Acceptance:** The same existing CLI flags remain supported through the test runner; production scripts no longer branch on `--test-*` or `--bench-*`. The inner suite stays near its current fast-loop target, and normal startup has an exercised scenario.

**If skipped:** Test fixtures and game lifecycle remain entangled, making future scene refactors harder to verify.

---

### 4. Separate environment presentation and warmup from root/menu scripts

**Evidence:** Most of `main.gd:4–327` concerns sky, sunlight, and streetlights rather than composition. It contains both discrete `_apply_time_of_day()` and continuous `_apply_time_hours()` implementations; repository text search found only the discrete method's declaration. `ui/start_screen.gd:40–76,128–172` embeds world prop names, toggles their visibility, and waits for traffic readiness.

**Problem:** Editing environment presentation means changing the entry-point script. Adding or regrouping a building means editing the menu's shader-warmup list. The two lighting implementations also provide competing places to change the same presentation behavior.

**Plan:**

- [ ] Extract one environment controller owning sky/sun/streetlight presentation, wired to the existing `GameState` clock signals. Keep time/weather state separate from rendering; do not introduce another global manager.
- [ ] Keep continuous-time lighting as the live implementation. Confirm references at implementation time, then remove the uncalled discrete path and state used only by it.
- [ ] Move world warmup ownership out of `StartScreen` into world/bootstrap setup. The menu should display progress and gate Start on readiness, not enumerate world asset names.
- [ ] Preserve the existing staged visibility sequence and initial-traffic readiness contract, including pause behavior. Restore authored visibility rather than assuming every hidden prop should become visible.
- [ ] Retain the existing `debug/bake_preview` / `--bake` mechanism (`main.gd:354–358`); it does not need to be reinvented.

**Acceptance:** Day-to-night changes still update sky, streetlights, and headlights. Startup cannot enable play before required warmup finishes. Adding a world warmup group no longer requires changing menu logic. Reopening the pause menu does not rerun startup.

**If skipped:** Root and menu scripts continue accumulating unrelated world responsibilities.

---

## Suggested implementation order

1. **Test entry isolation (Item 3):** establish fixtures and normal-startup coverage before changing scene ownership.
2. **Destination and dependency contracts (Items 1–2):** remove gameplay reliance on visual internals and root names.
3. **Environment/startup extraction (Item 4):** shrink root/menu responsibilities without changing world layout.

For each step, migrate all affected callers and remove obsolete paths. Update relevant documentation (`docs/objectives.md`, `docs/web-loading.md`) when ownership contracts change.

---

## Verification

- Check modified GDScript: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -d --ignore-error-breaks --check-only -s res://<file>.gd`
- Smoke-run main scene: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`
- Run core test suites: `mise run test` (fast loop) and relevant extended suites (`mise run test --extended`, or specific test flags for objectives, start screen, and lighting).
- Visually verify normal startup sequence, shader warmup, and daytime/nighttime lighting transitions in a graphical run.
