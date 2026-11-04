<script lang="ts">
  // Adapted from Frontier's PlayerSeat.svelte. Name, role, and stack sit
  // directly beside the two hole cards at every size (design system rule).
  import Card from "./Card.svelte";
  import ChipStack from "./ChipStack.svelte";
  import { formatChips } from "../lib/cards";
  import type { RivalTell, RivalTiming, SeatState } from "../lib/protocol";

  let {
    seat,
    name,
    role,
    isPlayer = false,
    acting = false,
    tell = "neutral",
    timing = "",
    showCommit = true,
  }: {
    seat: SeatState;
    name: string;
    role: string;
    isPlayer?: boolean;
    acting?: boolean;
    tell?: RivalTell;
    timing?: RivalTiming;
    showCommit?: boolean;
  } = $props();

  const TELL_TEXT: Record<Exclude<RivalTell, "neutral">, { label: string; hint: string }> = {
    kempt: { label: "Kempt", hint: "Steady rhythm — acting quickly lately" },
    unkempt: { label: "Unkempt", hint: "Shaky rhythm — long pauses lately" },
  };

  const cardSlots = $derived(
    seat.cards.length > 0
      ? seat.cards.map((code) => ({ code, hidden: false }))
      : Array.from({ length: seat.hidden_cards }, () => ({ code: "", hidden: true })),
  );
  const thinking = $derived(acting && !isPlayer && (timing === "tank" || timing === "snap" || timing === "normal"));
</script>

<section class="seat" class:player={isPlayer} class:acting class:folded={seat.folded} aria-label={`${name}'s seat`}>
  <div class="identity">
    <div class="name-row">
      <h2 class="name">{name}</h2>
      {#if seat.folded}
        <span class="badge fold">Folded</span>
      {:else if seat.all_in}
        <span class="badge allin">All-in</span>
      {/if}
      <span class="role">{role}</span>
    </div>
    <div class="stack">
      <ChipStack amount={seat.stack} />
      <span class="amount">{formatChips(seat.stack)}</span>
      <span class="unit">chips</span>
      {#if showCommit && seat.street_commitment > 0}
        <span class="commit" aria-label={`${formatChips(seat.street_commitment)} chips bet this street`}>
          <ChipStack amount={seat.street_commitment} max={3} />
          In for {formatChips(seat.street_commitment)}
        </span>
      {/if}
    </div>
  </div>

  {#if !isPlayer && tell !== "neutral"}
    <div class="read" title={TELL_TEXT[tell].hint}>
      <span class="read-label">Your read</span>
      <span class="read-value {tell}">{TELL_TEXT[tell].label}</span>
      <span class="read-hint">{TELL_TEXT[tell].hint}</span>
    </div>
  {/if}

  <div class="hand">
    <div class="cards">
      {#each cardSlots as slot, i (i)}
        <Card code={slot.code} hidden={slot.hidden} size={isPlayer ? "lg" : "md"} />
      {/each}
    </div>
    {#if thinking}
      <div class="thinking {timing}" role="status">
        {#if timing === "tank"}
          <span class="dots" aria-hidden="true"><i></i><i></i><i></i></span> In the tank…
        {:else if timing === "snap"}
          Snap decision
        {:else}
          Thinking…
        {/if}
      </div>
    {/if}
  </div>

</section>

<style>
  .seat {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, auto) auto;
    grid-template-areas: "identity read hand";
    align-items: center;
    gap: 10px 20px;
    padding: clamp(8px, 1.4vh, 14px) 18px;
    background: linear-gradient(180deg, var(--wood-light), var(--wood));
    border: 1px solid #5a4a33;
    border-radius: 14px;
    box-shadow: 0 8px 20px rgb(0 0 0 / 0.35);
    transition:
      border-color 160ms,
      box-shadow 160ms,
      opacity 160ms;
  }

  .seat.acting {
    border-color: var(--parchment);
    box-shadow:
      0 0 0 2px rgb(240 215 161 / 0.35),
      0 8px 24px rgb(0 0 0 / 0.4);
  }

  .seat.folded {
    opacity: 0.6;
  }

  .identity {
    grid-area: identity;
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0;
  }

  .name-row {
    display: flex;
    align-items: baseline;
    gap: 2px 10px;
    flex-wrap: wrap;
  }

  .name {
    margin: 0;
    font-family: var(--font-display);
    font-size: var(--size-name);
    font-weight: 700;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--paper);
  }

  /* Role sits on its own line when there is room, beside the name when short. */
  .role {
    flex-basis: 100%;
    font-size: var(--size-support);
    color: var(--parchment);
  }

  .stack {
    display: flex;
    align-items: flex-end;
    gap: 10px;
    margin-top: 2px;
  }

  .amount {
    font-size: var(--size-amount);
    font-weight: 700;
  }

  .unit {
    font-size: var(--size-support);
    color: var(--muted);
    padding-bottom: 3px;
  }

  .badge {
    font-size: 14px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    padding: 2px 8px;
    border-radius: 6px;
    border: 1px solid currentColor;
  }

  .badge.fold {
    color: #e6a091;
  }

  .badge.allin {
    color: var(--parchment);
  }

  .read {
    grid-area: read;
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 2px 8px;
    align-items: baseline;
    margin-top: 6px;
    padding: 6px 10px;
    border-left: 3px solid var(--brass);
    background: rgb(0 0 0 / 0.2);
    border-radius: 0 6px 6px 0;
    max-width: 30rem;
  }

  .read-label {
    font-size: 13px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--muted);
  }

  .read-value {
    font-weight: 800;
    font-size: var(--size-status);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .read-value.kempt {
    color: #9fd3b4;
  }

  .read-value.unkempt {
    color: #f0b48a;
  }

  .read-hint {
    grid-column: 1 / -1;
    font-size: 15px;
    color: var(--muted);
  }

  .hand {
    grid-area: hand;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
  }

  .cards {
    display: flex;
    gap: 8px;
  }

  .thinking {
    font-size: var(--size-support);
    color: var(--parchment);
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .thinking.snap {
    color: #9fd3b4;
    font-weight: 700;
  }

  .thinking.tank {
    color: #f0b48a;
    font-weight: 700;
  }

  .dots {
    display: inline-flex;
    gap: 3px;
  }

  .dots i {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: currentColor;
    animation: pulse 1s infinite ease-in-out;
  }

  .dots i:nth-child(2) {
    animation-delay: 0.15s;
  }

  .dots i:nth-child(3) {
    animation-delay: 0.3s;
  }

  .commit {
    display: inline-flex;
    align-items: flex-end;
    gap: 6px;
    margin-left: 10px;
    padding-bottom: 3px;
    font-size: var(--size-support);
    font-weight: 700;
    color: var(--parchment);
  }

  @keyframes pulse {
    50% {
      opacity: 0.25;
    }
  }

  /* Short windows: the exact numbers stay; decorative stacks go. */
  @media (max-height: 720px) {
    .stack :global(.stack),
    .commit :global(.stack) {
      display: none;
    }

    .identity {
      gap: 0;
    }

    .name-row {
      column-gap: 14px;
      row-gap: 0;
    }

    .role {
      flex-basis: auto;
    }
  }

  @media (max-width: 640px) {
    .seat {
      grid-template-columns: 1fr;
      grid-template-areas: "identity" "read" "hand";
      justify-items: start;
      padding: 12px;
    }

    .hand {
      align-items: flex-start;
    }
  }
</style>
