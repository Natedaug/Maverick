class_name NPCMemory
extends Resource
## One rival's persistent memory of one opponent (Milestone 3 contract,
## docs/NPC_MEMORY_CONTRACT.md). Explicit serializable data — not an autoload.
##
## Weight sign convention (contract §1, §2, §5):
##   negative = the rival has been burned by this opponent (sucked out on,
##              bluff caught, pushed off hands). It plays warier: folds more to
##              aggression and bluffs less.
##   positive = the rival has had the better of this opponent. It plays
##              emboldened: resists folding and calls lighter.
## Raw weight is stored unbounded; only the decision bias is capped.

const DECAY_RATE := 0.97
## Maximum probability shift memory may apply to any one decision (±15%).
const WEIGHT_BIAS_CAP := 0.15
## |weight| below this has no decision effect (contract §5 uses 0.5).
const BIAS_THRESHOLD := 0.5
## Weight at which the bias reaches its cap (contract §1 soft clamp).
const BIAS_FULL_WEIGHT := 2.0
## Tell window in hands, and how many tank/snap hands flip the state.
const TELL_WINDOW := 5
const TELL_TRIGGER := 3
## Bluff-frequency adjustments from lifetime counters (contract §5).
const OVERCONFIDENT_SUCK_OUTS := 2
const WARY_STONE_COLD := 1
const BLUFF_ADJUSTMENT := 0.05

const EVENT_DELTAS := {
	"suck_out_suffered": -0.25,
	"suck_out_delivered": 0.15,
	"stone_cold_caught": -0.30,
	"stone_cold_worked": 0.20,
	"folded_to_aggression": -0.10,
	"cooler_loss": -0.15,
	"tank": 0.0,
	"snap": 0.0,
}

var opponent_id: String = ""
var weight: float = 0.0
var hands_seen: int = 0
var last_seen_hand: int = 0
var suck_outs_suffered: int = 0
var suck_outs_delivered: int = 0
var stone_cold_bluffs: int = 0
var folded_to_aggression: int = 0
var tank_count: int = 0
var snap_count: int = 0
## Hand numbers (one entry per hand at most) with a tank / snap, newest last.
var recent_tanks: Array[int] = []
var recent_snaps: Array[int] = []

## Record one memory event. Returns false for an unknown event name.
## Tank/snap are recorded at most once per hand and do not change weight.
func record_event(event: String, hand_number: int) -> bool:
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
		"tank":
			if _recent_push(recent_tanks, hand_number):
				tank_count += 1
		"snap":
			if _recent_push(recent_snaps, hand_number):
				snap_count += 1
	return true

## Close out a hand that involved this rival: count it and decay the weight.
## Call exactly once per settled hand, after that hand's events.
func finish_hand(hand_number: int) -> void:
	hands_seen += 1
	last_seen_hand = maxi(last_seen_hand, hand_number)
	decay()

func decay() -> void:
	weight *= DECAY_RATE

## "kempt" / "unkempt" / "neutral" from tank/snap hands in the last
## TELL_WINDOW hands ending at the most recent hand seen.
func get_tell_state() -> String:
	var newest := last_seen_hand
	if not recent_tanks.is_empty():
		newest = maxi(newest, recent_tanks.back())
	if not recent_snaps.is_empty():
		newest = maxi(newest, recent_snaps.back())
	var oldest := newest - TELL_WINDOW + 1
	var tanks := _count_since(recent_tanks, oldest)
	var snaps := _count_since(recent_snaps, oldest)
	if tanks >= TELL_TRIGGER and tanks >= snaps:
		return "unkempt"
	if snaps >= TELL_TRIGGER:
		return "kempt"
	return "neutral"

## Player-facing label for the rival's current tell state ("" when neutral).
func get_label() -> String:
	match get_tell_state():
		"kempt":
			return "Kempt"
		"unkempt":
			return "Unkempt"
	return ""

## Signed decision bias in [-WEIGHT_BIAS_CAP, +WEIGHT_BIAS_CAP]. Zero inside
## the ±BIAS_THRESHOLD dead zone; scales to the cap at ±BIAS_FULL_WEIGHT.
## Used as a probability, so memory never makes a decision deterministic.
func get_bias() -> float:
	if absf(weight) < BIAS_THRESHOLD:
		return 0.0
	return clampf(weight / BIAS_FULL_WEIGHT, -1.0, 1.0) * WEIGHT_BIAS_CAP

## Additive change to the rival's bluff frequency from lifetime history.
func get_bluff_adjustment() -> float:
	var adjustment := 0.0
	if suck_outs_delivered > OVERCONFIDENT_SUCK_OUTS:
		adjustment += BLUFF_ADJUSTMENT
	if stone_cold_bluffs > WARY_STONE_COLD:
		adjustment -= BLUFF_ADJUSTMENT
	return adjustment

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
		tank_count = tank_count,
		snap_count = snap_count,
		recent_tanks = recent_tanks.duplicate(),
		recent_snaps = recent_snaps.duplicate(),
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
	mem.tank_count = int(data.get("tank_count", 0))
	mem.snap_count = int(data.get("snap_count", 0))
	for h in data.get("recent_tanks", []):
		mem.recent_tanks.append(int(h))
	for h in data.get("recent_snaps", []):
		mem.recent_snaps.append(int(h))
	return mem

## Append once per hand; keep only the newest TELL_WINDOW entries.
func _recent_push(arr: Array[int], hand_number: int) -> bool:
	if not arr.is_empty() and arr.back() == hand_number:
		return false
	arr.append(hand_number)
	while arr.size() > TELL_WINDOW:
		arr.pop_front()
	return true

func _count_since(arr: Array[int], oldest: int) -> int:
	var count := 0
	for h in arr:
		if h >= oldest:
			count += 1
	return count
