<script lang="ts">
  // Boots the Godot web export from /godot (built by `npm run godot:export`).
  // Godot draws nothing yet (Svelte draws the interface), so the canvas is a
  // fixed 64x64 and hidden; rendering a full-window canvas every frame slowed
  // the game's own timers badly on software-rendered browsers. When Godot
  // gets a world view, switch back to canvasResizePolicy 2 and show it.
  import { onMount } from "svelte";

  let { onError }: { onError: (message: string) => void } = $props();
  let canvas: HTMLCanvasElement;

  type EngineCtor = new (config: Record<string, unknown>) => {
    startGame(overrides?: Record<string, unknown>): Promise<void>;
  };

  function loadScript(src: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const el = document.createElement("script");
      el.src = src;
      el.onload = () => resolve();
      el.onerror = () => reject(new Error(`Could not load ${src}`));
      document.head.appendChild(el);
    });
  }

  onMount(async () => {
    try {
      await loadScript("/godot/maverick.js");
    } catch {
      onError("The Godot build is missing. Run `npm run godot:export` in web/.");
      return;
    }
    const Engine = (window as unknown as { Engine: EngineCtor }).Engine;
    const engine = new Engine({
      executable: "/godot/maverick",
      canvas,
      args: [],
      canvasResizePolicy: 0,
      focusCanvas: false,
      ensureCrossOriginIsolationHeaders: false,
      experimentalVK: false,
      gdextensionLibs: [],
    });
    engine.startGame().catch((error: unknown) => onError(`Godot failed to start: ${String(error)}`));
  });
</script>

<canvas bind:this={canvas} id="godot-canvas" class="godot" width="64" height="64" tabindex="-1" aria-hidden="true"></canvas>

<style>
  .godot {
    position: fixed;
    left: 0;
    top: 0;
    width: 64px;
    height: 64px;
    z-index: 0;
    pointer-events: none;
    opacity: 0;
  }
</style>
