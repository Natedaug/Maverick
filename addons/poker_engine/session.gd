class_name PokerSession
extends RefCounted
## Multi-hand table wrapper with stable seat ids and button rotation.
## PokerGameState remains the focused single-hand rules implementation.

var small_blind: int
var big_blind: int
var button_seat: int
var hand_number: int = 0
var rng: RandomNumberGenerator

var _stacks: Array[int] = []
var _active_seats: Array[int] = []  # local hand seat -> stable session seat
var _hand_state: PokerGameState

## Starting stacks may include zero to represent eliminated/empty seats.
func _init(
	starting_stacks: Array,
	p_button_seat: int,
	p_small_blind: int,
	p_big_blind: int,
	p_rng: RandomNumberGenerator = null
) -> void:
	assert(starting_stacks.size() >= 2, "a session needs at least two seats")
	assert(p_button_seat >= 0 and p_button_seat < starting_stacks.size(),
		"button seat index out of range")
	assert(p_small_blind > 0 and p_big_blind >= p_small_blind,
		"blinds must be positive and BB >= SB")
	var funded := 0
	for stack in starting_stacks:
		assert(typeof(stack) == TYPE_INT and stack >= 0,
			"session stacks must be nonnegative integers")
		_stacks.append(stack)
		if stack > 0:
			funded += 1
	assert(funded >= 2, "a session needs at least two funded seats")
	small_blind = p_small_blind
	big_blind = p_big_blind
	button_seat = p_button_seat
	rng = p_rng if p_rng else RandomNumberGenerator.new()

## Deal the first hand. Returns false if fewer than two seats have chips.
func start_hand(deal_order: Array[PokerCard] = []) -> bool:
	assert(_hand_state == null, "session already has a hand; use start_next_hand")
	return _deal_hand(deal_order)

## Settle the current hand first, then rotate the button and deal another.
## Returns false when the previous hand is unfinished or fewer than two seats
## remain funded.
func start_next_hand(deal_order: Array[PokerCard] = []) -> bool:
	if _hand_state == null or _hand_state.stage != PokerGameState.Street.SHOWDOWN:
		return false
	_sync_stacks()
	if _funded_seat_count() < 2:
		_active_seats.clear()
		_hand_state = null
		return false
	button_seat = _next_funded_after(button_seat)
	_hand_state = null
	return _deal_hand(deal_order)

## Stable session seat id whose turn it is, or -1 when no action is pending.
func current_actor() -> int:
	if _hand_state == null or _hand_state.betting.to_act < 0:
		return -1
	return _active_seats[_hand_state.betting.to_act]

func available_actions() -> Array[Dictionary]:
	return [] if _hand_state == null else _hand_state.available_actions()

func is_street_over() -> bool:
	return _hand_state != null and _hand_state.is_street_over()

func hand_over() -> bool:
	return _hand_state == null or _hand_state.hand_over()

func is_action_legal(seat_id: int, action: PokerBetting.Action, amount: int = 0) -> bool:
	if _hand_state == null:
		return false
	var local_seat := _active_seats.find(seat_id)
	return local_seat >= 0 and _hand_state.is_action_legal(local_seat, action, amount)

func apply_action(seat_id: int, action: PokerBetting.Action, amount: int = 0) -> bool:
	if not is_action_legal(seat_id, action, amount):
		return false
	return _hand_state.apply_action(_active_seats.find(seat_id), action, amount)

func advance_street() -> bool:
	return _hand_state != null and _hand_state.advance_street()

func can_run_out() -> bool:
	return _hand_state != null and _hand_state.can_run_out()

func run_out() -> void:
	assert(_hand_state != null, "session has no active hand")
	_hand_state.run_out()

## Returns payout amounts keyed by stable session seat id.
func settle() -> Dictionary:
	assert(_hand_state != null, "session has no active hand")
	var local_payouts: Dictionary = _hand_state.settle()
	_sync_stacks()
	var payouts: Dictionary = {}
	for local_seat in local_payouts:
		payouts[_active_seats[local_seat]] = local_payouts[local_seat]
	return payouts

## Current stack for each stable seat, including in-hand stack reductions.
func stacks() -> Array[int]:
	var out := _stacks.duplicate()
	if _hand_state != null:
		var current := _hand_state.stacks()
		for local_seat in range(_active_seats.size()):
			out[_active_seats[local_seat]] = current[local_seat]
	return out

## Viewer-safe table snapshot using stable session seat ids.
func snapshot(viewer_seat: int = -1) -> Dictionary:
	assert(_hand_state != null, "session has no active hand")
	assert(viewer_seat == -1 or (viewer_seat >= 0 and viewer_seat < _stacks.size()),
		"viewer seat index out of range")
	var local_viewer := _active_seats.find(viewer_seat)
	var state := _hand_state.snapshot(local_viewer)
	var rows: Array = state["seats"]
	for local_seat in range(rows.size()):
		var row: Dictionary = rows[local_seat]
		row["id"] = _active_seats[local_seat]
		rows[local_seat] = row
	for stable_seat in range(_stacks.size()):
		if not _active_seats.has(stable_seat):
			rows.append({
				id = stable_seat,
				stack = 0,
				street_commitment = 0,
				total_commitment = 0,
				folded = false,
				all_in = false,
				cards = [],
				hidden_cards = 0,
				out = true,
			})
	rows.sort_custom(func(a, b): return a["id"] < b["id"])
	state["seats"] = rows
	var actor: int = state["current_actor"]
	state["current_actor"] = -1 if actor < 0 else _active_seats[actor]
	state["button"] = button_seat
	state["hand_number"] = hand_number
	var pots: Array = state["pots"]
	for pot_index in range(pots.size()):
		var pot: Dictionary = pots[pot_index]
		var stable_eligible: Array[int] = []
		for local_seat in pot["eligible"]:
			stable_eligible.append(_active_seats[local_seat])
		pot["eligible"] = stable_eligible
		pots[pot_index] = pot
	state["pots"] = pots
	return state

func _deal_hand(deal_order: Array[PokerCard]) -> bool:
	_active_seats.clear()
	for seat_id in range(_stacks.size()):
		if _stacks[seat_id] > 0:
			_active_seats.append(seat_id)
	if _active_seats.size() < 2:
		return false
	if not _active_seats.has(button_seat):
		button_seat = _next_funded_at_or_after(button_seat)
	var local_button := _active_seats.find(button_seat)
	var active_stacks: Array[int] = []
	for seat_id in _active_seats:
		active_stacks.append(_stacks[seat_id])
	_hand_state = PokerGameState.new(
		active_stacks, local_button, small_blind, big_blind, rng, deal_order)
	hand_number += 1
	return true

func _sync_stacks() -> void:
	var current := _hand_state.stacks()
	for local_seat in range(_active_seats.size()):
		_stacks[_active_seats[local_seat]] = current[local_seat]

func _funded_seat_count() -> int:
	var count := 0
	for stack in _stacks:
		if stack > 0:
			count += 1
	return count

func _next_funded_after(seat_id: int) -> int:
	for step in range(1, _stacks.size() + 1):
		var candidate := (seat_id + step) % _stacks.size()
		if _stacks[candidate] > 0:
			return candidate
	return seat_id

func _next_funded_at_or_after(seat_id: int) -> int:
	for step in range(_stacks.size()):
		var candidate := (seat_id + step) % _stacks.size()
		if _stacks[candidate] > 0:
			return candidate
	return seat_id
