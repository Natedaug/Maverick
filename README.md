# 🤠 Texas Hold'em Frontier

A top-down open world western RPG where Texas Hold'em poker is the core mechanic.
The long-term mission is to make poker the way players read, negotiate with,
and build relationships across the frontier, with exploration and story giving
each table context. The current prototype is focused on making the poker rules
dependable before expanding the world systems.

## Status
**Phase 1: Poker Core (in progress)** — reusable rules engine extracted; current
work is validating settlement and edge cases before building the AI-to-table
play loop and connecting it to the world.

## Docs
- [Game Design Document](docs/TEXAS_HOLDEM_FRONTIER_GDD.md)
- [Godot Poker Engine](addons/poker_engine/README.md)
- [Poker Engine Work Log](docs/POKER_ENGINE_WORKLOG.md)
- [Project direction and next steps](docs/POKER_ENGINE_WORKLOG.md#project-direction)

## Requirements
- Godot 4.3+ (stable)

## Run
```bash
godot --path .          # open editor
godot --headless --quit # verify project loads cleanly 
```

## Poker engine checks
```bash
for test in tests/test_deck.gd tests/test_hand_evaluator.gd tests/test_betting.gd tests/test_game_state.gd tests/test_ai.gd tests/test_session.gd; do
  godot --headless --path . --script "$test" || exit 1
done
```
