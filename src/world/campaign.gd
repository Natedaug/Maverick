class_name Campaign extends RefCounted
## The slice's clock and the player's affairs: the day, debts, and holdings.
## A day passes only when the player sleeps (owner decision 2026-11-04).

const SEASON_DAYS := 14

var day: int = 1
var ledger := Ledger.new()
## The Crown confrontation's progress; see CrownDuel for the transitions.
var crown_status: String = "none"

const CROWN_STATUSES := ["none", "invited", "summoned", "won", "lost", "declined"]
## The journal keeps this many entries (oldest dropped first).
const JOURNAL_LIMIT := 60

## False until the player has read the arrival for this season.
var intro_seen: bool = false
## The story so far, oldest first: {day: int, text: String}. Only the moments
## that matter (debts, the deed, the drifter, the town, Crane), not every hand.
var journal: Array[Dictionary] = []

func note(text: String) -> void:
	journal.append({day = day, text = text})
	while journal.size() > JOURNAL_LIMIT:
		journal.pop_front()

## Sleep through the night. Returns the ledger's overnight event ids.
func sleep(wallet: Wallet) -> Array[String]:
	day += 1
	return ledger.overnight(wallet, day)

func to_dict() -> Dictionary:
	return {day = day, ledger = ledger.to_dict(), crown_status = crown_status,
		intro_seen = intro_seen, journal = journal.duplicate(true)}

## Null when `data` is malformed.
static func from_dict(data: Dictionary) -> Campaign:
	var raw_day: Variant = data.get("day", null)
	var raw_ledger: Variant = data.get("ledger", null)
	if typeof(raw_day) not in [TYPE_INT, TYPE_FLOAT] or int(raw_day) < 1 \
			or typeof(raw_ledger) != TYPE_DICTIONARY:
		return null
	var ledger := Ledger.from_dict(raw_ledger)
	if ledger == null:
		return null
	var crown := str(data.get("crown_status", "none"))
	if not crown in CROWN_STATUSES:
		return null
	var campaign := Campaign.new()
	campaign.day = int(raw_day)
	campaign.ledger = ledger
	campaign.crown_status = crown
	# Saves from before the arrival existed have already started their season.
	campaign.intro_seen = bool(data.get("intro_seen", true))
	var raw_journal: Variant = data.get("journal", [])
	if typeof(raw_journal) != TYPE_ARRAY:
		return null
	for entry in raw_journal:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("text", null)) != TYPE_STRING:
			return null
		campaign.journal.append({day = int(entry.get("day", 1)), text = str(entry.text)})
	return campaign
