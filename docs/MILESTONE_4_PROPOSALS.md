# Milestone 4 Proposals — money, debt, property, first Crown

**Status:** owner decisions recorded 2026-11-04 (see "Decisions" below). The
numbers are starting values for tuning, kept in data. Sections 1–5 keep the
original proposals and alternatives for reference.
**Milestone:** 4 — first connected story slice (see the roadmap).
**Sources:** the GDD's "The Dealer's Debt" premise and canon (2026-11-02),
Frontier `Agent.md` Part V (currency tiers, House Line, Crowns), and the
compass money boundary (chips are table bankroll; debt only from explicit
credit or obligations).

The slice needs just enough of each system to make one story connect:
arrive owing money → play the Rusty Spur → a poker result changes the town →
a debt or property consequence → a short Crown confrontation.

## 1. Currency

**Recommended: dollars, and chips at par.** The wallet is in dollars (`$1,250`).
The Rusty Spur sells chips 1:1 (`wallet_units_per_chip = 1.0`, already the
default). No coin denominations in the slice. Keep the rate per venue in data,
so later venues can charge a premium or take a rake.

Alternatives: Frontier's two tiers (silver for daily play, gold for property),
which adds an exchange step the slice doesn't need; or chips worth less than a
dollar (e.g. 10¢), which makes small stakes feel smaller.

## 2. Time

Debt needs a clock. **Recommended: a day passes when the player sleeps**
(leaving the saloon and resting at the boarding house). There is no real-time
clock and no day counter during a hand. The slice runs for a short season,
for example 14 days, not the GDD's full in-game year.

## 3. Debt

Two sources, both explicit, per the compass:

**a. The Dealer's marker (the premise).** You arrive owing The Dealer
**$5,000, due on day 14**, starting with $1,000 in your wallet. It doesn't
accrue interest; the pressure is the deadline. In the slice, missing it doesn't
end the game. Instead it triggers the Crown confrontation early, on worse
terms. (Ending states come later, with the full story.)

**b. The House Line (local credit).** The Rusty Spur's barkeep lends up to
**$1,500 in $500 markers**. Each marker costs **$100 if repaid within 7
days**, and $250 after that. If a marker is 14 days old, the House calls it: it
seizes your property (§4) if you have any; otherwise you are barred from the
Rusty Spur's tables until you pay, and your reputation drops.

Alternatives: interest compounding daily (harsher, harder to read); or no local
credit in the slice, only The Dealer's marker (simpler, but leaves out the "one
debt consequence" the slice needs).

## 4. Property

**Recommended: one deed, won at the table — the drifter's claim.** When the
drifter is losing badly, he puts up the deed to his silver claim in Split
River as part of a high-stakes hand. Win it and you own the claim: **$150 a day
in income** (paid when you sleep), with a resale value of about $2,000. The
House can seize it for an unpaid marker, and the drifter remembers losing it.

This ties the rival (Milestone 3) to property and debt in one object.

Alternatives: buy a room at the boarding house (simple, low drama); or buy a
share of the Rusty Spur (ties property to town prosperity, but it's a bigger
system).

## 5. First Crown

**Recommended: the Gilded Riverboat**, one of Frontier's five Crown venues. It
fits Split River Valley. The Crown is its owner (working name *Augustus
Crane*, a river tycoon) who holds paper on the Mayor and answers to The Dealer.
Per the GDD's revelations, that links the town's troubles to the long arc.

**The confrontation:** once your wallet reaches $3,000, or when The Dealer's
marker comes due, the riverboat docks at Devil's Draw and Crane invites you to
one heads-up freezeout. Stakes are set in a short exchange of dialogue:
- **Win:** Crane pays off part of your marker with The Dealer, and the town
  turns prosperous (his grip on the Mayor loosens).
- **Lose:** Crane takes a stake from you: the deed if you hold it, otherwise
  part of your wallet. The town turns stressed.

Either way, play continues; the full Crown arc is later work.

Alternatives: the Dust-Bowl Parlor (outlaw Crown; fits the drifter's world,
but not this valley); or make the Sheriff a local boss first, and leave Crowns
for after the slice.

## Decisions (owner, 2026-11-04)

- **Currency: silver and gold, at a floating rate.** Silver is everyday money;
  the Rusty Spur sells chips at 1 silver each. Gold is for deeds, big debts,
  and Crown stakes. The assay office exchanges them at a rate that moves with
  the town: **20 silver per gold when neutral, 18 when prosperous, 24 when
  stressed**, plus a 5% fee each way. A losing streak that stresses the town
  makes gold, and so the gold-denominated debt, more expensive in silver.
- **Time:** a day passes when the player sleeps; the slice season is 14 days.
- **The Dealer's marker:** you arrive owing **250 gold** (≈5,000 silver at the
  neutral rate), due on **day 14**, no interest, starting with **1,000 silver**.
  Missing it triggers the Crown confrontation early, on worse terms.
- **House Line (owner approved 2026-11-04):** §3b converted to silver: markers of 500 silver, up to
  3; repay 600 within 7 days, 750 after; called at 14 days old (seizes the
  deed, else bars you from the tables until paid and costs reputation).
- **Property:** the drifter's silver-claim deed (§4): won from him at the
  table, pays **150 silver a day** when you sleep, worth about 100 gold.
- **Deed wager details (implementation defaults, 2026-11-04; owner may tune):**
  once per sitting, after a hand where the drifter is down to half his buy-in
  or less, he offers the deed against **500 of the player's silver** (escrowed).
  The next pot's winner takes the side stakes; a split returns both. Losing the
  deed is a heavy memory event for him (-0.6, enough to turn him unkempt).
  If the House later seizes the deed, it stays with the House.
- **First Crown:** the Gilded Riverboat's owner (§5; working name Augustus
  Crane). Win/lose stakes as proposed; his stakes are in gold.

## What the owner needed to decide

1. Currency name and chip rate (§1).
2. Time model and season length (§2).
3. Debt terms: The Dealer's marker amount/deadline and the House Line
   numbers (§3).
4. The property (§4).
5. The first Crown and the confrontation's stakes (§5). Names here are working
   names.

Every number above is a starting point for tuning, stored as data rather than
hard-coded.

## Step 4 design — the Gilded Riverboat (implementation spec, 2026-11-04)

Built from the approved §5. Choices marked **(default)** were proposed by the
implementer and approved by the owner on 2026-11-04 ("good choices"); every
number lives in `CrownDuel` as data.

**Who:** Augustus Crane (working name), owner of the Gilded Riverboat. He
holds paper on the Mayor and answers to The Dealer. He plays differently from
the drifter: more aggressive, bigger bets, slightly more bluffs, and he
calculates more carefully (more equity samples). He has no tell in the slice
**(default)**: the drifter is the character you learn to read; Crane is the
test of what you learned.

**When the riverboat docks** (checked each morning, after you sleep; once per
season):
- **Invited:** your net worth reaches **3,000 silver**, counting gold at
  today's rate **(default: net worth, not just silver)**. Crane invites you. You
  may accept or decline; declining sends him away for now.
- **Summoned:** The Dealer's marker is overdue (the morning of day 15) and
  unpaid. Crane has bought your paper. You can't decline, and the Rusty Spur
  won't seat you until you face him. Paying The Dealer in full lifts the
  summons. A summons replaces an open invitation, and comes even if you
  declined him earlier.

**The terms (the dialogue choice):** Crane names the stakes and you answer
with one of:
- **"Name your stakes"** (standard), or **"Double it"** (twice the reward and
  twice the risk), or, if invited, **decline**.

| | Standard | Double |
|---|---|---|
| **Win (invited)** | Crane squares **100 gold** of your marker | **200 gold** |
| **Win (summoned, worse terms)** | **75 gold** | **150 gold** |
| **Lose** | He takes your claim deed; without one, **40%** of your silver and gold | The deed **and** 40%; without the deed, **80%** |
| **Lose (summoned, extra)** | **+50 gold** added to your marker | **+100 gold** |

If his payment exceeds what you still owe, he pays the rest to you in gold.
**Town:** winning loosens his grip on the Mayor (the town turns
**prosperous**); losing tightens it (the town turns **stressed**, and gold gets
dearer at the assay office).

**The match:** heads-up freezeout on the riverboat. Both start with **1,500
chips** **(default)**; these chips aren't bought with silver, the stakes above
are what's at risk. Blinds rise every **4 hands**: 25/50, 50/100, 100/200,
200/400, 400/800. The match ends when someone is broke. You can **concede** at
any time between hands, which counts as a loss. You can't save or leave mid-match.

**After:** Crane delivers a closing line, the result is applied, and you're
back in Devil's Draw. Play continues after a win or a loss. One confrontation
per season.
