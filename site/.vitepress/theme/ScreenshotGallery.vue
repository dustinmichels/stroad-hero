<template>
  <ul class="gallery vp-raw">
    <li>
      <img src="@screenshots/02_stroad_corridor_birds_eye.png" alt="Bird's-eye view of the stroad with Walgroins, Taco Hell, flagpoles, and traffic." loading="lazy" />
      <span>The corridor from above</span>
    </li>
    <li>
      <img src="@screenshots/03_pedestrian_hostile_street_level.png" alt="Street-level view along a narrow sidewalk next to fast traffic." loading="lazy" />
      <span>Street level</span>
    </li>
    <li>
      <img src="@screenshots/04_south_side_booger_king_and_inn.png" alt="The south side of the stroad with Booger King and the Cramped Inn." loading="lazy" />
      <span>Booger King and the Cramped Inn</span>
    </li>
    <li>
      <img src="@screenshots/05_north_side_errands_parking_lot.png" alt="Cars parked and maneuvering in the north-side parking lots." loading="lazy" />
      <span>North-side parking lots</span>
    </li>
    <li>
      <img src="@screenshots/06_character_customizer.png" alt="The character customizer showing Mats with his backpack." loading="lazy" />
      <span>Character customizer</span>
    </li>
    <li>
      <img src="@screenshots/asset_vehicles_fleet_lineup.png" alt="A lineup of the game's vehicles: sedans, pickups, SUVs, buses, and trucks." loading="lazy" />
      <span>The fleet</span>
    </li>
  </ul>
</template>

<style scoped>
.gallery {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(16rem, 1fr));
  gap: 1.5rem;
  margin: 1.5rem 0;
  padding: 0;
  list-style: none;
}

li {
  margin: 0;
}

img {
  width: 100%;
  aspect-ratio: 16 / 10;
  object-fit: cover;
  border-radius: 0.3rem;
}

span {
  display: block;
  margin-top: 0.4rem;
  font-weight: 600;
}
</style>
