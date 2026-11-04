class_name Campaign extends RefCounted
## The slice's clock and the player's affairs: the day, debts, and holdings.
## A day passes only when the player sleeps (owner decision 2026-11-04).

const SEASON_DAYS := 14

var day: int = 1
var ledger := Ledger.new()

## Sleep through the night. Returns the ledger's overnight event ids.
func sleep(wallet: Wallet) -> Array[String]:
	day += 1
	return ledger.overnight(wallet, day)

func to_dict() -> Dictionary:
	return {day = day, ledger = ledger.to_dict()}

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
	var campaign := Campaign.new()
	campaign.day = int(raw_day)
	campaign.ledger = ledger
	return campaign
