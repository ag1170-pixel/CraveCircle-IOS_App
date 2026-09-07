# CraveCircle — Prioritized Tasks

Ordered by **impact ÷ effort**. Owner key: **Claude** = logic/data/backend/ops · **Antigravity** =
UI/screens/web/content · **Aditya** = decisions/keys/device-testing only he can do. Full reasoning
in the vault: `State-of-the-App-Gaps.md`.

> The single highest-leverage decision is **auth** — it unblocks P0–P2 below at once.

---

## P0 — Unblocks everything (do first)
| # | Task | Owner | Notes |
|---|------|-------|-------|
| 0.1 | **Decide auth path: A) new cloud Supabase, or B) expose Homelab Supabase publicly** | **Aditya** | Blocks sharing, community, cross-user recs, cross-device. Nothing real ships without this. |
| 0.2 | Stand up Supabase schema: `profiles(role)`, `recipes(visibility, creator_id)`, `follows`, `shares`, `user_interactions` | Claude | After 0.1. Includes the RLS policies that make followers-only un-bypassable. |
| 0.3 | Real sign-in/up wired to the chosen Supabase; remove the DEBUG dev-bypass | Claude + Antigravity | Claude: auth client + token store. Antigravity: auth screen polish. |

## P1 — Make the social promise real (needs P0)
| # | Task | Owner | Notes |
|---|------|-------|-------|
| 1.1 | `log_interactions` + `get_suggested_recipes` RPCs; point `flushTelemetry`/`fetchSuggestedFeed` at them | Claude | Turns per-device recs into cross-user ("people like you cooked…"). Hooks already left in `AppEnvironment`. |
| 1.2 | Followers-only enforcement via RLS; deliver cross-user shares → **Received tab works** | Claude | Phase 2 of `COMMUNITY_PLAN.md`. |
| 1.3 | **Public recipe web page** `cravecircle.cc/r/<id>` (Open Graph preview + install nudge) so "share outside the app" resolves | Antigravity (web) + Claude (data/RLS) | Fixes the broken share link. |

## P2 — Retention & discovery (high user value)
| # | Task | Owner | Notes |
|---|------|-------|-------|
| 2.1 | **Onboarding**: import first reel + pick 2–3 cuisines so the feed is personal on day one | Antigravity (flow) + Claude (seed logic) | Kills the "full of recipes I didn't add" feeling. |
| 2.2 | **Ingredient / diet / time search + filters** (not just title/creator substring) | Claude (query) + Antigravity (filter UI) | Trending chips already imply this. |
| 2.3 | **"Why you're seeing this"** reason chip on each suggestion (e.g. "Because you cooked Paneer Tikka") | Claude (reason from engine) + Antigravity (chip) | Builds trust; engine already has the signal. |
| 2.4 | **Cook-nudge habit loop**: "You saved this 3 days ago — cook it tonight?" local notification | Claude | Uses existing telemetry + `UNUserNotificationCenter`. |

## P3 — Hardening & production-readiness
| # | Task | Owner | Notes |
|---|------|-------|-------|
| 3.1 | Move import backend off the personal laptop (managed host or resilient fallback) | Claude + Aditya | Homelab laptop sleeps/reboots — not production. |
| 3.2 | Graceful offline/error messaging on every network path (homelab asleep, no signal) | Claude + Antigravity | Some empty states done; audit the rest. |
| 3.3 | Authoritative nutrition (USDA FDC) computed server-side when ingredients are known | Claude | Replaces on-device estimate where possible. |
| 3.4 | Grocery: aisle grouping + cross-recipe dedupe | Claude (logic) + Antigravity (UI) | |
| 3.5 | Real-device validation: flashcard gestures, voice, HEIC thumbnails, on-device transcription | Aditya | Simulator can't cover these. |
| 3.6 | Run Periphery; add basic unit tests (scaler, nutrition, recommender scoring) | Claude | Dead-code sweep + safety net. |

## Already done (this session)
- ✅ Community MVP (client) + persisted share log
- ✅ HEIC runtime thumbnails + on-device voice privacy
- ✅ On-device dwell-weighted recommender (Home + Search "Suggested for You")
- ✅ Library/Search/Home swipe scoped to the on-screen list
- ✅ Photo buffering fix, Clear cache, dead-code removal, image optimization
