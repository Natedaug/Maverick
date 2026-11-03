extends SceneTree
## Headless test for TableReputation.
## Run: godot --headless --script tests/test_table_reputation.gd

const TableReputation = preload("res://src/world/table_reputation.gd")

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_table_reputation.gd ===")
	_test_initial_label_unknown()
	_test_winning_hands_make_known_winner()
	_test_losing_hands_make_known_loser()
	_test_mixed_hands_return_to_unknown()
	_test_lifetime_net_accumulates()

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

func _test_initial_label_unknown() -> void:
	var r: TableReputation = TableReputation.new()
	r.table_id = "rusty_spur"
	_check(r.get_label() == "unknown", "new table reputation is unknown")

func _test_winning_hands_make_known_winner() -> void:
	var r: TableReputation = TableReputation.new()
	r.apply_hand_result(50)
	r.apply_hand_result(25)
	_check(r.lifetime_net == 75, "lifetime_net accumulates (got %d)" % r.lifetime_net)
	_check(r.get_label() == "known winner", "label = known winner (got %s)" % r.get_label())

func _test_losing_hands_make_known_loser() -> void:
	var r: TableReputation = TableReputation.new()
	r.apply_hand_result(-100)
	r.apply_hand_result(-50)
	_check(r.lifetime_net == -150, "lifetime_net accumulates (got %d)" % r.lifetime_net)
	_check(r.get_label() == "known loser", "label = known loser (got %s)" % r.get_label())

func _test_mixed_hands_return_to_unknown() -> void:
	var r: TableReputation = TableReputation.new()
	r.apply_hand_result(100)
	r.apply_hand_result(-100)
	_check(r.lifetime_net == 0, "lifetime_net returns to zero")
	_check(r.get_label() == "unknown", "label = unknown when net is zero")

func _test_lifetime_net_accumulates() -> void:
	var r: TableReputation = TableReputation.new()
	r.apply_hand_result(10)
	r.apply_hand_result(-5)
	r.apply_hand_result(3)
	_check(r.lifetime_net == 8, "lifetime_net = 8 (got %d)" % r.lifetime_net)
