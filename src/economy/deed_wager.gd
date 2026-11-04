class_name DeedWager extends RefCounted
## The drifter stakes his silver-claim deed (Milestone 4 step 3; owner-approved
## property, docs/MILESTONE_4_PROPOSALS.md §4). When he has lost half his
## chips, he offers the deed against the player's silver as a side stake on
## the next hand. The pot's winner takes the side stakes; a split returns them.
## Pure rules here; PokerTable runs the flow.

## Silver the player puts against the deed (about half its value: he's desperate).
const STAKE_SILVER := 500
## He offers once his stack is at or below this share of his buy-in.
const OFFER_STACK_SHARE := 0.5

## Whether the drifter should offer his deed now.
static func should_offer(ledger: Ledger, wallet: Wallet, rival_stack: int, buy_in: int,
		offered_this_sitting: bool, stack_share: float = OFFER_STACK_SHARE) -> bool:
	return ledger.drifter_has_claim and not offered_this_sitting \
		and wallet.balance >= STAKE_SILVER \
		and float(rival_stack) <= float(buy_in) * stack_share

## Escrow the player's stake. False if the wallet can't cover it.
static func accept(wallet: Wallet) -> bool:
	return wallet.spend_silver(STAKE_SILVER)

## Settle the side stakes from the hand's payouts (seat id -> chips won).
## Returns "player", "rival", or "split". Updates the ledger, wallet (the
## escrowed stake comes back unless the rival won), and the rival's memory.
static func resolve(payouts: Dictionary, player_seat: int, rival_seat: int, ledger: Ledger,
		wallet: Wallet, rival_memory: NPCMemory, hand_number: int) -> String:
	var player_won := int(payouts.get(player_seat, 0)) > 0
	var rival_won := int(payouts.get(rival_seat, 0)) > 0
	if player_won and not rival_won:
		wallet.add_silver(STAKE_SILVER)
		ledger.drifter_has_claim = false
		ledger.has_claim_deed = true
		if rival_memory != null:
			rival_memory.record_event("deed_lost", hand_number)
		return "player"
	if rival_won and not player_won:
		if rival_memory != null:
			rival_memory.record_event("deed_defended", hand_number)
		return "rival"
	wallet.add_silver(STAKE_SILVER)
	return "split"
