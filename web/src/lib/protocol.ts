// Message shapes shared with Godot's WebBridge (src/web/web_bridge.gd).
// Godot owns every rule; these types only describe what it reports.

/** Mirrors PokerBetting.Action in addons/poker_engine/betting.gd. */
export const Action = { FOLD: 0, CHECK: 1, CALL: 2, BET: 3, RAISE: 4 } as const;
export type ActionId = (typeof Action)[keyof typeof Action];

export interface ActionOption {
  action: ActionId;
  amount?: number; // CALL: chips to add
  min_amount?: number; // BET/RAISE: legal target range
  max_amount?: number;
}

export interface SeatState {
  id: number;
  stack: number;
  street_commitment: number;
  total_commitment: number;
  folded: boolean;
  all_in: boolean;
  cards: string[]; // card codes like "As", "Td"; empty when hidden
  hidden_cards: number;
  out?: boolean;
}

export interface Snapshot {
  stage: "preflop" | "flop" | "turn" | "river" | "showdown";
  board: string[];
  seats: SeatState[];
  button: number;
  current_actor: number;
  pot: number;
  available_actions: ActionOption[];
  hand_number: number;
}

export type RivalTell = "kempt" | "unkempt" | "neutral";
export type RivalTiming = "tank" | "snap" | "normal" | "";

export interface Status {
  wallet_balance: number;
  wallet_units_per_chip: number;
  town_state: string;
  poker_volume: number;
  reputation: string;
  session_active: boolean;
  buy_in_chips: number;
  can_afford_buy_in: boolean;
  rival_tell: RivalTell;
  rival_label: string;
  rival_timing: RivalTiming;
  hand_settled: boolean;
}

export type Phase = "" | "reveal_cards" | "settling" | "hand_over";

export interface TableState {
  type: "state";
  snapshot: Snapshot | Record<string, never>;
  message: string;
  history: string[];
  status: Status;
  phase: Phase;
}

export type Command =
  | { type: "ready" }
  | { type: "buy_in"; chips: number }
  | { type: "action"; action: ActionId; amount: number }
  | { type: "next_hand" }
  | { type: "leave" }
  | { type: "save" }
  | { type: "load" };

export function isSeated(state: TableState | null): state is TableState & { snapshot: Snapshot } {
  return !!state && Array.isArray((state.snapshot as Snapshot).seats) && (state.snapshot as Snapshot).seats.length >= 2;
}
