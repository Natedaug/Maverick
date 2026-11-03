class_name PokerDeck
extends RefCounted

var cards: Array[PokerCard] = []
var rng: RandomNumberGenerator

func _init(p_rng: RandomNumberGenerator = null) -> void:
	rng = p_rng if p_rng else RandomNumberGenerator.new()
	build_standard_deck()

func build_standard_deck() -> void:
	cards.clear()
	for s in PokerCard.Suit.values():
		for r in range(PokerCard.Rank.TWO, PokerCard.Rank.ACE + 1):
			cards.append(PokerCard.new(s, r))

func shuffle() -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp

## Set a deterministic deal order. The first supplied card is drawn first.
## Input must be a complete, unique standard 52-card deck.
func set_deal_order(top_first: Array[PokerCard]) -> void:
	assert(top_first.size() == 52, "deal order must contain exactly 52 cards")
	var seen: Dictionary = {}
	for card in top_first:
		assert(card != null, "deal order cannot contain null cards")
		assert(card.suit >= PokerCard.Suit.CLUBS and card.suit <= PokerCard.Suit.SPADES,
			"deal order contains an invalid suit")
		assert(card.rank >= PokerCard.Rank.TWO and card.rank <= PokerCard.Rank.ACE,
			"deal order contains an invalid rank")
		var code := card.to_code()
		assert(not seen.has(code), "deal order contains duplicate card %s" % code)
		seen[code] = true
	cards = top_first.duplicate()
	cards.reverse()

func draw() -> PokerCard:
	assert(not cards.is_empty(), "PokerDeck is empty")
	return cards.pop_back()

func size() -> int:
	return cards.size()
