# Stroad Hero

This is a Godot indie video game.

## Goal

I want to make an activist video game that highlights the misery of "stroads" (sprawling, high speed streets).

User plays as "Mats" a young dutch boy living in Anywhere, USA. His mother has asked him to do some errands. He is trying to do so without going splat.

It involves a frogger like element, where user has to dodge cars.

It also has a satire element, showing the sprawing urban landscape. There are parody versions of common stores like Walgroins instead of Walgreens. Taco Hell intead of Taco Bell.

I am picturing something with pixel art graphics, but not married to this idea.

I think the underlying model should perhaps be 3D, so I can simulate real traffic patterns (cars drive to their destinations, park, person gets out, gets back in, drives somewhere else.)

## Controls

- Arrow keys: walk relative to the current camera
- W/A: rotate the camera left 45 degrees; S/D: rotate it right 45 degrees
- Space: small hop; next to a shopping cart, enter it or exit while riding
- C: open the paused character editor; use Up/Down to choose a row and Left/Right to change it. The preview slowly turns to show the backpack.
- F3: toggle traffic and parking debug overlay (parking stall statuses, car states/paths, merge windows, and HUD metrics)
- F4: spawn a debug errand car at the driveway turn-in
- F5: spawn a debug Taco Hell drive-thru car
- F6: spawn a debug Booger King drive-thru car
- F7: spawn a debug Cramped Inn errand car

## Traffic

Traffic includes sedans, SUVs, taxis, delivery vans, pickup trucks, buses, shipping trucks (semis), hatchbacks, minivans, and sports cars. Smaller passenger vehicles can use parking lots; buses, shipping trucks, and delivery vans remain on the road.

Vehicles in the westbound curb lane can run errands to Walgroins and Taco Hell. When assigned an errand, a car reserves a suitable stall, decelerates and turns into the shared parking lot driveway across the sidewalk apron, parks and dwells for a visit, reverses out into the aisle, proceeds to the exit wait point, yields for an acceptable gap in westbound traffic, and merges back into flow.
