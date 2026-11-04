class_name AssayOffice extends RefCounted
## Exchanges silver and gold at a rate that floats with the town's state
## (owner decision 2026-11-04, docs/MILESTONE_4_PROPOSALS.md). A stressed town
## makes gold dear; a prosperous one makes it cheap. Each exchange costs a fee.

## Silver per gold, by TownState.state. Starting values for tuning.
const RATES := {neutral = 20, prosperous = 18, stressed = 24}
const FEE := 0.05

## Silver per gold for this town right now.
static func rate(town: TownState) -> int:
	return int(RATES.get(town.state, RATES.neutral))

## Silver it costs to buy `gold` gold, fee included.
static func quote_buy(town: TownState, gold: int) -> int:
	return int(ceil(float(gold * rate(town)) * (1.0 + FEE)))

## Silver received for selling `gold` gold, fee taken.
static func quote_sell(town: TownState, gold: int) -> int:
	return int(floor(float(gold * rate(town)) * (1.0 - FEE)))

static func buy_gold(wallet: Wallet, town: TownState, gold: int) -> bool:
	if gold <= 0 or not wallet.spend_silver(quote_buy(town, gold)):
		return false
	wallet.add_gold(gold)
	return true

static func sell_gold(wallet: Wallet, town: TownState, gold: int) -> bool:
	if not wallet.spend_gold(gold):
		return false
	wallet.add_silver(quote_sell(town, gold))
	return true
