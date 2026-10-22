# Visual Style & Polish Checklist

Items marked **`[HUMAN REVIEW NEEDED]`** highlight open design questions or implementation choices.
---

## 1. Lighting & "Toybox" Post-Processing (`WorldEnvironment`)

- [ ] **Tilt-Shift Depth of Field**
  - [ ] Enable Depth of Field with narrow focus distance centered on the player's street lane.
  - [ ] [HUMAN REVIEW NEEDED] Placement choice from doc: Configure on `Camera3D` or in `WorldEnvironment`.
  - [ ] Verify miniature diorama toy-set aesthetic (top parking lot and bottom foreground blurred).
- [x] **Warm Directional Sun & Ambient Tint**
  - [x] Shift `DirectionalLight3D` to a slightly warm golden/sunlight tint (pale warm cream).
  - [x] Set ambient light (`Environment > Ambient Light > Sky/Color`) to soft cool periwinkle blue so shadows are not pitch black.
- [ ] **Screen-Space Ambient Occlusion (SSAO)**
  - [ ] Enable SSAO in `WorldEnvironment` for soft contact shadows under car chassis, building walls/asphalt seams, and curbs.
- [x] **Tonemapping & Color Grading**
  - [x] `Filmic` (Active in `main.tscn` via `tonemap_mode = 2`).
  - [ ] Bump saturation slightly (1.1–1.15) to make bright reds, yellows, and greens punch through cleanly.

---

## 2. Materials, Textures, and Outlines

- [ ] **Stylized Edge Outlines**
  - [ ] [HUMAN REVIEW NEEDED] Contradiction with Section 5: Section 2 proposes choosing between an inverted-hull material or a screen-space pixel outline shader applied across cars, signs, and character meshes. Section 5 preselects inverted hull for car base materials only.
    - [ ] Option A: Inverted-hull unshaded outline material.
    - [ ] Option B: Screen-space pixel outline post-process shader.
  - [ ] Target outline width: 1–2 pixels (black/dark navy).
  - [ ] Target scope: Decide whether outlines apply to cars only (per Section 5) or cars, signs, and character meshes (per Section 2).
- [ ] **Break Up Monolithic Asphalt**
  - [ ] Add painted road details:
    - [ ] Zebra crossing stripes.
    - [x] Road arrows (Added to Booger King drive-thru lane).
    - [ ] Oil drip decals in parking stalls.
    - [ ] Manhole covers.
    - [ ] Yellow-painted curb edges.
  - [ ] Add subtle triplanar noise shader on grass and pavement for slight value jitter instead of flat hex colors.
- [ ] **Glow / Emissive Signs & Lights**
  - [ ] Set emissive property on neon green "OPEN" sign, streetlamp bulbs, car headlights, and restaurant logos.
  - [x] Toggle **Glow** in `WorldEnvironment` for night/dusk transitions.

---

## 3. Environmental Dressing & Micro-Details

- [x] **Street Furniture**
  - [x] Replace red primitive sidewalk cylinder with recognizable stylized fire hydrant (cylinder with two side pegs and a top cap).
  - [x] Add low-poly dumpsters behind Booger King.
  - [x] Add steel bollards near store entrances.
  - [x] Add stray shopping carts abandoned in Walgroins parking lot.
- [ ] **Foliage Jitter**
  - [ ] [HUMAN REVIEW NEEDED] Choice in doc: Randomize tree scale, height, and rotation (±15%) via script or in editor.
    - [ ] Script randomization.
    - [ ] Editor manual / tool setup.
  - [x] Alternate between 2–3 slight green shades across round trees (Implemented via 5 distinct tree variants with distinct albedo green tints and foliage meshes in `props/tree.tscn`).
- [x] **Drive-Thru Details (Booger King)**
  - [x] Add menu board.
  - [x] Add ordering speaker box.
  - [x] Add lane striping around drive-thru window.

---

## 4. Dynamic Animation & "Juice"

- [ ] **Car Movement Dynamics**
  - [ ] Add chassis roll when cornering, forward dip on hard braking, and back squat on acceleration.
  - [ ] [HUMAN REVIEW NEEDED] Choice in doc: Implement via simple tweening or raycast spring damping.
    - [ ] Simple tweening.
    - [ ] Raycast spring damping.
- [x] **Particle Systems (`CPUParticles3D`)**
  - [x] Car exhaust smoke emitters (Implemented in `cars/car.gd` via `_setup_exhaust` and `_update_exhaust`).
  - [ ] Add simple dust poofs under player shoes when walking or sprinting.
- [ ] **Blinking / Neon Flicker**
  - [ ] Add small script to randomly flicker "OPEN" sign.
  - [ ] Add small script to buzz / flicker parking lot lamp.

- [x] **Wind & Flag Simulation**
  - [x] Global wind manager (`GameState`) simulating dynamic wind direction and speed fluctuations with gusts.
  - [x] Dynamic flagpole alignment swiveling cloth meshes to match prevailing wind while preserving hoist edge attachment.
  - [x] Custom vertex displacement shader (`shaders/us_flag.gdshader`) reacting to wind speed.
