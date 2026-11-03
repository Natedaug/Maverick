# Maverick UI Design System

> **Version:** 0.3 (working draft; first table refinement implemented)  
> **Status:** Living project guide; revise as the prototype is played and the
> game grows.  
> **Scope:** Game interface, interactive controls, poker tables, and reusable
> presentation components.  
> **North star:** Poker is how people in this western world read, negotiate
> with, and remember one another. The interface should make the hand clear and
> leave room for the human tension around it.

This document translates the [Game Design Document](TEXAS_HOLDEM_FRONTIER_GDD.md)
and current prototype into shared visual and interaction decisions. It is a
guide, not a freeze: update its version and rationale when playtests or new game
systems teach us something useful. Keep it aligned with the [project work log](POKER_ENGINE_WORKLOG.md).

## Product context

The long-term game is a top-down western RPG set around Devil's Draw and Split
River Valley. Poker links exploration, character relationships, reputation,
and progression. A future screen may need to communicate a live tell, a dubious
deal, social stakes, and a legal poker action at once. Presentations should make
those signals feel part of the same world without obscuring the rules.

The current player-versus-AI saloon table is the first functional slice. It
proves the hand loop, not the finished visual language. Establish reusable
patterns here, then apply and adjust them in the HUD, dialogue, inventory,
character dossiers, and world interactions as those features become playable.

## Design principles

1. **Make the hand legible at a glance.** The player's cards, board, pot, stacks,
   whose turn it is, and what actions are legal are the table's information
   hierarchy.
2. **Use atmosphere around the action.** Warm wood, worn paper, brass, felt,
   lamplight, and restrained western ornament establish place. Avoid texture,
   type, or animation that lowers card and chip readability.
3. **Make stakes concrete.** Chips are bankroll and story stakes. Show the price
   to call, the target bet or raise, and the consequence of a broke state in
   plain terms before using purely decorative signals.
4. **Treat characters as part of the interface.** A table should leave room for
   portraits, action, tells, and table talk. Tells are learnable clues, not
   unexplained flashes that reveal hidden cards or guarantee a hand result.
5. **Make every control explain its current meaning.** Poker actions change
   between streets. Labels, price, bounds, and enabled state should change with
   them.
6. **Preserve trust.** Keep private cards private, distinguish confirmed
   information from a read or suspicion, and describe outcomes accurately.
7. **Prefer familiar interaction.** Use standard navigation, focus, button
   behavior, and controller mappings; let western voice live in the wording and
   presentation, not in ambiguous controls.

## Visual language

### Tone and materials

- **Base mood:** intimate saloon warmth with a little frontier dust and danger.
- **Primary material cues:** deep green table felt, dark walnut, aged ivory,
  muted brass, and restrained leather/rust accents.
- **Surface treatment:** light wear belongs on frames, backdrops, and card
  backs. Keep card faces, numbers, action text, and pot values crisp.
- **Ornament:** use border rules, small corner cuts, stamped icons, and subtle
  grain sparingly. No element should imply a control unless it is interactive.
- **Motion:** short, purposeful dealing, chip, and focus transitions can support
  tension. Avoid looping motion during player decisions or timing pressure that
  makes reading difficult.

### Starter color tokens

These are initial implementation targets, not final art direction. Keep them
centralized in theme/resources once the project has a shared Godot theme.

| Token | Starter value | Use |
|---|---|---|
| `ink` | `#171612` | Main backdrop, deep shadows |
| `wood` | `#29241B` | Panels and table-side surfaces |
| `felt` | `#174A3A` | Main poker surface |
| `brass` | `#BD9655` | Borders, button accents, selected markers |
| `parchment` | `#F0D7A1` | Headlines and warm emphasis |
| `paper` | `#FFF9E9` | Primary text and card faces |
| `muted` | `#B9B1A1` | Secondary labels and supporting text |
| `danger` | `#B84B3A` | Fold/destructive or urgent states, with text/icon |
| `heart_red` | `#B6443A` | Heart/diamond suit marks |
| `club_black` | `#282620` | Spade/club suit marks |

Do not rely on hue alone for turn, suit, legality, error, or selection. Pair color
with text, shape, position, or icon. Check contrast on the actual scene; these
tokens are not a guarantee of accessible contrast at every size.

### Type and numbers

- Use one highly readable UI face for action labels, card values, and amounts.
- A western display face may be used for the saloon title or chapter headings;
  do not use it for body text, controls, card ranks, or chip amounts.
- Give poker numerals stable widths where possible so stacks and changing bets
  do not cause layout jitter.
- Distinguish primary labels, supporting labels, and decorative lettering by
  size and weight, not by color alone.
- Avoid all-caps for long instructions. Reserve it for short headers and table
  labels.

### Cards and chips

- A card face must read by rank and suit at a glance; use conventional corner
  indices and recognizable suit marks.
- Red suits (hearts/diamonds) and dark suits (spades/clubs) are a secondary cue.
  Keep suit letter or symbol visible for players with color-vision differences.
- Hidden opponent cards use a distinct back, never a blank card or a face-like
  placeholder. Show the player's own cards consistently and preserve privacy
  until showdown rules allow reveal.
- Undealt community-card slots are muted felt placeholders, visually distinct
  from both a real card face and a hidden opponent-card back.
- Show chips as counts and, when space permits, as stacks. Never make users
  estimate a wager from stack height alone.
- Put the number beside a chip-stack illustration; use a consistent unit and
  separator format across the table, HUD, and shop.

## Layout and hierarchy

### Poker table layout

Keep one stable scan path:

1. Opponent identity, stack, and current action near the opponent's seat.
2. Board and pot in the center of the felt.
3. Player identity, private cards, and stack near the player's seat.
4. Legal actions and bet sizing in a consistent control dock.
5. Secondary details such as hand history, tells, table talk, and rules behind
   an explicit expandable panel or contextual prompt.

Keep the felt as the visual anchor, but preserve enough reserved space for the
board and cards when there are five community cards or longer translated text.
The current prototype may use flat color panels; future scenes can carry the
same hierarchy into diegetic table props.

### Responsive behavior

- PC is the primary platform. Design first for a common 16:9 window, then
  confirm a smaller laptop window and a wider desktop size.
- Anchor table information to seats and center the shared board/pot; avoid
  positioning essential controls at fixed screen coordinates.
- Let text wrap or reflow before controls overlap. Keep the action dock visible
  without scrolling during an ordinary hand.
- Scale card faces and spacing before shrinking action labels below a comfortable
  reading size.
- Keep essential information inside a safe margin from window edges. Do not
  depend on a single 1280×720 layout.

## Interaction and accessibility

### Poker action states

- **Available:** clear label and visible focus/hover treatment.
- **Current action:** identify the active player in both text and a positional
  or icon cue; do not communicate turn only by dimming another seat.
- **Unavailable:** visibly disabled, with enough context to understand why when
  that reason matters (for example, betting is closed because players are all-in).
- **Focused/pressed:** distinct keyboard/controller focus and pressed states;
  preserve focus when the screen updates after an action.
- **Pending wager:** show the actual target commitment and the legal minimum and
  maximum. For calls, show the amount due. Make all-in state explicit.
- **Resolved:** briefly confirm the action and resulting chips, then return focus
  to the next meaningful control or the next player turn.
- **Showdown:** clearly separate revealed live hands from folded/hidden hands.

Use standard focus navigation and never require a pointer for a core action.
Support keyboard/controller navigation when the player is in the table scene;
the GDD baseline is Space/X for contextual poker action and Start/Menu for
reference/pause. Button labels must remain visible and unambiguous even when
icons are added.

Keep text readable at normal laptop viewing distance, allow UI scaling, avoid
rapid flashing, and do not time-limit ordinary action selection. If a future
stare-down minigame uses timing, provide clear timing cues and an accessibility
setting where practical.

## Component patterns

- **Seat panel:** name, optional role/dealer marker, stack amount, current action,
  and optional tell cue. Maintain consistent placement around the table.
- **Card view:** face/back state, rank/suit, selected/focused state, and optional
  special-card treatment. The same card component should work in hand, deck
  collection, and dossier contexts.
- **Chip amount:** labeled number with optional stack illustration; define
  compact and full versions.
- **Action button:** visible action verb, contextual price/target when needed,
  enabled state, focus state, and optional secondary shortcut hint.
- **Table message:** short, factual line for action/result/turn guidance. Keep
  rules explanation and character voice in separate text roles.
- **Tell cue:** character-linked observation plus confidence/source (observed,
  learned, rumor) when those differences affect player decisions. Never encode
  private hole cards directly in the visual language.
- **Panel/frame:** consistent padding, border, corner treatment, and header
  placement. Use hierarchy and spacing before adding more ornament.

When a component appears in multiple places, prefer a reusable scene or theme
resource over copying style values into each caller. Keep game rules and screen
state in their owning systems; view components should present data and emit
intent, not decide poker legality.

## First refinement pass: current saloon table

The player-versus-AI table is functional and the user has confirmed it plays.
This first refinement pass implemented reusable cards, seat/turn labels,
contextual wager labels, and a compact action history. It remains a prototype;
the user's full visual redesign is intentionally deferred. The following items
are the next focused polish opportunities:

1. Play through several hands and tune spacing, contrast, control hierarchy, and
   history density from the owner's feedback.
2. Check layout at a small laptop window and a wider 16:9 window before adding
   texture or animation.
3. Confirm keyboard/controller focus order; currently mouse interaction and
   default Godot focus styles are the functional baseline.

Do this in small passes and ask for a quick playthrough after each meaningful
change. UI polish supports the mission, but a readable hand and satisfying
decision loop come first.

### Version notes

- **0.1:** Initial living guide and recommendations for the functional table.
- **0.2:** Reusable card faces/backs, seat and dealer-role hierarchy, explicit
  call and wager amounts, and compact action history implemented. Visual polish
  and smaller-window review remain deferred.
- **0.3:** Community-card slots use muted felt placeholders instead of card
  backs; hidden opponent hands retain the recognizable card-back cue.

## Lightweight review checklist

Before marking a UI component functional:

- Can a first-time player tell what this is and what to do next?
- Are the essential values and legal choices visible without inference?
- Are action cost, target, result, and disabled reason clear where relevant?
- Are hidden information, uncertainty, and character tells represented fairly?
- Can keyboard/controller focus reach and identify every core action?
- Does it remain readable at smaller laptop size and the supported UI scale?
- Does it use existing tokens and component patterns, or explain its exception?
- Does the presentation reinforce the frontier tone without hiding the game?

When revising this guide, add the reason for the change and update the version.
Keep decisions that support the game mission; retire patterns that playtests
show are confusing or cumbersome.
