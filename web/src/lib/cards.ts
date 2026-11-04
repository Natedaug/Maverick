// Card-code helpers for codes produced by PokerCard.to_code() ("As", "Td").

export type Suit = "s" | "h" | "d" | "c";

export const SUIT_SYMBOL: Record<Suit, string> = { s: "♠", h: "♥", d: "♦", c: "♣" };
export const SUIT_NAME: Record<Suit, string> = { s: "spades", h: "hearts", d: "diamonds", c: "clubs" };
const RANK_NAME: Record<string, string> = {
  A: "Ace", K: "King", Q: "Queen", J: "Jack", T: "Ten",
  "9": "Nine", "8": "Eight", "7": "Seven", "6": "Six", "5": "Five", "4": "Four", "3": "Three", "2": "Two",
};

export function parseCard(code: string): { rank: string; suit: Suit; label: string } {
  const rankCode = code.slice(0, 1);
  const suit = code.slice(1, 2) as Suit;
  return {
    rank: rankCode === "T" ? "10" : rankCode,
    suit,
    label: `${RANK_NAME[rankCode] ?? rankCode} of ${SUIT_NAME[suit] ?? suit}`,
  };
}

export const formatChips = (n: number): string => Math.round(n).toLocaleString("en-US");
