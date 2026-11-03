# Project Compass

**Purpose:** Keep the broad game mission, approved decisions, and open choices
visible while implementation moves through small, reviewable steps. This is the
short strategic reference for future agents; use the roadmap for current work.

## North star

Build a western RPG where poker is how people negotiate, deceive, remember, and
gain power. Exploration gives poker tables social context; bets create economic
stakes; tells and memory make rivals feel personal; wins and losses change the
world. Poker is the central language of the game, not a detached minigame.

The long-term setting includes a frontier territory, rival venues, debt and
ownership, persistent NPC relationships, and authored Crown-level confrontations.
The first proof should be a much smaller playable slice: a hub, a saloon, one
memorable rival, a meaningful stake, and a lasting consequence.

## Approved direction

- **Runtime:** Godot 4 with GDScript is the production game.
- **Poker rules:** `addons/poker_engine/` is the single rules authority. AI, UI,
  world, and story systems consume it through public action/query APIs.
- **Frontier's role:** its `Agent.md`, system prototypes, and Svelte interface
  are design references. Adopt ideas selectively and implement them in Maverick;
  do not merge two runtimes or maintain duplicate poker rules.
- **Design evolution:** `docs/UI_DESIGN_SYSTEM.md` is the evolving UI standard.
  Revise it from playtest feedback and apply it to new functional components.
- **Scope discipline:** prove one connected town/poker/economy/NPC slice before
  expanding regions, properties, variants, cheating, procedural modes, or social
  multiplayer.

## Open decisions — not canon yet

These choices affect world content and should be settled before dependent
production work. Until then, keep code/data easy to rename and describe any
mapping as a proposal.

| Decision | Current sources conflict | Candidate for discussion |
|---|---|---|
| Presentation | Maverick GDD/current scenes: top-down 2D pixel art; combined roadmap: 3D world | Choose 2D or 3D before world-scene/asset production |
| Product and world canon | Maverick: Texas Hold'em Frontier, Devil's Draw, Split River Valley, The Dealer; Frontier: Dust & Decisions, New Canaan, Five Crowns | New Canaan territory → Split River Valley region → Devil's Draw hub → Rusty Spur saloon; Five Crowns circuit and The Dealer as long arc |
| Money and stakes | Maverick: chips serve as bankroll/currency/reputation; Frontier: silver, gold, credit, debt, deeds | Define table bankroll, wallet, credit, assets, reputation, and conversion/consequence rules |
| World-slice scope | Maverick's original hub and Frontier's empire-building vision differ in scale | Prove one town, saloon, rival, property/debt consequence, and short Crown arc |

The candidate mappings are discussion material, not approved decisions. Record
the owner's choice here and in the detailed roadmap when made.

## Architecture boundaries

- Poker legality, dealing, hand ranking, side pots, and settlement stay inside
  the reusable Godot engine.
- Persistent world state should be explicit and saveable. Use autoloads only
  for a few application-wide coordinators (for example, session/save services),
  not automatically for every domain concept.
- Connect hand outcomes to one ledger boundary. Do not equate chips, currency,
  property value, debt, and reputation without a defined rule.
- NPC reads must be learnable and fair: distinguish observed fact, suspicion,
  rumor, and private information.
- The table's current UI is a functional prototype. Follow the design system;
  defer a wholesale redesign until playtests show which decisions and information
  need more support.

## How to use the project references

- [`PROJECT_ROADMAP.md`](PROJECT_ROADMAP.md) owns the current milestone and
  ordered exit criteria.
- [`TEXAS_HOLDEM_FRONTIER_GDD.md`](TEXAS_HOLDEM_FRONTIER_GDD.md) is Maverick's
  original game-design source; pending canon conflicts are listed above.
- [`FRONTIER_INTEGRATION_REVIEW.md`](FRONTIER_INTEGRATION_REVIEW.md) compares
  the local Frontier prototypes and records integration risks.
- [`POKER_ENGINE_WORKLOG.md`](POKER_ENGINE_WORKLOG.md) records engine design,
  validation, and handoffs.
- [`UI_DESIGN_SYSTEM.md`](UI_DESIGN_SYSTEM.md) guides interface components.

Update this compass only when project direction or an owner decision changes.
Put small task progress in the roadmap and implementation history in the
relevant worklog so this page stays useful at a glance.
