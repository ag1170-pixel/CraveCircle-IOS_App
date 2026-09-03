# Task: Privacy Policy, Terms of Service & Support pages (CraveCircle)

**For:** whoever implements this (Antigravity for the website side is ideal — you already work in the `cravecircle` web repo + Vercel).
**Goal:** three publicly reachable pages — **Privacy Policy**, **Terms of Service**, **Support/Contact** — so the iOS app can be submitted to the App Store (Apple *requires* a Privacy Policy URL, and a support URL in App Store Connect).

> ⚠️ Not legal advice. These drafts are tailored to what the app actually does, but a human/legal review is wise before a public release, especially the governing-law and liability clauses.

---

## Where to host (recommended)
Add three routes to the **Next.js website** and deploy to Vercel:
- `https://cravecircle.cc/privacy`
- `https://cravecircle.cc/terms`
- `https://cravecircle.cc/support`

Then:
- Put the **Privacy URL** in **App Store Connect → App Privacy** and the app's metadata.
- Put the **Support URL** in **App Store Connect → App Information → Support URL**.
- (Optional but nice) Link all three from the iOS app: **Profile → Settings** rows opening these URLs in Safari.

---

## ⭐ The critical part — what the app ACTUALLY does with data
Write the policy to THESE facts. Do not invent data collection the app doesn't do.

**Platform:** native iOS app (SwiftUI), bundle `com.anassyed.AICookBook`, brand "CraveCircle".

**Permissions requested (and why):**
| Permission | Used for | Important truth |
|---|---|---|
| **Camera** | Hands-free Flashcard cooking — front camera detects a hand-swipe to change steps | Frames are processed **in real time on-device** for hand-pose detection. **No video is recorded, saved, or transmitted.** No camera preview is even shown. |
| **Microphone** | Voice commands "next" / "back" in Flashcard mode | Audio is processed **on-device** for keyword spotting. **Not recorded or uploaded.** |
| **Speech Recognition** | Transcribing a cooking video's audio into recipe steps | Runs **on-device** (Apple `SpeechAnalyzer`/`SpeechTranscriber`, Neural Engine). Audio does not leave the device for on-device import. |
| **Photo Library** | Pick a cooking video to import; pick a photo for a recipe you create | The picked video is transcribed + OCR'd **on-device**, then **discarded** — it is not stored or uploaded. A recipe photo you choose is saved with your recipe. |

**Two import paths (be precise — they differ):**
1. **On-device import** ("Pick a cooking video"): everything (transcription via Speech, on-screen-text via Apple **Vision OCR**) happens **on the phone**. The video is processed then thrown away. **No network, no upload.**
2. **Link / Share import** (paste a link, or Share a reel from Instagram/YouTube/TikTok/Facebook): the **URL** is sent to the user's **self-hosted CraveCircle backend** (a private server) which downloads the video, transcribes it, and returns structured recipe text. The downloaded video is transcribed then **discarded — not stored.** This backend is self-hosted (not a third-party cloud).

**Accounts / auth:** Supabase (email + password, Google sign-in intended). When enabled it stores your **email + basic profile**. (Note: public auth is currently offline pending a new Supabase endpoint — mention account handling as the intended behavior.)

**What's stored:** your recipes, collections, grocery lists, likes/saves, and comments — on your device and/or the CraveCircle backend tied to your account. Recipe photos you add are stored with the recipe.

**What the app does NOT do:**
- **No third-party analytics or tracking SDKs** (no Firebase/Mixpanel/Amplitude/ads). No cross-app tracking. No IDFA.
- **No selling or sharing** of personal data with advertisers.
- Camera/mic are **never** recorded or streamed off the device.

**Nutrition disclaimer (needed in Terms):** calorie/macro numbers are **automatic estimates** from ingredient text and may be inaccurate — **not medical, dietary, or nutritional advice.**

**User-generated content (needed in Terms):** users create/publish recipes and post comments — cover acceptable use, ownership/license, and removal.

**❗ Placeholders the human must fill:**
- **Support email / contact** (e.g. `support@cravecircle.cc` or a real inbox) — required for the Support page + Privacy contact.
- **Company / legal entity name & address** (App Store "real contact address").
- **Governing-law jurisdiction** (country/state) for the Terms.
- **Effective date.**

---

## Deliverable 1 — Privacy Policy (`/privacy`)
Sections:
1. **Intro** — who we are, that this covers the CraveCircle iOS app.
2. **Information we collect** — account info (email/profile) when you sign up; content you create (recipes, photos, comments, grocery lists); permission-based inputs (camera/mic/speech/photos) **used on-device and not stored as media**.
3. **How we use it** — provide the app, sync your library, run imports.
4. **On-device processing** — spell out that transcription, OCR, gesture, and voice all run on the device and media is discarded (this is the app's strongest privacy point — lead with it).
5. **When data leaves the device** — only the **link URL** for server import, and account/content sync to the CraveCircle backend. No third-party analytics/ads.
6. **Third parties** — Apple (on-device frameworks, no data to us), Supabase (auth/DB), the self-hosted backend. yt-dlp fetches the public post you chose to import.
7. **Data retention & deletion** — how to delete your account/content + contact.
8. **Children** — general audience, not directed at under-13.
9. **Your rights** (GDPR/CCPA-style access/deletion).
10. **Changes** + **Contact** (support email).

## Deliverable 2 — Terms of Service (`/terms`)
Sections: acceptance; eligibility; accounts; **user-generated content** (you own yours, grant us a license to display it; no illegal/infringing content; we may remove); acceptable use; **import from third-party platforms** (you must have the right to import; respect the source platform's terms); **nutrition/recipe disclaimer** (estimates, not health advice — cook safely, check allergens); IP; disclaimers & limitation of liability; termination; **governing law** (fill jurisdiction); changes; contact.

## Deliverable 3 — Support / Contact (`/support`)
- Real **support email** + expected response time.
- Short **FAQ** (how import works, on-device vs link import, permissions, deleting data/account).
- Links to `/privacy` and `/terms`.
- Company/contact address.

---

## Acceptance criteria
- [ ] `/privacy`, `/terms`, `/support` return 200 and render on mobile + desktop.
- [ ] Content matches the data-usage facts above (no invented data collection).
- [ ] All placeholders (contact, entity, jurisdiction, date) filled with real values.
- [ ] Privacy URL added to App Store Connect App Privacy; Support URL added to App Information.
- [ ] (Optional) In-app Profile/Settings links to the three URLs.

---

### Division of labor (suggested)
- **Content accuracy** was drafted from the live iOS codebase data-flows (this file). Keep it faithful.
- **Implementation** (Next.js routes, styling to match the site, Vercel deploy, App Store Connect fields) is the web/ops work — that's the main task here.
