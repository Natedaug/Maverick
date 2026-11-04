extends SceneTree
## Headless test for SaveSystem.
## Run: godot --headless --script tests/test_save_system.gd

const Wallet = preload("res://src/economy/wallet.gd")
const TownState = preload("res://src/world/town_state.gd")
const TableReputation = preload("res://src/world/table_reputation.gd")
const SaveSystem = preload("res://src/save/save_system.gd")

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_save_system.gd ===")
	_test_save_and_load()
	_test_load_missing_file_returns_false()
	_test_malformed_save_does_not_mutate_state()
	_test_rival_memory_round_trip()
	_test_legacy_v1_save_loads_without_memory()
	_test_malformed_memory_block_does_not_mutate_state()

	print("")
	print("PASSES: %d" % _passes)
	print("FAILURES: %d" % _failures)
	if _failures > 0:
		print("❌ TESTS FAILED")
		quit(1)
	else:
		print("✅ ALL TESTS PASSED")
		quit(0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + msg)

func _test_save_and_load() -> void:
	var wallet: Wallet = Wallet.new()
	wallet.balance = 750
	var town: TownState = TownState.new()
	town.town_id = "rusty_spur"
	town.apply_hand_result(10)
	town.apply_hand_result(10)
	town.apply_hand_result(10)  # prosperity: 1->2->3->transition to prosperous, reset to 0
	var rep: TableReputation = TableReputation.new()
	rep.table_id = "rusty_spur"
	rep.apply_hand_result(200)

	var save: SaveSystem = SaveSystem.new()
	var path := "/tmp/maverick_economy_save_test_%d.txt" % OS.get_process_id()
	var ok := save.save_game(wallet, town, rep, path)
	_check(ok, "save succeeds")

	# Mutate objects to verify load restores
	wallet.balance = 0
	town.prosperity = 99
	town.state = "collapsing"
	town.poker_volume = 0
	rep.lifetime_net = -999

	var loaded := save.load_game(wallet, town, rep, path)
	_check(loaded, "load succeeds")
	_check(wallet.get_balance() == 750, "wallet balance restored (got %d)" % wallet.get_balance())
	_check(town.prosperity == 0, "town prosperity restored (got %d)" % town.prosperity)
	_check(town.state == "prosperous", "town state restored (got %s)" % town.state)
	_check(town.poker_volume == 3, "town poker_volume restored (got %d)" % town.poker_volume)
	_check(rep.lifetime_net == 200, "rep lifetime_net restored (got %d)" % rep.lifetime_net)
	_check(rep.get_label() == "known winner", "rep label restored (got %s)" % rep.get_label())

func _test_load_missing_file_returns_false() -> void:
	var wallet: Wallet = Wallet.new()
	var town: TownState = TownState.new()
	var rep: TableReputation = TableReputation.new()
	var save: SaveSystem = SaveSystem.new()
	var missing_path := "/tmp/maverick_missing_save_test_%d.txt" % OS.get_process_id()
	if FileAccess.file_exists(missing_path):
		DirAccess.remove_absolute(missing_path)
	var ok := save.load_game(wallet, town, rep, missing_path)
	_check(not ok, "load returns false for missing file")

func _test_malformed_save_does_not_mutate_state() -> void:
	var path := "/tmp/maverick_malformed_save_test_%d.txt" % OS.get_process_id()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line("MAVERICK_SAVE_V1")
	file.store_line("not-a-balance")
	file.store_line("rusty_spur")
	file.store_line("0")
	file.store_line("0")
	file.store_line("neutral")
	file.store_line("rusty_spur")
	file.store_line("0")
	file.close()
	var wallet: Wallet = Wallet.new()
	wallet.balance = 400
	var town: TownState = TownState.new()
	town.town_id = "existing_town"
	var rep: TableReputation = TableReputation.new()
	rep.lifetime_net = 25
	var save: SaveSystem = SaveSystem.new()
	_check(not save.load_game(wallet, town, rep, path), "malformed save is rejected")
	_check(wallet.balance == 400, "failed load leaves wallet untouched")
	_check(town.town_id == "existing_town", "failed load leaves town untouched")
	_check(rep.lifetime_net == 25, "failed load leaves reputation untouched")

func _test_rival_memory_round_trip() -> void:
	var wallet: Wallet = Wallet.new()
	wallet.balance = 900
	var town: TownState = TownState.new()
	var rep: TableReputation = TableReputation.new()
	var rival := RivalMemory.new()
	var mem := rival.get_memory("0")
	mem.record_event("suck_out_suffered", 4)
	mem.record_event("stone_cold_caught", 4)
	mem.finish_hand(4)
	var save: SaveSystem = SaveSystem.new()
	var path := "/tmp/maverick_memory_save_test_%d.txt" % OS.get_process_id()
	_check(save.save_game(wallet, town, rep, path, rival), "save with rival memory succeeds")

	var restored := RivalMemory.new()
	restored.get_memory("stale").weight = 3.0
	_check(save.load_game(wallet, town, rep, path, restored), "load with rival memory succeeds")
	_check(not restored.memories.has("stale"), "load replaces existing memories")
	var back := restored.get_memory("0")
	_check(absf(back.weight - mem.weight) < 0.0001, "memory weight restored (got %f)" % back.weight)
	_check(back.suck_outs_suffered == 1 and back.hands_seen == 1 and back.last_seen_hand == 4,
		"memory counters restored")
	_check(not mem.kempt and not back.kempt, "unkempt look restored")

func _test_legacy_v1_save_loads_without_memory() -> void:
	var path := "/tmp/maverick_v1_save_test_%d.txt" % OS.get_process_id()
	var file := FileAccess.open(path, FileAccess.WRITE)
	for line in ["MAVERICK_SAVE_V1", "640", "devils_draw", "1", "7", "neutral", "rusty_spur", "-40"]:
		file.store_line(line)
	file.close()
	var wallet: Wallet = Wallet.new()
	var town: TownState = TownState.new()
	var rep: TableReputation = TableReputation.new()
	var rival := RivalMemory.new()
	rival.get_memory("0").weight = 1.0
	var save: SaveSystem = SaveSystem.new()
	_check(save.load_game(wallet, town, rep, path, rival), "existing V1 save still loads")
	_check(wallet.balance == 640 and rep.lifetime_net == -40, "V1 world state restored")
	_check(rival.memories.is_empty(), "V1 save starts the rival with no memory")

func _test_malformed_memory_block_does_not_mutate_state() -> void:
	var path := "/tmp/maverick_bad_memory_save_test_%d.txt" % OS.get_process_id()
	var file := FileAccess.open(path, FileAccess.WRITE)
	for line in ["MAVERICK_SAVE_V2", "640", "devils_draw", "1", "7", "neutral", "rusty_spur", "-40", "2", "{not json"]:
		file.store_line(line)
	file.close()
	var wallet: Wallet = Wallet.new()
	wallet.balance = 400
	var town: TownState = TownState.new()
	var rep: TableReputation = TableReputation.new()
	var rival := RivalMemory.new()
	rival.get_memory("0").weight = 1.0
	var save: SaveSystem = SaveSystem.new()
	_check(not save.load_game(wallet, town, rep, path, rival), "bad memory block is rejected")
	_check(wallet.balance == 400, "rejected memory block leaves wallet untouched")
	_check(rival.get_memory("0").weight == 1.0, "rejected memory block leaves memory untouched")
