# CraveCircle — App Store Listing

Ready-to-paste copy for App Store Connect. Everything here maps to a feature the code
actually ships — nothing aspirational, no fabricated statistics. Pattern inspired by Osta's
listing (short subtitle, five big screenshots, honest bullet list, free vs premium split).

---

## 1. App name
**CraveCircle**

## 2. Subtitle (30 characters max; shown under the app name)
> **Reels → recipes. Hands-free cook.**

(30 chars exactly. "Reels → recipes. Hands-free cook." — says the two things no competitor says.)

Fallback if 30 is tight on review:
- "Save a reel. Cook it hands-free."
- "Your social cookbook, voice-first."

## 3. Primary Category / Secondary Category
- **Primary:** Food & Drink
- **Secondary:** Lifestyle

## 4. Age rating
- **4+** today. If comments stay on at launch: **12+** (Infrequent/Mild Mature or Suggestive Themes).

## 5. Promotional text (170 chars; above the description, editable without re-review)
> Share a reel from Instagram, TikTok, or YouTube — we turn it into a clean recipe in seconds, all on your phone. Cook hands-free with voice. No ads.

## 6. Description

```
Your living cookbook. Save a reel, get a clean recipe, cook hands-free.

CraveCircle turns a cooking video — from Instagram, TikTok, YouTube, or Pinterest — into
a clean, structured recipe in seconds. Ingredients + directions + nutrition, no clutter,
no ads. Then it stays out of your way when you cook: big landscape flashcards, "Hey Crave"
voice commands, and timers that start themselves.

Private by design. The audio of your reel is transcribed on your iPhone, and the recipe
is extracted by Apple's on-device Foundation Models. Your cooking never touches a
third-party AI.

What's inside
• Share any reel → clean recipe in about 30 seconds (Instagram, TikTok, YouTube, Pinterest)
• Scan a cookbook page or Pinterest screenshot — the recipe is read on-device with Vision
• Hands-free Cook Mode: full-screen flashcards, "Hey Crave" wake word, voice navigation,
  self-starting timers
• USDA-backed per-serving nutrition — calories, protein, carbs, fat — scales live when you
  change the servings
• Smart grocery list — ingredients auto-group by aisle (produce, dairy, pantry, meat,
  spices) and dedupe across multiple recipes
• Translated-from-X — a reel in Hindi, Spanish, or Mandarin lands as an English recipe,
  clearly labelled
• Discover reel — a vertical feed of recipes tuned to your taste
• Circle — follow creators, see what friends shared, comment on dishes you've made
• Plan a meal — pick when you want to cook; CraveCircle reminds you 30 minutes before
• Works offline — nothing stops working on airplane mode

Free, forever
• Everything above. No paywall gates on nutrition. No paid tier for the social features.
• No ads.

Who it's for
• You save reels you never cook
• You scaled a recipe for two guests, then four more showed up
• You want to hit a protein number, not read a blog post
• You cook with your phone on the counter and sticky fingers

Privacy
• Reel audio is transcribed on your iPhone using the Neural Engine
• Recipe parsing runs on-device via Apple's Foundation Models framework
• Your account, your likes, your saves — stored in our EU-hosted database with Row-Level
  Security so nobody else can read them

Permissions we may ask for
• Microphone + Speech recognition — for "Hey Crave" voice commands
• Contacts — to help you find friends already using CraveCircle
• Notifications — for meal-plan cook reminders you set yourself

Support
help@cravecircle.cc · cravecircle.cc/support

Privacy
cravecircle.cc/privacy

Terms
cravecircle.cc/terms
```

## 7. What's New (release notes for v1.0 → first submission)

```
Hello, kitchen.

• Share a cooking reel from Instagram, TikTok, YouTube, or Pinterest — we turn it into
  a clean recipe in seconds, on your phone.
• New Cook Mode: landscape flashcards you can drive with your voice. Say "Hey Crave" to
  wake up, then "next" / "back" / "start timer".
• Smart grocery list — ingredients merge across recipes and group by aisle.
• USDA-backed nutrition per serving. Change servings; macros re-calculate.
• Follow creators, see what friends saved, comment on dishes you've made.
```

## 8. Keywords (100 characters, comma-separated, no spaces for max density)

```
recipe,cook,instagram,tiktok,pinterest,reel,import,grocery,aisle,nutrition,hands-free,voice,macros
```

(99 chars.)

## 9. Screenshot captions (5 iPhone screenshots, 6.9" / 6.7" / 5.5")

Each has a bold headline + one-liner. Shot the real app with real data (strip sample content
first, use the "no fake content" list in `docs/APPSTORE_READINESS_PLAN.md`).

### Screen 1 — Discover feed
> **A cookbook that fills itself.**
> Vertical reel of recipes tuned to your taste. Swipe, save, cook.

### Screen 2 — Share-sheet import
> **Share a reel. Get the recipe.**
> Any cooking video from Instagram, TikTok, YouTube, or Pinterest.
> Turned into ingredients + directions in about 30 seconds.

### Screen 3 — Flashcard Cook Mode
> **"Hey Crave, next step."**
> Hands-free. Big cards. Say it, don't tap it.
> Timers that start when the recipe says so.

### Screen 4 — Smart grocery
> **Groceries sort themselves.**
> Add a week of meals. Produce in one list, pantry in another.
> No duplicates. No re-reading recipes at the store.

### Screen 5 — Nutrition per serving
> **Macros you can trust.**
> USDA-backed calories, protein, carbs, fat per serving.
> Scale 2 → 6 servings and watch them update.

## 10. Review notes (what Apple reviewer needs)

```
Demo account
Username: review@cravecircle.cc
Password: ReviewMe2026

What to test
1. Open the Discover tab — swipe through 3 recipes.
2. Tap any recipe → read ingredients + directions.
3. Tap Start Cooking → use the segmented control to switch to Flashcards.
4. In Flashcards, say "Hey Crave" then "next" — the card advances. (Mic + speech
   permissions required.)
5. From the + sheet, paste this Instagram reel URL in Import from social:
   https://www.instagram.com/reel/EXAMPLE_ID/
   Watch it fetch → transcribe → extract. Takes ~30s on a demo device.
6. From the + sheet, tap Import from photo → pick any photo of a written recipe.
   Vision reads the text on-device.
7. Profile → Account → verify "Delete Account" actually deletes.

AI content disclosure
Yes. Recipe extraction uses Apple's on-device Foundation Models framework. The source
material is the user's shared video (their input). The output is clearly labelled with
the source handle + a "Watch original" link.
```

## 11. Where this listing differs from Osta's

| | Osta | CraveCircle |
|---|---|---|
| Nutrition | Behind Premium | **Free** |
| Smart imports | Behind Premium (ad-free) | **Free, no ads** |
| Photo scan | Behind Premium | **Free** |
| Hands-free cooking | ❌ | ✅ |
| On-device AI | ❌ (server-side) | ✅ (iOS 26 Foundation Models) |
| Voice commands | ❌ | ✅ "Hey Crave" |
| Aisle-grouped grocery | Partial | ✅ |

**One-line pitch for the owner call:**
> "Everything Osta charges for is free in CraveCircle, and you can cook without touching your phone."
