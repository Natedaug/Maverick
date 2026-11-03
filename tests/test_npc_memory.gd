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
	_test_tell_state_unkempt()
	_test_tell_state_kempt()
	_test_tell_state_neutral_and_window()
	_test_bias_dead_zone_scale_and_cap()
	_test_bluff_adjustment()
	_test_label()
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

func _test_tell_state_unkempt() -> void:
	var m := NPCMemory.new()
	for h in [1, 2, 3]:
		m.record_event("tank", h)
		m.finish_hand(h)
	_check(m.get_tell_state() == "unkempt", "3 tank hands in window = unkempt (got %s)" % m.get_tell_state())

func _test_tell_state_kempt() -> void:
	var m := NPCMemory.new()
	for h in [1, 2, 4]:
		m.record_event("snap", h)
	m.finish_hand(5)
	_check(m.get_tell_state() == "kempt", "3 snap hands in window = kempt (got %s)" % m.get_tell_state())

func _test_tell_state_neutral_and_window() -> void:
	var m := NPCMemory.new()
	m.record_event("tank", 1)
	m.record_event("snap", 2)
	_check(m.get_tell_state() == "neutral", "mixed rhythm = neutral")
	var old := NPCMemory.new()
	for h in [1, 2, 3]:
		old.record_event("tank", h)
	old.finish_hand(20)
	_check(old.get_tell_state() == "neutral", "tanks outside the 5-hand window expire")
	var dup := NPCMemory.new()
	for i in range(3):
		dup.record_event("tank", 7)
	_check(dup.tank_count == 1 and dup.get_tell_state() == "neutral", "repeat tanks in one hand count once")

func _test_bias_dead_zone_scale_and_cap() -> void:
	var m := NPCMemory.new()
	m.weight = 0.4
	_check(m.get_bias() == 0.0, "no bias inside the ±0.5 dead zone")
	m.weight = 1.0
	_check(absf(m.get_bias() - 0.075) < 0.001, "bias scales with weight (got %f)" % m.get_bias())
	m.weight = 10.0
	_check(absf(m.get_bias() - 0.15) < 0.001, "positive bias capped at 0.15 (got %f)" % m.get_bias())
	m.weight = -10.0
	_check(absf(m.get_bias() + 0.15) < 0.001, "negative bias capped at -0.15 (got %f)" % m.get_bias())

func _test_bluff_adjustment() -> void:
	var m := NPCMemory.new()
	_check(m.get_bluff_adjustment() == 0.0, "no history, no bluff change")
	m.suck_outs_delivered = 3
	_check(m.get_bluff_adjustment() > 0.0, "overconfident rival bluffs more")
	m.suck_outs_delivered = 0
	m.stone_cold_bluffs = 2
	_check(m.get_bluff_adjustment() < 0.0, "wary rival bluffs less")

func _test_label() -> void:
	var m := NPCMemory.new()
	_check(m.get_label() == "", "neutral label is empty")
	for h in [1, 2, 3]:
		m.record_event("tank", h)
	_check(m.get_label() == "Unkempt", "label = Unkempt (got %s)" % m.get_label())
	var k := NPCMemory.new()
	for h in [1, 2, 3]:
		k.record_event("snap", h)
	_check(k.get_label() == "Kempt", "label = Kempt (got %s)" % k.get_label())

func _test_dict_round_trip() -> void:
	var m := NPCMemory.new()
	m.opponent_id = "0"
	m.record_event("suck_out_suffered", 1)
	m.record_event("tank", 1)
	m.record_event("tank", 2)
	m.finish_hand(2)
	var copy := NPCMemory.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	_check(copy.opponent_id == "0", "id survives JSON round trip")
	_check(absf(copy.weight - m.weight) < 0.0001, "weight survives")
	_check(copy.hands_seen == 1 and copy.last_seen_hand == 2, "hand counters survive")
	_check(copy.suck_outs_suffered == 1 and copy.tank_count == 2, "event counters survive")
	_check(copy.recent_tanks == m.recent_tanks, "tell window survives")
