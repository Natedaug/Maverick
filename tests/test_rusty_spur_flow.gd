extends SceneTree
## End-to-end controller check for buy-in, settlement, cash-out, and resume.
## Run: godot --headless --path . --script tests/test_rusty_spur_flow.gd

const TABLE_SCENE := preload("res://scenes/poker/poker_table.tscn")

var _failures := 0
var _passes := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + message)

## The table paces reveals with timers; wait for a state instead of assuming
## synchronous play. Returns false if `condition` never held.
func _wait_for(condition: Callable, timeout_seconds: float = 15.0) -> bool:
	var waited := 0.0
	while not condition.call():
		if waited >= timeout_seconds:
			return false
		await create_timer(0.05).timeout
		waited += 0.05
	return true

func _settled_and_revealed(table: Node) -> bool:
	return bool(table.get("_hand_settled")) and not bool(table.get("_settlement_reveal_pending"))

func _run() -> void:
	var temp_save_path := "/tmp/maverick_test_rusty_spur_flow.txt"
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
	var table := TABLE_SCENE.instantiate()
	table.set("starting_wallet_balance", 5000)
	table.set("default_buy_in_chips", 1000)
	table.set("save_path", temp_save_path)
	root.add_child(table)
	await process_frame
	var ui: Node = table.get_node("PokerTableUI")
	var wallet: Wallet = table.get("_wallet")
	_check(wallet.balance == 5000, "new game initializes wallet")
	ui.emit_signal("buy_in_requested", 1000)
	_check(wallet.balance == 4000, "buy-in debits wallet once")
	_check(table.get("_session") != null, "buy-in creates a PokerSession")
	_check(table.get("_session").current_actor() == 0, "player acts first in opening hand")
	_check(await _wait_for(func(): return not bool(table.get("_opening_reveal_pending"))),
		"opening card reveal finishes")

	ui.emit_signal("player_action_requested", PokerBetting.Action.FOLD, 0)
	_check(await _wait_for(func(): return _settled_and_revealed(table)), "first hand settles")
	var town: TownState = table.get("_town_state")
	var reputation: TableReputation = table.get("_table_reputation")
	_check(town.poker_volume == 1, "settled hand increments Rusty Spur volume")
	_check(town.prosperity == -1, "small-blind fold applies net loss to prosperity")
	_check(reputation.lifetime_net == -10, "settlement updates lifetime table net")
	_check(reputation.get_label() == "known loser", "reputation label reflects net")
	var first_hand_stacks: Array[int] = table.get("_session").stacks()
	_check(first_hand_stacks[0] == 990, "player stack remains in the session after hand one")

	ui.emit_signal("next_hand_requested")
	var active_session: PokerSession = table.get("_session")
	_check(active_session.hand_number == 2, "next hand continues the same PokerSession")
	var in_play_stacks: Array[int] = active_session.stacks()
	var in_play_total := in_play_stacks[0] + in_play_stacks[1] + active_session.total_pot()
	_check(in_play_total == 2000, "session preserves all chips while the next hand is active")
	# The rival may act first; fold whenever the player is prompted.
	var player_prompted_or_settled := func():
		return bool(table.get("_hand_settled")) or (active_session.current_actor() == 0 \
			and not bool(table.get("_continuation_running")) \
			and not bool(table.get("_opening_reveal_pending")))
	_check(await _wait_for(player_prompted_or_settled), "second hand reaches a player decision or settles")
	if not bool(table.get("_hand_settled")):
		ui.emit_signal("player_action_requested", PokerBetting.Action.FOLD, 0)
	_check(await _wait_for(func(): return _settled_and_revealed(table)),
		"second hand settles through the controller")
	_check(town.poker_volume == 2, "second settled hand increments town volume once")

	ui.emit_signal("leave_table_requested")
	var ending_stack: Array[int] = active_session.stacks()
	_check(wallet.balance == 4000 + ending_stack[0], "leaving cashes remaining stack out once")
	_check(table.get("_session") == null, "leaving closes the table session")
	var wallet_after_leave := wallet.balance
	var reputation_before_save := reputation.lifetime_net
	ui.emit_signal("leave_table_requested")
	_check(wallet.balance == wallet_after_leave, "repeated leave cannot double-credit cash-out")
	var reputation_label_before_save := reputation.get_label()
	var rival: RivalMemory = table.get("_rival_memory")
	var rival_mem := rival.get_memory("0")
	_check(rival_mem.hands_seen == 2, "rival remembers both hands (got %d)" % rival_mem.hands_seen)
	rival_mem.record_event("suck_out_suffered", 99)
	var rival_weight_before_save := rival_mem.weight
	ui.emit_signal("save_requested")
	_check(FileAccess.file_exists(temp_save_path), "save action writes a file")

	wallet.balance = 1
	town.poker_volume = 0
	town.prosperity = 0
	town.state = "neutral"
	reputation.lifetime_net = 0
	ui.emit_signal("load_requested")
	_check(wallet.balance == wallet_after_leave, "load restores wallet")
	_check(town.poker_volume == 2, "load restores town volume")
	_check(reputation.lifetime_net == reputation_before_save, "load restores cumulative table reputation")
	_check(reputation.get_label() == reputation_label_before_save, "loaded reputation label matches saved net")
	var loaded_mem: NPCMemory = table.get("_rival_memory").get_memory("0")
	_check(absf(loaded_mem.weight - rival_weight_before_save) < 0.0001, "load restores rival memory weight")
	_check(loaded_mem.hands_seen == 2, "load restores rival hand count")

	print("PASSES: %d" % _passes)
	print("FAILURES: %d" % _failures)
	await create_timer(0.35).timeout
	table.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)
