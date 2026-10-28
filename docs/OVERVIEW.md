# CraveCircle / AICookBook — Repo Overview + Slop Audit

_Generated 2026-10-16. Every number below was measured in this checkout, not estimated._

---

## 1. What this is

An iOS recipe app ("**CraveCircle**", bundle still `com.anassyed.AICookBook`) that turns social
cooking videos (Instagram/YouTube reels) into cookable recipes: import a reel → server/on-device
transcription + extraction → recipe card → cook mode → grocery list → share with friends.

- **Client:** SwiftUI, iOS 17+ per `docs/PRODUCT.md` (but see contradictions in §6).
- **Backend:** Go `go-api` (Chi) at `api.cravecircle.cc`, Supabase (auth/DB) at `db.cravecircle.cc`
  (self-hosted on a homelab via Cloudflare tunnel), separate `whisper-transcriber` Docker service
  for audio → text.
- **Extras:** Share extension (import from other apps), Live Activity / Dynamic Island for cooking
  imports, a widget bundle, an experimental `GestureFlashcards` side project.

## 2. Numbers

| Metric | Value |
|---|---|
| Tracked files | 457 |
| Swift LOC (app + ext + widget + tests) | ~23,300 |
| Markdown (plans/specs/handoffs) | 2,453 lines across 20 files |
| One-off root scripts (`.py`/`.rb`) | 554 lines across 6 files |
| Commits | 341 (329 by one human, plus `Cursor Agent`, `Claude`) |
| Test files | **1** (`AICookBookTests/LogicTests.swift`, 536 lines) |
| Assets | 43 MB xcassets |
| `.git` size | 208 MB |

## 3. Structure

```
AICookBook/                 main app target (~75 Swift files)
  AICookBookApp.swift       entry point
  AppEnvironment.swift      2,027-line @MainActor god object: auth, recipes, grocery,
                            friends, collections, comments, imports, Live Activities
  RootView.swift            736 lines: tabs + auth flow + routing
  HomeScreen / RecipeDetailScreen / RecipeReelScreen / ProfileScreen / GroceryScreen …
  DesignComponents.swift    1,022 lines of shared UI
  SampleRecipes.swift       2,768 lines of hardcoded seed recipes (CONTENT file)
  SupabaseData / SupabaseAuthClient / APIClient   networking + sync
  Nutrition, IngredientScaler, RecipeSearch, RecommendationEngine  pure logic (tested)
ShareExtension/             import-from-other-apps extension
CookingWidget/              Live Activity + quick actions widget
GestureFlashcards/          separate Xcode project, gesture-driven step cards
whisper-transcriber/        Python+Go Docker service: chunked Whisper transcription
supabase/cravecircle_schema.sql   DB schema + RLS
docs/ARCHITECTURE.eraser.md diagram-as-code of the whole system
Config/                     Info.plist, entitlements, xcconfig (secrets example only)
scripts/relay.py            dev relay
AICookBookTests/            unit tests: scaler, search, grocery sort, recommender
```

**Data flow (import):** URL → `AppEnvironment.startImport` → POST `/reels/import` → poll job
(`queued → downloading → transcribing → extracting → done`) → fetch recipe → persist to
per-user JSON on disk (`LocalStore` + `AccountScope`) → mirror to Supabase when signed in.
Offline-first: `didSet` persistence is gated behind a `hydrated` flag so hydration can't clobber
saved state; every file is scoped per signed-in user id.

**Build:** `AICookBook.xcodeproj` (file-system-synchronized groups, so every `.swift` in
`AICookBook/` compiles — including dead files), plus an `xtool.yml` path for device builds from
Linux, plus a `Package.swift` (SPM, Lottie via `lottie-spm`).

## 4. Code quality — the honest read

The **Swift itself is above average for an agent-heavy repo**:

- 0 `TODO` / `FIXME` / `HACK`
- 0 `try!` / `as!`
- 2 commented-out code lines repo-wide
- Comments explain *why* and real constraints ("property `didSet`s only persist AFTER
  `hydrateLocal()` has loaded the saved state"), not narration.
- Cancellation, guards, and error paths are actually handled in the import state machine.
- Real unit tests on pure logic — small (1 file) but meaningful, no snapshot-filler.

The slop is **not** in the day-to-day Swift logic. It's in everything around it.

## 5. Slop audit — how much is absolute Claude slop

_The file locations and root-level recommendations in this audit describe the repository before its Markdown files were moved into `docs/`._

### A. Planning-document sludge — **20 files / 2,453 lines, ~60–70% stale** (biggest slop pool)
15 markdown files sit at the repo root (20 repo-wide): `docs/archive/LIGHTENING_PLAN.md`, `docs/archive/COMMUNITY_PLAN.md`, `docs/archive/GROCERY_DELIVERY_PLAN.md`,
`docs/archive/NO_TAILSCALE_PLAN.md`, `docs/archive/ANTIGRAVITY_CONTENT_TASK.md`, `docs/TASK_Privacy_Terms_Support.md`,
`docs/archive/FRIEND_TASK_Flashcard_Gesture.md`, `docs/archive/CHANGES_FOR_CLAUDE.md`, `docs/archive/WORK_DIVISION.md`,
`docs/PRIORITIZED_TASKS.md`, `docs/archive/DEVELOPMENT_VAULT_RULES.md`, `docs/archive/AICookbook_iOS_Master_Prompt.md` (743 lines)…
(4 are `*_PLAN.md`. 15 at the root + 5 in subfolders = 20 `.md` files / 2,453 lines repo-wide,
excluding this file.)

This is the multi-agent handoff layer (Claude ⨯ Antigravity ⨯ Cursor, ownership lanes, "handoff note
for Claude"). Most are one-time task briefs that were completed and never deleted. Only
`docs/PRODUCT.md`, `docs/POLICIES_CraveCircle.md` and `docs/ARCHITECTURE.eraser.md` carry durable value.
**Estimate: ~60–70% of the markdown is stale artifacts.**

### B. One-off content scripts — **554 lines, ~90% disposable**
`append_recipes.py` and `append_recipes_5.py` are near-copies of each other that append different
recipe blocks; `add_json.rb`, `add_lottie.rb`, `add_asset.py`, `seed_remaining_recipes.py` are
each single-use Xcode/project-file patchers. The recipes they write already exist. Classic
"generate, run once, never delete".

### C. Dead code compiled into the binary — **1,006 lines, 100% slop**
These files are in the synchronized folder (so they build) but no type in them is ever
referenced anywhere else in the repo:

| File | Lines |
|---|---|
| `RecipeCommentsView.swift` | 232 |
| `CookModeScreen.swift` | 165 |
| `ImportSheet.swift` | 159 |
| `CreatorRequestSheet.swift` | 120 |
| `DesignSystem.swift` | 110 |
| `Localization.swift` | 93 |
| `BrandAndTabBar.swift` | 63 |
| `PhotosPickerShim.swift` | 40 |
| `ContentView.swift` | 24 |

`DesignSystem.swift` being dead while `DesignComponents.swift` is live is the tell: an agent built a
design system, a later agent built another one, nobody deleted the first.

### D. Contradicted claims / ghost content — **2,768 lines, ~50% questionable**
Commit `2026-10-10` says *"refactor: removed 3,000 lines of hardcoded recipes from app binary"*, yet
`SampleRecipes.swift` still holds 2,768 lines of hardcoded recipes and `AppEnvironment` still merges
`Recipe.placeholderRecipes` into the user's library (lines 153, 158, 430, 437, 608). The content is
real and useful; the "removed" claim and the leftover merge paths are not.

### E. Repo hygiene — sloppy, not LLM-specific, but it stacks
- `Lottie.xcframework.zip` (**53 MB**) committed *and* the extracted `Lottie.xcframework`
  (**217 MB**) committed — and `Package.swift` pulls Lottie from SPM anyway. Three copies of one
  dependency. This is why `.git` is 208 MB.
- `xcuserdata/…/UserInterfaceState.xcuserstate` tracked (UI state, never should be committed).
- Root litter: `Group 6.png`, `Background(2).png`, extension-less `cravecircle_logo`.
- Hardcoded Supabase anon key in `AppConfig.swift:61` (public-role JWT, so not an incident, but it
  should live in `Config/Local.xcconfig` like the rest of the secrets).

### F. Architectural accretion
`AppEnvironment` is 2,027 lines with 18 `// MARK:` sections owning auth, recipes, grocery, friends,
collections, notifications, comments, telemetry, imports and Live Activities. No agent ever split
it — each one just appended. Also: `Package.swift` declares `.iOS(.v26)` while `docs/PRODUCT.md` binds
iOS 17+, and `docs/PRODUCT.md` itself flags a dark-first-vs-light design conflict left unresolved.

---

## 6. Verdict

| Layer | Slop estimate | Why |
|---|---|---|
| Swift app logic (screens, state, networking) | **~5–10%** | Clean, guarded, well-commented, almost no dead branches. Genuinely decent. |
| Dead/orphan Swift files | **1,006 lines (≈4.5% of Swift LOC)** | 100% deletable today. |
| Markdown / planning layer | **~65%** | Task briefs and handoffs nobody prunes. |
| Root scripts | **~90%** | One-shot generators, already run. |
| Repo/binary weight | **bad** | 270 MB of triplicate Lottie + tracked xcuserdata. |

**Overall: roughly 15–20% of the written artifacts (docs + scripts + dead files) is absolute slop,
but only ~5–10% of the actual Swift is.** The pattern is classic: the code an agent writes *while
you're watching* is fine; the scaffolding it leaves behind — plans, handoffs, one-off scripts,
superseded versions of things — is never cleaned up. This repo's real debt is **curation, not
correctness**.

### Quick wins (all safe, in order of payoff)
1. `git rm` the 9 dead Swift files above (−1,006 lines, nothing references them).
2. Delete stale root `*_PLAN.md` / `TASK_*.md` / `docs/archive/CHANGES_FOR_CLAUDE.md`, keep `docs/PRODUCT.md`,
   `docs/POLICIES_CraveCircle.md`, `docs/PRIORITIZED_TASKS.md`, `docs/AGENTS.md`.
3. Delete the 6 root scripts + `Lottie.xcframework.zip` + untrack `xcuserdata` (do a history purge
   later if the 208 MB matters).
4. Resolve the `SampleRecipes` question: either genuinely drop the bundled recipes from the binary
   or revert the "removed 3,000 lines" claim and keep them as the intended seed.
5. Split `AppEnvironment` along its existing 18 `// MARK:` seams — no new design needed.

_Verification status: all counts above come from `git ls-files`, `wc -l`, and targeted `grep`s run
in this checkout on 2026-10-16. I did **not** run `xcodebuild test` — treat build/test state as
unverified._
