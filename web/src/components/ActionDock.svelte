<script lang="ts">
  // Shows only what Godot reports as legal; Godot re-validates every action.
  import { Action, type ActionId, type ActionOption } from "../lib/protocol";
  import { formatChips } from "../lib/cards";

  let {
    options,
    pot,
    commitment,
    enabled,
    waiting,
    onAct,
  }: {
    options: ActionOption[];
    pot: number;
    commitment: number;
    enabled: boolean;
    waiting: string;
    onAct: (action: ActionId, amount: number) => void;
  } = $props();

  const find = (id: ActionId) => options.find((o) => o.action === id);
  const fold = $derived(find(Action.FOLD));
  const passive = $derived(find(Action.CHECK) ?? find(Action.CALL));
  const wager = $derived(find(Action.BET) ?? find(Action.RAISE));
  const callAmount = $derived(find(Action.CALL)?.amount ?? 0);
  const min = $derived(wager?.min_amount ?? 0);
  const max = $derived(Math.max(min, wager?.max_amount ?? 0));

  let target = $state(0);
  $effect(() => {
    // Reset to the minimum legal wager whenever the legal range changes.
    target = min;
  });

  function preset(fraction: number): number {
    const base = wager?.action === Action.RAISE ? commitment + callAmount : 0;
    const potAfterCall = pot + callAmount;
    return Math.min(max, Math.max(min, Math.round(base + potAfterCall * fraction)));
  }

  const presets = $derived(
    wager
      ? [
          { label: "Min", value: min },
          { label: "½ pot", value: preset(0.5) },
          { label: "Pot", value: preset(1) },
          { label: "All-in", value: max },
        ]
      : [],
  );
  const wagerVerb = $derived(wager?.action === Action.RAISE ? "Raise to" : "Bet");
  const isAllIn = $derived(wager !== undefined && target >= max);
</script>

<section class="dock" class:disabled={!enabled} aria-label="Your actions">
  {#if !enabled}
    <p class="waiting" role="status">{waiting}</p>
  {:else}
    {#if wager}
      <div class="wager">
        <div class="presets" role="group" aria-label="Wager presets">
          {#each presets as p}
            <button class="preset" class:on={target === p.value} onclick={() => (target = p.value)}>
              {p.label}
            </button>
          {/each}
        </div>
        <label class="slider">
          <span class="bound">{formatChips(min)}</span>
          <span class="sr">Wager amount</span>
          <input type="range" {min} {max} step="1" bind:value={target} />
          <span class="bound">{formatChips(max)}</span>
        </label>
      </div>
    {/if}

    <div class="buttons">
      {#if fold}
        <button class="act fold" onclick={() => onAct(Action.FOLD, 0)}>Fold</button>
      {/if}
      {#if passive}
        <button class="act passive" onclick={() => onAct(passive.action, 0)}>
          {#if passive.action === Action.CALL}
            Call <strong>{formatChips(callAmount)}</strong>
          {:else}
            Check
          {/if}
        </button>
      {/if}
      {#if wager}
        <button class="act aggressive" onclick={() => onAct(wager.action, target)}>
          {isAllIn ? "All-in" : wagerVerb} <strong>{formatChips(target)}</strong>
        </button>
      {/if}
    </div>
  {/if}
</section>

<style>
  .dock {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 12px 18px;
    background: var(--wood);
    border: 1px solid #5a4a33;
    border-radius: 14px;
    min-height: 88px;
    justify-content: center;
  }

  .waiting {
    margin: 0;
    text-align: center;
    font-size: var(--size-status);
    color: var(--muted);
  }

  .wager {
    display: flex;
    align-items: center;
    gap: 16px;
    flex-wrap: wrap;
  }

  .presets {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }

  .preset {
    min-height: 40px;
    padding: 0 14px;
    border-radius: 8px;
    border: 1px solid #6b5a3f;
    background: var(--wood-light);
    font-size: var(--size-support);
    font-weight: 600;
  }

  .preset.on {
    border-color: var(--parchment);
    background: #4a3f2e;
    color: var(--parchment);
  }

  .slider {
    flex: 1 1 260px;
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .slider input {
    flex: 1;
    accent-color: var(--brass);
    height: 28px;
  }

  .bound {
    font-size: 14px;
    color: var(--muted);
  }

  .buttons {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    gap: 10px;
  }

  .act {
    min-height: 52px;
    border-radius: 10px;
    border: 1px solid transparent;
    font-size: var(--size-action);
    font-weight: 600;
    transition:
      filter 120ms,
      transform 80ms;
  }

  .act:hover {
    filter: brightness(1.12);
  }

  .act:active {
    transform: translateY(1px);
  }

  .act strong {
    font-weight: 800;
  }

  .fold {
    background: #5b2a22;
    border-color: var(--danger);
  }

  .passive {
    background: var(--go);
    border-color: #6f9c7e;
  }

  .aggressive {
    background: #6a5330;
    border-color: var(--brass);
    color: var(--paper);
  }

  .sr {
    position: absolute;
    width: 1px;
    height: 1px;
    overflow: hidden;
    clip: rect(0 0 0 0);
  }

  @media (max-width: 640px) {
    .dock {
      padding: 10px;
    }

    .buttons {
      grid-template-columns: 1fr 1fr;
    }

    .aggressive {
      grid-column: 1 / -1;
    }
  }
</style>
