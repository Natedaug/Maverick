extends SceneTree
## Headless test for PokerGameState (dealing, streets, run-out, settlement).
## Run: godot --headless --script tests/test_game_state.gd

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_game_state.gd ===")
	_test_setup_blinds_and_deal()
	_test_heads_up_sb_is_button()
	_test_multiway_blind_positions()
	_test_advance_rejected_mid_round()
	_test_advance_street_collects_and_deals()
	_test_fold_win_settlement()
	_test_allin_runout_and_settlement()
	_test_showdown_best_hand_wins()
	_test_showdown_split_pot()
	_test_main_side_pots_and_folded_contribution()
	_test_snapshot_hides_opponent_cards()

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

## Drive the current betting round down using the "easiest legal" action:
## check when possible, otherwise call. Carries the round to completion.
func _check_call_down(g: PokerGameState) -> void:
	var guard := 0
	while not g.betting.is_round_over() and guard < 50:
		guard += 1
		if g.betting.is_legal(PokerBetting.Action.CHECK):
			g.act(PokerBetting.Action.CHECK)
		elif g.betting.is_legal(PokerBetting.Action.CALL):
			g.act(PokerBetting.Action.CALL)
		elif g.betting.is_legal(PokerBetting.Action.FOLD):
			g.act(PokerBetting.Action.FOLD)
		else:
			break

func _sum(d: Dictionary) -> int:
	var total: int = 0
	for k in d:
		total += d[k]
	return total

# --- Tests ---

func _test_setup_blinds_and_deal() -> void:
	# 3 seats, button on seat 2: SB=0, BB=1, first actor UTG=2
	var g := PokerGameState.new([1000, 1000, 1000], 2, 50, 100)
	_check(g.total_pot() == 150, "blinds in pot (got %d)" % g.total_pot())
	_check(g.sb_seat == 0, "SB = button+1 (got %d)" % g.sb_seat)
	_check(g.bb_seat == 1, "BB = button+2 (got %d)" % g.bb_seat)
	_check(g.hole_cards.size() == 3, "2 hole cards dealt to each of 3 seats")
	_check(g.board.is_empty(), "board empty preflop")
	var seen := {}
	var unique := true
	for seat_ff in range(g.hole_cards.size()):
		for c in g.hole_cards[seat_ff]:
			var key := "%d-%d" % [c.suit, c.rank]
			if seen.has(key):
				unique = false
			seen[key] = true
	_check(unique, "all dealt cards unique")
	_check(g.stage == PokerGameState.Street.PREFLOP, "stage = PREFLOP")
	_check(g.current_actor() != null and g.current_actor().id == 2, "UTG acts first")

func _test_heads_up_sb_is_button() -> void:
	var g := PokerGameState.new([1000, 1000], 0, 50, 100)
	_check(g.sb_seat == 0, "heads-up: button posts SB (got %d)" % g.sb_seat)
	_check(g.bb_seat == 1, "heads-up: other seat posts BB (got %d)" % g.bb_seat)
	_check(g.current_actor() != null and g.current_actor().id == 0, "SB (button) acts first preflop")

func _test_multiway_blind_positions() -> void:
	var g := PokerGameState.new([1000, 1000, 1000, 1000], 3, 50, 100)
	_check(g.sb_seat == 0, "4-way: SB = 0 (got %d)" % g.sb_seat)
	_check(g.bb_seat == 1, "4-way: BB = 1 (got %d)" % g.bb_seat)
	_check(g.current_actor().id == 2, "UTG = seat after BB (got %d)" % g.current_actor().id)

func _test_advance_rejected_mid_round() -> void:
	var g := PokerGameState.new([1000, 1000, 1000], 2, 50, 100)
	_check(not g.advance_street(), "cannot advance mid-round")
	_check(g.stage == PokerGameState.Street.PREFLOP, "stage unchanged")
	var before: int = g.total_pot()
	_check(before == 150, "pot untouched (got %d)" % before)

func _test_advance_street_collects_and_deals() -> void:
	var g := PokerGameState.new([1000, 1000, 1000], 2, 50, 100)
	_check(g.act(PokerBetting.Action.RAISE, 300), "UTG raises to 300")
	_check(g.act(PokerBetting.Action.CALL), "SB calls")
	_check(g.act(PokerBetting.Action.CALL), "BB calls")
	_check(g.is_street_over(), "preflop round over")
	_check(g.advance_street(), "advance works once round is over")
	_check(g.stage == PokerGameState.Street.FLOP, "stage = FLOP (got %s)" % str(g.stage))
	_check(g.communal == 900, "preflop bets collected into communal (got %d)" % g.communal)
	_check(g.betting.pot() == 0, "street bets reset (got %d)" % g.betting.pot())
	_check(g.board.size() == 3, "flop = 3 board cards (got %d)" % g.board.size())
	_check(g.current_actor() != null and g.current_actor().id == g.sb_seat,
		"postflop starts after the button (seat %d)" % g.sb_seat)
	# Walk flop -> turn -> river, checking down each round
	_check_call_down(g)          # flop round
	_check(g.advance_street(), "flop -> turn")
	_check(g.stage == PokerGameState.Street.TURN, "stage = TURN")
	_check(g.board.size() == 4, "turn board (got %d)" % g.board.size())
	_check_call_down(g)          # turn round
	_check(g.advance_street(), "turn -> river")
	_check(g.stage == PokerGameState.Street.RIVER, "stage = RIVER")
	_check_call_down(g)          # river round
	_check(g.board.size() == 5, "full board dealt (got %d)" % g.board.size())
	_check(not g.advance_street(), "cannot advance past river")

func _test_fold_win_settlement() -> void:
	var g := PokerGameState.new([1000, 1000, 1000], 2, 50, 100)
	# blinds: seat0 50, seat1 100; UTG seat 2 to act
	_check(g.act(PokerBetting.Action.FOLD), "UTG folds")
	_check(g.act(PokerBetting.Action.FOLD), "SB folds")
	_check(g.hand_over(), "hand over with 1 player left")
	var paid: Dictionary = g.settle()
	_check(paid == {1: 150}, "BB gets blinds back: %s" % str(paid))
	_check(g.stacks() == [950, 1050, 1000], "stacks: %s" % str(g.stacks()))
	_check(g.stage == PokerGameState.Street.SHOWDOWN, "stage = SHOWDOWN after settle")
	var fold_win_view: Dictionary = g.snapshot(-1)
	_check(fold_win_view.seats[1].cards.is_empty(),
		"fold-win does not reveal the winner's hole cards")
	_check(fold_win_view.pot == 0 and fold_win_view.pots.is_empty(),
		"settled fold-win snapshot clears the awarded pot")

func _test_allin_runout_and_settlement() -> void:
	# Both players all-in from the blinds; deck decides the rest
	var g := PokerGameState.new([50, 100], 0, 50, 100)
	_check(g.hand_over() == false, "hand not yet over")
	_check(g.is_street_over(), "both all-in from blinds: no betting possible")
	g.run_out()
	_check(g.board.size() == 5, "full board run out (got %d)" % g.board.size())
	_check(g.communal == 150, "blinds collected (got %d)" % g.communal)
	_check(g.stage == PokerGameState.Street.RIVER, "stage = RIVER after run-out")
	var paid: Dictionary = g.settle()
	_check(_sum(paid) == 150, "whole pot awarded (got %d)" % _sum(paid))
	_check(g.stage == PokerGameState.Street.SHOWDOWN, "settled")

func _test_showdown_best_hand_wins() -> void:
	var g := PokerGameState.new([1000, 1000], 0, 50, 100)
	# Script the end state directly (white-box): royal flush vs junk
	g.stage = PokerGameState.Street.RIVER
	g.communal = 600
	g.board = _cards("Qs Js Ts 7c 4h")
	g.hole_cards[0] = _cards("As Ks")
	g.hole_cards[1] = _cards("2d 3d")
	_check_call_down(g)   # river round still needs its check/check
	# Chip conservation: stacks before settle + the in-flight pot
	var chips_before: int = 0
	for c in g.stacks():
		chips_before += c
	var pot_in_flight: int = g.total_pot()
	var paid: Dictionary = g.settle()
	_check(paid.size() == 1 and paid.has(0), "seat 0 wins outright: %s" % str(paid))
	_check(paid[0] == pot_in_flight, "winner takes the entire pot")
	var total_chips: int = 0
	for c in g.stacks():
		total_chips += c
	_check(total_chips == chips_before + pot_in_flight, "all chips accounted for (got %d, want %d)" % [total_chips, chips_before + pot_in_flight])

func _test_showdown_split_pot() -> void:
	var g := PokerGameState.new([1000, 1000], 0, 50, 100)
	g.stage = PokerGameState.Street.RIVER
	# communal 1001 + blinds sitting in betting.pot() (200) = 1201 total
	g.communal = 1001
	g.board = _cards("As Ks Qh Jd 9c")
	# both players' best five is the board itself (A-high) -> chop
	g.hole_cards[0] = _cards("2c 3c")
	g.hole_cards[1] = _cards("4d 5d")
	_check_call_down(g)
	_check(g.total_pot() == 1201, "communal + betting chips (got %d)" % g.total_pot())
	var paid: Dictionary = g.settle()
	_check(paid[1] == 601, "odd chip to seat after button (got %d)" % paid.get(1, -1))
	_check(paid[0] == 600, "seat 0 gets 600 (got %d)" % paid.get(0, -1))
	_check(_sum(paid) == 1201, "full pot distributed")

func _test_main_side_pots_and_folded_contribution() -> void:
	var g := PokerGameState.new([1000, 1000, 1000], 0, 50, 100)
	# Total contributions are 100 / 300 / 300. Seat 2 folded, so its chips
	# fund both pots but it cannot win either one. Seat 0 wins the main pot;
	# seat 1 is the only eligible player for the side pot.
	for seat in g.betting.seats:
		seat.committed = 0
		seat.chips = [900, 700, 700][seat.id]
		seat.total_committed = [100, 300, 300][seat.id]
		seat.acted = true
	g.betting.seats[2].folded = true
	g.betting.current_bet = 0
	g.betting.to_act = -1
	g.communal = 700
	g.stage = PokerGameState.Street.RIVER
	g.board = _cards("As Kd Qh 8c 2s")
	g.hole_cards[0] = _cards("Ac Ad")
	g.hole_cards[1] = _cards("Kh Kc")
	var pots := g.pot_breakdown()
	_check(pots.size() == 2, "contributions form main and side pots: %s" % str(pots))
	_check(pots[0] == {amount = 300, eligible = [0, 1]},
		"main pot includes all contributions and only live contenders: %s" % str(pots[0]))
	_check(pots[1] == {amount = 400, eligible = [1]},
		"side pot excludes folded contributor: %s" % str(pots[1]))
	var paid: Dictionary = g.settle()
	_check(paid == {0: 300, 1: 400}, "each pot goes to its eligible winner: %s" % str(paid))
	_check(g.stacks() == [1200, 1100, 700], "pot payouts preserve folded seat chips: %s" % str(g.stacks()))
	var settled_view: Dictionary = g.snapshot(-1)
	_check(settled_view.seats[0].cards.size() == 2 and settled_view.seats[1].cards.size() == 2,
		"showdown reveals cards for players who reached it")
	_check(settled_view.seats[2].cards.is_empty() and settled_view.seats[2].hidden_cards == 2,
		"showdown keeps folded cards private")

func _test_snapshot_hides_opponent_cards() -> void:
	var g := PokerGameState.new([1000, 1000], 0, 50, 100)
	var own_cards: Array[String] = []
	for card in g.hole_cards[0]:
		own_cards.append(card.to_code())
	var opponent: Dictionary = g.snapshot(0).seats[1]
	_check(g.snapshot(0).seats[0].cards == own_cards, "viewer sees their own hole cards")
	_check(opponent.cards.is_empty() and opponent.hidden_cards == 2,
		"viewer cannot see opponent hole cards")
	var observer_seat: Dictionary = g.snapshot(-1).seats[0]
	_check(observer_seat.cards.is_empty() and observer_seat.hidden_cards == 2,
		"observer cannot see either player's hole cards")
