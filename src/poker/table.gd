class_name PokerTable
extends Control
## Player-facing Rusty Spur table controller. PokerSession owns multi-hand
## rules and stable seat ids; world services only observe its settlements.

const SMALL_BLIND := 10
const BIG_BLIND := 20
const AI_EQUITY_ITERATIONS := 80
const OPENING_REVEAL_SECONDS := 0.75
const PLAYER_ACTION_CONFIRM_SECONDS := 0.35
const AI_THINK_SECONDS := 0.55
## Rival think-time flavor: a visible long pause or an instant action. Not a
## tell — the tell is the drifter's appearance (NPCMemory.kempt).
const AI_TANK_SECONDS := 1.8
const AI_SNAP_SECONDS := 0.12
## History lines when the drifter's appearance changes between hands.
const LOOK_UNKEMPT := "The drifter's collar has come loose; there's trail dust on his coat."
const LOOK_KEMPT := "The drifter straightens his hat and brushes the dust from his coat."
const PLAYER_SEAT := 0
const RIVAL_SEAT := 1
const AI_ACTION_REVEAL_SECONDS := 0.65
const STREET_REVEAL_SECONDS := 0.7
const RUNOUT_STREET_SECONDS := 0.65
const SHOWDOWN_REVEAL_SECONDS := 1.2
const SAVE_PATH := "user://maverick_save.txt"
const TOWN_ID := "devils_draw"
const TABLE_ID := "rusty_spur"

## Full table state after every change, for alternate front ends (WebBridge).
## Keys: snapshot (empty when unseated), message, history, status, phase.
signal state_changed(state: Dictionary)

@export var starting_wallet_balance: int = 5000
@export var default_buy_in_chips: int = 1000
@export var save_path: String = SAVE_PATH
## Prototype default only. Change in the Inspector; the currency exchange rate
## remains undecided and this value does not establish canon.
@export_range(0.01, 100.0, 0.01) var wallet_units_per_chip: float = 1.0

@onready var table_ui: PokerTableUI = $PokerTableUI

var _rng := RandomNumberGenerator.new()
var _session: PokerSession
var _bridge: EconomyBridge
var _ai: AIPlayer
var _wallet: Wallet
var _town_state: TownState
var _table_reputation: TableReputation
var _save_system := SaveSystem.new()
var _rival_memory := RivalMemory.new()
var _last_message := "Welcome to the Rusty Spur. Buy in when you're ready."
var _history: Array[String] = []
var _hand_settled := false
var _continuation_running := false
var _opening_reveal_pending := false
var _settlement_reveal_pending := false
var _runout_visible_board_cards := -1
var _rival_timing := ""  # "tank" / "snap" / "normal" while the rival thinks
var _web_bridge: WebBridge

func _ready() -> void:
	_rng.randomize()
	_initialize_world_data()
	table_ui.player_action_requested.connect(_on_player_action_requested)
	table_ui.next_hand_requested.connect(_on_next_hand_requested)
	table_ui.buy_in_requested.connect(_on_buy_in_requested)
	table_ui.leave_table_requested.connect(_on_leave_table_requested)
	table_ui.save_requested.connect(_on_save_requested)
	table_ui.load_requested.connect(_on_load_requested)
	if WebBridge.host_present():
		# A Svelte host page draws the interface; Godot keeps running the game.
		_web_bridge = WebBridge.new()
		add_child(_web_bridge)
		_web_bridge.attach(self, table_ui)
		table_ui.visible = false
	_render()

func _initialize_world_data() -> void:
	_wallet = Wallet.new()
	_wallet.balance = starting_wallet_balance
	_town_state = TownState.new()
	_town_state.town_id = TOWN_ID
	_table_reputation = TableReputation.new()
	_table_reputation.table_id = TABLE_ID
	if _save_system.load_game(_wallet, _town_state, _table_reputation, save_path, _rival_memory):
		_last_message = "Your saved Rusty Spur record is ready. Buy in to take a seat."
	else:
		_last_message = "A new wallet is ready. Buy in to take a seat."

func _on_buy_in_requested(chip_amount: int) -> void:
	if _session != null:
		return
	if chip_amount <= 0:
		_set_message("Choose a positive buy-in.")
		return
	_bridge = EconomyBridge.new()
	_bridge.wallet = _wallet
	_bridge.wallet_units_per_chip = wallet_units_per_chip
	_bridge.player_seat = 0
	_bridge.town_state = _town_state
	_bridge.table_reputation = _table_reputation
	if not _bridge.buy_in(chip_amount):
		_bridge = null
		_set_message("Your wallet doesn't cover that buy-in.")
		return

	var starting_stacks: Array[int] = [chip_amount, chip_amount]
	_session = PokerSession.new(starting_stacks, 0, SMALL_BLIND, BIG_BLIND, _rng)
	_bridge.session = _session
	var strategy := Strategy.new(_rng)
	strategy.aggression = 0.55
	strategy.tightness = 0.48
	strategy.bluff_frequency = 0.08
	_ai = AIPlayer.new(RIVAL_SEAT, strategy)
	_ai.equity_iterations = AI_EQUITY_ITERATIONS
	_ai.set_memory(_rival_memory.get_memory(str(PLAYER_SEAT)))
	_history.clear()
	_start_first_hand()

func _start_first_hand() -> void:
	_bridge.hand_started()
	if not _session.start_hand():
		_end_session("The table could not start a hand.")
		return
	_rival_memory.begin_hand(_session, RIVAL_SEAT)
	_hand_settled = false
	_opening_reveal_pending = true
	_last_message = "Your cards are dealt. Take a moment to study them."
	_record_history(_last_message)
	_render()
	await _pause_hand(OPENING_REVEAL_SECONDS)
	_opening_reveal_pending = false
	_last_message = "You're in. Blinds are 10 / 20."
	_continue_hand()

func _on_player_action_requested(action: int, target: int) -> void:
	if _session == null or _hand_settled or _session.current_actor() != 0:
		return
	var facing_bet := _call_amount() > 0
	if not _session.apply_action(0, action as PokerBetting.Action, target):
		_set_message("That action is no longer legal. Choose from the lit options.")
		return
	_rival_memory.observe_action(PLAYER_SEAT, action as PokerBetting.Action, facing_bet)
	_last_message = "You %s." % _describe_action(action, target)
	_record_history(_last_message)
	_render()
	await _pause_hand(PLAYER_ACTION_CONFIRM_SECONDS)
	_continue_hand()

func _on_next_hand_requested() -> void:
	if _session == null or not _hand_settled:
		return
	_bridge.hand_started()
	if not _session.start_next_hand():
		_end_session("The table is settled. Cash out or buy in again when ready.")
		return
	_rival_memory.begin_hand(_session, RIVAL_SEAT)
	_hand_settled = false
	_opening_reveal_pending = true
	_last_message = "Your new cards are dealt. Take a moment to study them."
	_record_history(_last_message)
	_render()
	await _pause_hand(OPENING_REVEAL_SECONDS)
	_opening_reveal_pending = false
	_last_message = "Next hand. Blinds are 10 / 20."
	_continue_hand()

func _continue_hand() -> void:
	if _continuation_running:
		return
	_continuation_running = true
	var guard := 0
	while _session != null and guard < 100:
		guard += 1
		if _session.players_left() <= 1:
			await _settle_hand()
			_continuation_running = false
			return
		if _session.is_street_over():
			if _session.can_run_out():
				var prior_board_size: int = _session.snapshot(0).board.size()
				_session.run_out()
				await _reveal_runout(prior_board_size)
				await _settle_hand()
				_continuation_running = false
				return
			if _session.current_stage() == PokerGameState.Street.RIVER:
				await _settle_hand()
				_continuation_running = false
				return
			_session.advance_street()
			_last_message = "The %s is dealt." % _street_name(_session.current_stage())
			_record_history(_last_message)
			_render()
			await _pause_hand(STREET_REVEAL_SECONDS)
			continue
		var actor := _session.current_actor()
		if actor < 0:
			break
		if actor == 0:
			_last_message = _player_prompt()
			_render()
			_continuation_running = false
			return
		var timing := _ai.pick_timing()
		_rival_timing = timing
		var think_seconds := AI_THINK_SECONDS
		match timing:
			"tank":
				_last_message = "The drifter goes into the tank..."
				think_seconds = AI_TANK_SECONDS
			"snap":
				_last_message = "The drifter acts without a pause."
				think_seconds = AI_SNAP_SECONDS
			_:
				_last_message = "The drifter studies the table."
		_render()
		await _pause_hand(think_seconds)
		if _session == null or _hand_settled:
			_continuation_running = false
			return
		_rival_timing = ""
		var rival_facing_bet := _call_amount() > 0
		var decision := _ai.decide_session(_session)
		_rival_memory.observe_action(RIVAL_SEAT, decision.action, rival_facing_bet)
		_last_message = "The drifter %s." % _describe_action(decision.action, decision.amount, true)
		_record_history(_last_message)
		_render()
		await _pause_hand(AI_ACTION_REVEAL_SECONDS)
	if guard >= 100:
		_set_message("The hand stopped after too many turns. Please leave the table.")
	else:
		_render()
	_continuation_running = false

func _reveal_runout(prior_board_size: int) -> void:
	var first_visible_count := 3 if prior_board_size == 0 else prior_board_size + 1
	for visible_count in range(first_visible_count, 6):
		_runout_visible_board_cards = visible_count
		_last_message = "The %s is dealt." % _street_name_for_board_size(visible_count)
		_record_history(_last_message)
		_render()
		await _pause_hand(RUNOUT_STREET_SECONDS)
	_runout_visible_board_cards = -1

func _settle_hand() -> void:
	if _session == null or _hand_settled:
		return
	var payouts := _session.settle()
	_bridge.hand_settled()
	var rival_mem := _rival_memory.get_memory(str(PLAYER_SEAT))
	var was_kempt := rival_mem.kempt
	_rival_memory.record_settlement(_session, payouts)
	_hand_settled = true
	if payouts.is_empty():
		_last_message = "The pot was settled."
	else:
		var descriptions: Array[String] = []
		for seat_id in payouts:
			var winner_name := "You" if int(seat_id) == 0 else "The Drifter"
			descriptions.append("%s take%s %s chips" % [winner_name, "" if int(seat_id) == 0 else "s", _format_amount(int(payouts[seat_id]))])
		_last_message = "; ".join(descriptions) + "."
	_record_history(_last_message)
	if rival_mem.kempt != was_kempt:
		var look_line := LOOK_UNKEMPT if was_kempt else LOOK_KEMPT
		_record_history(look_line)
		_last_message += " " + look_line
	_last_message += " Rusty Spur: %s. Reputation: %s." % [
		_town_state.state, _table_reputation.get_label()]
	_settlement_reveal_pending = true
	_render()
	await _pause_hand(SHOWDOWN_REVEAL_SECONDS)
	_settlement_reveal_pending = false
	_render()

func _pause_hand(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _on_leave_table_requested() -> void:
	if _session == null or _settlement_reveal_pending:
		return
	if not _hand_settled:
		_set_message("Finish this hand before leaving the table.")
		return
	_end_session("You left the table and cashed out.")

func _end_session(message: String) -> void:
	if _bridge != null:
		var chip_amount := _bridge.cash_out()
		_last_message = "%s %s chips returned to your wallet." % [message, _format_amount(chip_amount)]
	_session = null
	_bridge = null
	_ai = null
	_hand_settled = false
	_render()

func _on_save_requested() -> void:
	if _settlement_reveal_pending:
		return
	if _session != null and not _hand_settled:
		_set_message("Save after this hand settles, so your chips are included.")
		return
	if _session != null:
		_end_session("Table closed for saving.")
	if _save_system.save_game(_wallet, _town_state, _table_reputation, save_path, _rival_memory):
		_set_message("Rusty Spur progress saved.")
	else:
		_set_message("Could not write the save file.")

func _on_load_requested() -> void:
	if _settlement_reveal_pending:
		return
	if _session != null and not _hand_settled:
		_set_message("Finish this hand before loading a save.")
		return
	if _session != null:
		_end_session("Table closed before loading.")
	if _save_system.load_game(_wallet, _town_state, _table_reputation, save_path, _rival_memory):
		_set_message("Saved Rusty Spur progress loaded. Buy in when ready.")
	else:
		_set_message("No readable save file was found.")

func _set_message(message: String) -> void:
	_last_message = message
	_render()

func _render() -> void:
	if not is_instance_valid(table_ui):
		return
	var status := {
		wallet_balance = _wallet.get_balance(),
		wallet_units_per_chip = wallet_units_per_chip,
		town_state = _town_state.state,
		poker_volume = _town_state.poker_volume,
		reputation = _table_reputation.get_label(),
		session_active = _session != null,
		buy_in_chips = default_buy_in_chips,
		can_afford_buy_in = wallet_units_per_chip > 0.0 \
			and _wallet.get_balance() >= _wallet_cost(default_buy_in_chips),
		rival_kempt = _rival_memory.get_memory(str(PLAYER_SEAT)).kempt,
		rival_timing = _rival_timing,
		hand_settled = _hand_settled,
	}
	var phase := ""
	if _opening_reveal_pending:
		phase = "reveal_cards"
	elif _settlement_reveal_pending:
		phase = "settling"
	elif _session != null and _hand_settled:
		phase = "hand_over"
	if _session == null:
		table_ui.render({}, _last_message, _history, status)
		state_changed.emit({snapshot = {}, message = _last_message,
			history = _history.duplicate(), status = status, phase = phase})
	else:
		var snapshot := _session.snapshot(0)
		if _opening_reveal_pending:
			# Keep the action dock disabled while the player reads the newly dealt cards.
			snapshot["current_actor"] = 1
			snapshot["available_actions"] = []
		if _settlement_reveal_pending:
			# Hold the hand in its reveal state until the result has been visible.
			snapshot["stage"] = "river"
			snapshot["current_actor"] = -1
			snapshot["available_actions"] = []
		if _runout_visible_board_cards >= 0:
			var board: Array = snapshot.get("board", [])
			snapshot["board"] = board.slice(0, _runout_visible_board_cards)
		table_ui.render(snapshot, _last_message, _history, status)
		state_changed.emit({snapshot = snapshot, message = _last_message,
			history = _history.duplicate(), status = status, phase = phase})

func _wallet_cost(chips: int) -> int:
	return int(round(float(chips) * wallet_units_per_chip))

func _record_history(entry: String) -> void:
	_history.append(entry)
	while _history.size() > 20:
		_history.pop_front()

## Chips the current actor must add to call (0 when checking is free).
func _call_amount() -> int:
	for option in _session.available_actions():
		if option.get("action", -1) == PokerBetting.Action.CALL:
			return int(option.get("amount", 0))
	return 0

func _player_prompt() -> String:
	var actions: Array[Dictionary] = _session.available_actions()
	for option in actions:
		if option.get("action", -1) == PokerBetting.Action.CALL:
			return "Your turn. %s chips to call." % _format_amount(int(option.get("amount", 0)))
	return "Your turn. Check or open the betting."

## `third_person` gives "folds"/"bets" for the drifter instead of "fold"/"bet".
func _describe_action(action: int, target: int, third_person: bool = false) -> String:
	var s := "s" if third_person else ""
	match action:
		PokerBetting.Action.FOLD:
			return "fold" + s
		PokerBetting.Action.CHECK:
			return "check" + s
		PokerBetting.Action.CALL:
			return "call" + s
		PokerBetting.Action.BET:
			return "bet%s %s" % [s, _format_amount(target)]
		PokerBetting.Action.RAISE:
			return "raise%s to %s" % [s, _format_amount(target)]
	return "act" + s

func _street_name(street: int) -> String:
	match street:
		PokerGameState.Street.FLOP:
			return "flop"
		PokerGameState.Street.TURN:
			return "turn"
		PokerGameState.Street.RIVER:
			return "river"
	return "next street"

func _street_name_for_board_size(card_count: int) -> String:
	match card_count:
		3:
			return "flop"
		4:
			return "turn"
		5:
			return "river"
	return "next card"

func _format_amount(value: int) -> String:
	return str(value)
