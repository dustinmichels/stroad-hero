<template>
  <div class="guide-sign exit-sign" role="img" aria-label="Road sign: Walgroins, Taco Hell, Smell, next right">
    <span>Walgroins</span>
    <span>Taco Hell</span>
    <span>Smell</span>
    <svg viewBox="0 0 48 48" aria-hidden="true">
      <path d="M12 36 34 14M18 13h17v17" fill="none" stroke="currentColor" stroke-width="6" />
    </svg>
  </div>
</template>

<style scoped>
.exit-sign {
  display: flex;
  flex-direction: column;
  width: min(100%, 18rem);
  margin-inline: auto;
  padding: 1.5rem 1.75rem 1.25rem;
  font-size: 1.6rem;
  font-weight: 700;
  line-height: 1.3;
}

svg {
  width: 3rem;
  margin-top: 0.75rem;
  align-self: flex-end;
}
</style>
