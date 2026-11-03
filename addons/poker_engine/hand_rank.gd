class_name PokerHandRank
extends RefCounted
## Poker hand categories, ordered from weakest to strongest.
## Higher numeric value = stronger hand.
##
## Used by PokerHandEvaluator to compare two hands. A tie on category
## is broken by kickers (handled by the evaluator, not this class).

enum Category {
	HIGH_CARD = 0,
	ONE_PAIR = 1,
	TWO_PAIR = 2,
	THREE_OF_A_KIND = 3,
	STRAIGHT = 4,
	FLUSH = 5,
	FULL_HOUSE = 6,
	FOUR_OF_A_KIND = 7,
	STRAIGHT_FLUSH = 8,
	ROYAL_FLUSH = 9,
}

## Human-readable name for each category.
static func category_name(cat: Category) -> String:
	match cat:
		Category.HIGH_CARD:        return "High PokerCard"
		Category.ONE_PAIR:         return "One Pair"
		Category.TWO_PAIR:         return "Two Pair"
		Category.THREE_OF_A_KIND:  return "Three of a Kind"
		Category.STRAIGHT:         return "Straight"
		Category.FLUSH:            return "Flush"
		Category.FULL_HOUSE:       return "Full House"
		Category.FOUR_OF_A_KIND:   return "Four of a Kind"
		Category.STRAIGHT_FLUSH:   return "Straight Flush"
		Category.ROYAL_FLUSH:      return "Royal Flush"
		_:                         return "Unknown"

## Compare two (category, kickers) pairs.
## Returns: 1 if a beats b, -1 if b beats a, 0 if tie.
## `kickers` are arrays of ints (rank values), highest first.
## Longer arrays break deeper ties; shorter arrays assume equal on missing entries.
static func compare(
	a_cat: Category, a_kickers: Array[int],
	b_cat: Category, b_kickers: Array[int]
) -> int:
	if a_cat != b_cat:
		return 1 if a_cat > b_cat else -1

	# Same category — compare kickers lexicographically
	var n: int = maxi(a_kickers.size(), b_kickers.size())
	for i in range(n):
		var a_k: int = a_kickers[i] if i < a_kickers.size() else 0
		var b_k: int = b_kickers[i] if i < b_kickers.size() else 0
		if a_k != b_k:
			return 1 if a_k > b_k else -1

	return 0
