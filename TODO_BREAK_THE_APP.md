# CraveCircle — Break-the-app backlog

> Rolling list of problems a user can hit, found during the 2026-10-25 QA pass.
> **Fixed** items are kept with their landing commit; everything else is a next-up candidate.
> Severity: **P0** = user is lied to or data is lost · **P1** = flow is broken but recoverable ·
> **P2** = polish, edge cases, missing content.

---

## ✅ Fixed in this pass (2026-10-25)

- [x] **[P0] Onboarding fake 92% statistic** — removed. Copy now honestly says we'll shape the feed around picked goals.
- [x] **[P0] Pinterest + Facebook promised but not supported** — removed from onboarding copy and the social icons row. Only Instagram / TikTok / YouTube advertised, matching `ReelURL.isValid`.
- [x] **[P0] Guest Follow lies** — `toggleFollow` now routes guests to the sign-in paywall instead of flipping a local-only pill.
- [x] **[P0] Guest Like / Save lies** — `toggleLikeRecipe` and `toggleSaveRecipe` gated behind `requireRealSessionOrPrompt()`.
- [x] **[P0] Guest Comment silently drops** — `addComment` returns "Sign in to post a comment." and raises the paywall.
- [x] **[P0] Studio "0 Followers" lie** — stat tile removed until the backend exposes a real follower count.
- [x] **[P0] Admin auto-elevation local-only** — now PATCHes `role = admin` to Supabase via `updateMyRole`, so RLS-gated writes line up with the client UI.
- [x] **[P0] Admin auto-elevation misses Google sign-in** — now reads the authenticated JWT's `email` claim via `supabase.currentUserEmail()` so OAuth sign-ins work even when no email was typed into the form.

---

## 🔴 P0 — still open

- [ ] **Sample data ships as real published state** — new accounts open to pre-seeded "Weeknight Dinners · 8" collections and sample notifications. User thinks they already have content they never created. _See `CollectionItem.ownedSamples`, `.sharedSamples`, `CircleNotificationItem.samples`._
- [ ] **No draft autosave in the recipe editor** — close the sheet by accident, lose everything. Needs background persist on every field change.
- [ ] **Comments success is faked on server timeout** — `addComment` treats a nil reply as success. A timeout silently loses the comment.
- [ ] **Likes keyed by local recipe id** — after a cloud sync re-id, the like's id no longer matches, so the heart appears to unlike itself.
- [ ] **Follow/unfollow races** — rapid taps fire async `setFollow` writes; final state can disagree between device and server.

## 🟠 P1 — broken flows that need UX

**Onboarding**
- [ ] 5 goals = 5 forced explainer cards, no "Skip" button.
- [ ] Back from `goalDetail` jumps to goalsAffirmation instead of previous goal in the cycle.
- [ ] No way to exit onboarding other than finishing it.
- [ ] The 4 captured picks (goals / decisionTime / sources / hearAbout) are written to `@AppStorage` and read by nothing downstream.
- [ ] `deviceOnboarded` is per-device, so a reinstall shows onboarding again; cuisines picked on another device don't restore.
- [ ] Three share-sheet coachmark screens are SF-Symbol mockups, don't match any real screen.

**Guest → sign-in migration**
- [ ] `carried` only moves recipes owned by the guestId. Likes, saved IDs, comments, bundled notifications, follows, onboarding picks all stay stranded on the guest id.
- [ ] Guest paywall triggers at 10 recipes viewed but Follow/Like/Save (now blocked) and Comment never incremented the counter — review guest limits now that the writes are blocked.

**Admin / Creator requests**
- [ ] Submitting a creator request → "pending" is local only; no polling for approval.
- [ ] Approval doesn't push a notification to the requester.
- [ ] Approval doesn't change `AccountRole` on the device until next `fetchMyProfile` — requester may still see "Become a Creator" after approval.
- [ ] "Open Studio" assumes `canPublish` is true, no server round-trip to confirm.

**Notifications bell**
- [ ] Bell count = unread + incoming requests; stale requests inflate the badge indefinitely.
- [ ] Unliking a recipe doesn't update bundled "You liked X and N others" rows.
- [ ] Re-liking in a 30-min window resets `isRead = false` and bumps `timeAgo = "Just now"` on a row the user already dismissed.
- [ ] `bundleLikeNotification` matches by `title == "Liked Recipe"` — fragile key, any future notif with that title would merge.
- [ ] No swipe-to-delete on individual notifications.
- [ ] No "Clear all" / "Mark all read" explicit action.

**Friends / Circle**
- [ ] Suggested list is only populated from recipe owners in your catalog. New install → empty forever.
- [ ] Add-sheet toolbar: guest message says "Sign in to add a friend" but Suggested list still shows Follow buttons (now at least gated by the paywall).
- [ ] Contacts match is name-contains; "Mom" matches any creator with "mom" in their name.
- [ ] Invite from Contacts sends the generic cravecircle.cc link with no deep-link / referral back to the inviter.
- [ ] Granted "Limited" contacts selection has no in-app re-pick UI.
- [ ] Accept/Decline friend request plays the animation before the backend confirms.
- [ ] Row avatars are initials disks, not real images.

**Studio**
- [ ] "Share a photo" duplicates "Import from photo" from the + sheet with the same OCR pipeline — inappropriate for a creator sharing their own plated dish.
- [ ] "Share a video" reads the whole video as `Data` into memory → OOM on a large clip.
- [ ] Picked video written to `/tmp/studio-<uuid>.mov` with no cleanup; wrong extension on HEVC/.mp4 sources.
- [ ] `importFromVideo(url:)` was built for a reel-server audio file + caption / title / thumbnailUrl; local pick carries none of those → likely silent failure.
- [ ] Studio dismisses before import starts; failures surface nowhere.
- [ ] "Publish a new recipe" opens the blank editor but nothing forces `visibility = .everyone`; a creator can publish a draft to no one.
- [ ] No "Share a reel link" tile in Studio.

**Recipe detail**
- [ ] Comments section is below Nutrition — 3+ swipes to reach. No "View N comments" tap-link higher.
- [ ] Reel rail's bubble-icon count is local `environment.comments(for:)` — stale vs. cloud.
- [ ] "Original" web badge → Safari 404 with no in-app context when the saved URL is gone.
- [ ] "Follow to Unlock" gate doesn't rebuild after a follow — user sees the locked screen and backs out.

**Add-a-recipe sheet**
- [ ] Grid cell count changes based on role (creator = 3 tiles → 2 + 1-with-space; non-creator = 4 tiles → 2×2). Visual asymmetry.
- [ ] "Import from social media" is a tap-to-reveal field; no paste-from-clipboard shortcut; no sample URL; no live validation.
- [ ] Share Extension still routes any shared video to recipe import; doesn't know about Studio's video flow.

## 🟡 P2 — edge cases that break

- [ ] Launch with no internet: `fetchMyProfile` fails → fallback user → onboarding doesn't fire because `deviceOnboarded` is true from a prior session.
- [ ] Delete + reinstall: onboarding fires fresh but existing Supabase account's recipes don't come back.
- [ ] Imported web recipe with a `sourceUrl` whose host is nil → `isWebImportURL` false → shows "Handcrafted Recipe" chip (lies).
- [ ] `ownerUsername` starting with `@@` from a bad import → fuzzy prefix matching produces false positives/negatives everywhere.
- [ ] The "+" FAB visibility: hides on Discover and Circle but still shows on Grocery / Profile / Home — on Profile it says "Add a grocery item" if `tab == .groceries` due to stale `tab` state.

## ⚪ Missing / incomplete

- [ ] Profile Edit → bio + Instagram + TikTok + YouTube + Facebook URL fields (model exists, no UI).
- [ ] Creator profile sheet never shows the creator's socials even if saved.
- [ ] Received-share preview when the recipe isn't local (P1.5 F in `PRIORITIZED_TASKS.md`).
- [ ] Inbound notifications: no "X followed you", "X liked your recipe", "X commented". The bell only shows your own actions.
- [ ] Report a user; block a user.
- [ ] "I don't want to see this" feedback loop in Suggested / Trending.
- [ ] Empty-state for Discover when both suggested feed and library are empty.
- [ ] Pull-to-refresh on the Notifications page.
- [ ] "Mark one as unread" from Notifications.
- [ ] Creator analytics in Studio: views, saves, likes on their own recipes.
- [ ] "Forgot password" + email verification resend on the login screen.
- [ ] Accessibility labels on the FAB, mic button, Studio tiles, reel follow pills.
- [ ] Reduce-motion fallbacks for cat companion, onboarding progress bar, heart-burst.
- [ ] Landscape / iPad layouts.
- [ ] Dark-mode art for the three onboarding coachmarks.

## 🩹 Hygiene

- [ ] `recipes.filter {…}` in `myDrafts` / `myPublished` / `createdRecipes` recomputes per render. Fine today, pain at scale.
- [ ] `/tmp/studio-*.mov` and `/tmp/build.log` artifacts never cleaned.
- [ ] Force-unwrap `URL(string: "https://cravecircle.cc")!` in FriendsScreen.
- [ ] Hardcoded admin email `adityagupta2646@gmail.com` in source — anyone forking inherits it.
- [ ] Device-token upload fires on bootstrap but never retries on failure.
- [ ] Build still has pre-existing warnings in `DesignComponents`, `FlashcardCookScreen`, `SpeechReader` (actor isolation, implicit strong capture, Sendable).

---

## 🧑‍🍳 User journey tests — "cook one real recipe, nothing breaks"

> Think like a real iOS user who installed the app yesterday and wants to make dinner tonight.
> Every step must work smoothly, nothing jarring, no dead ends. Each line is one testable
> moment the user actually passes through. Check them in order on a real device, not the
> simulator, with a real reel from Instagram / TikTok / YouTube / Pinterest.

### Fresh install → first dish
- [ ] Launch cold → onboarding opens on the welcome card within 2s.
- [ ] Finish onboarding → land on Home with Discover feed populated (not an empty state).
- [ ] Browse Discover reel → swipe up 10 times. No stutter, video / image loads before the
      card arrives on screen.
- [ ] Tap a recipe → detail opens in < 500 ms. Hero image, ingredients, directions, nutrition
      all present. No "0 min cook" or "Serves 0" placeholders.
- [ ] Scroll to Comments at the bottom — section renders, previous comments load.
- [ ] Tap "Cook Mode" → directions read full-screen, voice reads first step within 1 s.
- [ ] Hands-free: say "next step" → advances. Say "repeat" → repeats. Say "pause" → stops.
- [ ] Add every ingredient to the Grocery list → open Grocery tab → all there, no dupes.
- [ ] Cross off ingredients → state persists across app relaunch.
- [ ] Rate the recipe when done cooking → the rating lands in the server + bell logs it.

### Save + come back later
- [ ] Save a recipe → open Library → it's there, under Saved.
- [ ] Kill the app (force-quit) → reopen → saved recipe still there, same slot.
- [ ] Open on a different device signed in to the same account → saved recipe shows up.

### Import a reel
- [ ] Open Instagram → share a cooking reel → CraveCircle appears in the share sheet.
- [ ] Tap it → app opens, import banner says "Getting the reel…" within 2 s.
- [ ] Banner progresses: downloading → preparing → transcribing → extracting → "Recipe
      Plated!" within 60 s for a 60 s reel. No silent failure.
- [ ] Tap "View Recipe" → opens the imported recipe with ingredients + directions filled.
- [ ] Repeat with a TikTok link, a YouTube Shorts link, a Pinterest pin — each works.
- [ ] Try an unsupported URL (random blog) → import sheet shows the "Import from web" tile
      instead, which opens the web importer. No disabled button with no explanation.

### Guest flow
- [ ] As a brand-new install, tap "Continue as Guest" on the login screen.
- [ ] Browse Discover, Home, open 10 recipes — nothing walls you.
- [ ] Tap Like → paywall sheet appears with "Sign in to save recipes you love".
- [ ] Tap Follow on a creator → paywall "Sign in to follow creators and build your feed".
- [ ] Tap + → tap Import from photo → paywall "Sign in to import this recipe".
- [ ] Share a reel from Instagram → CraveCircle opens → paywall "You shared a recipe with
      us — we'd love you to keep it. Sign in to add it to your library".
- [ ] Dismiss the paywall → return to the exact spot you were in.
- [ ] Sign up / sign in → the paywall vanishes and everything you were trying works now.
- [ ] Verify: whatever cuisines you picked in onboarding as a guest are still your preferred
      cuisines after sign-in; nothing is lost.

### Multi-user on one phone
- [ ] Sign in as user A → like 3 recipes, follow 2 creators.
- [ ] Sign out → sign in as user B → likes and follows are EMPTY. Not user A's.
- [ ] Sign back in as user A → likes + follows restored.

### Creator flow (manual approval test)
- [ ] As a plain user, tap + → Become a Creator → submit the request.
- [ ] As the founder email, sign in → Admin Requests tab → approve the request.
- [ ] As the original user, pull-to-refresh on Profile → role flips to creator.
- [ ] Open + → Studio opens with Publish / Share a photo / Share a video tiles.
- [ ] Publish a recipe → appears on Discover for other accounts.

### Edge cases a real user will hit
- [ ] Airplane mode mid-import → import banner shows "Import didn't finish" with a Retry.
      Not stuck on a spinner forever.
- [ ] Airplane mode while browsing → cached recipes still open. New Discover doesn't lie
      "No results"; shows "You're offline — showing recipes you already saved".
- [ ] Receive a shared link from a friend while the app is cold → tap the link → app opens
      directly on the recipe, not Home.
- [ ] Rotate device during Cook Mode → voice doesn't stop, text doesn't reflow weird.
- [ ] Headphones in / out mid-voice step → voice continues on the active output, no gap.
- [ ] Lock screen during Cook Mode → voice continues through lock, Now Playing shows the
      recipe title + current step.
- [ ] Low Power Mode → voice + import still work, animations gracefully reduce.
- [ ] Battery hits 1% → the running import flushes to disk, resumes on next launch.
- [ ] 1000 saved recipes → Library scrolls at 60 fps.
- [ ] A recipe with 50 ingredients → ingredients list doesn't push Directions off screen.

---

## ⚡ Load / performance plan — fast imports, split work, no spinning wheels

> "If I share a 10-minute YouTube cooking video to the app, I shouldn't wait 10 minutes to
> see the recipe." The current import pipeline runs serially on one worker. These are the
> breakpoints and the sharding plan.

### What's slow today
- Video transcription runs end-to-end on one server process (homelab laptop). A 10-min reel
  blocks the queue for ~2–3 min.
- Image OCR for photo import also runs on the homelab, single-threaded.
- Recipe extraction (LLM call) blocks the user until the full transcript arrives.
- The suggested-feed refresh pulls the whole catalog with every recipe row, not just the
  cards the user is about to see.

### Sharding plan — divide the work, stream the output

1. **Chunk video audio at the server.** For any clip > 60 s, split into N ~45-second chunks
   with 2-second overlap. Transcribe each chunk in parallel on separate workers; stitch the
   captions by timestamp with overlap dedup. User sees the first chunk's text within 10 s
   instead of waiting for the full clip.
2. **Stream partial recipes to the client.** As each transcript chunk lands, send it to the
   LLM for incremental extraction (ingredients first, directions next, nutrition last).
   Push each piece through the existing `importState` with a new `.partial` case so the
   recipe detail opens as soon as the title + first 3 ingredients are known.
3. **Image OCR on-device for the first pass.** Vision framework runs Latin + CJK text
   detection on the phone with no network round-trip. The server is only called when we
   need the LLM to assemble a recipe from the recognised blocks.
4. **Hedged requests for the Pinterest pin fetch.** Fire the og:image fetch and the direct
   image fetch in parallel; use whichever returns first.
5. **Recipe cards paginated at 20 per page** on Discover, with prefetching for the next 10
   as the user swipes. Nutrition and gallery lazy-load per card as it arrives on screen.
6. **Push the suggested-feed refresh to a Supabase edge function** so the heavy work doesn't
   hit the homelab box, and so each client gets a cached response for ~60 s before the
   worker recomputes.
7. **Durable import queue.** A started import pins to a `imports` table row with `status`.
   If the client disconnects (airplane mode, app killed), the row survives; on next launch
   the client sees the row + resumes polling. Imports never "disappear".
8. **CDN the server media** so the client never re-downloads the audio file for the second
   import of the same reel. Cache by canonical URL + content hash.
9. **Debounce the follow/like/save writes** — collect taps within a 500 ms window, send one
   batched PATCH to Supabase. A rapid tap doesn't race the server.
10. **Pre-warm the detail view** when the user is paused on a Discover card for > 1 s —
    fetch the full recipe + comments before they tap, so detail opens in < 100 ms.

### Think-like-a-user checklist for every performance change
- [ ] First meaningful content on screen < 1 s.
- [ ] Any action that takes > 1 s shows a progress affordance (spinner, bar, or shimmer).
- [ ] Any action that takes > 10 s goes into the background and surfaces as a toast when
      done, so the user isn't trapped on a loading screen.
- [ ] No action loses user input on failure — drafts, imports, comments all persist locally
      and retry.
- [ ] Scroll performance is 60 fps on an iPhone 12 (our minimum target device).
