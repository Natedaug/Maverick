# NPC Memory & Tell Contract — Milestone 3

**Project:** Maverick (Godot 4)  
**Milestone:** 3 — One remembered rival with fair tells  
**Status:** Owner-approved 2026-11-03; implemented (see §10 for clarifications made during implementation)  
**Scope:** One rival NPC, memory events, signed weights, decay, one observable tell.  
**Boundary:** No loans, property, town travel, or Crown arcs. Poker rules stay in `addons/poker_engine/`.

---

## 1. Memory Model

Every rival keeps one `NPCMemory` Resource per opponent (explicit serializable data, not an autoload). A memory entry is keyed by opponent seat/player id and accumulates signed weighted events.

### Memory Entry

| Field | Type | Meaning |
|---|---|---|
| `opponent_id` | String | Seat or player id this entry tracks |
| `weight` | float | Signed cumulative sentiment (-1.0 to +1.0 typical, unbounded) |
| `hands_seen` | int | Number of hands this opponent has been observed |
| `last_seen_hand` | int | Hand number of the most recent observation |
| `suck_outs_suffered` | int | Times this rival lost with the better hand |
| `suck_outs_delivered` | int | Times this rival won with the worse hand |
| `stone_cold_bluffs` | int | Bluffs caught with zero showdown value |
| `folded_to_aggression` | int | Times this rival folded to a bet/raise |
| `kempt` | bool | The visible tell: clean (`true`) or dusty and tilted (`false`), see §4 |

### Weight Rules (repair Frontier's clamp bug)

- Weights are **signed**. Negative values (the rival has been burned by this opponent) persist — never clamped at zero. Positive values mean the rival has had the better of this opponent.
- `weight` range is soft-clamped to [-2.0, +2.0] for decision bias, but the raw accumulated value is stored unbounded for history.
- Each event adds a fixed delta; no multiplicative compounding.

---

## 2. Memory Events (one per settled hand)

Each event is recorded once per hand per opponent who was involved:

| Event | Weight Delta | Creative Label | Trigger Condition |
|---|---|---|---|
| `suck_out_suffered` | -0.25 | "Sucked out on" | Rival had best hand pre-river, lost on river |
| `suck_out_delivered` | +0.15 | "Sucked out" | Rival had worst hand pre-river, won on river |
| `stone_cold_caught` | -0.30 | "Stone cold" | Rival bluffed with zero showdown value, called |
| `stone_cold_worked` | +0.20 | "Stone cold worked" | Rival bluffed with zero showdown value, won |
| `folded_to_aggression` | -0.10 | "Folded under pressure" | Rival folded to a bet or raise |
| `cooler_loss` | -0.15 | "Cooler" | Rival lost with a strong hand to a stronger one |
Tank/snap think-time is table flavor, not a memory event (revised 2026-11-04, see §4).

### Hand-result attribution

For each settled hand:
1. Determine if any player was "sucked out on" (best hand pre-river, lost at showdown).
2. Determine if any player "sucked out" (worst hand pre-river, won at showdown).
3. Determine if any bluff was "stone cold" (bettor had zero showdown value at river).
4. All other showdown participants get `cooler_loss` if they lost with a hand >= two pair.
5. Every folding-to-bet participant gets `folded_to_aggression`.

---

## 3. Decay

Weights decay slowly so old grudges fade but don't vanish:

- After each hand involving this rival, multiply `weight` by `0.97` (3% decay).
- `hands_seen` increments each hand the rival plays (regardless of opponent).
- `last_seen_hand` updates to current hand number.
- Decay applies to weight only, not to event counters (`suck_outs_suffered`, etc. — those are lifetime).

Rationale: A grudge from 50 hands ago still matters, but less than one from 5 hands ago.

---

## 4. Tell System (one tell, observable, learnable)

**Selected tell: Kempt vs Unkempt — how the rival looks** (owner revision 2026-11-04)

*Kempt* and *unkempt* describe the rival's appearance: clean and pressed, or
dusty and disheveled. The original draft of this section tied the words to
betting rhythm; the owner corrected that on 2026-11-04.

In code the tell is one stored binary, `NPCMemory.kempt: bool`.

| State | When | What the player sees | How he plays |
|---|---|---|---|
| **Kempt** (`true`) | default; recovers once `weight > -0.25` | clean-shaven, hat level, collar buttoned | his normal, disciplined game — memory adds no bias |
| **Unkempt** (`false`) | tilt reaches `weight <= -0.5` | hat knocked askew, stubble, trail dust, collar loose, sweat | loose: calls lighter, bluffs weak hands more (value bet thin) |

- **What tilts him** is the burn events in §2: suck-outs he suffers, bluffs the
  player catches, coolers, and folding to the player's pressure. Taking pots off
  the player (positive events) and decay calm him down.
- **Hysteresis** (`-0.5` to go unkempt, `-0.25` to clean up) keeps the look for
  several hands instead of flickering. It changes only between hands, in
  `finish_hand()`, and the hand history notes the change ("The drifter's collar
  has come loose…" / "…brushes the dust from his coat.").
- **Tank/snap** pauses stay as table flavor only: random (20% tank, 20% snap),
  unrelated to memory or cards, and no longer recorded.

**UI exposure:** a portrait of the drifter in his seat shows the two looks
(placeholder vector art until painted art exists), with a short caption.

**Fairness rule:** The tell is **probabilistic, not deterministic**. A Kempt rival can still bluff; an Unkempt rival still folds most junk and still has strong hands. The player must learn over multiple hands that the correlation exists — never guaranteed.

---

## 5. AI Decision Bias (memory-informed)

`AIPlayer.decide_session()` consults `NPCMemory` for the player (seat 0) and applies weight-based bias:

| Rival state | Effect on AI Action |
|---|---|
| Kempt | none — memory never moves a kempt rival's decisions |
| Unkempt | a fold facing a bet may become a call; a check with equity < 0.5 may become a bluff bet (0.6 pot) |

The chance of each shift is the unkempt bias: 25% of the cap at the edge of
tilt, rising to the full cap at `weight <= -2.0`. Tilt never adds folds or
gives up bets. The earlier lifetime-counter bluff adjustments
(`get_bluff_adjustment`) were removed with this revision.

**Fairness rule:** Memory bias shifts action probabilities by at most ±15%. The poker engine's legality checks still govern all actions. Memory never overrides legality.

---

## 6. GDScript API (new, explicit, not autoload)

### `NPCMemory` Resource (`src/world/npc_memory.gd`)

```gdscript
class_name NPCMemory extends Resource
var opponent_id: String = ""
var weight: float = 0.0
var hands_seen: int = 0
var last_seen_hand: int = 0
var suck_outs_suffered: int = 0
var suck_outs_delivered: int = 0
var stone_cold_bluffs: int = 0
var folded_to_aggression: int = 0
var kempt: bool = true  # the visible tell (§4)

func record_event(event: String, hand_number: int) -> bool
func finish_hand(hand_number: int) -> void  # hands_seen++, last_seen_hand, decay, update_appearance
func update_appearance() -> void  # kempt/unkempt hysteresis
func decay() -> void
func get_bias() -> float  # 0 while kempt; loose-play chance while unkempt (<= 0.15)
func to_dict() -> Dictionary / static func from_dict(data) -> NPCMemory
```

### `RivalMemory` (`src/world/rival_memory.gd`, owned by the table — not an autoload)

The rival holds one `NPCMemory` per opponent. Per the compass, domain state is
explicit and owned rather than an autoload; `PokerTable` owns the instance and
`SaveSystem` persists it.

```gdscript
class_name RivalMemory extends RefCounted
var memories: Dictionary = {}  # opponent_id -> NPCMemory
func get_memory(opponent_id: String) -> NPCMemory
func begin_hand(session: PokerSession, rival_seat: int) -> void
func observe_action(seat: int, action: PokerBetting.Action, facing_bet: bool) -> void
func record_settlement(session: PokerSession, payouts: Dictionary) -> void
```

### `AIPlayer` extension

Add `memory: NPCMemory` property. `decide_session()` calls
`apply_memory_bias()`, which shifts the intent with
probability `get_bias()`. `pick_timing()` rolls random think-time flavor.

---

## 7. Save/Load

`NPCMemory` is a `Resource` — it can be saved via `ResourceSaver` or included in the existing `SaveSystem` plain-text format. For Milestone 3, extend `SaveSystem` to also persist `RivalMemory` entries.

Save fields per opponent: `opponent_id`, `weight`, `hands_seen`, `last_seen_hand`, `suck_outs_suffered`, `suck_outs_delivered`, `stone_cold_bluffs`, `folded_to_aggression`, and `kempt` so the look survives a reload. Saves written before the 2026-11-04 revision have no `kempt`; it is derived from weight and their old tank/snap fields are ignored.

Format `MAVERICK_SAVE_V2`: the eight V1 lines, a memory count, then one JSON line per memory. V1 saves still load (with no rival memory). A malformed file is rejected without mutating any state.

---

## 8. Tests

| Test | What it verifies |
|---|---|
| `test_npc_memory.gd` | weight signed, no clamp at zero; decay reduces magnitude; tilt turns him unkempt between hands and the look holds (hysteresis) |
| `test_rival_memory.gd` | suck_out detection, stone_cold detection, cooler attribution |
| `test_ai_memory_bias.gd` | kempt rival unaffected; unkempt rival calls lighter and bluffs more, never tighter; timing is flavor only |
| `test_save_system.gd` | memory round-trip, V1 compatibility, malformed memory block rejected |
| `test_rusty_spur_flow.gd` | live table records hands into rival memory; save/load restores it |

The appearance logic is covered in `test_npc_memory.gd`; the bridge test checks `rival_kempt` is a bool.

---

## 9. Open Decisions (owner)

- Portrait art: painted/sprite art to replace the placeholder vector portrait
- Decay rate (0.97 proposed)
- Weight bias cap (15% proposed) and the -0.5 / -0.25 look thresholds
- ~~Which UI surface shows the tell~~ — a portrait in the rival's seat (2026-11-04)

---

**Rule reaffirmed:** Nothing is ported from Frontier's TypeScript. This contract is implemented fresh in GDScript behind Maverick-owned APIs. Poker rules remain exclusively in `addons/poker_engine/`.

---

## 10. Implementation clarifications (2026-11-03)

These were needed to make the approved rules consistent; the owner may revisit any of them.

- **Superseded 2026-11-04.** The first implementation drove kempt/unkempt from tank/snap rhythm and made burned rivals play warier. The owner clarified that the words mean appearance; §4 and §5 above now record the decision: tilt (negative weight) makes him unkempt and loose, and timing is flavor. Negative weight still means "burned by this opponent".
- **Attribution.** "Pre-river" means the turn. A suck-out needs a showdown on a full board. A stone-cold bluff means the rival made the last bet/raise holding only high card on the final board. A cooler means the rival lost at showdown with two pair or better without being ahead on the turn. Folds count only when the rival faced a bet. The rival uses only its own cards, public actions/board, and opponent cards shown at showdown.
- **Counting.** `hands_seen` increments once per settled hand (not once per event).
- **UI surface.** The Svelte table shows the portrait; the legacy Godot table appends `KEMPT` / `UNKEMPT` to the rival's role line. Think-time flavor text says "goes into the tank…" / "acts without a pause." Tank = 1.8 s, snap = 0.12 s, normal = 0.55 s.

