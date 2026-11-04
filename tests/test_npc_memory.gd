extends SceneTree
## Headless test for NPCMemory.
## Run: godot --headless --path . -s tests/test_npc_memory.gd

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_npc_memory.gd ===")
	_test_signed_weights_no_clamp()
	_test_event_counters_and_unknown_event()
	_test_finish_hand_decays_and_counts_once()
	_test_starts_kempt_and_events_wait_for_hand_end()
	_test_tilt_turns_unkempt_and_holds()
	_test_winning_pots_clean_him_up()
	_test_bias_only_while_unkempt()
	_test_dict_round_trip()

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

func _test_signed_weights_no_clamp() -> void:
	var m := NPCMemory.new()
	for h in range(1, 4):
		m.record_event("suck_out_suffered", h)
	_check(absf(m.weight + 0.75) < 0.001, "weight goes negative, unclamped (got %f)" % m.weight)
	m.record_event("stone_cold_worked", 4)
	_check(m.weight < 0.0, "negative history persists after a positive event (got %f)" % m.weight)
	for h in range(10):
		m.record_event("stone_cold_caught", 5 + h)
	_check(m.weight < -2.0, "raw weight is stored beyond the soft clamp (got %f)" % m.weight)

func _test_event_counters_and_unknown_event() -> void:
	var m := NPCMemory.new()
	m.record_event("suck_out_delivered", 1)
	m.record_event("stone_cold_caught", 1)
	m.record_event("folded_to_aggression", 1)
	m.record_event("cooler_loss", 1)
	_check(m.suck_outs_delivered == 1 and m.stone_cold_bluffs == 1 \
		and m.folded_to_aggression == 1, "lifetime counters increment")
	_check(m.hands_seen == 0, "events alone do not count hands")
	var before := m.weight
	_check(not m.record_event("nonsense", 1), "unknown event rejected")
	_check(m.weight == before, "unknown event leaves weight unchanged")

func _test_finish_hand_decays_and_counts_once() -> void:
	var m := NPCMemory.new()
	m.record_event("suck_out_suffered", 3)
	m.record_event("folded_to_aggression", 3)
	m.finish_hand(3)
	_check(m.hands_seen == 1 and m.last_seen_hand == 3, "one hand counted")
	_check(absf(m.weight - (-0.35 * 0.97)) < 0.001, "decay 0.97 applied once (got %f)" % m.weight)
	_check(m.suck_outs_suffered == 1, "decay does not touch counters")

func _test_starts_kempt_and_events_wait_for_hand_end() -> void:
	var m := NPCMemory.new()
	_check(m.kempt, "a fresh rival is kempt")
	m.record_event("stone_cold_caught", 1)
	m.record_event("suck_out_suffered", 1)
	_check(m.weight <= -NPCMemory.UNKEMPT_AT, "tilted enough (weight %f)" % m.weight)
	_check(m.kempt, "appearance does not change mid-hand")
	m.finish_hand(1)
	_check(not m.kempt, "unkempt once the hand is over")

func _test_tilt_turns_unkempt_and_holds() -> void:
	var m := NPCMemory.new()
	m.record_event("suck_out_suffered", 1)
	m.finish_hand(1)
	_check(m.kempt, "one bad beat is not enough (weight %f)" % m.weight)
	m.record_event("suck_out_suffered", 2)
	m.record_event("folded_to_aggression", 2)
	m.finish_hand(2)
	_check(not m.kempt, "repeated bad beats make him unkempt (weight %f)" % m.weight)
	var hands := 0
	var h := 3
	while not m.kempt and hands < 100:
		m.finish_hand(h)
		h += 1
		hands += 1
	_check(hands >= 10, "the look holds for several hands, no flicker (%d)" % hands)
	_check(m.kempt and hands < 100, "with no new tilt he cleans up eventually (%d)" % hands)
	var winner := NPCMemory.new()
	for i in range(10):
		winner.record_event("suck_out_delivered", i)
		winner.finish_hand(i)
	_check(winner.kempt, "a rival who is winning stays kempt")

func _test_winning_pots_clean_him_up() -> void:
	var m := NPCMemory.new()
	m.weight = -0.6
	m.finish_hand(1)
	_check(not m.kempt, "tilted rival is unkempt")
	m.record_event("stone_cold_worked", 2)
	m.record_event("suck_out_delivered", 2)
	m.finish_hand(2)
	_check(m.kempt, "taking pots off the player calms him down (weight %f)" % m.weight)

func _test_bias_only_while_unkempt() -> void:
	var m := NPCMemory.new()
	m.weight = -10.0
	_check(m.get_bias() == 0.0, "kempt rival has no memory bias, however burned")
	m.finish_hand(1)
	_check(absf(m.get_bias() - 0.15) < 0.001, "deep tilt caps at 0.15 (got %f)" % m.get_bias())
	m.weight = -0.3
	var floor_bias := NPCMemory.UNKEMPT_MIN_SHARE * NPCMemory.WEIGHT_BIAS_CAP
	_check(absf(m.get_bias() - floor_bias) < 0.001, "still unkempt, still a little loose (got %f)" % m.get_bias())
	m.weight = -1.0
	_check(absf(m.get_bias() - 0.075) < 0.001, "loose shift scales with tilt (got %f)" % m.get_bias())
	var up := NPCMemory.new()
	up.weight = 10.0
	up.finish_hand(1)
	_check(up.get_bias() == 0.0, "positive weight never shifts decisions")

func _test_dict_round_trip() -> void:
	var m := NPCMemory.new()
	m.opponent_id = "0"
	m.record_event("suck_out_suffered", 1)
	m.record_event("stone_cold_caught", 1)
	m.finish_hand(2)
	var copy := NPCMemory.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	_check(copy.opponent_id == "0", "id survives JSON round trip")
	_check(absf(copy.weight - m.weight) < 0.0001, "weight survives")
	_check(copy.hands_seen == 1 and copy.last_seen_hand == 2, "hand counters survive")
	_check(copy.suck_outs_suffered == 1 and copy.stone_cold_bluffs == 1, "event counters survive")
	_check(not m.kempt and not copy.kempt, "unkempt look survives")
	var held := NPCMemory.from_dict({weight = -0.3, kempt = false})
	_check(not held.kempt, "a saved look inside the hysteresis band is kept")
	var legacy := NPCMemory.from_dict({weight = -0.8, recent_tanks = [1, 2, 3]})
	_check(not legacy.kempt, "an older save derives the look from weight")
	_check(NPCMemory.from_dict({weight = 0.4}).kempt, "an older save with mild weight is kempt")
