<script lang="ts">
  import Seat from "./Seat.svelte";
  import Card from "./Card.svelte";
  import ChipStack from "./ChipStack.svelte";
  import ActionDock from "./ActionDock.svelte";
  import { game } from "../lib/bridge.svelte";
  import { formatChips } from "../lib/cards";
  import type { Snapshot, TableState } from "../lib/protocol";

  let { view }: { view: TableState & { snapshot: Snapshot } } = $props();

  const PLAYER = 0;
  const RIVAL = 1;
  const STAGE_LABEL: Record<string, string> = {
    preflop: "Preflop",
    flop: "Flop",
    turn: "Turn",
    river: "River",
    showdown: "Showdown",
  };

  const snap = $derived(view.snapshot);
  const status = $derived(view.status);
  const phase = $derived(view.phase);
  const live = $derived(phase === "");
  const actor = $derived(live ? snap.current_actor : -1);
  const playerTurn = $derived(actor === PLAYER && snap.available_actions.length > 0);
  const handOver = $derived(phase === "hand_over");
  const boardSlots = $derived(Array.from({ length: 5 }, (_, i) => snap.board[i] ?? ""));

  // Heads-up: the button posts the small blind.
  const role = (seat: number) => (seat === snap.button ? "Dealer · small blind" : "Big blind");

  const waiting = $derived.by(() => {
    if (phase === "reveal_cards") return "Look over your cards…";
    if (phase === "settling") return "Settling the pot…";
    if (actor === RIVAL) return "The drifter is deciding.";
    return "Waiting for the dealer…";
  });
</script>

<div class="table">
  <div class="opponent">
    <Seat
      seat={snap.seats[RIVAL]}
      name="The Drifter"
      role={role(RIVAL)}
      acting={actor === RIVAL}
      kempt={status.rival_kempt}
      timing={status.rival_timing}
      showCommit={live}
    />
  </div>

  <div class="felt" aria-label="Table">
    <div class="street">
      <span>Hand {snap.hand_number}</span>
      <span class="dot">·</span>
      <span>{STAGE_LABEL[snap.stage] ?? snap.stage}</span>
      <span class="dot">·</span>
      <span>Blinds 10 / 20</span>
    </div>
    <div class="board" aria-label="Community cards">
      {#each boardSlots as code, i (i)}
        <Card {code} />
      {/each}
    </div>
    {#if status.deed.wager_active}
      <div class="deed-stake" role="status">
        <span class="deed-icon" aria-hidden="true">📜</span>
        The drifter's claim deed rides on this hand, against your {formatChips(status.deed.stake_silver)} silver.
      </div>
    {/if}
    {#if snap.pot > 0}
      <div class="pot" aria-live="polite">
        <ChipStack amount={snap.pot} />
        <span class="pot-label">Pot</span>
        <span class="pot-amount">{formatChips(snap.pot)}</span>
      </div>
    {/if}
    <p class="message" role="status" aria-live="polite">{view.message}</p>
  </div>

  <div class="player">
    <Seat seat={snap.seats[PLAYER]} name="You" role={role(PLAYER)} isPlayer acting={playerTurn} showCommit={live} />
  </div>

  <div class="controls">
    {#if handOver && status.deed.offer_pending}
      <section class="offer" aria-labelledby="offer-title">
        <div class="offer-text">
          <h2 id="offer-title"><span aria-hidden="true">📜</span> The drifter stakes his claim</h2>
          <p>
            His silver claim in Split River (worth about {formatChips(status.deed.value_gold)} gold, pays
            {formatChips(status.deed.income_silver)} silver a day) against
            <strong>{formatChips(status.deed.stake_silver)} of your silver</strong>. Whoever wins the next pot takes
            both; a split returns them.
          </p>
        </div>
        <div class="offer-buttons">
          <button class="next" disabled={!status.deed.can_afford} onclick={() => game.send({ type: "deed_accept" })}
            >Take the bet</button>
          <button class="leave" onclick={() => game.send({ type: "deed_decline" })}>Turn him down</button>
        </div>
      </section>
    {:else if handOver}
      <div class="between">
        <button class="next" onclick={() => game.send({ type: "next_hand" })}>Deal next hand</button>
        <button class="leave" onclick={() => game.send({ type: "leave" })}>Cash out &amp; leave</button>
      </div>
    {:else}
      <ActionDock
        options={playerTurn ? snap.available_actions : []}
        pot={snap.pot}
        commitment={snap.seats[PLAYER].street_commitment}
        enabled={playerTurn}
        {waiting}
        onAct={(action, amount) => game.send({ type: "action", action, amount })}
      />
    {/if}
  </div>

</div>

<style>
  .table {
    display: grid;
    grid-template-rows: auto minmax(min-content, 1fr) auto auto;
    gap: clamp(6px, 1.4vh, 14px);
    width: min(1100px, 100%);
    height: 100%;
    margin: 0 auto;
    min-height: 0;
  }

  .felt {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: clamp(6px, 1.4vh, 14px);
    padding: clamp(8px, 2vh, 28px) 16px;
    border-radius: 120px / 60px;
    background: radial-gradient(ellipse at 50% 40%, var(--felt-light), var(--felt) 70%);
    border: 10px solid #4a3522;
    box-shadow:
      inset 0 0 0 2px rgb(189 150 85 / 0.5),
      inset 0 0 40px rgb(0 0 0 / 0.45),
      0 12px 30px rgb(0 0 0 / 0.5);
    min-height: 0;
  }

  .street {
    font-size: var(--size-support);
    color: var(--parchment);
    letter-spacing: 0.06em;
    text-transform: uppercase;
    opacity: 0.85;
  }

  .dot {
    margin: 0 6px;
    opacity: 0.6;
  }

  .board {
    display: flex;
    gap: clamp(6px, 1vw, 12px);
    flex-wrap: nowrap;
  }

  .pot {
    display: flex;
    align-items: flex-end;
    gap: 10px;
  }

  .pot-label {
    font-size: var(--size-support);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--parchment);
    padding-bottom: 3px;
  }

  .pot-amount {
    font-size: var(--size-amount);
    font-weight: 800;
  }

  .message {
    margin: 0;
    max-width: 44rem;
    text-align: center;
    font-size: var(--size-status);
    line-height: 1.35;
    color: var(--paper);
    min-height: 1.35em;
  }

  .controls {
    position: sticky;
    bottom: 0;
    z-index: 3;
    box-shadow: 0 -10px 18px var(--ink);
    border-radius: 14px;
  }

  .between {
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: 10px;
  }

  .between button {
    min-height: 60px;
    border-radius: 10px;
    font-size: var(--size-action);
    font-weight: 700;
  }

  .next {
    background: var(--go);
    border: 1px solid #6f9c7e;
  }

  .leave {
    background: var(--wood-light);
    border: 1px solid #6b5a3f;
  }

  @media (max-height: 720px) {
    .felt {
      border-width: 6px;
      gap: 4px;
    }

    .street {
      font-size: 14px;
    }
  }

  @media (max-width: 640px) {
    .felt {
      border-radius: 28px;
      border-width: 6px;
      min-height: 0;
    }

    .board {
      gap: 4px;
    }

    .between {
      grid-template-columns: 1fr;
    }

    .controls {
      position: sticky;
      bottom: 0;
    }
  }

  .deed-stake {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 14px;
    border-radius: 999px;
    background: rgb(0 0 0 / 0.3);
    border: 1px solid var(--brass);
    font-size: var(--size-support);
    color: var(--parchment);
  }

  .offer {
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    align-items: center;
    gap: 12px 20px;
    padding: 12px 18px;
    background: linear-gradient(180deg, #3e3221, var(--wood));
    border: 1px solid var(--brass);
    border-radius: 14px;
  }

  .offer h2 {
    margin: 0 0 4px;
    font-family: var(--font-display);
    font-size: var(--size-status);
    color: var(--parchment);
  }

  .offer p {
    margin: 0;
    font-size: 15px;
    color: var(--muted);
  }

  .offer p strong {
    color: var(--paper);
  }

  .offer-buttons {
    display: grid;
    gap: 8px;
    min-width: 200px;
  }

  .offer-buttons button {
    min-height: 44px;
  }

  @media (max-width: 640px) {
    .offer {
      grid-template-columns: 1fr;
    }
  }
</style>
