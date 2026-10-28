<script setup>
// Two roadside pylon signs, one per side of the stroad. `errand` marks stores Mom sends Mats to.
const sides = [
  {
    name: "North side",
    tenants: [
      { name: "Walgroins", color: "#c8102e", what: "24-hour pharmacy. Cough syrup, band-aids, toothpaste.", errand: true },
      { name: "Taco Hell", color: "#6b2c91", what: "Tacos, burritos, quesadillas, and a drive-thru.", errand: true },
      { name: "Smell", color: "#e0a800", what: "Gas station. Milk, cereal, gum, beef jerky.", errand: true },
      { name: "Dorf", color: "#1f3c88", what: "Car dealership with Quick Pain service bays." },
    ],
  },
  {
    name: "South side",
    tenants: [
      { name: "Booger King", color: "#b5471b", what: "Hamburgers and a drive-thru lane.", errand: true },
      { name: "Colonial Plaza", color: "#2c3e66", what: "USA Vape, Freedom Tattoo, Abominos, Star Nails & Spa." },
      { name: "Cramped Inn", color: "#1d6f73", what: "Hotel with a parking lot bigger than the hotel." },
      { name: "Frontage road", color: "#555b66", what: "Consumer Car Care, Leaders Outdoor, Checkers." },
    ],
  },
];
</script>

<template>
  <div class="pylons vp-raw">
    <div v-for="side in sides" :key="side.name" class="pylon">
      <div class="side">{{ side.name }}</div>
      <ul>
        <li v-for="t in side.tenants" :key="t.name" :style="{ '--tenant': t.color }">
          <span class="tenant">{{ t.name }}</span>
          <span class="what">{{ t.what }}</span>
          <span v-if="t.errand" class="errand-stop">Mom sends you here</span>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.pylons {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 2rem;
  margin: 1.5rem 0;
  align-items: start;
}

@media (max-width: 640px) {
  .pylons {
    grid-template-columns: 1fr;
  }
}

.side {
  margin-bottom: 0.5rem;
  color: var(--vp-c-text-2);
  font-weight: 700;
}

ul {
  display: grid;
  gap: 0.5rem;
  margin: 0;
  padding: 0.6rem;
  list-style: none;
  background: var(--asphalt);
  border-radius: 0.4rem 0.4rem 0 0;
}

li {
  margin: 0;
  padding: 0.7rem 1rem 0.6rem;
  border-left: 0.6rem solid var(--tenant);
  border-radius: 0.2rem;
  background: var(--paint);
  color: var(--asphalt);
}

.tenant {
  display: block;
  font-size: 1.3rem;
  font-weight: 800;
  line-height: 1.2;
}

.what {
  display: block;
  color: #555b66;
  font-size: 0.95rem;
  line-height: 1.45;
}

.errand-stop {
  display: inline-block;
  margin-top: 0.3rem;
  padding: 0.05rem 0.5rem 0;
  border-radius: 0.2rem;
  background: var(--warning);
  font-size: 0.85rem;
  font-weight: 700;
}

/* The pole under the sign. */
.pylon::after {
  content: "";
  display: block;
  width: 1.5rem;
  height: 3rem;
  margin-inline: auto;
  background: var(--asphalt-light);
}
</style>
