extends SceneTree
## Headless test for the drifter's deed wager (Milestone 4 step 3): the offer
## rule, escrow, all three outcomes, his memory, and the ledger.
## Run: godot --headless --path . -s tests/test_deed_wager.gd

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_deed_wager.gd ===")
	_test_offer_rule()
	_test_player_wins_the_deed()
	_test_rival_defends_the_deed()
	_test_split_returns_both()
	_test_ledger_saves_who_holds_the_claim()

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

func _wallet(silver: int) -> Wallet:
	var w := Wallet.new()
	w.balance = silver
	return w

func _test_offer_rule() -> void:
	var ledger := Ledger.new()
	_check(DeedWager.should_offer(ledger, _wallet(500), 250, 500, false), "offers when he's down to half")
	_check(not DeedWager.should_offer(ledger, _wallet(500), 251, 500, false), "not before he's lost half")
	_check(not DeedWager.should_offer(ledger, _wallet(499), 100, 500, false), "not if you can't cover the stake")
	_check(not DeedWager.should_offer(ledger, _wallet(500), 100, 500, true), "once per sitting")
	ledger.drifter_has_claim = false
	_check(not DeedWager.should_offer(ledger, _wallet(500), 100, 500, false), "not once he's lost the claim")

func _test_player_wins_the_deed() -> void:
	var ledger := Ledger.new()
	var w := _wallet(800)
	var mem := NPCMemory.new()
	_check(DeedWager.accept(w) and w.balance == 300, "accepting escrows 500 silver")
	var outcome := DeedWager.resolve({0: 400}, 0, 1, ledger, w, mem, 7)
	_check(outcome == "player", "winning the pot wins the wager")
	_check(ledger.has_claim_deed and not ledger.drifter_has_claim, "the deed is yours")
	_check(w.balance == 800, "your stake comes back")
	_check(absf(mem.weight + 0.6) < 0.001, "the drifter remembers losing it (weight %f)" % mem.weight)
	mem.finish_hand(7)
	_check(not mem.kempt, "losing the deed tilts him straight to unkempt")

func _test_rival_defends_the_deed() -> void:
	var ledger := Ledger.new()
	var w := _wallet(800)
	var mem := NPCMemory.new()
	DeedWager.accept(w)
	_check(DeedWager.resolve({1: 400}, 0, 1, ledger, w, mem, 7) == "rival", "losing the pot loses the wager")
	_check(w.balance == 300 and not ledger.has_claim_deed and ledger.drifter_has_claim, "he keeps the deed and your silver")
	_check(mem.weight > 0.0, "defending it steadies him")

func _test_split_returns_both() -> void:
	var ledger := Ledger.new()
	var w := _wallet(800)
	DeedWager.accept(w)
	_check(DeedWager.resolve({0: 200, 1: 200}, 0, 1, ledger, w, null, 7) == "split", "a split pot")
	_check(w.balance == 800 and ledger.drifter_has_claim and not ledger.has_claim_deed, "both stakes go back")

func _test_ledger_saves_who_holds_the_claim() -> void:
	var ledger := Ledger.new()
	ledger.drifter_has_claim = false
	var back := Ledger.from_dict(JSON.parse_string(JSON.stringify(ledger.to_dict())))
	_check(back != null and not back.drifter_has_claim and not back.has_claim_deed,
		"seized by the House: nobody at the table holds it after a reload")
	var old := Ledger.from_dict({dealer_owed_gold = 250, dealer_due_day = 14, markers = [], has_claim_deed = true})
	_check(old != null and not old.drifter_has_claim, "older saves: the drifter has it unless you do")
