# Visual Style Guide & Asset Documentation

This document catalogs the current visual style and 3D assets of **Stroad Hero**. High-resolution render captures are saved in the [`./screenshots/`](../screenshots/) folder.

---

## 1. Visual Direction & Aesthetic

- **Art Style:** Stylized low-poly / voxel-adjacent 3D with clean silhouette edges, vibrant saturated colors, and untextured matte/semi-gloss materials.
- **Tone:** Parodic, satirical, and deliberate suburban dystopia. Clean, cheerful colors contrast with the bleak reality of car-dominated American stroad infrastructure.
- **Lighting & Atmosphere:** Bright mid-day sun, crisp directional shadows (`DirectionalLight3D` + soft ambient fill), procedural blue sky with horizon haze, and subtle tonemapped bloom for neon and signage.
- **Pedestrian vs. Vehicle Scale:** Mats is modeled as a small, fragile, blocky Dutch boy with bright orange jacket and blue trousers. In contrast, vehicles are chunky, massive, high-speed geometric forms, and store parking lots and roads dwarf the narrow sidewalks.

---

## 2. In-Game & Environmental Screenshots

| Screenshot                               | Description                                                                                                                                                                                                                    |
| :--------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `01_gameplay_perspective.png`            | **Default Gameplay View:** Mats on the south sidewalk with HUD ("SPD: 0 / Senseless Pedestrian Deaths"), active stroad traffic, double yellow lines, and the Walgroins / Taco Hell commercial strip across the 4-lane roadway. |
| `02_stroad_corridor_birds_eye.png`       | **Aerial Corridor View:** Elevated overview of the entire 4-lane stroad corridor, showing the shared commercial parking lot, sidewalk curb cuts, procedural grass shader, and roadside trees.                                  |
| `03_pedestrian_hostile_street_level.png` | **Pedestrian Peril (Street Level):** Dramatic eye-level perspective looking across the 4 asphalt lanes, showing the massive commercial pylon signs, lack of pedestrian crosswalks, and oncoming vehicle traffic.               |
| `04_south_side_booger_king_and_inn.png`  | **South Side Commercial Strip:** Booger King drive-thru lane, ordering menu board, green "OPEN" window sign, waving American flag, and the giant crowned Booger King burger pylon sign.                                        |
| `05_north_side_errands_parking_lot.png`  | **North Side Shared Lot:** Active errand vehicles turning into the lot across the sidewalk driveway apron, marked parking stalls, and storefront facades.                                                                      |
| `06_character_customizer.png`            | **Character Customizer UI:** In-game pause menu showing the customization options (hair/hat, backpack colors) and the 3D rotating preview of Mats.                                                                             |

---

## 3. Individual Assets Showcase

### Characters

- **`asset_character_mats.png`** — **Mats (Player Character)**:
  - Blocky proportions with segmented limbs (swinging arms and legs during walk cycle).
  - Stylized blonde hair, facial features (dark eyes with white specular highlights, subtle smiling mouth).
  - Bright orange hooded jacket, denim blue trousers, and modular backpack (Pine, Blue, Red, Yellow variants).

### Vehicles

- **`asset_vehicles_fleet_lineup.png`** — **Full Fleet Showcase**:
  - Lineup of all 9 vehicle types modeled in the game:
    1. **Transit Bus:** Two-tone blue and white livery, multiple passenger doors, rooftop HVAC units.
    2. **Delivery Van / Box Truck:** High-capacity white cargo box on commercial chassis.
    3. **Pickup Truck:** Forest green work truck with open rear cargo bed.
    4. **SUV:** Dark blue sport utility vehicle with roof rails.
    5. **Sedan:** Classic bright red 4-door family sedan.
    6. **Taxi:** Bright yellow cab with rooftop taxi medallion sign.
    7. **Minivan:** Burgundy family van with extended cabin.
    8. **Sports Car:** Low-slung purple coupe with rear aerodynamic wing and dual hood vents.
    9. **Hatchback:** Compact bright orange 3-door commuter car.
- **`asset_vehicles_featured.png`** — **Featured Vehicle Close-ups**:
  - Close-up 3/4 detail view of the Transit Bus, Taxi, Sports Car, and Pickup Truck.

### Buildings & Commercial Sites

- **`asset_building_walgroins.png`** — **Walgroins Pharmacy**:
  - Gable entrance pediment, red brick wainscoting, cream stucco facade.
  - Parodic red cursive _"Walgroins"_ script logo, bold _"W"_, and _"PHARMACY"_ lettering.
  - Side pharmacy drive-thru pickup window.
- **`asset_building_taco_hell.png`** — **Taco Hell**:
  - Southwestern mission-style facade with bell arch porticos.
  - Neon purple/pink roofline accent trim, bold _"OPEN"_ signage, and drive-thru order and pick-up windows.
- **`asset_building_booger_king.png`** — **Booger King**:
  - Modern fast-food architecture with stacked stone base, wood slat parapet tower, and horizontal red racing stripe.
  - Hamburger bun logo with parody text, rooftop HVAC units, and giant crowned roadside pylon sign (_"HOME OF THE BOOGER / 99¢ SNOT FRIES / DRIVE THRU"_).
- **`asset_building_cramped_inn.png`** — **Cramped Inn**:
  - Three-story hotel structure (parody of Hampton Inn) with beige stucco exterior, multi-window grid, vehicle drop-off porte-cochere canopy, and neon cursive hotel branding.
- **`asset_building_dorf_dealership.png`** — **Dorf Dealership**:
  - Contemporary auto dealership complex with sleek metallic silver showroom, tinted glass curtain wall showing interior turntable and sales desks, blue oval _"Dorf"_ logo, orange _"QUICK PAIN"_ service department with 3 garage bays and bollards, and display ramp.

### Props & Street Furniture

- **`asset_props_showcase.png`** — **Street Furniture Collection**:
  - **Overhead Road Sign:** Galvanized steel truss structure with green highway destination boards (_"688 WEST INDIAN ROCKS BEACH"_, _"TO 19 LARGO CLEARWATER"_, _"688 EAST TAMPA"_).
  - **US Flag:** 8-meter steel flagpole with gold finial and waving cloth using a custom vertex displacement shader.
  - **Stylized Tree:** Spherical layered low-poly foliage on a tapered brown trunk.
  - **Street Lamp:** Cobra-head dark steel streetlight with emissive illuminated luminaire.
  - **Fire Hydrant:** Classic red municipal cast-iron hydrant.
