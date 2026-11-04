<script lang="ts">
  // Devil's Draw while you're away from the table. Godot draws the walkable
  // street behind this screen; here is the HUD over it, and each place's panel
  // (the Rusty Spur, the assay office, the boarding house, the landing) opens
  // over the map. Godot computes every price and decides every rule.
  import BuyIn from "./BuyIn.svelte";
  import CranePortrait from "./CranePortrait.svelte";
  import { game } from "../lib/bridge.svelte";
  import { formatChips } from "../lib/cards";
  import type { Crown, TableState } from "../lib/protocol";

  let { view }: { view: TableState } = $props();

  const world = $derived(view.status.world);
  const places = $derived(world?.places ?? {});
  const near = $derived(world?.near ?? "");

  // Which place's panel is open over the map ("" = walking the street).
  let openPlace = $state("");
  let placesOpen = $state(false);

  function open(place: string): void {
    stopWalking();
    placesOpen = false;
    openPlace = place;
    game.send({ type: "go", place });
  }

  function close(): void {
    openPlace = "";
  }

  // Walking: keys held → one direction, sent only when it changes.
  const held = new Set<string>();
  let lastMove = "0,0";
  const KEYS: Record<string, [number, number]> = {
    w: [0, -1], arrowup: [0, -1], s: [0, 1], arrowdown: [0, 1],
    a: [-1, 0], arrowleft: [-1, 0], d: [1, 0], arrowright: [1, 0],
  };

  function sendMove(): void {
    let x = 0;
    let y = 0;
    for (const key of held) {
      x += KEYS[key][0];
      y += KEYS[key][1];
    }
    const next = `${Math.sign(x)},${Math.sign(y)}`;
    if (next === lastMove) return;
    lastMove = next;
    const len = Math.hypot(x, y) || 1;
    game.send({ type: "move", x: x / len, y: y / len });
  }

  function stopWalking(): void {
    held.clear();
    sendMove();
  }

  const typing = (e: KeyboardEvent) =>
    e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement || e.target instanceof HTMLSelectElement;

  function onKeyDown(e: KeyboardEvent): void {
    const key = e.key.toLowerCase();
    if (key === "escape" && openPlace) {
      close();
      return;
    }
    if (openPlace || crownResult || typing(e) || e.metaKey || e.ctrlKey || e.altKey) return;
    if (key in KEYS) {
      e.preventDefault();
      held.add(key);
      sendMove();
    } else if ((key === "e" || key === "enter") && near) {
      e.preventDefault();
      open(near);
    }
  }

  function onKeyUp(e: KeyboardEvent): void {
    const key = e.key.toLowerCase();
    if (held.delete(key)) sendMove();
  }

  // Leaving this screen (taking a seat, etc.) stops the walk.
  $effect(() => stopWalking);

  const eco = $derived(view.status.economy);
  const crown = $derived(view.status.crown);
  const crownPending = $derived(crown.status === "invited" || crown.status === "summoned");
  const crownResult = $derived(crown.result?.lines?.length ? crown.result : null);
  const silver = $derived(view.status.wallet_balance);
  const daysLeft = $derived(eco.dealer_due_day - eco.day);
  const paidShare = $derived(1 - eco.dealer_owed_gold / Math.max(1, eco.dealer_start_gold));

  let lot = $state(1); // index into gold_quotes
  const quote = $derived(eco.gold_quotes[Math.min(lot, eco.gold_quotes.length - 1)]);

  let payGold = $state(0);
  const maxPay = $derived(Math.min(eco.gold, eco.dealer_owed_gold));
  $effect(() => {
    payGold = maxPay;
  });
  const canPay = $derived(Number.isInteger(payGold) && payGold > 0 && payGold <= maxPay);

  const dueText = $derived(
    eco.dealer_owed_gold === 0
      ? "Paid in full."
      : eco.dealer_overdue
        ? `Past due since day ${eco.dealer_due_day}.`
        : daysLeft === 0
          ? "Due today."
          : `Due day ${eco.dealer_due_day} — ${daysLeft} day${daysLeft === 1 ? "" : "s"} left.`,
  );
</script>

{#snippet crownResultCard(r: Crown["result"])}
    <section class="crown" class:won={r.won} aria-labelledby="crown-title">
      <CranePortrait caption={false} />
      <div class="crown-body">
        <p class="eyebrow">The Gilded Riverboat</p>
        <h2 id="crown-title">{r.won ? "You beat Augustus Crane" : "Augustus Crane beat you"}</h2>
        <p class="words">{r.words}</p>
        <ul class="consequences">
          {#each r.lines ?? [] as line, i (i)}
            <li>{line}</li>
          {/each}
        </ul>
        <button class="primary" onclick={() => game.send({ type: "crown_dismiss" })}>Back to Devil's Draw</button>
      </div>
    </section>
{/snippet}

{#snippet crownCard(terms: NonNullable<Crown["terms"]>)}
    <section class="crown" class:summoned={crown.status === "summoned"} aria-labelledby="crown-title">
      <CranePortrait caption={false} />
      <div class="crown-body">
        <p class="eyebrow">{crown.status === "summoned" ? "Summoned" : "An invitation"}</p>
        <h2 id="crown-title">Augustus Crane, the Gilded Riverboat</h2>
        <p class="arrival">{crown.arrival}</p>
        <p class="words">{crown.words}</p>
        <div class="stakes">
          <div class="stake">
            <h3>Name your stakes</h3>
            <p><strong>Win:</strong> {terms.standard.win}</p>
            <p><strong>Lose:</strong> {terms.standard.lose}</p>
            <button class="primary" onclick={() => game.send({ type: "crown_accept", level: "standard" })}
              >Sit down with Crane</button>
          </div>
          <div class="stake double">
            <h3>Double it</h3>
            <p><strong>Win:</strong> {terms.double.win}</p>
            <p><strong>Lose:</strong> {terms.double.lose}</p>
            <button class="primary risky" onclick={() => game.send({ type: "crown_accept", level: "double" })}
              >Double the stakes</button>
          </div>
        </div>
        <p class="note">
          Heads-up freezeout: {formatChips(crown.duel_stack ?? 0)} chips each, blinds rising, until one of you is
          broke. No silver to sit. You can concede between hands.
        </p>
        {#if crown.can_decline}
          <button class="decline" onclick={() => game.send({ type: "crown_decline" })}>Send him away</button>
        {:else}
          <p class="warn">A summons can't be refused. The Rusty Spur won't seat you until you've faced him, unless you pay The Dealer in full.</p>
        {/if}
      </div>
    </section>
{/snippet}

{#snippet dealerPanel()}
    <section class="panel dealer" class:overdue={eco.dealer_overdue} aria-labelledby="dealer-title">
      <h2 id="dealer-title">The Dealer's marker</h2>
      <p class="big">{formatChips(eco.dealer_owed_gold)} <span class="unit">gold owed</span></p>
      <div class="meter" role="img" aria-label={`${Math.round(paidShare * 100)}% paid`}>
        <span style:width={`${Math.max(0, Math.min(1, paidShare)) * 100}%`}></span>
      </div>
      <p class="note">{dueText}</p>
      {#if eco.dealer_owed_gold > 0}
        <form
          class="inline"
          novalidate
          onsubmit={(e) => {
            e.preventDefault();
            if (canPay) game.send({ type: "pay_dealer", gold: payGold });
          }}
        >
          <label for="pay-gold" class="sr">Gold to pay</label>
          <input id="pay-gold" type="number" min="1" max={maxPay} bind:value={payGold} disabled={maxPay === 0} />
          <button type="submit" disabled={!canPay}>Pay gold</button>
        </form>
        {#if eco.gold === 0}
          <p class="note">Pay in gold. Buy it at the assay office.</p>
        {/if}
      {/if}
    </section>
{/snippet}

{#snippet assayPanel()}
    <section class="panel assay" aria-labelledby="assay-title">
      <h2 id="assay-title">Assay office</h2>
      <p class="big">{eco.gold_rate} <span class="unit">silver per gold today</span></p>
      <p class="note">The rate follows the town ({view.status.town_state}); 5% fee each way.</p>
      <div class="lots" role="group" aria-label="Amount of gold">
        {#each eco.gold_quotes as q, i (q.gold)}
          <button class="lot" class:on={lot === i} aria-pressed={lot === i} onclick={() => (lot = i)}>{q.gold}</button>
        {/each}
      </div>
      <div class="pair">
        <button
          disabled={quote.buy_silver > silver}
          onclick={() => game.send({ type: "buy_gold", gold: quote.gold })}
        >Buy for {formatChips(quote.buy_silver)}</button>
        <button
          disabled={quote.gold > eco.gold}
          onclick={() => game.send({ type: "sell_gold", gold: quote.gold })}
        >Sell for {formatChips(quote.sell_silver)}</button>
      </div>
      <p class="note">Prices in silver for {quote.gold} gold. You can afford up to {formatChips(eco.max_gold_affordable)}.</p>
    </section>
{/snippet}

{#snippet housePanel()}
    <section class="panel house" class:overdue={eco.barred} aria-labelledby="house-title">
      <h2 id="house-title">The House Line</h2>
      {#if eco.barred}
        <p class="warn" role="status">The House called a marker. You can't take a seat until it's paid.</p>
      {/if}
      {#if eco.markers.length === 0}
        <p class="note">The barkeep will write you a marker for {formatChips(eco.marker_silver)} silver.</p>
      {:else}
        <ul class="markers">
          {#each eco.markers as m, i (m.taken_day + "-" + i)}
            <li>
              <span>
                Day {m.taken_day} marker ·
                {#if m.days_until_called <= 0}
                  <strong class="called">called</strong>
                {:else}
                  called in {m.days_until_called} day{m.days_until_called === 1 ? "" : "s"}
                {/if}
              </span>
              <button disabled={m.repay_silver > silver} onclick={() => game.send({ type: "repay", index: i })}
                >Repay {formatChips(m.repay_silver)}</button>
            </li>
          {/each}
        </ul>
      {/if}
      <button class="wide" disabled={!eco.can_borrow} onclick={() => game.send({ type: "borrow" })}
        >Borrow {formatChips(eco.marker_silver)} silver</button>
      <p class="note">
        Repay {formatChips(eco.marker_terms.early_silver)} within {eco.marker_terms.early_days} days,
        {formatChips(eco.marker_terms.late_silver)} after. Unpaid at {eco.marker_terms.called_at_days} days, the
        House calls it.
      </p>
    </section>
{/snippet}

{#snippet innPanel()}
    <section class="panel inn" aria-labelledby="inn-title">
      <h2 id="inn-title">Boarding house</h2>
      <p class="big">
        Day {eco.day}
        <span class="unit">{eco.day <= eco.season_days ? `of ${eco.season_days}` : "· past the season's end"}</span>
      </p>
      {#if eco.has_claim_deed}
        <p class="note">Your silver claim pays {formatChips(eco.claim_income_silver)} silver each morning.</p>
      {:else}
        <p class="note">Sleeping ends the day. Markers age and debts come due.</p>
      {/if}
      <button class="wide sleep" onclick={() => game.send({ type: "sleep" })}>Sleep until morning</button>
    </section>
{/snippet}

<svelte:window onkeydown={onKeyDown} onkeyup={onKeyUp} onblur={stopWalking} />

<div class="world">
  {#if crownPending}
    <button class="banner" class:summoned={crown.status === "summoned"} onclick={() => open("landing")}>
      <span aria-hidden="true">⚓</span>
      The Gilded Riverboat is docked at the landing.
      {crown.status === "summoned" ? "Crane has summoned you." : "Augustus Crane would like a game."}
    </button>
  {/if}

  <div class="hud">
    {#if view.message}
      <p class="hud-message" role="status" aria-live="polite">{view.message}</p>
    {/if}
    <div class="hud-row">
      {#if near}
        <button class="enter" onclick={() => open(near)}><kbd>E</kbd> Enter {places[near]}</button>
      {:else}
        <span class="hint"><kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd> or arrow keys to walk · <kbd>E</kbd> at a door</span>
      {/if}
      <div class="places">
        <button aria-expanded={placesOpen} onclick={() => (placesOpen = !placesOpen)}>Places</button>
        {#if placesOpen}
          <ul class="places-menu">
            {#each Object.entries(places) as [id, name] (id)}
              <li><button onclick={() => open(id)}>{name}</button></li>
            {/each}
          </ul>
        {/if}
      </div>
    </div>
    {#if world && !world.has_art}
      <p class="art-note">Stand-in shapes: the Jarppix art pack isn't installed (see assets/third_party/README.md).</p>
    {/if}
  </div>
</div>

{#if crownResult}
  <div class="overlay" role="dialog" aria-modal="true" aria-label="The match with Crane">
    <div class="sheet">{@render crownResultCard(crownResult)}</div>
  </div>
{:else if openPlace}
  <div class="overlay" role="dialog" aria-modal="true" aria-labelledby="place-title">
    <div class="sheet">
      <header class="sheet-head">
        <h2 id="place-title" class:sr={openPlace === "rusty_spur"}>{places[openPlace]}</h2>
        <button class="close" onclick={close} aria-label="Back to the street"><kbd>Esc</kbd> Back to the street</button>
      </header>
      {#if openPlace === "rusty_spur"}
        <div class="two">
          <BuyIn {view} />
          {@render housePanel()}
        </div>
      {:else if openPlace === "assay"}
        <div class="two">
          {@render assayPanel()}
          {@render dealerPanel()}
        </div>
      {:else if openPlace === "boarding"}
        <div class="one">{@render innPanel()}</div>
      {:else if crownPending && crown.terms}
        {@render crownCard(crown.terms)}
      {:else}
        <p class="quiet">The landing is quiet. The river runs brown and slow{crown.status === "won" || crown.status === "lost" ? ", and the Gilded Riverboat is long gone" : ""}.</p>
      {/if}
    </div>
  </div>
{/if}

<style>
  .world {
    position: relative;
    height: 100%;
    min-height: 60vh;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    pointer-events: none;
  }

  .world > * {
    pointer-events: auto;
  }

  .banner {
    align-self: center;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    border-radius: 999px;
    border: 1px solid #d9b45a;
    background: rgb(22 27 36 / 0.92);
    color: #e8c56a;
    font-size: var(--size-support);
    box-shadow: 0 6px 16px rgb(0 0 0 / 0.45);
  }

  .banner.summoned {
    border-color: var(--danger);
    color: #f0b48a;
  }

  .hud {
    display: grid;
    gap: 8px;
    margin-top: auto;
    padding: 12px 16px;
    border-radius: 14px;
    background: rgb(23 22 18 / 0.88);
    border: 1px solid #5a4a33;
    box-shadow: 0 8px 20px rgb(0 0 0 / 0.45);
  }

  .hud-message {
    margin: 0;
    font-size: var(--size-support);
    color: var(--paper);
  }

  .hud-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    flex-wrap: wrap;
  }

  .hint {
    font-size: 15px;
    color: var(--muted);
  }

  kbd {
    display: inline-block;
    min-width: 1.6em;
    margin: 0 2px;
    padding: 1px 6px;
    border-radius: 5px;
    border: 1px solid #6b5a3f;
    background: var(--wood);
    font: inherit;
    font-size: 13px;
    font-weight: 700;
    text-align: center;
    color: var(--parchment);
  }

  .enter {
    min-height: 44px;
    background: var(--go);
    border-color: #6f9c7e;
    font-size: var(--size-support);
  }

  .places {
    position: relative;
  }

  .places-menu {
    position: absolute;
    right: 0;
    bottom: calc(100% + 6px);
    margin: 0;
    padding: 6px;
    list-style: none;
    display: grid;
    gap: 4px;
    min-width: 220px;
    background: rgb(23 22 18 / 0.97);
    border: 1px solid #5a4a33;
    border-radius: 10px;
  }

  .places-menu button {
    width: 100%;
    text-align: left;
  }

  .art-note {
    margin: 0;
    font-size: 13px;
    color: var(--muted);
  }

  .overlay {
    position: fixed;
    inset: 0;
    z-index: 20;
    display: grid;
    place-items: start center;
    overflow-y: auto;
    padding: clamp(84px, 11vh, 120px) clamp(10px, 3vw, 32px) 24px;
    background: rgb(10 9 7 / 0.55);
  }

  .sheet {
    width: min(980px, 100%);
    display: grid;
    gap: 12px;
  }

  .sheet-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
  }

  .sheet-head .close {
    margin-left: auto;
  }

  .sheet-head h2 {
    font-size: var(--size-name);
  }

  .two {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
    gap: 14px;
    align-items: start;
  }

  .one {
    width: min(440px, 100%);
  }

  .quiet {
    margin: 0;
    padding: 18px;
    border-radius: 14px;
    background: var(--wood);
    font-size: var(--size-status);
    color: var(--muted);
  }

  .panel {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 14px 16px;
    background: linear-gradient(180deg, var(--wood-light), var(--wood));
    border: 1px solid #5a4a33;
    border-radius: 14px;
    box-shadow: 0 8px 20px rgb(0 0 0 / 0.35);
  }

  .panel.overdue {
    border-color: var(--danger);
  }

  h2 {
    margin: 0;
    font-family: var(--font-display);
    font-size: var(--size-status);
    letter-spacing: 0.03em;
    color: var(--parchment);
  }

  .big {
    margin: 0;
    font-size: var(--size-amount);
    font-weight: 700;
  }

  .unit {
    font-size: var(--size-support);
    font-weight: 400;
    color: var(--muted);
  }

  .note {
    margin: 0;
    font-size: 15px;
    color: var(--muted);
  }

  .warn {
    margin: 0;
    font-size: var(--size-support);
    font-weight: 700;
    color: #f0b48a;
  }

  .meter {
    height: 8px;
    border-radius: 4px;
    background: rgb(0 0 0 / 0.35);
    overflow: hidden;
  }

  .meter span {
    display: block;
    height: 100%;
    background: var(--brass);
  }

  button {
    min-height: 40px;
    padding: 0 12px;
    border-radius: 8px;
    border: 1px solid #6b5a3f;
    background: var(--wood-light);
    font-size: var(--size-support);
    font-weight: 600;
  }

  button:disabled {
    opacity: 0.45;
  }

  .wide {
    width: 100%;
  }

  .sleep {
    margin-top: auto;
    background: #2f3b4a;
    border-color: #55687f;
  }

  .inline {
    display: flex;
    gap: 8px;
  }

  .inline input {
    width: 7ch;
    padding: 6px 10px;
    font: inherit;
    font-weight: 700;
    color: var(--paper);
    background: var(--ink);
    border: 1px solid var(--brass);
    border-radius: 8px;
  }

  .inline button {
    flex: 1;
  }

  .lots {
    display: flex;
    gap: 6px;
  }

  .lot {
    flex: 1;
    min-height: 36px;
    padding: 0;
  }

  .lot.on {
    border-color: var(--parchment);
    background: #4a3f2e;
    color: var(--parchment);
  }

  .pair {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 6px;
  }

  .markers {
    margin: 0;
    padding: 0;
    list-style: none;
    display: grid;
    gap: 6px;
  }

  .markers li {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    font-size: 15px;
  }

  .called {
    color: #f0b48a;
  }

  .sr {
    position: absolute;
    width: 1px;
    height: 1px;
    overflow: hidden;
    clip: rect(0 0 0 0);
  }

  .crown {
    grid-column: 1 / -1;
    display: grid;
    grid-template-columns: auto minmax(0, 1fr);
    gap: 18px;
    align-items: start;
    padding: 18px 20px;
    background: linear-gradient(180deg, #232b38, #161b24);
    border: 1px solid #d9b45a;
    border-radius: 16px;
    box-shadow: 0 12px 30px rgb(0 0 0 / 0.5);
  }

  .crown.summoned {
    border-color: var(--danger);
  }

  .crown.won {
    border-color: #6f9c7e;
  }

  .crown-body {
    display: grid;
    gap: 10px;
  }

  .eyebrow {
    margin: 0;
    font-size: 14px;
    text-transform: uppercase;
    letter-spacing: 0.18em;
    color: #e8c56a;
  }

  .crown h2 {
    font-size: var(--size-name);
  }

  .arrival {
    margin: 0;
    font-size: var(--size-support);
    color: var(--muted);
  }

  .words {
    margin: 0;
    font-size: var(--size-status);
    font-style: italic;
    color: var(--paper);
  }

  .stakes {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .stake {
    display: grid;
    gap: 6px;
    align-content: start;
    padding: 12px 14px;
    border-radius: 12px;
    border: 1px solid #3d4a5c;
    background: rgb(0 0 0 / 0.25);
  }

  .stake.double {
    border-color: #7c4a3a;
  }

  .stake h3 {
    margin: 0;
    font-size: var(--size-support);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--parchment);
  }

  .stake p {
    margin: 0;
    font-size: 15px;
    color: var(--muted);
  }

  .stake strong {
    color: var(--paper);
  }

  .primary {
    min-height: 46px;
    margin-top: 4px;
    background: var(--go);
    border-color: #6f9c7e;
    font-size: var(--size-support);
  }

  .primary.risky {
    background: #6a3a2a;
    border-color: var(--danger);
  }

  .decline {
    justify-self: start;
    background: none;
    border: none;
    padding: 0;
    min-height: 0;
    text-decoration: underline;
    color: var(--parchment);
  }

  .consequences {
    margin: 0;
    padding-left: 1.2em;
    display: grid;
    gap: 4px;
    font-size: var(--size-support);
  }

  .crown-body > .primary {
    justify-self: start;
    min-width: 240px;
  }

  @media (max-width: 760px) {
    .two {
      grid-template-columns: 1fr;
    }
  }

  @media (max-width: 560px) {
    .stakes {
      grid-template-columns: 1fr;
    }

    .crown {
      grid-template-columns: 1fr;
    }
  }
</style>
