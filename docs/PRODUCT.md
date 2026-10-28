# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

Native SwiftUI (iOS 17+), MVVM + async/await, `@Observable` / `ObservableObject` view models, actor-based `APIClient` over `URLSession`. No UIKit except where a system API requires it. No third-party UI or networking libraries. Auth/session tokens in Keychain. Backend: Go `go-api` (Chi) at `api.cravecircle.cc`; Supabase for auth/DB. (Recorded from the existing codebase, not chosen at init.)

## Users

- **Consumer (primary):** home cooks who find recipes as short cooking videos (Instagram Reels / TikTok / YouTube Shorts) and want to actually cook from them — browse, save, organize, cook with a checklist, build grocery lists, and share with friends.
- **Creator / Studio:** food creators who publish and manage their own recipes from the app.
- Not in iOS scope: the dev/`admin` persona (web-only).

## Product Purpose

Turn cooking videos into structured, cookable recipes — and a social "living cookbook" people build together. Saving a reel saves a *video*, not a recipe (no ingredient list, no measurements, no readable steps). CraveCircle extracts the real recipe and wraps it in a cook-mode checklist, grocery lists, collections, and a friend/creator social graph. Success = a saved video becomes a recipe the user actually cooks from, and comes back to.

## Positioning

Extraction is table stakes; the **social living-cookbook layer** (collections, friends, creator Studio, grocery, comments) is the differentiator competitors (Pestle, Deglaze, Pluck, Peel, etc.) haven't built — they stop at a private recipe card. The recipe is the hook; the network is the product.

## Operating Context

- Used on a phone, often **in the kitchen mid-cook** — possibly wet/greasy hands, glanceable at arm's length. Cook mode needs large tap targets (min ~56pt rows) and readable-at-distance type.
- Recipe discovery happens by pasting a social video URL; the recipe is produced server-side (async job the app polls: queued → downloading → transcribing → extracting → done).
- Media (thumbnails/reels) served from the go-api media-store via signed/public URLs.

## Capabilities and Constraints

- **Reel import (LIVE, intended):** caption-first + Voiceprint-style audio transcription. Deterministically pull caption, thumbnail, and metadata; for anything the caption doesn't cover, take the reel **audio and transcribe it in ~60-second chunks** (the Voiceprint method — Whisper-only, 60s clips; see vault [[Projects/Voiceprint/Canon]]), then merge chunks into the recipe. Merge, never overwrite; caption is source of truth. Strip engagement CTAs from directions; never persist `amount: 0` for "to taste".
- Core flows: browse recipe grid (paginated) · recipe detail (Ingredients | Directions tabs) · cook-mode checklist · grocery list (optimistic toggles) · collections · friends feed + requests · creator publishing (Studio) · profile/auth.
- Auth via Supabase (email/password + Google OAuth); tokens in Keychain; 401 → refresh → retry.
- ⚠️ **Known infra break (2026-08):** the cloud Supabase project `vaxuvotnzufwxcvsktke` was deleted; auth is currently down until a public Supabase endpoint is restored (see [[Projects/CraveCircle/CraveCircle]]). Product-level auth design is unchanged; this is an ops issue.
- Constraints (binding): iOS 17+, SwiftUI only, no third-party design libraries, Keychain-only tokens, no service-role key in app, **no emoji in UI**, async job polling (no synchronous import wait).

## Brand Commitments

- **Name:** the product brand is **CraveCircle**; the iOS codebase/bundle is still `AICookBook` (`com.anassyed.AICookBook`) and the name may still appear transitionally — brand lag, not a second product. User confirmed "both / transitional".
- **Accent color:** brand lime-green `#D4F73F` (the "LET'S COOK" button) as the single accent; everything else neutral. Binding brand asset.
- Tagline energy: "Your living cookbook" / collect every flavor.
- Note: the original master prompt specifies a **dark-first** design; the current `DesignSystem.swift` ships a **light** theme — this is an open visual conflict for DESIGN.md/new-work to resolve, not a product fact.

## Evidence on Hand

- Working iOS codebase (`AICookBook/`) — auth, recipe grid, recipe detail, import polling state machine, grocery list, profile. Kitchen/checklist, collections, and social are partial/placeholder.
- Master spec: `docs/archive/AICookbook_iOS_Master_Prompt.md` (in repo).
- Market/demand validation compiled: vault [[Projects/CraveCircle/Market-Research]] + showcase artifact.
- Do NOT fabricate: user counts, testimonials, download numbers, or press — none confirmed.

## Product Principles

1. **The food leads, the UI recedes** — photo-dominant, flat, typographic; chrome stays quiet.
2. **From screen to stove to cart** — every recipe is built to be cooked from (checklist) and shopped for (grocery), not just saved.
3. **Caption-first, audio-fills-the-gaps** — deterministic parse first; transcription (chunked audio) only fills what the caption omits; never invent ingredients.
4. **The circle is the moat** — social/collections/creator features are first-class, not afterthoughts.
5. **Kitchen-real ergonomics** — large tap targets, glanceable, forgiving of wet hands and divided attention.

## Accessibility & Inclusion

Minimum 44×44pt tap targets everywhere (56pt in cook mode); accessibility labels on all interactive elements and recipe imagery; checklist state exposed via accessibility value; respect Dynamic Type and reduced-motion. (From master spec; treat as required.)
