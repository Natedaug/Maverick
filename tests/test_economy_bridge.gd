extends SceneTree
## Headless test for EconomyBridge integration with PokerSession.
## Run: godot --headless --script tests/test_economy_bridge.gd

const Wallet = preload("res://src/economy/wallet.gd")
const TownState = preload("res://src/world/town_state.gd")
const TableReputation = preload("res://src/world/table_reputation.gd")
const EconomyBridge = preload("res://src/economy/economy_bridge.gd")
const PokerSession = preload("res://addons/poker_engine/session.gd")
const PokerBetting = preload("res://addons/poker_engine/betting.gd")

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_economy_bridge.gd ===")
	_test_buy_in_and_losing_hand()
	_test_winning_hand_and_cash_out()

	print("")
	print("PASSES: %d" % _passes)
	print("FAILURES: %d" % _failures)
	if _failures > 0:
		print("❌ TESTS FAILED")
		quit(1)
	else:
		print("✅ ALL TESTS PASSED")
		quit(0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + msg)

func _test_buy_in_and_losing_hand() -> void:
	# Wallet with 1000, player buys in for 500
	var wallet := Wallet.new()
	wallet.balance = 1000
	var ok := wallet.buy_in(500)
	_check(ok, "buy_in succeeds")
	_check(wallet.get_balance() == 500, "wallet debited (got %d)" % wallet.get_balance())

	# Session with player at seat 0, stack 500; button on seat 0 (player posts SB)
	var session := PokerSession.new([500, 1000], 0, 50, 100)
	var town := TownState.new()
	town.town_id = "rusty_spur"
	var rep := TableReputation.new()
	rep.table_id = "rusty_spur"
	var bridge := EconomyBridge.new()
	bridge.session = session
	bridge.wallet = wallet
	bridge.town_state = town
	bridge.table_reputation = rep
	bridge.player_seat = 0

	# Record pre-hand stack BEFORE start_hand (blinds not yet posted in _stacks)
	bridge.hand_started()
	_check(bridge._stack_at_hand_start == 500, "pre-hand stack recorded (got %d)" % bridge._stack_at_hand_start)

	var dealt := session.start_hand()
	_check(dealt, "first hand dealt")

	# Player (seat 0) is SB in heads-up, acts first preflop. Fold -> seat 1 wins.
	var acted := session.apply_action(0, PokerBetting.Action.FOLD)
	_check(acted, "player folds")
	var settled := session.settle()
	_check(settled.size() == 1, "settle returns payout")
	bridge.hand_settled()

	# Player stack: 500 - 50 (SB) = 450
	_check(session.stacks()[0] == 450, "player stack after fold (got %d)" % session.stacks()[0])
	# Town: net_delta = 450 - 500 = -50 -> prosperity -1, volume 1
	_check(town.prosperity == -1, "town prosperity -1 (got %d)" % town.prosperity)
	_check(town.poker_volume == 1, "town poker_volume 1 (got %d)" % town.poker_volume)
	_check(town.state == "neutral", "town state neutral (got %s)" % town.state)
	# Rep: lifetime_net -50 -> known loser
	_check(rep.lifetime_net == -50, "rep lifetime_net -50 (got %d)" % rep.lifetime_net)
	_check(rep.get_label() == "known loser", "rep label known loser (got %s)" % rep.get_label())
	# Wallet unchanged (buy-in debited before session, no cash-out yet)
	_check(wallet.get_balance() == 500, "wallet unchanged (got %d)" % wallet.get_balance())

func _test_winning_hand_and_cash_out() -> void:
	var wallet := Wallet.new()
	wallet.balance = 500
	# Player at seat 0, button on seat 1 (player posts BB)
	var session := PokerSession.new([500, 1000], 1, 50, 100)
	var town := TownState.new()
	town.town_id = "rusty_spur"
	var rep := TableReputation.new()
	rep.table_id = "rusty_spur"
	var bridge := EconomyBridge.new()
	bridge.session = session
	bridge.wallet = wallet
	bridge.town_state = town
	bridge.table_reputation = rep
	bridge.player_seat = 0

	# Record pre-hand stack BEFORE start_hand
	bridge.hand_started()
	_check(bridge._stack_at_hand_start == 500, "pre-hand stack recorded (got %d)" % bridge._stack_at_hand_start)

	var dealt := session.start_hand()
	_check(dealt, "hand dealt")

	# Seat 0 (BB) acts second preflop; seat 1 (SB) acts first.
	# Seat 1 folds -> seat 0 wins uncontested pot (150)
	var acted := session.apply_action(1, PokerBetting.Action.FOLD)
	_check(acted, "opponent folds")
	var settled := session.settle()
	bridge.hand_settled()

	# Player stack: 500 - 100 (BB) + 150 (pot won) = 550 after sync
	_check(session.stacks()[0] == 550, "player stack after win (got %d)" % session.stacks()[0])
	# net_delta = 550 - 500 = +50
	_check(town.prosperity == 1, "town prosperity +1 (got %d)" % town.prosperity)
	_check(town.poker_volume == 1, "town poker_volume 1 (got %d)" % town.poker_volume)
	_check(rep.lifetime_net == 50, "rep lifetime_net +50 (got %d)" % rep.lifetime_net)
	_check(rep.get_label() == "known winner", "rep label known winner (got %s)" % rep.get_label())

	# Cash out remaining session stack
	var cashed := bridge.cash_out()
	_check(cashed == 550, "cash_out returns 550 (got %d)" % cashed)
	_check(wallet.get_balance() == 1050, "wallet after cash_out (got %d)" % wallet.get_balance())
