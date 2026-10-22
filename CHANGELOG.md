# Changelog

## Oct 21, 2026

- **Police SUV & traffic stops**: Added reference-inspired black-and-white interceptor with push bar, steel wheels, POLICE markings, and roof/grille/rear red-blue strobes to the traffic pool. Patrol cars drive dark, light up (strobes + positional wail) behind a car in the curb lane, and pull it over half on the sidewalk at a spot clear of driveways and poles; they sit with silent strobes, then the stopped car leaves first and the police follow. Passing traffic slows, swerves around them, or moves over, and yields when they pull out (`traffic/traffic_stop.gd`).
- **Bus stops**: Four curbside stops with a galvanized pole and double-sided blue "BUS STOP" sign (`props/bus_stop.tscn`). Curb-lane buses signal, brake to put their door at the pole, tuck in toward the curb, dwell 6–12 s, then pull back out once the lane is clear. Traffic swerves past or moves over using the traffic-stop passing rules, and police never stop cars at a bus stop.
- **Erratic driving & shortcuts**: Lane wander and reckless overtakes; lot-to-lot shortcuts connect Colonial Plaza–Cramped Inn, Smell–Walgroins, Cramped Inn–Leaders, Leaders–Consumer Car Care, and Consumer Car Care–Checkers in both directions (25% eligible departure chance). Departing cars also jump the sidewalk at authored crossings by Walgroins/Taco Hell, Colonial Plaza, and Cramped Inn (15%) and merge from the curb. Grass crossings show generated dirt tire ruts (`props/shortcut_ruts.gd`) instead of green desire-path patches.
- **Busier parking lots**: Parked cars no longer run fixed errand timers. Lots start 60–85% full; after a 3–8 s stay a car leaves only while its site stays ≥50% full and at most 0–3 cars (rolled per car) are already leaving. More curb-lane traffic (1.8–3.4 s spawns, 90% errand rate) roughly doubles lot arrivals (~15 → ~31 per minute) and cars moving in lots (~5 → ~12).
- **Profiling & rendering optimizations**: Multi-meshed forest trees (replacing 688 bodies with 36 MultiMeshes), cached traffic blocker candidate sets and vehicle sweeps, throttled environment updates, culled unneeded shadows and 3D labels, and warmed up nighttime lighting shaders. Slashed dusk lights-on freeze from 852ms to 61ms on Compatibility (and 153ms to 38ms on Forward+), halved Compatibility draw calls from ~3,400 to ~1,565, and brought Forward+ night performance to a stable 60 fps.
- **Cybertruck rebuild**: Replaced box-assembled body with generated faceted meshes (`scripts/generate_cybertruck.gd`): single-ridge wedge profile, inward-leaning greenhouse with flush windshield/side glass, tonneau cover, polygonal arch flares, headlight/taillight markers for lamps and turn signals. Stainless steel is its only finish (never repainted).
- **Mats running gait**: Sprinting now blends out of the walking pose into longer strides, higher knee lift, stronger arm swing, and a forward lean.
- **Retro visual style filter**: Real-time post-process pixelation, ordered Bayer or clustered-dot halftone dithering, edge inking, nearest-color or luminance-ramp palettes, and CRT effects (scanlines, aperture mask, curvature, vignette, grain) (`shaders/pixel_art.gdshader`, table-driven presets in `ui/retro_filter.gd`). `F1` / `Shift+F1` cycle 14 styles: Subtle, 16-Bit, Chunky, PICO-8, Game Boy, Amber, CGA, NES, 1-Bit Ink, Virtual Boy, Arcade CRT, Night Vision, Thermal, Comic Halftone. Active presets render 3D at screen ÷ block size with MSAA and, on Forward+, draw 1-block depth/normal outlines (`shaders/pixel_outline.gdshader`); web falls back to color edges.
- **Custom game icon**: Replaced default Godot engine icon with custom SVG app icon depicting Mats in full heroic sprint dodging a monster American pickup across multi-lane stroad markings inside an MUTCD-style warning diamond sign assembly with vectorized "STROAD HERO" plaque.

## Oct 20, 2026

- **Frontage road & businesses**: Added parallel two-lane frontage road with connector, double-yellow striping, and 3 commercial businesses (Consumer Car Care, Leaders Outdoor, Checkers) (`f380152`).
- **Procedural forest & boundary fences**: Generated perimeter forest with ~690 trees and chainlink fences along the forest boundary enclosing the playable corridor (`387b217`).
- **Stroad road extension & tunnel portals**: Extended stroad 50m with concrete highway tunnel portals at $x = -100$ and $x = 150$ for smooth despawning (`bca5feb`).
- **Traffic speed classes & multi-lane passing**: Added tiered cruising speeds across vehicle classes and passing maneuvers for approaching faster cars (`387b217`).
- **Mats sprint & stamina system**: Added Shift sprint mechanic with forward lean and floating HUD stamina wheel (`a4eeaf1`).
- **Respawn & crossing counter**: Track active stroad side; respawn on starting sidewalk on death and track successful crossings (`e10aa63`).
- **Ford F-150 & sports car polish**: Added rolling coal smokestacks, racing stripes, and corrected F-150 hitbox/materials (`4007d80`).
- **Cybertruck car model**: Added electric pickup with stainless steel exoskeleton, triangular wedge roofline, full-width front/rear LED light bars, polygonal wheel arches, and EV zero-emissions behavior based on `@samples/cars/cybertruck/`.
- **Day & weather progression**: Accelerated day cycle from 3:30 PM to 9:00 PM with sky/lighting shifts, wind simulation, and top-right HUD compass/weather widget (`f380152`).
- **Environment & conflict architecture**: Extracted `EnvironmentController`, `WorldWarmup`, and `CarSweep` out of monolithic managers (`387b217`).
- **Visual & shader upgrades**: Added foliage wind flutter, neglected sidewalk weathering, billowing exhaust plumes, and colossal Dorf American flag (`6f1a0e8`, `4007d80`).
- **Sidewalk utility pole placement**: Relocated roadside wooden electricity power poles directly into the middle of the pedestrian sidewalk ($z = -13.85$) across all spans (`main.tscn`), capturing authentic suburban stroad pedestrian hostility where poles obstruct walking paths, verified with collision testing in `--test-powerlines` (`tests/objectives_ui_suite.gd`).

## Oct 19, 2026

- **Mats objective system**: Added JSON-driven objective loop where Mom calls Mats with errands across stores to encourage stroad crossings (`4af436e`).
- **Mom dialogue system**: Implemented dialogue overlay with typewriter text, excuse generator, and objective HUD tracking (`760bcc4`, `2a020f3`).
- **Daytime headlights**: Dynamic headlight activation during evening/night while remaining off during daytime travel (`64e5eb5`).
- **Sedan visual overhaul**: Replaced primitive sedan with refined Blender model, lowered cabin profile, and detailed trim (`64e5eb5`).
- **Lean test workflow**: Trimmed `mise run test` to fast inner suite and moved slow physics simulations to `mise run test --extended` (`64e5eb5`, `ee3b61d`).

## Oct 18, 2026

- **Smell gas station**: Added Shell parody on the north side with fuel canopy, 6 pumps, convenience store, and pylon sign (`f54b9f8`).
- **Jeep Wrangler passenger car**: Modeled 4-door off-road vehicle with custom palette, spare tire, and full traffic/errand integration (`101afca`).
- **Shipping truck**: Added 13.7m long-nose semi tractor with refrigerated trailer to highway cruising traffic (`12706bd`).
- **Mats character model**: Replaced primitive box character with low-poly Blender model, bending joints, and oversized backpack (`101afca`, `c460656`).
- **Strip mall parking & errands**: Enabled Colonial Plaza storefront parking stalls and Lane 3 errand routing (`65ed2c6`).
- **Strip mall mansard roof**: Replaced flat awning with steep red standing-seam mansard roof and updated storefront signage (`65ed2c6`).
- **Asphalt & sidewalk weathering**: Added subtle road grain shader, hairline cracks, tire marks, and textured sidewalks (`81b2920`, `c460656`).
- **World collision & sign visibility**: Added missing static body collision across buildings and tuned sign draw distances (`f54b9f8`).

## Oct 17, 2026

- **Cramped Inn hotel & parking**: Added hotel building, parking lot, and Lane 3 errand routing/merging (`e6367f9`).
- **Taco Hell & Booger King drive-thrus**: Built complete drive-thru lane system with menu boards, intercoms, canopy, and striping (`afe5a89`, `e6367f9`).
- **Street furniture**: Added fire hydrants, dumpsters with opening lids, steel bollards, and abandoned shopping carts (`afe5a89`).
- **Interactive shopping carts**: Mats can bump carts to roll them, jump inside to ride, and exit on prompt (`afe5a89`, `e98ebd5`).
- **Wind simulation & flags**: Added global wind model in `GameState`, animated US flags, and flag vertex shader (`afe5a89`).
- **Lot traffic anti-collision**: Implemented curved footprint collision checking in `TrafficManager.find_blocker` to prevent parking lot deadlocks (`afe5a89`).
- **Crime delivery van**: Cleaned up delivery van geometry, simplified rear cargo box, and polished side decals (`afe5a89`).
- **Camera smoothing**: Updated camera pitch and tracking to interpolate smoothly with player movement (`da6ab3c`).
