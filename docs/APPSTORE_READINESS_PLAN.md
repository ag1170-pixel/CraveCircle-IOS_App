# CraveCircle — App Store Readiness Plan

> Target: iOS App Store submission. Everything below is the shortest honest path to a build we're
> willing to ship. "Honest" means **no fake stats, no fake accounts, no fake counts, no soft
> promises we can't keep**. If a feature isn't ready, we hide it instead of faking it.

---

## 1. Scope guard — what ships in v1, what defers

**Ships in v1 (must be real, end-to-end)**

- Sign up / sign in (email + Google) → Supabase auth.
- Guest mode with a hard 5-recipe free-view cap, then a sign-in wall.
- Browse the Discover reel, Home feed, library.
- Import a recipe from Instagram / TikTok / YouTube / Pinterest.
- Save, Like, Follow — all per signed-in user, synced to Supabase.
- Comment on a recipe.
- Add a friend; accept / decline a friend request.
- Shared-with-you inbox.
- Notifications bell with real activity grouped by Today / Yesterday / Last 7 days.
- Creator request flow → admin approves → creator sees Studio and can publish.
- Studio: write-from-scratch, publish a draft, see your published recipes.
- Grocery list.
- Hands-free Cook Mode (works offline).

**Defers (hidden from UI until ready)**

- Share-a-video from Studio (today's `importFromVideo` isn't built for a local pick → see
  `docs/TODO_BREAK_THE_APP.md` P1).
- Followers count anywhere (no server endpoint yet).
- Push notifications for inbound follows / likes / comments (hooks exist; no push server).
- iPad / landscape adaptation.
- Contacts "limited" re-pick.

---

## 2. Data model — who owns what, how it stays per-user

The core rule: **every piece of personal state is keyed by a Supabase user id (`auth.uid()`),
both on device and in the cloud, with RLS enforcing the server side.** Nothing in the UI reads
or writes anything until we know whose data it is.

### 2.1 Server (Supabase)

Tables already defined in `supabase/cravecircle_schema.sql`:

| Table               | Owner column         | Purpose |
|---------------------|----------------------|---------|
| `profiles`          | `id = auth.uid()`    | Account + role (user / creator / admin) + socials. |
| `recipes`           | `owner_id`           | Both imported and created recipes, with `visibility`. |
| `follows`           | `follower_id`, `creator_id` | Social graph. RLS: user can insert/delete their own follower rows only. |
| `shares`            | `from_user`, `to_user` | Shared-with-you inbox. RLS: receiver + sender can read; sender can insert. |
| `user_interactions` | `user_id`            | Telemetry events (like / save / cook / view / interested / not_interested). RLS: user writes their own rows. |
| `creator_requests`  | `user_id`            | Admin-reviewed. RLS: user writes own; admin reads all. |

Pieces added or confirmed in this pass:

- **`role_self_elevation.sql`** — new trigger `enforce_role_change` + RPC `founder_elevate_me()`
  prevent anyone from PATCHing themselves to admin unless (a) they already are admin, or
  (b) they are the specific founder email. The iOS client calls `founder_elevate_me()` on sign-in.

Still **TODO on the server** (file them before submission):

- `likes` table + RLS (today likes are device-local only; we need a server copy so user A's
  likes follow them across devices). Keyed by `(recipe_id, user_id)`.
- `saved_recipes` table + RLS, same pattern.
- `comments` already exist (`supabase/comments.sql`); ensure RLS requires `author_id = auth.uid()`.
- `follower_counts` materialized view or a cheap SQL function so the Studio can show a real
  follower count without reading the whole table.

### 2.2 Device (AppEnvironment)

Everything persisted on the phone goes through two helpers in `AppEnvironment.swift`:

- `AccountScope.fileName(userId:, file:)` → every per-user JSON file lives under a per-user
  folder (recipes, likes, saves, follows, friends, requests, collections, comments, drafts,
  notifications, grocery, preferences, interactions, pending interactions, shared log). On a
  user switch, nothing from account A can bleed into account B.
- `AccountScope.defaultsKey(userId:, key:)` → UserDefaults keys namespaced by user id so sets
  (liked ids, saved ids, cooked ids, friend ids) stay isolated.

`hydrateLocal()` loads these on sign-in, `clearPersonalState()` wipes them on sign-out.
`continueAsGuest()` creates a stable guest id so a guest's state is itself per-guest.

**Audit result:** likes (`likedRecipeIds`), saves (`savedRecipeIds`), follows
(`followedCreators`), friends, requests, interactions, notifications, comments, collections,
drafts, grocery — all scoped per `userId`. User A and user B on the same device have fully
isolated state.

**Gaps to close before submission:**

1. Likes + saves exist locally only. Add server mirrors (`likes`, `saved_recipes` tables above)
   so a user who signs in on a new device sees their history. Mirror pattern already used for
   `follows`.
2. `pendingInteractions` is written locally but never flushed to the server — hook up
   `supabase.logInteractions(_:)` so the recommender has real data.
3. `comments` are loaded from Supabase but the local `recipeComments` map includes
   `RecipeComment.defaultSamples` as the fallback — remove the samples (point 3.1 below).

---

## 3. No fake content — strip the samples

The following seeded data looks like real user content and must be gated or removed before
submission:

- `CollectionItem.ownedSamples` + `.sharedSamples` — ships 5 "Weeknight Dinners" style
  collections as if the user created them. **Remove** or guard behind a DEBUG flag.
- `CircleNotificationItem.samples` — 4 sample activity rows. Already stripped by
  `CircleNotificationItem.withoutSamples(_:)` on hydrate, but the samples still exist in code
  and could be re-introduced. Delete.
- `RecipeComment.defaultSamples` — fake comments on sample recipes. **Delete.**
- `FriendItem.samples` + `FriendRequestItem.incoming/outgoing` — sample social graph. **Delete.**
- Preseeded `studioDraftIds = ["recipe-hot-honey-chicken", "recipe-spicy-paneer-wrap"]` in
  `AppEnvironment.swift:68`. **Remove the hardcoded set** — a new account should have 0 drafts.
- Preseeded sample recipes in `SampleRecipes.swift` must not be auto-ingested into a user's
  library on first launch. They may stay as the Discover reel's fallback when the suggested
  feed is empty, so long as the recipes are marked `owner_id = @cravecircle` and the user
  can't accidentally "own" them.

---

## 4. Guest flow — the hard wall

Owner call: a guest can open **5 recipes**, after which the sign-in wall is non-dismissible.

- Counter: `@AppStorage("guest_recipes_viewed")`, limit `AppEnvironment.guestRecipeViewLimit = 5`.
- Gate: `canViewRecipe()` — called from `selectRecipe(_:)`. Returns false when limit hit and
  raises `showGuestPaywall`.
- UI hint: show "N free recipes left" at the top of the detail screen for guests (TODO — not
  yet implemented).
- Write actions (Follow / Like / Save / Comment) **already** raise `showGuestPaywall` via
  `requireRealSessionOrPrompt()` — they never flip local state for a guest.
- On successful sign-in / sign-up, `resetGuestViewCounter()` clears the counter.
- `GuestWallView` must offer **sign in / sign up** on the same screen; no "close" that returns
  to the browsing surface.

---

## 5. UX & copy — honesty pass

- No fabricated statistics. (Fixed: the "92% of users" line is gone.)
- No promised networks the importer can't handle. (Fixed: Pinterest is now wired through
  the web / photo path; Facebook stays off the UI until it works.)
- No "0 Followers" when the server doesn't know. (Fixed: tile hidden.)
- Loading states on every network call that can take > 300 ms. (Audit outstanding.)
- Error states, not silent fail, on: addComment, publishDraft, submitCreatorRequest,
  toggleFollow. (Audit outstanding — see `docs/TODO_BREAK_THE_APP.md`.)

---

## 6. App Store Connect checklist (what Aditya needs to prepare)

- **Privacy Policy URL** — https://cravecircle.cc/privacy (per `TASK_Privacy_Terms_Support.md`).
- **Support URL** — https://cravecircle.cc/support.
- **Marketing URL** (optional).
- **Account deletion in-app** — iOS requires it for accounts you let people create. Already
  partially present in `ProfileScreen.swift` (`DeleteAccountSheet`); verify it actually calls
  Supabase to delete the row, not just signs out.
- **Age rating** — 4+ safe (user-generated comments → 12+ with "Infrequent/Mild Mature/
  Suggestive Themes" if we leave comment moderation as-is).
- **App Privacy data collected** — accurate list: email, name, user content (recipes +
  comments), identifiers (user id), diagnostics, usage data. Nothing else.
- **Camera / Mic / Speech / Contacts usage descriptions** — already in Xcode build settings;
  double-check the strings read as human sentences in a sheet, not acronyms.
- **Sign in with Apple** — required by App Review when you offer any third-party sign-in
  (Google). Must add before submission.
- **Export compliance** — if HTTPS only, declare "Standard encryption".

---

## 7. Pre-submission test matrix

- [ ] Fresh install → guest flow → view 5 recipes → wall → sign up → paywall gone, counter 0.
- [ ] Fresh install → sign in as user A → like, save, follow, comment. Sign out. Sign in as
      user B. None of A's state visible.
- [ ] Import a reel from Instagram, TikTok, YouTube, Pinterest. Each lands as a visible recipe.
- [ ] Submit a creator request. Admin (founder email) sees it, approves it, requester sees
      Studio + can publish within a reasonable refresh window.
- [ ] Publish a recipe. Second account sees it on Discover.
- [ ] Follow a creator. Their followers-only recipes become visible.
- [ ] Add a friend by username. Both sides see the request & accept flow.
- [ ] Share a recipe with a friend; the friend sees it in Shared-with-you.
- [ ] Open a recipe → read ingredients + directions + nutrition → enter Cook Mode → voice
      reads directions.
- [ ] Open the bell → sections render, thumbnails render, Confirm/Delete work.
- [ ] Delete account → row gone from Supabase, local caches wiped, app returns to signed-out.
- [ ] No crashes with Airplane mode on, mid-import.

---

## 8. Rolling backlog

The item-level open list lives in `docs/TODO_BREAK_THE_APP.md`. The architectural pieces above
reference it where applicable. Keep that file current; this one holds the shape, not the
items.
