# Maverick + Frontier Integration Review

**Reviewed:** 2026-11-02  
**Scope:** Compare Maverick's Godot project with the sibling `~/Dev/Frontier`
TypeScript/Svelte project and assess its combined roadmap.

## Recommendation

Combining the projects' direction is a good idea and is technically doable.
Treat it as **design consolidation and selective system translation**, not a
source-code merge. Maverick should remain the playable Godot game and the sole
runtime for shipping features. Frontier should remain a reference/archive for
design, prototypes, and useful interaction ideas until a design is deliberately
adapted into Maverick's architecture.

**Status update:** Frontier has since been initialized as a local Git
repository and committed at `adfa16d` (protected snapshot) and `b6c8af8`
(salvage map). Its worktree is clean and no source has been moved or deleted.
There is no remote configured yet, so this is local history rather than an
off-device backup. `~/Dev/Frontier/SALVAGE_MAP.md` is a useful file inventory;
its suggested port order is not the approved product roadmap. The active
execution sequence lives in Maverick's `docs/PROJECT_ROADMAP.md`.

This preserves the Godot poker engine, which already owns Texas Hold'em rules,
legal actions, side pots, viewer-safe snapshots, and multi-hand session state.
Do not bring over Frontier's second poker engine or make two engines share
authority over a hand.

## What exists today

| Area | Maverick | Frontier |
|---|---|---|
| Runtime | Godot 4, GDScript, scenes | TypeScript modules with Svelte/Vite UI and CLI harness |
| Poker | Reusable `addons/poker_engine/`; live table uses `PokerSession` for multi-hand play; 519 checks currently pass | Separate TypeScript rules engine, evaluator/pots, CLI/autoplay harness, and Svelte table components |
| AI | Equity-based Hold'em AI and strategy; basic tell system remains a stub | Psychology data model plus a very simple decision function |
| World | Early scenes and character scaffolding; currently centered on Devil's Draw / Split River Valley | Static region example and a small town-state transition function |
| Economy | Not implemented yet; table bankroll is now distinguished from wallet/debt | Minimal ledger, debt thresholds, and property catalog functions |
| Direction | Texas Hold'em Frontier GDD and living UI design guide | `Agent.md` proposes Dust & Decisions, New Canaan, five Crown venues, empire building, debt, memory, cheating, variants, and procedural modes |

Frontier's `AgentProgress.md` reports initial tests and scaffolding. Its world
and economy modules are useful design prototypes, but they are not yet complete
runtime systems. For example, `buyProperty()` creates a property record without
checking or debiting a ledger, and town transitions receive aggregate pressure
values without a world simulation that produces them.

## Roadmap assessment

The phase order is broadly sensible: make poker playable, then establish world
state and economy, then build persistent NPC behavior and authored progression.
The current roadmap should be narrowed around a vertical slice. One town, one
saloon, one rival, one property/debt consequence, and one short Crown arc are
enough to prove whether the systems reinforce poker as the social core.

Phase 1 is already partly complete: the rules engine, settlement/side pots,
button rotation wrapper, and human-versus-AI heads-up loop exist in Maverick.
The current table scene uses `PokerGameState` directly; `PokerSession` exists
separately and has focused tests. Generalizing the screen to multiple AI seats
would require adapting the AI to the session's stable-seat API and replacing
hard-coded two-seat presentation. It is a follow-up, not a prerequisite for the
first world slice.

## Recommended integration sequence

### 0. Protect and reconcile the source material

- Frontier now has a local Git snapshot and salvage map, but still has no
  remote backup. Add one if it should be protected off-device.
- The owner approved the first-slice 2D presentation and this setting hierarchy:
  New Canaan territory → Split River Valley region → Devil's Draw hub → Rusty
  Spur saloon; Five Crowns are the long-term circuit and The Dealer is the
  long-arc antagonist. Product title remains undecided.
- Keep both original design documents. Add a short canon map instead of
  silently overwriting either project's voice or assumptions.

### 1. Finish the small playable poker slice

- Keep Maverick's Godot poker engine as the sole rules authority.
- Playtest several heads-up hands, including all-in/showdown outcomes; refine
  the UI from the playtest notes.
- When adding more seats, adapt AI actions through the public
  `PokerSession`/`apply_action()` surface and add multiway coverage.

### 2. Port one world-state slice

- Model one region and Devil's Draw as Godot data/state objects first.
- Define exactly which events change town pressure (poker volume, debt paid,
  foreclosure, public scandal), how often the state updates, and what the player
  can observe as a result.
- Use an autoload only for truly application-wide runtime services such as a
  session coordinator or save manager. Keep Region and TownState as ordinary
  data/resources/services so they remain easy to instantiate and test.

### 3. Add a coherent ledger and debt loop

- The owner approved poker chips as the active table/session bankroll, separate
  from the persistent wallet/assets, with debt only from explicit credit or
  obligations. Exact currency names, units, conversion, loan terms, and property
  valuation remain open. Avoid making table stacks, wallet cash, property value,
  and reputation interchangeable by accident.
- Add one ledger transaction boundary for wins, losses, purchases, debt
  payments, and ownership changes. Define the House Line terms and player
  consequences before adding enforcement scenes.
- Prove one property purchase and one default consequence before introducing
  the full property catalog or foreclosure/bounty ladder.

### 4. Add one memorable rival

- Start with a small subset of psychology knobs tied to observable behavior.
- Connect actual hand equity and legal action materialization to persona
  adjustments; record a few concrete events (betrayal, favor, loss) and use them
  to alter the next encounter.
- Add tells only when the player can learn their source and act on them fairly.

### 5. Expand only after the slice works

Once players can travel to the saloon, recognize the rival, play for meaningful
stakes, and see a persistent consequence, expand to Crown venues, properties,
more NPCs, and then variants/cheating/procedural circuits. The large systems in
Frontier's long-term vision are achievable as a sequence, but not as one porting
milestone.

## Main snags to resolve

1. **Different poker contracts.** Both engines have distinct state shapes,
   action representations, turn rules, and settlement APIs. Frontier's engine
   expects bet/raise targets, but its current NPC decision function can return
   `RAISE` when no bet exists and uses `minRaise` as if it were a raise-to
   target. Those actions can be rejected by its own engine. Preserve the design
   ideas, not this engine/AI implementation, when moving to Godot.
2. **Relationship weights are not signed in practice.** Frontier describes a
   signed relationship graph, but updating an existing memory clamps its
   weight with `clamp01`, erasing negative/grudge values. Resolve the data
   contract and add tests before porting memory.
3. **Currency details remain open.** The owner approved separate table bankroll
   and persistent wallet, with debt from explicit credit/obligations. Names,
   units, exchange rates, loan terms, and property valuation still need design.
4. **Content scope.** Five regional arcs, several currencies, properties,
   weather, cheating, variants, and procedural content are too much to build
   before one cohesive town slice works.
5. **Overuse of global state.** Turning every domain concept into a Godot
   autoload makes tests, save/load, and multiple runs harder. Prefer explicit
   world/session state passed to systems; reserve autoloads for a few true
   coordinators.
6. **UI is not portable source code.** *Superseded 2026-11-03:* the owner
   chose a Svelte interface around a Godot web build (see the compass).
   Frontier's Svelte components may be adapted into Maverick's web UI; its
   TypeScript rules/logic still may not.
7. **History and generated files.** Frontier now preserves its TypeScript source
   and tests in local Git and ignores `dist/` and `node_modules/`. It has no
   remote yet. Do not migrate dependencies or generated build output into
   Maverick.

## Decision

Proceed with the combined vision, but do not start by porting every Frontier
module into autoloads. The owner has settled first-slice presentation and world
hierarchy. Define the remaining economy details, then prove one small Devil's
Draw slice with a saloon, an NPC rival, and poker-backed consequences. Port each
useful rule into GDScript behind Maverick-owned APIs and test it there.

## Review of Frontier's first town-slice proposal — 2026-11-02

Frontier commit `6420dba` proposes a focused end-to-end slice: settle poker,
update wallet and town state, preserve a lasting consequence, then verify
save/load. This is a good milestone and remains entirely inside Maverick's
runtime. The proposal is **approved in direction, pending a design revision
before implementation**.

Revise these details before starting a port:

- Do not cash out after every hand. The player's chips remain in the
  `PokerSession` stack across hands while seated. Debit the wallet once when
  buying into a table; cash out the remaining stack once when leaving the
  session. Keep the exchange rate configurable until the owner decides it.
- Model wallet and town state as explicit serializable data owned by the game
  state. Use autoloads only for genuine application-wide coordination; a
  service can accept state as an argument without owning it globally.
- Pick and document one deterministic settlement-to-town rule and one visible,
  persistent consequence for this slice. Keep the town update downstream of
  the poker engine's settlement result; the bridge must not duplicate poker
  rules. Keep debt unchanged for ordinary poker outcomes.
- Keep the first slice small. Do not add loans, property, NPC memory, or
  currency design decisions to it. Save/load should preserve the selected
  wallet, town, and consequence data.

After Frontier records this revised design and Maverick's owner-facing plan is
updated, implementation can proceed in Maverick as GDScript. The current
proposal does not authorize copying Frontier code or adding TypeScript/Svelte
runtime dependencies to Maverick.

**Revision reviewed:** Frontier commit `f1180e4` addresses the requested
buy-in/cash-out boundary, explicit serializable state, and scope limits. The
town rule is deterministic and small enough for the slice: each Rusty Spur
settlement adds one poker-volume point; positive/negative/zero net player stack
change adjusts prosperity by +1/-1/0; crossing +3/-3 changes town state and
resets prosperity. The visible “known winner”/“known loser” reputation label
is an appropriate first persistent consequence because it has no gameplay
effect yet. **Approved to proceed with implementation in Maverick.**

Implementation should define net stack change from the player's stack
immediately before the hand to their settled stack after payouts, excluding
wallet deposits, buy-ins, and cash-outs. “Lifetime” reputation means cumulative
net stack change from settled Rusty Spur hands in the current save. Persist the
cumulative value (or sufficient data to derive it) and derive the label from
its sign; zero remains “unknown.” Poker volume and prosperity belong to the
Rusty Spur town state. Keep the configured exchange rate explicit and do not
select a canonical rate as part of this implementation.

## First town slice implementation review — 2026-11-02

The foundations landed in `462b2a6` and the cash-out guard in `6e2293f`. The
runtime integration now connects `PokerSession`, `EconomyBridge`, `Wallet`,
`TownState`, `TableReputation`, and `SaveSystem` through `src/poker/table.gd`.
The player-facing flow supports buy-in, multiple hands on one session stack,
one town/reputation update per settlement, exactly-once cash-out, and save/load.
Exchange rate remains an Inspector setting; the default is not a canon decision.
Ordinary poker loss does not create debt.

Validation on 2026-11-02: `godot --headless --editor --path . --quit`, default
scene headless startup, and all 12 `tests/test_*.gd` scripts completed. The
suite reports 519 passing checks. `tests/test_rusty_spur_flow.gd` exercises
buy-in → two hands → town/reputation → leave/cash-out → save/load. Godot emitted
environment-only certificate/log write warnings under this restricted run and
the flow test reported four ObjectDB instances leaked at exit; assertions all
passed. The UI's responsive geometry/effect probe passed at five target sizes.

Remaining exit work is owner validation of rendered visuals, actual audio,
control feel, and `user://` save behavior on the normal Mac app. Do not mark the
milestone done until that playthrough confirms the complete loop is legible and
usable.
