class_name PokerTable
extends Control
## Rusty Spur table controller. PokerSession owns multi-hand rules and stable
## seat ids; world services only observe its settlements.
##
## The table has no Godot-drawn interface. The Svelte app in web/ draws it:
## every change is broadcast through `state_changed`, and player intents come
## back through the public commands below (via WebBridge in the browser).
##   buy_in(chips)  player_action(action, amount)  next_hand()
##   leave_table()  save_progress()  load_progress()
## Town commands (Milestone 4 economy; only while not seated at the table):
##   buy_gold(n)  sell_gold(n)  pay_dealer(gold)  borrow_marker()
##   repay_marker(index)  sleep()
## The drifter's deed offer (between hands, when he has lost half his chips):
##   accept_deed_wager()  decline_deed_wager()

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
## The drifter's deed (Milestone 4 step 3).
const DEED_OFFER := "The drifter lays a folded deed on the felt: \"My claim in Split River, against %s of your silver. Next hand takes it.\""
const DEED_WON := "You win the drifter's claim deed. He stares at it a long moment before he lets go."
const DEED_LOST := "The drifter pockets your %s silver and tucks his deed away."
const DEED_SPLIT := "A split pot. The deed and your silver go back where they came from."
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

## Starting silver (owner decision 2026-11-04: arrive with 1,000 silver).
@export var starting_wallet_balance: int = 1000
@export var default_buy_in_chips: int = 500
@export var save_path: String = SAVE_PATH
## Silver per chip at the Rusty Spur (owner decision 2026-11-04: chips at par).
@export_range(0.01, 100.0, 0.01) var wallet_units_per_chip: float = 1.0
## The drifter offers his deed at or below this share of his buy-in (tests
## raise it to trigger the offer on demand).
@export var deed_offer_stack_share: float = DeedWager.OFFER_STACK_SHARE

var _rng := RandomNumberGenerator.new()
var _session: PokerSession
var _bridge: EconomyBridge
var _ai: AIPlayer
var _wallet: Wallet
var _town_state: TownState
var _table_reputation: TableReputation
var _save_system := SaveSystem.new()
var _rival_memory := RivalMemory.new()
var _campaign := Campaign.new()
var _buy_in_chips := 0
var _deed_offer_pending := false
var _deed_wager_active := false
var _deed_offered_this_sitting := false
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
	if WebBridge.host_present():
		# The Svelte host page draws the interface; Godot runs the game.
		_web_bridge = WebBridge.new()
		add_child(_web_bridge)
		_web_bridge.attach(self)
	elif DisplayServer.get_name() != "headless":
		_show_browser_notice()
	_render()

## Opened outside the browser (e.g. the Godot editor's Play button).
func _show_browser_notice() -> void:
	var notice := Label.new()
	notice.text = "Maverick's interface runs in the browser.\n\n" \
		+ "cd web && npm run godot:export && npm run dev\nthen open http://localhost:5174"
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 22)
	notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(notice)

func _initialize_world_data() -> void:
	_wallet = Wallet.new()
	_wallet.balance = starting_wallet_balance
	_town_state = TownState.new()
	_town_state.town_id = TOWN_ID
	_table_reputation = TableReputation.new()
	_table_reputation.table_id = TABLE_ID
	if _save_system.load_game(_wallet, _town_state, _table_reputation, save_path, _rival_memory, _campaign):
		_last_message = "Your saved game is ready. Day %d in Devil's Draw." % _campaign.day
	else:
		_last_message = "You ride into Devil's Draw with 1,000 silver and a marker: " \
			+ "you owe The Dealer 250 gold by day 14."

func buy_in(chip_amount: int) -> void:
	if _session != null:
		return
	if _campaign.ledger.barred:
		_set_message("The House won't seat you until your called marker is paid.")
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

	_buy_in_chips = chip_amount
	_deed_offer_pending = false
	_deed_wager_active = false
	_deed_offered_this_sitting = false
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

func player_action(action: int, target: int) -> void:
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

func next_hand() -> void:
	if _session == null or not _hand_settled or _settlement_reveal_pending:
		return
	if _deed_offer_pending:
		_decline_offer_quietly()
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
	var deed_line := ""
	if _deed_wager_active:
		# Before record_settlement, so losing the deed shows on him right away.
		_deed_wager_active = false
		match DeedWager.resolve(payouts, PLAYER_SEAT, RIVAL_SEAT, _campaign.ledger, _wallet,
				rival_mem, _session.hand_number):
			"player":
				deed_line = DEED_WON
			"rival":
				deed_line = DEED_LOST % _format_amount(DeedWager.STAKE_SILVER)
			_:
				deed_line = DEED_SPLIT
	_rival_memory.record_settlement(_session, payouts)
	_hand_settled = true
	if payouts.is_empty():
		_last_message = "The pot was settled."
	else:
		var descriptions: Array[String] = []
		for seat_id in payouts:
			var winner_name := "You" if int(seat_id) == 0 else "The drifter"
			descriptions.append("%s take%s %s chips" % [winner_name, "" if int(seat_id) == 0 else "s", _format_amount(int(payouts[seat_id]))])
		_last_message = "; ".join(descriptions) + "."
	_record_history(_last_message)
	if not deed_line.is_empty():
		_record_history(deed_line)
		_last_message += " " + deed_line
	if rival_mem.kempt != was_kempt:
		var look_line := LOOK_UNKEMPT if was_kempt else LOOK_KEMPT
		_record_history(look_line)
		_last_message += " " + look_line
	_last_message += " Rusty Spur: %s. Reputation: %s." % [
		_town_state.state, _table_reputation.get_label()]
	_maybe_offer_deed()
	_settlement_reveal_pending = true
	_render()
	await _pause_hand(SHOWDOWN_REVEAL_SECONDS)
	_settlement_reveal_pending = false
	_render()

## Between hands: a drifter who has lost half his chips stakes his claim.
func _maybe_offer_deed() -> void:
	var stacks := _session.stacks()
	if stacks[PLAYER_SEAT] <= 0 or stacks[RIVAL_SEAT] <= 0:
		return
	if not DeedWager.should_offer(_campaign.ledger, _wallet, stacks[RIVAL_SEAT], _buy_in_chips,
			_deed_offered_this_sitting, deed_offer_stack_share):
		return
	_deed_offer_pending = true
	_deed_offered_this_sitting = true
	_record_history(DEED_OFFER % _format_amount(DeedWager.STAKE_SILVER))

func accept_deed_wager() -> void:
	if not _deed_offer_pending or _settlement_reveal_pending:
		return
	if not DeedWager.accept(_wallet):
		_set_message("You don't have %s silver to put against the deed." % _format_amount(DeedWager.STAKE_SILVER))
		return
	_deed_offer_pending = false
	_deed_wager_active = true
	_record_history("You put %s silver against the drifter's deed. The next hand decides it."
		% _format_amount(DeedWager.STAKE_SILVER))
	next_hand()

func decline_deed_wager() -> void:
	if not _deed_offer_pending:
		return
	_decline_offer_quietly()
	_set_message("You wave off the deed. The drifter tucks it back in his coat.")

func _decline_offer_quietly() -> void:
	_deed_offer_pending = false
	_record_history("You turned down the drifter's deed.")

func _pause_hand(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func leave_table() -> void:
	if _session == null or _settlement_reveal_pending:
		return
	if not _hand_settled:
		_set_message("Finish this hand before leaving the table.")
		return
	if _deed_offer_pending:
		_decline_offer_quietly()
	_end_session("You left the table and cashed out.")

func _end_session(message: String) -> void:
	if _bridge != null:
		var chip_amount := _bridge.cash_out()
		_last_message = "%s %s chips returned to your wallet." % [message, _format_amount(chip_amount)]
	_session = null
	_bridge = null
	_ai = null
	_hand_settled = false
	_deed_offer_pending = false
	_deed_wager_active = false
	_render()

func save_progress() -> void:
	if _settlement_reveal_pending:
		return
	if _session != null and not _hand_settled:
		_set_message("Save after this hand settles, so your chips are included.")
		return
	if _session != null:
		_end_session("Table closed for saving.")
	if _save_system.save_game(_wallet, _town_state, _table_reputation, save_path, _rival_memory, _campaign):
		_set_message("Progress saved.")
	else:
		_set_message("Could not write the save file.")

func load_progress() -> void:
	if _settlement_reveal_pending:
		return
	if _session != null and not _hand_settled:
		_set_message("Finish this hand before loading a save.")
		return
	if _session != null:
		_end_session("Table closed before loading.")
	if _save_system.load_game(_wallet, _town_state, _table_reputation, save_path, _rival_memory, _campaign):
		_set_message("Saved game loaded. Day %d in Devil's Draw." % _campaign.day)
	else:
		_set_message("No readable save file was found.")

# --- Town commands (Milestone 4 economy) ---

## Town business happens away from the table.
func _in_town() -> bool:
	if _session != null:
		_set_message("Leave the table first.")
		return false
	return true

func buy_gold(gold: int) -> void:
	if not _in_town():
		return
	var cost := AssayOffice.quote_buy(_town_state, gold)
	if AssayOffice.buy_gold(_wallet, _town_state, gold):
		_town_event("The assay office weighs out %d gold for %s silver." % [gold, _format_amount(cost)])
	else:
		_set_message("You don't have the silver for that much gold.")

func sell_gold(gold: int) -> void:
	if not _in_town():
		return
	var proceeds := AssayOffice.quote_sell(_town_state, gold)
	if AssayOffice.sell_gold(_wallet, _town_state, gold):
		_town_event("You sell %d gold for %s silver." % [gold, _format_amount(proceeds)])
	else:
		_set_message("You don't have that much gold.")

func pay_dealer(gold: int) -> void:
	if not _in_town():
		return
	var ledger := _campaign.ledger
	if ledger.pay_dealer(_wallet, gold):
		if ledger.dealer_owed_gold == 0:
			_town_event("You send %d gold to The Dealer. The marker is paid in full." % gold)
		else:
			_town_event("You send %d gold to The Dealer. %d gold still owed." % [gold, ledger.dealer_owed_gold])
	else:
		_set_message("You need the gold in hand, and no more than you owe.")

func borrow_marker() -> void:
	if not _in_town():
		return
	if _campaign.ledger.borrow(_wallet, _campaign.day):
		_town_event("The barkeep writes you a marker for %d silver." % Ledger.MARKER_SILVER)
	elif _campaign.ledger.barred:
		_set_message("The House won't lend to you until your called marker is paid.")
	else:
		_set_message("The House won't carry more than %d markers." % Ledger.MAX_MARKERS)

func repay_marker(index: int) -> void:
	if not _in_town():
		return
	var ledger := _campaign.ledger
	if index < 0 or index >= ledger.markers.size():
		return
	var cost := ledger.repay_cost(index, _campaign.day)
	if ledger.repay(_wallet, index, _campaign.day):
		_town_event("You pay off a marker for %s silver." % _format_amount(cost))
	else:
		_set_message("You need %s silver to pay off that marker." % _format_amount(cost))

## Sleep at the boarding house; a new day begins.
func sleep() -> void:
	if not _in_town():
		return
	var events := _campaign.sleep(_wallet)
	var lines: Array[String] = ["Day %d. You wake at the boarding house." % _campaign.day]
	for event in events:
		match event:
			"claim_income":
				lines.append("Your claim pays %d silver." % Ledger.CLAIM_INCOME_SILVER)
			"deed_seized":
				lines.append("The House called an old marker and took your claim deed.")
			"barred":
				lines.append("The House called an old marker. You're barred from the tables until it's paid.")
			"dealer_overdue":
				lines.append("The Dealer's marker is past due. Word travels fast downriver.")
	if _campaign.day == _campaign.ledger.dealer_due_day and _campaign.ledger.dealer_owed_gold > 0:
		lines.append("The Dealer's marker is due today.")
	_town_event(" ".join(lines))

func _town_event(message: String) -> void:
	_record_history(message)
	_set_message(message)

func _economy_status() -> Dictionary:
	var ledger := _campaign.ledger
	var markers: Array = []
	for i in range(ledger.markers.size()):
		markers.append({
			taken_day = ledger.markers[i],
			repay_silver = ledger.repay_cost(i, _campaign.day),
			days_until_called = ledger.markers[i] + Ledger.CALLED_AT_DAYS - _campaign.day,
		})
	var gold_quotes: Array = []
	for amount in [1, 5, 10, 25, 50]:
		gold_quotes.append({gold = amount, buy_silver = AssayOffice.quote_buy(_town_state, amount),
			sell_silver = AssayOffice.quote_sell(_town_state, amount)})
	var max_buy := 0
	while AssayOffice.quote_buy(_town_state, max_buy + 1) <= _wallet.balance:
		max_buy += 1
	return {
		gold = _wallet.gold,
		day = _campaign.day,
		season_days = Campaign.SEASON_DAYS,
		gold_rate = AssayOffice.rate(_town_state),
		gold_quotes = gold_quotes,
		max_gold_affordable = max_buy,
		dealer_start_gold = Ledger.DEALER_START_GOLD,
		dealer_owed_gold = ledger.dealer_owed_gold,
		dealer_due_day = ledger.dealer_due_day,
		dealer_overdue = ledger.dealer_overdue(_campaign.day),
		markers = markers,
		marker_silver = Ledger.MARKER_SILVER,
		marker_terms = {early_silver = Ledger.REPAY_EARLY_SILVER, late_silver = Ledger.REPAY_LATE_SILVER,
			early_days = Ledger.EARLY_DAYS, called_at_days = Ledger.CALLED_AT_DAYS},
		can_borrow = ledger.can_borrow(),
		barred = ledger.barred,
		has_claim_deed = ledger.has_claim_deed,
		claim_income_silver = Ledger.CLAIM_INCOME_SILVER,
	}

func _set_message(message: String) -> void:
	_last_message = message
	_render()

func _render() -> void:
	if _wallet == null:
		return
	var status := {
		wallet_balance = _wallet.get_balance(),
		wallet_units_per_chip = wallet_units_per_chip,
		town_state = _town_state.state,
		poker_volume = _town_state.poker_volume,
		reputation = _table_reputation.get_label(),
		session_active = _session != null,
		buy_in_chips = default_buy_in_chips,
		can_afford_buy_in = wallet_units_per_chip > 0.0 and not _campaign.ledger.barred \
			and _wallet.get_balance() >= _wallet_cost(default_buy_in_chips),
		rival_kempt = _rival_memory.get_memory(str(PLAYER_SEAT)).kempt,
		rival_timing = _rival_timing,
		hand_settled = _hand_settled,
		economy = _economy_status(),
		deed = {
			offer_pending = _deed_offer_pending,
			wager_active = _deed_wager_active,
			stake_silver = DeedWager.STAKE_SILVER,
			value_gold = Ledger.CLAIM_VALUE_GOLD,
			income_silver = Ledger.CLAIM_INCOME_SILVER,
			can_afford = _wallet.balance >= DeedWager.STAKE_SILVER,
		},
	}
	var phase := ""
	if _opening_reveal_pending:
		phase = "reveal_cards"
	elif _settlement_reveal_pending:
		phase = "settling"
	elif _session != null and _hand_settled:
		phase = "hand_over"
	if _session == null:
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
