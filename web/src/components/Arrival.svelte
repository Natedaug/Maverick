<script lang="ts">
  // The opening of a new season. Godot authors the text; this only shows it.
  import Portrait from "./Portrait.svelte";
  import { game } from "../lib/bridge.svelte";

  let { paragraphs }: { paragraphs: string[] } = $props();
</script>

<section class="arrival" aria-labelledby="arrival-title">
  <p class="eyebrow">New Canaan · Split River Valley</p>
  <h1 id="arrival-title">Devil's Draw</h1>
  <div class="story">
    {#each paragraphs as text, i (i)}
      <p>{text}</p>
    {/each}
  </div>
  <div class="drifter" aria-hidden="true">
    <Portrait kempt={true} />
  </div>
  <button onclick={() => game.send({ type: "begin" })}>Ride in</button>
</section>

<style>
  .arrival {
    width: min(680px, 100%);
    margin: clamp(12px, 5vh, 64px) auto 0;
    padding: clamp(24px, 4vh, 40px) clamp(20px, 4vw, 48px);
    display: grid;
    justify-items: center;
    gap: 14px;
    text-align: center;
    background: linear-gradient(180deg, var(--wood-light), var(--wood));
    border: 1px solid #5a4a33;
    border-radius: 18px;
    box-shadow:
      inset 0 0 0 6px var(--wood),
      inset 0 0 0 7px rgb(189 150 85 / 0.5),
      0 16px 40px rgb(0 0 0 / 0.5);
  }

  .eyebrow {
    margin: 0;
    font-size: 14px;
    text-transform: uppercase;
    letter-spacing: 0.2em;
    color: var(--brass);
  }

  h1 {
    margin: 0;
    font-family: var(--font-display);
    font-size: clamp(36px, 5vw, 52px);
    color: var(--parchment);
  }

  .story {
    display: grid;
    gap: 12px;
    text-align: left;
  }

  .story p {
    margin: 0;
    font-size: var(--size-status);
    line-height: 1.5;
    color: var(--paper);
  }

  .drifter :global(figcaption) {
    display: none;
  }

  @media (max-height: 720px) {
    .drifter {
      display: none;
    }

    .arrival {
      margin-top: 8px;
      gap: 10px;
    }
  }

  button {
    min-height: 56px;
    min-width: 220px;
    border-radius: 10px;
    font-size: var(--size-action);
    font-weight: 700;
    background: var(--go);
    border: 1px solid #6f9c7e;
  }
</style>
