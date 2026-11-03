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
| `tank_count` | int | Times this rival took unusually long to act |
| `snap_count` | int | Times this rival acted instantly |

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
| `tank` | 0.0 | "In the tank" | Rival took longer than threshold to act |
| `snap` | 0.0 | "Snap" | Rival acted within instant-action threshold |

**Tank/snap don't change weight directly** — they feed the tell system (see section 4).

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

**Selected tell: "Unkempt vs Kempt" betting rhythm**

A rival's `tank` and `snap` counts over the last 5 hands determine their current mental state:

| State | Condition | Observable Behavior | Player Exploit |
|---|---|---|---|
| **Kempt** | `snap >= 3` in last 5 hands | Instant actions, steady chip placement | Bluff more; they're on autopilot |
| **Unkempt** | `tank >= 3` in last 5 hands | Long pauses, shaky bet sizing | Value bet thin; they're tilted/distracted |
| **Neutral** | otherwise | Normal timing | Play straightforward |

**UI exposure:** The rival's name tag or avatar shows a small icon:
- 🎯 Kempt (steady)
- 🌀 Unkempt (shaken)
- (nothing) Neutral

**Fairness rule:** The tell is **probabilistic, not deterministic**. A Kempt rival can still have a strong hand; an Unkempt rival can still bluff. The player must learn over multiple hands that the correlation exists — never guaranteed.

---

## 5. AI Decision Bias (memory-informed)

`AIPlayer.decide_session()` consults `NPCMemory` for the player (seat 0) and applies weight-based bias:

| Memory Weight | Effect on AI Action |
|---|---|
| `weight > 0.5` (grudge held against player) | More likely to call player's bets; less likely to fold to player |
| `weight < -0.5` (rival likes/respects player) | More likely to fold to player aggression; less likely to bluff into player |
| `suck_outs_delivered > 2` | Rival is overconfident; slightly more likely to bluff |
| `stone_cold_caught > 1` | Rival is wary; less likely to bluff into player |

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
var tank_count: int = 0
var snap_count: int = 0
var recent_tanks: Array[int] = []  # hand numbers of last 5 tanks
var recent_snaps: Array[int] = []  # hand numbers of last 5 snaps

func record_event(event: String, hand_number: int) -> bool
func finish_hand(hand_number: int) -> void  # hands_seen++, last_seen_hand, decay
func decay() -> void
func get_tell_state() -> String  # "kempt" / "unkempt" / "neutral"
func get_bias() -> float  # -1.0 to +1.0 decision bias
func get_label() -> String  # human-readable state
func get_bluff_adjustment() -> float
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
func observe_timing(kind: String) -> void            # "tank" / "snap"
func record_settlement(session: PokerSession, payouts: Dictionary) -> void
```

### `AIPlayer` extension

Add `memory: NPCMemory` property. `decide_session()` adjusts bluff frequency with
`get_bluff_adjustment()`, then `apply_memory_bias()` shifts the intent with
probability `|get_bias()|`. `pick_timing()` rolls the visible rhythm (§4).

---

## 7. Save/Load

`NPCMemory` is a `Resource` — it can be saved via `ResourceSaver` or included in the existing `SaveSystem` plain-text format. For Milestone 3, extend `SaveSystem` to also persist `RivalMemory` entries.

Save fields per opponent: `opponent_id`, `weight`, `hands_seen`, `last_seen_hand`, `suck_outs_suffered`, `suck_outs_delivered`, `stone_cold_bluffs`, `folded_to_aggression`, `tank_count`, `snap_count`, plus `recent_tanks`/`recent_snaps` so the tell state survives a reload.

Format `MAVERICK_SAVE_V2`: the eight V1 lines, a memory count, then one JSON line per memory. V1 saves still load (with no rival memory). A malformed file is rejected without mutating any state.

---

## 8. Tests

| Test | What it verifies |
|---|---|
| `test_npc_memory.gd` | weight signed, no clamp at zero; decay reduces magnitude; tell state flips kempt↔unkempt |
| `test_rival_memory.gd` | suck_out detection, stone_cold detection, cooler attribution |
| `test_ai_memory_bias.gd` | AI with negative memory weight folds more to player aggression |
| `test_save_system.gd` | memory round-trip, V1 compatibility, malformed memory block rejected |
| `test_rusty_spur_flow.gd` | live table records hands into rival memory; save/load restores it |

The tell label logic is covered in `test_npc_memory.gd`; a separate `test_tell_ui.gd` was not added.

---

## 9. Open Decisions (owner)

- Tell icon/visual design (emoji vs sprite vs color)
- Decay rate (0.97 proposed)
- Weight bias cap (±15% proposed)
- Which UI surface shows the tell (name tag, avatar, status line)

---

**Rule reaffirmed:** Nothing is ported from Frontier's TypeScript. This contract is implemented fresh in GDScript behind Maverick-owned APIs. Poker rules remain exclusively in `addons/poker_engine/`.

---

## 10. Implementation clarifications (2026-11-03)

These were needed to make the approved rules consistent; the owner may revisit any of them.

- **Weight wording.** §1 called negative weights "grudges", while §5 says negative weight makes the rival fold more and bluff less. The implementation follows the mechanics in §2, §5 and §8: negative = burned/wary, positive = emboldened.
- **What drives the tell (not specified in §4).** The rival's timing comes from its memory of the player: an emboldened rival (weight ≥ +0.5) tanks ~60% of decisions (snaps 10%); a wary rival (weight ≤ −0.5) snaps ~60% (tanks 10%); otherwise 20%/20%. This keeps §4's exploit column true: **Unkempt** rivals call lighter (value bet thin), **Kempt** rivals fold more to pressure (bluff more). It is probabilistic, so the tell is learnable, not certain.
- **Bias strength.** No effect while |weight| < 0.5; above that the shift probability scales linearly to the 15% cap at |weight| = 2.0. Wary rivals only abandon low-equity bets (bluffs), never value bets.
- **Attribution.** "Pre-river" means the turn. A suck-out needs a showdown on a full board. A stone-cold bluff means the rival made the last bet/raise holding only high card on the final board. A cooler means the rival lost at showdown with two pair or better without being ahead on the turn. Folds count only when the rival faced a bet. The rival uses only its own cards, public actions/board, and opponent cards shown at showdown.
- **Counting.** `hands_seen` increments once per settled hand (not once per event). Tank/snap is recorded at most once per hand each; the tell window is the last 5 hands by hand number.
- **UI surface.** The live table appends `KEMPT` / `UNKEMPT` to the rival's role line, and the table text says "goes into the tank…" / "acts without a pause." Tank = 1.8 s, snap = 0.12 s, normal = 0.55 s.

