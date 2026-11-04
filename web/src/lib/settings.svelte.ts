// Player presentation preferences, kept in this browser (not in the game save:
// they are about this device, not the player's run).

const STORAGE_KEY = "maverick.settings.v1";

interface Stored {
  soundOn: boolean;
  volume: number; // 0..1 slider position
  reducedMotion: boolean;
}

function load(): Stored {
  const osReduced = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;
  const fallback: Stored = { soundOn: true, volume: 0.7, reducedMotion: osReduced };
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return fallback;
    const data = JSON.parse(raw) as Partial<Stored>;
    return {
      soundOn: typeof data.soundOn === "boolean" ? data.soundOn : fallback.soundOn,
      volume: typeof data.volume === "number" ? Math.min(1, Math.max(0, data.volume)) : fallback.volume,
      reducedMotion: typeof data.reducedMotion === "boolean" ? data.reducedMotion : fallback.reducedMotion,
    };
  } catch {
    return fallback;
  }
}

class Settings {
  soundOn = $state(true);
  volume = $state(0.7);
  reducedMotion = $state(false);

  constructor() {
    const stored = load();
    this.soundOn = stored.soundOn;
    this.volume = stored.volume;
    this.reducedMotion = stored.reducedMotion;
    $effect.root(() => {
      $effect(() => {
        const data: Stored = { soundOn: this.soundOn, volume: this.volume, reducedMotion: this.reducedMotion };
        try {
          localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
        } catch {
          // Private browsing or storage disabled: settings last for this visit.
        }
      });
      $effect(() => {
        document.documentElement.classList.toggle("reduce-motion", this.reducedMotion);
      });
    });
  }
}

export const settings = new Settings();
