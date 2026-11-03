class_name PokerGameState
extends RefCounted
## Orchestrates one Texas Hold'em hand: deck, dealing, street progression,
## betting (via PokerBetting), pot collection, and settlement.
##
## Usage:
##   var g := PokerGameState.new([1000, 1000, 1000], 2, 50, 100)  # button on seat 2
##   g.act(PokerBetting.Action.RAISE, 300)      # current seat acts
##   g.advance_street()                     # after the betting round ends
##   var payouts: Dictionary = g.settle()   # fold-win or river showdown -> {seat: chips}
##
## Notes:
## - One instance = one hand; per-call tables construct a fresh PokerGameState per
##   hand (seat stacks are given at construction and updated by settle()).
## - Side pots are derived from hand-wide seat contributions at settlement.

enum Street { PREFLOP, FLOP, TURN, RIVER, SHOWDOWN }

var betting: PokerBetting
var deck: PokerDeck
var rng: RandomNumberGenerator
var stage: Street = Street.PREFLOP
var showdown_reached: bool = false
var communal: int = 0            # chips pulled in from completed betting rounds
var board: Array[PokerCard] = []      # community cards 0..5
var hole_cards: Array[Array] = []  # per-seat hole cards
var button: int
var sb_seat: int
var bb_seat: int
var sb_amount: int
var bb_amount: int

## chips_per_seat indexed by seat. Heads-up: the button posts the SB.
func _init(
	chips_per_seat: Array,
	p_button: int,
	p_sb: int,
	p_bb: int,
	p_rng: RandomNumberGenerator = null,
	p_deal_order: Array[PokerCard] = []
) -> void:
	rng = p_rng if p_rng else RandomNumberGenerator.new()
	button = p_button
	sb_amount = p_sb
	bb_amount = p_bb
	var num: int = chips_per_seat.size()
	assert(num >= 2, "need at least 2 seats (got %d)" % num)
	assert(button >= 0 and button < num, "button index out of range")
	assert(p_sb > 0 and p_bb >= p_sb, "blinds must be positive and BB >= SB")
	for stack in chips_per_seat:
		assert(typeof(stack) == TYPE_INT and stack > 0,
			"a hand requires positive integer stacks for every seated player")
	if num == 2:
		sb_seat = button
	else:
		sb_seat = (button + 1) % num
	bb_seat = (sb_seat + 1) % num
	betting = PokerBetting.new(chips_per_seat, sb_seat, bb_seat, sb_amount, bb_amount)
	deck = PokerDeck.new(rng)
	if p_deal_order.is_empty():
		deck.shuffle()
	else:
		deck.set_deal_order(p_deal_order)
	for i in range(num):
		var hole: Array[PokerCard] = [deck.draw(), deck.draw()]
		hole_cards.append(hole)

## Create a hand using a named configuration dictionary.
## Required keys: stacks, button, small_blind, big_blind.
## Optional keys: rng, deal_order (complete top-first 52-card deck).
static func from_config(config: Dictionary) -> PokerGameState:
	assert(config.has("stacks"), "config requires stacks")
	assert(config.has("button"), "config requires button")
	assert(config.has("small_blind"), "config requires small_blind")
	assert(config.has("big_blind"), "config requires big_blind")
	assert(config["stacks"] is Array, "stacks must be an array")
	assert(typeof(config["button"]) == TYPE_INT, "button must be an integer")
	assert(typeof(config["small_blind"]) == TYPE_INT, "small_blind must be an integer")
	assert(typeof(config["big_blind"]) == TYPE_INT, "big_blind must be an integer")
	for stack in config["stacks"]:
		assert(typeof(stack) == TYPE_INT, "stacks must contain integers")
	var raw_rng: Variant = config.get("rng", null)
	assert(raw_rng == null or raw_rng is RandomNumberGenerator,
		"rng must be a RandomNumberGenerator")
	var rng: RandomNumberGenerator = raw_rng as RandomNumberGenerator
	var order: Array[PokerCard] = []
	var raw_order: Variant = config.get("deal_order", [])
	assert(raw_order is Array, "deal_order must be an array")
	for card in raw_order:
		assert(card is PokerCard, "deal_order must contain PokerCard resources")
		order.append(card as PokerCard)
	return PokerGameState.new(
		config["stacks"],
		config["button"],
		config["small_blind"],
		config["big_blind"],
		rng,
		order
	)

# --- Queries ---

## All chips already in the hand (collected streets + current bets).
func total_pot() -> int:
	return communal + betting.pot()

## Contributions split into main/side pots, with each pot's eligible seats.
## Folded seats contribute chips but are never eligible to win.
func pot_breakdown() -> Array[Dictionary]:
	var levels: Array[int] = []
	for seat in betting.seats:
		if seat.total_committed > 0 and not levels.has(seat.total_committed):
			levels.append(seat.total_committed)
	levels.sort()
	var pots: Array[Dictionary] = []
	var previous := 0
	for level in levels:
		var amount := 0
		var eligible: Array[int] = []
		for seat in betting.seats:
			amount += maxi(0, mini(seat.total_committed, level) - previous)
			if not seat.folded and seat.total_committed >= level:
				eligible.append(seat.id)
		if amount > 0:
			if eligible.is_empty():
				# A folded player's unmatched excess has no eligible owner. Keep
				# it attached to the preceding pot; if there is no preceding tier,
				# award it to all remaining players.
				if pots.is_empty():
					for seat in betting.seats:
						if not seat.folded:
							eligible.append(seat.id)
					pots.append({amount = amount, eligible = eligible})
				else:
					var last_pot: Dictionary = pots[pots.size() - 1]
					last_pot["amount"] += amount
					pots[pots.size() - 1] = last_pot
			elif not pots.is_empty() and pots[-1].eligible == eligible:
				var merged_pot: Dictionary = pots[pots.size() - 1]
				merged_pot["amount"] += amount
				pots[pots.size() - 1] = merged_pot
			else:
				pots.append({amount = amount, eligible = eligible})
		previous = level
	# Normal play has exact parity between communal and hand contributions.
	# Retain compatibility with callers/tests that set communal directly by
	# placing any untracked amount in the main pot.
	var tracked := 0
	for pot in pots:
		tracked += pot.amount
	var untracked := total_pot() - tracked
	if untracked > 0:
		var eligible_now: Array[int] = []
		for seat in betting.seats:
			if not seat.folded:
				eligible_now.append(seat.id)
		if pots.is_empty():
			pots.append({amount = untracked, eligible = eligible_now})
		else:
			var main_pot: Dictionary = pots[0]
			main_pot["amount"] += untracked
			pots[0] = main_pot
	return pots

## Seat that must act now, or null when nothing is pending.
func current_actor() -> PokerBetting.Seat:
	return betting.current_seat()

## Legal action choices for the current actor, suitable for a UI/controller.
func available_actions() -> Array[Dictionary]:
	return betting.available_actions()

## Whether `seat_id` is the actor and the requested action is currently legal.
func is_action_legal(seat_id: int, action: PokerBetting.Action, amount: int = 0) -> bool:
	return seat_id >= 0 and seat_id < betting.seats.size() \
		and betting.to_act == seat_id \
		and betting.is_legal(action, amount)

## Apply an action on behalf of a seat. Wrong-seat and illegal actions leave
## the hand unchanged.
func apply_action(seat_id: int, action: PokerBetting.Action, amount: int = 0) -> bool:
	if not is_action_legal(seat_id, action, amount):
		return false
	return betting.apply(action, amount)

## JSON-friendly state for a viewer. Opponent hole cards stay hidden until the
## hand is settled; -1 creates an observer view with no private cards.
func snapshot(viewer_seat: int = -1) -> Dictionary:
	assert(viewer_seat == -1 or (viewer_seat >= 0 and viewer_seat < betting.seats.size()),
		"viewer seat index out of range")
	var public_seats: Array[Dictionary] = []
	for seat in betting.seats:
		var can_see_cards := seat.id == viewer_seat \
			or (showdown_reached and not seat.folded)
		var visible_cards: Array[String] = []
		if can_see_cards:
			for card in hole_cards[seat.id]:
				visible_cards.append(card.to_code())
		public_seats.append({
			id = seat.id,
			stack = seat.chips,
			street_commitment = seat.committed,
			total_commitment = seat.total_committed,
			folded = seat.folded,
			all_in = seat.all_in,
			cards = visible_cards,
			hidden_cards = 0 if can_see_cards else hole_cards[seat.id].size(),
		})
	var board_codes: Array[String] = []
	for card in board:
		board_codes.append(card.to_code())
	var stage_names := ["preflop", "flop", "turn", "river", "showdown"]
	var visible_pot := total_pot()
	var visible_pots: Array[Dictionary] = pot_breakdown()
	if stage == Street.SHOWDOWN:
		visible_pot = 0
		visible_pots.clear()
	return {
		stage = stage_names[stage],
		board = board_codes,
		seats = public_seats,
		button = button,
		current_actor = betting.to_act,
		pot = visible_pot,
		pots = visible_pots,
		available_actions = available_actions(),
	}

## Whether the current betting round is finished (street can advance).
func is_street_over() -> bool:
	return betting.is_round_over()

## Whether betting is closed and the rest of the board can be dealt safely.
func can_run_out() -> bool:
	if stage == Street.SHOWDOWN or stage == Street.RIVER \
		or not betting.is_round_over() or players_left() <= 1:
		return false
	var actionable := 0
	for seat in betting.seats:
		if not seat.folded and not seat.all_in:
			actionable += 1
	return actionable <= 1

## True when nothing can decide the hand any more: fold-win or showdown pending.
func hand_over() -> bool:
	return stage == Street.SHOWDOWN or betting.remaining() <= 1

## Number of players still in the hand.
func players_left() -> int:
	return betting.remaining()

func stacks() -> Array:
	var out: Array = []
	for s in betting.seats:
		out.append(s.chips)
	return out

# --- Actions ---

## Forward a betting action for the current seat.
func act(action: PokerBetting.Action, amount: int = 0) -> bool:
	return betting.apply(action, amount)

## Collect this street's bets and deal the next board section.
## Returns false if the betting round is not over or the hand is done.
func advance_street() -> bool:
	if not betting.is_round_over() or hand_over() or stage == Street.RIVER:
		return false
	match stage:
		Street.PREFLOP:
			_pull_pot()
			_deal_board(3)
			stage = Street.FLOP
		Street.FLOP:
			_pull_pot()
			_deal_board(1)
			stage = Street.TURN
		Street.TURN:
			_pull_pot()
			_deal_board(1)
			stage = Street.RIVER
		_:
			return false
	return true

## Deal the rest of the board with no further betting (all-in run-out).
## Requires the current betting round to be over and at most one live seat
## still able to act.
func run_out() -> void:
	assert(can_run_out(), "run_out is only legal when no more betting can happen")
	_pull_pot()
	for seat in betting.seats:
		if not seat.folded and not seat.all_in:
			seat.acted = true
	betting.to_act = -1
	_deal_remaining_board()

## Fold-win (single player left) or river showdown.
## Returns {seat_id: chips_awarded} and updates seat stacks. Stage -> SHOWDOWN.
func settle() -> Dictionary:
	assert(stage != Street.SHOWDOWN, "hand already settled")
	var pot: int = total_pot()
	if betting.remaining() > 1:
		assert(stage == Street.RIVER and betting.is_round_over(),
			"settling a live hand requires a complete river betting round")
	assert(board.size() == 5 or betting.remaining() == 1,
		"showdown requires full board (got %d)" % board.size())
	stage = Street.SHOWDOWN
	var alive: Array = []
	for s in betting.seats:
		if not s.folded:
			alive.append(s)
	if alive.size() == 1:
		var w: PokerBetting.Seat = alive[0]
		w.chips += pot
		var out := {}
		out[w.id] = pot
		return out
	assert(alive.size() >= 2, "showdown requires at least 2 live seats")
	showdown_reached = true
	return _payout_showdown(alive)

# --- Internals ---

func _pull_pot() -> void:
	communal += betting.pot()
	betting.start_street(_first_actionable_after_button())

func _deal_board(count: int) -> void:
	for i in range(count):
		board.append(deck.draw())

func _deal_remaining_board() -> void:
	while stage != Street.RIVER:
		match stage:
			Street.PREFLOP:
				_deal_board(3)
				stage = Street.FLOP
			Street.FLOP:
				_deal_board(1)
				stage = Street.TURN
			Street.TURN:
				_deal_board(1)
				stage = Street.RIVER
			_:
				pass

## First seat clockwise after the button that can still act; -1 if none.
func _first_actionable_after_button() -> int:
	var num: int = betting.seats.size()
	for k in range(1, num + 1):
		var idx := (button + k) % num
		var s := betting.seats[idx]
		if not s.folded and not s.all_in:
			return idx
	return -1

## Evaluate every live seat and distribute the pot (split ties; odd chips go
## to winners in seat order starting after the button).
func _payout_showdown(alive: Array) -> Dictionary:
	var payouts: Dictionary = {}
	var results: Dictionary = {}
	for s in alive:
		var seven: Array[PokerCard] = []
		seven.append_array(hole_cards[s.id])
		seven.append_array(board)
		results[s.id] = PokerHandEvaluator.evaluate(seven)
	for side_pot in pot_breakdown():
		var eligible: Array = []
		for seat_id in side_pot.eligible:
			if results.has(seat_id):
				eligible.append(seat_id)
		# Defensive fallback for malformed/incomplete externally edited states.
		if eligible.is_empty():
			for s in alive:
				eligible.append(s.id)
		var best: int = eligible[0]
		for seat_id in eligible:
			if results[seat_id].compare(results[best]) > 0:
				best = seat_id
		var winners: Array[int] = []
		for seat_id in eligible:
			if results[seat_id].compare(results[best]) == 0:
				winners.append(seat_id)
		_distribute_pot(payouts, winners, side_pot.amount)
	for s in alive:
		# The public payout map includes winners only; losing seats need no entry.
		s.chips += payouts.get(s.id, 0)
	return payouts

## Divide one pot among seat ids. Odd chips go clockwise after the button.
func _distribute_pot(payouts: Dictionary, winners: Array[int], amount: int) -> void:
	var n: int = betting.seats.size()
	winners.sort_custom(func(a, b):
		var da: int = (a - button + n) % n
		var db: int = (b - button + n) % n
		return (da if da != 0 else n) < (db if db != 0 else n))
	var share: int = amount / winners.size()
	var remainder: int = amount % winners.size()
	for s in winners:
		payouts[s] = payouts.get(s, 0) + share
	for i in range(remainder):
		payouts[winners[i]] = payouts.get(winners[i], 0) + 1
