# Third-party art (local only)

Art in subfolders here is **not committed**: its license doesn't allow
redistribution (the GitHub repo is public). Each person downloads it once.

| Folder | Pack | Source | Terms (from the page, 2026-11-04) |
|---|---|---|---|
| `jarppix_western/` | Top down WESTERN tileset, by Jarppix | https://jarppix.itch.io/top-down-western-tileset ("Name your own price"; $0 works) | "This pack can be used in any project and game engine, both commercial and non-commercial." Redistribution and attribution aren't addressed, so we keep it out of the repo and credit the artist in-game. |

To set up:
1. Download the pack from itch.io and put its five PNG files in
   `assets/third_party/jarppix_western/`.
2. Run `godot --headless --path . --import`, then
   `godot --headless --path . -s tools/prepare_jarppix.gd` to make the
   `_keyed` sheets (backgrounds removed) that the town uses.
3. Re-export the web build (`cd web && npm run godot:export`).

Without the pack, the town draws plain stand-in shapes and says so.
