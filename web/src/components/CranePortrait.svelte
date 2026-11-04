<script lang="ts">
  // Augustus Crane of the Gilded Riverboat (working name). Placeholder vector
  // art in the same style as the drifter's portrait, until painted art exists.
  let { caption = true }: { caption?: boolean } = $props();
</script>

<figure class="portrait">
  <svg viewBox="0 0 120 120" role="img" aria-label="Augustus Crane: top hat, silver side-whiskers, gold watch chain">
    <defs>
      <clipPath id="crane-frame">
        <rect x="2" y="2" width="116" height="116" rx="14" />
      </clipPath>
      <radialGradient id="crane-lamp" cx="50%" cy="35%" r="75%">
        <stop offset="0" stop-color="#3b4a5e" />
        <stop offset="1" stop-color="#141a24" />
      </radialGradient>
    </defs>
    <g clip-path="url(#crane-frame)">
      <rect width="120" height="120" fill="url(#crane-lamp)" />
      <!-- Frock coat, waistcoat, watch chain -->
      <path d="M6 120 C10 94 30 85 46 82 L60 100 L74 82 C90 85 110 94 114 120 Z" fill="#1c1c22" />
      <path d="M48 84 L60 100 L72 84 L76 120 L44 120 Z" fill="#5b2330" />
      <path d="M50 106 C56 112 64 112 70 106" stroke="#d9b45a" stroke-width="1.6" fill="none" />
      <circle cx="70" cy="106" r="2.2" fill="#d9b45a" />
      <circle cx="60" cy="104" r="1.2" fill="#d9b45a" />
      <circle cx="60" cy="112" r="1.2" fill="#d9b45a" />
      <!-- High collar and cravat with a gold pin -->
      <path d="M50 78 L60 92 L70 78 L66 76 L60 84 L54 76 Z" fill="#f4efe2" />
      <path d="M54 86 C57 84 63 84 66 86 L63 96 L60 93 L57 96 Z" fill="#111" />
      <circle cx="60" cy="89" r="1.6" fill="#e8c56a" />
      <!-- Neck and head -->
      <path d="M51 68 L51 82 L60 88 L69 82 L69 68 Z" fill="#c9a086" />
      <ellipse cx="60" cy="55" rx="18" ry="22" fill="#e0b79a" />
      <ellipse cx="42" cy="57" rx="3.2" ry="5.5" fill="#cfa488" />
      <ellipse cx="78" cy="57" rx="3.2" ry="5.5" fill="#cfa488" />
      <!-- Silver hair and mutton-chop side-whiskers -->
      <path d="M42 44 C42 40 46 38 50 38 L49 50 C46 49 44 51 43 55 Z" fill="#c9c6c0" />
      <path d="M78 44 C78 40 74 38 70 38 L71 50 C74 49 76 51 77 55 Z" fill="#c9c6c0" />
      <path d="M42 56 C42 66 45 72 51 74 L52 64 C48 62 45 60 44 55 Z" fill="#d6d3cd" />
      <path d="M78 56 C78 66 75 72 69 74 L68 64 C72 62 75 60 76 55 Z" fill="#d6d3cd" />
      <!-- Eyes: level, appraising -->
      <path d="M49 53 L56 53" stroke="#2a2420" stroke-width="2.2" stroke-linecap="round" />
      <path d="M64 53 L71 53" stroke="#2a2420" stroke-width="2.2" stroke-linecap="round" />
      <path d="M48 49 L57 48" stroke="#a9a6a0" stroke-width="1.8" stroke-linecap="round" />
      <path d="M63 48 L72 49" stroke="#a9a6a0" stroke-width="1.8" stroke-linecap="round" />
      <path d="M60 54 L58.5 63 L61 63.5" fill="none" stroke="#b58d72" stroke-width="1.3" stroke-linecap="round" />
      <!-- Waxed mustache and a thin smile -->
      <path d="M48 67 C52 64 57 64.5 60 66 C63 64.5 68 64 72 67 C69 68 66 67.5 60 67.5 C54 67.5 51 68 48 67 Z" fill="#e3e0da" />
      <path d="M55 71.5 Q60 73.5 65 71" fill="none" stroke="#8a5a48" stroke-width="1.2" stroke-linecap="round" />
      <!-- Top hat -->
      <path d="M26 41 C36 36 84 36 94 41 C88 45 74 44 60 44 C46 44 32 45 26 41 Z" fill="#0f0f12" />
      <rect x="40" y="6" width="40" height="35" rx="3" fill="#18181d" />
      <rect x="40" y="31" width="40" height="5" fill="#5b2330" />
      <path d="M43 9 L43 30" stroke="#2c2c34" stroke-width="2" />
    </g>
    <rect x="2" y="2" width="116" height="116" rx="14" fill="none" stroke="#d9b45a" stroke-width="3" />
  </svg>
  {#if caption}
    <figcaption>The Gilded Riverboat</figcaption>
  {/if}
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
  }

  figcaption {
    font-size: 13px;
    line-height: 1.2;
    text-align: center;
    color: var(--muted);
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
