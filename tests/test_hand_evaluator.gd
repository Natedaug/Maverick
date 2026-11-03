extends SceneTree
## Headless test for PokerHandEvaluator and PokerHandRank.
## Run: godot --headless --script tests/test_hand_evaluator.gd

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_hand_evaluator.gd ===")
	_test_royal_flush()
	_test_straight_flush()
	_test_four_of_a_kind()
	_test_full_house()
	_test_flush()
	_test_straight()
	_test_wheel_straight()
	_test_three_of_a_kind()
	_test_two_pair()
	_test_one_pair()
	_test_high_card()
	_test_compare_category_ordering()
	_test_compare_same_category_kickers()
	_test_same_hand_ties()
	_test_seven_card_selects_best_five()
	_test_best_five_reports_correct_cards()
	_test_flush_vs_straight()

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

static func _hand(codes: String) -> Array[PokerCard]:
	var cards: Array[PokerCard] = []
	for part in codes.split(" ", false):
		var rank_names := "23456789TJQKA"
		var suit_names := "cdhs"
		var c := PokerCard.new(
			suit_names.find(part.substr(1, 1)) as PokerCard.Suit,
			rank_names.find(part.substr(0, 1)) + 2 as PokerCard.Rank
		)
		cards.append(c)
	return cards

func _eval(codes: String) -> PokerHandEvaluator.Result:
	return PokerHandEvaluator.evaluate_five(_hand(codes))

# --- Tests ---

func _test_royal_flush() -> void:
	var r := _eval("As Ks Qs Js Ts")
	_check(r.category == PokerHandRank.Category.ROYAL_FLUSH, "royal flush detected (got %s)" % r.to_code())

func _test_straight_flush() -> void:
	var r := _eval("9h 8h 7h 6h 5h")
	_check(r.category == PokerHandRank.Category.STRAIGHT_FLUSH, "straight flush detected (got %s)" % r.to_code())
	_check(r.kickers == [9], "straight flush high = 9 (got %s)" % str(r.kickers))

func _test_four_of_a_kind() -> void:
	var r := _eval("Jd Js Jh Jc As")
	_check(r.category == PokerHandRank.Category.FOUR_OF_A_KIND, "quads detected (got %s)" % r.to_code())
	_check(r.kickers == [11, 14], "quads kicker = Ace (got %s)" % str(r.kickers))

func _test_full_house() -> void:
	var r := _eval("3d 3s 7h 7c 7d")
	_check(r.category == PokerHandRank.Category.FULL_HOUSE, "full house detected (got %s)" % r.to_code())
	_check(r.kickers == [7, 3], "full house = trips 7s over 3s (got %s)" % str(r.kickers))
	# Trips rank takes priority over pairs regardless of big/small values
	var r2 := _eval("8d 8s Kh Kc Kd")
	_check(r2.kickers == [13, 8], "trips 8s over pair of kings (got %s)" % str(r2.kickers))

func _test_flush() -> void:
	var r := _eval("Ah Qh 9h 5h 2h")
	_check(r.category == PokerHandRank.Category.FLUSH, "flush detected (got %s)" % r.to_code())
	_check(r.kickers == [14, 12, 9, 5, 2], "flush kickers descending (got %s)" % str(r.kickers))

func _test_straight() -> void:
	var r := _eval("9d 8c 7h 6s 5h")
	_check(r.category == PokerHandRank.Category.STRAIGHT, "straight detected (got %s)" % r.to_code())
	_check(r.kickers == [9], "straight high = 9 (got %s)" % str(r.kickers))

func _test_wheel_straight() -> void:
	var r := _eval("Ad 2c 3h 4s 5h")
	_check(r.category == PokerHandRank.Category.STRAIGHT, "wheel is a straight (got %s)" % r.to_code())
	_check(r.kickers == [5], "wheel high = 5, not Ace (got %s)" % str(r.kickers))

func _test_three_of_a_kind() -> void:
	var r := _eval("Kd Ks Kh 4c 2d")
	_check(r.category == PokerHandRank.Category.THREE_OF_A_KIND, "trips detected (got %s)" % r.to_code())
	_check(r.kickers == [13, 4, 2], "trips kickers (got %s)" % str(r.kickers))

func _test_two_pair() -> void:
	var r := _eval("Ad Ac 5s 5h Kd")
	_check(r.category == PokerHandRank.Category.TWO_PAIR, "two pair detected (got %s)" % r.to_code())
	_check(r.kickers == [14, 5, 13], "two pair ordered high-low + kicker (got %s)" % str(r.kickers))

func _test_one_pair() -> void:
	var r := _eval("Qs Qd 9h 6c 2s")
	_check(r.category == PokerHandRank.Category.ONE_PAIR, "one pair detected (got %s)" % r.to_code())
	_check(r.kickers == [12, 9, 6, 2], "one pair kickers (got %s)" % str(r.kickers))

func _test_high_card() -> void:
	var r := _eval("Ah Js 8d 5c 2h")
	_check(r.category == PokerHandRank.Category.HIGH_CARD, "high card detected (got %s)" % r.to_code())
	_check(r.kickers == [14, 11, 8, 5, 2], "high card kickers (got %s)" % str(r.kickers))

func _test_compare_category_ordering() -> void:
	# Every category beats every weaker category
	var bills := [
		"Ah Js 8d 5c 2h",  # high card
		"Qs Qd 9h 6c 2s",  # one pair
		"Ad Ac 5s 5h Kd",  # two pair
		"Kd Ks Kh 4c 2d",  # trips
		"9d 8c 7h 6s 5h",  # straight
		"Ah Qh 9h 5h 2h",  # flush
		"3d 3s 7h 7c 7d",  # full house
		"Jd Js Jh Jc As",  # quads
		"9h 8h 7h 6h 5h",  # straight flush
		"As Ks Qs Js Ts",  # royal flush
	]
	for i in range(bills.size()):
		for j in range(bills.size()):
			var cmp: int = _eval(bills[i]).compare(_eval(bills[j]))
			var expected: int = sign(i - j)
			_check(cmp == expected, "%s vs %s: cmp=%d expected=%d" % [bills[i], bills[j], cmp, expected])

func _test_compare_same_category_kickers() -> void:
	# Kicker breaks ties within a category
	_check(_eval("Ah Ad 9h 6c 2s").compare(_eval("Ac As 8d 5h 3c")) > 0, "pair of aces, 9 kicker beats 8 kicker")
	_check(_eval("2h 2d 5h 6c As").compare(_eval("3s 3c 5d 6h Kd")) < 0, "pair 2s lose to pair 3s, kickers irrelevant")
	_check(_eval("Ah Ad 9h 6c 2s").compare(_eval("Ac As 9d 6h 2c")) == 0, "identical-value pairs tie")
	var wheel := _eval("Ad 2c 3h 4s 5d").compare(_eval("2h 3c 4d 5s 6h"))
	_check(wheel < 0, "wheel loses to 6-high straight (not compared as Ace)")

func _test_same_hand_ties() -> void:
	_check(_eval("Ah Qh 9h 5h 2h").compare(_eval("As Qs 9s 5s 2s")) == 0, "same flush values tie")
	_check(_eval("9d 8c 7h 6s 5h").compare(_eval("9h 8d 7s 6h 5d")) == 0, "same straight ties")

func _test_seven_card_selects_best_five() -> void:
	# Hole cards + board; the best five is a pair of queens (hole pair + board)
	var r := PokerHandEvaluator.evaluate(_hand("Qd Qc 2h 3s 6d 9h Js"))
	_check(r.category == PokerHandRank.Category.ONE_PAIR, "7-card: picks pair of queens (got %s)" % r.to_code())
	_check(r.kickers == [12, 11, 9, 6], "7-card one-pair kickers (got %s)" % str(r.kickers))

	# Straight available through a 3-7 run; hole king and ace stay unused in the best five
	var r2 := PokerHandEvaluator.evaluate(_hand("Kd Ah 3h 4s 5d 6h 7s"))
	_check(r2.category == PokerHandRank.Category.STRAIGHT, "7-card: finds straight (got %s)" % r2.to_code())
	_check(r2.kickers == [7], "7-card: straight is 7-high (got %s)" % str(r2.kickers))

	# Two pair from board + hole card; the third pair on board is ignored
	var r3 := PokerHandEvaluator.evaluate(_hand("8d 8c 2h 2s Ad Kh Qd"))
	_check(r3.category == PokerHandRank.Category.TWO_PAIR, "7-card: two pair 8s+2s (got %s)" % r3.to_code())
	_check(r3.kickers == [8, 2, 14], "7-card: two pair kickers include ace (got %s)" % str(r3.kickers))

	# Flush from board + hole card
	var r4 := PokerHandEvaluator.evaluate(_hand("9s 8s 2h 5s 6s Ts Kd"))
	_check(r4.category == PokerHandRank.Category.FLUSH, "7-card: finds spade flush (got %s)" % r4.to_code())

func _test_best_five_reports_correct_cards() -> void:
	var cards := _hand("Qd Qc 2h 3s 6d 9h Js")
	var r := PokerHandEvaluator.evaluate(cards)
	var best: Array = []
	for c in r.best_five:
		best.append(c.to_code())
	best.sort()
	var expected := ["6d", "9h", "Js", "Qc", "Qd"]
	_check(best == expected, "best_five = %s (got %s)" % [str(expected), str(best)])

func _test_flush_vs_straight() -> void:
	var flush := _eval("Ah Qh 9h 5h 2h")
	var straight := _eval("9d 8c 7h 6s 5h")
	_check(flush.compare(straight) > 0, "flush beats straight")
