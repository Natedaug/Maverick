extends SceneTree
## Headless test for PokerCard and PokerDeck.
## Run: godot --headless --script tests/test_deck.gd
##
## Uses SceneTree so we can use await and quit the loop cleanly.

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_deck.gd ===")
	_test_deck_has_52_cards()
	_test_deck_unique_cards()
	_test_shuffle_preserves_cards()
	_test_draw_reduces_size()
	_test_card_to_string()
	_test_card_compare()

	print("")
	print("PASSES: %d" % _passes)
	print("FAILURES: %d" % _failures)
	if _failures > 0:
		print("❌ TESTS FAILED")
		quit(1)
	else:
		print("✅ ALL TESTS PASSED")
		quit(0)

# --- Assertion helpers ---

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + msg)

# --- Tests ---

func _test_deck_has_52_cards() -> void:
	var d := PokerDeck.new()
	_check(d.size() == 52, "deck has 52 cards (got %d)" % d.size())

func _test_deck_unique_cards() -> void:
	var d := PokerDeck.new()
	var seen: Dictionary = {}
	for c in d.cards:
		var key := "%d-%d" % [c.suit, c.rank]
		_check(not seen.has(key), "duplicate card: " + c.to_code())
		seen[key] = true
	_check(seen.size() == 52, "52 unique cards (got %d)" % seen.size())

func _test_shuffle_preserves_cards() -> void:
	var d := PokerDeck.new()
	var before: Array = d.cards.duplicate()
	d.shuffle()
	var after: Array = d.cards.duplicate()
	before.sort_custom(func(a, b): return a.to_code() < b.to_code())
	after.sort_custom(func(a, b): return a.to_code() < b.to_code())
	var all_match := true
	for i in range(before.size()):
		if before[i].to_code() != after[i].to_code():
			all_match = false
			break
	_check(all_match, "shuffle preserves cards (only reorders)")

func _test_draw_reduces_size() -> void:
	var d := PokerDeck.new()
	var s0 := d.size()
	d.draw()
	var s1 := d.size()
	_check(s1 == s0 - 1, "draw reduces size by 1 (%d -> %d)" % [s0, s1])

func _test_card_to_string() -> void:
	var ace_spades := PokerCard.new(PokerCard.Suit.SPADES, PokerCard.Rank.ACE)
	_check(ace_spades.to_code() == "As", "Ace of Spades = 'As' (got '%s')" % ace_spades.to_code())
	var two_clubs := PokerCard.new(PokerCard.Suit.CLUBS, PokerCard.Rank.TWO)
	_check(two_clubs.to_code() == "2c", "Two of Clubs = '2c' (got '%s')" % two_clubs.to_code())
	var ten_hearts := PokerCard.new(PokerCard.Suit.HEARTS, PokerCard.Rank.TEN)
	_check(ten_hearts.to_code() == "Th", "Ten of Hearts = 'Th' (got '%s')" % ten_hearts.to_code())

func _test_card_compare() -> void:
	var ace := PokerCard.new(PokerCard.Suit.SPADES, PokerCard.Rank.ACE)
	var king := PokerCard.new(PokerCard.Suit.HEARTS, PokerCard.Rank.KING)
	_check(ace.compare_to(king) > 0, "Ace > King")
	_check(king.compare_to(ace) < 0, "King < Ace")
	_check(king.compare_to(king) == 0, "King == King")
