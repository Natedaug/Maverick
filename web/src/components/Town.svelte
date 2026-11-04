<script lang="ts">
  // Devil's Draw while you're away from the table: the Rusty Spur's buy-in,
  // your debts, the assay office, and the boarding house. Godot computes every
  // price and decides every rule; this screen only shows them and sends intents.
  import BuyIn from "./BuyIn.svelte";
  import { game } from "../lib/bridge.svelte";
  import { formatChips } from "../lib/cards";
  import type { TableState } from "../lib/protocol";

  let { view }: { view: TableState } = $props();

  const eco = $derived(view.status.economy);
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
      <p class="big">Day {eco.day} <span class="unit">of {eco.season_days}</span></p>
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

  @media (max-width: 1100px) {
    .town {
      grid-template-columns: minmax(0, 640px);
    }
  }

  @media (max-width: 560px) {
    .affairs {
      grid-template-columns: 1fr;
    }
  }
</style>
