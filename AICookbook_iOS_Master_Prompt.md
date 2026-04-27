# AICookbook — iOS App Master Development Prompt

---

## 0. What You Are Building

A native SwiftUI iOS application called **AICookbook** that transforms Instagram Reels into structured, cookable recipes. Users paste a reel URL, the backend AI pipeline extracts the recipe, and the app presents it beautifully with a cook-mode checklist, grocery list, social sharing, and collections.

The app targets **iOS 17+**, uses **SwiftUI exclusively** (no UIKit unless required for system APIs), follows **MVVM + async/await**, and connects to a single backend service (go-api). There is **no local AI** — all intelligence is server-side.

---

## 1. Design Language (Non-Negotiable)

Your entire application must derive from the UI shown in the provided mockups. Extract and follow this DNA precisely:

### 1.1 Visual Principles
- **Dark-first, photo-dominant.** Recipes lead with large full-bleed food photography. The UI recedes; the food leads.
- **Flat and typographic.** No gradients, no drop shadows on UI elements, no decorative flourishes. Heavy weight type does the visual lifting.
- **Single accent.** Use a warm yellow-green (`#D4F73F` or calibrate from the "LETS COOK!" button in the mockup) as the sole accent. Everything else is white, off-white, mid-grey, and near-black.
- **Generous negative space.** Section titles like "COLLECTIONS >" and "RECIPES >" use oversized bold type with arrow chevrons — editorial, not app-like.
- **Pill buttons.** CTAs use rounded rect pill shapes with no border — filled primary, outlined secondary.
- **Segmented tabs.** The Ingredients/Directions toggle is a native-style pill segmented control inside the recipe detail, not a tab bar.

### 1.2 Typography
- **Display / Section Headers:** SF Pro Display, Black or Heavy weight, uppercase tracking (`COLLECTIONS >`, `RECIPES >`, `WHATS COOKING!?`)
- **Recipe Titles:** SF Pro Display, Bold, 24–28pt, mixed case
- **Body / Ingredient Lines:** SF Pro Text, Regular, 16pt
- **Step Numbers:** Monospaced or SF Pro Mono, small, styled like `01`, `02`
- **Meta line (Prep / Cook):** SF Pro Text, Regular, 13pt, separator `|`
- **Tab bar labels:** SF Pro Text, Medium, 10pt, uppercase

### 1.3 Color Tokens
```
Background:          #0F0F0F  (near-black)
Surface:             #1A1A1A  (card/sheet background)
Surface Elevated:    #252525
Separator:           #2E2E2E
Text Primary:        #FFFFFF
Text Secondary:      #8A8A8A
Text Tertiary:       #555555
Accent:              #D4F73F  (yellow-green, "LETS COOK!" button)
Checked/Done:        #555555  (strikethrough text, muted)
Destructive:         #FF453A  (system red)
```

### 1.4 Component Patterns
- **Recipe Card:** Full-bleed image, title bottom-left, creator handle bottom-left below title, no explicit card border — images tile edge to edge in a 2-column grid
- **Collection Row:** Horizontal scroll of square thumbnails, header as large bold label + " >" arrow
- **Nav Bar:** Transparent over hero images, white icons, standard back chevron
- **Bottom Tab Bar:** Dark frosted glass blur, 5 tabs: HOME / CREATORS / KITCHEN / PROFILE / Search (search is rightmost icon-only)
- **Import Sheet:** Bottom sheet with "WHATS COOKING!?" header, text field, "Paste Link" secondary button, "LETS COOK!" filled yellow-green pill — matches mockup exactly
- **Step Item:** Number prefix bold, text body, checkbox trailing — full-width tap target with subtle separator
- **Ingredient Item:** Bullet radio circle leading, text, strikethrough + grey when checked

---

## 2. Backend Integration Contract

### 2.1 Base URL
```
http://localhost:8000   // development (via Cloudflare Tunnel or direct)
https://<your-domain>  // production
```
All endpoints require `Authorization: Bearer <supabase_access_token>` except `GET /health`.

### 2.2 Authentication
- Auth is handled by **Supabase Auth** (email + password, password grant)
- **Supabase Auth endpoint:** `POST https://<project>.supabase.co/auth/v1/token?grant_type=password`
- After sign-in, store `access_token` and `refresh_token` securely in **Keychain** (never UserDefaults)
- On every request: attach `Authorization: Bearer <access_token>`
- On `401`: attempt token refresh; if refresh fails, clear keychain and route to login
- Never store or use the `service_role` key in the iOS app

### 2.3 Network Layer Architecture
Build a single `APIClient` actor:
```
APIClient (actor)
├── authToken: String (from Keychain)
├── func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
├── func upload(...) async throws
└── TokenRefresher (handles 401 retry once)
```
- Use `URLSession` with async/await
- All models: `Codable` structs with `snake_case` → `camelCase` key mapping via `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`
- Wrap all errors in a typed `APIError` enum: `.unauthorized`, `.notFound`, `.forbidden`, `.serverError(String)`, `.networkError(Error)`, `.decodingError(Error)`

### 2.4 Response Quirks (Critical)
Some endpoints return **arrays even for single-object responses**. Build a helper:
```swift
// Use this pattern for endpoints known to return arrays
func decodeSingle<T: Decodable>(_ data: Data) throws -> T {
    // Try object first, fall back to first element of array
}
```
Affected endpoints: `GET /recipes/{id}`, `GET /reels/import/{jobId}`

### 2.5 Complete Endpoint Map

#### Health
| Method | Path | Auth | Notes |
|--------|------|------|-------|
| GET | /health | No | App startup check |

#### Auth (direct Supabase, not go-api)
| Method | Path | Notes |
|--------|------|-------|
| POST | /auth/v1/signup | Supabase URL |
| POST | /auth/v1/token?grant_type=password | Supabase URL, returns access_token |

#### Profile
| Method | Path | Body | Returns |
|--------|------|------|---------|
| GET | /profile | — | UserProfile |
| PUT | /profile | {username, full_name, avatar_url} | UserProfile |

#### Reel Import
| Method | Path | Body | Returns |
|--------|------|------|---------|
| POST | /reels/import | {"url": String} | {job_id, poll, status} |
| GET | /reels/import/{jobId} | — | ImportJob (array, take first) |

#### Recipes
| Method | Path | Params/Body | Returns |
|--------|------|-------------|---------|
| GET | /recipes | ?limit=&offset= | [Recipe] |
| GET | /recipes/friends | ?friend_id= | [Recipe] |
| GET | /recipes/{id} | — | Recipe (array, take first) |
| PATCH | /recipes/{id} | Partial Recipe fields | Recipe |
| DELETE | /recipes/{id} | — | 204 |

#### Checklist
| Method | Path | Body |
|--------|------|------|
| GET | /recipes/{id}/checklist | — |
| PATCH | /recipes/{id}/checklist/{itemId} | {"checked": Bool} |

#### Grocery List
| Method | Path | Body |
|--------|------|------|
| POST | /grocery-list/{recipeId} | — |
| GET | /grocery-list | — |
| PATCH | /grocery-list/{itemId} | {"checked": Bool} |

#### Friends
| Method | Path | Body |
|--------|------|------|
| POST | /friends/request | {"friend_id": String} |
| GET | /friends/requests | — |
| POST | /friends/requests/{id}/accept | — |
| POST | /friends/requests/{id}/reject | — |
| DELETE | /friends/{friendId} | — |

#### Collections
| Method | Path | Body |
|--------|------|------|
| POST | /collections | {name, is_shared?, members?[]} |
| GET | /collections | — returns {as_owner, as_member} |
| POST | /collections/{id}/recipes | {"recipe_id": String} |
| DELETE | /collections/{id}/recipes/{recipeId} | — |
| POST | /collections/{id}/members | {user_id, can_edit} |
| DELETE | /collections/{id}/members/{userId} | — |

---

## 3. Data Models (Swift Structs)

```swift
// All use Codable with .convertFromSnakeCase

struct UserProfile: Codable, Identifiable {
    let id: String
    var username: String?
    var fullName: String?
    var avatarUrl: String?
}

struct ImportJob: Codable, Identifiable {
    let id: String
    let status: ImportStatus
    let errorMessage: String?
    let recipeId: String?
    let shortcode: String?
    let createdAt: Date?
    let updatedAt: Date?
}

enum ImportStatus: String, Codable {
    case queued, downloading, transcribing, extracting, done, error
    
    var displayLabel: String { /* user-facing stage label */ }
    var isTerminal: Bool { self == .done || self == .error }
}

struct Recipe: Codable, Identifiable {
    let id: String
    let ownerId: String
    var title: String
    var description: String?
    var prepTime: String?
    var cookTime: String?
    var servings: Int?
    var ingredients: [IngredientGroup]
    var directions: [DirectionStep]
    var videoUrl: String?
    var thumbnailUrl: String?
    var videoSignedUrl: String?
    var thumbnailSignedUrl: String?
    var ownerUsername: String?
    var ownerAvatar: String?
    var authorName: String?
    var authorUsername: String?
    var sourceReel: String?
    var createdAt: Date?
}

struct IngredientGroup: Codable {
    var groupName: String?
    var items: [String]
}

struct DirectionStep: Codable {
    var stepIndex: Int
    var text: String
}

struct ChecklistItem: Codable, Identifiable {
    let id: String
    let itemType: String   // "ingredient" or "direction"
    let itemText: String
    let stepIndex: Int?
    var checked: Bool
    let lastReset: Date?
}

struct GroceryItem: Codable, Identifiable {
    let id: String
    let ingredientName: String
    var checked: Bool
    let recipeId: String?
    let addedAt: Date?
}

struct FriendRequest: Codable, Identifiable {
    let id: String
    let requesterId: String
    let addresseeId: String
    let status: String
    let createdAt: Date?
}

struct Collection: Codable, Identifiable {
    let id: String
    let name: String
    let ownerId: String
    let isShared: Bool?
    let createdAt: Date?
    var recipes: [Recipe]?
    var members: [CollectionMember]?
}

struct CollectionMembership: Codable {
    let asOwner: [Collection]
    let asMember: [Collection]
}

struct CollectionMember: Codable {
    let userId: String
    let canEdit: Bool
}
```

---

## 4. App Architecture

### 4.1 Project Structure
```
AICookbook/
├── App/
│   ├── AICookbookApp.swift
│   └── AppEnvironment.swift          // DI container
├── Network/
│   ├── APIClient.swift
│   ├── Endpoints.swift
│   ├── TokenStore.swift              // Keychain wrapper
│   └── SupabaseAuthClient.swift
├── Models/
│   └── (all Codable structs above)
├── Features/
│   ├── Auth/
│   │   ├── AuthViewModel.swift
│   │   ├── LoginView.swift
│   │   └── SignUpView.swift
│   ├── Home/
│   │   ├── HomeViewModel.swift
│   │   └── HomeView.swift
│   ├── Import/
│   │   ├── ImportViewModel.swift
│   │   ├── ImportSheetView.swift
│   │   └── ImportProgressView.swift
│   ├── Recipe/
│   │   ├── RecipeDetailViewModel.swift
│   │   ├── RecipeDetailView.swift
│   │   ├── IngredientsView.swift
│   │   ├── DirectionsView.swift
│   │   └── EditRecipeView.swift
│   ├── Kitchen/
│   │   ├── KitchenViewModel.swift   // checklist
│   │   └── KitchenView.swift
│   ├── Grocery/
│   │   ├── GroceryViewModel.swift
│   │   └── GroceryView.swift
│   ├── Social/
│   │   ├── FriendsViewModel.swift
│   │   ├── FriendsView.swift
│   │   └── FriendsFeedView.swift
│   ├── Collections/
│   │   ├── CollectionsViewModel.swift
│   │   ├── CollectionsView.swift
│   │   └── CollectionDetailView.swift
│   └── Profile/
│       ├── ProfileViewModel.swift
│       └── ProfileView.swift
├── Components/
│   ├── RecipeCard.swift
│   ├── CollectionThumbnail.swift
│   ├── ChecklistRow.swift
│   ├── GroceryRow.swift
│   ├── PillButton.swift
│   ├── SegmentedPicker.swift
│   ├── AsyncHeroImage.swift
│   ├── SkeletonView.swift
│   └── ImportProgressTimeline.swift
├── Extensions/
│   ├── Color+App.swift
│   ├── Font+App.swift
│   └── View+Skeleton.swift
└── Resources/
    └── Assets.xcassets
```

### 4.2 State Management
- **ViewModels** are `@Observable` classes (Swift 5.9 Observation framework)
- **App-level state** (auth session, current user) in `AppEnvironment` passed via `.environment()`
- **No Redux, no TCA** — MVVM with async/await is sufficient
- Use `@MainActor` on all ViewModel methods that update state
- All API calls in `Task { }` blocks within ViewModels, never in View body

### 4.3 Navigation
- Use `NavigationStack` with a typed `NavigationPath`
- Root router lives in `RootView` which switches between `AuthFlow` and `MainTabView` based on session state
- Sheet presentation for Import (bottom sheet)
- Full-screen cover for Cook Mode (Kitchen)

---

## 5. Screen-by-Screen Specifications

### 5.1 RootView
- On launch: restore Keychain token → `GET /health` → `GET /profile`
- If token invalid: show `LoginView`
- If valid: show `MainTabView`
- Loading state: splash with app logo (centered, white on black)

### 5.2 LoginView / SignUpView
- Minimalist: app name top, email + password fields, pill CTA
- "Sign Up" / "Log in" toggle link
- Error inline below fields
- No social auth (email only, matching backend)

### 5.3 MainTabView (Tab Bar)
5 tabs matching mockup bottom bar:
1. **HOME** — house icon
2. **CREATORS** — Instagram-style icon (friends' feed)
3. **KITCHEN** — chef hat icon (checklist/cook mode)
4. **PROFILE** — person icon
5. **Search** — magnifier, icon only (future feature, show empty state)

Tab bar: dark frosted glass `.ultraThinMaterial` with dark tint.

### 5.4 HomeView
Layout exactly matching mockup:
- **COLLECTIONS >** heading → horizontal scroll of square thumbnails (3+ visible)
- **RECIPES >** heading → 2-column grid of `RecipeCard`
- Pull to refresh
- Infinite scroll (pagination via `?limit=20&offset=n`)
- **FAB (Floating Action Button):** bottom-right, circular, accent yellow-green, crosshair/fork-knife icon → opens import sheet
- On FAB tap: present `ImportSheetView` as `.sheet` (bottom)

#### RecipeCard
- Full-bleed AsyncImage (thumbnail_signed_url, fallback thumbnail_url)
- Title text bottom-left, white, bold, 15pt, max 2 lines
- Creator handle below title, grey, 12pt
- Aspect ratio: 1:1 (square grid cells)
- On tap: navigate to `RecipeDetailView`

### 5.5 ImportSheetView
Exact replica of "WHATS COOKING!?" mockup:
- Drag indicator top
- Large bold header "WHATS COOKING!?" — black text on white sheet (light sheet against dark background)
- Subtitle hint text field: "Enter your new findings here!"
- Row: "Paste Link" secondary pill button (black outline) + "LETS COOK!" filled accent pill button
- On "Paste Link": read `UIPasteboard.general.string`, populate field
- On "LETS COOK!" tap: validate URL (must contain instagram.com/reel/), call POST /reels/import, dismiss sheet, show import progress

#### URL Validation
- Must match pattern: `instagram.com/reel/<shortcode>`
- Show inline error if invalid before hitting API

### 5.6 ImportProgressView
Presented as a non-dismissible loading screen or full-screen overlay after import starts:

**Visual:** vertical timeline of stages with animated indicators:
```
● Downloading reel...       [animated spinner or pulsing dot]
○ Transcribing audio...
○ Extracting recipe...
○ Done
```
- Active stage: accent color dot, label in white
- Pending stages: grey
- Complete stages: checkmark
- Poll every 3s initially, back off to 5s after 30s
- On `done` + `recipe_id`: auto-navigate to `RecipeDetailView`, dismiss progress
- On `error`: show error message, "Try Again" and "Cancel" buttons
- On app background: continue polling, show notification or badge on return

### 5.7 RecipeDetailView
This is the hero screen. Match mockups precisely:

**Hero Section (top ~45% of screen):**
- Full-bleed AsyncImage, edge to edge
- Gradient overlay bottom half (dark → transparent) — only gradient allowed in the app, it's on top of a photo
- Top-left: back chevron (white)
- Top-right: share icon + ellipsis menu (edit, delete if owner; add to collection)
- Bottom-left over image: creator avatar (circular, 32pt) + `@username`
- Bottom-right over image: "▷ Watch" pill button (links to original reel) + step counter `1/8`

**Below image (scrollable):**
- Title: 24pt Bold
- Meta: "Prep: 20 min | Cook: 25 min" — 13pt secondary
- Description: truncated to 3 lines, expand on tap (chevron right)
- Row: Servings pill (adjustable — see note) + Share pill
- Segmented control: **Ingredients | Directions**

**Ingredients tab:**
- Group headers (bold, 14pt) — e.g. "Tomato Sauce Base"
- Ingredient rows with leading radio circle, text, strikethrough + grey when checked (drives checklist)
- Checking an ingredient calls PATCH /recipes/{id}/checklist/{itemId}

**Directions tab:**
- Numbered steps: `01`, `02`, `03` prefix (monospaced, accent-colored number)
- Step text body
- Trailing checkbox
- Checking a step calls PATCH /recipes/{id}/checklist/{itemId}

**Note on servings:** The "2 Servings" pill opens a stepper popover. Scaling ingredient amounts client-side is a UI-only calculation (multiply amounts by ratio) — do not save to backend unless PATCH /recipes/{id} is triggered explicitly by user.

### 5.8 EditRecipeView
- Form-based: title field, prep/cook time fields, servings stepper
- Ingredients: editable list with add/remove rows
- Directions: editable list with reorder + add/remove
- Save calls PATCH /recipes/{id} with changed fields only (diff against original)
- Owner-only: if `recipe.ownerId != currentUserId`, do not surface this screen

### 5.9 KitchenView (Cook Mode)
Full-screen, dark background, slightly elevated card style:
- Back button top-left, recipe title top-center
- **Completion ring / progress bar** top: "5 of 12 done" style
- Two sections: Ingredients / Steps — scrollable unified list grouped by type
- Large tap targets (min 56pt row height) — kitchen context means possibly wet hands
- 24h reset notice: subtle footnote "Checklist resets daily"
- Data from GET /recipes/{id}/checklist, updates via PATCH

### 5.10 GroceryView (KITCHEN tab or separate)
- Group items by source recipe (show recipe name as section header if available)
- Filter chips: All | Pending | Done
- Large checkbox rows — same kitchen-friendly sizing
- Check/uncheck: optimistic toggle, rollback on error
- "Add from recipe" — navigates back to recipe detail with "Add to Grocery" CTA visible

### 5.11 FriendsView (CREATORS tab)
Two sub-tabs: **Feed | Requests**

**Feed sub-tab:**
- Same 2-column recipe grid as home, but from GET /recipes/friends
- Tap recipe card → RecipeDetailView (backend enforces friend-only access via accepted friendship)
- Filter by friend: dropdown or chip row of friend avatars

**Requests sub-tab:**
- Two sections: Incoming / Outgoing
- Incoming row: avatar + name + "Accept" (accent) / "Reject" (outlined) buttons
- Outgoing row: avatar + name + "Pending" label + "Cancel" button
- Add friend: search by username (future), or manual user ID input for now

### 5.12 CollectionsView
Two sections matching GET /collections response:
- **Owned by me:** horizontal cards with collection name + recipe count
- **Shared with me:** same layout, with "shared" badge

**Create Collection:**
- Plus button top-right
- Sheet: name field + is_shared toggle + optional member add

**CollectionDetailView:**
- Recipe grid inside collection
- Member list (owner sees manage controls)
- Add recipe: picker from user's own recipes
- Remove recipe / member: swipe-to-delete (owner only)

### 5.13 ProfileView
- Avatar (large, circular) + name + username
- Edit button → inline fields
- Stats row: recipe count, friend count, collection count
- Settings section: logout
- On logout: clear Keychain, route to LoginView

---

## 6. Cross-Cutting Concerns

### 6.1 Loading States
Every list screen uses **skeleton rows** while loading:
- Skeleton: `RoundedRectangle` with `.shimmer()` animation in `#252525` on `#1A1A1A`
- Never show empty state and skeleton simultaneously

### 6.2 Error States
Typed error messages — never show raw API error to user:
| API Error | User Message |
|-----------|-------------|
| 401 | "Session expired. Please log in again." |
| 403 | "You don't have access to this." |
| 404 | "Not found." |
| `{"error":"db"}` | "Something went wrong. Please try again." |
| Network | "Check your connection and retry." |

### 6.3 Empty States
- Home (no recipes): Large text "No recipes yet." + Import CTA button
- Friends feed (none): "Your friends haven't shared any recipes."
- Grocery (empty): "Your grocery list is empty." + "Browse recipes" link
- Collections (none): "Create your first collection."

### 6.4 Optimistic Updates
Apply for: checklist toggles, grocery toggles. Pattern:
1. Update local model immediately
2. Fire PATCH request async
3. On error: revert local model + show brief toast

### 6.5 Image Loading
- Use SwiftUI `AsyncImage` with a phased display (placeholder → loading shimmer → image)
- Cache via `URLCache` — set a large disk cache (200MB) for recipe imagery
- All signed URLs may expire — on 403 when loading image, refetch recipe detail to get fresh signed URL

### 6.6 Pagination
Pattern for all list screens:
```
@State var items: [Recipe] = []
@State var offset: Int = 0
@State var hasMore: Bool = true
@State var isLoadingMore: Bool = false
let limit = 20

// Trigger next page when last item appears
.onAppear { if item == items.last { loadMore() } }
```

### 6.7 Import State Machine
Use a dedicated `ImportViewModel` with explicit state enum:
```swift
enum ImportState {
    case idle
    case submitting
    case polling(jobId: String, status: ImportStatus)
    case done(recipeId: String)
    case failed(message: String)
}
```
- Store `jobId` in `AppStorage` (UserDefaults) so polling survives sheet dismissal
- Cancel polling `Task` with `task.cancel()` on screen disappear if user explicitly cancels
- Resume polling on relaunch if `AppStorage` contains an in-progress jobId

### 6.8 Accessibility
- All interactive elements: `.accessibilityLabel()`
- Recipe images: `.accessibilityLabel(recipe.title)`
- Checklist checkboxes: `.accessibilityValue(checked ? "Checked" : "Unchecked")`
- Minimum tap target 44×44pt everywhere

### 6.9 Security
- All tokens in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- HTTPS enforced via ATS (no `NSAllowsArbitraryLoads`)
- Never log tokens or user data to console in production
- Strip dev-only headers (`X-AICookbook-Dev-Key`) via build flag
- User-entered Instagram URLs: validate format client-side before any network call

---

## 7. Key UX Behaviors

### Servings Scaler
- "2 Servings" pill button in recipe detail opens a stepper
- Scaling is client-side UI math: parse ingredient amounts (regex numeric prefix), multiply by (newServings / baseServings), display recalculated text
- Do NOT write scaled values to backend unless user explicitly saves

### Watch Reel
- "▷ Watch" button: open `source_reel` URL in `SFSafariViewController` or deep link to Instagram
- If Instagram is installed, use `instagram://` scheme; fall back to Safari

### Share Recipe
- Share button: present `UIActivityViewController` with recipe title + thumbnail + a deep link URL (define URL scheme `aicookbook://recipe/{id}`)

### 24h Checklist Reset
- Detect `last_reset` date in checklist items
- If it's a new day and items show `checked: true` but `last_reset` is yesterday, the backend auto-resets — just refetch on screen appear
- Show subtle label: "Resets daily at midnight"

### Add to Collection
- Long press or ellipsis menu on recipe card → "Add to Collection"
- Sheet: list of user's collections with "Add" button per row
- Uses POST /collections/{id}/recipes

---

## 8. Third-Party Dependencies (Minimal)

Use Swift Package Manager only. Keep dependencies minimal:

| Package | Purpose |
|---------|---------|
| None required | All UI in SwiftUI, all networking in URLSession |
| Optional: Kingfisher | If AsyncImage performance is insufficient for image caching |
| Optional: Lottie | If animated import progress icons are desired |

Do **not** add Alamofire, RxSwift, Combine-heavy frameworks, or any UI component libraries. The design system is custom.

---

## 9. Testing Requirements

### Unit Tests
- `APIClient` request building (URL, headers, body encoding)
- `ImportViewModel` state machine transitions
- Servings scaler math
- URL validation logic (Instagram reel URL regex)
- `decodeSingle` helper (array vs object normalization)

### UI Tests (XCTest)
- Login flow happy path
- Import flow: submit URL → polling → recipe detail navigation
- Checklist toggle: optimistic update + visual state

### Manual Test Checklist
- [ ] Token refresh on 401 without user disruption
- [ ] Import polling survives app background/foreground cycle
- [ ] Checklist resets appear correctly day-over-day
- [ ] Grocery list optimistic toggle rollback on network failure
- [ ] Owner vs non-owner UI controls (edit/delete hidden for non-owners)
- [ ] Image signed URL refresh on 403

---

## 10. Build & Environment Configuration

### Schemes
- **Debug:** local go-api URL, verbose logging enabled
- **Release:** production URL, logging stripped

### Info.plist
```xml
<!-- Instagram deep link -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>instagram</string>
</array>
<!-- Custom URL scheme for deep links -->
<key>CFBundleURLSchemes</key>
<array>
    <string>aicookbook</string>
</array>
```

### Environment Variables (via xcconfig, not hardcoded)
```
API_BASE_URL = https://your-api-domain.com
SUPABASE_URL = https://yourproject.supabase.co
SUPABASE_ANON_KEY = eyJ...
```
Load via `Bundle.main.infoDictionary`.

---

## 11. Phase Delivery Order

Build in this order to have a working app at each phase:

**Phase 1 — Foundation**
- APIClient + TokenStore + Supabase Auth
- Login / Sign Up screens
- App skeleton with tab bar and empty views

**Phase 2 — Core Recipe Flow**
- HomeView with RecipeCard grid
- RecipeDetailView (ingredients + directions tabs)
- Pagination

**Phase 3 — Import Pipeline**
- ImportSheetView
- ImportProgressView with polling state machine
- Navigation on completion

**Phase 4 — Cook & Grocery**
- KitchenView / ChecklistView
- GroceryView with bulk-add + toggle

**Phase 5 — Social**
- FriendsView (feed + requests)
- Collections (list + detail + create)

**Phase 6 — Polish**
- Skeleton loading states
- Error/empty states
- Optimistic updates
- Accessibility pass
- Edit recipe
- Profile screen

---

## 12. What Not to Do

- **No UIKit** view controllers as root — SwiftUI only
- **No hardcoded secrets** — env config only
- **No gradients in UI chrome** — only over food photos
- **No third-party design libraries** — custom components only
- **No service key in app** — only anon key and user access token
- **No synchronous import wait** — always async job polling
- **No UserDefaults for tokens** — Keychain only
- **No retry on 403/404** — surface error immediately
- **No emoji in UI** — matches the flat, typographic design language

---

*This document is the single source of truth for the AICookbook iOS application. All implementation decisions should trace back to a section in this document.*
