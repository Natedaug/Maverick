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
	_test_dead_zone_no_change()
	_test_emboldened_resists_folding()
	_test_wary_folds_more_to_aggression()
	_test_wary_abandons_bluffs_not_value_bets()
	_test_timing_tell_follows_memory()
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

func _test_dead_zone_no_change() -> void:
	var ai := _ai(0.4)
	var r := _rate(ai, {action = PokerBetting.Action.FOLD}, 0.1, 40, PokerBetting.Action.CALL)
	_check(r == 0.0, "weight inside dead zone never shifts (rate %f)" % r)

func _test_emboldened_resists_folding() -> void:
	var r := _rate(_ai(5.0), {action = PokerBetting.Action.FOLD}, 0.1, 40, PokerBetting.Action.CALL)
	_check(r > 0.10 and r < 0.20, "emboldened rival calls instead of folding ~15%% (rate %f)" % r)
	var free := _rate(_ai(5.0), {action = PokerBetting.Action.FOLD}, 0.1, 0, PokerBetting.Action.CALL)
	_check(free == 0.0, "no shift when there is nothing to call")

func _test_wary_folds_more_to_aggression() -> void:
	var r := _rate(_ai(-5.0), {action = PokerBetting.Action.CALL}, 0.4, 40, PokerBetting.Action.FOLD)
	_check(r > 0.10 and r < 0.20, "wary rival folds to a bet ~15%% (rate %f)" % r)
	var mild := _rate(_ai(-1.0), {action = PokerBetting.Action.CALL}, 0.4, 40, PokerBetting.Action.FOLD)
	_check(mild > 0.04 and mild < r, "smaller grievance, smaller shift (rate %f)" % mild)

func _test_wary_abandons_bluffs_not_value_bets() -> void:
	var bet := {action = PokerBetting.Action.BET, frac = 0.6}
	var bluff := _rate(_ai(-5.0), bet, 0.2, 0, PokerBetting.Action.CHECK)
	_check(bluff > 0.10 and bluff < 0.20, "wary rival abandons a bluff ~15%% (rate %f)" % bluff)
	var value := _rate(_ai(-5.0), bet, 0.8, 0, PokerBetting.Action.CHECK)
	_check(value == 0.0, "value bets are untouched (rate %f)" % value)

func _test_timing_tell_follows_memory() -> void:
	var counts := {}
	for weight in [-2.0, 0.0, 2.0]:
		var ai := _ai(weight, 11)
		var tally := {tank = 0, snap = 0, normal = 0}
		for i in range(TRIALS):
			tally[ai.pick_timing()] += 1
		counts[weight] = tally
	_check(counts[-2.0].snap > counts[-2.0].tank * 3, "wary rival mostly snaps (%s)" % str(counts[-2.0]))
	_check(counts[2.0].tank > counts[2.0].snap * 3, "emboldened rival mostly tanks (%s)" % str(counts[2.0]))
	_check(counts[0.0].tank > 0 and counts[0.0].snap > 0 and counts[0.0].normal > counts[0.0].tank,
		"neutral rival mixes rhythms (%s)" % str(counts[0.0]))
	_check(counts[-2.0].tank > 0 and counts[2.0].snap > 0, "tell is never deterministic")

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
