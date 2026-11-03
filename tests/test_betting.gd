extends SceneTree
## Headless test for PokerBetting (blinds, action cycle, all-in handling).
## Run: godot --headless --script tests/test_betting.gd

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_betting.gd ===")
	_test_blinds_posted()
	_test_blinds_oversized_stack_allin()
	_test_illegal_check_facing_bet()
	_test_illegal_call_when_nothing_to_call()
	_test_heads_up_call_and_check_ends_round()
	_test_three_way_raise_cycle()
	_test_min_raise_enforced()
	_test_raise_allin_below_min_raise_allowed()
	_test_allin_raise_reopens_betting()
	_test_allin_call_caps_at_stack()
	_test_everyone_folds_ends_round()
	_test_everyone_allin_ends_round()
	_test_street_reset()
	_test_illegal_action_leaves_state_untouched()
	_test_action_wraps_to_seat_zero()

	print("")
	print("PASSES: %d" % _passes)
	print("FAILURES: %d" % _failures)
	if _failures > 0:
		print("❌ TESTS FAILED")
		quit(1)
	else:
		print("✅ ALL TESTS PASSED")
		quit(0)

# --- Helpers ---

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + msg)

## 3 live seats of 1000 chips, seat 0 = SB, seat 1 = BB, seat 2 = button/UTG.
static func _three_handed() -> PokerBetting:
	return PokerBetting.new([1000, 1000, 1000], 0, 1, 50, 100)

# --- Tests ---

func _test_blinds_posted() -> void:
	var b := _three_handed()
	_check(b.pot() == 150, "blinds total 150 (got %d)" % b.pot())
	_check(b.current_bet == 100, "current bet = BB (got %d)" % b.current_bet)
	_check(b.to_act == 2, "UTG (seat after BB) acts first (got %d)" % b.to_act)
	_check(not b.is_round_over(), "round not over while action pending")

func _test_blinds_oversized_stack_allin() -> void:
	# 30-chip seat can't cover the SB; commits all-in
	var b := PokerBetting.new([30, 1000], 0, 1, 50, 100)
	_check(b.seats[0].all_in, "short blind seat is all-in (30 < SB 50)")
	_check(b.seats[0].committed == 30, "committed capped at stack (got %d)" % b.seats[0].committed)
	_check(b.current_bet == 100, "current bet still nominal BB (got %d)" % b.current_bet)

func _test_illegal_check_facing_bet() -> void:
	var b := _three_handed()
	_check(not b.is_legal(PokerBetting.Action.CHECK), "check illegal facing BB")
	_check(not b.apply(PokerBetting.Action.CHECK), "apply rejects check facing BB")

func _test_illegal_call_when_nothing_to_call() -> void:
	var b := PokerBetting.new([1000, 1000], 0, 1, 50, 100)
	# SB completed; now BB faces nothing
	_check(b.apply(PokerBetting.Action.CALL), "SB completes to BB")
	_check(not b.is_legal(PokerBetting.Action.CALL), "call illegal when matched")

func _test_heads_up_call_and_check_ends_round() -> void:
	var b := PokerBetting.new([1000, 1000], 0, 1, 50, 100)
	_check(b.apply(PokerBetting.Action.CALL), "SB calls")
	_check(b.seats[0].committed == 100, "SB completed to 100 (got %d)" % b.seats[0].committed)
	_check(b.to_act == 1, "BB acts next (got %d)" % b.to_act)
	_check(b.apply(PokerBetting.Action.CHECK), "BB checks its option")
	_check(b.is_round_over(), "round over after SB call + BB check")
	_check(b.pot() == 200, "pot = 200 (got %d)" % b.pot())

func _test_three_way_raise_cycle() -> void:
	var b := _three_handed()
	_check(b.apply(PokerBetting.Action.RAISE, 300), "UTG raises to 300")
	_check(b.seats[2].committed == 300, "UTG committed 300 (got %d)" % b.seats[2].committed)
	_check(b.to_act == 0, "SB acts next (got %d)" % b.to_act)
	_check(b.apply(PokerBetting.Action.CALL), "SB calls")
	_check(b.apply(PokerBetting.Action.CALL), "BB calls")
	_check(b.is_round_over(), "round over after everyone matched")
	_check(b.pot() == 900, "pot = 900 (got %d)" % b.pot())
	_check(b.remaining() == 3, "3 players remain");

func _test_min_raise_enforced() -> void:
	var b := _three_handed()
	# min raise-to = current_bet (100) + min raise size (BB 100) = 200
	_check(not b.is_legal(PokerBetting.Action.RAISE, 150), "raise to 150 < min 200 illegal")
	_check(not b.apply(PokerBetting.Action.RAISE, 150), "apply rejects short raise")
	_check(b.current_bet == 100, "state unchanged after rejection")
	_check(b.apply(PokerBetting.Action.RAISE, 200), "raise to 200 legal")
	_check(b.apply(PokerBetting.Action.CALL), "SB calls")
	_check(b.is_round_over() == false, "BB still must act")
	_check(b.apply(PokerBetting.Action.CALL), "BB calls")
	_check(b.is_round_over(), "round over")

func _test_raise_allin_below_min_raise_allowed() -> void:
	# BB with 250 chips can't make a legal min-raise; short all-in must be allowed
	var b := PokerBetting.new([1000, 1000, 250], 1, 2, 50, 100)  # seat 2 = BB (250 chips)
	_check(b.apply(PokerBetting.Action.RAISE, 200), "UTG raises to 200")
	_check(b.apply(PokerBetting.Action.CALL), "SB calls")
	_check(b.to_act == 2, "BB next (got %d)" % b.to_act)
	_check(not b.is_legal(PokerBetting.Action.RAISE, 220), "short non-all-in raise illegal")
	_check(b.is_legal(PokerBetting.Action.RAISE, 250), "all-in for 250 legal despite short raise")
	_check(b.apply(PokerBetting.Action.RAISE, 250), "BB shoves 250")
	_check(b.seats[2].all_in, "BB all-in")
	_check(b.current_bet == 250, "current bet = 250 (got %d)" % b.current_bet)
	_check(b.apply(PokerBetting.Action.CALL), "UTG calls the extra 50")
	_check(b.apply(PokerBetting.Action.CALL), "SB calls the extra 50")
	_check(b.is_round_over(), "all matched")
	_check(b.pot() == 750, "pot 750 (3 x 250) (got %d)" % b.pot())

func _test_allin_raise_reopens_betting() -> void:
	var b := PokerBetting.new([2000, 2000, 2000], 0, 1, 50, 100)
	_check(b.apply(PokerBetting.Action.RAISE, 300), "UTG raises to 300")
	_check(b.apply(PokerBetting.Action.CALL), "SB calls")
	_check(b.to_act == 1, "BB next (got %d)" % b.to_act)
	_check(b.apply(PokerBetting.Action.RAISE, 1500), "BB shoves 1500")
	_check(b.current_bet == 1500, "current bet 1500 (got %d)" % b.current_bet)
	_check(b.to_act == 2, "UTG must act again after raise (got %d)" % b.to_act)
	_check(b.apply(PokerBetting.Action.CALL), "UTG calls")
	_check(b.apply(PokerBetting.Action.CALL), "SB calls")
	_check(b.is_round_over(), "all matched after reopen")
	_check(b.pot() == 4500, "pot 4500 (got %d)" % b.pot())

func _test_allin_call_caps_at_stack() -> void:
	# Seat 0 has 200 chips and acts first; blinds are seats 1 (SB) and 2 (BB)
	var b := PokerBetting.new([200, 2000, 2000], 1, 2, 50, 100)
	_check(b.current_bet == 100, "facing BB")
	_check(b.to_act == 0, "seat 0 acts first (got %d)" % b.to_act)
	_check(b.apply(PokerBetting.Action.CALL), "UTG calls")
	_check(b.seats[0].committed == 100, "UTG committed 100 (got %d)" % b.seats[0].committed)
	_check(b.apply(PokerBetting.Action.RAISE, 600), "SB raises to 600")
	_check(b.apply(PokerBetting.Action.CALL), "BB calls")
	_check(b.to_act == 0, "UTG must respond to raise (got %d)" % b.to_act)
	_check(not b.is_legal(PokerBetting.Action.RAISE, 700), "can't raise beyond stack")
	_check(b.apply(PokerBetting.Action.CALL), "UTG calls all-in for what he has")
	_check(b.seats[0].all_in, "UTG all-in")
	_check(b.seats[0].committed == 200, "UTG committed all 200 (got %d)" % b.seats[0].committed)
	_check(b.is_round_over(), "round over")
	_check(b.pot() == 1400, "pot 600+600+200 (got %d)" % b.pot())

func _test_everyone_folds_ends_round() -> void:
	var b := _three_handed()
	_check(b.apply(PokerBetting.Action.FOLD), "UTG folds")
	_check(b.apply(PokerBetting.Action.FOLD), "SB folds")
	_check(not b.is_round_over(), "BB still owes its option")
	_check(b.apply(PokerBetting.Action.CHECK), "BB takes the pot uncontested")
	_check(b.is_round_over(), "round over")
	_check(b.remaining() == 1, "1 player remains")
	_check(b.pot() == 150, "folded players leave blinds in pot (got %d)" % b.pot())

func _test_everyone_allin_ends_round() -> void:
	# SB (50) and UTG (100) both all-in; BB keeps chips to take its option
	var b := PokerBetting.new([50, 150, 100], 0, 1, 50, 100)
	_check(b.seats[0].all_in, "SB all-in from blind")
	_check(b.apply(PokerBetting.Action.CALL), "UTG calls to 100")
	_check(b.seats[2].all_in, "UTG called all-in (had exactly 100)")
	_check(b.to_act == 1, "BB still owes its option (got %d)" % b.to_act)
	_check(b.apply(PokerBetting.Action.CHECK), "BB checks")
	_check(b.is_round_over(), "everyone all-in or matched -> round over")

func _test_street_reset() -> void:
	var b := _three_handed()
	_check(b.apply(PokerBetting.Action.CALL), "UTG calls")
	_check(b.apply(PokerBetting.Action.CALL), "SB calls")
	_check(b.apply(PokerBetting.Action.CHECK), "BB checks")
	_check(b.is_round_over(), "preflop round over")
	_check(b.pot() == 300, "preflop pot 300 (got %d)" % b.pot())
	b.start_street(1)  # SB acts first postflop
	_check(b.pot() == 0, "street pot reset (got %d)" % b.pot())
	_check(b.current_bet == 0, "current bet reset")
	_check(b.to_act == 1, "SB acts first postflop (got %d)" % b.to_act)
	# first bet postflop must be at least the BB
	_check(not b.is_legal(PokerBetting.Action.BET, 30), "bet below BB illegal")
	_check(b.apply(PokerBetting.Action.BET, 100), "bet of BB legal")
	_check(b.current_bet == 100, "current bet after bet (got %d)" % b.current_bet)

func _test_illegal_action_leaves_state_untouched() -> void:
	var b := _three_handed()
	var before_pot: int = b.pot()
	var before_to_act: int = b.to_act
	_check(not b.apply(PokerBetting.Action.RAISE, 50), "short raise rejected")
	_check(b.pot() == before_pot, "pot unchanged after reject")
	_check(b.to_act == before_to_act, "to_act unchanged after reject")
	_check(not b.apply(PokerBetting.Action.CHECK), "check rejected facing bet")

func _test_action_wraps_to_seat_zero() -> void:
	# BB is the last seat: action wraps from BB around to seat 0
	var b := PokerBetting.new([1000, 1000, 1000], 1, 2, 50, 100)
	_check(b.to_act == 0, "first to act wraps to seat 0 (got %d)" % b.to_act)
	_check(b.apply(PokerBetting.Action.RAISE, 200), "seat 0 raises to 200")
	_check(b.to_act == 1, "SB next (got %d)" % b.to_act)
