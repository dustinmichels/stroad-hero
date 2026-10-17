### 1. Lighting & "Toybox" Post-Processing (WorldEnvironment)

Right now, the lighting is standard flat directional light with sharp, high-contrast shadows and washed-out ambient tones. Adding post-processing inside Godot instantly elevates low-poly block art:

- **Tilt-Shift Depth of Field:** In the `Camera3D` or `WorldEnvironment`, enable Depth of Field with a narrow focus distance centered on the player's street lane. Blurring the top parking lot and bottom foreground gives the scene a miniature, diorama toy-set aesthetic.
- **Warm Directional Sun & Ambient Tint:** Shift the `DirectionalLight3D` to a slightly warm golden/sunlight tint (e.g., pale warm cream) and set ambient light (`Environment > Ambient Light > Sky/Color`) to a soft cool periwinkle blue so shadows aren't pitch black.
- **Screen-Space Ambient Occlusion (SSAO):** Enable SSAO in Godot's `WorldEnvironment`. This adds soft contact shadows under car chassis, where building walls meet asphalt, and around curbs, eliminating the "floating" feeling of untextured primitives.
- **Tonemapping & Color Grading:** Change the tonemapper from `Linear` to `Filmic` or `ACES` and bump saturation slightly (1.1–1.15) to make the bright saturated reds, yellows, and greens punch through cleanly.

---

### 2. Materials, Textures, and Outlines

Flat solid-color materials show polygon edges abruptly without conveying surface feel. Subtle stylized tweaks keep the low-poly style without requiring complex 3D texturing:

- **Stylized Edge Outlines:** Apply an inverted-hull unshaded outline material or a screen-space pixel outline post-process shader. A 1–2 pixel outline around cars, signs, and character meshes emphasizes the retro cartoon/comic tone.
- **Break Up Monolithic Asphalt:**
- The parking lot and road currently look like single flat grey planes. Add simple painted details: road arrows, zebra crossing stripes, oil drip decals in parking stalls, manhole covers, and yellow-painted curb edges.
- Use a subtle triplanar noise shader on the grass and pavement just to add slight value jitter rather than flat hex colors.

- **Glow/Emissive Signs & Lights:** Give the neon green "OPEN" sign, streetlamp bulbs, car headlights, and restaurant logos an emissive property, and toggle **Glow** in the `WorldEnvironment` to make night/dusk transitions pop.

---

### 3. Environmental Dressing & Micro-Details

The humor in satirical storefronts ("Walgroins", "Booger King", "Taco Hell") works best when the surrounding scene matches the mundane absurdity of suburban strip malls:

- **Street Furniture:**
- Replace the red primitive cylinder on the sidewalk with a recognizable stylized fire hydrant (a cylinder with two side pegs and a top cap).
- Add low-poly dumpsters behind Booger King, newspaper vending boxes, steel bollards near store entrances, and stray shopping carts abandoned in the Walgroins parking lot.

- **Foliage Jitter:** The round trees look great conceptually, but give them scale, height, and rotation variations (±15% randomized via script or editor) and alternate between 2–3 slight green shades so they don't look cloned.
- **Drive-Thru Details:** Add a menu board, ordering speaker box, and lane striping around the Booger King drive-thru window.

---

### 4. Dynamic Animation & "Juice"

Low-poly games feel infinitely better when rigid bodies have exaggerated physical responses:

- **Car Movement Dynamics:** Give vehicles a slight chassis roll when cornering, a forward dip on hard braking, and a back squat on acceleration using simple tweening or raycast spring damping.
- **Particle Systems (`GPUParticles3D`):**
- Tiny cartoon smoke puffs (2D billowy sprite or low-poly white spheres that quickly shrink) spitting from car exhausts.
- Simple dust poofs under the player's shoes when walking or sprinting.

- **Blinking / Neon Flicker:** A small script that randomly flickers the "OPEN" sign or buzzes a parking lot lamp adds life to static buildings.

---

### Immediate Implementation Plan

```
1. Godot Environment Pass (15 min):
   └── Add WorldEnvironment node -> Set Tonemap to ACES -> Enable SSAO -> Enable Glow (Soft) -> Add slight DOF.

2. Road & Lot Decals (30 min):
   └── Place 3D Decal nodes or thin flat planes for crosswalk zebra stripes, manhole covers, and oil stains.

3. Car & Entity Outlines (20 min):
   └── Attach an inverted hull outline pass (black/dark navy, cull_front, unshaded) to car base materials.

4. Micro-Props (30 min):
   └── Build 3 quick Godot CSG assemblies: low-poly dumpster, fire hydrant, and parking lot shopping cart.

```
