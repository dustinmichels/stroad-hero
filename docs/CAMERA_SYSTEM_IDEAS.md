# Camera System Ideas

## Problem

The current camera maps W/A/S/D to absolute world-space viewpoints. This has several drawbacks:

- The controls describe directions on the keyboard, but the result depends on an invisible world compass.
- W can swing 180 degrees from the starting view because the starting camera is on the opposite side of Mats.
- A held key continually retargets the same fixed angle instead of feeling like direct camera control.
- The camera can move while arrow-key walking remains locked to the movement basis captured at the start of the stride. That is stable, but the relationship is not obvious to the player.
- There is no quick command whose meaning is always “put the camera behind Mats.”

The camera should prioritize seeing traffic, preserving movement direction during a crossing, and recovering a useful view with one predictable input.

## Options

| Option | Controls | Strengths | Risks |
|---|---|---|---|
| Relative orbit | A/D orbit left and right; W moves behind Mats; S moves in front of Mats | Every input is relative to the player, provides direct control, and has a reliable reset | W/S are actions rather than symmetric orbit axes |
| Free orbit | A/D control yaw; W/S control pitch | Familiar third-person camera control and complete viewpoint freedom | Pitch is probably less useful than quick recentering in a road-crossing game; keyboard control can feel mechanical |
| Eight-way stepping | Each WASD press rotates 45 degrees relative to the current view | Simple, discrete, and easy to tune | The meaning of each individual key is difficult to teach; repeated taps are needed to recover a known view |
| Automatic follow | Camera gradually moves behind Mats while walking; WASD temporarily overrides it | Low input burden and consistently shows the direction of travel | The camera may move when the player needs a stable view of oncoming traffic |
| Fixed isometric views | WASD selects one of four authored viewpoints | Predictable composition and straightforward level design | Abrupt conceptual changes between views; less freedom around buildings and parking lots |
| Road-aware camera | Camera favors the direction of dangerous traffic near roads and follows normally elsewhere | Can improve hazard visibility without player input | Hidden rules, surprising movement, and substantially more tuning and code |

## Recommendation: Relative Orbit

Use a restrained third-person orbit rather than absolute compass directions.

### Controls

- **A:** orbit counterclockwise around Mats.
- **D:** orbit clockwise around Mats.
- **W:** smoothly recenter behind Mats, using his facing direction.
- **S:** smoothly move in front of Mats, looking back at him.
- **Arrow keys:** continue moving relative to the camera.
- **A + D:** cancel each other.

A/D should support both taps and holds:

- A tap rotates one 45-degree step.
- Holding for roughly 0.2 seconds transitions into continuous orbit.
- Releasing stops at the current angle; it should not snap to a compass direction.

This makes all commands local and visible. W always recovers the standard playable view, while S gives a quick look at danger approaching from behind.

### Movement Interaction

Keep the movement basis fixed until all arrow keys are released. Camera motion during a stride must not curve Mats or reverse the meaning of a held arrow key. The next arrow-key press uses the camera’s new orientation.

This is close to the current movement behavior and avoids changing two systems at once.

### Camera Motion

Start with:

- Fixed distance and pitch.
- A/D orbit speed around 150 degrees per second.
- 45-degree tap steps.
- 0.25-second recenter time for W/S.
- Short position smoothing so the camera follows Mats without lagging across a traffic lane.
- Shortest-path angle interpolation for every swing.

Do not add zoom, mouse control, shoulder swapping, or automatic recentering in the first prototype. They complicate evaluation of the core orbit behavior.

## Alternative Worth Prototyping: Automatic Follow With Manual Override

If manual orbit still demands too much attention, try a conservative follow mode:

1. The camera remains still while Mats is idle.
2. After Mats walks consistently in one direction for about one second, the camera slowly begins moving behind him.
3. Any WASD camera input immediately cancels automatic movement.
4. Automatic follow stays disabled for several seconds after manual input.
5. The camera never auto-rotates while Mats is in the road.

The final rule matters most. A player judging traffic gaps needs a stable view more than a perfectly centered character.

## Occlusion

Whichever control model wins, buildings and signs can block Mats. Handle this separately from orbit controls:

1. Raycast from Mats to the desired camera position.
2. Move the camera inward when geometry blocks the ray.
3. Restore distance smoothly when the obstruction clears.
4. Never change yaw to solve occlusion; unexpected rotation is more disruptive than temporary zoom-in.

Do this only after the control scheme feels correct in unobstructed areas.

## Prototype Checklist

Test each candidate in these situations:

- Cross all four traffic lanes while rotating the camera.
- Stop on the median and inspect both traffic directions.
- Walk around a parked bus or delivery van.
- Navigate between a storefront and the parking lot.
- Reverse direction, then recover the behind-Mats view with one input.
- Die while the camera is off-center and verify that respawn restores a predictable view.

A successful camera should satisfy all of these:

- A held arrow key never changes meaning mid-stride.
- The player can look both ways without moving Mats.
- One key restores the standard view.
- Camera motion never starts without input while crossing the road.
- Mats remains visible near large vehicles and buildings.

## Suggested Next Prototype

Implement only the recommended relative orbit behavior in `follow_camera.gd`. Keep the existing distance, pitch, target tracking, smoothing, and death reset. Replace absolute WASD yaw targets with A/D relative orbit plus W/S facing-relative recenter commands. Evaluate that before adding collision handling or automatic behavior.
