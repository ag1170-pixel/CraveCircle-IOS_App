# CraveCircle

> **Reels → recipes. Hands-free cook. On-device.**

A native iOS app that turns a cooking reel from Instagram, TikTok, YouTube, or
Pinterest into a clean, structured recipe in about 30 seconds — fully on your
iPhone, using Apple's on-device Foundation Models. Then it stays out of the way
while you cook: full-screen flashcards, "Hey Crave" voice commands, timers that
start themselves.

**Links**
- Figma prototype: https://www.figma.com/design/yBLMbRRYqWAVeXFLdHVinL/CraveCircle-Prototyping
- Instagram: https://www.instagram.com/crave.circle/
- Website: https://cravecircle.cc

---

## 1. What this project is

Everyone saves cooking reels. Nobody cooks them. The recipe is buried in captions,
voice-overs, and comments. CraveCircle solves that in five pieces:

1. **Instant recipe import** — share any cooking reel to the app → the audio is
   transcribed on the Neural Engine, the recipe is extracted by Apple Intelligence,
   and you get ingredients + directions + nutrition in about 30 seconds. **Nothing
   is sent to a third-party AI.**
2. **Hands-free Cook Mode** — full-screen landscape flashcards you can drive by
   voice. Say "Hey Crave" to wake it, then "next" / "back" / "start timer".
3. **Honest nutrition** — USDA-backed per-serving macros that re-scale when you
   change the servings. **Free** — not behind a Premium gate.
4. **Smart grocery** — ingredients merge across recipes and group by aisle
   (produce, dairy, pantry, meat, spices).
5. **Social kitchen** — follow creators, see what friends shared, comment on
   dishes you've made.

---

## 2. Why it matters right now (Apple alignment)

Apple's most recent iOS / macOS launch leaned heavily into **on-device AI
experiences for the home** — recipe-style assistant cards powered by Apple
Intelligence, Visual Intelligence read-the-world features, and a renewed
emphasis on the home / cooking surface. The direction is clear: Apple wants
local-first, private, hands-free experiences on the kitchen counter.

**CraveCircle is already there.** We are built on exactly the frameworks Apple
is pushing:

- **Foundation Models** (iOS 26, Apple Intelligence) for recipe extraction —
  guided generation with structured output, so the LLM returns a `Recipe` object,
  not free text.
- **SpeechAnalyzer / SpeechTranscriber** for transcription on the Neural Engine.
- **Vision framework** for OCR on cookbook photos and Pinterest screenshots.
- **SFSpeechRecognizer + AVAudioEngine** with hardware noise cancellation for the
  "Hey Crave" wake word.
- **ActivityKit** for the import progress Live Activity on the Dynamic Island.
- **UserNotifications** for cook-time reminders.

We're not using Apple's direction as a marketing hook — we **wrote the app on
top of it** because that's the only way to deliver what the direction promises.
See `docs/APPLE_ALIGNMENT.md` for the deeper story.

---

## 3. How to run this project

### Prerequisites

- **Xcode 26.0** or later
- **iOS 26.0+** target. The on-device extraction needs a device that supports
  Apple Intelligence (iPhone 15 Pro and up). On older devices the app falls
  back to a heuristic parser — the import still works, just less polished.
- A free Apple Developer account is enough to run on a simulator; a device
  needs any signing team (free personal or paid).

### 3.1 Clone

```bash
git clone git@github.com:ag1170-pixel/CraveCircle-IOS_App.git
cd CraveCircle-IOS_App
```

### 3.2 Local config

The project reads your team ID and bundle ID from a gitignored `xcconfig` file.
Copy the example and fill it in:

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
# then edit Config/Local.xcconfig:
#   DEVELOPMENT_TEAM = <your team id, found in Xcode → Settings → Accounts>
#   CRAVE_BUNDLE_ID  = com.<your-name>.cravecircle  (any unique id you own)
```

If you skip this on a free personal team the build will fail to sign — the
error Xcode shows will point you right back to this step.

### 3.3 Open & run

```bash
open AICookBook.xcodeproj
```

Select the **AICookBook** scheme → pick a destination (**iPhone 17 Pro simulator**
is the one we test on) → ⌘R.

The first launch will drop you on the sign-in screen. Three paths from there:

- **Email + password** — any email, any password. Our Supabase instance will
  create the account.
- **Continue with Google** — opens Google's OAuth web view.
- **Continue as Guest** — browse everything; write actions prompt you to sign in.

### 3.4 Backend (optional, only if you want your own)

The app connects to our hosted Supabase instance by default. You don't need to
run anything server-side to build and use the app for review.

If you want your own backend:

1. Spin up Supabase.
2. Apply every SQL file in `supabase/` in alphabetical order. All migrations are
   idempotent, so re-runs are safe.
3. Point the app at your instance by editing the two keys in the project's
   build settings: `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

The six migrations in `supabase/` set up:
- Role self-elevation (founder → admin)
- Likes + saves (cross-device sync)
- Delete-me RPC (App Store Guideline 5.1.1(v))
- Comment moderation + orphan cleanup trigger
- Meal plan table
- Public reads for comments + likes

---

## 4. Repo structure

```
AICookBook/              — the iOS app sources (SwiftUI)
AICookBook.xcodeproj/    — Xcode project
AICookBookTests/         — unit tests
Config/                  — build xcconfig files (Local.xcconfig is gitignored)
CookingWidget/           — home-screen widget target
ShareExtension/          — share-sheet extension so any reel can land in the app
supabase/                — SQL migrations for the Supabase backend
docs/                    — pitch docs, App Store copy, Apple alignment notes
scripts/                 — one-off helpers
```

Features map to screen files inside `AICookBook/`:
- Import flow: `AddRecipeSheet`, `ImportSheet`, `ImportProgressScreen`,
  `OnDeviceTranscriber`, `RecipeExtractor`.
- Cook: `CookModeScreen`, `FlashcardCookScreen`, `VoiceCommandController`,
  `FloatingVoiceAssistantView`.
- Social: `FriendsScreen`, `CreatorProfileSheet`, `RecipeCommentsView`,
  `CircleNotificationsSheet`.
- Meal plan: `MealPlanScreen`, `MealPlanPickerSheet`.
- Studio: `StudioScreen`.

---

## 5. Tech used (reviewer cheat-sheet)

| Layer | Tech |
|---|---|
| UI | SwiftUI (every screen) + a few `UIViewControllerRepresentable` bridges |
| On-device LLM | `FoundationModels` framework, guided generation |
| Transcription | `SpeechAnalyzer` / `SpeechTranscriber` on the Neural Engine |
| OCR | Vision framework |
| Voice | `SFSpeechRecognizer` + `AVAudioEngine`, hardware noise cancellation |
| Live Activity | `ActivityKit` |
| Notifications | `UserNotifications` |
| Share-sheet import | App Group + Share Extension target |
| Auth | Supabase Auth (Google OAuth today; Sign in with Apple on deck) |
| Database | Supabase Postgres with Row-Level Security |
| Image cache | On-disk per-user scoped JSON + bounded `URLCache` |

**Accessibility** — Dynamic Type, Reduce Motion honored, VoiceOver labels on
every tappable element, Smart Invert correctness.

---

## 6. Mentor review quick-start

1. Open the Figma link at the top of this file and swipe through the prototype.
2. Clone the repo, follow §3, run on the iPhone 17 Pro simulator.
3. From **Discover**, pick any recipe → **Start Cooking** → segmented control
   top-right → **Flashcards**. Rotate to landscape. Mic + Speech permissions
   required for voice.
4. From the **+** sheet → **Import from social media** → paste any Instagram
   reel URL → watch the live progress banner. On a device with Apple Intelligence
   this takes ~30 s end-to-end.
5. Any recipe → **Plan** pill → pick Today / Dinner → Save → check **Profile →
   Meal Plan**. A local notification is scheduled 30 min before.

If anything doesn't work, open `docs/TODO_BREAK_THE_APP.md` and `docs/APPSTORE_READINESS_PLAN.md`
in the repo root — the known gaps are catalogued there honestly.
---

Built with care by Aditya Gupta and the CraveCircle team.
Questions: `help@cravecircle.cc`.
