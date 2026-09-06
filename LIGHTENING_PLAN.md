# CraveCircle — Lightening & Better-Alternatives Plan (no-harm)

Goal: keep the app **small on disk, light on storage, fast**, without breaking anything or
degrading quality. Everything here is either already done or a safe, reversible change.
Ordered by **impact ÷ risk** — do the top ones first.

---

## Where the weight actually is (measured)
- **Debug `.app` ≈ 48 MB** — but that's not what users download.
  - `Assets.car` (bundled images) **34 MB → ~15 MB** after image optimization (done, commit `92ccb9c`).
  - `debug.dylib` **13 MB** — **stripped entirely in Release builds** (0 MB shipped).
  - `chickenRecipe` alone was **13 MB** (3562×2849) → recompressed.
- **Real App Store download ≈ 15–18 MB** after Release stripping + App Thinning.
- Zero heavy third-party libraries — the app is 100% Apple frameworks. That's the single
  biggest "already light" win; keep it that way.

---

## 1. Images — the lighter-than-JPG answer (biggest lever)
**Short answer: HEIC.** Apple's native format, ~40–50% smaller than JPEG at the same quality,
hardware-decoded on every iPhone. Two different places matter, and they behave differently:

| Where | Format today | What to do | Why |
|---|---|---|---|
| **Bundled catalog images** (Assets.xcassets) | recompiled by Xcode | keep dimensions modest (≤1400px, done) | Xcode re-encodes these into `Assets.car` — source format barely matters; **pixel dimensions are the real lever**, already cut. |
| **Runtime thumbnails** (`VideoThumbnail`, saved per import) | JPEG q0.8 | **switch to HEIC** | This is where HEIC pays off — every imported reel saves a frame to disk; HEIC ~halves that. |
| **Remote images** (network) | — | bounded `URLCache` 16 MB RAM / 96 MB disk (done) | caps cache growth so "storage keeps growing" never happens. |

**Runtime HEIC switch** (the "from next thing onwards" ask): replace the JPEG encode in
`VideoThumbnail` with a HEIC encoder, JPEG fallback for the rare device without HEIC support.
- *Status:* **ready to do**, blocked only because `AppEnvironment.swift` is currently checked
  out by Antigravity. Do it the moment they commit (one small, isolated function).
- *No harm:* HEIC is readable everywhere in-app via `UIImage`; fallback keeps old devices safe.

**Even lighter, later:** AVIF/WebP are smaller still but need a decoder and aren't native to
`UIImage` — not worth the complexity vs HEIC for a phone-first app. Skip unless we ever ship a web view.

---

## 2. Build & shipping (free size wins, zero code change)
- **Release build** strips the 13 MB debug dylib and symbols → already happens on Archive.
- **App Thinning / on-demand**: the App Store slices assets per device automatically. Nothing to do
  beyond using the asset catalog (we do).
- **`ENABLE_USER_SCRIPT_SANDBOXING` / dead-strip**: confirm `DEAD_CODE_STRIPPING = YES` (default) so
  unreferenced Swift is dropped from the binary.
- **On-Demand Resources (later):** if the sample-recipe images ever grow, tag them ODR so they
  download on first use instead of shipping in the bundle. Not needed at 15 MB.

## 3. Code weight (dead-code / "ponytail")
- Removed dead `parse_recipe_content` (75 lines, backend) — done.
- **Run Periphery** across the Swift target to list unreferenced types/functions before we grow more.
  Safe: it only *reports*; we delete by hand after reading each hit. (Install: `brew install peripheryapp/periphery/periphery`, then `periphery scan`.)
- Keep the "Claude = logic, Antigravity = UI" split so we don't accumulate duplicate helpers.

## 4. Storage footprint (user's "don't let storage balloon" worry)
- **Local library** persists as compact JSON, not a heavy DB (done) — text is tiny.
- **Thumbnails** are the only real disk cost per recipe → HEIC (§1) halves it.
- **Bounded URLCache** (done) caps remote-image disk at 96 MB hard ceiling.
- **Add later:** a "Clear cache" row in Profile (one line: `URLCache.shared.removeAllCachedResponses()`)
  so a worried user can reclaim space without deleting the app. High reassurance, ~5 lines.

## 5. Backend / model (already lean, note for the future)
- faster-whisper `small` int8 on CPU — small footprint, GPU left to Voiceprint.
- Caption-first path skips transcription entirely when a good caption exists (fast + zero model load).
- On-device transcription (Apple Speech) for narrated reels would remove server dependency for many
  imports — lighter *operationally*, not app-size. Tracked in remaining steps.

---

## Do-now checklist (safe, high value)
- [x] Optimize bundled images (dimensions) — `92ccb9c`
- [x] Bounded URLCache
- [x] Remove dead backend code
- [ ] **HEIC for runtime thumbnails** — the moment `AppEnvironment` is free
- [ ] Confirm `DEAD_CODE_STRIPPING = YES` on Release
- [ ] Add "Clear cache" row in Profile (reassurance)
- [ ] Run Periphery once, delete confirmed-dead Swift
