class_name EconomyBridge extends RefCounted
## Coordinates a PokerSession with persistent wallet, town state, and table
## reputation. Observes settlement results only — never duplicates poker rules.
## All data objects are explicit (not autoloads); services receive what they need.

var session
var wallet
var town_state
var table_reputation
var player_seat

var _stack_at_hand_start: int = 0
var _hand_in_progress: bool = false

## Record the player's session stack at the start of a hand. Call this BEFORE
## PokerSession.start_hand() / start_next_hand(), so the recorded stack is the
## pre-blind stack and blinds are captured as part of the hand result.
func hand_started() -> void:
	_stack_at_hand_start = int(session.stacks()[player_seat])
	_hand_in_progress = true

## Call after PokerSession.settle(). Computes the player's net stack change for
## the hand (session stack before vs after, buy-ins/cash-outs excluded) and
## updates town state and table reputation.
func hand_settled() -> void:
	if not _hand_in_progress:
		return
	var stack_after := int(session.stacks()[player_seat])
	var net_delta := stack_after - _stack_at_hand_start
	town_state.apply_hand_result(net_delta)
	table_reputation.apply_hand_result(net_delta)
	_hand_in_progress = false

## Cash out the player's remaining session stack to the wallet. Returns the
## amount cashed out. Call once when the player leaves the table.
func cash_out() -> int:
	var remaining := int(session.stacks()[player_seat])
	wallet.cash_out(remaining)
	_hand_in_progress = false
	return remaining
