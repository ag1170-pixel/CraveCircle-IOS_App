# iOS & SwiftUI Development Vault: Lessons Learned & Rules

This document serves as the master record of every major mistake made, the root cause, and the permanent rule established to prevent it in future app builds. 

## 1. Navigation & Routing
**Mistake:** Using `.sheet(isPresented:)` for secondary screens (like "Creator Requests" or settings pages) instead of pushing them.
**Problem:** Sheets slide up and can only be dismissed by swiping down or tapping a "Close" button. Users expect standard iOS behavior: swiping from the left edge to go back.
**Rule:** Use `NavigationLink` inside a `NavigationStack` for any screen that represents a deeper level of hierarchy. Reserve `.sheet` strictly for quick tasks (like a Share Sheet, creating a new item, or a modal alert).

## 2. Deep Linking & Sharing
**Mistake:** Using custom URL schemes (e.g., `cravecircle://recipe/123`) as the text users copy and share with friends on WhatsApp or Instagram.
**Problem:** Modern messaging apps aggressively block custom URL schemes for security/spam reasons. The link sends as plain, unclickable text.
**Rule:** ALWAYS share a standard `https://` web link (e.g., `https://cravecircle.cc/recipe/123`). 
*   **Best Practice:** Set up Apple Universal Links (`apple-app-site-association`) so iOS intercepts the link and opens the app natively.
*   **Fallback:** Host a tiny HTML file on the domain that instantly runs Javascript `window.location.replace("customscheme://...")` to bounce Safari into the app.

## 3. State Management & "Zero State"
**Mistake:** Using the main local database array (`environment.recipes`) to calculate the user's Profile stats (e.g., `environment.recipes.count` for "Your Recipes").
**Problem:** Because the app caches community recipes for the Home Feed, the user's profile showed "27 Recipes" the second they opened the app.
**Rule:** Strictly separate "Local App Cache" from "User Owned Data". Always create computed properties (e.g., `var myLibraryRecipes: [Recipe] { recipes.filter { isOwned || isSaved } }`) and use those for stats, ensuring new users truly start at 0.

## 4. Guest Mode Architecture
**Mistake:** Relying on `if currentUser == nil` to lock premium/auth-only features (like the Creator Studio).
**Problem:** Once we implemented unique local Guest IDs (creating a dummy `UserProfile` like `guest_8492` to track their temporary data), `currentUser` was no longer nil! The paywalls instantly broke and let guests in.
**Rule:** Never rely on `nil` for guest checks if your app generates temporary guest profiles. Create an explicit `var isGuest: Bool` that checks for `nil` OR a specific `"guest_"` ID prefix, and use that everywhere.

## 5. Paywalls & Data Leaks
**Mistake:** Protecting the button to open a recipe, but forgetting to protect the *swipe gesture* inside the full-screen recipe pager.
**Problem:** A guest could bypass the 10-recipe limit by opening one free recipe and simply swiping left endlessly.
**Rule:** When limiting content, intercept data access at the lowest possible level. Protect the gesture callbacks (`onSwitchRecipe`) just as rigorously as the UI buttons.

## 6. Hardcoded Testing Data
**Mistake:** Leaving placeholder data (e.g., `["recipe_butter_chicken"]`) in the `@Published` initializers for `likedRecipes` while testing the UI.
**Problem:** Every new user that installs the app automatically "likes" Butter Chicken. 
**Rule:** Never hardcode IDs into initial state. Initialize arrays as empty `[]`. If you need demo data for previews, inject it via a `#if DEBUG` preview wrapper or a specific `hydrateDemo()` function that never runs in production.

## 7. Accessibility (VoiceOver)
**Mistake:** Creating icon-only buttons using `Image(systemName: "xmark")` without providing text.
**Problem:** VoiceOver reads the literal system name ("xmark button"), confusing visually impaired users.
**Rule:** Every icon-only button must have an `.accessibilityLabel("Close")` or `.accessibilityLabel("Settings")` attached to it.

## 8. Animations & Motion Sensitivity
**Mistake:** Using default bouncy springs (`withAnimation(.spring)`) everywhere.
**Problem:** Fails Apple's accessibility guidelines for users with vestibular motion sensitivity.
**Rule:** Always read `@Environment(\.accessibilityReduceMotion) var reduceMotion`. If true, fall back to `.easeOut(duration: 0.2)` or `nil` instead of bouncy animations.

## 9. Distribution (No Apple Developer Account)
**Mistake:** Trying to use Tailscale to network the app for friends, requiring them to join a VPN just to use the app.
**Problem:** High friction, confusing for non-technical friends, and iOS limits VPN tunneling.
**Rule:** Use a Cloudflare Tunnel (`cloudflared`) on the homelab to safely expose the backend via a standard HTTPS domain. This completely eliminates VPN requirements, allowing the app to be sideloaded (via Xcode/Sideloadly) and used freely on cellular data anywhere in the world.

## 10. The "Ponytail" Lazy Dev Principle
**Rule:** Before writing any code, climb the ladder:
1. Does this need to be built? (YAGNI)
2. Does it already exist in the codebase?
3. Can the standard library do it?
4. Can native platform features do it?
5. Write the shortest, most boring, edge-case-correct diff. Delete over add.
