<script lang="ts">
  // Devil's Draw while you're away from the table: the Rusty Spur's buy-in,
  // your debts, the assay office, and the boarding house. Godot computes every
  // price and decides every rule; this screen only shows them and sends intents.
  import BuyIn from "./BuyIn.svelte";
  import CranePortrait from "./CranePortrait.svelte";
  import { game } from "../lib/bridge.svelte";
  import { formatChips } from "../lib/cards";
  import type { TableState } from "../lib/protocol";

  let { view }: { view: TableState } = $props();

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

<div class="town">
  {#if crownResult}
    <section class="crown" class:won={crownResult.won} aria-labelledby="crown-title">
      <CranePortrait caption={false} />
      <div class="crown-body">
        <p class="eyebrow">The Gilded Riverboat</p>
        <h2 id="crown-title">{crownResult.won ? "You beat Augustus Crane" : "Augustus Crane beat you"}</h2>
        <p class="words">{crownResult.words}</p>
        <ul class="consequences">
          {#each crownResult.lines ?? [] as line, i (i)}
            <li>{line}</li>
          {/each}
        </ul>
        <button class="primary" onclick={() => game.send({ type: "crown_dismiss" })}>Back to Devil's Draw</button>
      </div>
    </section>
  {:else if crownPending && crown.terms}
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
            <p><strong>Win:</strong> {crown.terms.standard.win}</p>
            <p><strong>Lose:</strong> {crown.terms.standard.lose}</p>
            <button class="primary" onclick={() => game.send({ type: "crown_accept", level: "standard" })}
              >Sit down with Crane</button>
          </div>
          <div class="stake double">
            <h3>Double it</h3>
            <p><strong>Win:</strong> {crown.terms.double.win}</p>
            <p><strong>Lose:</strong> {crown.terms.double.lose}</p>
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
  {/if}

  <BuyIn {view} />

  <div class="affairs">
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
  </div>
</div>

<style>
  .town {
    display: grid;
    grid-template-columns: minmax(300px, 440px) minmax(0, 760px);
    justify-content: center;
    align-items: start;
    gap: clamp(12px, 2vw, 24px);
  }

  .affairs {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: clamp(10px, 1.4vw, 16px);
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

  @media (max-width: 1100px) {
    .town {
      grid-template-columns: minmax(0, 640px);
    }
  }

  @media (max-width: 560px) {
    .affairs,
    .stakes {
      grid-template-columns: 1fr;
    }

    .crown {
      grid-template-columns: 1fr;
    }
  }
</style>
