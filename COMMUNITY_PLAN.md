# CraveCircle — Sharing, Community & Follower-Gated Recipes (plan)

Three connected features: **(1) sharing that works + a record of what was shared to whom, (2) a
creator community (only Studio creators publish, for their followers), (3) followers-only recipes
(follow the creator to unlock).** This is the plan — the *how* and the *what*, split into a
client MVP we can ship now and the server enforcement that lands with real auth.

> **Why phased:** real enforcement (a followers-only recipe truly hidden from non-followers) can
> only be trusted on the **server** (Supabase Row-Level Security). Auth is currently the
> dev-bypass, so Phase 1 is client-side (demo-correct, not secure); Phase 2 makes it real.

---

## Data model (the foundation)
Add to the existing models:
- `UserProfile.role: "consumer" | "creator"` — only creators can publish to the community.
- `Recipe.visibility: "everyone" | "followers"` — plus `creatorId` (already `ownerId`).
- `FollowEdge { followerId, creatorId, createdAt }` — we already track `followedCreators` locally.
- `SharedRecipeRecord { id, recipeId, fromUserId, toUserId/handle, createdAt, channel }` — the
  "who shared what to whom" log.

## Feature 1 — Sharing that works + "shared with whom"
**What the user gets:** a Share button that (a) sends a recipe to a Circle friend in-app, (b) shares
a link outside the app, and (c) a **"Shared" screen** showing what they sent to whom and what was
shared *with* them.

**How:**
- **In-app send:** `shareRecipeWithFriend(recipe, friend)` records a `SharedRecipeRecord` and drops
  a "Recipe shared with X" into the recipient's inbox (today it only posts a local notification —
  extend it to a real record).
- **External link:** `ShareLink` with a deep link `cravecircle://recipe/<id>` (register the route in
  `AICookBookApp.onOpenURL`, mirroring the existing `cravecircle://import`). Opening it selects the
  recipe (or shows the follow-gate if it's followers-only).
- **"Shared" screen:** two lists — *Sent* (from `sharedLog` where `fromUserId == me`) and *Received*
  (`toUserId == me`). Entry point: Profile row + the share sheet's "Recent".
- **Ownership:** Claude → `SharedRecipeRecord`, `AppEnvironment.share(...)`/`sharedLog`, deep-link
  route. Antigravity → the Share sheet UI additions + the "Shared" screen.

## Feature 2 — Creator community (Studio-only publishing)
**What:** a **Community / Circle feed** of recipes published by creators the user follows; only users
with the **creator role** can publish there.
**How:**
- `UserProfile.role`; the Studio "Publish" / "New recipe" actions are **gated to `role == creator`**
  (consumers see "Become a creator" instead).
- Publishing sets the recipe's `creatorId` and pushes it to the community feed (followers' feeds).
- Feed = recipes from `followedCreators`, newest first (client filter now; server query later).
- **Ownership:** Claude → role field + `canPublish` gate + feed query. Antigravity → Community feed
  screen + the "Become a creator" state in Studio.

## Feature 3 — Followers-only recipes (follow to unlock)
**What:** a creator marks a recipe **followers-only**; a non-follower sees a locked preview
("Follow @creator to unlock this recipe") and, on following, it unlocks.
**How:**
- `Recipe.visibility` toggle in the editor (creator-only).
- `AppEnvironment.canView(recipe) = recipe.visibility == .everyone || isOwner(recipe) ||
  isFollowing(recipe.ownerUsername)`.
- **Recipe detail:** if `!canView`, render a **follow-gate** — blurred hero + title + a Follow
  button; tapping Follow calls `toggleFollow` and the content reveals (spring). Cards elsewhere show
  a small "Followers only" lock badge.
- **Ownership:** Claude → `visibility` field + `canView` + the gate's *logic*. Antigravity → the
  gate's *look* (blur, lock badge, Follow CTA) and the editor toggle.

---

## Phase 1 — Client MVP (ship now; demo-correct, not secure)
1. Models: `Recipe.visibility` (default `.everyone`), `UserProfile.role`, `SharedRecipeRecord`.
2. `AppEnvironment`: `canView(recipe:)`, `canPublish`, `sharedLog` + `recordShare(...)`, persisted
   via the existing `LocalStore` (autosave `didSet`).
3. UI: follow-gate on `RecipeDetailScreen`; "Followers only" badge on cards; Community feed;
   "Shared" screen; creator-gate in Studio; deep link `cravecircle://recipe/<id>`.
4. Sample data: mark a couple of sample recipes `followers`-only + set some creators' `role`.

## Phase 2 — Server enforcement (with real auth, from `COMMUNITY`/Supabase plan)
1. Supabase tables: `profiles(role)`, `recipes(visibility, creator_id)`, `follows(follower,creator)`,
   `shares(recipe, from, to, created_at)`.
2. **RLS policies** = the real gate: a `followers`-visibility recipe row is returned **only** to the
   owner or a follower (`exists(select 1 from follows where follower = auth.uid() and creator =
   recipes.creator_id)`). This is what makes "follow to unlock" un-bypassable.
3. Publishing writes `creator_id` + fan-out to followers' feeds (or a feed query with the follows
   join). Shares insert a `shares` row → recipient's "Received" list + a push (Phase 3).
4. Deep links resolve server-side with the same RLS, so a shared followers-only link still prompts
   a non-follower to follow.

## Phase 3 — Polish
Rich share previews (Open Graph on `cravecircle.cc/r/<id>`), push notifications for shares/new
follower recipes, community discovery (trending creators), and analytics for creators.

---

## Division of labor
- **Claude (logic/data/backend):** model fields, `canView`/`canPublish`/`sharedLog`, deep-link
  route, Supabase schema + **RLS** (the real enforcement), feed/share queries.
- **Antigravity (UI):** follow-gate visuals, "Followers only" badge, Community feed screen, "Shared"
  screen, Studio creator-gate + visibility toggle in the editor.
- **Interface:** screens call `environment.canView(recipe)`, `environment.canPublish`,
  `environment.recordShare(...)`, `environment.communityFeed` — Claude implements these.

**Note:** Phase 1 gating is client-side and can be bypassed by a determined user — fine for
demo/personal use. Do **not** call followers-only "private/secure" to end users until Phase 2 RLS
is in place.
