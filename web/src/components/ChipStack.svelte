<script lang="ts">
  // Adapted from Frontier's ChipStack.svelte. Decorative only: the exact
  // number is always shown beside it (design system: never make players
  // estimate an amount from stack height).
  let { amount = 0, max = 8 }: { amount?: number; max?: number } = $props();

  const DENOMS = [
    { value: 500, color: "#2b2b2b", edge: "#bd9655" },
    { value: 100, color: "#a74336", edge: "#f0d7a1" },
    { value: 25, color: "#3f6b4f", edge: "#f0d7a1" },
    { value: 5, color: "#e9dfc7", edge: "#a74336" },
  ];

  const chips = $derived.by(() => {
    const out: { color: string; edge: string }[] = [];
    let left = amount;
    for (const d of DENOMS) {
      while (left >= d.value && out.length < max) {
        out.push(d);
        left -= d.value;
      }
    }
    if (amount > 0 && out.length === 0) out.push(DENOMS[3]);
    return out;
  });
</script>

<div class="stack" aria-hidden="true" style:--n={chips.length}>
  {#each chips as chip, i}
    <span class="chip" style:--i={i} style:--c={chip.color} style:--e={chip.edge}></span>
  {/each}
</div>

<style>
  .stack {
    position: relative;
    width: 34px;
    height: calc(14px + var(--n) * 5px);
    flex: none;
  }

  .chip {
    position: absolute;
    left: 0;
    bottom: calc(var(--i) * 5px);
    width: 34px;
    height: 14px;
    border-radius: 50%;
    background: var(--c);
    border: 2px dashed var(--e);
    box-shadow: 0 2px 0 rgb(0 0 0 / 0.45);
    transition: bottom 180ms ease-out;
  }
</style>
