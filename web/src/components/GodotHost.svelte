<script lang="ts">
  // Boots the Godot web export from /godot (built by `npm run godot:export`).
  // The canvas sits behind the interface; it will show the world view later.
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
      canvasResizePolicy: 2,
      focusCanvas: false,
      ensureCrossOriginIsolationHeaders: false,
      experimentalVK: false,
      gdextensionLibs: [],
    });
    engine.startGame().catch((error: unknown) => onError(`Godot failed to start: ${String(error)}`));
  });
</script>

<canvas bind:this={canvas} id="godot-canvas" class="godot" tabindex="-1" aria-hidden="true"></canvas>

<style>
  .godot {
    position: fixed;
    inset: 0;
    width: 100vw;
    height: 100vh;
    z-index: 0;
    pointer-events: none;
    opacity: 0;
  }
</style>
