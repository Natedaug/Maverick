class_name PokerCard
extends Resource

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }
enum Rank { TWO=2, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING, ACE }

@export var suit: Suit
@export var rank: Rank
@export var special_id: String = ""  # e.g. "dead_mans_hand", "preachers_ace"

func _init(p_suit: Suit = Suit.CLUBS, p_rank: Rank = Rank.TWO, p_special: String = "") -> void:
	suit = p_suit
	rank = p_rank
	special_id = p_special

func to_code() -> String:
	var suit_names := ["c", "d", "h", "s"]
	var rank_names := ["", "", "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"]
	return rank_names[rank] + suit_names[suit]

func compare_to(other: PokerCard) -> int:
	return sign(rank - other.rank)
