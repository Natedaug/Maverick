class_name PokerHandEvaluator
extends RefCounted
## Evaluates 5-card and 7-card poker hands.
##
## The `Result` inner class holds (category, kickers). Compare two Results
## with Result.compare() to determine the winner.
##
## Usage:
##   var r := PokerHandEvaluator.evaluate(seven_cards)  # 7-card wrapper
##   var a := PokerHandEvaluator.evaluate_five(five_cards)  # 5-card exact
##   if a.compare(b) > 0: print("A wins")

class Result extends RefCounted:
	var category: PokerHandRank.Category
	var kickers: Array[int]  # rank values, highest first
	var best_five: Array[PokerCard]  # the actual 5 cards that formed the hand

	func _init(p_cat: PokerHandRank.Category, p_kickers: Array[int], p_best: Array[PokerCard]) -> void:
		category = p_cat
		kickers = p_kickers
		best_five = p_best

	## +1 if self beats other, -1 if other beats self, 0 if tie.
	func compare(other: Result) -> int:
		return PokerHandRank.compare(category, kickers, other.category, other.kickers)

	func to_code() -> String:
		return "%s %s" % [PokerHandRank.category_name(category), str(kickers)]

# --- Public API ---

## Evaluate the best 5-card hand among 5 or 7 cards (Hold'em style).
## With 7 cards, tries all 21 five-card combinations and returns the strongest.
static func evaluate(cards: Array[PokerCard]) -> Result:
	assert(cards.size() == 5 or cards.size() == 7,
		"evaluate requires 5 or 7 cards (got %d)" % cards.size())
	if cards.size() == 5:
		return evaluate_five(cards)

	var best: Result = null
	for a in range(7):
		for b in range(a + 1, 7):
			for c in range(b + 1, 7):
				for d in range(c + 1, 7):
					for e in range(d + 1, 7):
						var five: Array[PokerCard] = [cards[a], cards[b], cards[c], cards[d], cards[e]]
						var r := evaluate_five(five)
						if best == null or r.compare(best) > 0:
							best = r
	return best

## Evaluate exactly 5 cards. Returns Result with category + kickers + the 5 cards.
static func evaluate_five(cards: Array[PokerCard]) -> Result:
	assert(cards.size() == 5, "evaluate_five requires exactly 5 cards (got %d)" % cards.size())

	# Sort by rank descending — simplifies straight/flush/grouping detection
	var sorted: Array[PokerCard] = cards.duplicate()
	sorted.sort_custom(func(a: PokerCard, b: PokerCard) -> bool: return a.rank > b.rank)

	# Group ranks
	var rank_counts: Dictionary = {}  # rank -> count
	for c in sorted:
		rank_counts[c.rank] = rank_counts.get(c.rank, 0) + 1

	# Group cards by count, then by rank — for pair/trips/quads ordering
	# entries: Array of [rank, count], sorted by count desc, then rank desc
	var groups: Array = []
	for r in rank_counts:
		groups.append([r, rank_counts[r]])
	groups.sort_custom(func(a, b):
		if a[1] != b[1]:
			return a[1] > b[1]
		return a[0] > b[0]
	)

	var is_flush := _is_flush(sorted)
	var straight_high := _straight_high(sorted)

	# --- STRAIGHT FLUSH / ROYAL FLUSH ---
	if is_flush and straight_high > 0:
		if straight_high == PokerCard.Rank.ACE:
			return Result.new(PokerHandRank.Category.ROYAL_FLUSH, [PokerCard.Rank.ACE], sorted)

		return Result.new(PokerHandRank.Category.STRAIGHT_FLUSH, [straight_high], sorted)

	# --- FOUR OF A KIND ---
	if groups[0][1] == 4:
		var quad_rank: int = groups[0][0]
		var kicker: int = groups[1][0]
		return Result.new(PokerHandRank.Category.FOUR_OF_A_KIND, [quad_rank, kicker], sorted)

	# --- FULL HOUSE ---
	if groups[0][1] == 3 and groups[1][1] == 2:
		var trips_rank: int = groups[0][0]
		var pair_rank: int = groups[1][0]
		return Result.new(PokerHandRank.Category.FULL_HOUSE, [trips_rank, pair_rank], sorted)

	# --- FLUSH ---
	if is_flush:
		var kickers: Array[int] = []
		for c in sorted:
			kickers.append(c.rank)
		return Result.new(PokerHandRank.Category.FLUSH, kickers, sorted)

	# --- STRAIGHT ---
	if straight_high > 0:
		return Result.new(PokerHandRank.Category.STRAIGHT, [straight_high], sorted)

	# --- THREE OF A KIND ---
	if groups[0][1] == 3:
		var trips_rank: int = groups[0][0]
		var kickers: Array[int] = [trips_rank]
		for i in range(1, groups.size()):
			kickers.append(groups[i][0])
		return Result.new(PokerHandRank.Category.THREE_OF_A_KIND, kickers, sorted)

	# --- TWO PAIR ---
	if groups[0][1] == 2 and groups[1][1] == 2:
		var high_pair: int = groups[0][0]
		var low_pair: int = groups[1][0]
		var kicker: int = groups[2][0]
		return Result.new(PokerHandRank.Category.TWO_PAIR, [high_pair, low_pair, kicker], sorted)

	# --- ONE PAIR ---
	if groups[0][1] == 2:
		var pair_rank: int = groups[0][0]
		var kickers: Array[int] = [pair_rank]
		for i in range(1, groups.size()):
			kickers.append(groups[i][0])
		return Result.new(PokerHandRank.Category.ONE_PAIR, kickers, sorted)

	# --- HIGH CARD ---
	var high_kickers: Array[int] = []
	for c in sorted:
		high_kickers.append(c.rank)
	return Result.new(PokerHandRank.Category.HIGH_CARD, high_kickers, sorted)

# --- Internal helpers ---

static func _is_flush(sorted_cards: Array[PokerCard]) -> bool:
	var suit: int = sorted_cards[0].suit
	for c in sorted_cards:
		if c.suit != suit:
			return false
	return true

## Returns the high card rank of a 5-card straight, or 0 if not a straight.
## Handles the wheel (A-2-3-4-5) by returning FIVE (the "high" card is the 5).
static func _straight_high(sorted_cards: Array[PokerCard]) -> int:
	var ranks: Array[int] = []
	for c in sorted_cards:
		ranks.append(c.rank)
	# sorted_cards is descending: [A, K, Q, ...] or [A, 5, 4, 3, 2]
	# Deduplicate (should already be unique in a 5-card straight check)
	var unique: Array[int] = []
	for r in ranks:
		if not unique.has(r):
			unique.append(r)
	if unique.size() != 5:
		return 0

	# Check for standard 5-in-a-row (descending)
	var is_consecutive := true
	for i in range(4):
		if unique[i] - unique[i + 1] != 1:
			is_consecutive = false
			break
	if is_consecutive:
		return unique[0]  # high card

	# Check for wheel: A, 5, 4, 3, 2 (ranks ACE=14, FIVE=5, FOUR=4, THREE=3, TWO=2)
	if unique == [PokerCard.Rank.ACE, PokerCard.Rank.FIVE, PokerCard.Rank.FOUR, PokerCard.Rank.THREE, PokerCard.Rank.TWO]:
		return PokerCard.Rank.FIVE  # 5-high straight

	return 0
