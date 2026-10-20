# Changelog

## Oct 19, 2026

### Changed

- **Sedan appearance**: Lowered the cabin profile, reshaped the front and rear lamps, and added five-spoke wheel detail, grille blades, door seams, and beltline trim in `cars/bodies/sedan.blend`. Mirror housings now follow the body paint palette. Driving behavior and wheel radius are unchanged.
- **Daytime car headlights**: Car headlights now remain off during the day across all vehicle types (SpotLight3D disabled, mesh emission disabled). Headlights dynamically activate during evening and night for moving vehicles, turn off when parked, and update on time-of-day transitions (`cars/car.gd`, `cars/passenger_car.gd`, car scenes, `addons/mesh_baker/mesh_baker.gd`).
- **Lean test workflow**: Moved the Godot test harness out of `main.gd` into an inherited test scene, made `mise run test` a small inner suite, added `--extended` for long gameplay simulations, and moved non-asserting performance measurements to `mise run bench`. Removed duplicate merge and animation-implementation tests, trimmed brittle visual assertions, and made the runner stop failed Godot processes immediately.

### Added

- **Expanded parody objective system**: Added JSON-driven objective catalog (`objectives/mats_objectives.json`) and procedural dialogue generator for Mom's errand calls across 4 parody stores (Walgroins, Booger King, Taco Hell, Smell) and 13 items. Features Dutch terms of endearment, variable excuses, and randomized requests alternating between proper and generic store names.

- **Mats objectives (errands from Mom)**: An errand loop where Mom calls Mats with errands to pick up items along the stroad. Answer incoming calls via the `answer_phone` action (A, Enter, or Gamepad A) with a typewriter dialogue overlay that pauses Mats's input while the world keeps running. Errands alternate across the stroad (cough syrup at Walgroins, milk at Smell Food Mart, hamburgers at Booger King) to encourage crossing traffic. Includes an in-world emissive green chevron marker with an arrival ring (`objectives/objective_marker.gd`), an off-screen HUD tracker arrow with distance readouts (`ui/objective_arrow.gd`), a completion toast with checkmark (`ui/objective_toast.gd`), a green-bordered OBJ counter on the HUD (`ui/hud.tscn`, `ui/hud.gd`), and a headless test suite (`--test-objectives`).

## Oct 18, 2026

### Added

- **Smell gas station**: A Shell parody on the north side of the road, west of Walgroins (`samples/buildings/shell/`). It has a concrete forecourt, a white canopy with yellow and red bands and Smell logo panels, three pump islands with six double-sided pumps, a convenience store ("SMELL FOOD MART") with a maroon/gold fascia, poster-covered glass, and rooftop units, and a roadside pylon sign with a logo cabinet, message panels, and a price board. The north-west sidewalk now has two curb cuts for the station, and two trees that stood in the lot were moved (`buildings/smell_gas_station.tscn`, `buildings/smell_fuel_pump.tscn`, `buildings/smell_logo.tscn`, `main.tscn`).
- **Ice machine**: A reusable packaged-ice merchandiser with two blue doors, chrome handles, and collision (`props/ice_machine.tscn`). One stands next to the Smell store entrance.
- **Shipping truck**: A white long-nose semi tractor with a high-roof sleeper and roof fairing, pulling a ribbed aluminum refrigerated trailer with a front reefer unit. It has tandem drive and trailer axles with chrome wheels. It is 13.7 m long, spawns in about 4% of lane traffic at 90% of lane speed, and stays on the road (`cars/shipping_truck.tscn`, `cars/shipping_truck.gd`, `Car.CarType.SHIPPING_TRUCK`, `traffic/traffic_manager.gd`).
- **Strip mall parking**: Colonial Plaza's lot has 8 striped stalls along the storefront (two handicap) that are registered with the parking engine as `strip_mall` spots. Eastbound Lane 3 cars now take strip mall errands: they turn in at the mall's driveway (entry x = -7, exit x = -3), park, back out, wait, and merge east. F8 spawns a debug strip mall car, and `--test-strip-mall` runs the full errand cycle (`traffic/parking_lot.gd`, `traffic/traffic_manager.gd`, `buildings/strip_mall.tscn`, `main.gd`).
- **Jeep car type**: A 4-door Wrangler-style passenger car modeled on `samples/cars/jeep/jeep.png` (`cars/bodies/jeep.tscn`, `Car.CarType.JEEP`). It has a painted 7-slot grille with round headlights in black bezels, a flat hood between lower front fenders, trapezoid black fender flares, larger 0.4 m all-terrain tires on gunmetal rims, a black bumper with red tow hooks, fog lights, and a skid plate, and a raked windshield. The painted hardtop has A/B/C/D pillars over the side glass. It also has door seams, exposed hinges, handles, black mirrors, rock-rail side steps, vertical taillights, and a tailgate-mounted spare tire. It spawns as part of regular passenger traffic, visits parking lots and drive-thrus, and supports random paint palette customization (`cars/passenger_car.gd` paints the fenders and center pillars and sets the jeep's wheel radius).
- **Pavement weathering**: Asphalt uses a restrained procedural grain shader, while a compact authored detail mesh places twelve short hairline cracks and four faint paired tire marks at deliberate locations across the road and parking lots (`shaders/pavement.gdshader`, `props/pavement_details.gd`).

### Changed

- **Sedan model**: Replaced the primitive Godot-built sedan with a curvier four-door Blender model featuring rounded bodywork, a raked glasshouse, mirrors and handles, detailed wheels, grille and diffuser trim, and shaped lamp assemblies. `cars/bodies/sedan.blend` is now the source of truth, instantiated by `cars/bodies/sedan.tscn`.
- **Mats model**: Replaced the primitive-built Mats with a Blender-modeled low-poly kid (about 1.40 m, a big head at roughly 4.7 heads tall) with round cheeks, large eyes with highlights, a button nose, blush, a small smile, side-swept hair, a curved-brim ball cap, a fitted jacket with collar, zipper, and hem, chunky velcro sneakers, and an oversized backpack with straps, sternum strap, and grab handle. Knees, elbows, and ankles now bend: knees flex through the swing phase, elbows bend more on the forward arm swing, ankles keep the shoes near level, and knees tuck mid-hop. The faster stride rate suits his shorter legs. He kneels facing forward in shopping carts. The collision capsule is now 1.5 m tall, and the character editor preview re-aims at his middle. The source is `art/mats/build_mats.py` (generator) and `art/mats/mats.blend`; `mise run mats` exports it to native meshes in `player/mats_meshes/` without an editor import. Backpack and shoe tinting are unchanged; the shoe paths moved under `Knee/Shoe` (`player/mats.tscn`, `player/mats.gd`, `player/character_editor.gd`, `mise.toml`).
- **Strip mall roof**: Replaced the flat red awning, which hid the store signs, with a steep standing-seam red mansard that has closed ends, a white fascia, and a soffit, matching `samples/strip-mall/mall2.png`. The store signs are mounted upright in front of the slope. Window posters now sit in front of the glass. Sign text was resized to fit its panels: the Freedom Tattoo and Star Nails titles, the handicap plates, the RESERVED stall paint, and the dumpster warning sticker (`buildings/strip_mall.tscn`, `props/dumpster.tscn`).
- **South-side lots**: Cramped Inn routing now comes from a shared `ParkingLot.SOUTH_LOTS` config instead of `cramped_inn_*` route functions. Lane 3 merges pick the merge path for the nearest wait point (`TrafficManager.lane3_merge_path`) instead of checking `x > 0`. Spot requests no longer poach stalls behind another driveway. `can_spawn_drive_thru` now also requires the turn-in point to be clear of lane traffic.
- **World collision coverage**: Added `StaticBody3D` collision shapes to previously passable objects: Walgroins main building and entrance tower, roadside pylon sign posts (Walgroins, Booger King, Cramped Inn, and Taco Hell), Taco Hell dumpster corral adobe walls, and drive-thru menu boards and ordering speakers (Booger King and Taco Hell). Fixed Strip Mall's roadside sign to place cylinder collision shapes on both actual poles rather than blocking the center pedestrian gap (`buildings/walgroins.tscn`, `buildings/booger_king_sign.tscn`, `buildings/cramped_inn.tscn`, `buildings/taco_hell.tscn`, `buildings/strip_mall.tscn`, `buildings/booger_king_site.tscn`).

### Fixed

- **Walgroins awnings**: Reversed both storefront awning tilts so they slope down toward the sidewalk instead of up, and shifted each 0.3 m toward its outside building edge (`buildings/walgroins.tscn`).

## Oct 17, 2026

### Added

- **Street Furniture**: Stylized fire hydrant (`props/fire_hydrant.tscn`), dumpsters with opening lids (`props/dumpster.tscn`), steel security bollards (`props/bollard.tscn`), and abandoned shopping carts (`props/shopping_cart.tscn`).
- **Booger King Dressing**: Ordering station with menu board and LCD screen, intercom speaker box, dumpster corral, and drive-thru pavement striping (`buildings/booger_king_site.tscn`).
- **Taco Hell Dressing & Functionality**: Complete drive-thru suite with commercial multi-panel menu board, illuminated overhead canopy hood, dynamic LCD order screen, angled intercom speaker box with marquee, transverse "ORDER STOP" and "WAIT HERE FOR PICKUP" striping, painted directional arrows and "DRIVE THRU" pavement lettering, window apron hazard hatching, security bollards, southwest adobe dumpster corral with dual trash/recycle dumpsters, and live interactive controller (`buildings/taco_hell_drive_thru.gd`).
- **Wind & Flags**: `GameState` global wind simulation (`game_state.gd`), dynamic flag alignment (`props/us_flag.gd`), wind vertex shader (`shaders/us_flag.gdshader`), and `--test-wind-flags` test in `main.gd`.
- **Shopping Cart Interaction**: Carts roll forward or backward with collision when Mats bumps either end, but never sideways. A small bottom-right Space prompt appears nearby; Mats can jump in, ride seated, and press Space again to exit (`props/shopping_cart.gd`, `player/mats.gd`, `ui/hud.gd`).
- **Infrastructure**: Cramped Inn hotel building (`buildings/cramped_inn.tscn`), parking lot, and `export-web` mise task.
- **Cramped Inn Traffic & Parking**: Activated Cramped Inn parking lot with 5 stalls across two rows, entrance routing, split entry/exit aisles (`CI_ENTRY_AISLE_Z = 17.5`, `CI_EXIT_AISLE_Z = 20.25`), Lane 3 errand decisions and right turns, reversing out, exit waiting, and Lane 3 gap merging (`traffic/parking_lot.gd`, `traffic/traffic_manager.gd`, `main.gd`). F7 debug key spawns an errand vehicle directly to Cramped Inn.

### Changed

- **Camera pitch**: Updates now run on render frames and aim from the camera's smoothed position at Mats's interpolated position, keeping W/S tilt motion and framing smooth.
- **Crime van**: Smoothed the side arrows and spaced both logos clear of the lettering. Simplified the rear cargo body to one rectangular box without stacked panels or wheel skirts, removed the side windows, retained the windshield and rounded cab/bumper details, and removed the roof overhang (`cars/van.tscn`, baked `cars/van_*.res` meshes).
- **Walgroins**: Moved the roadside sign to the left side of the building when facing the storefront (`buildings/walgroins.tscn`).
- `main.tscn`: Replaced primitive hydrant cylinder, placed abandoned carts in Walgroins lot, and added `GameState` node.
- `docs/style.md`: Updated polish checklist progress.

### Fixed

- **Lot traffic collisions**: Cars backing out of stalls and heading back to the road no longer drive through each other. `TrafficManager.find_blocker` now checks each car's real footprint along its curved path, not a straight line from its center. A car backing out claims its whole back-out route, and `can_reverse_out` waits until that route is clear. When two routes cross, the car that reaches the crossing first goes and the other stops before it is in the way. The Taco Hell crossing mutex and the drive-thru/driveway special cases are gone because the general check covers them (`traffic/traffic_manager.gd`).
- **Parking-lot turn clearance**: Right-sized the three driveway openings and their asphalt aprons around the full entering and exiting car footprints so cars stay off the sidewalk without oversized curb cuts (`main.tscn`).
