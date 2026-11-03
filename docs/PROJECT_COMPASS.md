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
- **First-slice presentation:** top-down 2D pixel art, consistent with
  Maverick's GDD and current scenes. Reconsider 3D only as a later, explicit
  production decision.
- **World hierarchy:** New Canaan is the territory; Split River Valley is a
  region; Devil's Draw is the hub town; the Rusty Spur is its saloon; the Five
  Crowns are the long-term circuit; The Dealer remains the long-arc antagonist.
- **Money boundary:** table chips are the current hand/session bankroll;
  persistent wallet and assets are separate world state. Debt comes from
  explicit credit or obligations, not automatically from every ordinary poker
  loss. Currency names, units, conversion rates, and detailed debt terms remain
  to be designed.

## Open decisions

Do not reopen the approved decisions above without new owner direction. The
product title and detailed currency/credit rules still need a choice. Keep these
details data-driven until settled.

| Decision | Still open |
|---|---|
| Product title | Whether to retain Texas Hold'em Frontier, adopt Dust & Decisions, or choose another title |
| Currency details | Names/units for wallet currency, currency exchange, loan terms, repayment schedule, property valuation, and how reputation is represented |

**Decision record — 2026-11-02:** the owner approved the first-slice 2D
presentation, world hierarchy, and table-chip/wallet/debt boundary above. The
exact product title and currency implementation remain open.

## Architecture boundaries

- Poker legality, dealing, hand ranking, side pots, and settlement stay inside
  the reusable Godot engine.
- Persistent world state should be explicit and saveable. Use autoloads only
  for a few application-wide coordinators (for example, session/save services),
  not automatically for every domain concept.
- Connect hand outcomes to one ledger boundary. Keep table stacks, wallet
  currency, property value, debt, and reputation distinct; only explicit
  borrowing or obligations create debt.
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
