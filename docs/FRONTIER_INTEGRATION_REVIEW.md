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

This preserves the Godot poker engine, which already owns Texas Hold'em rules,
legal actions, side pots, viewer-safe snapshots, and multi-hand session state.
Do not bring over Frontier's second poker engine or make two engines share
authority over a hand.

## What exists today

| Area | Maverick | Frontier |
|---|---|---|
| Runtime | Godot 4, GDScript, scenes | TypeScript modules with Svelte/Vite UI and CLI harness |
| Poker | Reusable `addons/poker_engine/`; headless suite has 413 checks; a playable heads-up table consumes `PokerGameState` | Separate TypeScript rules engine, evaluator/pots, CLI/autoplay harness, and Svelte table components |
| AI | Equity-based Hold'em AI and strategy; basic tell system remains a stub | Psychology data model plus a very simple decision function |
| World | Early scenes and character scaffolding; currently centered on Devil's Draw / Split River Valley | Static region example and a small town-state transition function |
| Economy | Not implemented yet; original design treats poker chips as bankroll/currency/story stakes | Minimal ledger, debt thresholds, and property catalog functions |
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

- Back up/version Frontier before major edits. At review time, `~/Dev/Frontier`
  did not have a Git repository, so there is no local commit history to rely on.
- Decide the canonical product name, territory, and map. Maverick currently
  names Devil's Draw, Split River Valley, and The Dealer; Frontier names Dust &
  Decisions, New Canaan, and the Five Crowns. These can fit together, but the
  hierarchy and canonical names need to be explicit.
- One possible hierarchy is New Canaan as the territory, Split River Valley as
  a region, Devil's Draw as the hub town, the Rusty Spur as its saloon, and the
  Five Crowns as the long-term circuit around The Dealer. Treat this as a
  proposal for review, not settled canon.
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

- Decide how poker chips relate to spendable currency and long-term assets.
  The GDD currently makes chips bankroll/currency/reputation, while Frontier
  separates silver, gold, credit, and debt. Avoid making table stacks, wallet
  cash, property value, and reputation interchangeable by accident.
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
3. **Money model conflict.** Decide chips-to-cash conversion, whether poker
   losses create debt, how debts accrue, and how property purchases affect
   gameplay. Otherwise balances will drift across table and world systems.
4. **2D versus 3D.** Maverick's GDD and current `CharacterBody2D` scenes describe
   a top-down pixel-art game; the combined roadmap calls Godot a 3D world. Pick
   a presentation direction before making world scenes or acquiring assets.
   The current 2D foundation can support the world-state design, but a 3D
   conversion is a separate production and technical decision.
5. **Setting and content scope.** New Canaan/Five Crowns and Devil's Draw/Split
   River Valley need one canonical hierarchy. Five regional arcs, several
   currencies, properties, weather, cheating, variants, and procedural content
   are too much to build before one cohesive town slice works.
6. **Overuse of global state.** Turning every domain concept into a Godot
   autoload makes tests, save/load, and multiple runs harder. Prefer explicit
   world/session state passed to systems; reserve autoloads for a few true
   coordinators.
7. **UI is not portable source code.** Frontier's Svelte components are useful
   interaction references, but should be recreated as Godot scenes/components
   using Maverick's living design system, not copied or embedded into runtime.
8. **History and generated files.** Frontier currently includes `dist/` and
   `node_modules/` alongside TypeScript sources and has no Git repository.
   Preserve the source and tests; do not migrate dependencies or generated
   build output into Maverick.

## Decision

Proceed with the combined vision, but do not start by porting every Frontier
module into autoloads. First preserve Frontier, settle naming/canon, then prove
one small Devil's Draw slice with a saloon, an NPC rival, and poker-backed
consequences. Port each useful rule into GDScript behind Maverick-owned APIs and
test it there.
