class_name SaveSystem extends RefCounted
## Persists wallet, town state, table reputation, rival memory, and the
## campaign (day, debts, holdings) to a plain-text save file. Explicit
## serialization — no autoloads involved.
##
## V3 layout: the eight V1 lines (one per field; line 2 is silver), a memory
## count line, one JSON line per NPCMemory (NPCMemory.to_dict()), then one
## JSON line {"gold": int, "campaign": Campaign.to_dict()}.
## V2 and V1 saves still load: they carry no gold, and a given campaign is
## reset to a fresh start. V1 also carries no rival memory.

const SAVE_HEADER := "MAVERICK_SAVE_V3"
const LEGACY_HEADER_V2 := "MAVERICK_SAVE_V2"
const LEGACY_HEADER_V1 := "MAVERICK_SAVE_V1"

## Save all data objects to `path`. `rival_memory` is optional. Returns false
## if the file cannot be opened for writing.
func save_game(wallet, town_state, reputation, path: String, rival_memory: RivalMemory = null,
		campaign: Campaign = null) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_line(SAVE_HEADER)
	file.store_line(str(wallet.balance))
	file.store_line(town_state.town_id)
	file.store_line(str(town_state.prosperity))
	file.store_line(str(town_state.poker_volume))
	file.store_line(town_state.state)
	file.store_line(reputation.table_id)
	file.store_line(str(reputation.lifetime_net))
	var entries: Array = []
	if rival_memory != null:
		for key in rival_memory.memories.keys():
			entries.append(rival_memory.memories[key].to_dict())
	file.store_line(str(entries.size()))
	for entry in entries:
		file.store_line(JSON.stringify(entry))
	var economy := {gold = wallet.gold}
	if campaign != null:
		economy["campaign"] = campaign.to_dict()
	file.store_line(JSON.stringify(economy))
	file.close()
	return true

## Load all data objects from `path`. Returns false if the file cannot be
## read or is malformed; nothing is mutated unless the whole file is valid.
## When `rival_memory` is given, its entries are replaced by the saved ones.
func load_game(wallet, town_state, reputation, path: String, rival_memory: RivalMemory = null,
		campaign: Campaign = null) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var lines: Array[String] = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	if lines.size() < 8 or not [SAVE_HEADER, LEGACY_HEADER_V2, LEGACY_HEADER_V1].has(lines[0]):
		return false
	if not lines[1].is_valid_int() or not lines[3].is_valid_int() \
			or not lines[4].is_valid_int() or not lines[7].is_valid_int():
		return false
	var loaded_balance := lines[1].to_int()
	var loaded_prosperity := lines[3].to_int()
	var loaded_volume := lines[4].to_int()
	var loaded_net := lines[7].to_int()
	var loaded_state := lines[5]
	if loaded_balance < 0 or loaded_volume < 0 \
			or loaded_prosperity < -2 or loaded_prosperity > 2 \
			or not ["neutral", "prosperous", "stressed"].has(loaded_state):
		return false

	var loaded_memories: Array[NPCMemory] = []
	var loaded_gold := 0
	var loaded_campaign: Campaign = null
	if lines[0] != LEGACY_HEADER_V1:
		if lines.size() < 9 or not lines[8].is_valid_int():
			return false
		var count := lines[8].to_int()
		if count < 0 or lines.size() < 9 + count:
			return false
		for i in range(count):
			var parsed: Variant = JSON.parse_string(lines[9 + i])
			if typeof(parsed) != TYPE_DICTIONARY or str(parsed.get("opponent_id", "")) == "":
				return false
			loaded_memories.append(NPCMemory.from_dict(parsed))
		if lines[0] == SAVE_HEADER:
			if lines.size() < 10 + count:
				return false
			var economy: Variant = JSON.parse_string(lines[9 + count])
			if typeof(economy) != TYPE_DICTIONARY:
				return false
			var gold: Variant = economy.get("gold", null)
			if typeof(gold) not in [TYPE_INT, TYPE_FLOAT] or int(gold) < 0:
				return false
			loaded_gold = int(gold)
			if economy.has("campaign"):
				if typeof(economy.campaign) != TYPE_DICTIONARY:
					return false
				loaded_campaign = Campaign.from_dict(economy.campaign)
				if loaded_campaign == null:
					return false

	wallet.balance = loaded_balance
	wallet.gold = loaded_gold
	if campaign != null:
		var source := loaded_campaign if loaded_campaign != null else Campaign.new()
		campaign.day = source.day
		campaign.ledger = source.ledger
		campaign.crown_status = source.crown_status
		campaign.intro_seen = source.intro_seen
		campaign.journal = source.journal
	town_state.town_id = lines[2]
	town_state.prosperity = loaded_prosperity
	town_state.poker_volume = loaded_volume
	town_state.state = loaded_state
	reputation.table_id = lines[6]
	reputation.lifetime_net = loaded_net
	if rival_memory != null:
		rival_memory.clear()
		for mem in loaded_memories:
			rival_memory.memories[mem.opponent_id] = mem
	return true
