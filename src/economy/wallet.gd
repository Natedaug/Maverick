class_name Wallet extends Resource
## Persistent player wallet. Explicit serializable data — not an autoload.
## Services receive the wallet instance they need.

var balance: int = 0

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
