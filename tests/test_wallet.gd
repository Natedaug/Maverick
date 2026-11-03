extends SceneTree
## Headless test for Wallet.
## Run: godot --headless --script tests/test_wallet.gd

const Wallet = preload("res://src/economy/wallet.gd")

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== test_wallet.gd ===")
	_test_initial_balance()
	_test_buy_in_success()
	_test_buy_in_insufficient_funds()
	_test_buy_in_invalid_amount()
	_test_cash_out()
	_test_get_balance()

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

func _test_initial_balance() -> void:
	var w: Wallet = Wallet.new()
	_check(w.get_balance() == 0, "new wallet starts at 0 (got %d)" % w.get_balance())

func _test_buy_in_success() -> void:
	var w: Wallet = Wallet.new()
	w.balance = 500
	var ok := w.buy_in(200)
	_check(ok, "buy_in returns true")
	_check(w.get_balance() == 300, "balance after buy_in (got %d)" % w.get_balance())

func _test_buy_in_insufficient_funds() -> void:
	var w: Wallet = Wallet.new()
	w.balance = 100
	var ok := w.buy_in(200)
	_check(not ok, "buy_in returns false when insufficient")
	_check(w.get_balance() == 100, "balance unchanged (got %d)" % w.get_balance())

func _test_buy_in_invalid_amount() -> void:
	var w: Wallet = Wallet.new()
	w.balance = 500
	_check(not w.buy_in(0), "buy_in rejects zero")
	_check(not w.buy_in(-50), "buy_in rejects negative")
	_check(w.get_balance() == 500, "balance unchanged (got %d)" % w.get_balance())

func _test_cash_out() -> void:
	var w: Wallet = Wallet.new()
	w.balance = 100
	w.cash_out(250)
	_check(w.get_balance() == 350, "balance after cash_out (got %d)" % w.get_balance())

func _test_get_balance() -> void:
	var w: Wallet = Wallet.new()
	w.balance = 42
	_check(w.get_balance() == 42, "get_balance returns balance (got %d)" % w.get_balance())
