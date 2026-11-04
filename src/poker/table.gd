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
## The Crown confrontation (Augustus Crane, the Gilded Riverboat):
##   accept_crown(level)  decline_crown()  concede_duel()  dismiss_crown_result()
## The season (Milestone 4 step 5):
##   begin_season()  (after the arrival)  new_game()  (away from the table)
## Walking the town (TownMap): move(direction)  go_to_place(place)

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
## The Crown confrontation (Milestone 4 step 4). Working name: Augustus Crane.
const CRANE := "Crane"
const CRANE_EQUITY_ITERATIONS := 160
const RIVERBOAT := "The Gilded Riverboat"
const CRANE_INVITE_ARRIVAL := "The Gilded Riverboat tied up at the Devil's Draw landing before dawn. A steward finds you at breakfast: Mr. Augustus Crane would like a word, and a game."
const CRANE_INVITE_WORDS := "\"You've been taking silver out of my valley, friend. I don't mind. I'd just like the chance to take it back. One table, heads-up, until one of us is broke.\""
const CRANE_SUMMON_ARRIVAL := "The Gilded Riverboat is waiting at the landing, and two of Crane's men are waiting at your door."
const CRANE_SUMMON_WORDS := "\"The Dealer sold me your paper. I could collect it the dull way. Or you can sit down with me and try to win some of it back.\""
const CRANE_WIN_WORDS := "Crane turns his cards face down with a thin smile. \"Well played. The Dealer will hear your account is lighter.\""
const CRANE_LOSE_WORDS := "Crane gathers the chips without looking at them. \"Don't take it hard. Everyone in this valley pays me eventually.\""
const CRANE_DECLINE := "Crane's steward bows. \"Mr. Crane will be disappointed.\" The riverboat casts off by noon."
## The arrival, shown once at the start of a new game (Milestone 4 step 5).
const ARRIVAL := [
	"You ride into Devil's Draw at dusk with 1,000 silver in your saddlebag and a marker in your coat. It says you owe The Dealer 250 gold, due on day 14.",
	"The Rusty Spur is the only lit window on the street. A drifter deals at the back table. He doesn't forget a face, and he doesn't hide it when he's rattled. Watch how he carries himself.",
	"Win silver at the table. Trade it for gold at the assay office. The House will lend, at a price. Sleep at the boarding house to end the day. And mind the river: a man named Crane runs this valley from a riverboat.",
]
const ARRIVAL_NOTE := "You rode into Devil's Draw owing The Dealer 250 gold, due on day 14."
const TOWN_NOTES := {
	prosperous = "Devil's Draw turned prosperous. Gold got cheaper at the assay office.",
	stressed = "Devil's Draw turned stressed. Gold got dearer at the assay office.",
	neutral = "Devil's Draw settled back to ordinary.",
}
const CRANE_SUMMONS_LIFTED := "With The Dealer paid, Crane's men leave your door. The riverboat casts off."
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
## True while the Crown match is being played (instead of the Rusty Spur game).
var _duel := false
var _duel_path := ""  # "invited" / "summoned"
var _duel_level := ""  # "standard" / "double"
## The last match's outcome for the result screen; empty once dismissed.
var _crown_result: Dictionary = {}
var _last_message := "Welcome to the Rusty Spur. Buy in when you're ready."
var _history: Array[String] = []
var _hand_settled := false
var _continuation_running := false
var _opening_reveal_pending := false
var _settlement_reveal_pending := false
var _runout_visible_board_cards := -1
var _rival_timing := ""  # "tank" / "snap" / "normal" while the rival thinks
var _web_bridge: WebBridge
var _town_map: TownMap

func _ready() -> void:
	_rng.randomize()
	_initialize_world_data()
	_town_map = TownMap.new()
	add_child(_town_map)
	_town_map.near_changed.connect(func(_place: String) -> void: _render())
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
	_fresh_world()
	if _save_system.load_game(_wallet, _town_state, _table_reputation, save_path, _rival_memory, _campaign):
		_last_message = "Your saved game is ready. Day %d in Devil's Draw." % _campaign.day
	else:
		_fresh_world()

## A new season: fresh wallet, town, reputation, rival memory, and campaign.
func _fresh_world() -> void:
	_wallet = Wallet.new()
	_wallet.balance = starting_wallet_balance
	_town_state = TownState.new()
	_town_state.town_id = TOWN_ID
	_table_reputation = TableReputation.new()
	_table_reputation.table_id = TABLE_ID
	_rival_memory.clear()
	_campaign = Campaign.new()
	_campaign.note(ARRIVAL_NOTE)
	_history.clear()
	_crown_result = {}
	_last_message = "You ride into Devil's Draw with %s silver and a marker: you owe The Dealer %d gold by day %d." \
		% [_format_amount(starting_wallet_balance), Ledger.DEALER_START_GOLD, Ledger.DEALER_DUE_DAY]

## Close the arrival and start playing.
func begin_season() -> void:
	if _campaign.intro_seen:
		return
	_campaign.intro_seen = true
	_render()

## Start over. Your saved game is replaced the next time you save or sleep.
func new_game() -> void:
	if not _in_town():
		return
	_fresh_world()
	_render()

## Save quietly in town (each morning, and after Crane). Returns success.
func _autosave() -> bool:
	if _session != null:
		return false
	return _save_system.save_game(_wallet, _town_state, _table_reputation, save_path, _rival_memory, _campaign)

func buy_in(chip_amount: int) -> void:
	if _session != null:
		return
	if _campaign.ledger.barred:
		_set_message("The House won't seat you until your called marker is paid.")
		return
	if _campaign.crown_status == "summoned":
		_set_message("Crane's men are at the door. Nobody seats you until you've seen him.")
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
	await _deal(true)

## Deal the first or next hand. In the Crown match, blinds rise on schedule.
func _deal(first: bool) -> void:
	if _duel:
		var blinds := CrownDuel.blinds_for_hand(_session.hand_number + 1)
		_session.small_blind = int(blinds[0])
		_session.big_blind = int(blinds[1])
	else:
		_bridge.hand_started()
	var dealt := _session.start_hand() if first else _session.start_next_hand()
	if not dealt:
		if _duel:
			_finish_duel(_session.stacks()[PLAYER_SEAT] > 0)
		else:
			_end_session("The table is settled. Cash out or buy in again when ready.")
		return
	if not _duel:
		_rival_memory.begin_hand(_session, RIVAL_SEAT)
	_hand_settled = false
	_opening_reveal_pending = true
	_last_message = ("Your cards are dealt." if first else "Your new cards are dealt.") \
		+ " Take a moment to study them."
	_record_history(_last_message)
	_render()
	await _pause_hand(OPENING_REVEAL_SECONDS)
	_opening_reveal_pending = false
	var blinds_text := "Blinds are %d / %d." % [_session.small_blind, _session.big_blind]
	_last_message = ("You're in. " if first else "Next hand. ") + blinds_text
	_continue_hand()

func player_action(action: int, target: int) -> void:
	if _session == null or _hand_settled or _session.current_actor() != 0:
		return
	var facing_bet := _call_amount() > 0
	if not _session.apply_action(0, action as PokerBetting.Action, target):
		_set_message("That action is no longer legal. Choose from the lit options.")
		return
	if not _duel:
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
	await _deal(false)

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
				_last_message = "%s goes into the tank..." % _opponent()
				think_seconds = AI_TANK_SECONDS
			"snap":
				_last_message = "%s acts without a pause." % _opponent()
				think_seconds = AI_SNAP_SECONDS
			_:
				_last_message = "%s studies the table." % _opponent()
		_render()
		await _pause_hand(think_seconds)
		if _session == null or _hand_settled:
			_continuation_running = false
			return
		_rival_timing = ""
		var rival_facing_bet := _call_amount() > 0
		var decision := _ai.decide_session(_session)
		if not _duel:
			_rival_memory.observe_action(RIVAL_SEAT, decision.action, rival_facing_bet)
		_last_message = "%s %s." % [_opponent(), _describe_action(decision.action, decision.amount, true)]
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
	if _duel:
		await _settle_duel_hand(payouts)
		return
	var town_before := _town_state.state
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
		_campaign.note(deed_line)
		_last_message += " " + deed_line
	if rival_mem.kempt != was_kempt:
		var look_line := LOOK_UNKEMPT if was_kempt else LOOK_KEMPT
		_record_history(look_line)
		_campaign.note(look_line)
		_last_message += " " + look_line
	if _town_state.state != town_before:
		_campaign.note(str(TOWN_NOTES.get(_town_state.state, "")))
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
	if _duel:
		_set_message("There's no walking away from Crane's table. Concede if you're done.")
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
	_duel = false
	_render()

func save_progress() -> void:
	if _settlement_reveal_pending:
		return
	if _duel:
		_set_message("Finish the match with Crane before saving.")
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
	if _duel:
		_set_message("Finish the match with Crane before loading.")
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
			var paid_line := "You send %d gold to The Dealer. The marker is paid in full." % gold
			if _campaign.crown_status == "summoned":
				_campaign.crown_status = "none"
				paid_line += " " + CRANE_SUMMONS_LIFTED
			_campaign.note(paid_line)
			_town_event(paid_line)
		else:
			var part_line := "You sent %d gold to The Dealer. %d gold still owed." % [gold, ledger.dealer_owed_gold]
			_campaign.note(part_line)
			_town_event(part_line)
	else:
		_set_message("You need the gold in hand, and no more than you owe.")

func borrow_marker() -> void:
	if not _in_town():
		return
	if _campaign.ledger.borrow(_wallet, _campaign.day):
		_campaign.note("You took a House marker for %d silver." % Ledger.MARKER_SILVER)
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
		_campaign.note("You paid off a House marker for %s silver." % _format_amount(cost))
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
				_campaign.note("The House called an old marker and took your claim deed.")
			"barred":
				lines.append("The House called an old marker. You're barred from the tables until it's paid.")
				_campaign.note("The House called a marker you couldn't cover. You were barred from the tables.")
			"dealer_overdue":
				lines.append("The Dealer's marker is past due. Word travels fast downriver.")
				_campaign.note("The Dealer's marker went past due.")
	if _campaign.day == _campaign.ledger.dealer_due_day and _campaign.ledger.dealer_owed_gold > 0:
		lines.append("The Dealer's marker is due today.")
	var arrival := CrownDuel.check_arrival(_campaign, _wallet, _town_state)
	if not arrival.is_empty():
		_campaign.crown_status = arrival
		lines.append(CRANE_INVITE_ARRIVAL if arrival == "invited" else CRANE_SUMMON_ARRIVAL)
		_campaign.note("The Gilded Riverboat docked. Augustus Crane %s." % (
			"invited you to a game" if arrival == "invited" else "bought your marker and summoned you"))
	if _autosave():
		lines.append("(Saved.)")
	_town_event(" ".join(lines))

# --- The Crown confrontation (Milestone 4 step 4) ---

func _opponent() -> String:
	return CRANE if _duel else "The drifter"

func accept_crown(level: String) -> void:
	if not _in_town() or not CrownDuel.is_pending(_campaign.crown_status) or not level in CrownDuel.LEVELS:
		return
	_duel = true
	_duel_path = _campaign.crown_status
	_duel_level = level
	_crown_result = {}
	_deed_offer_pending = false
	_deed_wager_active = false
	var stacks: Array[int] = [CrownDuel.DUEL_STACK, CrownDuel.DUEL_STACK]
	var first_blinds := CrownDuel.blinds_for_hand(1)
	_session = PokerSession.new(stacks, 0, int(first_blinds[0]), int(first_blinds[1]), _rng)
	var strategy := Strategy.new(_rng)
	strategy.aggression = 0.7
	strategy.tightness = 0.55
	strategy.bluff_frequency = 0.12
	_ai = AIPlayer.new(RIVAL_SEAT, strategy)
	_ai.equity_iterations = CRANE_EQUITY_ITERATIONS
	_history.clear()
	_record_history("You sit down across from Augustus Crane on the Gilded Riverboat. %s stakes."
		% ("Double" if level == "double" else "Standard"))
	_start_first_hand()

func decline_crown() -> void:
	if not _in_town() or _campaign.crown_status != "invited":
		return
	_campaign.crown_status = "declined"
	_campaign.note("You sent Augustus Crane away.")
	_town_event(CRANE_DECLINE)

## Concede between hands; counts as a loss.
func concede_duel() -> void:
	if not _duel or _session == null or not _hand_settled or _settlement_reveal_pending:
		return
	_record_history("You concede the match.")
	_finish_duel(false)

func dismiss_crown_result() -> void:
	if _crown_result.is_empty():
		return
	_crown_result = {}
	_render()

func _settle_duel_hand(payouts: Dictionary) -> void:
	_hand_settled = true
	var descriptions: Array[String] = []
	for seat_id in payouts:
		var winner := "You take" if int(seat_id) == PLAYER_SEAT else "Crane takes"
		descriptions.append("%s %s chips" % [winner, _format_amount(int(payouts[seat_id]))])
	_last_message = "; ".join(descriptions) + "." if not descriptions.is_empty() else "The pot was settled."
	_record_history(_last_message)
	_settlement_reveal_pending = true
	_render()
	await _pause_hand(SHOWDOWN_REVEAL_SECONDS)
	_settlement_reveal_pending = false
	if _session == null:
		return
	var stacks := _session.stacks()
	if stacks[PLAYER_SEAT] <= 0 or stacks[RIVAL_SEAT] <= 0:
		_finish_duel(stacks[PLAYER_SEAT] > 0)
	else:
		_render()

func _finish_duel(won: bool) -> void:
	var lines := CrownDuel.apply_result(won, _duel_path, _duel_level, _campaign, _wallet, _town_state)
	var words := CRANE_WIN_WORDS if won else CRANE_LOSE_WORDS
	_crown_result = {won = won, words = words, lines = lines}
	_record_history(words)
	_campaign.note("You %s Augustus Crane on the Gilded Riverboat (%s stakes)." % [
		"beat" if won else "lost to", _duel_level])
	for line in lines:
		_record_history(line)
		_campaign.note(line)
	_session = null
	_ai = null
	_hand_settled = false
	_duel = false
	_last_message = ("You beat Augustus Crane. " if won else "Augustus Crane beat you. ") + lines[0]
	_autosave()
	_render()

## Plain-language stakes for the dialogue choice.
func _crown_terms(path: String, level: String) -> Dictionary:
	var t := CrownDuel.terms(path, level, _campaign.ledger.has_claim_deed)
	var lose: Array[String] = []
	if bool(t.lose_deed):
		lose.append("your claim deed")
	if float(t.lose_share) > 0.0:
		lose.append("%d%% of your silver and gold" % int(round(float(t.lose_share) * 100.0)))
	if int(t.penalty_gold) > 0:
		lose.append("%d more gold on your marker" % int(t.penalty_gold))
	return {
		win = "Crane squares %d gold of your debt with The Dealer, and the town prospers." % int(t.win_gold_off),
		lose = "He takes %s, and the town is stressed." % " and ".join(lose),
	}

func _crown_status() -> Dictionary:
	var status := _campaign.crown_status
	var out := {status = status, result = _crown_result.duplicate(true)}
	if CrownDuel.is_pending(status):
		out["arrival"] = CRANE_INVITE_ARRIVAL if status == "invited" else CRANE_SUMMON_ARRIVAL
		out["words"] = CRANE_INVITE_WORDS if status == "invited" else CRANE_SUMMON_WORDS
		out["can_decline"] = status == "invited"
		out["terms"] = {standard = _crown_terms(status, "standard"), double = _crown_terms(status, "double")}
		out["duel_stack"] = CrownDuel.DUEL_STACK
	return out

func _table_status() -> Dictionary:
	var out := {
		mode = "duel" if _duel else "cash",
		venue = RIVERBOAT if _duel else "The Rusty Spur",
		opponent = {id = "crane" if _duel else "drifter", name = "Augustus Crane" if _duel else "The Drifter"},
		small_blind = SMALL_BLIND,
		big_blind = BIG_BLIND,
	}
	if _session != null:
		out.small_blind = _session.small_blind
		out.big_blind = _session.big_blind
	if _duel and _session != null:
		var hand := maxi(_session.hand_number, 1)
		out["blind_level"] = int(CrownDuel.blinds_for_hand(hand)[2]) + 1
		out["hands_to_next_level"] = CrownDuel.hands_to_next_level(hand)
	return out

# --- Walking the town ---

## Walking intent from the interface. Ignored while seated at a table.
func move(direction: Vector2) -> void:
	if _town_map == null:
		return
	_town_map.set_move(Vector2.ZERO if _session != null else direction)

## Stand at a place's door (opening a place from the menu).
func go_to_place(place: String) -> void:
	if _town_map != null and _session == null and _town_map.go_to(place):
		_render()

func _world_status() -> Dictionary:
	if _town_map == null:
		return {}
	var places := {}
	for id in TownMap.PLACES:
		places[id] = TownMap.PLACES[id].name
	return {near = _town_map.near, places = places, has_art = _town_map.has_art()}

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
		crown = _crown_status(),
		intro = [] if _campaign.intro_seen else ARRIVAL.duplicate(),
		journal = _campaign.journal.duplicate(true),
		world = _world_status(),
		table = _table_status(),
		deed = {
			offer_pending = _deed_offer_pending,
			wager_active = _deed_wager_active,
			stake_silver = DeedWager.STAKE_SILVER,
			value_gold = Ledger.CLAIM_VALUE_GOLD,
			income_silver = Ledger.CLAIM_INCOME_SILVER,
			can_afford = _wallet.balance >= DeedWager.STAKE_SILVER,
		},
	}
	if _town_map != null:
		_town_map.set_scene(_rival_memory.get_memory(str(PLAYER_SEAT)).kempt,
			CrownDuel.is_pending(_campaign.crown_status))
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

## Thousands separators, matching the web app ("1,838").
func _format_amount(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < 0 else "") + out
