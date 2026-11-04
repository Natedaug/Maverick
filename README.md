# 🤠 Texas Hold'em Frontier

A top-down open world western RPG where Texas Hold'em poker is the core mechanic.
The long-term mission is to make poker the way players read, negotiate with,
and build relationships across the frontier, with exploration and story giving
each table context.

## Status
**Phase 1: Poker Core (heads-up slice playable)** — reusable rules engine and
one-player-versus-AI table are in place. Current work is playtesting the refined
table and setting the world/economy direction before building the world slice.

The current prototype opens a one-player-versus-AI Hold'em table. Deal a hand,
use Fold / Check / Call / Bet / Raise, and select **Next hand** after settlement.
World exploration, persistent NPC relationships, and learnable tells are the
next major systems.

## Docs
- [Agent handoff instructions](AGENTS.md)
- [Project Compass](docs/PROJECT_COMPASS.md)
- [Project Roadmap](docs/PROJECT_ROADMAP.md)
- [Game Design Document](docs/TEXAS_HOLDEM_FRONTIER_GDD.md)
- [Godot Poker Engine](addons/poker_engine/README.md)
- [Poker Engine Work Log](docs/POKER_ENGINE_WORKLOG.md)
- [UI Design System](docs/UI_DESIGN_SYSTEM.md)
- [Project direction and next steps](docs/POKER_ENGINE_WORKLOG.md#project-direction)
- [Frontier integration review](docs/FRONTIER_INTEGRATION_REVIEW.md)

## Requirements
- Godot 4.3+ (stable)

## Run
The game runs in a browser: a Svelte interface (`web/`) hosts a Godot web
build. Godot owns all rules and game state; Svelte draws the interface and
sends player intents over a JSON bridge (`src/web/web_bridge.gd`).

```bash
cd web
npm install             # first time only
npm run godot:export    # rebuild after any Godot/GDScript change
npm run dev             # open http://localhost:5174
```

To play the Devil's Draw slice and know what to look for, see
[the playtest guide](docs/PLAYTEST_GUIDE.md). The walkable town uses a free
art pack that isn't in the repo; see
[assets/third_party/README.md](assets/third_party/README.md) to install it.

Requires Godot 4.7.2 web export templates (Editor → Manage Export Templates).
The Godot-drawn table was removed on 2026-11-04; `godot --path .` now only
shows a pointer to the web app. Godot's canvas is hidden in the page until
there is a world view to draw.

## Poker engine checks
```bash
for test in tests/test_deck.gd tests/test_hand_evaluator.gd tests/test_betting.gd tests/test_game_state.gd tests/test_ai.gd tests/test_session.gd; do
  godot --headless --path . --script "$test" || exit 1
done
```
