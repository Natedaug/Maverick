class_name TableReputation extends Resource
## Player reputation at one table. Lifetime cumulative net stack change from
## hands played at that table in the current save. Explicit serializable data.

var table_id: String = ""
var lifetime_net: int = 0

## Apply one settled hand result to the lifetime running total.
func apply_hand_result(net_delta: int) -> void:
	lifetime_net += net_delta

## Current reputation label derived from lifetime_net.
func get_label() -> String:
	if lifetime_net > 0:
		return "known winner"
	elif lifetime_net < 0:
		return "known loser"
	return "unknown"
