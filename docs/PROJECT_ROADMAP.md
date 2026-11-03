# Project Roadmap

This is the task-level counterpart to the [Project Compass](PROJECT_COMPASS.md).
It tracks what exists, what needs to be decided, and what proves each milestone.
Reorder it when playtests or owner decisions change the plan; record why.

## Current snapshot — 2026-11-02

- **Playable poker:** one human versus one AI; Texas Hold'em hand progression,
  legal actions, showdown, side pots, stack carry-over, and button rotation work.
- **Engine confidence:** `PokerSession` exists and has headless coverage. A
  previous roadmap snapshot records 413 checks; the latest implementation
  handoff reports 403 existing + 66 new = 469 passing. Reconcile that baseline
  count on the next requested test run. The live table still uses
  `PokerGameState` directly and is heads-up only.
- **UI:** the owner playtested the first refinement and found the table still
  wastes space, text is too small, and content overflows narrow windows. An
  interim responsive-layout pass has been checked with viewport bounds, but
  the final rendered appearance still needs a cohesive redesign.
  The owner requested a larger, mobile-adaptive design with names beside cards,
  visible chip stacks and pot, card/chip animations and sound, and a smooth
  wager slider with pot-fraction and all-in presets. UI design steward is
  preparing a reusable brief; retain the AI's aggressive style.
- **Hardware:** the project uses Godot's Compatibility renderer after Vulkan
  pipeline failures on the owner's Intel Mac.
- **World/economy:** the first town-slice data/services landed in Maverick at
  `462b2a6`: wallet, town state, table reputation, economy bridge, and basic
  save/load. These are isolated services; the live poker table does not yet
  call them.
- **Integration decisions:** the owner approved 2D for the first slice, the
  New Canaan → Split River Valley → Devil's Draw hierarchy, and separate table
  bankroll/wallet/explicit debt. Product title and exact currency units,
  conversion, and loan terms remain open.
- **Source safety:** the Maverick review, renderer setting, and current UI
  refinement are uncommitted at this snapshot. Frontier now has local commits
  `adfa16d` and `b6c8af8` with a clean worktree and salvage map; it has no Git
  remote yet, so it is not backed up off-device.
- **Integration plan:** the approved Frontier design (`6420dba`, revised in
  `f1180e4`) has been translated into GDScript foundations in `462b2a6`. The
  end-to-end runtime loop remains to be wired and playtested.

## Immediate focus

1. Wire the committed services into the playable table lifecycle: buy-in funds
   the player's `PokerSession` stack, hand-start/settlement update town and
   reputation exactly once, and leaving cashes out exactly once. The current
   `src/poker/table.gd` still uses `PokerGameState` directly and fixed stacks,
   so the new economy is not yet player-facing.
2. Expose town/reputation changes and save/load in the game flow. Keep the
   exchange rate configurable; isolated save-service tests do not prove that a
   player can save and resume the slice.
3. Implement the cohesive UI pass from `docs/UI_DESIGN_SYSTEM.md` after the
   runtime loop contracts are stable. Preserve the aggressive AI baseline.
4. Add an off-device remote backup for Frontier if it should survive device
   loss. It currently has local Git history only.

## Milestones

### 1. Reliable, playable poker table — **working; heads-up slice exists**

**Included:** reusable Hold'em engine, human-versus-AI table, showdown/side-pot
settlement, privacy-safe snapshots, multi-hand session wrapper, and a first UI
system/polish pass.

**Exit when:** the owner can play several hands on their machine (including an
all-in/showdown); outcomes, legal action prices, and private-card visibility
are clear; the redesigned UI is comfortably readable and adapts to small
screens. Multiway AI is not required to start the world slice.

### 2. One town, one money loop, one lasting consequence — **foundation committed; runtime integration pending**

The wallet, town state, table reputation, economy bridge, and save/load service
are implemented and committed. Next, connect them to the live table so a player
can buy in, keep the stack in `PokerSession` across hands, and cash out once on
leaving. Each settled hand should add one poker-volume point and adjust
prosperity by the sign of net stack change; crossing +3/-3 changes town state
and resets prosperity. Persist cumulative Rusty Spur net results and show the
derived reputation label. Keep currency exchange configurable and debt out of
ordinary poker settlement.

**Exit when:** the player-facing table uses the persistent wallet and
`PokerSession` across multiple hands; leaving cashes out once; town and
reputation changes are visible; save/load restores the same playable state; and
the player can understand what caused each change. Loans, property, and NPC
memory are out of scope for this slice.

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
