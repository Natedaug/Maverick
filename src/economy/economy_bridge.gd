class_name EconomyBridge extends RefCounted
## Coordinates a PokerSession with persistent wallet, town state, and table
## reputation. Observes settlement results only — never duplicates poker rules.
## All data objects are explicit (not autoloads); services receive what they need.

var session
var wallet
var town_state
var table_reputation
var player_seat
## Prototype default only. Keep this editable until canonical currency values
## are chosen; one wallet unit per chip is not a world-economy decision.
var wallet_units_per_chip: float = 1.0

var _stack_at_hand_start: int = 0
var _hand_in_progress: bool = false
var _cashed_out: bool = false
var _buy_in_complete: bool = false

## Debit the configured wallet cost for a chip buy-in. The caller creates the
## PokerSession with this chip amount only after this succeeds.
func buy_in(chip_amount: int) -> bool:
	if _buy_in_complete or chip_amount <= 0 or wallet_units_per_chip <= 0.0:
		return false
	var wallet_cost := int(round(float(chip_amount) * wallet_units_per_chip))
	if wallet_cost <= 0 or not wallet.buy_in(wallet_cost):
		return false
	_buy_in_complete = true
	return true

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
## amount cashed out. Call once when the player leaves the table. Safe to call
## repeatedly — only the first call credits the wallet.
func cash_out() -> int:
	if _cashed_out:
		return 0
	_cashed_out = true
	var remaining := int(session.stacks()[player_seat])
	var wallet_credit := int(round(float(remaining) * wallet_units_per_chip))
	wallet.cash_out(wallet_credit)
	_hand_in_progress = false
	return remaining
