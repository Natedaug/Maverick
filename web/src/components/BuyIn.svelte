<script lang="ts">
  import { game } from "../lib/bridge.svelte";
  import { formatChips } from "../lib/cards";
  import type { TableState } from "../lib/protocol";

  let { view }: { view: TableState } = $props();

  const status = $derived(view.status);
  const rate = $derived(status.wallet_units_per_chip > 0 ? status.wallet_units_per_chip : 1);
  const affordable = $derived(Math.floor(status.wallet_balance / rate));
  let chips = $state(0);
  $effect(() => {
    chips = Math.min(status.buy_in_chips, affordable);
  });
  const cost = $derived(Math.round(chips * rate));
  const canBuy = $derived(Number.isInteger(chips) && chips > 0 && cost <= status.wallet_balance);
</script>

<section class="buyin" aria-labelledby="buyin-title">
  <p class="eyebrow">Devil's Draw</p>
  <h1 id="buyin-title">The Rusty Spur</h1>
  <p class="lede">A drifter deals at the back table. He doesn't forget a face.</p>

  <form
    novalidate
    onsubmit={(e) => {
      e.preventDefault();
      if (canBuy) game.send({ type: "buy_in", chips });
    }}
  >
    <label for="chips">Buy-in</label>
    <div class="row">
      <input id="chips" type="number" min="1" max={affordable} step="50" bind:value={chips} />
      <span class="unit">chips</span>
    </div>
    <p class="cost">Costs {formatChips(cost)} of your {formatChips(status.wallet_balance)} silver.</p>
    <button type="submit" disabled={!canBuy || status.economy.barred || status.crown.status === "summoned"}>Take a seat</button>
    <p class="cost">Your name here: <strong class="rep">{status.reputation}</strong></p>
  </form>

  {#if view.message}
    <p class="message" role="status">{view.message}</p>
  {/if}
  <div class="files">
    <button onclick={() => game.send({ type: "load" })}>Load saved game</button>
  </div>
</section>

<style>
  .buyin {
    width: 100%;
    margin: 0;
    padding: 32px clamp(20px, 4vw, 40px);
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
    font-size: var(--size-support);
    text-transform: uppercase;
    letter-spacing: 0.2em;
    color: var(--brass);
  }

  h1 {
    margin: 4px 0 8px;
    font-family: var(--font-display);
    font-size: clamp(34px, 5vw, 48px);
    color: var(--parchment);
  }

  .lede {
    margin: 0 0 24px;
    font-size: var(--size-status);
    color: var(--muted);
  }

  form {
    display: grid;
    gap: 10px;
    justify-items: center;
  }

  label {
    font-size: var(--size-support);
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--parchment);
  }

  .row {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  input {
    width: 8ch;
    padding: 8px 12px;
    font: inherit;
    font-size: var(--size-amount);
    font-weight: 700;
    text-align: center;
    color: var(--paper);
    background: var(--ink);
    border: 1px solid var(--brass);
    border-radius: 8px;
  }

  .unit,
  .cost {
    font-size: var(--size-support);
    color: var(--muted);
  }

  .cost {
    margin: 0;
  }

  .rep {
    color: var(--paper);
    text-transform: capitalize;
  }

  button[type="submit"] {
    margin-top: 8px;
    min-height: 56px;
    min-width: 220px;
    border-radius: 10px;
    font-size: var(--size-action);
    font-weight: 700;
    background: var(--go);
    border: 1px solid #6f9c7e;
  }

  button[type="submit"]:disabled {
    opacity: 0.5;
  }

  .message {
    margin: 20px 0 0;
    font-size: var(--size-support);
    color: var(--paper);
  }

  .files {
    margin-top: 16px;
  }

  .files button {
    background: none;
    border: none;
    text-decoration: underline;
    color: var(--parchment);
    font-size: var(--size-support);
  }
</style>
