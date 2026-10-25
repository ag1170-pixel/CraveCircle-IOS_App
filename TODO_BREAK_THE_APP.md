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
