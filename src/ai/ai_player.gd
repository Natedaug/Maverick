class_name AIPlayer
extends RefCounted
## Decides legal poker actions for one seat of a PokerGameState.
##
## Combines HandStrength equity estimation with a Strategy, then translates
## the resulting intent into a legal PokerBetting.Action + amount via a fallback
## ladder (raise -> call -> check -> fold), so the caller can always apply
## the returned action.
##
## Usage:
##   var ai := AIPlayer.new(1)          # plays seat 1
##   var decision := ai.decide(game_state)   # {action, amount}
##   game_state.act(decision.action, decision.amount)

const DEFAULT_EQUITY_ITERATIONS := 200

var seat_index: int
var strategy: Strategy
var equity_iterations: int = DEFAULT_EQUITY_ITERATIONS

func _init(p_seat_index: int, p_strategy: Strategy = null) -> void:
	seat_index = p_seat_index
	strategy = p_strategy if p_strategy else Strategy.new()

## Decide for `seat_index` in `g`. Must be this seat's turn.
func decide(g: PokerGameState) -> Dictionary:
	var b := g.betting
	assert(b.to_act == seat_index, "not seat %d's turn (to_act=%d)" % [seat_index, b.to_act])
	var hole: Array[PokerCard] = g.hole_cards[seat_index]
	var opponents: int = g.players_left() - 1
	var equity: float = HandStrength.equity(
		hole, g.board, opponents, equity_iterations, strategy.rng)
	var seat: PokerBetting.Seat = b.seats[seat_index]
	var pot: int = g.total_pot()
	var call_amount: int = b.amount_to_call(seat_index)
	var intent: Dictionary = strategy.decide(
		equity, g.stage, call_amount, pot, opponents)
	return _materialize(intent, b, g)

# --- Internals ---

## Translate a Strategy intent into a legal applied action.
func _materialize(intent: Dictionary, b: PokerBetting, g: PokerGameState) -> Dictionary:
	var action: PokerBetting.Action = intent.get("action", PokerBetting.Action.FOLD)
	match action:
		PokerBetting.Action.CHECK:
			return _apply_first_legal(g, [[PokerBetting.Action.CHECK, 0], [PokerBetting.Action.CALL, 0]])
		PokerBetting.Action.CALL:
			return _apply_first_legal(g, [[PokerBetting.Action.CALL, 0], [PokerBetting.Action.CHECK, 0]])
		PokerBetting.Action.FOLD:
			return _apply_first_legal(g, [[PokerBetting.Action.FOLD, 0]])
		PokerBetting.Action.BET, PokerBetting.Action.RAISE:
			return _bet_or_raise(intent.get("frac", 0.5), b, g)
	return _apply_first_legal(g, [[PokerBetting.Action.FOLD, 0]])

## Apply the first legal candidate; last resort is FOLD (always legal).
func _apply_first_legal(g: PokerGameState, candidates: Array) -> Dictionary:
	for c in candidates:
		if g.is_action_legal(seat_index, c[0], c[1]):
			if g.apply_action(seat_index, c[0], c[1]):
				return {action = c[0], amount = c[1]}
	g.apply_action(seat_index, PokerBetting.Action.FOLD)
	return {action = PokerBetting.Action.FOLD, amount = 0}

## Size a value bet/raise (or plausible bluff) and materialize it with fallbacks.
func _bet_or_raise(frac: float, b: PokerBetting, g: PokerGameState) -> Dictionary:
	var seat: PokerBetting.Seat = b.seats[seat_index]
	var pot: int = g.total_pot()
	if b.current_bet == 0:
		# Opening bet: target fraction of the pot, at least the BB, capped at stack
		var desired: int = maxi(b.big_blind, int(round(float(pot) * frac)))
		var amount: int = mini(desired, seat.chips)
		var ladder: Array = [[PokerBetting.Action.BET, amount]]
		if seat.chips != amount:  # else same as above
			ladder.append([PokerBetting.Action.BET, seat.chips])  # all-in bet
		ladder.append([PokerBetting.Action.CHECK, 0])
		return _apply_first_legal(g, ladder)
	# Facing a bet: raise-to = current bet + size worth `frac` of the pot,
	# but never below the legal minimum
	var min_to: int = b.current_bet + maxi(b.big_blind, b.last_raise_size)
	var cap: int = seat.chips + seat.committed
	var desired_to: int = b.current_bet + int(round(float(pot) * frac))
	var raise_to: int = clampi(maxi(desired_to, min_to), 0, cap)
	var ladder: Array = [[PokerBetting.Action.RAISE, raise_to]]
	if cap > b.current_bet:  # all-in fallback
		ladder.append([PokerBetting.Action.RAISE, cap])
	ladder.append([PokerBetting.Action.CALL, 0])
	ladder.append([PokerBetting.Action.CHECK, 0])
	return _apply_first_legal(g, ladder)
