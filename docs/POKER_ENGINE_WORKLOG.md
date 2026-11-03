# Poker Engine Extraction Work Log

This file is a handoff trail for agents continuing the reusable Godot poker
engine work. Read it with `addons/poker_engine/README.md` and the root README.

## Goal

Make Maverick's Texas Hold'em rules a reusable GDScript module that can be
dropped into other Godot projects. `_pocal` is a separate TypeScript-oriented
reference project; its architecture is useful, but TypeScript is not a direct
runtime dependency for this Godot game.

Keep poker rules independent from Maverick's world, UI, NPC, and presentation
code. AI strategy can remain a consumer of the engine rather than part of the
rules package. Reuse in another game should mean copying/installing the Godot
module, not connecting to a service.

## Project direction

Maverick's larger mission is a western RPG where poker is the social and
progression system: exploration introduces people and stakes; tells, reputation,
and consequences make each poker table part of the story. The current source
does not yet deliver that full loop: world/UI scripts are early scaffolding and
the engine is the only substantial implemented system. Keep the next milestone
narrow: establish a trustworthy, reusable poker core, then connect it to a
playable table with AI and readable tells before broadening into world content.

The immediate workstream is a playable table that consumes the engine. After
the first AI hand loop works, validate clean-project engine installation and
broader chip-conservation cases. Keep technical extraction work in service of
the game's larger goal.

## Work completed

- Created `addons/poker_engine/` as the intended package boundary.
- Moved the card, deck, hand ranking, evaluator, betting, and game-state scripts
  and their Godot UID sidecars into that folder as the first extraction pass.
- Left `src/ai/` and `src/poker/table.gd` in Maverick; AI and scene/table
  integration are consumers, not engine primitives.
- Added the engine README with current API and limitations.
- Added hand-wide contribution tracking to betting seats, exposed
  `PokerGameState.pot_breakdown()`, and changed showdown payouts to rank eligible
  players independently for each main/side pot. Existing one-pot behavior is
  represented as a single pot; uncontested wins still award the whole pot.
- Added `available_actions()` query methods for UI/controller consumers and
  constructor assertions for seat counts/indexes, blind values, and stack
  ranges. A hand requires positive starting stacks; `PokerBetting` itself accepts
  zero stacks. The current preflop bet uses the actual posted amount when a
  blind stack is short.
- Tracked each seat's last acted-at bet and now distinguish needing to respond
  from having raise rights. Short all-ins require a call/fold response, but do
  not reopen raising unless cumulative increases reach a full raise.
- Documented copy-based installation into another Godot project's
  `addons/poker_engine/` folder; this is a script module, not an enabled Godot
  editor plugin or an autoload.
- Added `PokerGameState.from_config()` as a named-field factory, optional complete
  top-first deck injection for deterministic hands, and `snapshot()` for a
  JSON-friendly viewer-specific view that omits the deck and hides private
  cards until showdown. Folded cards and fold-win hands remain hidden from
  other seats after settlement.
- Renamed the engine's global classes with a `Poker` prefix (`PokerCard`,
  `PokerBetting`, `PokerGameState`, etc.) and updated AI/test consumers to avoid
  collisions with common global names in Godot projects.
- Added seat-authorized `is_action_legal()` and `apply_action()` entry points;
  Maverick's AI now submits actions through that public game-state boundary.
- Added `PokerSession` as an optional multi-hand wrapper. It preserves stable
  roster seats while omitting empty stacks from a hand, maps payouts/snapshots
  back to stable ids, and rotates the button past busted seats.
- Tightened hand progression: an all-in runout is rejected if multiple live
  seats can still act, and street advancement stops once the hand is already
  over by folds. Added `can_run_out()` so consumers can query that condition
  before calling `run_out()`.

## Current architecture

`PokerGameState` owns one hand and composes `PokerDeck`, `PokerBetting`, and
`PokerHandEvaluator`. `PokerBetting` owns street commitments and legal action
checks. `PokerSession` optionally owns the stable seat roster across hands.
Cards/deck and hand ranking are separate helpers. AI scripts consume
`PokerGameState`; the first saloon table now connects a player-facing UI and AI
to one hand at a time. Exploration, persistent NPC relationships, and tells
remain future work.

## Known gaps and design decisions to make

1. Replace exposed mutable internals with a versioned config/query surface
   before treating the API as stable.
2. Add portable edge-case coverage for chip conservation. Existing tests are in
   `tests/` and refer to global `class_name` types; keep those consumers aligned
   when the public names change.
3. Document install/use in a clean Godot project and confirm the addon imports
   there before calling it a reusable release.
4. Choose a license for the engine before distributing it outside Maverick;
   this repository currently has no license file.

## Validation status

The Godot 4.7.2 headless suite currently passes: deck (62 checks), hand
evaluator (137), betting (99), game state (65), AI (40), and session (10),
for 413 checks.
The local Godot global class cache must be refreshed after the engine extraction
or standalone scripts may resolve stale pre-extraction names/paths. The editor
reported a macOS certificate lookup warning and could not save user-level
editor settings in this environment; the project-local scripts nevertheless
ran and passed.

Coverage still needed before calling the extraction release-ready: broader
chip-conservation runs across varied all-in patterns and import/use in a clean
Godot project.

## Agent continuation — 2026-11-02

- Refreshed Godot's stale `.godot/global_script_class_cache.cfg`; it referenced removed `src/poker/` paths and prevented standalone tests from parsing. This is generated cache state, not a source change.
- Existing scripts: deck (62 checks), evaluator (137), and betting (99) pass. Game-state and AI runs exposed a showdown settlement error: live losing seats had no payout entry, and settlement indexed the missing key while crediting stacks.
- Made stack crediting default to zero for seats omitted from the winner-only payout map. This preserves the existing public return shape while allowing losers to settle and conserving chips.
- Updated the root README and this work log with the whole-project mission and sequence: trustworthy core → playable AI table/tells → broader world systems.

All five original scripts pass (392 checks total).

## Agent continuation — 2026-11-02 (verification coverage)

- An independent agent reviewed settlement, snapshot privacy, and session
  lifecycle. It found no confirmed defect in those areas and recommended adding
  deterministic tests where coverage was absent.
- Added a scripted main/side-pot settlement case with contributions 100/300/300:
  the folded contributor's chips remain in both pots, seat 0 wins the 300-chip
  main pot, and seat 1 wins the 400-chip side pot.
- Added snapshot assertions for private cards before showdown, revealed live
  hands at showdown, hidden folded cards, and hidden cards after a fold-win.
- Added `tests/test_session.gd` for stable seat ids, winner payout mapping,
  empty-seat snapshot state, and button rotation past an empty seat.
- Reran the six headless scripts: all 413 checks pass. Remaining verification
  is broader chip-conservation coverage and import/use in a clean Godot project.

The extraction is not yet verified as a reusable release until clean-project
installation is confirmed.

## Playable table vertical slice — 2026-11-02

- Replaced the empty table/UI stubs with a saloon table scene and card/pot/stack
  display, Fold / Check / Call / Bet / Raise controls, and a next-hand button.
- Connected the table controller to `PokerGameState` and the existing
  equity-based AI. The controller advances streets, runs out all-in boards,
  settles hands, preserves both stacks, and rotates the heads-up button.
- Kept this as one player versus one AI. The scene does not yet connect to
  exploration, NPC relationships, persistence, or the tell system.
- Set the project renderer to Compatibility after the user's Intel Mac failed
  to compile Vulkan pipelines. Godot 4.7.2 headless startup loads the main scene
  and scripts without project parse/runtime errors, and the user confirmed the
  table is playable locally.
- The user reports the UI/UX is very basic. Keep it as a functional prototype
  for now; tune the poker loop before planning an interface redesign. Engine
  headless coverage remains at 413 passing checks.

## Table UI refinement — 2026-11-02

- Added reusable card faces and backs with rank/suit corner marks, red/black
  suit colors, and muted felt placeholders for community cards not yet dealt.
- Clarified heads-up dealer/blind roles, active turn labels, and all-in state at
  each seat; stacks remain explicit numeric values.
- Made the call control show the exact price, the wager control show its target,
  and a nearby range label show legal min/max targets.
- Added a compact four-line action history while keeping status text separate.
- Godot headless startup check passed after correcting a UI parenting issue.
  Review at a laptop-sized window remains a follow-up.

## Responsive table layout — 2026-11-02

- Fixed wrapped status/history labels collapsing to one pixel wide: wrapped
  labels now receive the available felt width directly instead of relying on a
  centering container that honored their one-character minimum.
- Added a compact layout below 700 px height or 900 px width. It reduces card
  dimensions, margins, spacing, and action-control widths, and hides history
  below 540 px height so the decision UI stays visible.
- Kept Next Hand in the same action dock row; it replaces the action controls
  at showdown instead of adding a lower row that could be cut off.
- Scene layout probe, with viewport sizes assigned on the root Window, checked
  active-hand and showdown geometry at 1152×648, 800×600, and 640×480. In all
  three, Fold / Check / Call / Wager and Next Hand stayed within viewport
  bounds; wrapped message labels had full available width. Godot startup also
  completed with no scene script/runtime errors.
- Rendered pixels were not inspected: `--write-movie` capture could not start
  cleanly in this Mac session due to a LaunchServices/XPC failure. Owner visual
  review remains necessary.

## Owner UI/UX direction — 2026-11-02

- The owner wants a broader table redesign: much larger, readable text; names
  adjacent to hole cards; a creative saloon table with visible player/pot chip
  piles; fluid layouts through narrow/mobile-sized viewports; a smooth wager
  slider with pot presets and click-to-step behavior; card/chip animations;
  tasteful sound; and retention of the AI's assertive play style.
- Documented a concrete layout brief, breakpoints, type sizes, interaction
  semantics, acceptance criteria, and implementation order in
  `docs/UI_DESIGN_SYSTEM.md` v0.5.
- The prior responsive pass only verified that essential controls fit at fixed
  viewports and corrected wrapped-text width. It does not resolve the owner's
  concerns about small type, wasted space, weak table art direction, chip
  feedback, wager ergonomics, or sensory polish.
- Avoid iterative screenshot requests. Implement a coherent pass, check geometry
  at the documented viewports, and collect one playthrough summary from the
  owner. Poker legality remains with the engine/controller; UI sizing is a
  proposal constrained by the engine's legal ranges.
