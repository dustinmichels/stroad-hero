# Visual Style Guide & Asset Documentation

## 1. Visual Direction & Aesthetic

- **Art Style:** Stylized low-poly / voxel-adjacent 3D with clean silhouette edges, vibrant saturated colors, and untextured matte/semi-gloss materials.
- **Tone:** Parodic, satirical, and deliberate suburban dystopia. Clean, cheerful colors contrast with the bleak reality of car-dominated American stroad infrastructure.
- **Lighting & Atmosphere:** Bright mid-day sun, crisp directional shadows (`DirectionalLight3D` + soft ambient fill), procedural blue sky with horizon haze, and subtle tonemapped bloom for neon and signage.
- **Pedestrian vs. Vehicle Scale:** Mats is modeled as a small, fragile, blocky Dutch boy with bright orange jacket and blue trousers. In contrast, vehicles are chunky, massive, high-speed geometric forms, and store parking lots and roads dwarf the narrow sidewalks.

## 2. Lighting & Post-Processing

- **Sun & Sky:** Warm golden sunlight (`DirectionalLight3D`) paired with soft periwinkle ambient fill (`Environment > Ambient Light`) prevents pitch-black shadows while preserving high contrast.
- **Tonemapping:** Filmic tonemapping (`tonemap_mode = 2` in `WorldEnvironment`) controls highlight blowout across bright vehicles and white concrete.
- **Glow & Emissives:** `WorldEnvironment` glow enables bloom for storefront neon, restaurant logos, streetlight bulbs, and vehicle headlamps/taillights during dusk and night phases.
- **Time & Atmosphere:** `EnvironmentController` orchestrates smooth day/night transitions and weather conditions, modulating ambient energy, fog, and sun angles.

## 3. Environmental Dressing & Props

- **Street Furniture:** Stylized low-poly props add lived-in detail without visual clutter: low-poly commercial dumpsters behind Booger King, red fire hydrants along sidewalks, yellow protective bollards at entrances, and abandoned shopping carts in parking lots.
- **Commercial Features:** Fast-food sites feature functional visual dressings including drive-thru menu boards, ordering speaker boxes, and painted pavement arrows.
- **Foliage:** Five distinct tree variants with procedural canopies and unique green albedos break up repetitive landscaping.

## 4. World Dynamics & Effects

- **Wind & Flag Simulation:** Global wind model in `GameState` drives fluctuating speed and direction with gusting. Flagpoles dynamically swivel to align with the wind vector, and the flag cloth uses a vertex displacement shader (`shaders/us_flag.gdshader`).
- **Vehicle Exhaust:** Running vehicles emit low-poly exhaust puffs (`CPUParticles3D`) that scale with vehicle throttle and speed.

## 5. Visual Performance Constraints

- **Label3D Culling:** All 3D signage text nodes use explicit `visibility_range_end` distances and alpha fade margins to eliminate off-screen glyph processing.
- **Headlamp LOD:** Hardware `SpotLight3D` illumination is limited to the closest moving vehicles; distant or parked cars retain emissive lens shaders without dynamic light instances.
- **Shadow Casters:** Shadow casting is disabled on road striping, parking stall paint, decals, flat logo trim, billboards, and chainlink fence fabric.
- **Distant Scenery:** Background perimeter trees outside the playable fences are batched as `MultiMeshInstance3D` instances with distance fade, bypassing individual nodes and colliders.
