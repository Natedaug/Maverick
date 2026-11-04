<script lang="ts">
  // Adapted from Frontier's Card.svelte. Three distinct looks per the design
  // system: a readable face, a stamped back for hidden cards, and a muted
  // felt slot for undealt board cards.
  import { parseCard, SUIT_SYMBOL } from "../lib/cards";

  let {
    code = "",
    hidden = false,
    size = "md",
  }: { code?: string; hidden?: boolean; size?: "md" | "lg" } = $props();

  const card = $derived(code ? parseCard(code) : null);
  const red = $derived(card?.suit === "h" || card?.suit === "d");
</script>

{#if card}
  <div class="card face {size}" class:red role="img" aria-label={card.label}>
    <span class="corner top">{card.rank}<span class="pip">{SUIT_SYMBOL[card.suit]}</span></span>
    <span class="center" aria-hidden="true">{SUIT_SYMBOL[card.suit]}</span>
    <span class="corner bottom" aria-hidden="true">{card.rank}<span class="pip">{SUIT_SYMBOL[card.suit]}</span></span>
  </div>
{:else if hidden}
  <div class="card back {size}" role="img" aria-label="Hidden card">
    <span class="stamp" aria-hidden="true">★</span>
  </div>
{:else}
  <div class="card slot {size}" aria-hidden="true"></div>
{/if}

<style>
  .card {
    --w: clamp(44px, min(6.2vw, 8vh), 84px);
    position: relative;
    width: var(--w);
    aspect-ratio: 5 / 7;
    border-radius: calc(var(--w) * 0.1);
    flex: none;
    animation: deal 220ms ease-out;
  }

  .card.lg {
    --w: clamp(54px, min(7.4vw, 10vh), 104px);
  }

  .face {
    background: var(--paper);
    color: var(--club-black);
    border: 1px solid #d8ccb0;
    box-shadow: 0 6px 14px rgb(0 0 0 / 0.45);
  }

  .face.red {
    color: var(--heart-red);
  }

  .corner {
    position: absolute;
    display: flex;
    flex-direction: column;
    align-items: center;
    line-height: 0.95;
    font-weight: 800;
    font-size: calc(var(--w) * 0.3);
  }

  .corner .pip {
    font-size: 0.8em;
  }

  .top {
    top: 6%;
    left: 8%;
  }

  .bottom {
    bottom: 6%;
    right: 8%;
    transform: rotate(180deg);
  }

  .center {
    position: absolute;
    inset: 0;
    display: grid;
    place-items: center;
    font-size: calc(var(--w) * 0.55);
    opacity: 0.9;
    padding-left: 18%;
    padding-top: 22%;
  }

  .back {
    background:
      repeating-linear-gradient(45deg, rgb(255 255 255 / 0.05) 0 4px, transparent 4px 8px),
      linear-gradient(160deg, #7c2f26, #4e1c17);
    border: 2px solid var(--brass);
    box-shadow:
      inset 0 0 0 4px #4e1c17,
      inset 0 0 0 5px rgb(189 150 85 / 0.6),
      0 6px 14px rgb(0 0 0 / 0.45);
    display: grid;
    place-items: center;
  }

  .stamp {
    color: var(--brass);
    font-size: calc(var(--w) * 0.34);
  }

  .slot {
    border: 2px dashed rgb(240 215 161 / 0.22);
    background: rgb(0 0 0 / 0.12);
    animation: none;
  }

  @keyframes deal {
    from {
      transform: translateY(-10px) scale(0.96);
      opacity: 0;
    }
  }
</style>
