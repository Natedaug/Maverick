extends SceneTree
## Headless tests for PokerSession stable seats and button rotation.
## Run: godot --headless --script tests/test_session.gd

var _failures := 0
var _passes := 0

func _init() -> void:
	_test_zero_stack_seats_and_button_rotation()
	print("PASSES: %d" % _passes)
	print("FAILURES: %d" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _test_zero_stack_seats_and_button_rotation() -> void:
	var session := PokerSession.new([500, 0, 500, 500], 0, 50, 100)
	_check(session.start_hand(), "first hand starts with three funded seats")
	_check(session.current_actor() == 0, "button seat acts first preflop")
	var view := session.snapshot(0)
	_check(view.seats.size() == 4 and view.seats[1].out,
		"snapshot preserves stable ids and marks empty seat out")
	_check(session.apply_action(0, PokerBetting.Action.FOLD), "button folds")
	_check(session.current_actor() == 2, "turn maps back to stable seat 2")
	_check(session.apply_action(2, PokerBetting.Action.FOLD), "small blind folds")
	_check(session.settle() == {3: 150}, "big blind receives uncontested pot by stable id")
	_check(session.start_next_hand(), "next hand starts after settlement")
	_check(session.button_seat == 2, "button rotates past the empty seat")
	_check(session.current_actor() == 2, "next hand retains stable action ids")
