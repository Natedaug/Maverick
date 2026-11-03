class_name SaveSystem extends RefCounted
## Persists wallet, town state, and table reputation to a plain-text save file.
## Explicit serialization — no autoloads involved. Versioned, one line per field.

const SAVE_HEADER := "MAVERICK_SAVE_V1"

## Save all three data objects to `path`. Returns false if the file cannot be
## opened for writing.
func save_game(wallet, town_state, reputation, path: String) -> bool:
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
	file.close()
	return true

## Load all three data objects from `path`. Returns false if the file cannot be
## opened for reading or is malformed. Objects are mutated in place.
func load_game(wallet, town_state, reputation, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var lines: Array[String] = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	if lines.size() < 8 or lines[0] != SAVE_HEADER:
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

	wallet.balance = loaded_balance
	town_state.town_id = lines[2]
	town_state.prosperity = loaded_prosperity
	town_state.poker_volume = loaded_volume
	town_state.state = loaded_state
	reputation.table_id = lines[6]
	reputation.lifetime_net = loaded_net
	return true
