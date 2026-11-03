# Project Roadmap

This is the task-level counterpart to the [Project Compass](PROJECT_COMPASS.md).
It tracks what exists, what needs to be decided, and what proves each milestone.
Reorder it when playtests or owner decisions change the plan; record why.

## Current snapshot — 2026-11-02

- **Playable poker:** one human versus one AI; Texas Hold'em hand progression,
  legal actions, showdown, side pots, stack carry-over, and button rotation work.
- **Engine confidence:** six Godot headless scripts previously passed 413 checks.
  `PokerSession` exists and is tested; the current table UI still uses
  `PokerGameState` directly and is heads-up only.
- **UI:** the owner played the first table version and called the UI basic. A
  UI specialist created `docs/UI_DESIGN_SYSTEM.md` and applied a first refinement
  pass: reusable cards, dealer/blind/turn states, contextual prices, legal wager
  range, and compact action history. Godot startup was checked after this pass;
  owner playtest and small-window layout review remain.
- **Hardware:** the project uses Godot's Compatibility renderer after Vulkan
  pipeline failures on the owner's Intel Mac.
- **World/economy:** Frontier's region, town, ledger, debt, and property modules
  have not been ported into the Godot runtime.
- **Integration decisions:** 2D/3D presentation, canon/name hierarchy, and the
  chips/currency/debt model remain open. See the compass.
- **Source safety:** the Maverick review, renderer setting, and current UI
  refinement are uncommitted at this snapshot. Frontier has no Git repository;
  back it up before editing or migrating it.

## Immediate focus

1. Preserve Frontier in Git (source, tests, and design docs; exclude
   `node_modules/` and generated `dist/`). Do not change its source during the
   consolidation review.
2. Resolve the three owner decisions in `PROJECT_COMPASS.md`: world presentation,
   names/map hierarchy, and the relationship between chips and world money.
3. Have the owner play several hands with the refined table and report what
   feels confusing or engaging. Review at a smaller laptop window before more
   decoration.
4. Once those foundations are clear, implement one small region/town state and
   define its causes and visible effects before adding more towns.

## Milestones

### 1. Reliable, playable poker table — **working; heads-up slice exists**

**Included:** reusable Hold'em engine, human-versus-AI table, showdown/side-pot
settlement, privacy-safe snapshots, multi-hand session wrapper, and a first UI
system/polish pass.

**Exit when:** the owner can play several hands on their machine (including an
all-in/showdown); outcomes, legal action prices, and private-card visibility
are clear; the owner has reviewed the refined UI. Multiway AI is not required
to start the world slice.

### 2. One changing frontier town — **not started**

Build explicit Godot state for one region and one hub town. Define the update
inputs (for example, poker volume, debt paid/defaulted, public scandal), update
cadence, save behavior, and player-visible consequences. Keep domain data and
transitions independently testable; use a small number of autoload services.

**Exit when:** a deterministic game event changes town state, saving/loading
preserves it, and the UI/world shows a consequence the player can understand.

### 3. Coherent money and one economic consequence — **design pending**

Define the wallet, table stack, ledger credit, debt, property value, and
reputation boundaries. Implement settlement from a poker hand into the ledger,
then one purchase or one default consequence.

**Exit when:** chip conservation and ledger changes are test-covered, the player
can complete one purchase or debt payment, and one outcome changes a later
choice or encounter.

### 4. One remembered rival with fair tells — **not started**

Adapt a small subset of Frontier's NPC psychology into Maverick's existing AI
consumer. Add a few explicit memory events and decay rules. Connect one learned
tell to an observable behavior and a player decision; never reveal hole cards.

Before implementation, repair the Frontier design contracts: its current AI
prototype can emit invalid raise actions, and its memory update clamps negative
weights. See the [integration review](FRONTIER_INTEGRATION_REVIEW.md).

**Exit when:** an event from one hand changes this rival's behavior/read in a
later hand, and the player can learn and act on the tell fairly.

### 5. First connected story slice — **not started**

Connect travel/arrival, the hub saloon, the rival, poker stakes, one town-state
change, one property/debt consequence, and a short Crown confrontation.

**Exit when:** the player can explain how a poker decision changed a character
relationship and the town's state, and can continue play after either a win or
a loss.

### 6. Broader content — **deferred**

More regions/Crowns, expanded property tiers, weather, variants, cheating,
procedural tournaments/rumors, and multiplayer follow only after the first
connected slice is fun and its systems survive repeated play.

## Update protocol for agents

- Keep status words consistent: **not started**, **working**, **blocked on
  owner decision**, or **done**. Never mark a phase done because code merely
  compiles; use its exit conditions.
- Before adding a task, say which milestone it advances and what it depends on.
- At handoff, update the current snapshot, completed item, evidence (playtest,
  test command/result, or user feedback), and next smallest useful action.
- When the owner changes direction, update the Compass decision table and
  reorder milestones rather than leaving conflicting plans in different docs.
- Keep historical details in specialist worklogs; link them here instead of
  copying all implementation history into this roadmap.
