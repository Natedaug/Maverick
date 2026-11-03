# Agent Guide

Before making project changes, read these in order:

1. [`docs/PROJECT_COMPASS.md`](docs/PROJECT_COMPASS.md) — mission, approved
   decisions, proposals that still need the owner's choice, and project-wide
   boundaries.
2. [`docs/PROJECT_ROADMAP.md`](docs/PROJECT_ROADMAP.md) — current milestone,
   exit conditions, dependencies, and next actions.
3. The specialist guide for the work: [`docs/UI_DESIGN_SYSTEM.md`](docs/UI_DESIGN_SYSTEM.md)
   for interface work; [`docs/POKER_ENGINE_WORKLOG.md`](docs/POKER_ENGINE_WORKLOG.md)
   and [`addons/poker_engine/README.md`](addons/poker_engine/README.md) for
   engine work; [`docs/FRONTIER_INTEGRATION_REVIEW.md`](docs/FRONTIER_INTEGRATION_REVIEW.md)
   for Frontier design/system porting.
4. Read the relevant implementation and existing tests before editing.

## Working rules

- Maverick is the Godot runtime and production source of truth. Keep one poker
  rules engine in `addons/poker_engine/`; other systems consume its API.
- Frontier is design/reference material. Port approved behavior into Maverick's
  architecture; do not copy its TypeScript runtime, duplicate poker engine,
  `node_modules/`, or generated `dist/` output.
- Frontier's `SALVAGE_MAP.md` is a file inventory, not authorization or the
  execution order. Follow `docs/PROJECT_ROADMAP.md` and wait for owner decisions
  before starting a port.
- Do not silently resolve open canon decisions. Mark new ideas as proposals in
  the compass/roadmap and get the owner's direction before dependent work.
- Keep work scoped to the current roadmap milestone. UI specialists should use
  `docs/UI_DESIGN_SYSTEM.md` and review a component after its behavior works.
- When implementation or owner feedback changes project status, update the
  roadmap's current snapshot. Put durable system-specific history in its
  worklog; keep the project compass concise.
- Inspect Git status before finishing. Report uncommitted work clearly; do not
  assume Frontier has a repository or alter either project's remote.
