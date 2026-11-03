extends SceneTree
## Headless test for TownState.
## Run: godot --headless --script tests/test_town_state.gd

const TownState = preload("res://src/world/town_state.gd")

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_town_state.gd ===")
	_test_initial_state()
	_test_winning_hand_increases_prosperity()
	_test_losing_hand_decreases_prosperity()
	_test_push_no_change()
	_test_transition_to_prosperous()
	_test_transition_to_stressed()
	_test_prosperity_resets_after_transition()
	_test_poker_volume_increments()

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

func _test_initial_state() -> void:
	var t: TownState = TownState.new()
	t.town_id = "rusty_spur"
	_check(t.town_id == "rusty_spur", "town_id set")
	_check(t.prosperity == 0, "prosperity starts at 0")
	_check(t.poker_volume == 0, "poker_volume starts at 0")
	_check(t.state == "neutral", "state starts neutral")

func _test_winning_hand_increases_prosperity() -> void:
	var t: TownState = TownState.new()
	t.apply_hand_result(100)
	_check(t.prosperity == 1, "prosperity +1 on win (got %d)" % t.prosperity)
	_check(t.poker_volume == 1, "poker_volume +1 (got %d)" % t.poker_volume)

func _test_losing_hand_decreases_prosperity() -> void:
	var t: TownState = TownState.new()
	t.apply_hand_result(-50)
	_check(t.prosperity == -1, "prosperity -1 on loss (got %d)" % t.prosperity)

func _test_push_no_change() -> void:
	var t: TownState = TownState.new()
	t.apply_hand_result(0)
	_check(t.prosperity == 0, "prosperity unchanged on push")
	_check(t.poker_volume == 1, "poker_volume still increments")

func _test_transition_to_prosperous() -> void:
	var t: TownState = TownState.new()
	t.apply_hand_result(10)
	t.apply_hand_result(10)
	t.apply_hand_result(10)
	_check(t.state == "prosperous", "state = prosperous (got %s)" % t.state)
	_check(t.prosperity == 0, "prosperity reset after transition (got %d)" % t.prosperity)

func _test_transition_to_stressed() -> void:
	var t: TownState = TownState.new()
	t.apply_hand_result(-10)
	t.apply_hand_result(-10)
	t.apply_hand_result(-10)
	_check(t.state == "stressed", "state = stressed (got %s)" % t.state)
	_check(t.prosperity == 0, "prosperity reset after transition (got %d)" % t.prosperity)

func _test_prosperity_resets_after_transition() -> void:
	var t: TownState = TownState.new()
	t.apply_hand_result(10)
	t.apply_hand_result(10)
	t.apply_hand_result(10)
	_check(t.prosperity == 0, "prosperity reset to 0 after transition (got %d)" % t.prosperity)
	t.apply_hand_result(10)
	_check(t.prosperity == 1, "prosperity restarts from 0 (got %d)" % t.prosperity)

func _test_poker_volume_increments() -> void:
	var t: TownState = TownState.new()
	t.apply_hand_result(10)
	t.apply_hand_result(-10)
	t.apply_hand_result(0)
	_check(t.poker_volume == 3, "poker_volume = 3 (got %d)" % t.poker_volume)
