# Project Roadmap

This is the task-level counterpart to the [Project Compass](PROJECT_COMPASS.md).
It tracks what exists, what needs to be decided, and what proves each milestone.
Reorder it when playtests or owner decisions change the plan; record why.

## Current snapshot — 2026-11-03

- **Playable poker:** one human versus one AI; Texas Hold'em hand progression,
  legal actions, showdown, side pots, stack carry-over, and button rotation work.
- **Engine confidence:** `PokerSession` is the live table's multi-hand authority.
  All 721 checks across 16 headless test scripts pass (Godot 4.7.2), including
  a Rusty Spur flow from buy-in through two hands, cash-out, and save/load. The
  flow test had silently broken when timed reveals were added; it now waits on
  table state instead of assuming synchronous play.
- **Rival memory (Milestone 3):** the owner approved
  [`NPC_MEMORY_CONTRACT.md`](NPC_MEMORY_CONTRACT.md) on 2026-11-03. The drifter
  now remembers suck-outs, coolers, stone-cold bluffs, and folds to pressure;
  memory nudges its decisions (≤15%, probabilistic), drives a visible
  tank/snap rhythm shown as KEMPT/UNKEMPT, and persists in save format V2
  (V1 saves still load). Contract §10 records clarifications for owner review.
- **UI:** the latest responsive pass has larger type, adjacent player/card
  groups, visible chip stacks and pot, a smooth legal wager slider with
  fractional/pot/all-in presets, card/chip motion, synthesized cues, mute, and
  reduced-motion controls. Geometry was probed at five laptop/mobile sizes.
  Rendered pixel/audio quality and hands-on interaction still need the owner's
  playthrough. Keep the AI's assertive style.
- **Hardware:** the project uses Godot's Compatibility renderer after Vulkan
  pipeline failures on the owner's Intel Mac.
- **World/economy:** wallet, town state, table reputation, bridge, and save/load
  are now wired into the live table. Buy-in funds a multi-hand session, each
  settlement updates town/reputation once, and leaving cashes out once.
- **Integration decisions:** the owner approved 2D for the first slice, the
  New Canaan → Split River Valley → Devil's Draw hierarchy, and separate table
  bankroll/wallet/explicit debt. Product title and exact currency units,
  conversion, and loan terms remain open.
- **Source safety:** town foundations are on `462b2a6`, the cash-out guard and
  review updates on `6e2293f`, and the interim responsive UI code on `c2a1fe8`.
  Runtime integration is on `d04545a`. The Milestone 3 rival-memory work and
  the flow-test repair are committed on the local `milestone-3-rival-memory`
  branch, pending merge to `main` after owner playtest.
  The UI redesign brief is committed. Frontier has local commits `adfa16d` and
  `b6c8af8` with a salvage map but no remote backup.
- **Integration plan:** the approved Frontier design (`6420dba`, revised in
  `f1180e4`) has been translated into GDScript and connected to the playable
  loop. Remaining owner validation is a hands-on visual/audio playthrough and
  confirmation of save behavior in the installed Mac environment.

## Immediate focus

0. **Svelte UI spike (owner decision 2026-11-03) — working; owner playtest
   pending.** The Rusty Spur table runs in `web/` (Svelte 5 + Vite) around a
   Godot web build, over `WebBridge` JSON messages. Automated Chrome runs
   bought in, played hands to showdown, saw tank/snap and a KEMPT/UNKEMPT
   read develop naturally, and fit 1440×900, 1280×800, 1152×648 and 800×600
   without scrolling (390×844 scrolls with the action dock pinned). Exit when
   the owner can buy in, play several hands, see the rival's tell, and
   leave/save from the Svelte table and prefers it. The old Godot-drawn table
   still has layout bugs (collapsed seat text, clipped message); leave them
   unless the spike is abandoned.

1. Owner playthrough: check visual hierarchy, sounds, wager controls, multi-hand
   settlement, save/load, and leaving/cash-out. Record any concrete defects.
2. Confirm the configurable wallet/chip exchange rate and `user://` save path
   behave as expected in the owner's normal Godot app context.
3. Owner playtest of the rival: over several hands, does the KEMPT/UNKEMPT
   tell feel noticeable, fair, and worth acting on? Review contract §10 and the
   open tuning choices in §9 (icon, decay, bias cap, UI surface). Do not add
   the wider Frontier economy or progression systems yet.
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

### 2. One town, one money loop, one lasting consequence — **working; runtime wired, owner playthrough pending**

The wallet, town state, reputation, bridge, and save/load are connected to the
live table. A player buys in once, plays successive `PokerSession` hands,
updates town/reputation from settlement, then cashes out once on leaving. Save
and load expose the same world state. Exchange rate remains configurable; its
default is a prototype setting, not canon. Debt stays out of ordinary poker
settlement.

**Exit when:** the player-facing table uses the persistent wallet and
`PokerSession` across multiple hands; leaving cashes out once; town and
reputation changes are visible; save/load restores the same playable state; and
the player can understand what caused each change. Loans, property, and NPC
memory are out of scope for this slice.

### 3. One remembered rival with fair tells — **working; implemented, owner playtest pending**

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
