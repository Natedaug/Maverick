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

export type RivalTiming = "tank" | "snap" | "normal" | "";

/** Milestone 4 economy, all values computed by Godot (Svelte does no money math). */
export interface Economy {
  gold: number;
  day: number;
  season_days: number;
  /** Silver per gold at today's town rate, before the exchange fee. */
  gold_rate: number;
  /** Exact prices for preset amounts, fee included. */
  gold_quotes: { gold: number; buy_silver: number; sell_silver: number }[];
  max_gold_affordable: number;
  dealer_start_gold: number;
  dealer_owed_gold: number;
  dealer_due_day: number;
  dealer_overdue: boolean;
  markers: { taken_day: number; repay_silver: number; days_until_called: number }[];
  marker_silver: number;
  marker_terms: { early_silver: number; late_silver: number; early_days: number; called_at_days: number };
  can_borrow: boolean;
  barred: boolean;
  has_claim_deed: boolean;
  claim_income_silver: number;
}

export interface Status {
  /** Silver. */
  wallet_balance: number;
  wallet_units_per_chip: number;
  town_state: string;
  poker_volume: number;
  reputation: string;
  session_active: boolean;
  buy_in_chips: number;
  can_afford_buy_in: boolean;
  /** The drifter's visible tell: true = clean, false = dusty and tilted. */
  rival_kempt: boolean;
  rival_timing: RivalTiming;
  hand_settled: boolean;
  economy: Economy;
  /** The drifter's claim deed, staked as a side bet on one hand. */
  deed: {
    offer_pending: boolean;
    wager_active: boolean;
    stake_silver: number;
    value_gold: number;
    income_silver: number;
    can_afford: boolean;
  };
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
  | { type: "load" }
  | { type: "buy_gold" | "sell_gold" | "pay_dealer"; gold: number }
  | { type: "borrow" }
  | { type: "repay"; index: number }
  | { type: "sleep" }
  | { type: "deed_accept" }
  | { type: "deed_decline" };

export function isSeated(state: TableState | null): state is TableState & { snapshot: Snapshot } {
  return !!state && Array.isArray((state.snapshot as Snapshot).seats) && (state.snapshot as Snapshot).seats.length >= 2;
}
