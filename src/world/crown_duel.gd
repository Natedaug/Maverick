class_name CrownDuel extends RefCounted
## Rules for the slice's Crown confrontation: Augustus Crane of the Gilded
## Riverboat (Milestone 4 step 4). Spec: docs/MILESTONE_4_PROPOSALS.md,
## "Step 4 design". Pure rules; PokerTable runs the match and the dialogue.
##
## Campaign.crown_status moves through:
##   "none" -> "invited" (rich enough) -> "won" / "lost" / "declined"
##   "none" / "invited" / "declined" -> "summoned" (The Dealer's marker overdue)
##   "summoned" -> "won" / "lost", or back to "none" if the marker is paid off

const INVITE_NET_WORTH_SILVER := 3000
const DUEL_STACK := 1500
const BLIND_LEVELS := [[25, 50], [50, 100], [100, 200], [200, 400], [400, 800]]
const HANDS_PER_LEVEL := 4

## Gold Crane squares off your marker if you win, by path and stake level.
const WIN_GOLD := {invited = {standard = 100, double = 200}, summoned = {standard = 75, double = 150}}
## Share of your silver and gold he takes if you lose without (or beyond) the deed.
const LOSE_SHARE := 0.4
## Gold added to your marker if you lose a summons.
const SUMMONED_PENALTY_GOLD := {standard = 50, double = 100}

const LEVELS := ["standard", "double"]

## Silver value of everything you hold, gold at today's town rate.
static func net_worth(wallet: Wallet, town: TownState) -> int:
	return wallet.balance + wallet.gold * AssayOffice.rate(town)

## Morning check after sleeping. Returns the new status if the riverboat
## arrives ("invited" / "summoned"), otherwise "".
static func check_arrival(campaign: Campaign, wallet: Wallet, town: TownState) -> String:
	var status := campaign.crown_status
	if campaign.ledger.dealer_overdue(campaign.day) and status in ["none", "invited", "declined"]:
		return "summoned"
	if status == "none" and net_worth(wallet, town) >= INVITE_NET_WORTH_SILVER:
		return "invited"
	return ""

static func is_pending(status: String) -> bool:
	return status == "invited" or status == "summoned"

## The stakes for `path` ("invited"/"summoned") at `level`, as numbers.
static func terms(path: String, level: String, has_deed: bool) -> Dictionary:
	var double := level == "double"
	var share := LOSE_SHARE
	if double and not has_deed:
		share = LOSE_SHARE * 2.0
	return {
		win_gold_off = int(WIN_GOLD[path][level]),
		lose_deed = has_deed,
		lose_share = share if (double or not has_deed) else 0.0,
		penalty_gold = int(SUMMONED_PENALTY_GOLD[level]) if path == "summoned" else 0,
	}

## Small/big blind and level index for the hand about to be dealt (1-based).
static func blinds_for_hand(hand_number: int) -> Array:
	var level := mini((maxi(hand_number, 1) - 1) / HANDS_PER_LEVEL, BLIND_LEVELS.size() - 1)
	return [BLIND_LEVELS[level][0], BLIND_LEVELS[level][1], level]

## Hands left at this blind level after `hand_number` (0 at the top level).
static func hands_to_next_level(hand_number: int) -> int:
	var level := int(blinds_for_hand(hand_number)[2])
	if level >= BLIND_LEVELS.size() - 1:
		return 0
	return (level + 1) * HANDS_PER_LEVEL - maxi(hand_number, 1) + 1

## Apply the match result. Returns plain-language consequence lines.
static func apply_result(won: bool, path: String, level: String, campaign: Campaign,
		wallet: Wallet, town: TownState) -> Array[String]:
	var ledger := campaign.ledger
	var t := terms(path, level, ledger.has_claim_deed)
	var lines: Array[String] = []
	if won:
		var off := mini(int(t.win_gold_off), ledger.dealer_owed_gold)
		ledger.dealer_owed_gold -= off
		var extra := int(t.win_gold_off) - off
		if off > 0:
			lines.append("Crane squares %d gold of your marker with The Dealer. You owe %d." % [off, ledger.dealer_owed_gold])
		if extra > 0:
			wallet.add_gold(extra)
			lines.append("Your marker is clear, so he pays you the other %d gold." % extra)
		_set_town(town, "prosperous")
		lines.append("His grip on the Mayor loosens. Devil's Draw is prospering.")
	else:
		if bool(t.lose_deed):
			ledger.has_claim_deed = false
			lines.append("Crane takes your claim deed.")
		var share := float(t.lose_share)
		if share > 0.0:
			var silver := int(floor(wallet.balance * share))
			var gold := int(floor(wallet.gold * share))
			wallet.balance -= silver
			wallet.gold -= gold
			var taken: Array[String] = []
			if silver > 0:
				taken.append("%d silver" % silver)
			if gold > 0:
				taken.append("%d gold" % gold)
			if not taken.is_empty():
				lines.append("He takes %s." % " and ".join(taken))
		if int(t.penalty_gold) > 0:
			ledger.dealer_owed_gold += int(t.penalty_gold)
			lines.append("He adds %d gold to the marker he bought. You owe %d." % [t.penalty_gold, ledger.dealer_owed_gold])
		_set_town(town, "stressed")
		lines.append("Crane's hold on the Mayor tightens. Devil's Draw is stressed, and gold is dearer.")
	campaign.crown_status = "won" if won else "lost"
	return lines

static func _set_town(town: TownState, state: String) -> void:
	town.state = state
	town.prosperity = 0
