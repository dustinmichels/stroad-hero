# Changelog

## Oct 17, 2026

### Added

- **Street Furniture**: Stylized fire hydrant (`props/fire_hydrant.tscn`), dumpsters with opening lids (`props/dumpster.tscn`), steel security bollards (`props/bollard.tscn`), and abandoned shopping carts (`props/shopping_cart.tscn`).
- **Booger King Dressing**: Ordering station with menu board and LCD screen, intercom speaker box, dumpster corral, and drive-thru pavement striping (`buildings/booger_king_site.tscn`).
- **Taco Hell Dressing & Functionality**: Complete drive-thru suite with commercial multi-panel menu board, illuminated overhead canopy hood, dynamic LCD order screen, angled intercom speaker box with marquee, entrance height clearance arch ("CLEARANCE 9' 0\""), transverse "ORDER STOP" and "WAIT HERE FOR PICKUP" striping, painted directional arrows and "DRIVE THRU" pavement lettering, window apron hazard hatching, security bollards, southwest adobe dumpster corral with dual trash/recycle dumpsters, and live interactive controller (`buildings/taco_hell_drive_thru.gd`).
- **Wind & Flags**: `GameState` global wind simulation (`game_state.gd`), dynamic flag alignment (`props/us_flag.gd`), wind vertex shader (`shaders/us_flag.gdshader`), and `--test-wind-flags` test in `main.gd`.
- **Infrastructure**: Cramped Inn hotel building (`buildings/cramped_inn.tscn`), parking lot, and `export-web` mise task.

### Changed

- `main.tscn`: Replaced primitive hydrant cylinder, placed abandoned carts in Walgroins lot, and added `GameState` node.
- `docs/style.md`: Updated polish checklist progress.
