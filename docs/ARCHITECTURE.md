# CraveCircle — Architecture (updated 2026-11-17)

Seven diagrams, written as [eraser.io](https://app.eraser.io) diagram-as-code. Paste each block into
its own eraser diagram of the type named in its heading.

**What was checked.** Everything about the iOS app, the Share Extension, the import backend and the
database schema was read from this repository on 2026-11-17 (`main` at `e5e30cd`). The inside of the
homelab (gateway, Supabase containers) is carried over from the previous diagram: the homelab was
unreachable while this was written, so that part was not re-checked. The Go media API, Redis and the
Android app from the older diagram are left out because the iOS app does not call them.

## The whole thing in plain words

1. **You open the app.** Recipes you already have are on the phone, so the Home screen shows up
   even with no internet. In the background the app asks the server for new community recipes.
2. **You sign in (or stay a guest).** Sign-in goes to our own server, which hands back a pass (a
   token). The phone keeps that pass in the Keychain. Guests can use everything for now; their data
   stays on the phone.
3. **You add a recipe.** Paste a reel link, share a reel from Instagram, pick a photo, paste a web
   link, or type it yourself.
   - *Paste a link in the app:* the server only downloads the video. The **phone** listens to it,
     reads the on-screen text and writes the recipe. The video is then thrown away.
   - *Share from another app:* the phone hands the link to the **server**, which does the listening
     and writing, then sends a notification when the recipe is ready.
4. **You cook.** Cook mode shows one step per card. Say "Forward", "Backward", "Start" or "Stop"
   and the phone understands it without sending audio anywhere.
5. **You like, save, follow, comment, plan meals, build a grocery list.** Each action is saved on
   the phone first, then copied to the server when you are signed in.
6. **The server decides what is allowed.** The app hides buttons, but the database is what refuses
   a request that breaks the rules (for example, only an admin can publish to everyone).

---

## 1. Big picture — for anyone (Cloud Architecture Diagram)

```
title CraveCircle — Big Picture

You [icon: user, color: gray]

Your iPhone [icon: smartphone, color: blue] {
  CraveCircle App [icon: apple, label: "CraveCircle app\nshows recipes, cook mode, grocery list"]
  Phone Brain [icon: cpu, label: "On-phone AI\nlistens to reels, reads text, hears voice commands"]
  Phone Memory [icon: hard-drive, label: "Saved on the phone\nworks with no internet"]
}

Internet Door [icon: cloudflare, color: orange, label: "Cloudflare\nthe front door to our server"]

Our Server [icon: server, color: green] {
  Accounts and Recipes [icon: database, label: "Accounts, recipes, likes,\ncomments, meal plans, photos"]
  Reel Helper [icon: download, label: "Reel helper\ndownloads a reel and can turn it into a recipe"]
}

Social Apps [icon: instagram, color: pink, label: "Instagram, TikTok, YouTube"]

You > CraveCircle App: taps and talks
CraveCircle App > Phone Brain: understand this reel or voice
CraveCircle App <> Phone Memory: save and load
CraveCircle App > Internet Door: sign in, fetch and send recipes
Internet Door > Accounts and Recipes
Internet Door > Reel Helper
Reel Helper > Social Apps: fetch the reel
Reel Helper > CraveCircle App: notification when a shared reel is ready
```

---

## 2. System architecture — technical (Cloud Architecture Diagram)

```
title CraveCircle — System Architecture

// ---------------- People ----------------
User [icon: user, color: gray]
Admin [icon: user-check, color: gray, label: "Admin (founder)"]

// ---------------- iPhone ----------------
iPhone [icon: apple, color: blue] {
  CraveCircle App [icon: smartphone, label: "CraveCircle app (SwiftUI, iOS 26)\nAppEnvironment is the single state owner"]
  Share Extension [icon: share-2, label: "Share Extension\nreceives a reel link or photo"]
  Widgets [icon: layout, label: "CookingWidget\nquick actions + import Live Activity"]

  OnDevice AI [icon: cpu, color: lightblue] {
    Speech [icon: mic, label: "Speech framework\nreel transcript, voice search, cook commands"]
    Vision OCR [icon: eye, label: "Vision\ntext in video frames and photos"]
    Foundation Models [icon: sparkles, label: "On-device LLM\nRecipeExtractor (heuristic fallback)"]
  }

  Local State [icon: hard-drive, color: lightblue] {
    LocalStore [icon: file-text, label: "LocalStore JSON files\nrecipes, grocery, meal plan, comments, unsynced ids"]
    Keychain [icon: key, label: "TokenStore (Keychain)\naccess + refresh token"]
    App Group [icon: folder, label: "App Group container\npending import, language, user id"]
  }
}

// ---------------- Edge ----------------
Cloudflare [icon: cloudflare, color: orange] {
  db.cravecircle.cc [icon: globe]
  import.cravecircle.cc [icon: globe]
}

// ---------------- Outside services ----------------
External [icon: cloud, color: gray] {
  Google Sign-In [icon: google]
  Social Sources [icon: instagram, label: "Instagram, TikTok, YouTube, Facebook"]
  Apple Push [icon: bell, label: "APNs"]
  Google Translate [icon: type, label: "Google Translate (fallback only)"]
}

// ---------------- Homelab ----------------
Homelab [icon: server, color: green, label: "Homelab (Docker)"] {
  Gateway [icon: shield, label: "API gateway\nroutes /auth /rest /storage"]

  Supabase [icon: supabase, color: green] {
    GoTrue Auth [icon: lock, label: "Auth (GoTrue)\nissues JWT"]
    PostgREST [icon: table, label: "REST (PostgREST)\ncravecircle schema only"]
    Storage [icon: image, label: "Storage\nbucket recipe-thumbnails"]
    Postgres [icon: postgresql, label: "Postgres\nRLS policies + triggers"]
  }

  Import Backend [icon: python, color: teal, label: "whisper-transcriber (FastAPI, port 8009)"] {
    Downloader [icon: download, label: "yt-dlp"]
    Media Tools [icon: film, label: "ffmpeg cover frame + tesseract OCR"]
    Whisper [icon: mic, label: "faster-whisper small"]
    Recipe Assembler [icon: list, label: "assemble_recipe + nutrition (offline USDA table)"]
    Translator [icon: type, label: "Ollama LLM translate"]
    SQLite [icon: file, label: "SQLite\nimported recipes, devices, feedback"]
    Job Table [icon: box, label: "JOBS dict (in memory)"]
  }
}

// ---------------- People ----------------
User > CraveCircle App: uses
User > Share Extension: shares a reel
Admin > CraveCircle App: publishes, moderates

// ---------------- Inside the phone ----------------
CraveCircle App > OnDevice AI: transcribe, OCR, extract
CraveCircle App <> LocalStore: load and persist
CraveCircle App <> Keychain: tokens
Share Extension > App Group: hand over link or photo
CraveCircle App > App Group: read pending import
Widgets > CraveCircle App: cravecircle:// deep links

// ---------------- Auth and data ----------------
CraveCircle App > Google Sign-In: PKCE, returns id_token
CraveCircle App > db.cravecircle.cc: auth/v1, rest/v1, storage/v1 (HTTPS)
db.cravecircle.cc > Gateway
Gateway > GoTrue Auth: /auth/v1
Gateway > PostgREST: /rest/v1
Gateway > Storage: /storage/v1
GoTrue Auth > Postgres: auth.users + new-user trigger
PostgREST > Postgres: SQL under RLS
Storage > Postgres: object metadata

// ---------------- Import ----------------
CraveCircle App > import.cravecircle.cc: /reels/download, /translate-text, /recipes, /devices
Share Extension > import.cravecircle.cc: POST /reels/import
import.cravecircle.cc > Import Backend
Downloader > Social Sources: fetch video + caption
Translator > Google Translate: only if the LLM fails
Import Backend > Apple Push: recipe ready
Apple Push > CraveCircle App: notification
```

---

## 3. Frontend — inside the iOS app (Cloud Architecture Diagram)

```
title CraveCircle — Inside the iOS App

Entry [icon: play, color: gray] {
  AICookBookApp [icon: apple, label: "AICookBookApp\nlifecycle, deep links, push"]
  RootView [icon: layout, label: "RootView\ntabs, sign-in, add-recipe sheet"]
}

Screens [icon: smartphone, color: blue, label: "Features (one folder per screen)"] {
  Home [icon: home, label: "Home\nFresh, Suggested, Community (10 at a time)"]
  Discover [icon: compass]
  Recipe Detail [icon: book-open, label: "Recipe Detail\nIngredients / Directions (swipe)"]
  Cook Mode [icon: flame, label: "Cook Mode flashcards\ntimer + voice"]
  Grocery [icon: shopping-cart]
  Meal Plan [icon: calendar]
  Add Recipe [icon: plus-circle, label: "Add Recipe\nreel, web, photo, scratch, Studio"]
  Profile [icon: user, label: "Profile + admin tools"]
}

State [icon: box, color: purple] {
  AppEnvironment [icon: cpu, label: "AppEnvironment (@Observable)\nthe one place that owns app data and rules"]
}

Services [icon: tool, color: teal] {
  Networking [icon: globe, label: "APIClient, SupabaseAuthClient, SupabaseData"]
  Recipe Import [icon: download, label: "OnDeviceTranscriber, VideoTextOCR,\nPhotoTextOCR, WebRecipe, RecipeExtractor"]
  Recipes Logic [icon: sliders, label: "IngredientScaler, RecipeSearch,\nRecommendationEngine"]
  Voice [icon: mic, label: "VoiceCommandController, VoiceSearchController,\nSpeechReader"]
  Storage [icon: hard-drive, label: "LocalStore (JSON files per user)"]
  Auth [icon: key, label: "GoogleAuthSession, TokenStore"]
  Notifications [icon: bell, label: "DailyNudgeScheduler"]
}

Design System [icon: palette, color: orange, label: "DesignSystem\ncolours, type, spacing, shared components"]
Models [icon: file-text, color: gray, label: "Models\nRecipe, Nutrition, UserProfile, PlannedMeal"]

AICookBookApp > RootView
AICookBookApp > AppEnvironment: creates once
RootView > Screens: shows
Screens > AppEnvironment: read state, call actions
Screens > Design System: look and feel
AppEnvironment > Services: does the work
AppEnvironment > Models
Networking > Models: decode
Recipe Import > Models: build Recipe
```

---

## 4. Backend — the homelab (Cloud Architecture Diagram)

```
title CraveCircle — Backend

Phone [icon: smartphone, color: blue, label: "App + Share Extension"]

Cloudflare [icon: cloudflare, color: orange] {
  db.cravecircle.cc [icon: globe]
  import.cravecircle.cc [icon: globe]
}

Data Side [icon: database, color: green, label: "Supabase (self-hosted)"] {
  Gateway [icon: shield, label: "API gateway"]
  Auth [icon: lock, label: "GoTrue\nemail+password, Google id_token"]
  REST [icon: table, label: "PostgREST\nonly the cravecircle schema is exposed"]
  Storage [icon: image, label: "Storage\nrecipe-thumbnails (public read)"]

  Postgres [icon: postgresql, label: "Postgres — schema cravecircle"] {
    Tables [icon: table, label: "profiles, recipes, recipe_likes, recipe_saves,\nfollows, friendships, shares, comments, meal_plan,\nreports, creator_requests, search_requests,\nuser_interactions, admin_alerts"]
    Rules [icon: shield, label: "RLS policies + triggers\nenforce_role_change, enforce_no_publish_imports,\nenforce_verified_admin_only, enforce_disabled_admin_only,\ncomments_block_abuse, cleanup on recipe delete"]
    Functions [icon: code, label: "RPC functions\nget_suggested_recipes, log_interactions,\nnote_search_miss, admin_signals, delete_me,\ndecide_creator_request, admin_delete_user"]
  }
}

Import Side [icon: python, color: teal, label: "whisper-transcriber (FastAPI)"] {
  API [icon: server, label: "Endpoints\n/reels/download, /reels/media, /reels/import,\n/reels/import/{job}, /translate-text, /recipes,\n/devices, /feedback, /health, /recipe/{id} web page"]
  Worker [icon: cpu, label: "Import job\ndownloading > transcribing > extracting > done"]
  Tools [icon: tool, label: "yt-dlp, ffmpeg, tesseract,\nfaster-whisper small"]
  LLM [icon: sparkles, label: "Ollama (translation)"]
  Store [icon: file, label: "SQLite: recipes, devices, feedback\nJOBS: in memory only"]
}

Outside [icon: cloud, color: gray] {
  Social [icon: instagram, label: "Instagram, TikTok, YouTube"]
  APNs [icon: bell]
}

Phone > db.cravecircle.cc: auth, data, photos
Phone > import.cravecircle.cc: imports, translate
db.cravecircle.cc > Gateway
Gateway > Auth
Gateway > REST
Gateway > Storage
Auth > Postgres
REST > Postgres
import.cravecircle.cc > API
API > Worker: start job
Worker > Tools
Tools > Social: download
Worker > LLM: translate
Worker > Store: save recipe
Worker > APNs: recipe ready
```

---

## 5. User journey (Flowchart)

```
title CraveCircle — What a User Does

Open [shape: oval, label: "Open the app"]
First [shape: diamond, label: "First time?"]
Onboard [label: "Onboarding\npick cuisines and goals"]
Choose [shape: diamond, label: "Sign in or guest?"]
SignIn [label: "Google or email + password"]
Guest [label: "Continue as guest\n(everything unlocked for now, data stays on phone)"]
Home [label: "Home\nFresh in your Circle, Suggested, Community"]
What [shape: diamond, label: "What next?"]
Browse [label: "Open a recipe\nIngredients / Directions"]
Add [label: "Tap + to add a recipe"]
How [shape: diamond, label: "From where?"]
Reel [label: "Paste a reel link\nphone writes the recipe"]
Share [label: "Share from Instagram\nserver writes it, notification arrives"]
Other [label: "Web link, photo,\nor write from scratch"]
Saved [label: "Recipe is in your library"]
Cook [label: "Start Cooking\none step per card"]
Voice [label: "Say Forward, Backward,\nStart or Stop"]
Plan [label: "Add to Meal Plan"]
Grocery [label: "Add to Grocery List\nsame item across recipes merges"]
Social [label: "Like, save, follow,\ncomment, share"]
Done [shape: oval, label: "Dinner"]

Open > First
First > Onboard: yes
First > Choose: no
Onboard > Choose
Choose > SignIn: sign in
Choose > Guest: guest
SignIn > Home
Guest > Home
Home > What
What > Browse: browse
What > Add: add
Add > How
How > Reel
How > Share
How > Other
Reel > Saved
Share > Saved
Other > Saved
Saved > Browse
Browse > Cook
Browse > Plan
Browse > Grocery
Browse > Social
Cook > Voice
Voice > Done
Plan > Grocery
Grocery > Done
```

---

## 6. Reel import — in-app vs share (Sequence Diagram)

```
title Reel Import — In-App (phone does the work) vs Share (server does the work)

User [icon: user]
App [icon: smartphone, label: "CraveCircle App"]
OnDevice [icon: cpu, label: "On-device AI"]
ShareExt [icon: share-2, label: "Share Extension"]
Backend [icon: python, label: "Import Backend"]
Social [icon: instagram, label: "Instagram / TikTok / YouTube"]
Supabase [icon: database]
APNs [icon: bell]

// ---- In-app: paste a link ----
User > App: paste reel link
App > Backend: POST /reels/download
Backend > Social: yt-dlp fetch video, caption, poster
Backend > Backend: ffmpeg cover frame
Backend > App: media id, caption, title, cover
App > Backend: GET /reels/media/{file}
App > OnDevice: transcribe the audio
App > OnDevice: OCR the frames when there is little speech
App > OnDevice: RecipeExtractor (LLM, else heuristic)
OnDevice > App: title, ingredients, steps
App > App: not food? stop and say so
App > Backend: POST /translate-text (only if language differs)
App > App: save to LocalStore, mark unsynced
App > Supabase: push only if signed in and allowed to publish
App > User: recipe in library

// ---- Share: from another app ----
User > ShareExt: share reel to CraveCircle
ShareExt > Backend: POST /reels/import (url, language, user id)
Backend > ShareExt: job id
ShareExt > User: "Importing, we will notify you"
Backend > Social: yt-dlp fetch
Backend > Backend: faster-whisper transcript
Backend > Backend: tesseract OCR on frames
Backend > Backend: assemble recipe + nutrition, translate
Backend > Backend: save recipe in SQLite
Backend > APNs: recipe ready
APNs > App: notification
App > Backend: GET /reels/import/{job} and /recipes
Backend > App: the new recipe
App > User: recipe in library
```

---

## 7. Auth + cloud data (Sequence Diagram)

```
title Auth + Cloud Data

User [icon: user]
App [icon: smartphone, label: "CraveCircle App"]
Keychain [icon: key]
Google [icon: google]
Edge [icon: cloudflare, label: "db.cravecircle.cc"]
Auth [icon: lock, label: "GoTrue"]
REST [icon: table, label: "PostgREST"]
DB [icon: postgresql, label: "Postgres (cravecircle)"]

// ---- Guest ----
User > App: Continue as guest
App > App: local profile only, nothing sent

// ---- Sign in ----
User > App: Continue with Google
App > Google: PKCE authorize
Google > App: id_token
App > Edge: POST auth/v1/token (grant_type id_token)
Edge > Auth: exchange
Auth > DB: find or create auth.users (trigger creates the profile row)
Auth > App: access token + refresh token
App > Keychain: store both

// ---- Email ----
User > App: email + password
App > Edge: POST auth/v1/token (password) or auth/v1/signup
Auth > App: session, or "confirm your email first"

// ---- Reading and writing ----
App > Edge: GET rest/v1/profiles (my row)
Edge > REST: Accept-Profile cravecircle
REST > DB: SELECT under RLS
DB > App: name, username, role
App > Edge: likes, saves, follows, comments, meal plan, shares
REST > DB: INSERT or DELETE, RLS checks the row is mine
App > Edge: rpc/get_suggested_recipes, rpc/log_interactions
App > Edge: upsert recipes (only when the role may publish)
DB > DB: trigger rejects a public import from a non-admin

// ---- Token expiry ----
App > Edge: any request with an expired token
Edge > App: 401
App > Edge: POST auth/v1/token (refresh_token)
Auth > App: new tokens
App > Keychain: replace
App > Edge: retry once
```

---

## Known weak spots (checked in code today)

| Where | What | Why it matters |
|---|---|---|
| `whisper-transcriber/app/main.py` `_run_ytdlp` | `subprocess.run` for yt-dlp has no timeout (ffmpeg and tesseract calls do) | One stuck download holds a worker forever |
| `whisper-transcriber/app/main.py` `JOBS` | Import job status lives in a Python dict | A backend restart loses every in-flight job; the app polls a job id that no longer exists |
| `AICookBook/Models/Nutrition.swift` | `"cup": 200` grams for every ingredient | A cup of flour and a cup of honey get the same weight, so calories drift |
| `AppEnvironment.guestRestrictionsEnabled` | Off for now | Guests can do everything locally. Nothing reaches the server without a session, and the database still refuses non-admin publishing. Turn back on before release. |
