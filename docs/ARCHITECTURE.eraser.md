# CraveCircle — Architecture (eraser.io diagram-as-code)

Paste each fenced block into a new diagram at https://app.eraser.io (Diagram-as-code).
Everything below reflects the **current** implementation (branch `gowtham/sergantswagg-device`).

---

## 1) System Architecture  (eraser "cloud architecture" diagram)

```eraser
title CraveCircle — System Architecture

// ============ Actors ============
User [icon: user, color: gray]
Creator [icon: user-check, color: gray]

// ============ iPhone (client) ============
iPhone [icon: apple, color: blue] {
  CraveCircle App [icon: smartphone, color: blue]
  Share Extension [icon: share-2, color: blue]

  OnDevice AI [icon: cpu, color: lightblue] {
    Speech Neural Engine [icon: mic]
    Vision OCR [icon: eye]
    Foundation Models LLM [icon: sparkles]
    AVFoundation Frame [icon: film]
  }

  Local State [icon: hard-drive, color: lightblue] {
    LocalStore JSON [icon: file-text]
    Token Store JWT [icon: key]
    Cached Covers [icon: image]
  }
}

// ============ Edge (Cloudflare) ============
Cloudflare Edge [icon: cloudflare, color: orange] {
  Named Tunnel crave_circle_backend [icon: git-branch]
  db.cravecircle.cc [icon: globe]
  import.cravecircle.cc [icon: globe]
}

// ============ External services ============
External [icon: cloud, color: gray] {
  Google Sign-In [icon: google]
  Google Translate [icon: type]
  Instagram YouTube [icon: instagram]
}

// ============ Homelab (Docker, GTX 1650) ============
Homelab [icon: server, color: green] {
  Connector crave-circle-tunnel [icon: link]

  CraveCircle Gateway [icon: shield, color: teal] {
    Caddy Reverse Proxy [icon: git-merge]
    cravecircle-rest PostgREST [icon: table]
  }

  Shared Supabase [icon: database, color: green] {
    GoTrue Auth [icon: lock]
    Postgres [icon: postgresql]
  }

  Whisper Backend FastAPI [icon: python, color: green] {
    yt-dlp Downloader [icon: download]
    ffmpeg Thumbnailer [icon: film]
    faster-whisper small [icon: mic]
    deep-translator [icon: type]
    In-memory Recipes [icon: box]
    Feedback SQLite [icon: file]
  }
}

// ============ Connections ============
User > CraveCircle App: uses
Creator > CraveCircle App: publishes
User > Share Extension: share reel

// ---- Auth ----
CraveCircle App > Google Sign-In: PKCE (accounts.google.com)
Google Sign-In > CraveCircle App: id_token
CraveCircle App > db.cravecircle.cc: auth/v1 (id_token grant OR email+password)
CraveCircle App > db.cravecircle.cc: rest/v1 profiles/recipes/follows/shares
db.cravecircle.cc > Named Tunnel crave_circle_backend
Named Tunnel crave_circle_backend > Connector crave-circle-tunnel
Connector crave-circle-tunnel > Caddy Reverse Proxy
Caddy Reverse Proxy > cravecircle-rest PostgREST: /rest/v1/*
Caddy Reverse Proxy > GoTrue Auth: /auth/v1/*
cravecircle-rest PostgREST > Postgres: SQL (RLS, cravecircle schema only)
GoTrue Auth > Postgres: auth.users + profile trigger

// ---- In-app import (on-device transcription) ----
CraveCircle App > import.cravecircle.cc: POST /reels/download
import.cravecircle.cc > Connector crave-circle-tunnel
Connector crave-circle-tunnel > Whisper Backend FastAPI
yt-dlp Downloader > Instagram YouTube: fetch mp4 + caption
Whisper Backend FastAPI > CraveCircle App: mp4 url + caption + server cover
CraveCircle App > OnDevice AI: transcribe + OCR + extract recipe
CraveCircle App > import.cravecircle.cc: POST /translate-text
deep-translator > Google Translate: translate to user language
CraveCircle App > Local State: save recipe + cover

// ---- Share import (server-side transcription) ----
Share Extension > import.cravecircle.cc: POST /reels/import
Whisper Backend FastAPI > Instagram YouTube: yt-dlp
faster-whisper small > deep-translator: transcript to recipe

// ---- Data sync ----
CraveCircle App > db.cravecircle.cc: syncRecipes pull/push
```

---

## 2) Reel Import — Sequence  (eraser "sequence" diagram)

```eraser
title Reel Import — In-App (on-device) vs Share (server-side)

// In-app path: fast, on-device transcription
User > CraveCircle App: paste reel link
CraveCircle App > Whisper Backend: POST /reels/download {url}
Whisper Backend > Instagram: yt-dlp fetch (mp4 VP9 + caption + poster)
Whisper Backend > Whisper Backend: ffmpeg extract cover frame (VP9-safe)
Whisper Backend > CraveCircle App: {media_id, caption, title, thumbnail, download_url}
CraveCircle App > Whisper Backend: GET /reels/media/{id}.mp4
CraveCircle App > OnDevice AI: transcribe audio (Neural Engine)
OnDevice AI > CraveCircle App: transcript
CraveCircle App > OnDevice AI: Vision OCR (if little narration)
CraveCircle App > OnDevice AI: RecipeExtractor (LLM or heuristic)
OnDevice AI > CraveCircle App: structured recipe (title, ingredients, steps)
CraveCircle App > CraveCircle App: cover priority 1 AVFoundation frame (H.264)
CraveCircle App > CraveCircle App: cover priority 2 download server ffmpeg frame (VP9)
CraveCircle App > Whisper Backend: POST /translate-text {texts, target_language}
Whisper Backend > Google Translate: translate (deep-translator, one batch)
Whisper Backend > CraveCircle App: translated texts
CraveCircle App > Supabase: syncRecipes (push if owner, RLS)
CraveCircle App > User: recipe in library (View Recipe)

// Share path: works with no App Group, server does the work
User > Share Extension: share reel to CraveCircle
Share Extension > Whisper Backend: POST /reels/import {url, target_language}
Whisper Backend > Instagram: yt-dlp fetch
Whisper Backend > faster-whisper: transcribe (small, CPU)
Whisper Backend > Google Translate: deep-translator to user language
Whisper Backend > Share Extension: job accepted
CraveCircle App > Whisper Backend: refreshRecipes on next open
Whisper Backend > CraveCircle App: new recipe appears in library
```

---

## 3) Auth & Data — Sequence  (eraser "sequence" diagram)

```eraser
title Auth + Cloud Data (homelab cravecircle schema over public HTTPS)

User > CraveCircle App: Continue with Google / email+password
CraveCircle App > Google: PKCE authorize (accounts.google.com)
Google > CraveCircle App: id_token
CraveCircle App > Cloudflare: POST db.cravecircle.cc/auth/v1/token (grant_type=id_token)
Cloudflare > Caddy Gateway: route /auth/v1
Caddy Gateway > GoTrue: token exchange
GoTrue > Postgres: find/create auth.users (+ trigger makes cravecircle.profiles)
GoTrue > CraveCircle App: access_token (JWT, sub=uid)
CraveCircle App > Cloudflare: GET db.cravecircle.cc/rest/v1/profiles?id=eq.uid
Cloudflare > Caddy Gateway: route /rest/v1
Caddy Gateway > cravecircle-rest: PostgREST (Accept-Profile cravecircle)
cravecircle-rest > Postgres: SELECT under RLS (only cravecircle schema exposed)
Postgres > CraveCircle App: profile row (name, username, role)
CraveCircle App > Cloudflare: rest/v1 recipes/follows/shares (RLS-scoped)
```

---

## Notes for readers
- **Two import pipelines on purpose:** in-app = on-device transcription (fast, uses the iPhone Neural Engine); share-extension = server-side Whisper (works with no App Group). **Both translate** into the user's language.
- **Thumbnail is codec-safe:** IG serves VP9 which iOS can't frame-grab, so the server extracts the cover with ffmpeg; the app tries its own frame first (H.264) and falls back to the server frame, then the reel poster.
- **Security boundary:** the public `db.cravecircle.cc` reaches ONLY the `cravecircle` schema (isolated `cravecircle-rest`); the shared Supabase Kong (8 schemas) stays private. Client ships the **anon** key only (RLS-enforced); service_role is never in the app.
- **Homelab dependency:** login + imports need the homelab up and reachable via the Cloudflare tunnel. Model is `faster-whisper small` on CPU (GPU shared with Voiceprint).
</content>
