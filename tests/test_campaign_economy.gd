extends SceneTree
## Headless test for the Milestone 4 economy core: silver/gold wallet, the
## floating AssayOffice rate, The Dealer's marker, House Line markers, the
## claim deed, the day clock, and save format V3.
## Run: godot --headless --path . -s tests/test_campaign_economy.gd

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_campaign_economy.gd ===")
	_test_wallet_gold()
	_test_assay_rate_floats_with_town()
	_test_assay_exchange()
	_test_dealer_marker()
	_test_house_line_borrow_and_repay()
	_test_called_marker_seizes_deed_else_bars()
	_test_claim_income_and_sleep()
	_test_save_v3_round_trip()
	_test_older_saves_reset_campaign()
	_test_malformed_economy_rejected()

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

func _town(state: String) -> TownState:
	var t := TownState.new()
	t.state = state
	return t

func _test_wallet_gold() -> void:
	var w := Wallet.new()
	_check(w.gold == 0, "wallet starts with no gold")
	w.add_gold(5)
	_check(w.spend_gold(3) and w.gold == 2, "spend gold")
	_check(not w.spend_gold(3) and w.gold == 2, "cannot overspend gold")
	_check(not w.spend_gold(0) and not w.spend_gold(-1), "invalid gold amounts rejected")
	w.balance = 100
	_check(w.spend_silver(40) and w.balance == 60, "spend silver")
	_check(not w.spend_silver(61), "cannot overspend silver")

func _test_assay_rate_floats_with_town() -> void:
	_check(AssayOffice.rate(_town("neutral")) == 20, "neutral: 20 silver per gold")
	_check(AssayOffice.rate(_town("prosperous")) == 18, "prosperous: gold is cheaper")
	_check(AssayOffice.rate(_town("stressed")) == 24, "stressed: gold is dearer")
	_check(AssayOffice.quote_buy(_town("neutral"), 10) == 210, "buying 10 gold costs 210 with the 5% fee")
	_check(AssayOffice.quote_sell(_town("neutral"), 10) == 190, "selling 10 gold pays 190 after the fee")
	_check(AssayOffice.quote_buy(_town("stressed"), 250) > AssayOffice.quote_buy(_town("neutral"), 250),
		"a stressed town makes The Dealer's debt cost more silver")

func _test_assay_exchange() -> void:
	var w := Wallet.new()
	w.balance = 1000
	var town := _town("neutral")
	_check(AssayOffice.buy_gold(w, town, 10) and w.gold == 10 and w.balance == 790, "buy gold")
	_check(not AssayOffice.buy_gold(w, town, 1000) and w.gold == 10 and w.balance == 790,
		"cannot buy gold without the silver; nothing changes")
	_check(AssayOffice.sell_gold(w, town, 10) and w.gold == 0 and w.balance == 980, "sell gold")
	_check(not AssayOffice.sell_gold(w, town, 1), "cannot sell gold you lack")

func _test_dealer_marker() -> void:
	var ledger := Ledger.new()
	var w := Wallet.new()
	_check(ledger.dealer_owed_gold == 250 and ledger.dealer_due_day == 14, "arrive owing 250 gold, due day 14")
	_check(not ledger.dealer_overdue(14) and ledger.dealer_overdue(15), "overdue only after day 14")
	_check(not ledger.pay_dealer(w, 10), "paying needs gold in hand")
	w.gold = 300
	_check(not ledger.pay_dealer(w, 251), "cannot overpay")
	_check(ledger.pay_dealer(w, 250) and ledger.dealer_owed_gold == 0 and w.gold == 50, "pay in full")
	_check(not ledger.dealer_overdue(30), "a paid marker is never overdue")

func _test_house_line_borrow_and_repay() -> void:
	var ledger := Ledger.new()
	var w := Wallet.new()
	for i in range(3):
		_check(ledger.borrow(w, 2), "marker %d" % (i + 1))
	_check(w.balance == 1500 and not ledger.can_borrow(), "up to three 500-silver markers")
	_check(not ledger.borrow(w, 2) and w.balance == 1500, "a fourth is refused")
	_check(ledger.repay_cost(0, 9) == 600 and ledger.repay_cost(0, 10) == 750, "600 within 7 days, 750 after")
	_check(ledger.repay(w, 0, 9) and w.balance == 900 and ledger.markers.size() == 2, "repay early")
	_check(ledger.repay(w, 0, 12) and w.balance == 150, "repay late")
	_check(not ledger.repay(w, 0, 12) and ledger.markers.size() == 1, "cannot repay without the silver")
	_check(not ledger.repay(w, 5, 12), "bad marker index rejected")

func _test_called_marker_seizes_deed_else_bars() -> void:
	var w := Wallet.new()
	var ledger := Ledger.new()
	ledger.has_claim_deed = true
	ledger.borrow(w, 1)
	var events := ledger.overnight(w, 14)
	_check(not events.has("deed_seized"), "13 days old: not called yet")
	events = ledger.overnight(w, 15)
	_check(events.has("deed_seized") and not ledger.has_claim_deed and ledger.markers.is_empty(),
		"called at 14 days: the House takes the deed and tears up the marker")
	_check(not ledger.barred, "the deed covered it; not barred")

	var broke := Ledger.new()
	broke.borrow(w, 1)
	events = broke.overnight(w, 15)
	_check(events.has("barred") and broke.barred and not broke.can_borrow(), "no deed: barred from the tables")
	events = broke.overnight(w, 16)
	_check(not events.has("barred"), "barred is reported once")
	w.balance = 750
	_check(broke.repay(w, 0, 16) and not broke.barred, "paying the called marker lifts the bar")

func _test_claim_income_and_sleep() -> void:
	var w := Wallet.new()
	var campaign := Campaign.new()
	_check(campaign.day == 1, "the season starts on day 1")
	var events := campaign.sleep(w)
	_check(campaign.day == 2 and events.is_empty() and w.balance == 0, "sleeping advances one day")
	campaign.ledger.has_claim_deed = true
	events = campaign.sleep(w)
	_check(events.has("claim_income") and w.balance == 150, "the claim pays 150 silver a day")
	for i in range(12):
		events = campaign.sleep(w)
	_check(campaign.day == 15 and events.has("dealer_overdue"), "day 15 morning: The Dealer's marker is overdue")
	events = campaign.sleep(w)
	_check(not events.has("dealer_overdue"), "overdue is reported once")

func _save_path(tag: String) -> String:
	return "/tmp/maverick_campaign_%s_%d.txt" % [tag, OS.get_process_id()]

func _test_save_v3_round_trip() -> void:
	var w := Wallet.new()
	w.balance = 640
	w.gold = 12
	var town := TownState.new()
	var rep := TableReputation.new()
	var campaign := Campaign.new()
	campaign.day = 6
	campaign.ledger.dealer_owed_gold = 200
	campaign.ledger.borrow(w, 4)
	campaign.ledger.has_claim_deed = true
	var save := SaveSystem.new()
	var path := _save_path("v3")
	_check(save.save_game(w, town, rep, path, null, campaign), "save V3")
	var w2 := Wallet.new()
	var c2 := Campaign.new()
	_check(save.load_game(w2, TownState.new(), TableReputation.new(), path, null, c2), "load V3")
	_check(w2.balance == 1140 and w2.gold == 12, "silver and gold restored")
	_check(c2.day == 6 and c2.ledger.dealer_owed_gold == 200, "day and Dealer debt restored")
	_check(c2.ledger.markers == [4] and c2.ledger.has_claim_deed, "markers and deed restored")
	DirAccess.remove_absolute(path)

func _test_older_saves_reset_campaign() -> void:
	var path := _save_path("v2")
	var file := FileAccess.open(path, FileAccess.WRITE)
	for line in ["MAVERICK_SAVE_V2", "640", "devils_draw", "1", "7", "neutral", "rusty_spur", "-40", "0"]:
		file.store_line(line)
	file.close()
	var w := Wallet.new()
	w.gold = 9
	var campaign := Campaign.new()
	campaign.day = 9
	_check(SaveSystem.new().load_game(w, TownState.new(), TableReputation.new(), path, null, campaign),
		"a V2 save still loads")
	_check(w.balance == 640 and w.gold == 0, "V2: silver restored, no gold")
	_check(campaign.day == 1 and campaign.ledger.dealer_owed_gold == 250, "V2: the campaign starts fresh")
	DirAccess.remove_absolute(path)

func _test_malformed_economy_rejected() -> void:
	var path := _save_path("bad")
	var file := FileAccess.open(path, FileAccess.WRITE)
	for line in ["MAVERICK_SAVE_V3", "640", "devils_draw", "1", "7", "neutral", "rusty_spur", "-40", "0",
			'{"gold": 5, "campaign": {"day": 0, "ledger": {}}}']:
		file.store_line(line)
	file.close()
	var w := Wallet.new()
	w.balance = 400
	var campaign := Campaign.new()
	campaign.day = 3
	_check(not SaveSystem.new().load_game(w, TownState.new(), TableReputation.new(), path, null, campaign),
		"a bad campaign block is rejected")
	_check(w.balance == 400 and w.gold == 0 and campaign.day == 3, "rejected save changes nothing")
	DirAccess.remove_absolute(path)
