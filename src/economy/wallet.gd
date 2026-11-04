class_name Wallet extends Resource
## Persistent player wallet. Explicit serializable data — not an autoload.
## Services receive the wallet instance they need.
##
## Two currencies (owner decision 2026-11-04): `balance` is silver, the
## everyday money that buys table chips; `gold` pays for deeds, big debts, and
## Crown stakes. Convert between them at the AssayOffice.

## Silver.
var balance: int = 0
var gold: int = 0

## Debit the wallet for a table buy-in. Returns false if amount is invalid or
## insufficient funds. Does not touch poker session stacks.
func buy_in(amount: int) -> bool:
	if amount <= 0:
		return false
	if balance < amount:
		return false
	balance -= amount
	return true

## Credit the wallet with a cash-out amount.
func cash_out(amount: int) -> void:
	if amount > 0:
		balance += amount

func get_balance() -> int:
	return balance

## Spend silver for a world purchase or repayment. False if invalid/short.
func spend_silver(amount: int) -> bool:
	return buy_in(amount)

func add_silver(amount: int) -> void:
	cash_out(amount)

func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false
	gold -= amount
	return true

func add_gold(amount: int) -> void:
	if amount > 0:
		gold += amount
