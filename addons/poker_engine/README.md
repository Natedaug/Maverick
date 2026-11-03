# Maverick Poker Engine (GDScript)

A Godot 4 GDScript module for Texas Hold'em rules. The scripts in this folder
own cards, deck operations, hand ranking, betting-round rules, and one-hand
state progression. They have no scene or rendering requirements and can be
copied into another Godot project.

This is an early extraction from Maverick, not yet a stable, versioned package.
The public API may change while the engine is made reusable.
The repository does not yet define a license for redistributing the module.

## Install in another Godot project

Copy this folder into the other project's `addons/poker_engine/` directory,
including the `.gd` files and any `.gd.uid` sidecars present. No plugin toggle or
autoload is needed. Open/import the destination project so Godot discovers the
`class_name` scripts, then use the global classes shown below. The module has
no third-party dependencies. AI, UI, and world integration are not included.

## Current API

All scripts register named global classes with `class_name`:

- `PokerCard`, `PokerDeck`: card values and shuffled standard decks.
- `PokerHandRank`, `PokerHandEvaluator`: five/seven-card evaluation and
  comparison.
- `PokerBetting`: one street's action order and chip commitments.
- `PokerGameState`: one hand, including dealing, street progression, runouts,
  and settlement.
- `PokerSession`: optional multi-hand table lifecycle with stable seat ids,
  busted-seat removal from hands, and button rotation.

The `Poker` prefix reduces global class-name collisions when copied into other
Godot projects. `PokerGameState.from_config(config)` is the named-argument
entry point. Required fields are `stacks`, `button`, `small_blind`, and
`big_blind`; optional fields are a seeded `rng` and a complete top-first
`deal_order` of 52 `PokerCard`s.
`PokerGameState.new(stacks, button_index, small_blind, big_blind, rng = null)` is
also available. Stacks are indexed by seat and must be positive. With two
players, the button posts the small blind; with three or more, the seat after
the button posts it. `PokerBetting.Action.BET` and `RAISE` amounts are target street
commitments.

`PokerGameState.pot_breakdown()` returns dictionaries with `amount` and
`eligible` seat ids. Folded seats remain part of contribution amounts but are
excluded from eligibility. Showdown evaluates and distributes every main/side
pot separately; uncontested pots go to their sole eligible player.

`PokerGameState.available_actions()` describes the current actor's options.
Bet and raise options include inclusive `min_amount`/`max_amount` target
bounds; calls include the chips to commit in `amount`. `apply_action()` checks
the seat and action legality before changing state.

Use `PokerGameState.is_action_legal(seat_id, action, amount)` to validate a
seat-specific action and `apply_action(...)` to submit it. A wrong-seat action
returns `false` without changing the hand.

`PokerGameState.snapshot(viewer_seat)` returns JSON-friendly public state with
opponents' hole cards hidden. Pass `-1` for an observer view. Cards are strings
such as `"As"`; the deck is never included. After settlement, cards are shown
for players who reached showdown; folded cards and fold-win hole cards stay
hidden from other seats.

For repeated hands, create `PokerSession(stacks, button_seat, small_blind,
big_blind, rng = null)`. It wraps each `PokerGameState`, filters zero-stack
seats when dealing, and maps actions, payouts, and snapshots back to stable
session seat ids. `start_hand()` deals the first hand; after `settle()`, call
`start_next_hand()` to rotate the button and deal again.

## Hand flow

On each turn, read `available_actions()`, then submit with
`apply_action(seat_id, action, amount)`. On `PokerSession`, seat ids are stable
across hands. When a betting round ends, call
`advance_street()` to deal the flop, turn, or river. On the river, call
`settle()` after the round ends; it returns `{seat_id: chips_awarded}` and
updates stacks. If betting is closed because all but at most one live player
is all-in (`can_run_out()` is true), call `run_out()` to deal the remaining
board, then `settle()`.
`advance_street()` refuses to continue after an uncontested fold win.

Example:

```gdscript
var hand := PokerGameState.from_config({
	stacks = [1000, 1000],
	button = 0,
	small_blind = 50,
	big_blind = 100,
})
# Heads-up: seat 0 (the button) posts the small blind and acts first.
hand.apply_action(0, PokerBetting.Action.CALL)   # complete the small blind
hand.apply_action(1, PokerBetting.Action.CHECK)  # big blind checks its option
hand.advance_street()           # collect preflop bets and deal the flop

# BET/RAISE amounts are total street commitments, not incremental amounts.
# Check with hand.is_action_legal(seat_id, action, amount) before applying.

var public_view: Dictionary = hand.snapshot(0)
```

Callers provide seat stacks, button index, and blind amounts. A
`RandomNumberGenerator` can be passed to `PokerGameState` for reproducible deals.
The engine does not provide a UI, player identity model, AI, persistence, or
network transport.

## Current limitations

- The betting API still has seat-indexed mutable internals; it is not yet a
  validated, stable public interface.
- Short blind posting is capped to the stack and sets the current bet to the
  amount actually posted, but blind edge cases still need rules coverage.
- `PokerGameState` is mutable and represents one hand; callers create the next
  hand and pass updated stacks themselves.
- The named config factory checks basic types/ranges, but seats are still
  represented as parallel index-based arrays rather than player records.
- Choose and add a license before distributing this module outside the project.

See [the work log](../../docs/POKER_ENGINE_WORKLOG.md) for scope, progress, and
recommended next steps.
