class_name NPCMemory
extends Resource
## One rival's persistent memory of one opponent (Milestone 3 contract,
## docs/NPC_MEMORY_CONTRACT.md). Explicit serializable data — not an autoload.
##
## Weight sign convention (contract §1, §2):
##   negative = the rival has been burned by this opponent (sucked out on,
##              bluff caught, pushed off hands).
##   positive = the rival has had the better of this opponent.
## Raw weight is stored unbounded; only the decision bias is capped.
##
## The tell (contract §4, revised 2026-11-04) is a single visible binary:
## `kempt`. Enough tilt (weight <= -UNKEMPT_AT) and the rival turns unkempt —
## dusty and disheveled — and plays loose: calls lighter, bluffs more. He
## cleans up only once weight recovers above -CLEAN_UP_AT, so the look holds
## for several hands instead of flickering. It changes only between hands.

const DECAY_RATE := 0.97
## Maximum probability shift memory may apply to any one decision (±15%).
const WEIGHT_BIAS_CAP := 0.15
## Weight at which the bias reaches its cap (contract §1 soft clamp).
const BIAS_FULL_WEIGHT := 2.0
## Tilt needed to turn unkempt, and the recovery needed to clean up again.
const UNKEMPT_AT := 0.5
const CLEAN_UP_AT := 0.25
## Smallest loose-play shift while unkempt (fraction of WEIGHT_BIAS_CAP).
const UNKEMPT_MIN_SHARE := 0.25

const EVENT_DELTAS := {
	"suck_out_suffered": -0.25,
	"suck_out_delivered": 0.15,
	"stone_cold_caught": -0.30,
	"stone_cold_worked": 0.20,
	"folded_to_aggression": -0.10,
	"cooler_loss": -0.15,
}

var opponent_id: String = ""
var weight: float = 0.0
var hands_seen: int = 0
var last_seen_hand: int = 0
var suck_outs_suffered: int = 0
var suck_outs_delivered: int = 0
var stone_cold_bluffs: int = 0
var folded_to_aggression: int = 0
## The visible tell: clean and composed (true) or dusty and tilted (false).
var kempt: bool = true

## Record one memory event. Returns false for an unknown event name.
## Appearance does not change until finish_hand().
func record_event(event: String, _hand_number: int) -> bool:
	if not EVENT_DELTAS.has(event):
		push_error("NPCMemory: unknown event %s" % event)
		return false
	weight += EVENT_DELTAS[event]
	match event:
		"suck_out_suffered":
			suck_outs_suffered += 1
		"suck_out_delivered":
			suck_outs_delivered += 1
		"stone_cold_caught":
			stone_cold_bluffs += 1
		"folded_to_aggression":
			folded_to_aggression += 1
	return true

## Close out a hand that involved this rival: count it, decay the weight,
## then update his appearance. Call exactly once per settled hand, after that
## hand's events.
func finish_hand(hand_number: int) -> void:
	hands_seen += 1
	last_seen_hand = maxi(last_seen_hand, hand_number)
	decay()
	update_appearance()

## Apply the kempt/unkempt hysteresis to the current weight.
func update_appearance() -> void:
	if kempt and weight <= -UNKEMPT_AT:
		kempt = false
	elif not kempt and weight > -CLEAN_UP_AT:
		kempt = true

func decay() -> void:
	weight *= DECAY_RATE

## Loose-play shift in [0, WEIGHT_BIAS_CAP]: zero while kempt; while
## unkempt it grows with tilt, from UNKEMPT_MIN_SHARE of the cap up to the
## cap at -BIAS_FULL_WEIGHT. Used as a probability, so memory never makes a
## decision deterministic.
func get_bias() -> float:
	if kempt:
		return 0.0
	return clampf(-weight / BIAS_FULL_WEIGHT, UNKEMPT_MIN_SHARE, 1.0) * WEIGHT_BIAS_CAP

func to_dict() -> Dictionary:
	return {
		opponent_id = opponent_id,
		weight = weight,
		hands_seen = hands_seen,
		last_seen_hand = last_seen_hand,
		suck_outs_suffered = suck_outs_suffered,
		suck_outs_delivered = suck_outs_delivered,
		stone_cold_bluffs = stone_cold_bluffs,
		folded_to_aggression = folded_to_aggression,
		kempt = kempt,
	}

static func from_dict(data: Dictionary) -> NPCMemory:
	var mem := NPCMemory.new()
	mem.opponent_id = str(data.get("opponent_id", ""))
	mem.weight = float(data.get("weight", 0.0))
	mem.hands_seen = int(data.get("hands_seen", 0))
	mem.last_seen_hand = int(data.get("last_seen_hand", 0))
	mem.suck_outs_suffered = int(data.get("suck_outs_suffered", 0))
	mem.suck_outs_delivered = int(data.get("suck_outs_delivered", 0))
	mem.stone_cold_bluffs = int(data.get("stone_cold_bluffs", 0))
	mem.folded_to_aggression = int(data.get("folded_to_aggression", 0))
	# Saves from before the appearance tell derive it from weight.
	mem.kempt = bool(data.get("kempt", mem.weight > -UNKEMPT_AT))
	return mem
