class_name TownState extends Resource
## Persistent town state for one town. Explicit serializable data — not an
## autoload. Updated deterministically from settled poker hand results.

var town_id: String = ""
var prosperity: int = 0
var poker_volume: int = 0
var state: String = "neutral"

## Apply one settled hand result. `net_delta` is the player's session stack
## change from before the hand to after payouts (buy-ins/cash-outs excluded).
func apply_hand_result(net_delta: int) -> void:
	poker_volume += 1
	if net_delta > 0:
		prosperity += 1
	elif net_delta < 0:
		prosperity -= 1
	_recompute_state()

func _recompute_state() -> void:
	if prosperity >= 3:
		state = "prosperous"
		prosperity = 0
	elif prosperity <= -3:
		state = "stressed"
		prosperity = 0
