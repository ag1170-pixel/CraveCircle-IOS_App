# CraveCircle — Task: Polish the Flashcard Hand-Gesture Navigation

Welcome! You're helping with **CraveCircle**, a native iOS cooking app. Your job is one focused
feature: the **hands-free "Flashcard" cooking mode** — where you wave your hand in front of the
phone to move between recipe steps. It works today but isn't smooth; make it **reliable and
delightful**. You do **not** need any server, VPN, or backend — this feature runs entirely on the phone.

---

## 1. What you need
- A **Mac with Xcode 26** (iOS 26 SDK).
- An **iPhone on iOS 26** — **required**: the gesture uses the front camera, and the Simulator has no
  camera, so you must run on a real iPhone.
- A **free Apple ID** (a paid Apple Developer account is NOT needed).
- ❌ You do **not** need Tailscale, the homelab, cookies, or any server. Ignore anything about those.

## 2. Get the code
You'll be added as a collaborator on the private repo (or sent a zip).
```bash
git clone git@github.com:ag1170-pixel/CraveCircle-IOS_App.git
cd CraveCircle-IOS_App
git checkout flashcard-gesture-polish     # ← your working branch
open AICookBook.xcodeproj
```

## 3. Make it build on your free Apple ID (~2 min, one time)
In Xcode:
1. Select the **AICookBook** target → **Signing & Capabilities** → set **Team** = your Apple ID,
   keep **Automatically manage signing**. If the bundle id `com.anassyed.AICookBook` is taken,
   change it to something unique like `com.<you>.cravecircle`.
2. On that same tab, **remove the "App Groups" capability** (click the small ⊖/trash on the
   App Groups box). Free Apple IDs can't use App Groups, and the flashcard feature doesn't need it.
3. Select the **ShareExtension** target → set the **same Team**, and **remove its "App Groups"**
   capability too. (Still fighting you? Edit Scheme → Build → uncheck ShareExtension so it doesn't
   build — it's unrelated to your task.)
4. Plug in your iPhone, pick it as the run target, press **⌘R**. First run only: on the iPhone,
   **Settings → General → VPN & Device Management → Trust** your developer certificate.

> The app opens straight into a signed-in demo with sample recipes — no login. The "paste a link"
> import won't work for you (it needs a server); that's expected and **not** your task.

## 4. Reach the feature
Open any recipe → **Start Cooking** → **Flashcards** (hands-free mode). Prop the phone up facing
you, and wave your hand left/right to change cards. (Saying "next"/"back" also works — that's the
voice sibling feature; your focus is the **hand gesture**.)

## 5. Your task — polish the hand-gesture navigation
**Files you'll work in:**
- `AICookBook/HandGestureController.swift` — front-camera hand-pose detection + swipe logic (the brains).
- `AICookBook/FlashcardCookScreen.swift` — the flashcard UI, the status indicator, and how a
  recognized swipe animates the card (the feel).
- `FloatingVoiceAssistantView.swift` / `VoiceCommandController.swift` exist for the **voice** sibling —
  only touch if your gesture work genuinely overlaps.

**What "polished" means (acceptance criteria):**
- A deliberate left/right hand swipe **reliably** moves to the next / previous card — in normal
  kitchen lighting, at arm's length.
- **No false triggers** from just adjusting/moving your hand, and **no double-jumps**.
- **Clear, subtle feedback**: the cook can tell when a hand is detected and when a swipe registered
  (an indicator + a smooth card transition). **Respect Reduce Motion.**
- **Correct direction**: swiping right should feel natural for "next" (the front camera is mirrored —
  tune this on the device).
- **Graceful**: if camera permission is denied, fall back to touch-swipe cleanly; recover when the
  hand leaves and re-enters the frame.
- Bonus: a first-time hint ("wave to flip"), and tuned sensitivity.

**Starting-point knobs already in `HandGestureController`** (refine or rework freely):
`travelThreshold`, `cooldown`, `window`, the minimum confident-joints count, and the
directional/monotonic swipe checks.

## 6. Send your work back
- Commit **only your gesture changes** (`HandGestureController.swift`, `FlashcardCookScreen.swift`,
  any new helper file). **Do NOT commit** the signing / App-Group / bundle-id changes from step 3 —
  those are only for your machine.
- Push your branch and open a **Pull Request**, or `git format-patch`/zip the changed files and send them.
- A **10-second screen recording** of the polished gesture working is hugely helpful.

## 7. Troubleshooting
- "Signing/App Groups" build error → redo step 3 (remove App Groups on both targets).
- Camera does nothing → you're on the Simulator; use a real iPhone.
- The app remembers recipes/edits between launches — that's intentional (local save).

Questions → ping the team. Thank you! 🙏
