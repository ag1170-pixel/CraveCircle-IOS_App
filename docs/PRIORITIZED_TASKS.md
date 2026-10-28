# CraveCircle — Prioritized Tasks

**Vault (current):** `Projects/CraveCircle/State-of-the-App-Gaps.md` (updated 2026-09-20). Auth P0 is **done** (Homelab public `db.cravecircle.cc`). Do not treat 0.1 as open.

**Parked next (Anas picks):** A public share page · B recommender RPCs · C share-inbox missing recipes · D web grocery parity · iOS comments → Homelab API.

Ordered by **impact ÷ effort**. Owner key: **Claude** = logic/data/backend/ops · **Antigravity** =
UI/screens/web/content · **Aditya** = decisions/keys/device-testing only he can do.

> Historical: the Sep 6 line below said auth unblocks everything. That decision is made (Homelab).

---

## P0 — Unblocks everything (do first)
| # | Task | Owner | Notes |
|---|------|-------|-------|
| 0.1 | ~~Decide auth path~~ **DONE 2026-09-20** Homelab public Auth/REST | **Aditya** | `https://db.cravecircle.cc` isolated gateway. Cloud ref is legacy. |
| 0.2 | Stand up Supabase schema: `profiles(role)`, `recipes(visibility, creator_id)`, `follows`, `shares`, `user_interactions` | Claude | After 0.1. Includes the RLS policies that make followers-only un-bypassable. |
| 0.3 | ~~Real sign-in/up~~ **DONE** Homelab GoTrue + Google | Claude + Antigravity | DEBUG bypass gone. |

## P1 — Make the social promise real (needs P0)
| # | Task | Owner | Notes |
|---|------|-------|-------|
| 1.1 | ✅ `log_interactions` + `get_suggested_recipes` RPCs; `flushTelemetry`/`fetchSuggestedFeed` wired | Claude | Done (`465828e`). Cross-user recs live once signed in. |
| 1.2 | ✅ Followers-only via RLS + shares delivery + follow sync | Claude | Done (`cab7c92`). RLS enforces; shares deliver to Received; follow re-syncs to unlock. Activates on real sign-in. |
| 1.3 | ✅ Deep-link recipe route — `cravecircle://recipe/<id>` opens recipes in-app; Share/Copy emit it (was dead web URLs). App-only, no web page. | Claude | Done (`79bd31b`). Opens local copy or pulls from Supabase (RLS-gated). |
| 1.4 | ✅ Recipe cloud sync (offline-first) + showcase newly-published recipes | Claude | Done (`eb8aa44`). Seeded `@cravecircle` welcome recipe; new content pulls in. |

## P1.5 — "Shared with you" inbox (where a reel shared with me shows up)
**Plan / status.** The full round-trip is: someone shares a recipe → a `shares` row (from→to) →
the recipient's app pulls it (RLS-scoped) → it appears in their inbox with a notification.
| # | Task | Owner | Status |
|---|------|-------|--------|
| A | `shares` table + RLS (only sender/recipient can read) | Claude | ✅ Done |
| B | Deliver on share (`recordShare` → cloud) + pull (`syncShares`) into `sharedLog` | Claude | ✅ Done (`cab7c92`) |
| C | **Entry point:** Profile → **"Shared with you"** row → `SharedScreen` (Received / Sent tabs) | Claude | ✅ Done — SharedScreen had NO entry point before; now reachable |
| D | Notification on a newly received share ("Recipe shared with you") → also in Circle activity | Claude | ✅ Done |
| E | **Badge/count** on the Profile row + a bell badge when unseen shares exist | Antigravity (UI) + Claude (unseen count) | ✅ Done — `unreadSharedCount` implemented via `lastOpenedSharedScreen` timestamp |
| F | Received row for a recipe I don't have locally (esp. followers-only) — store title/thumb on the share or fetch-on-tap so it still renders + offers follow-to-unlock | Claude | ⏳ TODO — today a share only renders if the recipe is already in my library |
| G | Surface the inbox from a second place (a tray icon in Home top bar, or a tab) so it's discoverable, not only in Profile | Antigravity (UI) | ✅ Done — Envelope icon added to `HomeScreen` top bar |
| H | Real friend graph: friends must be real Supabase users for delivery (today `FriendItem` ids are local UUIDs; resolves by @handle, best-effort) | Claude | ⏳ TODO — depends on real auth + a users directory |

**Where the user sees it (today):** Profile → "Shared with you" → **Received** tab, OR the Mail icon in the Home screen top bar. Plus a "Recipe shared with you" entry in Circle activity/notifications.

## P2 — Retention & discovery (high user value)
| # | Task | Owner | Notes |
|---|------|-------|-------|
| 2.1 | ✅ **Onboarding**: welcome → pick cuisines → import first reel | Claude | Done (`de31f6b`). Cuisine picks seed the cold-start feed; reason chip reads 'Because you love Indian'. |
| 2.2 | ✅ **Ingredient / diet / time search + filters** | Claude | Done (`f195ebe`). Ingredient-aware search + veg/non-veg/vegan, time, high-protein chips. |
| 2.3 | ✅ **"Why you're seeing this"** reason chip on suggestions (Home + Search) | Claude | Done (`5237671`). Honest per-recipe reason from the engine; no chip when signal is thin. |
| 2.4 | ✅ **Cook-nudge habit loop** + foreground notification presentation | Claude | Done (`611dc84`). Save → 2-day reminder; cancelled on cook/unsave. |

## P3 — Hardening & production-readiness
| # | Task | Owner | Notes |
|---|------|-------|-------|
| 3.1 | Move import backend off the personal laptop (managed host or resilient fallback) | Claude + Aditya | Homelab laptop sleeps/reboots — not production. |
| 3.2 | ✅ Import resilience — polling timeout, friendly network errors, 20s request timeouts | Claude | Done (`32bca0c`). Stuck/hung imports fail fast with cook-friendly copy + on-device fallback. |
| 3.3 | ✅ Authoritative nutrition (USDA FoodData Central) | Claude | Done (`25364c8`). Per-ingredient USDA macros, cached, estimate fallback. Needs a free API key for real use (DEMO_KEY rate-limited). |
| 3.4 | ✅ Grocery: aisle grouping + cross-recipe dedupe | Claude | Done (`1a4e4ab`). Delivery-app integration plan in docs/archive/GROCERY_DELIVERY_PLAN.md (deferred). |
| 3.5 | Real-device validation: flashcard gestures, voice, HEIC thumbnails, on-device transcription | Aditya | Simulator can't cover these. |
| 3.6 | ✅ Unit test target (14 tests) + manual dead-code sweep (found orphaned share bug) | Claude | Done (`5cdac74`). Periphery couldn't install (no brew on PATH) — manual sweep instead. |

## Already done (this session)
- ✅ Community MVP (client) + persisted share log
- ✅ HEIC runtime thumbnails + on-device voice privacy
- ✅ On-device dwell-weighted recommender (Home + Search "Suggested for You")
- ✅ Library/Search/Home swipe scoped to the on-screen list
- ✅ Photo buffering fix, Clear cache, dead-code removal, image optimization

- ✅ Zoom-style Safari Redirect hosted on homelab for deep-link URL sharing
- ✅ Guest Mode Architecture: Unique temporary IDs, Profile Zeroing, 10-recipe Paywall limits, and Account data migration on login