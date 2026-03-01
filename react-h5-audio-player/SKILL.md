---
name: react-h5-audio-player
description: Use react-h5-audio-player in React apps: correct style import path (lib not dist), ref to underlying audio element, and onListen for playback time sync. Reference when integrating or replacing native audio with this player.
---

# react-h5-audio-player

Reference when adding or replacing an HTML5 audio player in a React app with the `react-h5-audio-player` package. Covers the correct styles import, accessing the underlying audio element for sync (e.g. segment highlighting), and time-update behavior.

---

## When to Use This Skill

- Integrating react-h5-audio-player for the first time.
- Replacing native `<audio controls>` with this component.
- Needing to read or sync `currentTime` (e.g. with transcript or segment highlighting).
- Build or runtime failing with missing styles or “ref not working”.

---

## 1. Style Import Path (Common Pitfall)

The package does **not** ship styles under `dist/`. Import from `lib/`:

```ts
// ✅ Correct
import "react-h5-audio-player/lib/styles.css";

// ❌ Wrong — will fail at build (Rollup/Vite "failed to resolve import")
import "react-h5-audio-player/dist/styles.css";
```

If the build fails with “Rollup failed to resolve import … react-h5-audio-player/dist/styles.css”, switch to `lib/styles.css`.

---

## 2. Accessing the Underlying Audio Element

The component is a class component that exposes the native `HTMLAudioElement` via ref:

- **Ref type**: The default export is a class; use a ref to the component instance.
- **Audio element**: `ref.current?.audio?.current` is the `HTMLAudioElement` (or `undefined` before mount).

Use this when you need to:

- Read or set `currentTime` outside the component’s own callbacks.
- Drive a custom progress UI or segment/transcript sync (e.g. in a `requestAnimationFrame` or effect that reads `currentTime`).

Example (TypeScript):

```tsx
import AudioPlayer from "react-h5-audio-player";

const playerRef = useRef<InstanceType<typeof AudioPlayer> | null>(null);

// Later:
const el = playerRef.current?.audio?.current;
if (el) {
  console.log(el.currentTime);
  el.currentTime = 30; // seek
}

<AudioPlayer ref={playerRef} src={url} ... />
```

---

## 3. Time Updates: onListen

For playback position updates (e.g. highlighting the current segment), use the **onListen** prop. It fires at a configurable interval while the audio is playing.

- **Signature**: `onListen?: (e: Event) => void` — `e.target` is the `HTMLAudioElement`.
- **Interval**: Controlled by **listenInterval** (default **1000** ms). Use a smaller value (e.g. **100**) for smoother UI updates.
- **Ref fallback**: If the event is not passed or you need to poll (e.g. in RAF), use `playerRef.current?.audio?.current?.currentTime`.

Example:

```tsx
const handleTimeUpdate = (e?: Event) => {
  const el = e?.target instanceof HTMLAudioElement ? e.target : playerRef.current?.audio?.current;
  if (!el) return;
  setCurrentTime(el.currentTime);
  // e.g. find segment and scroll into view
};

<AudioPlayer
  ref={playerRef}
  src={url}
  onListen={handleTimeUpdate}
  onPause={() => setCurrentTime(null)}
  onEnded={() => setCurrentTime(null)}
  listenInterval={100}
/>
```

---

## 4. Theming / Overrides

The component uses BEM-like classes under `.rhap_container`. Override in your CSS for layout and colors (e.g. `.rhap_progress-filled`, `.rhap_main-controls-button`). Scope overrides by a parent class (e.g. `.interview-audio-player`) to avoid affecting other instances.

---

## 5. Checklist

- [ ] Styles: `import "react-h5-audio-player/lib/styles.css"` (not `dist/`).
- [ ] Ref: Use `playerRef.current?.audio?.current` for the `HTMLAudioElement`.
- [ ] Time sync: Use `onListen` (and optionally `listenInterval`) for segment/transcript sync.
- [ ] Cleanup: No need to revoke object URLs from inside the component; revoke in the parent when changing `src` or unmounting.

---

## References

- [npm: react-h5-audio-player](https://www.npmjs.com/package/react-h5-audio-player)
- Package styles on disk: `node_modules/react-h5-audio-player/lib/styles.css` (and `lib/index.d.ts` for ref/onListen types).
