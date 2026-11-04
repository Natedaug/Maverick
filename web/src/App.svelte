<script lang="ts">
  import GodotHost from "./components/GodotHost.svelte";
  import Town from "./components/Town.svelte";
  import Table from "./components/Table.svelte";
  import { game } from "./lib/bridge.svelte";
  import { formatChips } from "./lib/cards";
  import { isSeated, type TableState } from "./lib/protocol";
  import { settings } from "./lib/settings.svelte";
  import { cuesFor } from "./lib/cues";
  import { play, unlockAudio } from "./lib/sound";

  let bootError = $state("");
  let openPanel = $state<"" | "history" | "settings">("");
  const view = $derived(game.state);

  // Table sounds follow confirmed state changes from Godot.
  let previous: TableState | null = null;
  $effect(() => {
    const next = view;
    if (!next) return;
    for (const cue of cuesFor(previous, next, settings.reducedMotion)) play(cue.kind, cue.delayMs);
    previous = next;
  });

  const toggle = (panel: "history" | "settings") => (openPanel = openPanel === panel ? "" : panel);
</script>

<svelte:window
  onpointerdown={unlockAudio}
  onkeydown={(e) => {
    unlockAudio();
    if (e.key === "Escape") openPanel = "";
  }}
/>

<GodotHost onError={(m) => (bootError = m)} />

<div class="shell">
  <header>
    <div class="title">
      {#if view?.status.table?.mode !== "duel"}
        <span class="town">Devil's Draw</span>
        <span class="sep" aria-hidden="true">·</span>
      {/if}
      <span class="venue">{view?.status.table?.venue ?? "The Rusty Spur"}</span>
    </div>
    {#if view}
      <dl class="ledger">
        <div><dt>Silver</dt><dd>{formatChips(view.status.wallet_balance)}</dd></div>
        <div><dt>Gold</dt><dd>{formatChips(view.status.economy.gold)}</dd></div>
        <div><dt>Day</dt><dd>
            {view.status.economy.day}{#if view.status.economy.day <= view.status.economy.season_days}<span class="of"
                >{" / "}{view.status.economy.season_days}</span
              >{/if}
          </dd></div>
        <div><dt>Town</dt><dd>{view.status.town_state}</dd></div>
      </dl>
      <div class="menu">
        <button onclick={() => game.send({ type: "save" })}>Save</button>
        <button onclick={() => game.send({ type: "load" })}>Load</button>
        <button aria-expanded={openPanel === "history"} onclick={() => toggle("history")}>History</button>
        <button
          class="icon"
          aria-label="Settings"
          title="Settings"
          aria-expanded={openPanel === "settings"}
          onclick={() => toggle("settings")}><span aria-hidden="true">⚙</span></button>
      </div>
      {#if openPanel === "settings"}
        <section class="popover settings" aria-label="Settings">
          <label class="row">
            <span>Sound</span>
            <input type="checkbox" role="switch" bind:checked={settings.soundOn} />
          </label>
          <label class="row" class:off={!settings.soundOn}>
            <span>Volume</span>
            <input type="range" min="0" max="1" step="0.05" bind:value={settings.volume} disabled={!settings.soundOn} />
          </label>
          <label class="row">
            <span>Reduced motion</span>
            <input type="checkbox" role="switch" bind:checked={settings.reducedMotion} />
          </label>
          <p class="hint">Sound never carries information you can't also see on the table.</p>
        </section>
      {/if}
      {#if openPanel === "history"}
        <section class="popover history" aria-label="Hand history">
          {#if view.history.length === 0}
            <p>No hands played yet.</p>
          {:else}
            <ol>
              {#each view.history.slice().reverse() as line, i (i)}
                <li>{line}</li>
              {/each}
            </ol>
          {/if}
        </section>
      {/if}
    {/if}
  </header>

  <main>
    {#if bootError}
      <p class="notice error" role="alert">{bootError}</p>
    {:else if !view}
      <p class="notice" role="status">Riding into Devil's Draw…</p>
    {:else if isSeated(view)}
      <Table {view} />
    {:else}
      <Town {view} />
    {/if}
  </main>
</div>

<style>
  .shell {
    position: relative;
    z-index: 1;
    height: 100%;
    display: grid;
    grid-template-rows: auto minmax(0, 1fr);
    background:
      radial-gradient(ellipse at 50% -10%, rgb(240 215 161 / 0.12), transparent 55%),
      linear-gradient(180deg, #1d1a14, var(--ink));
  }

  header {
    position: relative;
    display: flex;
    align-items: center;
    gap: 16px 28px;
    flex-wrap: wrap;
    padding: clamp(8px, 1.4vh, 14px) clamp(14px, 3vw, 32px);
    border-bottom: 1px solid #3d3324;
  }

  .title {
    font-family: var(--font-display);
    font-size: var(--size-title);
    color: var(--parchment);
    letter-spacing: 0.03em;
    margin-right: auto;
  }

  .sep {
    margin: 0 10px;
    color: var(--brass);
  }

  .venue {
    color: var(--paper);
  }

  .ledger {
    display: flex;
    gap: 22px;
    margin: 0;
  }

  .ledger div {
    display: flex;
    flex-direction: column;
  }

  dt {
    font-size: 13px;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--muted);
  }

  dd {
    margin: 0;
    font-size: var(--size-status);
    font-weight: 700;
    text-transform: capitalize;
  }

  .of {
    font-weight: 400;
    color: var(--muted);
  }

  .menu {
    display: flex;
    gap: 8px;
  }

  .menu button {
    min-height: 40px;
    padding: 0 16px;
    border-radius: 8px;
    border: 1px solid #6b5a3f;
    background: var(--wood);
    font-size: var(--size-support);
  }

  .popover {
    position: absolute;
    top: calc(100% + 6px);
    right: clamp(10px, 3vw, 32px);
    z-index: 10;
    width: min(400px, calc(100vw - 20px));
    max-height: 50vh;
    overflow-y: auto;
    padding: 10px 16px;
    background: rgb(23 22 18 / 0.97);
    border: 1px solid #5a4a33;
    border-radius: 10px;
    box-shadow: 0 12px 30px rgb(0 0 0 / 0.6);
    font-size: var(--size-support);
    color: var(--muted);
  }

  .settings {
    display: grid;
    gap: 12px;
    width: min(320px, calc(100vw - 20px));
    padding: 14px 16px;
    color: var(--paper);
  }

  .row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    min-height: 36px;
  }

  .row.off {
    opacity: 0.5;
  }

  .row input[type="checkbox"] {
    width: 22px;
    height: 22px;
    accent-color: var(--brass);
  }

  .row input[type="range"] {
    flex: 0 1 170px;
    accent-color: var(--brass);
  }

  .hint {
    margin: 0;
    font-size: 14px;
    color: var(--muted);
  }

  .menu .icon {
    padding: 0 12px;
    font-size: 20px;
    line-height: 1;
  }

  .history ol {
    margin: 0;
    padding-left: 1.2em;
  }

  .history li {
    padding: 3px 0;
  }

  main {
    padding: clamp(8px, 1.4vh, 20px) clamp(10px, 3vw, 32px) clamp(8px, 1.4vh, 16px);
    min-height: 0;
    overflow-y: auto;
  }

  .notice {
    margin: 20vh auto 0;
    text-align: center;
    font-size: var(--size-status);
    color: var(--muted);
  }

  .notice.error {
    color: #f0b48a;
  }

  @media (max-width: 1200px) and (min-width: 641px) {
    .town,
    .sep {
      display: none;
    }
  }

  @media (max-width: 900px) and (min-width: 641px) {
    header {
      gap: 12px 18px;
    }

    .ledger {
      gap: 14px;
    }

    .menu button {
      padding: 0 12px;
    }
  }

  @media (max-width: 640px) {
    .shell {
      height: auto;
      min-height: 100%;
    }

    /* Let the page scroll so the action dock can pin to the screen bottom. */
    main {
      overflow: visible;
    }

    .title {
      width: 100%;
    }

    .ledger {
      gap: 14px;
    }
  }
</style>
