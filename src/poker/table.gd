class_name PokerTable
extends Control
## Human-vs-AI table controller. Poker rules remain in the reusable addon.

const STARTING_STACK := 1000
const SMALL_BLIND := 10
const BIG_BLIND := 20
const AI_EQUITY_ITERATIONS := 80

@onready var table_ui: PokerTableUI = $PokerTableUI

var _rng := RandomNumberGenerator.new()
var _stacks: Array[int] = [STARTING_STACK, STARTING_STACK]
var _button := 0
var _hand: PokerGameState
var _ai: AIPlayer
var _last_message := ""
var _history: Array[String] = []

func _ready() -> void:
	_rng.randomize()
	table_ui.player_action_requested.connect(_on_player_action_requested)
	table_ui.next_hand_requested.connect(_on_next_hand_requested)
	_start_hand()

func _start_hand() -> void:
	var rebuy := false
	if _stacks[0] <= 0 or _stacks[1] <= 0:
		_stacks = [STARTING_STACK, STARTING_STACK]
		_button = 0
		rebuy = true
	_hand = PokerGameState.new(_stacks, _button, SMALL_BLIND, BIG_BLIND, _rng)
	var strategy := Strategy.new(_rng)
	strategy.aggression = 0.55
	strategy.tightness = 0.48
	strategy.bluff_frequency = 0.08
	_ai = AIPlayer.new(1, strategy)
	_ai.equity_iterations = AI_EQUITY_ITERATIONS
	_last_message = "A fresh 1,000-chip stake. Blinds are 10 / 20." \
		if rebuy else "New hand. Blinds are 10 / 20."
	_record_history(_last_message)
	_render()
	_continue_hand()

func _on_player_action_requested(action: int, target: int) -> void:
	if _hand == null or _hand.current_actor() == null or _hand.current_actor().id != 0:
		return
	if not _hand.apply_action(0, action as PokerBetting.Action, target):
		_last_message = "That action is no longer legal. Choose from the lit options."
		_render()
		return
	_last_message = "You %s." % _describe_action(action, target)
	_record_history(_last_message)
	_continue_hand()

func _on_next_hand_requested() -> void:
	if _hand == null or _hand.stage != PokerGameState.Street.SHOWDOWN:
		return
	_button = (_button + 1) % 2
	_start_hand()

func _continue_hand() -> void:
	var guard := 0
	while guard < 100 and _hand.stage != PokerGameState.Street.SHOWDOWN:
		guard += 1
		if _hand.players_left() <= 1:
			_settle_hand()
			break
		if _hand.is_street_over():
			if _hand.can_run_out():
				_hand.run_out()
				_last_message = "The remaining board is dealt."
				_record_history(_last_message)
				_settle_hand()
				break
			if _hand.stage == PokerGameState.Street.RIVER:
				_settle_hand()
				break
			_hand.advance_street()
			_last_message = "The %s is dealt." % _street_name(_hand.stage)
			_record_history(_last_message)
			_render()
			continue
		var actor: PokerBetting.Seat = _hand.current_actor()
		if actor == null:
			break
		if actor.id == 0:
			_last_message = _player_prompt()
			_render()
			return
		var decision := _ai.decide(_hand)
		_last_message = "The drifter %s." % _describe_action(decision.action, decision.amount)
		_record_history(_last_message)
		_render()
	if guard >= 100:
		_last_message = "The hand stopped after too many turns. Please start a new hand."
	_render()

func _settle_hand() -> void:
	var payouts := _hand.settle()
	_stacks = _hand.stacks()
	if payouts.is_empty():
		_last_message = "The pot was settled."
	else:
		var winner: int = payouts.keys()[0]
		var amount: int = payouts[winner]
		var name := "You" if winner == 0 else "The drifter"
		_last_message = "%s take%s %s chips. Select Next hand when you're ready." % [name, "" if winner == 0 else "s", str(amount)]
		_record_history(_last_message)
	_render()

func _render() -> void:
	if _hand == null or not is_instance_valid(table_ui):
		return
	var message := _last_message
	if _hand.stage == PokerGameState.Street.SHOWDOWN and (_stacks[0] == 0 or _stacks[1] == 0):
		message += " The table will offer a fresh 1,000-chip stake next hand."
	table_ui.render(_hand.snapshot(0), message, _history)

func _record_history(entry: String) -> void:
	_history.append(entry)
	while _history.size() > 20:
		_history.pop_front()

func _player_prompt() -> String:
	var call_amount := _hand.betting.amount_to_call(0)
	if call_amount > 0:
		return "Your turn. %s chips to call." % str(call_amount)
	return "Your turn. Check or open the betting."

func _describe_action(action: int, target: int) -> String:
	match action:
		PokerBetting.Action.FOLD:
			return "fold"
		PokerBetting.Action.CHECK:
			return "check"
		PokerBetting.Action.CALL:
			return "call"
		PokerBetting.Action.BET:
			return "bet to %s" % str(target)
		PokerBetting.Action.RAISE:
			return "raise to %s" % str(target)
	return "act"

func _street_name(street: int) -> String:
	match street:
		PokerGameState.Street.FLOP:
			return "flop"
		PokerGameState.Street.TURN:
			return "turn"
		PokerGameState.Street.RIVER:
			return "river"
	return "next street"
