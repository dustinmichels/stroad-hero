# Changelog

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
