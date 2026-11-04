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
	_check(_send({type = "save"}) and _send({type = "sleep"}) and _send({type = "load"}), "save, sleep, load")
	_check(int(_eco().day) == 16, "load restores the day")

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

	print("PASSES: %d" % _passes)
	print("FAILURES: %d" % _failures)
	await create_timer(0.35).timeout
	table.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)
