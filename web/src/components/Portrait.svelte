<script lang="ts">
  // The drifter's tell (NPC contract §4): how he looks. Kempt = clean and
  // pressed; unkempt = tilted — hat askew, stubble, trail dust, collar loose.
  // Placeholder vector art until a painted portrait replaces it.
  let { kempt = true }: { kempt?: boolean } = $props();

  const caption = $derived(kempt ? "Clean-shaven, collar buttoned" : "Stubbled and dusty, collar loose");

  // Brief glow when the look changes so the shift is noticed.
  let changed = $state(false);
  let previous: boolean | undefined;
  $effect(() => {
    const now = kempt;
    if (previous !== undefined && previous !== now) {
      changed = true;
      const timer = setTimeout(() => (changed = false), 1400);
      previous = now;
      return () => clearTimeout(timer);
    }
    previous = now;
  });
</script>

<figure class="portrait" class:unkempt={!kempt} class:changed>
  <svg viewBox="0 0 120 120" role="img" aria-label={`The drifter: ${caption.toLowerCase()}`}>
    <defs>
      <clipPath id="frame">
        <rect x="2" y="2" width="116" height="116" rx="14" />
      </clipPath>
      <radialGradient id="lamp" cx="50%" cy="35%" r="70%">
        <stop offset="0" stop-color="#6b5434" />
        <stop offset="1" stop-color="#2a2016" />
      </radialGradient>
    </defs>
    <g clip-path="url(#frame)">
      <rect width="120" height="120" fill="url(#lamp)" />

      <!-- Coat and shirt -->
      <path d="M8 120 C10 96 28 86 46 82 L60 96 L74 82 C92 86 110 96 112 120 Z" fill="#4a3424" />
      <path d="M46 82 L60 96 L74 82 L68 80 L60 88 L52 80 Z" fill="#d9ceb4" />
      <!-- Kempt: buttoned collar and a neat bandana knot -->
      <g class="kempt-only">
        <path d="M52 80 L60 90 L68 80 L64 78 L60 84 L56 78 Z" fill="#efe6d0" />
        <path d="M55 88 L60 92 L65 88 L63 98 L60 95 L57 98 Z" fill="#7c2f26" />
      </g>
      <!-- Unkempt: collar open, bandana slipped, dust on the coat -->
      <g class="unkempt-only">
        <path d="M50 79 L58 92 L54 80 Z M70 79 L64 90 L67 80 Z" fill="#c9bc9c" />
        <path d="M60 92 C66 94 70 99 72 106 L67 104 L64 108 C62 101 60 97 58 95 Z" fill="#6a2a22" />
        <g fill="#a08a64" opacity="0.55">
          <circle cx="24" cy="104" r="5" />
          <circle cx="33" cy="112" r="3.5" />
          <circle cx="92" cy="100" r="4" />
          <circle cx="98" cy="110" r="2.5" />
          <circle cx="84" cy="114" r="2" />
        </g>
      </g>

      <!-- Neck and head -->
      <path d="M50 70 L50 84 L60 92 L70 84 L70 70 Z" fill="#a8774f" />
      <ellipse cx="60" cy="56" rx="19" ry="23" fill="#c4915f" />
      <ellipse cx="41" cy="58" rx="3.5" ry="6" fill="#b5844f" />
      <ellipse cx="79" cy="58" rx="3.5" ry="6" fill="#b5844f" />
      <!-- Hair below the hat -->
      <path d="M41 46 C41 40 46 38 50 38 L50 50 C46 48 43 50 41 54 Z" fill="#3a2716" />
      <path d="M79 46 C79 40 74 38 70 38 L70 50 C74 48 77 50 79 54 Z" fill="#3a2716" />

      <!-- Eyes -->
      <ellipse cx="52" cy="55" rx="2.4" ry="2" fill="#20160e" />
      <ellipse cx="68" cy="55" rx="2.4" ry="2" fill="#20160e" />
      <g class="kempt-only" stroke="#3a2716" stroke-width="1.8" stroke-linecap="round">
        <path d="M47 50 L56 49.5" />
        <path d="M64 49.5 L73 50" />
      </g>
      <g class="unkempt-only" stroke-linecap="round" fill="none">
        <path d="M47 49 L56 51" stroke="#3a2716" stroke-width="1.8" />
        <path d="M64 51.5 L73 49.5" stroke="#3a2716" stroke-width="1.8" />
        <path d="M48.5 58.5 Q52 60.5 55.5 58.5" stroke="#8a5e3a" stroke-width="1.2" />
        <path d="M64.5 58.5 Q68 60.5 71.5 58.5" stroke="#8a5e3a" stroke-width="1.2" />
      </g>
      <path d="M60 56 L58 64 L61 65" fill="none" stroke="#9c6c44" stroke-width="1.3" stroke-linecap="round" />

      <!-- Mustache and mouth -->
      <g class="kempt-only">
        <path d="M51 69 C54 66 58 66 60 67.5 C62 66 66 66 69 69 C65 69.5 62 69 60 68.5 C58 69 55 69.5 51 69 Z" fill="#3a2716" />
        <path d="M55 73 L65 73" stroke="#7a4a30" stroke-width="1.3" stroke-linecap="round" />
      </g>
      <g class="unkempt-only">
        <path d="M49 70 C52 66 57 65.5 60 67.5 C63 65.5 68 66 71 70.5 C68 69 66 70.5 63 69.5 C61 70 59 70 57 69.5 C54 70.5 52 69 49 70 Z" fill="#3a2716" />
        <path d="M55 74 Q60 72.5 65 74.5" fill="none" stroke="#7a4a30" stroke-width="1.3" stroke-linecap="round" />
        <!-- Stubble -->
        <g fill="#4a3424" opacity="0.7">
          <circle cx="46" cy="66" r="0.8" /><circle cx="48" cy="70" r="0.8" /><circle cx="50" cy="74" r="0.8" />
          <circle cx="53" cy="77" r="0.8" /><circle cx="57" cy="78.5" r="0.8" /><circle cx="61" cy="79" r="0.8" />
          <circle cx="65" cy="78" r="0.8" /><circle cx="68" cy="76" r="0.8" /><circle cx="71" cy="73" r="0.8" />
          <circle cx="73" cy="69" r="0.8" /><circle cx="74" cy="65" r="0.8" /><circle cx="47" cy="72" r="0.8" />
          <circle cx="51" cy="78" r="0.8" /><circle cx="55" cy="75.5" r="0.8" /><circle cx="60" cy="76.5" r="0.8" />
          <circle cx="64" cy="75.8" r="0.8" /><circle cx="70" cy="74.5" r="0.8" /><circle cx="72" cy="66" r="0.8" />
        </g>
        <!-- Dirt and sweat -->
        <ellipse cx="70" cy="62" rx="4.5" ry="3" fill="#6b4a2c" opacity="0.45" />
        <ellipse cx="48" cy="48" rx="3" ry="1.8" fill="#6b4a2c" opacity="0.4" />
        <path d="M77 44 C78.5 47 79.5 48.5 79.5 50 A1.8 1.8 0 0 1 76 50 C76 48.5 76.6 47 77 44 Z" fill="#cfe3ea" opacity="0.85" />
        <!-- Stray hair -->
        <path d="M44 40 C42 44 40 45 38 47 M75 39 C78 42 80 42 82 45" stroke="#3a2716" stroke-width="1.6" fill="none" stroke-linecap="round" />
      </g>

      <!-- Hat: level and brushed when kempt; knocked askew and dented when not -->
      <g class="hat">
        <path d="M14 42 C30 34 90 34 106 42 C100 47 84 45 60 45 C36 45 20 47 14 42 Z" fill="#2e2117" />
        <path d="M38 40 C38 22 44 14 60 14 C76 14 82 22 82 40 Z" fill="#3d2c1e" />
        <path d="M50 16 C55 21 65 21 70 16" stroke="#2e2117" stroke-width="2" fill="none" />
        <rect x="38" y="34" width="44" height="5" fill="#8a6a3e" />
        <g class="unkempt-only">
          <path d="M62 15 L66 24 L60 22 Z" fill="#2e2117" />
          <path d="M96 42 L101 45 L97 46 Z" fill="#59452d" />
          <ellipse cx="50" cy="28" rx="5" ry="3" fill="#8f7a58" opacity="0.4" />
        </g>
      </g>
    </g>
    <rect x="2" y="2" width="116" height="116" rx="14" fill="none" stroke="#bd9655" stroke-width="3" />
  </svg>
  <figcaption>{caption}</figcaption>
</figure>

<style>
  .portrait {
    --p: clamp(64px, min(8vw, 11vh), 120px);
    margin: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    width: calc(var(--p) * 1.25);
  }

  svg {
    width: var(--p);
    height: var(--p);
    display: block;
    border-radius: 14px;
    box-shadow: 0 6px 14px rgb(0 0 0 / 0.45);
    transition: box-shadow 400ms;
  }

  .changed svg {
    animation: notice 1.4s ease-out;
  }

  figcaption {
    font-size: 13px;
    line-height: 1.2;
    text-align: center;
    color: var(--muted);
  }

  .kempt-only,
  .unkempt-only {
    transition: opacity 700ms ease;
  }

  .unkempt-only {
    opacity: 0;
  }

  .unkempt .kempt-only {
    opacity: 0;
  }

  .unkempt .unkempt-only {
    opacity: 1;
  }

  .hat {
    transform-box: fill-box;
    transform-origin: 50% 100%;
    transition: transform 700ms ease;
  }

  .unkempt .hat {
    transform: rotate(-9deg) translate(-2px, 2px);
  }

  @keyframes notice {
    0%,
    100% {
      box-shadow: 0 6px 14px rgb(0 0 0 / 0.45);
    }
    30% {
      box-shadow:
        0 0 0 3px rgb(240 215 161 / 0.8),
        0 6px 18px rgb(0 0 0 / 0.5);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .kempt-only,
    .unkempt-only,
    .hat {
      transition: none;
    }

    .changed svg {
      animation: none;
    }
  }

  @media (max-height: 720px) {
    figcaption {
      display: none;
    }

    .portrait {
      width: auto;
    }
  }
</style>
