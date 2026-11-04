# Project Roadmap

This is the task-level counterpart to the [Project Compass](PROJECT_COMPASS.md).
It tracks what exists, what needs to be decided, and what proves each milestone.
Reorder it when playtests or owner decisions change the plan; record why.

## Current snapshot — 2026-11-04

- **Playable poker:** one human versus one AI; Texas Hold'em hand progression,
  legal actions, showdown, side pots, stack carry-over, and button rotation work.
- **Engine confidence:** `PokerSession` is the live table's multi-hand authority.
  All 1018 checks across 20 headless test scripts pass (Godot 4.7.2), including
  a Rusty Spur flow from buy-in through two hands, cash-out, and save/load. The
  flow test had silently broken when timed reveals were added; it now waits on
  table state instead of assuming synchronous play.
- **Rival memory (Milestone 3):** the owner approved
  [`NPC_MEMORY_CONTRACT.md`](NPC_MEMORY_CONTRACT.md) on 2026-11-03. The drifter
  now remembers suck-outs, coolers, stone-cold bluffs, and folds to pressure;
  memory persists in save format V2 (V1 saves still load). On 2026-11-04 the
  owner clarified that kempt/unkempt means how clean or dirty the drifter
  looks: tilt from bad beats makes him unkempt (shown by his portrait), and an
  unkempt drifter plays loose (calls lighter, bluffs more, ≤15%,
  probabilistic). Tank/snap pauses are now flavor only. See contract §4–§5.
- **UI:** the Svelte table (`web/`) is the only interface; the Godot-drawn
  table was deleted on 2026-11-04. It has large type, adjacent seat/card
  groups, chip stacks and pot, a legal wager slider with presets, card motion,
  the drifter's portrait tell, and synthesized table sounds (deal, card
  reveal, chips, your turn, pot, win) driven by confirmed state changes. A
  header Settings popover has sound on/off, volume, and reduced motion
  (defaults to the OS setting; saved per browser). Sound feel still needs the
  owner's ears. Keep the AI's assertive style.
- **Web performance:** Godot runs with low-processor mode and a hidden 64×64
  canvas, since Svelte draws everything. Restore a full canvas when Godot gets
  a world view.
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
  Runtime integration is on `d04545a`. Rival memory (`7b8b74a`), the Svelte
  table (`ca8ec01`), and the tracked web export preset (`2947eb0`) were merged
  to `main` and pushed to `origin` on 2026-11-04 at the owner's request.
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
   bought in, played hands to showdown, and fit 1440×900, 1280×800, 1152×648 and 800×600
   without scrolling (390×844 scrolls with the action dock pinned). Exit when
   the owner can buy in, play several hands, see the rival's tell, and
   leave/save from the Svelte table and prefers it. On 2026-11-04 the owner
   chose to delete the old Godot-drawn table (`PokerTableUI`, `PokerCardView`);
   `PokerTable` now exposes public commands that `WebBridge` calls directly.

1. **Owner playthrough of the whole slice** with
   [`PLAYTEST_GUIDE.md`](PLAYTEST_GUIDE.md): one season from the arrival to
   Crane. This covers items 0, 2 and 3 below and Milestones 1–4's exit tests.
   Record concrete defects and tuning notes.
2. Confirm the configurable wallet/chip exchange rate and `user://` save path
   behave as expected in the owner's normal Godot app context.
3. Owner playtest of the rival: over several hands, does the drifter's
   kempt/unkempt look feel noticeable, fair, and worth acting on? Review the
   open tuning choices in contract §9 (portrait art, decay, bias cap, look
   thresholds). Do not add
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

### 4. First connected story slice — **working; built, owner playtest pending**

Connect travel/arrival, the hub saloon, the rival, poker stakes, one town-state
change, one property/debt consequence, and a short Crown confrontation.

**Decisions (2026-11-04):** see [`MILESTONE_4_PROPOSALS.md`](MILESTONE_4_PROPOSALS.md).
Build order, each step tested before the next:
1. **Done 2026-11-04.** Economy core in Godot: silver/gold wallet
   (`Wallet.gold`), `AssayOffice` (floating rate), `Campaign` (day clock),
   `Ledger` (The Dealer's marker, House Line markers, claim deed), and save
   format V3 (V1/V2 still load). `tests/test_campaign_economy.gd`, 53 checks.
   Not yet wired into the table or UI.
2. **Done 2026-11-04.** Bridge and Svelte screens: the header shows silver,
   gold, and the day; away from the table, a town screen holds the Rusty Spur
   buy-in, The Dealer's marker (pay in gold), the assay office (exact quotes
   from Godot), the House Line (borrow/repay; barred blocks buy-in), and the
   boarding house (sleep). New games start with 1,000 silver; default buy-in
   500. `test_web_bridge.gd` drives the town commands through JSON.
3. **Done 2026-11-04.** The drifter stakes his deed: `DeedWager` (offer rule,
   escrow, outcomes), deed memory events, an offer panel in place of "Deal
   next hand", and a felt banner while it rides. `test_deed_wager.gd` plus
   the bridge test's deed flow.
4. **Done 2026-11-04.** The Gilded Riverboat confrontation, built to the
   "Step 4 design" spec in the proposals doc: Crane invites you at 3,000
   silver net worth or summons you when The Dealer's marker is overdue
   (summons blocks the Rusty Spur until faced or the marker is paid). You
   choose standard or double stakes (or decline an invitation). Heads-up
   freezeout from 1,500 chips with blinds rising every 4 hands; concede
   between hands. Results move the marker, wallet, deed, and town state, and
   play continues. `CrownDuel` holds the rules (`test_crown_duel.gd`); the
   bridge test plays both routes. Crane's portrait is placeholder art.
5. **Done 2026-11-04.** The arrival (a new season opens with the premise),
   a saved journal of the moments that matter (the drifter's look, the deed,
   debts, the town turning, Crane), Start a new game (Settings, confirmed),
   and an autosave each morning and after Crane. Next: the owner plays a
   full season with [`PLAYTEST_GUIDE.md`](PLAYTEST_GUIDE.md).
6. **Done 2026-11-04 (owner request).** Walkable Devil's Draw: `TownMap`
   draws the street in Godot (assay office, Rusty Spur, boarding house,
   riverboat landing), with the drifter outside the saloon (dusty when
   unkempt) and Crane's riverboat at the landing when he's in town. WASD or
   arrows to walk, E at a door, or the Places menu. Art: the local-only
   Jarppix pack (stand-in shapes without it). `test_town_map.gd`.

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
