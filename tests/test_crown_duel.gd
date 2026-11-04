extends SceneTree
## Headless test for the Crown confrontation rules (Milestone 4 step 4):
## when the riverboat docks, the terms, the blind schedule, and every outcome.
## Run: godot --headless --path . -s tests/test_crown_duel.gd

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_crown_duel.gd ===")
	_test_invitation_counts_net_worth()
	_test_summons_when_overdue()
	_test_only_once_per_season()
	_test_terms()
	_test_blind_schedule()
	_test_win_squares_the_marker()
	_test_win_beyond_the_marker_pays_gold()
	_test_lose_takes_the_deed()
	_test_lose_without_deed_takes_a_share()
	_test_lose_double_and_summoned()
	_test_campaign_saves_crown_status()

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

func _town(state: String = "neutral") -> TownState:
	var t := TownState.new()
	t.state = state
	return t

func _wallet(silver: int, gold: int = 0) -> Wallet:
	var w := Wallet.new()
	w.balance = silver
	w.gold = gold
	return w

func _test_invitation_counts_net_worth() -> void:
	var c := Campaign.new()
	_check(CrownDuel.check_arrival(c, _wallet(2999), _town()) == "", "2,999 silver: no invitation")
	_check(CrownDuel.check_arrival(c, _wallet(3000), _town()) == "invited", "3,000 silver: invited")
	_check(CrownDuel.check_arrival(c, _wallet(1000, 100), _town()) == "invited",
		"gold counts at today's rate (1,000 + 100x20)")
	_check(CrownDuel.check_arrival(c, _wallet(1000, 90), _town("prosperous")) == "",
		"a cheaper gold rate lowers net worth (1,000 + 90x18 < 3,000)")

func _test_summons_when_overdue() -> void:
	var c := Campaign.new()
	c.day = 15
	_check(CrownDuel.check_arrival(c, _wallet(0), _town()) == "summoned", "overdue: summoned")
	c.crown_status = "invited"
	_check(CrownDuel.check_arrival(c, _wallet(5000), _town()) == "summoned", "a summons replaces an invitation")
	c.crown_status = "declined"
	_check(CrownDuel.check_arrival(c, _wallet(0), _town()) == "summoned", "declining doesn't escape a summons")
	c.crown_status = "none"
	c.ledger.dealer_owed_gold = 0
	_check(CrownDuel.check_arrival(c, _wallet(0), _town()) == "", "a paid marker brings no summons")

func _test_only_once_per_season() -> void:
	for status in ["won", "lost"]:
		var c := Campaign.new()
		c.crown_status = status
		c.day = 15
		_check(CrownDuel.check_arrival(c, _wallet(9000), _town()) == "", "after a %s match he doesn't return" % status)
	var d := Campaign.new()
	d.crown_status = "declined"
	_check(CrownDuel.check_arrival(d, _wallet(9000), _town()) == "", "declined: no second invitation")

func _test_terms() -> void:
	var t := CrownDuel.terms("invited", "standard", true)
	_check(t.win_gold_off == 100 and t.lose_deed and t.lose_share == 0.0 and t.penalty_gold == 0,
		"invited standard with deed: win 100 off, lose the deed only")
	t = CrownDuel.terms("invited", "standard", false)
	_check(not t.lose_deed and absf(t.lose_share - 0.4) < 0.001, "no deed: lose 40%")
	t = CrownDuel.terms("invited", "double", true)
	_check(t.win_gold_off == 200 and t.lose_deed and absf(t.lose_share - 0.4) < 0.001, "double with deed: deed and 40%")
	t = CrownDuel.terms("invited", "double", false)
	_check(absf(t.lose_share - 0.8) < 0.001, "double without deed: 80%")
	t = CrownDuel.terms("summoned", "standard", false)
	_check(t.win_gold_off == 75 and t.penalty_gold == 50, "summoned: worse terms (75 off, +50 if you lose)")
	_check(CrownDuel.terms("summoned", "double", false).penalty_gold == 100, "summoned double: +100")

func _test_blind_schedule() -> void:
	_check(CrownDuel.blinds_for_hand(1) == [25, 50, 0] and CrownDuel.blinds_for_hand(4) == [25, 50, 0], "hands 1-4: 25/50")
	_check(CrownDuel.blinds_for_hand(5) == [50, 100, 1], "hand 5: 50/100")
	_check(CrownDuel.blinds_for_hand(17) == [400, 800, 4] and CrownDuel.blinds_for_hand(99) == [400, 800, 4],
		"top level holds")
	_check(CrownDuel.hands_to_next_level(1) == 4 and CrownDuel.hands_to_next_level(4) == 1,
		"hands left at this level")
	_check(CrownDuel.hands_to_next_level(17) == 0, "no next level at the top")

func _test_win_squares_the_marker() -> void:
	var c := Campaign.new()
	var w := _wallet(500)
	var town := _town("stressed")
	var lines := CrownDuel.apply_result(true, "invited", "standard", c, w, town)
	_check(c.ledger.dealer_owed_gold == 150 and c.crown_status == "won", "win: 100 gold off the marker")
	_check(town.state == "prosperous" and w.balance == 500, "the town prospers; your silver is untouched")
	_check(lines.size() >= 2, "the result is explained (%d lines)" % lines.size())

func _test_win_beyond_the_marker_pays_gold() -> void:
	var c := Campaign.new()
	c.ledger.dealer_owed_gold = 60
	var w := _wallet(0)
	CrownDuel.apply_result(true, "invited", "double", c, w, _town())
	_check(c.ledger.dealer_owed_gold == 0 and w.gold == 140, "200 gold: 60 clears the marker, 140 to you")

func _test_lose_takes_the_deed() -> void:
	var c := Campaign.new()
	c.ledger.has_claim_deed = true
	c.ledger.drifter_has_claim = false
	var w := _wallet(1000, 10)
	var town := _town()
	CrownDuel.apply_result(false, "invited", "standard", c, w, town)
	_check(not c.ledger.has_claim_deed and w.balance == 1000 and w.gold == 10, "standard loss with a deed: only the deed")
	_check(town.state == "stressed" and c.crown_status == "lost", "the town is stressed")
	_check(not c.ledger.drifter_has_claim, "the deed is Crane's now, not the drifter's")

func _test_lose_without_deed_takes_a_share() -> void:
	var c := Campaign.new()
	var w := _wallet(1000, 10)
	CrownDuel.apply_result(false, "invited", "standard", c, w, _town())
	_check(w.balance == 600 and w.gold == 6, "40% of silver and gold")
	_check(c.ledger.dealer_owed_gold == 250, "an invited loss doesn't touch the marker")

func _test_lose_double_and_summoned() -> void:
	var c := Campaign.new()
	c.ledger.has_claim_deed = true
	var w := _wallet(1000)
	CrownDuel.apply_result(false, "summoned", "double", c, w, _town())
	_check(not c.ledger.has_claim_deed and w.balance == 600, "double: the deed and 40%")
	_check(c.ledger.dealer_owed_gold == 350, "summoned double: +100 gold on the marker")
	var d := Campaign.new()
	var w2 := _wallet(1000)
	CrownDuel.apply_result(false, "invited", "double", d, w2, _town())
	_check(w2.balance == 200, "double without a deed: 80%")
	var e := Campaign.new()
	var lines := CrownDuel.apply_result(false, "invited", "standard", e, _wallet(1000), _town())
	_check(not str(lines).contains(" 0 gold"), "a zero amount isn't listed (%s)" % lines[0])

func _test_campaign_saves_crown_status() -> void:
	var c := Campaign.new()
	c.crown_status = "summoned"
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	_check(back != null and back.crown_status == "summoned", "crown status survives a save")
	var legacy := Campaign.from_dict({day = 3, ledger = Ledger.new().to_dict()})
	_check(legacy != null and legacy.crown_status == "none", "older saves start with no Crown business")
	_check(Campaign.from_dict({day = 3, ledger = Ledger.new().to_dict(), crown_status = "bogus"}) == null,
		"an unknown status is rejected")
