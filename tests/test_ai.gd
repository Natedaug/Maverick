extends SceneTree
## Headless test for HandStrength, Strategy, and AIPlayer.
## Run: godot --headless --script tests/test_ai.gd

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_ai.gd ===")
	_test_equity_royal_is_certain()
	_test_equity_weak_hand_rarely_wins()
	_test_equity_nuts_over_board()
	_test_strategy_value_bet_when_free()
	_test_strategy_check_when_free()
	_test_strategy_raise_when_strong()
	_test_strategy_call_when_above_required()
	_test_strategy_fold_when_priced_out()
	_test_ai_decision_is_applied_in_place()
	_test_ai_folds_junk_facing_river_bet()
	_test_ai_bets_the_nuts_on_river()
	_test_ai_plays_full_hands_legally()
	_test_ai_acts_through_poker_session()

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

func _seed_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _no_bluff_strategy(rng: RandomNumberGenerator) -> Strategy:
	var s := Strategy.new(rng)
	s.bluff_frequency = 0.0
	return s

static func _cards(codes: String) -> Array[PokerCard]:
	var cards: Array[PokerCard] = []
	var rank_names := "23456789TJQKA"
	var suit_names := "cdhs"
	for part in codes.split(" ", false):
		cards.append(PokerCard.new(
			suit_names.find(part.substr(1, 1)) as PokerCard.Suit,
			rank_names.find(part.substr(0, 1)) + 2 as PokerCard.Rank
		))
	return cards

## Clean river-ready state: blinds resolved, fresh street, seat 1 (BB) to act.
func _river_bench() -> PokerGameState:
	var g := PokerGameState.new([1000, 1000], 0, 50, 100)
	g.act(PokerBetting.Action.CALL)   # SB completes
	g.act(PokerBetting.Action.CHECK)  # BB option
	g.advance_street()           # collects preflop, deals 3 (replaced below)
	g.stage = PokerGameState.Street.RIVER
	g.communal = 500
	g.board = []
	return g

## "Human" policy for the non-AI seat: check when free, otherwise call; fold never.
func _human_step(g: PokerGameState) -> void:
	if g.betting.is_legal(PokerBetting.Action.CHECK):
		g.act(PokerBetting.Action.CHECK)
	elif g.betting.is_legal(PokerBetting.Action.CALL):
		g.act(PokerBetting.Action.CALL)
	else:
		g.act(PokerBetting.Action.FOLD)

# --- HandStrength tests ---

func _test_equity_royal_is_certain() -> void:
	var rng := _seed_rng(1234)
	var hole := _cards("As Ks")
	var board := _cards("Qs Js Ts 7c 2c")
	var eq: float = HandStrength.equity(hole, board, 1, 60, rng)
	_check(eq == 1.0, "royal flush equity vs 1 = 1.0 (got %f)" % eq)

func _test_equity_weak_hand_rarely_wins() -> void:
	var rng := _seed_rng(99)
	# Junk that cannot improve: best five is always the board itself
	var hole := _cards("2h 3d")
	var board := _cards("Ah Ks Qd Jc 9c")
	var eq: float = HandStrength.equity(hole, board, 1, 400, rng)
	_check(eq >= 0.04, "junk equity not absurdly low (got %f)" % eq)
	_check(eq <= 0.40, "junk equity well below a coin flip (got %f)" % eq)

func _test_equity_nuts_over_board() -> void:
	var rng := _seed_rng(7)
	# Pocket aces over an Ace board = trips, nearly unbeatable 1-up
	var hole := _cards("Ac Ad")
	var board := _cards("Ah Kh Qs 4c 2d")
	var eq: float = HandStrength.equity(hole, board, 1, 400, rng)
	_check(eq >= 0.90, "trips over board nearly always wins (got %f)" % eq)

# --- Strategy tests ---

func _test_strategy_value_bet_when_free() -> void:
	var s := _no_bluff_strategy(_seed_rng(5))
	var d := s.decide(0.95, PokerGameState.Street.RIVER, 0, 500, 1)
	_check(d.action == PokerBetting.Action.BET, "strong equity bets when unchecked (got %s)" % str(d))
	_check(d.frac >= 0.4 and d.frac <= 1.1, "bet size in sensible range (got %f)" % d.frac)

func _test_strategy_check_when_free() -> void:
	var s := _no_bluff_strategy(_seed_rng(5))
	var d := s.decide(0.25, PokerGameState.Street.RIVER, 0, 500, 1)
	_check(d.action == PokerBetting.Action.CHECK, "weak equity checks (got %s)" % str(d))

func _test_strategy_raise_when_strong() -> void:
	var s := _no_bluff_strategy(_seed_rng(5))
	var d := s.decide(0.95, PokerGameState.Street.RIVER, 100, 500, 1)
	_check(d.action == PokerBetting.Action.RAISE, "nut equity raises facing bet (got %s)" % str(d))
	_check(d.frac > 0.0, "raise has a size (got %f)" % d.frac)

func _test_strategy_call_when_above_required() -> void:
	var s := _no_bluff_strategy(_seed_rng(5))
	# facing ~16.7% pot odds with 45% equity
	var d := s.decide(0.45, PokerGameState.Street.RIVER, 100, 500, 1)
	_check(d.action == PokerBetting.Action.CALL, "equity above pot odds calls (got %s)" % str(d))

func _test_strategy_fold_when_priced_out() -> void:
	var s := _no_bluff_strategy(_seed_rng(5))
	var d := s.decide(0.08, PokerGameState.Street.RIVER, 800, 400, 1)
	_check(d.action == PokerBetting.Action.FOLD, "equity below required folds (got %s)" % str(d))

# --- AIPlayer tests ---

func _test_ai_decision_is_applied_in_place() -> void:
	var g := _river_bench()
	g.board = _cards("Qd 4s 5c 9h 2c")
	var ai := AIPlayer.new(1, _no_bluff_strategy(_seed_rng(3)))
	var d := ai.decide(g)  # decide() applies the action itself
	_check(d.has("action") and d.has("amount"), "decision returned {action, amount}")
	_check(g.betting.seats[1].acted, "AI's action was applied to seat 1")
	_check(g.betting.to_act != 1, "turn moved past the AI (got %d)" % g.betting.to_act)

func _test_ai_folds_junk_facing_river_bet() -> void:
	var g := _river_bench()
	g.board = _cards("Qd 4s 5c 9h 2c")
	g.hole_cards[1] = _cards("2h 3d")
	var ai := AIPlayer.new(1, _no_bluff_strategy(_seed_rng(11)))
	var d := ai.decide(g)
	_check(d.action == PokerBetting.Action.CHECK, "AI checks first (got %s)" % str(d))
	_check(g.act(PokerBetting.Action.BET, 600), "human bets heavy")
	var d2 := ai.decide(g)
	_check(d2.action == PokerBetting.Action.FOLD, "AI folds junk facing oversized bet (got %s)" % str(d2))

func _test_ai_bets_the_nuts_on_river() -> void:
	var g := _river_bench()
	g.board = _cards("Qs Js Ts 7c 2c")
	g.hole_cards[1] = _cards("As Ks")
	var ai := AIPlayer.new(1, _no_bluff_strategy(_seed_rng(21)))
	var d := ai.decide(g)
	_check(d.action == PokerBetting.Action.BET or d.action == PokerBetting.Action.RAISE,
		"AI bets the nuts (got %s)" % str(d))
	_check(d.amount >= 100, "bet at least the BB (got %d)" % d.amount)
	_check(d.amount <= 950, "bet within the AI stack (got %d)" % d.amount)

# --- Integration: AI plays whole hands against a script, everything legal ---

func _test_ai_plays_full_hands_legally() -> void:
	var rng := _seed_rng(2024)
	for h in range(5):
		var g := PokerGameState.new([1000, 1000], h % 2, 50, 100, rng)
		var shover := _no_bluff_strategy(rng)
		shover.aggression = 0.7
		var ai := AIPlayer.new(1, shover)
		var guard := 0
		while not g.hand_over() and guard < 500:
			guard += 1
			if g.betting.is_round_over():
				if g.stage == PokerGameState.Street.RIVER:
					g.settle()
				else:
					g.advance_street()
				continue
			var actor: PokerBetting.Seat = g.current_actor()
			if actor.id == 1:
				ai.decide(g)
			else:
				_human_step(g)
		_check(guard < 500, "hand %d terminated (guard %d)" % [h, guard])
		_check(g.stage == PokerGameState.Street.SHOWDOWN or g.players_left() == 1,
			"hand %d settled or fold-win" % h)
		_check(g.players_left() >= 1, "at least one player alive (hand %d)" % h)
		var remaining_chips: int = 0
		for c in g.stacks():
			remaining_chips += c
		# the loop always settles fully, so all 2000 chips are back in stacks
		_check(remaining_chips == 2000,
			"chips conserved exactly (hand %d: got %d)" % [h, remaining_chips])

func _test_ai_acts_through_poker_session() -> void:
	var session := PokerSession.new([1000, 1000], 1, 50, 100, _seed_rng(281))
	_check(session.start_hand(), "session starts for AI integration")
	var ai := AIPlayer.new(1, _no_bluff_strategy(_seed_rng(282)))
	var decision := ai.decide_session(session)
	_check(decision.has("action") and decision.has("amount"), "session AI returns a materialized action")
	_check(session.current_actor() != 1, "session AI action advances the stable-seat actor")
	_check(session.stacks().size() == 2, "session keeps both stable seats")
