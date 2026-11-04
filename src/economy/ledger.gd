class_name Ledger extends Resource
## The player's debts and holdings for the Milestone 4 slice (owner decisions
## 2026-11-04, docs/MILESTONE_4_PROPOSALS.md). Explicit serializable data.
##
## - The Dealer's marker: owed in gold, due on a day. No interest; missing the
##   deadline only marks it overdue (the Crown confrontation reacts to that).
## - The House Line: the Rusty Spur lends silver in fixed markers. Repaying
##   costs more after a week; a marker unpaid for two weeks is called.
## - Holdings: the drifter's claim deed, which pays silver each day.
##
## Ordinary poker losses never touch this ledger (compass money boundary).

const DEALER_START_GOLD := 250
const DEALER_DUE_DAY := 14

## House Line terms (owner approved 2026-11-04; starting values for tuning).
const MARKER_SILVER := 500
const MAX_MARKERS := 3
const REPAY_EARLY_SILVER := 600
const REPAY_LATE_SILVER := 750
const EARLY_DAYS := 7
const CALLED_AT_DAYS := 14

const CLAIM_INCOME_SILVER := 150
const CLAIM_VALUE_GOLD := 100

var dealer_owed_gold: int = DEALER_START_GOLD
var dealer_due_day: int = DEALER_DUE_DAY
## Open House Line markers: the day each was taken.
var markers: Array[int] = []
## Set when a called marker could not be covered by seizing the deed.
var barred: bool = false
var has_claim_deed: bool = false

func dealer_overdue(day: int) -> bool:
	return dealer_owed_gold > 0 and day > dealer_due_day

## Pay The Dealer in gold (convert at the AssayOffice first).
func pay_dealer(wallet: Wallet, gold: int) -> bool:
	if gold <= 0 or gold > dealer_owed_gold or not wallet.spend_gold(gold):
		return false
	dealer_owed_gold -= gold
	return true

func can_borrow() -> bool:
	return not barred and markers.size() < MAX_MARKERS

## Take one House Line marker on `day`.
func borrow(wallet: Wallet, day: int) -> bool:
	if not can_borrow():
		return false
	markers.append(day)
	wallet.add_silver(MARKER_SILVER)
	return true

## Silver needed to repay marker `index` on `day`.
func repay_cost(index: int, day: int) -> int:
	return REPAY_EARLY_SILVER if day - markers[index] <= EARLY_DAYS else REPAY_LATE_SILVER

func repay(wallet: Wallet, index: int, day: int) -> bool:
	if index < 0 or index >= markers.size() or not wallet.spend_silver(repay_cost(index, day)):
		return false
	markers.remove_at(index)
	if barred and _called_markers(day).is_empty():
		barred = false
	return true

## Run the overnight rules for the morning of `new_day`. Returns event ids:
## "claim_income", "deed_seized", "barred", "dealer_overdue".
func overnight(wallet: Wallet, new_day: int) -> Array[String]:
	var events: Array[String] = []
	if has_claim_deed:
		wallet.add_silver(CLAIM_INCOME_SILVER)
		events.append("claim_income")
	for index in _called_markers(new_day):
		if has_claim_deed:
			# The House takes the deed and tears up the marker it covered.
			has_claim_deed = false
			markers.remove_at(index)
			events.append("deed_seized")
		elif not barred:
			barred = true
			events.append("barred")
	if dealer_overdue(new_day) and not dealer_overdue(new_day - 1):
		events.append("dealer_overdue")
	return events

## Indices of called markers, newest first (safe to remove in order).
func _called_markers(day: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(markers.size() - 1, -1, -1):
		if day - markers[i] >= CALLED_AT_DAYS:
			out.append(i)
	return out

func to_dict() -> Dictionary:
	return {
		dealer_owed_gold = dealer_owed_gold,
		dealer_due_day = dealer_due_day,
		markers = markers.duplicate(),
		barred = barred,
		has_claim_deed = has_claim_deed,
	}

## Null when `data` is malformed.
static func from_dict(data: Dictionary) -> Ledger:
	var ledger := Ledger.new()
	var owed: Variant = data.get("dealer_owed_gold", null)
	var due: Variant = data.get("dealer_due_day", null)
	var raw_markers: Variant = data.get("markers", [])
	if typeof(owed) not in [TYPE_INT, TYPE_FLOAT] or typeof(due) not in [TYPE_INT, TYPE_FLOAT] \
			or typeof(raw_markers) != TYPE_ARRAY or int(owed) < 0:
		return null
	ledger.dealer_owed_gold = int(owed)
	ledger.dealer_due_day = int(due)
	for day in raw_markers:
		if typeof(day) not in [TYPE_INT, TYPE_FLOAT]:
			return null
		ledger.markers.append(int(day))
	ledger.barred = bool(data.get("barred", false))
	ledger.has_claim_deed = bool(data.get("has_claim_deed", false))
	return ledger
