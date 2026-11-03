class_name HandStrength
extends RefCounted
## Monte Carlo equity estimation for Texas Hold'em hands.
##
## equity() answers "how often does this hand win heads-up or multiway?"
## by sampling the remaining deck, dealing opponents + board completions,
## and evaluating with PokerHandEvaluator. Deterministic given a seeded RNG.
##
## Usage:
##   var eq := HandStrength.equity(hole, board, 1, 200)  # heads-up win chance

## Win probability (ties count as a shared win) for `hole` against
## `opponents` random hands, given `board` (0..5 cards).
## iterations trades accuracy for speed (~200 is plenty for AI decisions).
static func equity(
	hole: Array[PokerCard], board: Array[PokerCard], opponents: int,
	iterations: int, rng: RandomNumberGenerator = null
) -> float:
	assert(hole.size() == 2, "hole must have exactly 2 cards")
	assert(board.size() >= 0 and board.size() <= 5)
	assert(opponents >= 1, "equity needs at least 1 opponent")
	var rand := rng if rng else RandomNumberGenerator.new()

	# Remaining unseen cards
	var known: Array[PokerCard] = []
	known.append_array(hole)
	known.append_array(board)
	var remaining: Array[PokerCard] = []
	for s in PokerCard.Suit.values():
		for r in range(PokerCard.Rank.TWO, PokerCard.Rank.ACE + 1):
			var unseen := true
			for k in known:
				if k.suit == s and k.rank == r:
					unseen = false
					break
			if unseen:
				remaining.append(PokerCard.new(s, r as PokerCard.Rank))

	var need_board: int = 5 - board.size()
	var draw_n: int = need_board + opponents * 2
	var wins: float = 0.0
	var iter_board: Array[PokerCard] = board.duplicate()

	for i in range(iterations):
		# Partial Fisher-Yates: draw_n cards land in the front of `remaining`
		for k in range(draw_n):
			var j := rand.randi_range(k, remaining.size() - 1)
			var tmp := remaining[k]
			remaining[k] = remaining[j]
			remaining[j] = tmp
		var cursor := 0
		# Opponents first, then the board completion (order is irrelevant)
		var opp_cards: Array[PokerCard] = []
		for k in range(opponents * 2):
			opp_cards.append(remaining[cursor])
			cursor += 1
		iter_board.clear()
		iter_board.append_array(board)
		for c in range(need_board):
			iter_board.append(remaining[cursor])
			cursor += 1

		# Evaluate my hand vs each opponent's
		var mine: Array[PokerCard] = []
		mine.append_array(hole)
		mine.append_array(iter_board)
		var my_result := PokerHandEvaluator.evaluate(mine)
		var shared: int = 0
		var still_best := true
		for o in range(opponents):
			var theirs: Array[PokerCard] = []
			theirs.append(opp_cards[o * 2])
			theirs.append(opp_cards[o * 2 + 1])
			theirs.append_array(iter_board)
			var r := PokerHandEvaluator.evaluate(theirs)
			var cmp := r.compare(my_result)
			if cmp > 0:
				still_best = false
				break
			elif cmp == 0:
				shared += 1
		if still_best:
			wins += 1.0 / float(1 + shared)
	return wins / float(iterations)
