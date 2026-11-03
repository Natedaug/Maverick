extends SceneTree
## Headless test for RivalMemory hand attribution, using rigged decks.
## Run: godot --headless --path . -s tests/test_rival_memory.gd
##
## Deal order is top-first: seat 0 hole, seat 1 hole, then flop/turn/river.
## Seat 0 is the human player (button); seat 1 is the remembering rival.

const PLAYER := 0
const RIVAL := 1
const STACK := 500

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_rival_memory.gd ===")
	_test_get_memory_creates_independent_entries()
	_test_suck_out_suffered()
	_test_suck_out_delivered()
	_test_cooler_loss()
	_test_folded_to_aggression()
	_test_stone_cold_worked()
	_test_stone_cold_caught()
	_test_plain_showdown_records_nothing_but_decays()
	_test_timing_recorded_once_per_hand()
	_test_settlement_is_idempotent()

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

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001

# --- Helpers ---

func _deck(codes: Array[String]) -> Array[PokerCard]:
	var out: Array[PokerCard] = []
	var used: Dictionary = {}
	for code in codes:
		out.append(_card(code))
		used[code] = true
	for suit in range(4):
		for rank in range(2, 15):
			var card := PokerCard.new(suit as PokerCard.Suit, rank as PokerCard.Rank)
			if not used.has(card.to_code()):
				out.append(card)
	return out

func _card(code: String) -> PokerCard:
	var rank := "23456789TJQKA".find(code.substr(0, 1)) + 2
	var suit := "cdhs".find(code.substr(1, 1))
	return PokerCard.new(suit as PokerCard.Suit, rank as PokerCard.Rank)

func _new_hand(codes: Array[String]) -> Array:
	var stacks: Array[int] = [STACK, STACK]
	var session := PokerSession.new(stacks, PLAYER, 10, 20)
	_check(session.start_hand(_deck(codes)), "rigged hand starts")
	var rm := RivalMemory.new()
	rm.begin_hand(session, RIVAL)
	return [session, rm]

func _call_amount(session: PokerSession) -> int:
	for option in session.available_actions():
		if option.get("action", -1) == PokerBetting.Action.CALL:
			return int(option.get("amount", 0))
	return 0

## Apply one action and report it to the rival memory, as the table does.
func _act(session: PokerSession, rm: RivalMemory, action: PokerBetting.Action, amount: int = 0) -> void:
	var seat := session.current_actor()
	var facing := _call_amount(session) > 0
	_check(session.apply_action(seat, action, amount), "seat %d action %d legal" % [seat, action])
	rm.observe_action(seat, action, facing)

## Check/call every remaining decision until the river round is over.
func _passive_to_river(session: PokerSession, rm: RivalMemory) -> void:
	var guard := 0
	while guard < 40:
		guard += 1
		if session.players_left() <= 1:
			return
		if session.is_street_over():
			if session.current_stage() == PokerGameState.Street.RIVER:
				return
			session.advance_street()
			continue
		var action := PokerBetting.Action.CALL if _call_amount(session) > 0 else PokerBetting.Action.CHECK
		_act(session, rm, action)

func _settle(session: PokerSession, rm: RivalMemory) -> NPCMemory:
	rm.record_settlement(session, session.settle())
	return rm.get_memory(str(PLAYER))

# --- Tests ---

func _test_get_memory_creates_independent_entries() -> void:
	var rm := RivalMemory.new()
	var m0 := rm.get_memory("0")
	var m1 := rm.get_memory("1")
	_check(m0.opponent_id == "0" and m1.opponent_id == "1", "entries keyed by opponent id")
	_check(rm.get_memory("0") == m0, "get_memory returns the same entry")
	m0.weight = 5.0
	_check(m1.weight == 0.0, "entries are independent")

func _test_suck_out_suffered() -> void:
	# Turn: rival pair of aces beats player's sevens. River 7h: player trips.
	var h := _new_hand(["7c", "7d", "As", "Kd", "Ah", "9c", "4s", "2d", "7h"])
	_passive_to_river(h[0], h[1])
	var mem := _settle(h[0], h[1])
	_check(mem.suck_outs_suffered == 1, "suck-out suffered recorded (got %d)" % mem.suck_outs_suffered)
	_check(mem.suck_outs_delivered == 0, "no suck-out delivered")
	_check(_near(mem.weight, -0.25 * NPCMemory.DECAY_RATE), "weight -0.25 then decayed (got %f)" % mem.weight)
	_check(mem.hands_seen == 1 and mem.last_seen_hand == 1, "hand counted once")

func _test_suck_out_delivered() -> void:
	var h := _new_hand(["As", "Kd", "7c", "7d", "Ah", "9c", "4s", "2d", "7h"])
	_passive_to_river(h[0], h[1])
	var mem := _settle(h[0], h[1])
	_check(mem.suck_outs_delivered == 1, "suck-out delivered recorded (got %d)" % mem.suck_outs_delivered)
	_check(mem.suck_outs_suffered == 0, "no suck-out suffered")
	_check(_near(mem.weight, 0.15 * NPCMemory.DECAY_RATE), "weight +0.15 then decayed (got %f)" % mem.weight)

func _test_cooler_loss() -> void:
	# Rival two pair (aces and fours) is already behind a set of nines on the turn.
	var h := _new_hand(["9c", "9d", "Ac", "4h", "9h", "Ad", "4s", "2c", "Kd"])
	_passive_to_river(h[0], h[1])
	var mem := _settle(h[0], h[1])
	_check(mem.suck_outs_suffered == 0, "cooler is not a suck-out")
	_check(_near(mem.weight, -0.15 * NPCMemory.DECAY_RATE), "cooler weight -0.15 then decayed (got %f)" % mem.weight)

func _test_folded_to_aggression() -> void:
	var h := _new_hand(["Ac", "Ad", "7c", "2d", "Kh", "9c", "4s", "3d", "8h"])
	var session: PokerSession = h[0]
	var rm: RivalMemory = h[1]
	_act(session, rm, PokerBetting.Action.RAISE, 60)
	_act(session, rm, PokerBetting.Action.FOLD)
	var mem := _settle(session, rm)
	_check(mem.folded_to_aggression == 1, "fold to raise recorded (got %d)" % mem.folded_to_aggression)
	_check(_near(mem.weight, -0.10 * NPCMemory.DECAY_RATE), "weight -0.10 then decayed (got %f)" % mem.weight)

func _river_bluff_hand() -> Array:
	# Rival 3d 2c holds high card only on a dry board; player has Q-J high.
	var h := _new_hand(["Qc", "Jc", "3d", "2c", "Ah", "Kd", "9s", "7c", "5h"])
	var session: PokerSession = h[0]
	var rm: RivalMemory = h[1]
	_act(session, rm, PokerBetting.Action.CALL)
	_act(session, rm, PokerBetting.Action.CHECK)
	for street in range(3):
		session.advance_street()
		if street < 2:
			_act(session, rm, PokerBetting.Action.CHECK)
			_act(session, rm, PokerBetting.Action.CHECK)
	# River: rival (first to act post-flop) fires a bluff.
	_check(session.current_actor() == RIVAL, "rival acts first on the river")
	_act(session, rm, PokerBetting.Action.BET, 40)
	return h

func _test_stone_cold_worked() -> void:
	var h := _river_bluff_hand()
	_act(h[0], h[1], PokerBetting.Action.FOLD)
	var mem := _settle(h[0], h[1])
	_check(mem.stone_cold_bluffs == 0, "worked bluff is not a caught bluff")
	_check(_near(mem.weight, 0.20 * NPCMemory.DECAY_RATE), "bluff worked +0.20 then decayed (got %f)" % mem.weight)

func _test_stone_cold_caught() -> void:
	var h := _river_bluff_hand()
	_act(h[0], h[1], PokerBetting.Action.CALL)
	var mem := _settle(h[0], h[1])
	_check(mem.stone_cold_bluffs == 1, "caught bluff counted (got %d)" % mem.stone_cold_bluffs)
	_check(_near(mem.weight, -0.30 * NPCMemory.DECAY_RATE), "bluff caught -0.30 then decayed (got %f)" % mem.weight)

func _test_plain_showdown_records_nothing_but_decays() -> void:
	# Rival leads throughout with aces; nothing memorable happens.
	var h := _new_hand(["7c", "2d", "As", "Ad", "Kh", "9c", "4s", "3d", "8h"])
	var mem: NPCMemory = h[1].get_memory(str(PLAYER))
	mem.weight = 1.0
	_passive_to_river(h[0], h[1])
	_settle(h[0], h[1])
	_check(_near(mem.weight, NPCMemory.DECAY_RATE), "only decay applies (got %f)" % mem.weight)
	_check(mem.hands_seen == 1, "hand counted")

func _test_timing_recorded_once_per_hand() -> void:
	var h := _new_hand(["7c", "2d", "As", "Ad", "Kh", "9c", "4s", "3d", "8h"])
	var rm: RivalMemory = h[1]
	rm.observe_timing("tank")
	rm.observe_timing("tank")
	rm.observe_timing("snap")
	rm.observe_timing("bogus")
	var mem := rm.get_memory(str(PLAYER))
	_check(mem.tank_count == 1, "two tanks in one hand count once (got %d)" % mem.tank_count)
	_check(mem.snap_count == 1, "snap counted (got %d)" % mem.snap_count)
	_check(mem.weight == 0.0, "timing does not change weight")
	_check(not rm.memories.has(str(RIVAL)), "rival keeps no memory of itself")

func _test_settlement_is_idempotent() -> void:
	var h := _new_hand(["7c", "7d", "As", "Kd", "Ah", "9c", "4s", "2d", "7h"])
	_passive_to_river(h[0], h[1])
	var payouts: Dictionary = h[0].settle()
	h[1].record_settlement(h[0], payouts)
	h[1].record_settlement(h[0], payouts)
	var mem: NPCMemory = h[1].get_memory(str(PLAYER))
	_check(mem.suck_outs_suffered == 1 and mem.hands_seen == 1, "second settlement call is ignored")
