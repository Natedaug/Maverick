class_name PokerBetting
extends RefCounted
## Texas Hold'em betting-round logic for one betting street (blinds -> river).
##
## Manages seat stacks, blinds, the action cycle, and pot math. The caller
## (future game_state/table code) transitions streets via start_street() and
## harvests pot() into the communal pot at street end.
##
## Usage:
##   var b := PokerBetting.new([1000, 1000, 1000], 0, 1, 50, 100)  # seat 0 = SB, seat 1 = BB
##   b.apply(PokerBetting.Action.CALL)   # SB completes to the BB
##   b.apply(PokerBetting.Action.CHECK)  # BB's preflop option
##   b.is_round_over()              # -> true
##
## pot() reports the current street only. Seat.total_committed tracks the hand
## total for PokerGameState's main/side-pot calculation.

enum Action { FOLD, CHECK, CALL, BET, RAISE }

class Seat extends RefCounted:
	var id: int
	var chips: int
	var committed: int = 0   # chips put in this street
	var total_committed: int = 0  # chips put in this hand, across all streets
	var folded: bool = false
	var all_in: bool = false
	var acted: bool = false  # took a voluntary action this street
	var last_acted_bet: int = 0  # currentBet when this seat last acted

var seats: Array[Seat] = []
var small_blind: int = 0
var big_blind: int = 0
var current_bet: int = 0        # highest committed amount this street
var last_raise_size: int = 0    # size of the last bet/raise (min-raise reference)
var to_act: int = -1            # seat index whose turn it is, -1 = none

## chip_amounts is indexed by seat. sb_seat/bb_seat post their blinds on setup.
## Preflop action starts at the seat after the BB (handled automatically).
func _init(chip_amounts: Array, sb_seat: int, bb_seat: int, p_sb: int, p_bb: int) -> void:
	assert(chip_amounts.size() >= 2, "need at least 2 seats")
	assert(sb_seat >= 0 and sb_seat < chip_amounts.size(), "invalid small blind seat")
	assert(bb_seat >= 0 and bb_seat < chip_amounts.size(), "invalid big blind seat")
	assert(sb_seat != bb_seat, "blinds must be posted by different seats")
	assert(p_sb > 0 and p_bb >= p_sb, "blinds must be positive and BB >= SB")
	for stack in chip_amounts:
		assert(stack >= 0, "stacks cannot be negative")
	small_blind = p_sb
	big_blind = p_bb
	last_raise_size = big_blind
	for i in range(chip_amounts.size()):
		var s := Seat.new()
		s.id = i
		s.chips = chip_amounts[i]
		seats.append(s)
	_commit(seats[sb_seat], small_blind, false)
	_commit(seats[bb_seat], big_blind, false)
	current_bet = maxi(seats[sb_seat].committed, seats[bb_seat].committed)
	to_act = _next_needing_action(bb_seat)

# --- Public API ---

## Seat whose turn it is, or null when no action is pending.
func current_seat() -> Seat:
	return null if to_act < 0 else seats[to_act]

## Chips the given seat must add to match current_bet (capped by stack).
func amount_to_call(seat_index: int) -> int:
	var s := seats[seat_index]
	return mini(current_bet - s.committed, s.chips)

## Whether this seat's raise rights are open. Short all-ins only reopen action
## once cumulative increases reach a full raise since the seat last acted.
func can_raise(seat_index: int) -> bool:
	var s := seats[seat_index]
	return not s.acted or current_bet - s.last_acted_bet >= maxi(big_blind, last_raise_size)

## Compact options for UI/controllers. BET/RAISE options include inclusive
## target bounds; CALL includes the amount this seat will commit.
func available_actions() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if to_act < 0:
		return options
	var s := seats[to_act]
	options.append({action = Action.FOLD})
	if is_legal(Action.CHECK):
		options.append({action = Action.CHECK})
	else:
		options.append({action = Action.CALL, amount = amount_to_call(to_act)})
	var max_target := s.committed + s.chips
	if current_bet == 0 and max_target > 0:
		options.append({
			action = Action.BET,
			min_amount = mini(big_blind, max_target),
			max_amount = max_target,
		})
	elif current_bet > 0 and max_target > current_bet and can_raise(to_act):
		var min_raise_to := current_bet + maxi(big_blind, last_raise_size)
		if max_target >= min_raise_to:
			options.append({
				action = Action.RAISE,
				min_amount = min_raise_to,
				max_amount = max_target,
			})
		elif is_legal(Action.RAISE, max_target):
			# A below-minimum raise is only legal as an all-in.
			options.append({
				action = Action.RAISE,
				min_amount = max_target,
				max_amount = max_target,
			})
	return options

## Whether `action` (with total-target `amount` for BET/RAISE) is legal for the
## seat to act. Illegal actions leave state untouched.
func is_legal(action: Action, amount: int = 0) -> bool:
	if to_act < 0:
		return false
	var s := seats[to_act]
	match action:
		Action.FOLD:
			return true
		Action.CHECK:
			return s.committed >= current_bet
		Action.CALL:
			return s.committed < current_bet and s.chips > 0
		Action.BET:
			return current_bet == 0 and amount > 0 \
				and amount <= s.chips \
				and (amount >= big_blind or amount == s.chips)
		Action.RAISE:
			return current_bet > 0 \
				and can_raise(to_act) \
				and amount > current_bet \
				and amount > s.committed \
				and amount - s.committed <= s.chips \
				and (amount >= current_bet + maxi(big_blind, last_raise_size)
					or amount == s.chips + s.committed)
	return false

## Apply a legal action for the seat to act and advance the action. Returns
## false (without side effects) for illegal actions.
func apply(action: Action, amount: int = 0) -> bool:
	if not is_legal(action, amount):
		return false
	var s := seats[to_act]
	match action:
		Action.FOLD:
			s.folded = true
			s.acted = true
		Action.CHECK:
			s.acted = true
		Action.CALL:
			_commit(s, current_bet - s.committed, true)
		Action.BET, Action.RAISE:
			if amount - current_bet >= maxi(big_blind, last_raise_size):
				last_raise_size = amount - current_bet
			_commit(s, amount - s.committed, true)
			# Bet/raise may have been a (short) all-in below the intended size
			if s.committed > current_bet:
				current_bet = s.committed
	s.last_acted_bet = current_bet
	to_act = _next_needing_action(to_act)
	return true

## Reset per-street state and set who acts first (seat after the button postflop).
func start_street(first_seat: int) -> void:
	for s in seats:
		s.committed = 0
		s.last_acted_bet = 0
		if not s.all_in:
			s.acted = false
	current_bet = 0
	last_raise_size = big_blind
	to_act = first_seat
	if to_act < 0 or not _needs_action(seats[to_act]):
		to_act = _next_needing_action(to_act if to_act >= 0 else seats.size() - 1)

## True when no seat can or needs to act any more.
func is_round_over() -> bool:
	for s in seats:
		if _needs_action(s):
			return false
	return true

## Chips committed this street by all seats.
func pot() -> int:
	var total: int = 0
	for s in seats:
		total += s.committed
	return total

## Seats still in the hand (not folded).
func remaining() -> int:
	var count: int = 0
	for s in seats:
		if not s.folded:
			count += 1
	return count

# --- Internal helpers ---

## A seat needs action when it is live, can still act, and either has not
## acted this street or is yet to match the current bet (BB's blind option
## counts as not-acted for preflop).
func _needs_action(s: Seat) -> bool:
	return not s.folded and not s.all_in \
		and (not s.acted or s.committed < current_bet)

## First seat needing action, searching clockwise starting after `after`.
func _next_needing_action(after: int) -> int:
	for k in range(1, seats.size() + 1):
		var idx := (after + k) % seats.size()
		if _needs_action(seats[idx]):
			return idx
	return -1

## Move amount into the seat's street commitment, all-in when the stack runs out.
func _commit(s: Seat, amount: int, acting: bool) -> void:
	var pay := mini(amount, s.chips)
	s.chips -= pay
	s.committed += pay
	s.total_committed += pay
	if s.chips == 0:
		s.all_in = true
	if acting:
		s.acted = true
