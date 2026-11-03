# 🤠 TEXAS HOLD'EM FRONTIER
## Game Design Document — Reference for AI Agents & Collaborators

> **Version:** 1.0
> **Status:** Concept / Pre-Production
> **Genre:** Top-Down Open World Western RPG × Texas Hold'em Poker
> **Platform:** PC (primary), potential console/mobile ports
> **Audience:** Fans of Stardew Valley, Red Dead Redemption, Poker Night at the Inventory, and roguelike deck-builders

---

## 📌 QUICK REFERENCE (TL;DR for Agents)

| Attribute | Value |
|---|---|
| **Core Loop** | Explore world → Find poker game → Read tells → Play hand → Earn chips/reputation → Unlock higher stakes → Repeat |
| **Primary Currency** | Chips (= health, money, reputation) |
| **Unique Mechanic** | Tell System + Stare-Down Bluff Minigame |
| **Progression** | Reputation (Honest/Shark/Cheat/Sport) + Deck Collection + Camp Upgrades |
| **Retention Hooks** | Daily Hands, Seasonal Events, Living NPCs, Back Room Roguelike, Async Multiplayer |
| **Setting** | Devil's Draw & Split River Valley (fictional Old West) |
| **Final Boss** | "The Dealer" (high-stakes poker duel for your soul/the town) |

---

## 🎯 CORE CONCEPT

You are a drifter in the town of **Devil's Draw** with a deck of cards and a debt to pay. Poker is not just a minigame—it is the **language of power**. Every conversation, negotiation, and conflict is resolved through hands, bluffs, and reads.

**The Hook:** You cannot shoot your way through the West. Violence is a last resort with permanent consequences. But a well-timed bluff can topple a mayor.

---

## 🗺️ WORLD DESIGN

### Hub Town: Devil's Draw

| Location | Function | Notes |
|---|---|---|
| **The Rusty Spur Saloon** | Central poker hub | 3 tables: Low Stakes (safe), High Stakes (rep-gated), Back Room (invite-only, story-critical) |
| **The General Store** | Buy chips, items, intel | "Table talk" intel purchasable here |
| **The Sheriff's Office** | Bribes, bounties | Sheriff plays dirty poker |
| **The Undertaker's** | Clue hub | Read dead rivals' final hands for story clues |
| **The Church** | Reputation cleanse | Donate chips; Preacher grants tell-reading buff |
| **The Train Station** | New NPC arrival | Weekly rotation: marks, sharks, legends |
| **Your Camp** | Home base | Upgradeable; sleep to advance time; special deck storage |

### Open World: Split River Valley

- **Rival Towns** with distinct poker cultures:
  - **San Antonio Slums** — Aggressive players
  - **Austin Gulch** — Bluff-heavy players
  - **El Paso Flats** — Tight-passive players
- **Roadside Encounters** — Salesmen (quick hands for items), bandits (pay toll in chips OR beat them at poker)
- **The Riverboat Casino** — Moving high-stakes location; schedule is secret; find via rumors
- **Caves & Hideouts** — Outlaw camps; win for stolen goods; lose your horse
- **Poker Tournament Circuit** — Seasonal rotating events; win circuit to face The Dealer

---

## 🃏 POKER SYSTEM

### Core Rules
Standard Texas Hold'em, with the following adaptations:

- **Chips = Health + Currency + Reputation** (no HP system; lose bankroll = "broke" state → debt or dangerous work)
- **No instant death** — loss creates story (debt, revenge, redemption arcs)

### The Tell System
Every NPC has a unique tell (eye twitch, chip habit, breathing pattern). Tells are learned via:
1. Observation across multiple games (slow reveal)
2. Buying drinks (loosens lips and bluffs)
3. Hiring town gossip
4. Unlocking character dossiers through story

### Bluff Meter — Stare-Down Minigame
When bluffing:
1. Mini-game triggers (stare-down)
2. Hold button prompt while opponent's tell flickers
3. **Success:** opponent folds OR you gain "unreadable" reputation
4. **Failure:** opponent calls your bluff

### Unique Mechanics

#### 1. The Devil's Deck (Collectible Special Cards)
Found throughout the world; modify hands:

| Card | Effect |
|---|---|
| **The Dead Man's Hand** (A♠ 8♠) | Win = double chips; Lose = double loss |
| **The Preacher's Ace** | Once per game: swap one hole card for random new card |
| **The Snake Oil Joker** | Wild card; requires blind bet for one round |
| **The Sheriff's Star** | Reveals one opponent's hole card; costs reputation (counts as cheating) |

#### 2. Table Talk (Dialogue Poker)
Between hands, choose actions that affect AI behavior in real-time:

- **Intimidate** — Risk: opponent calls bluff more
- **Befriend** — Risk: opponent expects you to go easy
- **Lie about hand** — Risk: opponent reads you
- **Buy drink** — Opponent gets looser (but so do you)

#### 3. The Reputation Economy

| Reputation | How to Earn | Effect |
|---|---|---|
| **Honest** | Win cleanly | NPCs trust you; better quests |
| **Shark** | Win by bluffing | NPCs fear you; higher-stakes invites |
| **Cheat** | Cheat and get caught | Bounties, locked doors; underworld opens |
| **Good Sport** | Lose gracefully | NPCs give tips and second chances |

#### 4. The Camp (Meta-Progression)

| Building | Function |
|---|---|
| **The Study** | Unlock poker theory perks (pot odds display, opponent history log) |
| **The Stable** | Better horses → faster travel → more tournaments |
| **The Vault** | Store winnings; accrue interest (banking minigame) |
| **The Shrine** | Sacrifice chips for luck (RNG manipulation; risky/addictive) |

---

## 📖 STORY & QUESTS

### Main Story: "The Dealer's Debt"

**Premise:** You arrive in Devil's Draw owing a debt to **The Dealer**—a mysterious figure running the underground circuit. You have one in-game year to win enough chips to pay off the debt, or face worse consequences.

**Revelations (unlocked progressively):**
- The Dealer *rigged* your arrival—you are part of a larger game
- The Mayor is in debt to The Dealer
- The Sheriff is on the take
- A rival drifter (your mirror) is also climbing ranks — ally or destroy
- The final hand is against The Dealer himself; stakes are your soul or the town's freedom

### Side Quest Examples

| Quest | Description |
|---|---|
| **"The Widow's Hand"** | Win back a widow's ranch from a cheating card shark (prove cheating via investigation OR out-cheat) |
| **"The Preacher's Gamble"** | Help a terrible poker player win a tournament (coach via between-hand advice minigame) |
| **"The Kid"** | Train a young drifter; may become ally or rival |
| **"The Riverboat Heist"** | Rob the rigged casino (stealth + poker distraction) OR win it (high-stakes tournament) |
| **"The Undertaker's Secret"** | Solve conspiracy by playing dead players' final hands against living NPCs |

---

## 🔁 RETENTION & REPLAYABILITY

### 1. The Living World
- NPCs remember you; behavior changes based on wins/losses
- Tournaments rotate; new NPCs arrive weekly
- **Seasonal Events:** Summer Showdown, Winter Bluff, Dead Man's Hand (Halloween)
- **Dynamic Rivalries:** Beaten NPCs seek revenge; befriended NPCs defend you

### 2. The Poker Meta
- **Daily Hands:** New challenge with unique rules (e.g., "No face cards," "All-in only")
- **Leaderboards:** Global rankings (biggest pots, longest win streaks, most bluffs)
- **Deck Collection:** 52+ special cards; some ultra-rare (0.1% drop from specific NPCs)
- **The Back Room:** Roguelike mode — start with nothing, climb 10 tables with random modifiers (e.g., "All NPCs can see one of your cards")

### 3. Social Layer
- **Async Multiplayer:** Challenge friends' ghost AI (playing style recorded)
- **Town Chat:** Moderated message board in saloon
- **Co-op Tables:** Team with friend against NPC sharks (split pot, share glory)

### 4. "One More Hand" Loop
- Near-miss psychology: *almost* won that pot
- Escalating stakes: each win unlocks higher tables; each loss teaches a tell
- Camp: always something to upgrade

---

## 🎨 ART & AUDIO DIRECTION

### Visuals
- **Style:** Top-down pixel art (Stardew Valley × Red Dead Redemption)
- **Interiors:** Rich, warm saloon interiors
- **Exteriors:** Dusty, sun-bleached, dynamic lighting (lanterns at night, alley shadows)
- **Cards:** Hand-drawn, slightly worn; special cards have unique art
- **UI:** Diegetic where possible — bankroll shown as chip stack on table, not corner number

### Audio
- **Soundtrack:** Spaghetti Western guitar
- **Saloon piano:** Tempo changes with pot size
- **SFX:** Chip clinks, card shuffles
- **Silence:** Used for stare-down tension

---

## 🕹️ CONTROLS (Top-Down)

| Input | Action |
|---|---|
| **WASD / Left Stick** | Move |
| **E / A Button** | Interact |
| **Tab / Start** | Open satchel (inventory, deck, dossiers) |
| **Space / X Button** | Contextual: Call / Check / Fold |
| **Shift / RB** | Sprint |
| **P / Menu** | Pause / Poker Rules reference |

---

## 💡 DESIGN PILLARS ("Why This Works")

1. **Poker is inherently social and tense** — Stare-down mechanic translates tension into gameplay
2. **The world IS the table** — Every NPC interaction is a read/bluff minigame
3. **Progression is meaningful** — Earning respect (or fear), not just XP
4. **Failure is interesting** — Losing creates new story (debt, revenge, redemption)
5. **"One more hand" hook** — Always a bigger table, rarer card, tougher rival

---

## 🎁 BONUS: THE WILD CARD SYSTEM

Random events that change rules mid-game:

| Event | Effect |
|---|---|
| **"The Drunk Cowboy"** | Random NPC joins; plays completely randomly; cannot be read |
| **"The Sheriff's Raid"** | Mid-hand; hide chips via QTE or face fine |
| **"The Storm"** | Lightning strikes; table dark for one round; can palm a card (cheat) without consequence—or so you think |
| **"The Legend"** | Mysterious player who never loses; find their tell across multiple sessions |

---

## 🔧 IMPLEMENTATION NOTES FOR AGENTS

### Suggested Tech Stack
- **Engine:** Godot 4 (open-source, 2D-friendly) OR Unity 2D
- **Poker Logic:** Custom implementation of Texas Hold'em hand evaluator (well-documented problem; many open-source references)
- **AI:** Behavior trees for NPC poker styles (aggressive/tight/passive/bluff-heavy), plus a "tell" state machine for readable patterns
- **Save System:** JSON-based save for world state, deck collection, reputation, NPC relationships

### Priority Systems (Build Order)
1. **Poker core** — Standard Hold'em with betting, hand evaluation, and 1 AI opponent
2. **Tell system** — Add readable tells to AI + stare-down minigame
3. **Hub town** — Saloon, shop, camp with basic interactions
4. **Reputation economy** — Track and react to player behavior
5. **Story quests** — Main story + 2–3 side quests
6. **Open world** — Rival towns, travel, encounters
7. **Retention features** — Daily hands, deck collection, Back Room roguelike
8. **Social layer** — Async ghost AI, co-op tables

### Content Priorities (Minimum Viable Game)
- **NPCs:** 15–20 unique characters with dossiers and tells
- **Special Cards:** 20 (of planned 52+)
- **Quests:** 1 main story + 5 side quests
- **Locations:** Devil's Draw + 2 rival towns + riverboat
- **Tournaments:** 3 seasonal events for first release

### Key Design Risks to Mitigate
- **Poker fatigue:** Ensure world exploration and story break up poker sessions
- **AI readability vs. fairness:** Tells must be learnable but not trivially exploitable
- **Reputation complexity:** Keep four states clear; avoid overwhelming players
- **RNG frustration:** The Shrine and Devil's Deck add variance — balance with skill-based perks

---

## 📚 REFERENCE & INSPIRATION

| Title | Why Relevant |
|---|---|
| **Stardew Valley** | Top-down pixel art, living NPCs, day/night cycle |
| **Red Dead Redemption** | Western atmosphere, saloon culture |
| **Poker Night at the Inventory** | Character-driven poker, table talk |
| **Slay the Spire** | Deck-building, roguelike structure (Back Room mode) |
| **Cultist Simulator** | Reputation and consequence systems |
| **Disco Elysium** | Dialogue as gameplay |

---

## 📝 GLOSSARY

| Term | Definition |
|---|---|
| **Bankroll** | Player's chip total; serves as HP/currency/reputation |
| **Tell** | Readable behavioral pattern unique to each NPC |
| **Stare-Down** | Bluff minigame; hold prompt while tell flickers |
| **Devil's Deck** | Collectible special cards that modify hands |
| **Table Talk** | Between-hand dialogue actions affecting AI |
| **Back Room** | Roguelike mode with random modifiers |
| **The Dealer** | Final boss; runs underground circuit |
| **Ghost AI** | Recorded playing style of a friend (async multiplayer) |

---

## 🗓️ SUGGESTED ROADMAP

| Phase | Deliverable |
|---|---|
| **Prototype (1–2 mo)** | Playable poker + 1 AI + stare-down minigame |
| **Vertical Slice (3–4 mo)** | Devil's Draw hub + 5 NPCs + tell system + reputation |
| **Alpha (6–9 mo)** | Main story + 3 side quests + open world travel |
| **Beta (9–12 mo)** | All retention features + polish |
| **Launch (12–15 mo)** | Full release + seasonal event calendar |

---

*"In the West, a man's word is his bond. But a man's hand? That's his truth."*

---

**End of Document — Texas Hold'em Frontier GDD v1.0**
*For questions, expansions, or agent task assignments, refer to individual sections above.*

