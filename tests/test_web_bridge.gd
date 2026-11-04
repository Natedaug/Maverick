extends SceneTree
## Drives the Rusty Spur table only through WebBridge JSON messages, the way
## the Svelte host page does. Run: godot --headless --path . -s tests/test_web_bridge.gd

const TABLE_SCENE := preload("res://scenes/poker/poker_table.tscn")
const SAVE_PATH := "/tmp/maverick_test_web_bridge.txt"

var _failures := 0
var _passes := 0
var _bridge: WebBridge
var _last: Dictionary = {}
var _messages_sent := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _wait_for(condition: Callable, timeout_seconds: float = 15.0) -> bool:
	var waited := 0.0
	while not condition.call():
		if waited >= timeout_seconds:
			return false
		await create_timer(0.05).timeout
		waited += 0.05
	return true

## Send a command exactly as the page does: as a JSON string.
func _send(command: Dictionary) -> bool:
	var parsed: Variant = JSON.parse_string(JSON.stringify(command))
	return _bridge.handle_command(parsed)

func _on_sent(json: String) -> void:
	_messages_sent += 1
	var parsed: Variant = JSON.parse_string(json)
	_check(typeof(parsed) == TYPE_DICTIONARY, "bridge always sends a JSON object")
	if typeof(parsed) == TYPE_DICTIONARY:
		_last = parsed

## The drifter stakes his deed; the offer threshold is raised so it comes at once.
func _test_deed_flow() -> void:
	var table: PokerTable = TABLE_SCENE.instantiate()
	table.save_path = SAVE_PATH + ".deed"
	if FileAccess.file_exists(table.save_path):
		DirAccess.remove_absolute(table.save_path)
	table.starting_wallet_balance = 5000
	table.deed_offer_stack_share = 10.0
	root.add_child(table)
	await process_frame
	_bridge = WebBridge.new()
	table.add_child(_bridge)
	_bridge.attach(table)
	_bridge.state_sent.connect(_on_sent)
	_send({type = "buy_in", chips = 500})
	_check(await _wait_for(_player_can_act), "deed flow: player gets a decision")
	_send({type = "action", action = PokerBetting.Action.FOLD, amount = 0})
	_check(await _wait_for(func(): return _last.get("phase", "") == "hand_over"), "deed flow: hand over")
	var deed: Dictionary = _last.status.get("deed", {})
	_check(bool(deed.get("offer_pending", false)) and int(deed.get("stake_silver", 0)) == 500,
		"the drifter offers his deed against 500 silver")
	_check(str(_last.history.back()).contains("My claim in Split River"), "the offer is in the history")
	var silver := int(_last.status.wallet_balance)
	_check(_send({type = "deed_accept"}), "deed_accept accepted")
	_check(int(_last.status.wallet_balance) == silver - 500, "the stake is escrowed")
	_check(bool(_last.status.deed.wager_active) and int(_last.snapshot.get("hand_number", 0)) == 2,
		"the wager rides on hand 2")
	var done := func():
		return _last.get("phase", "") == "hand_over" or _player_can_act()
	while await _wait_for(done) and _player_can_act():
		_send({type = "action", action = PokerBetting.Action.FOLD, amount = 0})
	_check(_last.get("phase", "") == "hand_over", "deed hand settles")
	_check(not bool(_last.status.deed.wager_active), "the wager is settled")
	if bool(_last.status.economy.has_claim_deed):
		# The drifter folded first: the deed is yours and your stake comes back.
		_check(int(_last.status.wallet_balance) == silver, "won the deed; stake returned")
		_check(str(_last.history).contains("You win the drifter's claim deed"), "the win is in the history")
	else:
		_check(int(_last.status.wallet_balance) == silver - 500, "folding loses the stake; he keeps the deed")
		_check(str(_last.history).contains("pockets your 500 silver"), "the loss is in the history")
	_check(not bool(_last.status.deed.offer_pending), "he only offers once per sitting")
	table.queue_free()
	await process_frame

## The arrival, the journal, and starting over (Milestone 4 step 5).
func _test_season_commands() -> void:
	var journal: Array = _last.status.get("journal", [])
	var text := str(journal)
	_check(text.contains("owing The Dealer 250 gold"), "the journal starts with the arrival")
	_check(text.contains("You took a House marker") and text.contains("You paid off a House marker"),
		"the journal records the House Line")
	_check(text.contains("You sent 5 gold to The Dealer"), "the journal records Dealer payments")
	_check(text.contains("barred from the tables") and text.contains("went past due"),
		"the journal records the called marker and the overdue debt")
	_check(not text.contains("You wake"), "the journal skips routine mornings")
	_check(int(journal[0].get("day", 0)) == 1, "entries carry their day")
	_check(_send({type = "new_game"}), "new_game accepted")
	_check(int(_eco().day) == 1 and int(_eco().dealer_owed_gold) == 250 and int(_last.status.wallet_balance) == 5000,
		"a new game starts the season over")
	_check((_last.status.intro as Array).size() == 3, "a new game shows the arrival")
	_check((_last.status.journal as Array).size() == 1, "a new game starts a new journal")
	_check(_send({type = "begin"}) and (_last.status.intro as Array).is_empty(), "begin closes the arrival")

func _new_table(silver: int, tag: String) -> PokerTable:
	var table: PokerTable = TABLE_SCENE.instantiate()
	table.save_path = SAVE_PATH + "." + tag
	if FileAccess.file_exists(table.save_path):
		DirAccess.remove_absolute(table.save_path)
	table.starting_wallet_balance = silver
	root.add_child(table)
	await process_frame
	_bridge = WebBridge.new()
	table.add_child(_bridge)
	_bridge.attach(table)
	_bridge.state_sent.connect(_on_sent)
	return table

func _crown() -> Dictionary:
	return _last.get("status", {}).get("crown", {})

## Play one Crown hand by folding when prompted, then wait for it to settle.
func _play_out_hand() -> bool:
	var done := func():
		return _last.get("phase", "") == "hand_over" or _player_can_act() or _last.get("snapshot", {}).is_empty()
	while await _wait_for(done) and _player_can_act():
		_send({type = "action", action = PokerBetting.Action.FOLD, amount = 0})
	return _last.get("phase", "") == "hand_over" or _last.get("snapshot", {}).is_empty()

func _test_crown_invited_flow() -> void:
	var table := await _new_table(3500, "crown")
	_check(str(_crown().get("status", "")) == "none", "crown: nothing before the riverboat arrives")
	_send({type = "sleep"})
	_check(str(_crown().status) == "invited", "3,500 silver: Crane invites you")
	_check(str(_last.message).contains("Gilded Riverboat"), "the arrival is announced")
	_check(bool(_crown().can_decline) and str(_crown().words).begins_with("\""), "an invitation can be declined; Crane speaks")
	_check(str(_crown().terms.standard.lose).contains("40%"), "no deed: standard loss is 40%")
	_check(not _send({type = "crown_accept", level = "triple"}), "unknown stake level rejected")
	_check(_send({type = "crown_accept", level = "standard"}), "crown_accept accepted")
	var t: Dictionary = _last.status.table
	_check(str(t.mode) == "duel" and str(t.opponent.id) == "crane" and str(t.venue) == "The Gilded Riverboat",
		"the match is on the riverboat against Crane")
	_check(int(t.small_blind) == 25 and int(t.big_blind) == 50 and int(t.blind_level) == 1, "level 1 blinds: 25/50")
	var seats: Array = _last.snapshot.seats
	_check(int(seats[0].stack) + int(seats[0].street_commitment) == 1500 \
		and int(seats[1].stack) + int(seats[1].street_commitment) == 1500, "both start with 1,500 chips")
	_check(int(_last.status.wallet_balance) == 3500, "the match doesn't cost silver to sit")
	_check(await _play_out_hand(), "a Crane hand settles")
	_send({type = "leave"})
	_check(str(_last.status.table.mode) == "duel", "you can't walk away mid-match")
	_send({type = "save"})
	_check(str(_last.message).contains("Finish the match"), "no saving mid-match")
	if _last.get("snapshot", {}).is_empty():
		_check(true, "the match ended on the first hand")
	else:
		_check(_send({type = "concede"}), "concede accepted")
	var result: Dictionary = _crown().get("result", {})
	_check(not result.is_empty() and (result.get("lines", []) as Array).size() >= 2, "the result screen has Crane's verdict")
	if bool(result.get("won", false)):
		_check(str(_crown().status) == "won" and str(_last.status.town_state) == "prosperous", "won: the town prospers")
	else:
		_check(str(_crown().status) == "lost" and str(_last.status.town_state) == "stressed", "lost: the town is stressed")
		_check(int(_last.status.wallet_balance) == 2100, "lost without a deed: he takes 40% (3,500 -> 2,100)")
		_check(str(result.words).contains("pays me eventually"), "Crane's closing words")
	_check(_last.get("snapshot", {}).is_empty() and str(_last.status.table.mode) == "cash", "back in Devil's Draw")
	var journal_text := str(_last.status.journal)
	_check(journal_text.contains("Augustus Crane on the Gilded Riverboat") and journal_text.contains("docked"),
		"the journal records Crane's arrival and the match")
	_check(_send({type = "crown_dismiss"}) and (_crown().result as Dictionary).is_empty(), "dismiss the result")
	for i in range(15):
		_send({type = "sleep"})
	_check(str(_crown().status) in ["won", "lost"], "one confrontation per season: no summons afterwards")
	_send({type = "buy_in", chips = 100})
	_check(not _last.get("snapshot", {}).is_empty() and str(_last.status.table.opponent.id) == "drifter",
		"play continues at the Rusty Spur")
	table.queue_free()
	await process_frame

func _test_crown_summoned_flow() -> void:
	var table := await _new_table(1000, "summons")
	for i in range(14):
		_send({type = "sleep"})
	_check(str(_crown().status) == "summoned" and not bool(_crown().can_decline), "day 15, marker unpaid: summoned")
	_check(not _send({type = "crown_decline"}) or str(_crown().status) == "summoned", "a summons can't be declined")
	_send({type = "buy_in", chips = 100})
	_check(_last.get("snapshot", {}).is_empty() and str(_last.message).contains("Crane's men"),
		"the Rusty Spur won't seat you")
	_check(str(_crown().terms.double.lose).contains("80%") and str(_crown().terms.double.lose).contains("100 more gold"),
		"summoned double: 80% and 100 more gold on the marker")
	_send({type = "crown_accept", level = "double"})
	_check(await _play_out_hand(), "a summoned hand settles")
	if not _last.get("snapshot", {}).is_empty():
		_send({type = "concede"})
	if not bool(_crown().result.get("won", false)):
		_check(int(_eco().dealer_owed_gold) == 350 and int(_last.status.wallet_balance) <= 200,
			"lost a doubled summons: 80% taken, marker now 350 gold")
	table.queue_free()
	await process_frame

func _eco() -> Dictionary:
	return _last.get("status", {}).get("economy", {})

## Milestone 4 town business, entirely through JSON as the page sends it.
func _test_town_commands() -> void:
	var eco := _eco()
	_check(int(eco.get("day", 0)) == 1 and int(eco.get("dealer_owed_gold", 0)) == 250,
		"status carries day 1 and The Dealer's 250 gold")
	_check(int(eco.get("gold_rate", 0)) == 20 or int(eco.get("gold_rate", 0)) == 24 \
		or int(eco.get("gold_rate", 0)) == 18, "status carries the gold rate")
	_check((eco.get("gold_quotes", []) as Array).size() == 5, "status carries exact gold quotes")
	var silver := int(_last.status.wallet_balance)
	var quote := int(eco.gold_quotes[1].buy_silver)
	_check(_send({type = "buy_gold", gold = 5}), "buy_gold accepted")
	_check(int(_eco().gold) == 5 and int(_last.status.wallet_balance) == silver - quote,
		"bought 5 gold at the quoted price")
	_check(_send({type = "pay_dealer", gold = 5}), "pay_dealer accepted")
	_check(int(_eco().dealer_owed_gold) == 245 and int(_eco().gold) == 0, "paid The Dealer 5 gold")
	_check(_send({type = "borrow"}), "borrow accepted")
	_check((_eco().markers as Array).size() == 1 and int(_eco().markers[0].repay_silver) == 600,
		"one marker, 600 to repay this week")
	_check(_send({type = "sleep"}), "sleep accepted")
	_check(int(_eco().day) == 2 and str(_last.message).begins_with("Day 2"), "a new day")
	for i in range(14):
		_send({type = "sleep"})
	_check(bool(_eco().barred) and int(_eco().day) == 16, "an unpaid marker is called: barred")
	_check(bool(_eco().dealer_overdue), "The Dealer's marker is overdue after day 14")
	var balance_before := int(_last.status.wallet_balance)
	_send({type = "buy_in", chips = 100})
	_check(_last.get("snapshot", {}).is_empty() and int(_last.status.wallet_balance) == balance_before,
		"barred: the House refuses a seat")
	_check(_send({type = "repay", index = 0}), "repay accepted")
	_check(not bool(_eco().barred) and (_eco().markers as Array).is_empty(), "paying the marker lifts the bar")
	_check(_send({type = "save"}) and _send({type = "sleep"}), "save, then sleep")
	_check(str(_last.message).contains("(Saved.)"), "each morning autosaves")
	_check(_send({type = "load"}) and int(_eco().day) == 17, "load restores the morning autosave")
	_test_season_commands()

func _seats() -> Array:
	return _last.get("snapshot", {}).get("seats", [])

func _player_can_act() -> bool:
	var snap: Dictionary = _last.get("snapshot", {})
	return _last.get("phase", "") == "" and int(snap.get("current_actor", -1)) == 0 \
		and not snap.get("available_actions", []).is_empty()

func _run() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var table: PokerTable = TABLE_SCENE.instantiate()
	table.save_path = SAVE_PATH
	table.starting_wallet_balance = 5000
	root.add_child(table)
	await process_frame
	_check(not WebBridge.host_present(), "no browser host when running headless")

	_bridge = WebBridge.new()
	table.add_child(_bridge)
	_bridge.attach(table)
	_bridge.state_sent.connect(_on_sent)

	_check(not _send({type = "bogus"}), "unknown command rejected")
	_check(not _send({type = "action", action = 9}), "out-of-range action rejected")

	_check(_send({type = "buy_in", chips = 1000}), "buy_in accepted")
	_check(_last.get("type", "") == "state", "state message typed")
	_check(_seats().size() == 2, "state carries both seats")
	_check(int(_last.status.get("wallet_balance", -1)) == 4000, "status carries the wallet")
	_check(_last.status.get("rival_kempt") is bool and _last.status.has("rival_timing"),
		"status carries the rival's look as a bool")
	_check(_last.get("phase", "") == "reveal_cards", "opening reveal phase is explicit")
	_check(_seats()[0].get("cards", []).size() == 2, "player's own cards are visible")
	_check(_seats()[1].get("cards", []).is_empty() and int(_seats()[1].get("hidden_cards", 0)) == 2,
		"rival's cards stay hidden")

	var before := _messages_sent
	_check(_send({type = "ready"}), "ready accepted")
	_check(_messages_sent == before + 1, "ready resends the current state")

	_check(await _wait_for(_player_can_act), "player gets a legal decision")
	_check(_send({type = "action", action = PokerBetting.Action.FOLD, amount = 0}), "fold accepted")
	_check(await _wait_for(func(): return _last.get("phase", "") == "hand_over"), "hand reaches hand_over")
	_check(bool(_last.status.get("hand_settled", false)), "status reports settlement")

	_check(_send({type = "next_hand"}), "next_hand accepted")
	_check(int(_last.snapshot.get("hand_number", 0)) == 2, "second hand dealt")
	var settled_or_prompted := func():
		return _last.get("phase", "") == "hand_over" or _player_can_act()
	_check(await _wait_for(settled_or_prompted), "second hand prompts the player or settles")
	if _player_can_act():
		_send({type = "action", action = PokerBetting.Action.FOLD, amount = 0})
	_check(await _wait_for(func(): return _last.get("phase", "") == "hand_over"), "second hand settles")

	_check(_send({type = "leave"}), "leave accepted")
	_check(_last.get("snapshot", {}).is_empty(), "leaving clears the table snapshot")
	_check(not bool(_last.status.get("session_active", true)), "session closed")
	var wallet_after_leave := int(_last.status.wallet_balance)
	_check(_send({type = "save"}), "save accepted")
	_check(FileAccess.file_exists(SAVE_PATH), "save written")
	_check(_send({type = "load"}), "load accepted")
	_check(int(_last.status.wallet_balance) == wallet_after_leave, "load restores the wallet")

	_test_town_commands()

	table.queue_free()
	await process_frame
	await _test_deed_flow()
	await _test_crown_invited_flow()
	await _test_crown_summoned_flow()

	print("PASSES: %d" % _passes)
	print("FAILURES: %d" % _failures)
	await create_timer(0.35).timeout
	quit(1 if _failures > 0 else 0)
