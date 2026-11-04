// Which table sounds a state change deserves. Pure: compares the previous and
// next state Godot reported, so a cue always matches something now visible.
import type { SoundKind } from "./sound";
import { isSeated, type Snapshot, type TableState } from "./protocol";

export interface Cue {
  kind: SoundKind;
  delayMs: number;
}

const PLAYER = 0;
const RIVAL = 1;
/** Stagger between cards dealt in one update (design brief: 80–120 ms). */
export const DEAL_STAGGER_MS = 100;

function playerTurn(state: TableState, snap: Snapshot): boolean {
  return state.phase === "" && snap.current_actor === PLAYER && snap.available_actions.length > 0;
}

/**
 * Cues for moving from `prev` to `next`. With `collapse` (reduced motion),
 * repeated cues of one kind play once instead of as a staggered run.
 */
export function cuesFor(prev: TableState | null, next: TableState, collapse = false): Cue[] {
  if (!isSeated(next)) return [];
  const snap = next.snapshot as Snapshot;
  const before = prev && isSeated(prev) ? (prev.snapshot as Snapshot) : null;
  const cues: Cue[] = [];
  const deal = (count: number) => {
    for (let i = 0; i < count; i++) cues.push({ kind: "deal", delayMs: i * DEAL_STAGGER_MS });
  };

  if (!before || before.hand_number !== snap.hand_number) {
    // A new hand: the hole cards land.
    deal(snap.seats[PLAYER]?.cards.length ?? 0);
  } else {
    deal(Math.max(0, snap.board.length - before.board.length));

    const rivalBefore = before.seats[RIVAL];
    const rivalNow = snap.seats[RIVAL];
    if (rivalBefore && rivalNow && rivalBefore.cards.length === 0 && rivalNow.cards.length > 0) {
      cues.push({ kind: "flip", delayMs: 0 });
    }

    const bet = snap.seats.some((seat, i) => seat.total_commitment > (before.seats[i]?.total_commitment ?? 0));
    if (bet) cues.push({ kind: "chips", delayMs: 0 });

    if (!prev!.status.hand_settled && next.status.hand_settled) {
      const won = (snap.seats[PLAYER]?.stack ?? 0) > (before.seats[PLAYER]?.stack ?? 0);
      cues.push({ kind: won ? "win" : "pot", delayMs: 0 });
    }
  }

  const wasTurn = before !== null && prev !== null && playerTurn(prev, before) && before.hand_number === snap.hand_number;
  if (playerTurn(next, snap) && !wasTurn) cues.push({ kind: "turn", delayMs: cues.length > 0 ? 160 : 0 });

  if (!collapse) return cues;
  const seen = new Set<SoundKind>();
  return cues.filter((c) => !seen.has(c.kind) && seen.add(c.kind)).map((c) => ({ ...c, delayMs: 0 }));
}
