# Handoff Note for Claude: App Store Legal & Support In-App Integration

**Date:** September 3, 2026  
**Author:** Antigravity  
**Context:** App Store preparation & legal compliance per user brief `TASK_Privacy_Terms_Support.md` and drafts in `POLICIES_CraveCircle.md`.

---

## 1. Summary of What Was Done

To prepare the **CraveCircle** iOS app (`com.anassyed.AICookBook`) for Apple App Store review (Guidelines 5.1.1 & 5.1.2) and App Store Connect submission:
1. Added static legal and support URLs to the app configuration.
2. Added a dedicated **"Legal & Support"** card in `ProfileScreen.swift` opening Privacy Policy, Terms of Service, and Help & Support in a native in-app Safari view.
3. Committed and pushed all changes along with the policy briefs to GitHub (`ag1170-pixel/CraveCircle-IOS_App`).
4. Updated all project documentation and architecture logs in the Obsidian vault (`SergantSwaggBase`).

---

## 2. Files Modified & Why

### 1. `AICookBook/AppConfig.swift`
* **Changes:**
  Added three static constants to `AppConfig`:
  ```swift
  static let privacyPolicyURL = URL(string: "https://cravecircle.cc/privacy")!
  static let termsOfServiceURL = URL(string: "https://cravecircle.cc/terms")!
  static let supportURL = URL(string: "https://cravecircle.cc/support")!
  ```
* **Why:** Centralizes the production URLs for legal policies and user support in one configuration file instead of hardcoding URLs across UI views.

---

### 2. `AICookBook/ProfileScreen.swift`
* **Changes:**
  1. **State:** Added `@State private var activeSafariURL: IdentifiableURL? = nil`.
  2. **UI Section:** Added a new **"Legal & Support"** card under Profile preferences before the "Log out" button:
     * **Help & Support** (`questionmark.circle.fill` / `.teal`) → triggers `AppConfig.supportURL`
     * **Privacy Policy** (`hand.raised.shield.fill` / `.green`) → triggers `AppConfig.privacyPolicyURL`
     * **Terms of Service** (`doc.text.fill` / `.blue`) → triggers `AppConfig.termsOfServiceURL`
  3. **Presentation:** Attached `.sheet(item: $activeSafariURL)` presenting `SafariView(url: item.url)` (`SFSafariViewController`) with `.presentationDetents([.large])` and native drag dismissal.
  4. **Branding:** Added subtle version and brand footer: `"CraveCircle v1.0 · Crafted for cooks & food lovers"`.
  5. **Helper Model:** Defined `IdentifiableURL: Identifiable` (`id = UUID()`, `url: URL`) for clean SwiftUI sheet presentation.
* **Why:**
  * Apple App Store Guidelines require easily accessible Privacy Policy and Support URLs.
  * Presenting via `SafariView` keeps users inside the app with standard Safari reader, security, and navigation controls rather than kicking them out to an external browser.

---

### 3. `TASK_Privacy_Terms_Support.md` (Committed to repo root)
* **Contents:**
  * The locked technical brief documenting the app's **exact on-device data truth** (hand-pose camera frames analyzed in real time with zero recording/streaming; microphone keyword spotting on-device; Neural Engine audio transcription + Vision OCR on-device with video discarded immediately; zero analytics or third-party tracking SDKs; link-import via self-hosted backend).
  * Hosting specs (`/privacy`, `/terms`, `/support` on `cravecircle.cc`).
  * App Store Connect submission checklist.

---

### 4. `POLICIES_CraveCircle.md` (Committed to repo root)
* **Contents:**
  * Ready-to-publish complete text drafts tailored precisely to what the iOS app actually does:
    1. **Privacy Policy** (highlighting on-device privacy safeguards)
    2. **Terms of Service** (including nutrition disclaimer and user-generated content terms)
    3. **Support & FAQ** (common questions on link vs. on-device import, permissions, account deletion)

---

## 3. Obsidian Vault Updates Made

The following notes in `/Users/user38/SergantSwaggBase/Projects/CraveCircle/` were updated:

1. **`CraveCircle.md`**:
   * Header table updated to list `https://github.com/ag1170-pixel/CraveCircle-IOS_App` as the primary iOS repo.
   * Added `## 2026-09-03 — App Store Legal & Support In-App Integration` log summarizing the files changed, data truth, and verification.
2. **`iOS-Architecture-and-Methods.md`**:
   * Added `## 13. App Store Legal & Support In-App Integration — 2026-09-03` detailing static endpoints, `ProfileScreen` UI rows, `IdentifiableURL` sheet presentation mechanics, and App Store guideline mapping.

---

## 4. Git & Build Status

* **Build Verification:**
  ```bash
  xcodebuild -project AICookBook.xcodeproj -scheme AICookBook -destination 'generic/platform=iOS' -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO build
  ```
  **Result:** `** BUILD SUCCEEDED **` (0 errors, 0 warnings).
* **Git Remote:**
  * `origin`: `git@github.com:ag1170-pixel/CraveCircle-IOS_App.git`
  * `crave-app`: `git@github.com:ag1170-pixel/CraveCircle-IOS_App.git`
* **Commit:** `d9d3647` on `main` pushed to `ag1170-pixel/CraveCircle-IOS_App.git`.

---

## 5. Next Step: Web Plumbing (`cravecircle.cc`)

The website repository is **`ag1170-pixel/Crave.circle_heropage`** (Next.js 16 app deployed on Vercel at `cravecircle.cc`).
The remaining task is to:
1. Add routes `src/app/(marketing)/privacy/page.tsx`, `src/app/(marketing)/terms/page.tsx`, and `src/app/(marketing)/support/page.tsx`.
2. Populate them with the copy from `POLICIES_CraveCircle.md`.
3. Replace the 5 placeholders:
   * `[SUPPORT_EMAIL]`
   * `[LEGAL_ENTITY]`
   * `[CONTACT_ADDRESS]`
   * `[JURISDICTION]`
   * `[EFFECTIVE_DATE]`
4. Deploy to Vercel so the live URLs resolve 200 for App Store Connect submission.
