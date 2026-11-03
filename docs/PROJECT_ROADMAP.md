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
- **Integration decisions:** the owner approved 2D for the first slice, the
  New Canaan → Split River Valley → Devil's Draw hierarchy, and separate table
  bankroll/wallet/explicit debt. Product title and exact currency units,
  conversion, and loan terms remain open.
- **Source safety:** the Maverick review, renderer setting, and current UI
  refinement are uncommitted at this snapshot. Frontier now has local commits
  `adfa16d` and `b6c8af8` with a clean worktree and salvage map; it has no Git
  remote yet, so it is not backed up off-device.
- **Integration plan:** Frontier's proposed town/poker/economy slice is recorded
  in commits `6420dba` and `f1180e4`. The revised design is approved for
  implementation in Maverick; implementation status/evidence is pending the
  Frontier agent's next handoff.

## Immediate focus

1. Let the Frontier agent implement the approved town-slice design in Maverick.
   Coordinate file ownership and avoid overlapping edits; review its handoff,
   tests, and save/load behavior before marking the milestone complete.
2. In parallel, have the owner play several hands with the refined table and
   report confusing or engaging moments. Review at a smaller laptop window
   before more decoration.
3. Once the agent's code lands, integrate and play the end-to-end Rusty Spur
   loop: buy in, play multiple hands, see town/reputation updates, leave/cash
   out, save, reload, and confirm persistence. Keep exchange rate configurable.
4. Add an off-device remote backup for Frontier if it should survive device
   loss. It currently has local Git history only.

## Milestones

### 1. Reliable, playable poker table — **working; heads-up slice exists**

**Included:** reusable Hold'em engine, human-versus-AI table, showdown/side-pot
settlement, privacy-safe snapshots, multi-hand session wrapper, and a first UI
system/polish pass.

**Exit when:** the owner can play several hands on their machine (including an
all-in/showdown); outcomes, legal action prices, and private-card visibility
are clear; the owner has reviewed the refined UI. Multiway AI is not required
to start the world slice.

### 2. One town, one money loop, one lasting consequence — **design approved; implementation pending**

Implement the approved Rusty Spur loop in Maverick. Keep the player's stack in
`PokerSession` across hands; debit wallet on buy-in and cash out on leaving.
Each settled hand adds one poker-volume point and changes prosperity by the
sign of the player's net stack change. Crossing +3/-3 changes town state and
resets prosperity. Persist cumulative Rusty Spur net results and show the
derived reputation label. Keep currency exchange configurable and debt out of
ordinary poker settlement.

**Exit when:** a player can buy in, play several hands, leave and cash out, see
the Rusty Spur town state/reputation respond, and save/load preserves wallet,
town counters/state, and reputation. The player can understand what caused
each change. Loans, property, and NPC memory are out of scope for this slice.

### 3. One remembered rival with fair tells — **not started**

Adapt a small subset of Frontier's NPC psychology into Maverick's existing AI
consumer. Add a few explicit memory events and decay rules. Connect one learned
tell to an observable behavior and a player decision; never reveal hole cards.

Before implementation, repair the Frontier design contracts: its current AI
prototype can emit invalid raise actions, and its memory update clamps negative
weights. See the [integration review](FRONTIER_INTEGRATION_REVIEW.md).

**Exit when:** an event from one hand changes this rival's behavior/read in a
later hand, and the player can learn and act on the tell fairly.

### 4. First connected story slice — **not started**

Connect travel/arrival, the hub saloon, the rival, poker stakes, one town-state
change, one property/debt consequence, and a short Crown confrontation.

**Exit when:** the player can explain how a poker decision changed a character
relationship and the town's state, and can continue play after either a win or
a loss.

### 5. Broader content — **deferred**

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
