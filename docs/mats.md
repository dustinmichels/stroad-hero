# Mats: Character & Gameplay Guide

Mats is the player character in Stroad Hero—a stylized low-poly kid (approximately 1.40 m tall, 4.7 heads high) navigating suburban arterial stroads on foot.

---

## 1. Controls

| Action               | Input                                                          | Description                                                                                          |
| -------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Walk / Turn**      | Arrow Keys (`move_up`, `move_down`, `move_left`, `move_right`) | Move Mats forward/backward and turn in world space.                                                  |
| **Jump / Hop**       | Space (`jump`)                                                 | Jump while on foot.                                                                                  |
| **Shopping Cart**    | Space (`jump`)                                                 | Mount or dismount an abandoned shopping cart when standing nearby.                                   |
| **Answer Phone**     | **Enter** or Gamepad A (`answer_phone`)                        | Answer Mom's incoming phone calls for errands; dismiss in-call dialogue.                             |
| **Rotate Camera**    | A / D (`camera_left`, `camera_right`)                          | Orbit camera around Mats (yaw).                                                                      |
| **Tilt Camera**      | W / S (`camera_forward`, `camera_back`)                        | Pitch camera up and down.                                                                            |
| **Reset Camera**     | R (`camera_reset`)                                             | Re-center camera to default angle and distance behind Mats.                                          |
| **Character Editor** | C (`character_editor`)                                         | Open customization screen to change jacket color, headwear (cap, beanie), backpack, and shoe colors. |
| **Time of Day**      | N                                                              | Cycle lighting between Morning, Noon, Sunset, and Night.                                             |
| **Controls / Help**  | H                                                              | Open the start / controls menu overlay.                                                              |
| **Pause Game**       | Esc                                                            | Pause gameplay and show menu.                                                                        |

---

## 2. Errand Loop (Objectives from Mom)

Mats's primary objective loop involves running errands for Mom across the stroad:

1. **Incoming Call**:
   - Mom calls Mats on his phone after a short initial delay or following the completion of a previous errand.
   - A ringing phone banner appears with a pulsing phone handset icon, the caller ID "MOM", and the prompt `[Enter] Answer`.
   - Press the `answer_phone` action (**Enter** or **Gamepad A**) to answer.

2. **Dialogue Box**:
   - Mom explains what item she needs via typewriter-style dialogue.
   - Mats's movement input is frozen during the call so he doesn't walk into traffic while talking, but world traffic and physics continue uninterrupted.
   - Press **Enter** (`[Enter] OK`) to acknowledge and start the errand.

3. **Store Objectives & Routing**:
   - The errand targets one of the commercial destinations along the stroad:
     - **Cough syrup**: Walgroins entrance (`Props/Walgroins`, north side).
     - **Milk**: Smell Food Mart door (`Props/SmellGasStation`, north side).
     - **Hamburgers**: Booger King entrance (`Props/BoogerKingSite`, south side).
   - **Opposite-Side Rule**: Each new errand prioritizes a store situated on the opposite side of the stroad from Mats's current location, requiring him to cross the multi-lane stroad.

4. **Wayfinding**:
   - **In-World Marker** (`objectives/objective_marker.gd`): An emissive green rotating, bobbing chevron hangs ~6 m above the target store door, paired with a green translucent arrival ring on the ground. The emissive shader ensures visibility during day, sunset, and night.
   - **HUD Arrow** (`ui/objective_arrow.gd`): When the target store is off-screen or behind the camera, a green directional chevron on the HUD points toward the store and displays the real-time distance in meters.

5. **Completion & Loop**:
   - When Mats enters within 2.5 meters of the store entrance, the errand completes immediately.
   - A celebration toast appears ("Got the cough syrup!", etc.) with a green checkmark (`ui/objective_toast.gd`).
   - The HUD's green **OBJ** counter increments with a green flash animation (`ui/hud.gd`).
   - After a ~4-second delay, Mom rings again with the next errand, continuing the loop indefinitely.

---

## 3. Architecture & Key Files

- `objectives/objective_manager.gd`: State machine (`IDLE` $\rightarrow$ `RINGING` $\rightarrow$ `IN_CALL` $\rightarrow$ `ACTIVE` $\rightarrow$ `COMPLETE`), opposite-side target selection, arrival distance tracking, and HUD coordination.
- `objectives/mats_errand.gd`: Errand definition resource containing IDs, item names, store names, entrance node paths, and dialogue lines.
- `objectives/objective_marker.gd`: In-world 3D marker with emissive chevron and ground ring.
- `ui/phone_call.tscn` / `ui/phone_call.gd`: Ringing HUD widget and dialogue panel handling `answer_phone`.
- `ui/objective_arrow.gd`: Screen-edge HUD pointer tracking off-screen target coordinates.
- `ui/objective_toast.gd`: Screen toast banner and checkmark on objective completion.
- `player/mats.gd`: Player kinematic controller, animation loops, and shopping cart riding logic.
