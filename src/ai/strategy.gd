class_name Strategy
extends RefCounted
## Equity-driven poker policy with personality knobs.
##
## decide() returns an "intent" as a Dictionary:
##   {action: PokerBetting.Action.X, frac: float}
## where `frac` is the fraction of the pot to bet/raise with (only meaningful
## for BET/RAISE intents). Materializing legal actions is AIPlayer's job.
##
## Knobs (0.0..1.0 scales):
##   aggression      higher = bigger bets, more raises
##   tightness       higher = gets out of marginal spots faster
##   bluff_frequency chance of firing a bluff when equity is marginal

const NOISE := 0.02

var aggression: float = 0.5
var tightness: float = 0.5
var bluff_frequency: float = 0.10
var rng: RandomNumberGenerator

func _init(p_rng: RandomNumberGenerator = null) -> void:
	rng = p_rng if p_rng else RandomNumberGenerator.new()

## `street` is a PokerGameState.Street value (PREFLOP=0..RIVER=3).
## `call_amount`/`pot` come from the betting round with the pot prefetched.
func decide(equity: float, street: int, call_amount: int, pot: int, opponents: int) -> Dictionary:
	var e := clampf(equity + rng.randf_range(-NOISE, NOISE), 0.0, 1.0)

	if call_amount <= 0:
		# Check-or-bet spot
		var bet_thresh: float = 0.55 + 0.15 * (tightness - 0.5)
		if e >= bet_thresh:
			return _bet_intent()
		if _bluff_roll(street, e, opponents):
			return _bet_intent()
		return {action = PokerBetting.Action.CHECK}

	# Facing a bet: approximate required equity to continue
	var pot_total: float = float(pot) + float(call_amount)
	var required: float = float(call_amount) / pot_total
	var give_up: float = required + 0.03 + 0.15 * (tightness - 0.5)
	if e < give_up:
		# Rare bluff raise instead of folding (turn/river only, cheap spots)
		if street >= PokerGameState.Street.TURN and _bluff_roll(street, e, opponents) \
				and required < 0.35:
			return {action = PokerBetting.Action.RAISE, frac = 0.4 + 0.2 * aggression}
		return {action = PokerBetting.Action.FOLD}
	if e >= 0.78 - 0.2 * aggression:
		return {action = PokerBetting.Action.RAISE, frac = 0.5 + 0.5 * aggression}
	return {action = PokerBetting.Action.CALL}

func _bet_intent() -> Dictionary:
	return {action = PokerBetting.Action.BET, frac = 0.4 + 0.6 * aggression}

## Bluff roll: evaluates to true occasionally on later streets when the hand
## isn't hopeless but also isn't bet-worthy on its own merit.
func _bluff_roll(street: int, e: float, opponents: int) -> bool:
	if opponents > 2:
		return false
	var weight := 0.0
	match street:
		PokerGameState.Street.PREFLOP: weight = 0.3
		PokerGameState.Street.FLOP:     weight = 0.7
		PokerGameState.Street.TURN:     weight = 1.0
		_:                         weight = 1.0
	if e > 0.45:
		return false  # value betting territory, not a bluff
	return rng.randf() < bluff_frequency * weight
