// The only module that talks to Godot. Godot's WebBridge calls
// window.maverickHost.attachGodot(cb) once it boots, then pushes every state
// change through window.maverickHost.receive(json).
import type { Command, TableState } from "./protocol";

type GodotCallback = (json: string) => void;

declare global {
  interface Window {
    maverickHost?: {
      attachGodot(callback: GodotCallback): void;
      receive(json: string): void;
    };
  }
}

class GameConnection {
  state = $state<TableState | null>(null);
  connected = $state(false);
  #godot: GodotCallback | null = null;

  constructor() {
    // Must exist before the Godot build boots; Godot checks for it on startup.
    window.maverickHost = {
      attachGodot: (callback) => {
        this.#godot = callback;
        this.connected = true;
        this.send({ type: "ready" });
      },
      receive: (json) => {
        try {
          this.state = JSON.parse(json) as TableState;
        } catch (error) {
          console.error("Maverick: malformed state from Godot", error);
        }
      },
    };
  }

  send(command: Command): void {
    if (!this.#godot) {
      console.warn("Maverick: Godot is not connected yet", command);
      return;
    }
    this.#godot(JSON.stringify(command));
  }
}

export const game = new GameConnection();
