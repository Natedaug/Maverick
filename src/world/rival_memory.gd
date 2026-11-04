class_name RivalMemory
extends RefCounted
## One rival NPC's memories, one NPCMemory per opponent id. The table owns the
## instance (explicit data, saved through SaveSystem — not an autoload).
##
## Per hand, the table calls:
##   begin_hand(session, rival_seat)          after the hand is dealt
##   observe_action(seat, action, facing_bet) before applying each action
##   record_settlement(session, payouts)      once, after PokerSession.settle()
##
## Fairness: attribution uses only what the rival may know — its own hole
## cards, public actions/board, and opponent cards revealed at showdown.
## Hands won by a fold never inspect the opponent's cards.

const RANKS := "23456789TJQKA"
const SUITS := "cdhs"

var memories: Dictionary = {}  # opponent_id (String) -> NPCMemory

var _rival_seat: int = -1
var _hand_number: int = 0
var _opponents: Array[int] = []
var _last_aggressor: int = -1
var _rival_folded_to: int = -1  # seat whose bet/raise the rival folded to
var _hand_open := false

## Get or create the memory entry for `opponent_id`.
func get_memory(opponent_id: String) -> NPCMemory:
	if not memories.has(opponent_id):
		var mem := NPCMemory.new()
		mem.opponent_id = opponent_id
		memories[opponent_id] = mem
	return memories[opponent_id]

func clear() -> void:
	memories.clear()
	_hand_open = false

func begin_hand(session: PokerSession, rival_seat: int) -> void:
	_rival_seat = rival_seat
	_hand_number = session.hand_number
	_opponents.clear()
	for seat in session.snapshot(-1).get("seats", []):
		var sid := int(seat.get("id", -1))
		if sid >= 0 and sid != rival_seat and not bool(seat.get("out", false)):
			_opponents.append(sid)
	_last_aggressor = -1
	_rival_folded_to = -1
	_hand_open = true

## Report an action before it is applied. `facing_bet` is true when the actor
## had chips to call.
func observe_action(seat: int, action: PokerBetting.Action, facing_bet: bool) -> void:
	if not _hand_open:
		return
	if action == PokerBetting.Action.BET or action == PokerBetting.Action.RAISE:
		_last_aggressor = seat
	elif action == PokerBetting.Action.FOLD and seat == _rival_seat and facing_bet:
		_rival_folded_to = _last_aggressor

## Attribute this hand's memory events and close the hand. Safe to call once;
## further calls before the next begin_hand() do nothing.
func record_settlement(session: PokerSession, payouts: Dictionary) -> void:
	if not _hand_open:
		return
	_hand_open = false
	var public_view := session.snapshot(-1)
	var own_view := session.snapshot(_rival_seat)
	var board := _cards(public_view.get("board", []))
	var rival_row := _seat_row(own_view, _rival_seat)
	var rival_hole := _cards(rival_row.get("cards", []))
	var rival_won := int(payouts.get(_rival_seat, 0)) > 0

	for opp in _opponents:
		var mem := get_memory(str(opp))
		var opp_row := _seat_row(public_view, opp)
		var opp_hole := _cards(opp_row.get("cards", []))
		var showdown := not bool(rival_row.get("folded", false)) \
			and not bool(opp_row.get("folded", false)) and opp_hole.size() == 2
		var opp_won := int(payouts.get(opp, 0)) > 0

		if _rival_folded_to == opp:
			mem.record_event("folded_to_aggression", _hand_number)

		# Stone-cold bluff: the rival made the last bet/raise holding nothing
		# (high card on the final board).
		if _last_aggressor == _rival_seat and board.size() >= 3 \
				and _best(rival_hole, board).category == PokerHandRank.Category.HIGH_CARD:
			if bool(opp_row.get("folded", false)) and rival_won:
				mem.record_event("stone_cold_worked", _hand_number)
			elif showdown and opp_won and not rival_won:
				mem.record_event("stone_cold_caught", _hand_number)

		if showdown and board.size() == 5:
			_attribute_showdown(mem, rival_hole, opp_hole, board, rival_won, opp_won)

		mem.finish_hand(_hand_number)

func _attribute_showdown(mem: NPCMemory, rival_hole: Array[PokerCard],
		opp_hole: Array[PokerCard], board: Array[PokerCard],
		rival_won: bool, opp_won: bool) -> void:
	var turn_board: Array[PokerCard] = board.slice(0, 4)
	var turn_cmp := _best(rival_hole, turn_board).compare(_best(opp_hole, turn_board))
	var rival_lost := opp_won and not rival_won
	var opp_lost := rival_won and not opp_won
	if turn_cmp > 0 and rival_lost:
		mem.record_event("suck_out_suffered", _hand_number)
	elif turn_cmp < 0 and opp_lost:
		mem.record_event("suck_out_delivered", _hand_number)
	elif rival_lost and _best(rival_hole, board).category >= PokerHandRank.Category.TWO_PAIR:
		mem.record_event("cooler_loss", _hand_number)

## Best five-card hand from hole cards plus a 3-5 card board.
func _best(hole: Array[PokerCard], board: Array[PokerCard]) -> PokerHandEvaluator.Result:
	var cards: Array[PokerCard] = []
	cards.append_array(hole)
	cards.append_array(board)
	if cards.size() == 5 or cards.size() == 7:
		return PokerHandEvaluator.evaluate(cards)
	assert(cards.size() == 6, "expected 5-7 cards (got %d)" % cards.size())
	var best: PokerHandEvaluator.Result = null
	for skip in range(6):
		var five: Array[PokerCard] = []
		for i in range(6):
			if i != skip:
				five.append(cards[i])
		var r := PokerHandEvaluator.evaluate_five(five)
		if best == null or r.compare(best) > 0:
			best = r
	return best

func _seat_row(view: Dictionary, seat_id: int) -> Dictionary:
	for row in view.get("seats", []):
		if int(row.get("id", -1)) == seat_id:
			return row
	return {}

func _cards(codes: Array) -> Array[PokerCard]:
	var out: Array[PokerCard] = []
	for code in codes:
		var text := str(code)
		var rank := RANKS.find(text.substr(0, 1))
		var suit := SUITS.find(text.substr(1, 1))
		if rank >= 0 and suit >= 0:
			out.append(PokerCard.new(suit as PokerCard.Suit, (rank + 2) as PokerCard.Rank))
	return out
