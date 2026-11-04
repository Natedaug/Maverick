extends SceneTree
## Headless test for memory-informed AI behavior (contract §4–§5).
## Run: godot --headless --path . -s tests/test_ai_memory_bias.gd
##
## Bias is probabilistic and capped at ±15%, so these checks sample many
## seeded decisions and assert rates within generous bounds.

const TRIALS := 4000

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_ai_memory_bias.gd ===")
	_test_no_memory_no_change()
	_test_kempt_rival_plays_straight()
	_test_unkempt_calls_lighter()
	_test_unkempt_bluffs_more()
	_test_unkempt_never_weakens_play()
	_test_timing_is_flavor_only()
	_test_session_decisions_stay_legal()

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

func _ai(weight: float, seed_value: int = 7) -> AIPlayer:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ai := AIPlayer.new(1, Strategy.new(rng))
	var mem := NPCMemory.new()
	mem.opponent_id = "0"
	mem.weight = weight
	mem.update_appearance()
	ai.set_memory(mem)
	return ai

## Fraction of TRIALS where `intent` became `changed_to`.
func _rate(ai: AIPlayer, intent: Dictionary, equity: float, call_amount: int, changed_to: int) -> float:
	var hits := 0
	for i in range(TRIALS):
		if ai.apply_memory_bias(intent, equity, call_amount).action == changed_to:
			hits += 1
	return float(hits) / TRIALS

func _test_no_memory_no_change() -> void:
	var ai := AIPlayer.new(1)
	_check(ai.memory == null, "no memory by default")
	var intent := {action = PokerBetting.Action.FOLD}
	_check(ai.apply_memory_bias(intent, 0.1, 40).action == PokerBetting.Action.FOLD, "no memory, intent unchanged")

func _test_kempt_rival_plays_straight() -> void:
	for weight in [0.0, 0.4, 5.0]:
		var ai := _ai(weight)
		_check(ai.memory.kempt, "weight %f is kempt" % weight)
		var r := _rate(ai, {action = PokerBetting.Action.FOLD}, 0.1, 40, PokerBetting.Action.CALL)
		_check(r == 0.0, "kempt rival (weight %f) never shifts (rate %f)" % [weight, r])

func _test_unkempt_calls_lighter() -> void:
	var ai := _ai(-5.0)
	_check(not ai.memory.kempt, "deeply tilted rival is unkempt")
	var r := _rate(ai, {action = PokerBetting.Action.FOLD}, 0.1, 40, PokerBetting.Action.CALL)
	_check(r > 0.10 and r < 0.20, "unkempt rival calls instead of folding ~15%% (rate %f)" % r)
	var mild := _rate(_ai(-0.6), {action = PokerBetting.Action.FOLD}, 0.1, 40, PokerBetting.Action.CALL)
	_check(mild > 0.02 and mild < r, "milder tilt, smaller shift (rate %f)" % mild)
	var free := _rate(ai, {action = PokerBetting.Action.FOLD}, 0.1, 0, PokerBetting.Action.CALL)
	_check(free == 0.0, "no call when there is nothing to call")

func _test_unkempt_bluffs_more() -> void:
	var check := {action = PokerBetting.Action.CHECK}
	var weak := _rate(_ai(-5.0), check, 0.2, 0, PokerBetting.Action.BET)
	_check(weak > 0.10 and weak < 0.20, "unkempt rival bluffs a weak hand ~15%% (rate %f)" % weak)
	var strong := _rate(_ai(-5.0), check, 0.8, 0, PokerBetting.Action.BET)
	_check(strong == 0.0, "only weak hands turn into bluffs (rate %f)" % strong)

func _test_unkempt_never_weakens_play() -> void:
	var ai := _ai(-5.0)
	var call := _rate(ai, {action = PokerBetting.Action.CALL}, 0.4, 40, PokerBetting.Action.FOLD)
	var bet := _rate(ai, {action = PokerBetting.Action.BET, frac = 0.6}, 0.2, 0, PokerBetting.Action.CHECK)
	_check(call == 0.0 and bet == 0.0, "tilt never adds folds or gives up bets (%f, %f)" % [call, bet])

func _test_timing_is_flavor_only() -> void:
	var counts := {}
	for weight in [-5.0, 0.0, 5.0]:
		var ai := _ai(weight, 11)
		var tally := {tank = 0, snap = 0, normal = 0}
		for i in range(TRIALS):
			tally[ai.pick_timing()] += 1
		counts[weight] = tally
	for weight in counts:
		var t: Dictionary = counts[weight]
		_check(t.tank > TRIALS * 0.15 and t.tank < TRIALS * 0.25 and t.snap > TRIALS * 0.15 \
			and t.snap < TRIALS * 0.25, "weight %f: ~20%% tank / ~20%% snap (%s)" % [weight, str(t)])

func _test_session_decisions_stay_legal() -> void:
	# Play many hands with extreme memory; every decision must be applied.
	for weight in [-5.0, 5.0]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var stacks: Array[int] = [2000, 2000]
		var session := PokerSession.new(stacks, 0, 10, 20, rng)
		var ai0 := _ai(0.0, 3)
		ai0.seat_index = 0
		ai0.equity_iterations = 20
		var ai1 := _ai(weight, 5)
		ai1.equity_iterations = 20
		var hands := 0
		var stuck := false
		session.start_hand()
		while hands < 25 and not stuck:
			var guard := 0
			while guard < 60:
				guard += 1
				if session.players_left() <= 1:
					break
				if session.is_street_over():
					if session.can_run_out():
						session.run_out()
						break
					if session.current_stage() == PokerGameState.Street.RIVER:
						break
					session.advance_street()
					continue
				var actor := session.current_actor()
				var before: int = session.snapshot(-1).get("current_actor", -2)
				(ai0 if actor == 0 else ai1).decide_session(session)
				if session.snapshot(-1).get("current_actor", -2) == before and not session.is_street_over() \
						and session.players_left() > 1:
					stuck = true
					break
			if stuck or guard >= 60:
				stuck = true
				break
			session.settle()
			hands += 1
			if not session.start_next_hand():
				break
		_check(not stuck, "weight %f: every AI decision was legal and applied" % weight)
		_check(hands > 0, "weight %f: hands completed (%d)" % [weight, hands])
