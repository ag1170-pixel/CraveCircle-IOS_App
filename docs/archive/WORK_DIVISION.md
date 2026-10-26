# CraveCircle — Work Division: Claude ⨯ Antigravity

> **Focus (2026-09-03, revised by founder):** make the **app itself perfect and feature-complete
> first** — every button/flow working, features connected end-to-end, more content. **Launch/auth/App-Store
> paperwork is deferred** (don't optimize for public release yet). Antigravity's first job = **recipe
> content** (`ANTIGRAVITY_CONTENT_TASK.md`), then the UI polish lane below.

Goal: finish the app to a shippable, everything-works state. We share one repo
(`/Users/user38/Projects/CraveCircle.cc` → `ag1170-pixel/CraveCircle-IOS_App`), so this splits by
**layer + file ownership** to avoid merge collisions, and assigns each task to whoever is stronger at it.

---

## Who's better at what (honest read, from what each of us has actually shipped here)

**Antigravity — the UI/product/web builder.** Shipped the social Home, Studio, Collections, Profile,
Comments, the design system + food assets, and the web/Vercel side. Fast and strong at: **SwiftUI
screen composition, visual design, motion/micro-interactions, design-system consistency, and the
Next.js website.** → Owns **pixels & web**.

**Claude — the systems/integration/QA engineer.** Shipped the homelab Whisper backend (Docker,
cookies, OCR), on-device Speech + Vision, the Share Extension target (pbxproj surgery), gesture +
voice logic, nutrition parser, config/secrets/git ops, and build/test verification. Strong at:
**backend & data, device frameworks, correctness/wiring, security, project/Xcode plumbing, and
verification.** → Owns **logic, data & ops**.

**The interface between us:** `AppEnvironment` methods + the models in `Models.swift`. Antigravity's
screens call `environment.doThing()`; Claude implements/backends `doThing()`. Neither reaches across.

**Access reality (this decides several assignments, not just preference):**
- **Only Claude can reach the Homelab** (SSH `homelab` / `100.70.151.71`) and the **Obsidian vault**
  (`SergantSwaggBase`). So **all backend/Docker/Supabase-exposure/tunnel/cookies work and all
  ops-doc updates are Claude's** — Antigravity physically can't do them.
- **Claude keeps the Obsidian vault as the shared source of ops truth** (homelab, endpoints,
  deploy steps). Antigravity: when you need a private detail (an IP, a deploy command, a secret
  location), ask via a `// NEED(claude): …` note or the handoff doc — it's in the vault, not the repo.

---

## File ownership (edit only your side; coordinate on shared)

| Owner | Files |
|---|---|
| **Antigravity (UI/web/content)** | `*Screen.swift`, `*Sheet.swift`, `*View.swift`, `DesignSystem.swift`, `DesignComponents.swift`, `BrandAndTabBar.swift`, `Assets.xcassets/*`, `SampleRecipes.swift` (recipe content), `FlashcardCookScreen.swift` (visual layer), the **website** repo |
| **Claude (logic/data/ops)** | `AppEnvironment.swift`, `APIClient.swift`, `AppConfig.swift`, `Models.swift`, `Nutrition.swift`, `IngredientScaler.swift`, `OnDeviceTranscriber.swift`, `RecipeExtractor.swift`, `VideoTextOCR.swift`, `HandGestureController.swift`, `VoiceCommandController.swift`, `SupabaseAuthClient.swift`, `whisper-transcriber/*`, `*.entitlements`, `Config/*`, `project.pbxproj`, backend/homelab |
| **Shared (announce before editing)** | `RootView.swift`, `AICookBookApp.swift`, `Localization.swift` |

**Protocol:** small commits, clear messages, `git pull --rebase` before pushing. If you must touch the
other's file, leave a `// TODO(other-agent): …` and note it in your handoff commit.

---

## 🟦 Claude's tasks (logic, data, backend, correctness, security)

**P0 — the real blocker**
1. **Auth + persistence** (needs 1 user decision, below). Stand up real accounts + data storage so the
   app isn't on the dev-bypass: either expose the homelab Supabase publicly (Cloudflare tunnel) or
   recreate a cloud Supabase; wire `SupabaseAuthClient` + a real recipe/collection/grocery store.
2. **Remove the DEBUG dev-bypass** once auth works (`AppEnvironment.bootstrap`).

**P1 — make features real, not local-only**
3. **Persist imported recipes** (backend currently in-memory) + **recipe-edit sync** (`updateRecipe` → `PATCH /recipes/{id}`).
4. **Grocery data layer** — server-backed list + `PATCH /grocery-list/{id}` (UI stays Antigravity's).
5. **Backend hardening** — API key on the endpoint, off-tailnet access (tunnel), job persistence.
6. **Import correctness** — language auto-detect (on-device is en-US only), better narration→ingredient extraction, robust error surfaces.

**P2 — quality**
7. **Every-button wiring audit (code level)** — verify every control calls a real `AppEnvironment`/nav action; no dead handlers. Produce a checklist Antigravity can verify visually.
8. **Nutrition accuracy** pass.
9. **Build/test + release plumbing** — signing config, entitlements, App Privacy label facts, keep the repo green.

## 🟩 Antigravity's tasks (UI/UX, screens, design, web)

**P1 — the app's look & feel**
1. **Studio UI** — redesign/polish as desired (user flagged this): stats layout, draft/published, publish flow feedback.
2. **Grocery list UI** — categories/sections, swipe-to-delete, check animations, "clear checked", empty state (calls Claude's grocery methods).
3. **Visual consistency pass** — spacing/typography/color tokens across all screens; unify cards, headers, buttons.
4. **Loading & empty & error states** — every network-backed screen gets a proper loading + empty + error visual (wire to the states Claude exposes).
5. **Motion/micro-interactions** — tasteful, respect Reduce Motion.

**P2 — polish & platform**
6. **Accessibility pass** — VoiceOver labels on all controls/images, Dynamic Type, contrast.
7. **Device-size/dark-mode parity** — check small iPhones + iPad, full light/dark.
8. **Web** — build `/privacy`, `/terms`, `/support` on the site from `POLICIES_CraveCircle.md`; verify which repo serves `cravecircle.cc` first (hero repo vs the main Next.js app).
9. **App Store visual assets** — screenshots, marketing copy.

## 🟨 Shared / User
- **Signing on device** (user's Apple ID on both targets + App Group) — user.
- **On-device testing** of gestures/voice/share sheet — user (real hardware).
- **Fill the 5 policy placeholders** — user.
- **The button audit** = Claude (code) + Antigravity (visual/interaction) together.

---

## ⚠️ One decision needed to unblock P0 (auth)
Pick the persistence path so Claude can start:
- **A. Expose the homelab Supabase publicly** (Cloudflare tunnel, e.g. `auth.cravecircle.cc`) — keeps
  data in place, matches the existing `api.cravecircle.cc` pattern, but depends on the lab laptop.
- **B. Recreate a cloud Supabase project** — most reliable for a public app; re-point web + app + Google OAuth.
- **C. Stay local/dev-bypass for now** — ship a single-user/offline build; defer real accounts.

Until this is chosen, Claude will proceed on P1/P2 items that don't depend on it (import correctness,
nutrition, wiring audit, backend hardening groundwork).
