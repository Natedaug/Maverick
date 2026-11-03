class_name SaveSystem extends RefCounted
## Persists wallet, town state, and table reputation to a plain-text save file.
## Explicit serialization — no autoloads involved. One line per field.

## Save all three data objects to `path`. Returns false if the file cannot be
## opened for writing.
func save_game(wallet, town_state, reputation, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
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
	if lines.size() < 7:
		return false

	wallet.balance = lines[0].to_int()
	town_state.town_id = lines[1]
	town_state.prosperity = lines[2].to_int()
	town_state.poker_volume = lines[3].to_int()
	town_state.state = lines[4]
	reputation.table_id = lines[5]
	reputation.lifetime_net = lines[6].to_int()
	return true
