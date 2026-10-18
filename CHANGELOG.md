# Changelog

## Oct 18, 2026

### Added

- **Shipping truck**: A white long-nose semi tractor with a high-roof sleeper and roof fairing, pulling a ribbed aluminum refrigerated trailer with a front reefer unit. It has tandem drive and trailer axles with chrome wheels. It is 13.7 m long, spawns in about 4% of lane traffic at 90% of lane speed, and stays on the road (`cars/shipping_truck.tscn`, `cars/shipping_truck.gd`, `Car.CarType.SHIPPING_TRUCK`, `traffic/traffic_manager.gd`).
- **Strip mall parking**: Colonial Plaza's lot has 8 striped stalls along the storefront (two handicap) that are registered with the parking engine as `strip_mall` spots. Eastbound Lane 3 cars now take strip mall errands: they turn in at the mall's driveway (entry x = -7, exit x = -3), park, back out, wait, and merge east. F8 spawns a debug strip mall car, and `--test-strip-mall` runs the full errand cycle (`traffic/parking_lot.gd`, `traffic/traffic_manager.gd`, `buildings/strip_mall.tscn`, `main.gd`).

### Changed

- **Strip mall roof**: Replaced the flat red awning, which hid the store signs, with a steep standing-seam red mansard that has closed ends, a white fascia, and a soffit, matching `samples/strip-mall/mall2.png`. The store signs are mounted upright in front of the slope. Window posters now sit in front of the glass. Sign text was resized to fit its panels: the Freedom Tattoo and Star Nails titles, the handicap plates, and the RESERVED stall paint (`buildings/strip_mall.tscn`).
- **South-side lots**: Cramped Inn routing now comes from a shared `ParkingLot.SOUTH_LOTS` config instead of `cramped_inn_*` route functions. Lane 3 merges pick the merge path for the nearest wait point (`TrafficManager.lane3_merge_path`) instead of checking `x > 0`. Spot requests no longer poach stalls behind another driveway.

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
