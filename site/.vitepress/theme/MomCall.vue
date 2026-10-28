<script setup>
import { onMounted, ref } from "vue";
// Mom's lines come from the file the game reads, so the site can't drift from the game.
import errands from "../../../objectives/mats_objectives.json";
import portrait from "../../../ui/mom_portrait.png";

const pick = (list) => list[Math.floor(Math.random() * list.length)];

// Godot BBCode italics mark Dutch translations: "Mats schat [[i]darling[/i]]". Split them out instead of using v-html.
const segments = (text) =>
  text.split(/\[i\](.*?)\[\/i\]/).map((part, i) => ({ text: part, em: i % 2 === 1 }));

// Mirrors ObjectiveManager.generate_dialogue: opening, excuse (item-specific 45% of the time), request.
function momCall() {
  const parts = errands.dialogue_parts;
  const location = pick(errands.locations);
  const item = pick(location.items);
  const itemExcuses = parts.item_excuses[item.toLowerCase().replace(/[ -]/g, "_")] ?? [];
  const pool = [...parts.excuses.general, ...(parts.excuses[location.category] ?? [])];
  const excuse = itemExcuses.length && Math.random() < 0.45 ? pick(itemExcuses) : pick(pool);
  return {
    lead: segments(`${pick(parts.openings)} ${excuse}`),
    request: pick(parts.requests).replace("{item}", item).replace("{location}", location.proper_name),
  };
}

// A fixed first call keeps server-rendered HTML and hydration identical; randomize once mounted.
const call = ref({
  lead: segments("Mats lieverd [[i]sweetheart[/i]]... The TV remote just died right before my favorite show."),
  request: "Could you pick up some batteries at Walgroins?",
});
const mounted = ref(false);
onMounted(() => {
  call.value = momCall();
  mounted.value = true;
});
</script>

<template>
  <article class="phone-call vp-raw" aria-labelledby="mom-caller">
    <header>
      <img :src="portrait" alt="" width="64" height="64" />
      <div>
        <div id="mom-caller" class="caller">Mom</div>
        <div class="status">Incoming call</div>
      </div>
    </header>
    <p class="line" aria-live="polite">
      <template v-for="(seg, i) in call.lead" :key="i"><em v-if="seg.em">{{ seg.text }}</em><template v-else>{{ seg.text }}</template></template>
      <strong>{{ call.request }}</strong>
    </p>
    <button v-if="mounted" class="call-again" type="button" @click="call = momCall()">
      Let Mom call again
    </button>
  </article>
</template>

<style scoped>
.phone-call {
  max-width: 34rem;
  margin: 1.5rem 0;
  padding: 1.5rem;
  border-radius: 1.25rem;
  background: var(--asphalt);
  color: var(--paint);
}

header {
  display: flex;
  align-items: center;
  gap: 1rem;
}

header img {
  width: 4rem;
  height: 4rem;
  border-radius: 50%;
  object-fit: cover;
  border: 3px solid var(--warning);
}

.caller {
  font-size: 1.25rem;
  font-weight: 800;
}

.status {
  color: #c3c7cf;
  font-size: 0.95rem;
}

.line {
  min-height: 6em;
  font-size: 1.1rem;
  line-height: 1.55;
}

.line strong {
  display: block;
  margin-top: 0.5rem;
  color: var(--warning);
}

.call-again {
  padding: 0.6rem 1.2rem 0.5rem;
  border-radius: 0.4rem;
  background: var(--warning);
  color: var(--asphalt);
  font-weight: 800;
}

.call-again:hover {
  background: #ffd659;
}
</style>
