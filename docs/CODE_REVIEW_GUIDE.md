# CraveCircle — Code Review Study Guide

How to explain the whole app, screen by screen: what each screen does, which SwiftUI tools it uses, and why we built it that way. Every claim here points at a real file so you can open it during the review.

---

## 0. The 30-second pitch (say this first)

> "CraveCircle turns a cooking reel from Instagram, TikTok, YouTube or Pinterest into a structured recipe in about 30 seconds, **on the iPhone itself**. It uses Apple's on-device speech model (SpeechAnalyzer) to transcribe the audio, Vision OCR to read text on screen, and Apple's Foundation Models LLM to turn that into a `Recipe`. Around that we built a Home feed, a TikTok-style Discover reel, a smart Grocery list, a hands-free Cook Mode, and a social Profile. The whole UI is SwiftUI, one shared `AppEnvironment` object holds the app's state, and Supabase is the backend."

---

## 1. Where the app starts: `@main`

**File: [AICookBook/AICookBookApp.swift](../AICookBook/AICookBookApp.swift) — line 143**

```swift
@main
struct CraveCircleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .onOpenURL { url in ... }
                .onChange(of: scenePhase) { _, phase in ... }
                .onAppear { ... }
        }
    }
}
```

The chain is the one from your notes: **App → Scene (`WindowGroup`) → View (`RootView`)**.

What each line does:

| Line | What it is | Why we did it |
|---|---|---|
| `@main` | Marks the app's entry point | iOS starts the app here |
| `struct CraveCircleApp: App` | Follows the `App` protocol | Its `body` is a `Scene`, not a `View` |
| `@StateObject private var environment = AppEnvironment()` | Creates the app's one shared data object, and owns it | Created once and kept alive for the whole app run |
| `.environmentObject(environment)` | Puts that object into the environment | Every screen below can read it with `@EnvironmentObject` without passing it by hand |
| `@UIApplicationDelegateAdaptor(AppDelegate.self)` | Plugs in an old-style UIKit `AppDelegate` | SwiftUI has no direct hooks for push notifications, home-screen quick actions ("Write to CEO", "Search", "Grocery"), or locking orientation. The AppDelegate handles those |
| `@Environment(\.scenePhase)` + `.onChange(of: scenePhase)` | App lifecycle | When the app comes back to `.active`, we refresh recipes, check for a reel shared from the Share Extension, and re-fetch the profile |
| `.onOpenURL` | Deep links | Handles `cravecircle://recipe/<id>`, `cravecircle://grocery`, and `https://cravecircle.cc/recipe/<id>` links. These come from widgets, shared links and the Share Extension |
| `init()` sets `URLCache.shared` | Image cache limits (16 MB RAM, 96 MB disk) | Recipe photos don't fill up the phone's storage |

There is no `ContentView.swift` (the Xcode template file was deleted). The real first screen is `RootView`.

There's a **second `@main`** at [CookingWidget/CookingWidgetBundle.swift:11](../CookingWidget/CookingWidgetBundle.swift). That's a separate target (the home-screen widget and the Live Activity), not the app. Each target gets its own entry point.

---

## 2. Big-picture architecture

```
CraveCircleApp (@main)
 └─ WindowGroup
     └─ RootView  ← decides which screen to show based on app state
         ├─ ProgressView        (appState == .loading)
         ├─ OnboardingView      (first launch, before login)
         ├─ LoginView           (appState == .signedOut)
         ├─ OnboardingView      (signed in but not onboarded)
         └─ MainTabView         (signed in)
              ├─ Tab: HomeScreen
              ├─ Tab: RecipeReelScreen  (Discover)
              ├─ Tab: GroceryScreen
              └─ Tab: ProfileScreen
              + floating "+" button → AddRecipeSheet
              + fullScreenCover → RecipeDetailPager (recipe page)
```

### The state model: one shared `ObservableObject`

**File: [AICookBook/AppEnvironment.swift](../AICookBook/AppEnvironment.swift)**

```swift
@MainActor
final class AppEnvironment: ObservableObject {
    @Published private(set) var appState: AppState = .loading
    @Published private(set) var recipes: [Recipe] = [] { didSet { persist(recipes, "recipes.json") } }
    @Published private(set) var groceryItems: [GroceryItem] = [] { didSet { persist(...) } }
    ...
}
```

**Important for the review.** Your MCQ notes teach the newer `@Observable` macro. **This app uses the older system that does the same job:**

| Your notes (new, iOS 17+) | What CraveCircle uses | Same idea |
|---|---|---|
| `@Observable class DataSource` | `class AppEnvironment: ObservableObject` | A shared model class |
| plain `var` property | `@Published var` | A change redraws the views that use it |
| `@State var ds = DataSource()` | `@StateObject var environment = AppEnvironment()` | The view that **creates and owns** the object |
| `.environment(ds)` | `.environmentObject(environment)` | Put it into the environment |
| `@Environment(DataSource.self) var ds` | `@EnvironmentObject var environment: AppEnvironment` | Read it from the environment, at any depth |
| (pass object in) | `@ObservedObject` | Watch an object someone else owns |

**If they ask "why a class and not a struct?"** It has to be **shared**. Home, Grocery, Profile and Recipe Detail all hold the *same* `AppEnvironment`. When Recipe Detail adds ingredients to the grocery list, the Grocery tab sees it straight away.

**Why `@MainActor`?** It holds UI data, and UI updates must happen on the main thread.

**Why `private(set)`?** Views can *read* `recipes` but can't change it directly. They have to call a method such as `toggleSaveRecipe(...)`. That keeps all the rules (guest checks, saving to disk, syncing to the server) in one place.

**Why `didSet { persist(...) }`?** Every time a list changes it's saved as JSON on disk ([LocalStore.swift](../AICookBook/LocalStore.swift)), so the app works offline and survives restarts. The write happens on a background `DispatchQueue` so the UI never freezes.

### Layers (who does what)

| Layer | Files | Job |
|---|---|---|
| **Views** | `HomeScreen`, `GroceryScreen`, … | Draw the screen and call `environment` methods |
| **State / logic** | `AppEnvironment.swift` | Single source of truth, business rules |
| **Models** | `Models.swift`, `Nutrition.swift` | `Recipe`, `GroceryItem`, `UserProfile`, … (structs) |
| **Networking** | `APIClient.swift` (an **actor**), `SupabaseData.swift`, `SupabaseAuthClient.swift` | Talk to the server |
| **Storage** | `LocalStore.swift` (JSON files), `TokenStore.swift` (**Keychain**), `@AppStorage` (UserDefaults) | Keep data saved on the phone |
| **On-device AI** | `OnDeviceTranscriber.swift`, `RecipeExtractor.swift`, `PhotoTextOCR.swift`, `VideoTextOCR.swift` | Speech → text, text → recipe |
| **Design system** | `DesignSystem.swift`, `Color+Theme.swift`, `DesignComponents.swift` | Colours, fonts, spacing, shared components |
| **Extensions (other targets)** | `ShareExtension/`, `CookingWidget/` | Share sheet import, widget, Live Activity |

### Models

**File: [AICookBook/Models.swift](../AICookBook/Models.swift)**

```swift
struct Recipe: Codable, Identifiable, Hashable { ... }
struct GroceryItem: Codable, Identifiable, Equatable { ... }
enum MealSlot: String, Codable, CaseIterable, Hashable, Identifiable { ... }
```

| Protocol | Why |
|---|---|
| `Identifiable` | Has an `id`, so `ForEach(recipes) { ... }` works without `id:` |
| `Hashable` | Needed for `NavigationLink(value:)`, `.sheet(item:)`, and putting items in a `Set` |
| `Codable` | Convert to/from JSON for the server and for disk |
| `CaseIterable` | `ForEach(MealSlot.allCases)` builds a picker of every option |

They're **structs** (value types) because a recipe is just data. Copying it is safe, and the shared state lives in `AppEnvironment` instead.

---

## 3. Design system ("how did you design it?")

**File: [AICookBook/DesignSystem.swift](../AICookBook/DesignSystem.swift)**

We didn't scatter colours and numbers through the code. Everything comes from **design tokens**:

```swift
enum AppTheme {
    static let background = Color(light: Color(hex: "FAF8F3"), dark: Color(hex: "16130F"))
    static let brand = Color(hex: "EA5A38")   // CraveCircle coral
    ...
}
enum AppSpacing { static let xs: CGFloat = 8; static let md: CGFloat = 16; ... }
enum AppRadius  { static let card: CGFloat = 16; static let sheet: CGFloat = 24 }
enum AppMotion  { static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78) ... }
enum AppFont    { ... serif wordmark + SF body ... }
```

- **Design idea:** "a living cookbook where the food leads." Warm cream background, white cards, a single coral brand colour (`#EA5A38`), a serif "CraveCircle" wordmark, and the food photo as the hero. It started from a Figma prototype.
- **Light + dark mode:** `Color(light:dark:)` in [Color+Theme.swift](../AICookBook/Color+Theme.swift) picks a colour based on the current appearance, and has high-contrast versions for accessibility.
- **`enum` with `static let`:** an enum with no cases is just a namespace. You can't create one by mistake.
- **Accessibility:** text colours meet a 4.5:1 contrast ratio, there's an accessibility label on every icon button, tap targets are at least 44×44, and animations switch off when `@Environment(\.accessibilityReduceMotion)` is true.

### Custom `ButtonStyle` and `ViewModifier`

[DesignComponents.swift:467](../AICookBook/DesignComponents.swift)

```swift
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { ... }
}
// the label shrinks to 96% while pressed, with a spring
```

Used as `.buttonStyle(PressableStyle())` on almost every button, so the whole app has the same "press" feel.

Custom **`ViewModifier`** (your notes, section 1): `LeadingEdgeBackModifier: ViewModifier` in [DesignComponents.swift:1064](../AICookBook/DesignComponents.swift). There are also small `View` extensions such as `.doodleScreenBackground()`, `.sectionLabelStyle()` and `.conditionalInvert()` (files named `View+*.swift`). That's the "nicer: add an extension" pattern from your notes.

---

## 4. RootView — the screen switcher

**File: [AICookBook/RootView.swift](../AICookBook/RootView.swift)**

```swift
struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    var body: some View {
        Group {
            if environment.appState == .loading { ProgressView() }
            else if environment.showPreAuthOnboarding { OnboardingView() }
            else if environment.appState == .signedOut { LoginView() }
            else if environment.needsOnboarding { OnboardingView() }
            else { MainTabView() }
        }
        .animation(.easeInOut(duration: 0.24), value: environment.appState)
        .task { await environment.bootstrap() }
        .alert("Something went wrong", isPresented: ...) { ... }
    }
}
```

- **"The screen is a function of the data."** We never say "go to the login screen". We change `appState`, and SwiftUI redraws the right screen.
- `.task { await environment.bootstrap() }` runs async startup work when the view appears. It checks the Keychain for a login token, fetches the profile from Supabase, and loads recipes.
- `.alert` shows any `errorMessage` from anywhere in the app.

### LoginView (same file)

- `@State private var email`, `password`, `isSignUpMode`: data owned by this view.
- `TextField`/`SecureField` with `$email`: **two-way bindings**.
- A **hand-built `Binding(get:set:)`** connects our custom `LimeSegmentedControl` (Log In / Sign Up) to the Bool `isSignUpMode`.
- "Continue with Google" is `Button { Task { await environment.signInWithGoogle() } }`. That's **`Task {}` to start async work from a button.**
- "Continue as Guest" lets people try the app first. Some actions (importing, commenting) then show a **guest wall** sheet that asks them to sign in.

---

## 5. MainTabView — the tab bar

**File: [AICookBook/RootView.swift](../AICookBook/RootView.swift) (`struct MainTabView`, around line 291). Tab enum: [BrandAndTabBar.swift](../AICookBook/BrandAndTabBar.swift)**

```swift
@State private var tab: AppTab = .home

TabView(selection: $tab) {
    Tab(value: AppTab.home)      { HomeScreen(showingImportSheet: importSheetBinding) } label: { Image(systemName: "house") }
    Tab(value: AppTab.discover)  { RecipeReelScreen(...) } label: { ... }
    Tab(value: AppTab.groceries) { GroceryScreen() } label: { ... }
    Tab(value: AppTab.profile)   { ProfileScreen() } label: { ... }
}
.tabBarMinimizeBehavior(.onScrollDown)
.overlay(alignment: .bottomTrailing) { if tab != .discover { importFAB } }
```

| Thing | Explanation |
|---|---|
| `TabView(selection: $tab)` + `Tab(value:)` | iOS 18+ tab style; selection bound to `@State` so we can **switch tabs in code** (quick actions, widgets) |
| `enum AppTab: CaseIterable, Hashable` | Tab values are enum cases, not magic numbers |
| **`NavigationStack` is inside each screen**, not around the TabView | Your notes' rule: each tab keeps its own back-history |
| `.tabBarMinimizeBehavior(.onScrollDown)` | iOS 26 "Liquid Glass" bar shrinks while scrolling |
| **Floating "+" button** in an `.overlay` | Import is an *action*, not a place, so it's a button, not a 5th tab. It's hidden on Discover so it doesn't cover the reel |
| `.simultaneousGesture(DragGesture...)` | Swipe left/right to change tabs; ignores swipes that start inside horizontal carousels (their frames are collected with a `PreferenceKey`) |
| Many `.sheet` / `.fullScreenCover` | Add Recipe, Add Grocery Item, CEO letter, NPS survey, guest wall, the recipe page |
| `.fullScreenCover(item: Binding(get: { environment.selectedRecipe }, ...))` | **Sheet driven by an optional**: when `selectedRecipe` becomes non-nil, the recipe page covers the screen |
| `importSheetBinding` (custom `Binding`) | **One gate** for the Add-Recipe sheet: if a guest tries to open it, show sign-in instead |
| `.onChange(of: environment.pendingTabSwitch)` | Other parts of the app request "go to Grocery" by setting a flag; the tab view reacts |

---

## 6. Home page

**File: [AICookBook/HomeScreen.swift](../AICookBook/HomeScreen.swift)**

**Purpose:** your library plus a social feed, with search built in.

**Layout, top to bottom:** brand bar (wordmark + notification bell) → search bar → *Your Library* row → *Fresh in your Circle* → *Suggested for you* grid. While you're typing, the sections are swapped for search suggestions or results.

```swift
struct HomeScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var showingImportSheet: Bool          // borrowed from MainTabView
    @State private var query = ""
    @State private var filters = RecipeFilters()
    @StateObject private var voiceSearch = VoiceSearchController()
    @FocusState private var searchFocused: Bool
    @AppStorage("recent_home_searches") private var recentSearchesCSV = ""
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack { topBar; searchSection; librarySection; freshSection; suggestedSection }
                }
                .refreshable { await environment.refreshRecipes() }
                .task { await environment.fetchSuggestedFeed() }
            }
            .navigationDestination(isPresented: $navigateToLibrary) { LibraryScreen() }
            .navigationDestination(isPresented: $showNotifications) { CircleNotificationsScreen() }
            .sheet(isPresented: $showShared) { SharedScreen() }
        }
    }
}
```

| Concept from your notes | Where on Home |
|---|---|
| `@Binding` | `showingImportSheet` is owned by `MainTabView`; Home's empty state can open it |
| `@State` | search text, filters, which sheet is showing |
| `@StateObject` | `VoiceSearchController` (mic search). Home creates and owns it |
| `@FocusState` | Puts the keyboard in the search box (the "Search" quick action uses this) |
| `@AppStorage` | Recent searches saved in UserDefaults |
| `LazyVGrid` with 2 `.flexible()` columns | Suggested-recipe and search-result grids |
| `ScrollView(.horizontal)` + `ForEach` | "Fresh in your Circle" and creators carousels |
| `ForEach(recipes)` | Works without `id:` because `Recipe` is `Identifiable` |
| `.refreshable` | Pull to refresh |
| `.task` / `.task(id: query)` | Load the feed when the screen appears; `task(id:)` **restarts when the query changes** and cancels the old one (we use it to debounce "search miss" logging) |
| `.navigationDestination(isPresented:)` | Push Library / Notifications |
| `ScrollViewReader` | Scroll up to the search bar in code |
| `.contextMenu` | Long-press a card for Save / Share / Add to Grocery |
| `PreferenceKey` (`HorizontalScrollFrameKey`, `CardFramesKey`) | Child views report their position **up** to the parent. Used so tab-swipes ignore carousels, and so the chef-cat mascot knows where the cards are |
| `GeometryReader` | Measuring those frames |
| `withAnimation(.spring(...))` | Filter chips, and the double-tap ❤️ burst in `CardLikeOverlay` |

**Reusable card views** in the same file: `FreshCard`, `LibraryCard`, `SuggestedGridCard`, `SuggestedRailCard`, `CreatorChip`, `EmptyRecipesState`. That's "build once, reuse with different data".

**Design decisions to mention:**
- The brand header is *inside* the scroll, so it scrolls away (like Instagram).
- Cards use a fixed frame + `.scaledToFill()` + clip **instead of `GeometryReader`**, which is slow in a grid.
- `CatCompanion`: a chef-hat cat mascot walks over the cards as an `.overlay`. `.scrollDisabled(catHeld)` stops the page scrolling while you drag it.
- Suggestions come from [RecommendationEngine.swift](../AICookBook/RecommendationEngine.swift), which uses your onboarding cuisines plus what you like, save and view (`logInteraction`).

---

## 7. Discovery page (Discover tab, the recipe reel)

**File: [AICookBook/RecipeReelScreen.swift](../AICookBook/RecipeReelScreen.swift)**

**Purpose:** a full-screen, swipe-up reel of recipes, like TikTok or Instagram Reels.

```swift
GeometryReader { geo in
    ScrollView(.vertical, showsIndicators: false) {
        LazyVStack(spacing: 0) {
            ForEach(reel) { r in ReelCell(recipe: r).frame(height: geo.size.height) }
        }
        .scrollTargetLayout()
    }
    .scrollTargetBehavior(.paging)          // snaps one card per swipe
    .scrollPosition(id: $currentID)          // which card is showing
    .refreshable { await environment.fetchSuggestedFeed(); refreshReel() }
}
.task { if reel.isEmpty { refreshReel() } }
.task(id: autoplay) { ... auto-advance ... }
```

| Concept | Why |
|---|---|
| **`LazyVStack` inside `ScrollView`** | Only builds cards as they come on screen. The reel can be long, and that's the "performance / long scrolling" answer |
| `.scrollTargetBehavior(.paging)` | Each swipe moves exactly one full card |
| `GeometryReader` | Each card is exactly the screen height |
| `@Binding var reel` / `currentID` | Owned by `MainTabView`, so your place in the reel **survives switching tabs** |
| `@AppStorage("reel_autoplay")` | User setting saved in UserDefaults |
| `ReelCell` (private struct) | One card: photo, title, Like / Save / Comment / Share rail |
| Double-tap → heart burst with `withAnimation(.spring)` | Instagram-style like |
| `ShareLink(item: shareURL)` | Native iOS share sheet with a `https://cravecircle.cc/recipe/<id>` link |
| `.sheet` for the "more" menu, report, comments | Comments sheet has its own `NavigationStack` |
| Double-tap the Discover tab icon | Jumps to a fresh card (`DiscoverTabSignal.token += 1`; reel reacts with `.onChange`) |

---

## 8. Recipe page (Recipe detail)

**File: [AICookBook/RecipeDetailScreen.swift](../AICookBook/RecipeDetailScreen.swift)**

**Purpose:** everything about one recipe: photo gallery, title, creator, servings scaler, **Ingredients / Directions** switch, and actions (Cook, Nutrition, Add to Grocery, Plan meal, Share, Edit, Delete).

**How it opens:** any card calls `environment.selectRecipe(recipe, in: list)`. `MainTabView` has a `.fullScreenCover(item:)` bound to `selectedRecipe`, so it appears. It shows a **`RecipeDetailPager`**, which lets you swipe sideways to the next recipe in the list you came from.

```swift
struct RecipeDetailScreen: View {
    @State private var recipe: Recipe
    @State private var servings: Int
    @State private var checkedIngredients: Set<String> = []
    @Binding var tab: Int                 // 0 = Ingredients, 1 = Directions (owned by the pager)
    @State private var showCook = false, showNutrition = false, showEdit = false, ...
    ...
    .fullScreenCover(isPresented: $showCook)      { FlashcardCookScreen(...) }
    .fullScreenCover(isPresented: $showNutrition) { NutritionScreen(...) }
    .sheet(isPresented: $showMealPlanner)         { MealPlanPickerSheet(...) }
    .sheet(isPresented: $showScaleRecipeSheet)    { ScaleRecipeSheet(...) }
    .sheet(isPresented: $showAddToGrocerySheet)   { AddToGrocerySheet(...) }
    .alert("Delete this recipe?", isPresented: $showDeleteConfirm) {
        Button("Delete", role: .destructive) { ... }
        Button("Cancel", role: .cancel) { }
    }
}
```

| Concept | Where |
|---|---|
| **Photo gallery = page-style TabView** | `TabView(selection: $galleryIndex) { ForEach(imgs.indices) ... }.tabViewStyle(.page(indexDisplayMode: .never))`. That's the "swipeable pages" from your notes |
| `@Binding var tab` | The Ingredients/Directions choice is owned by the **pager**, so it stays the same when you swipe to the next recipe |
| Many `Bool` `@State` → `.sheet` / `.fullScreenCover` | Each feature is its own screen |
| `.fullScreenCover` for Cook and Nutrition | Immersive; no swipe-down to close by accident |
| `.alert` with `role: .destructive` | Delete confirmation (red button) |
| `ForEach(Array(...enumerated()), id: \.offset)` | Numbered direction steps and ingredient groups |
| `Set<String>` in `@State` | Tick off ingredients and steps while cooking |
| `.contextMenu` | Long-press an ingredient to copy it |
| `.task(id: recipe.id)` | Fetch accurate nutrition each time a different recipe is shown |
| Servings stepper → [IngredientScaler.swift](../AICookBook/IngredientScaler.swift) | Scales "200g paneer" to "400g paneer" by parsing the numbers |
| `reduceMotion` / `reduceTransparency` | Accessibility: turn off animation and blur effects |

**Linked screens** you can mention:
- **Cook Mode:** [FlashcardCookScreen.swift](../AICookBook/FlashcardCookScreen.swift). One step per full-screen card, **forced landscape** (via `AppDelegate.orientationLock`). There's a `CookTimer: ObservableObject` for timers, and "Hey Crave" voice commands ("next", "back", "start timer") from [VoiceCommandController.swift](../AICookBook/VoiceCommandController.swift) using `SFSpeechRecognizer` + `AVAudioEngine`.
- **Nutrition:** [NutritionScreen.swift](../AICookBook/NutritionScreen.swift) + [Nutrition.swift](../AICookBook/Nutrition.swift). Macros per serving from a USDA-based food table (`OfflineFoodDB`, `NutritionEstimator`).
- **Edit:** [RecipeEditScreen.swift](../AICookBook/RecipeEditScreen.swift). **Comments:** [RecipeCommentsView.swift](../AICookBook/RecipeCommentsView.swift). **Share:** [RecipeShareSheet.swift](../AICookBook/RecipeShareSheet.swift).

---

## 9. Grocery page

**File: [AICookBook/GroceryScreen.swift](../AICookBook/GroceryScreen.swift). Sorting logic: [GrocerySort.swift](../AICookBook/GrocerySort.swift)**

**Purpose:** a shopping checklist built from your recipes. Items can be grouped **by recipe** or **by supermarket aisle** (produce, dairy, pantry, meat, spices).

```swift
struct GroceryScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selectedDish: String? = nil        // nil = show all dishes
    @AppStorage("grocery_sort_mode") private var sortModeRaw = GrocerySortMode.recipe.rawValue

    private var groups: [(dish: String, items: [GroceryItem])] { GrocerySort.groupedByDish(environment.groceryItems) }
    private var progress: Double { total == 0 ? 0 : Double(checked) / Double(total) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    header                       // progress ring + ShareLink + "mark all done"
                    if environment.groceryItems.isEmpty { GroceryEmptyState() }
                    else { sortBar; dishFilter; checklist }
                    addRow
                }
            }
            .task { await environment.loadGroceryList() }
        }
    }
}
```

| Concept | Where |
|---|---|
| **Computed properties** (`groups`, `shownItems`, `progress`) | We don't store the filtered list. It's worked out from the data every time, so it can never be out of date. Same as the `filtered` search example in your notes |
| `@AppStorage` | Sort mode remembered between launches |
| Segmented sort bar with `ForEach(GrocerySortMode.allCases)` | Recipe vs Aisle |
| Dish filter: `ScrollView(.horizontal)` of chips | `selectedDish` is an optional; `nil` means "All" |
| `ForEach(groups, id: \.dish)` | Key path ID, because a tuple isn't `Identifiable` |
| `ProgressRing` (custom view) | `Circle().trim(from: 0, to: progress)`: "3 of 10 picked up" |
| `ShareLink(item: shareText)` | Send the list to someone over Messages or WhatsApp |
| Tap a row → `withAnimation(AppMotion.snappy) { ... }` then `Task { await environment.toggleGroceryItem(...) }` | **The UI updates first** (instant), then it syncs to the server in the background (an "optimistic update") |
| `AddGroceryItemSheet` (same file) | Opened by the floating "+" on this tab; uses `@FocusState` so the keyboard opens straight away |
| `GroceryCat` overlay | The mascot again, sitting over the list rows |

**How items get here:** in Recipe Detail, "Add to grocery" calls `environment.addIngredientsToGrocery(recipe:servings:)`. That scales the quantities to your servings and labels each item with the recipe name. Because `groceryItems` is `@Published`, the Grocery tab updates immediately.

---

## 10. Profile page

**File: [AICookBook/ProfileScreen.swift](../AICookBook/ProfileScreen.swift)**

**Purpose:** your identity, stats, and every setting.

**Layout:** avatar, name and Edit Profile → a **2×2 stat grid** (Recipes / Liked / Friends / Collections) → Meal Plan → Studio / creator tools → settings rows (language, notifications, kitchen-cat toggle, server, clear cache, contact developer, the CEO letter, account).

```swift
struct ProfileScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @AppStorage(LanguagePrefs.key) private var langCode = ...
    @AppStorage("kitchen_cat_enabled") private var kitchenCatEnabled = true
    @State private var showEditProfile = false, showLanguagePicker = false, ...
    @State private var activeSafariURL: IdentifiableURL? = nil

    NavigationStack {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                NavigationLink { LibraryScreen() }     label: { statTile("12", "Recipes") }
                NavigationLink { FriendsScreen() }     label: { statTile("4", "Friends") }
                NavigationLink { CollectionsScreen() } label: { ... }
            }
            NavigationLink { MealPlanScreen() } label: { mealPlanRow }
            ...
        }
    }
    .sheet(isPresented: $showEditProfile) { ... }
    .sheet(item: $activeSafariURL) { item in SafariView(url: item.url) }
    .confirmationDialog("Contact Developer", isPresented: $showContactOptions) { ... }
}
```

| Concept | Where |
|---|---|
| `NavigationLink { Destination() } label: { ... }` | "Destination link" style (Way 1 in your notes) for Library, Friends, Collections, Meal Plan, Admin screens. Pushes give the native back button and swipe-back |
| `LazyVGrid` 2 columns | Stat tiles |
| `@AppStorage` | Language, kitchen cat on/off, server URL. Saved straight into UserDefaults |
| `.onChange(of: langCode)` | When you change language, download that language's on-device speech model |
| `.sheet(item: $activeSafariURL)` + `struct IdentifiableURL: Identifiable` | **Sheet from an optional**: an in-app browser for links |
| `.confirmationDialog` | "Contact Developer" choices (email / Instagram, …) |
| `@Environment(\.dismiss)` | In `AccountSheet`, `LanguagePickerSheet` and `DeleteAccountSheet`: close from inside |
| `@Binding var selection` in `LanguagePickerSheet` | Child sheet changes the parent's `@AppStorage` value |
| Multi-step delete flow (`@State var step = 0/1`) | `DeleteAccountScreen`: choice → reason → confirm. Temporary vs permanent delete |

**Role-based UI:** `UserProfile` has an `AccountRole` (user / creator / admin). Admins get extra rows that open [AdminRequestsScreen.swift](../AICookBook/AdminRequestsScreen.swift) and [AdminSignalsScreen.swift](../AICookBook/AdminSignalsScreen.swift). Users can apply to be a creator from [CreatorRequestSheet.swift](../AICookBook/CreatorRequestSheet.swift).

---

## 11. Onboarding pages

**File: [AICookBook/OnboardingView.swift](../AICookBook/OnboardingView.swift)**

**Purpose:** pitch the app before sign-in, learn your goals and cuisines (to personalise Home), and *teach* how to import a reel with animated mini-phone demos.

**How it works: one view, an enum of steps, a `switch`:**

```swift
@State private var step: Step = .welcome
@State private var goals: Set<Goal> = []
@State private var cuisines: Set<String> = []
private let cuisineColumns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

Group {
    switch step {
    case .welcome:          welcome
    case .goals:            goalsStep
    case .goalsAffirmation: goalsAffirmation
    case .goalDetail:       goalDetail
    case .recipeSources:    recipeSourcesStep
    case .howHeard:         howHeardStep
    case .cuisinesStep:     cuisinesStep
    case .awesome:          awesome
    case .tutorialShare, .tutorialPanel, .tutorialPickApp, .tutorialWebsite, .tutorialCamera, .tutorialImported: ...
    }
}
.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)))
```

| Concept | Why |
|---|---|
| `enum Step` + `switch` | A clear, ordered flow; "Next" does `withAnimation { step = next }` |
| **Why not `TabView(.page)`?** | Users can't swipe past a question they haven't answered, and we control the slide animation and back button ourselves |
| `.transition(.asymmetric(...))` | New page slides in from the right, old one leaves to the left |
| `Set<Goal>` in `@State` | Multi-select answers (tap toggles membership) |
| `enum Goal: String, CaseIterable, Identifiable` | `ForEach(Goal.allCases)` builds the options |
| **`GridItem(.adaptive(minimum: 104))`** | Cuisine chips: fit as many columns as the screen allows. More on iPad, fewer on a small iPhone |
| Progress bar + back chevron header | Shows how far along you are; 44×44 tap target |
| `PhoneReel`, `PhoneSharePanel`, `PhoneAppPicker`, `PhoneImportedRecipe` | Small custom views that draw a fake iPhone showing the import steps |
| End: `environment.completeOnboarding(cuisines:...)` | Saves answers to the profile and feeds `RecommendationEngine`. `RootView` then shows `MainTabView` automatically |

It appears **twice** in `RootView`: before login (`showPreAuthOnboarding`, first install) and after sign-up if `needsOnboarding` is true.

---

## 12. CEO page ("A message from our team")

**File: [AICookBook/CEOMessageScreen.swift](../AICookBook/CEOMessageScreen.swift)**

**Purpose:** a warm letter from the founder with a big **"Write to CEO"** button that opens the feedback form ([FeedbackFormView.swift](../AICookBook/FeedbackFormView.swift)). It's a direct line for user feedback.

```swift
struct CEOMessageScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFeedback = false

    var body: some View {
        NavigationStack {
            ScrollView { VStack { header; letterCard } }
            .safeAreaInset(edge: .bottom) { writeButton }     // button pinned at the bottom
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark") } }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFeedback) { FeedbackFormView() }
        }
    }
}
```

| Concept | Where |
|---|---|
| `@Environment(\.dismiss)` | The ✕ button closes the sheet |
| `.toolbar { ToolbarItem(placement: .topBarTrailing) }` | Close button in the top-right of the nav bar |
| `.safeAreaInset(edge: .bottom)` | The CTA stays pinned at the bottom while the letter scrolls |
| A sheet opened from a sheet | CEO letter → feedback form |
| `Text("A MESSAGE ") + Text("from")` | Joining `Text` values to mix fonts in one line (bold display + italic serif) |

**Three ways in:**
1. **Long-press the app icon → "Write to CEO"** (home-screen quick action). `AppDelegate.handleShortcut("writeCEO")` sets `env.pendingFeedback = true` → `MainTabView`'s `.onChange(of: environment.pendingFeedback)` → `.sheet { CEOMessageScreen() }`.
2. From Profile.
3. Same pattern as the other quick actions ("Search", "Grocery").

---

## 13. Adding a recipe (the core feature)

**Files: [AddRecipeSheet.swift](../AICookBook/AddRecipeSheet.swift), [ImportSheet.swift](../AICookBook/ImportSheet.swift), [ImportProgressScreen.swift](../AICookBook/ImportProgressScreen.swift), [AppEnvironment.swift](../AICookBook/AppEnvironment.swift) (`startImport`, `_importFromVideo`), [OnDeviceTranscriber.swift](../AICookBook/OnDeviceTranscriber.swift), [RecipeExtractor.swift](../AICookBook/RecipeExtractor.swift)**

You can add a recipe by pasting a reel link, picking a video, taking or picking a photo (OCR), importing from a website ([WebImportScreen.swift](../AICookBook/WebImportScreen.swift)), or writing one from scratch ([NewRecipeWizard.swift](../AICookBook/NewRecipeWizard.swift)).

**Reel → recipe pipeline:**

1. **Download:** our server fetches just the reel's **audio** (plus caption and cover image).
2. **Transcribe on the phone:** `SpeechAnalyzer` / `SpeechTranscriber` (iOS 26, runs on the Neural Engine). It guesses the spoken language from the caption.
3. **No narration?** Use **Vision OCR** to read text shown on screen in the video ([VideoTextOCR.swift](../AICookBook/VideoTextOCR.swift)).
4. **Extract with the on-device LLM** (Apple Foundation Models), using *guided generation*:
   ```swift
   @Generable struct GeneratedRecipe {
       @Guide(description: "A concise recipe title, 3–6 words.") var title: String
       @Guide(description: "Ingredient groups...") var ingredients: [GeneratedGroup]
       @Guide(description: "The cooking steps in order...") var directions: [String]
   }
   let session = LanguageModelSession(instructions: "...")
   ```
   The model returns a **typed Swift struct**, not loose text, so there's nothing to parse by hand. If the device has no Apple Intelligence, a simpler rule-based extractor takes over.
5. **Translate (optional)** into your chosen language.
6. Save, show a **"Recipe Ready!"** local notification, and update the **Live Activity** in the Dynamic Island.

**Progress UI:** `enum ImportFlowState` (idle → downloading → transcribing → extracting → done/failed) is `@Published`. `ImportToastBanner` (top of the tab view), `ImportProgressScreen`, and the Live Activity ([CookingImportActivity.swift](../AICookBook/CookingImportActivity.swift), `ActivityAttributes`) all draw from that one state.

**Share Extension:** [ShareExtension/ShareViewController.swift](../ShareExtension/ShareViewController.swift). In Instagram you tap Share → CraveCircle. The extension sends the link to the server and opens the app with `cravecircle://import?job=<id>`. `onOpenURL` in the `@main` struct catches that and resumes the progress UI.

---

## 14. Concurrency: where we used each tool

| Concept (your notes, section 11) | Where in CraveCircle |
|---|---|
| `async` / `await` | Everywhere networking happens: `await environment.refreshRecipes()`, `try await URLSession.shared.data(...)` |
| `.task { }` | `RootView` (bootstrap), `HomeScreen` (feed), `GroceryScreen` (load list), `RecipeReelScreen` |
| `.task(id:)` | Home search-miss logging, Recipe Detail nutrition. Restarts when the value changes |
| `Task { }` from a button | Login's Google button, grocery check-off sync |
| **`actor`** | **`actor APIClient`** ([APIClient.swift:3](../AICookBook/APIClient.swift)): one network client shared safely between tasks. Calls from outside use `await` |
| **`@MainActor`** | `AppEnvironment` (all UI state), `requestPushAuthorization()`, `GoogleAuthSession` |
| **`async let`** | [SupabaseData.swift:411](../AICookBook/SupabaseData.swift): fetch **likes and saves in parallel**, then `await (likesData, savesData)` |
| **`withTaskGroup`** | [AppEnvironment.swift:1890](../AICookBook/AppEnvironment.swift): **race** the translation request against a 25-second timer; take whichever finishes first, then `group.cancelAll()`. That's a timeout built from a task group |
| `Task.detached` | Image decoding and JSON encoding off the main thread (e.g. [DesignComponents.swift:174](../AICookBook/DesignComponents.swift)) so scrolling stays smooth |
| `withCheckedContinuation` | [OnDeviceTranscriber.swift](../AICookBook/OnDeviceTranscriber.swift): wraps the old callback-based `SFSpeechRecognizer.requestAuthorization` so we can `await` it |
| `Task.sleep` | Debouncing search, refreshing at roughly 0s, 30s and 90s after the app returns to the foreground |

---

## 15. Storage and security

| What | Where | Why |
|---|---|---|
| Login tokens | **Keychain**, [TokenStore.swift](../AICookBook/TokenStore.swift) | Secure, encrypted storage for secrets |
| Recipes, grocery, collections, comments | JSON in Application Support, [LocalStore.swift](../AICookBook/LocalStore.swift) | Offline cache; **one file set per user** (`AccountScope`) so two accounts on one phone don't mix |
| Small preferences | `@AppStorage` (UserDefaults) | Language, sort mode, autoplay, cat on/off |
| Backend | Supabase (Postgres + Auth + REST) via `SupabaseData` / `SupabaseAuthClient` | Accounts, likes, saves, friends, sharing |
| Images | `URLCache` with limits | Memory and disk stay bounded |

---

## 16. Other targets and extras (quick mentions)

- **Widget + Live Activity:** `CookingWidget/` (WidgetKit + ActivityKit). Quick-action tiles open `cravecircle://grocery`, `cravecircle://add` and so on.
- **Friends / Circle:** [FriendsScreen.swift](../AICookBook/FriendsScreen.swift), [AddFriendSheet.swift](../AICookBook/AddFriendSheet.swift), [SharedScreen.swift](../AICookBook/SharedScreen.swift), [CircleNotificationsSheet.swift](../AICookBook/CircleNotificationsSheet.swift).
- **Collections:** [CollectionsScreen.swift](../AICookBook/CollectionsScreen.swift), [CollectionDetailScreen.swift](../AICookBook/CollectionDetailScreen.swift).
- **Meal plan:** [MealPlanScreen.swift](../AICookBook/MealPlanScreen.swift). Plans a recipe for a day/slot and schedules a cook-reminder notification.
- **Studio (creator tools):** [StudioScreen.swift](../AICookBook/StudioScreen.swift). Drafts → publish.
- **Unit tests:** [AICookBookTests/LogicTests.swift](../AICookBookTests/LogicTests.swift). Tests the logic (ingredient scaling, grocery sorting and so on) without the UI.

---

## 17. Likely teacher questions with model answers

**Q: Where does your app start?**
`AICookBook/AICookBookApp.swift`, the `@main struct CraveCircleApp: App`. Its `body` is a `WindowGroup` scene that shows `RootView`, with our `AppEnvironment` injected using `.environmentObject`.

**Q: How do different screens share data?**
One `ObservableObject` class, `AppEnvironment`. It's created once with `@StateObject` in the App, put in the environment, and read with `@EnvironmentObject` in every screen. Its properties are `@Published`, so any screen that uses one redraws when it changes. (The newer equivalent is `@Observable` + `@Environment(Type.self)`.)

**Q: `@State` vs `@Binding`, show me one.**
`MainTabView` owns `@State var showingImportSheet`. `HomeScreen` takes `@Binding var showingImportSheet`, so Home's empty-state button can open the sheet owned by its parent. Another: `RecipeDetailScreen`'s `@Binding var tab` is owned by `RecipeDetailPager`.

**Q: Why NavigationStack inside each tab?**
So every tab keeps its own back-history and the tab bar stays visible.

**Q: How did you make the reel scroll one card at a time?**
A `LazyVStack` inside a vertical `ScrollView` with `.scrollTargetBehavior(.paging)`, each card sized to the screen with `GeometryReader`. Lazy, so only the visible cards are built.

**Q: Where did you use a grid?**
Home's suggestions (`LazyVGrid`, 2 `.flexible()` columns), Profile stats (2 flexible columns), Onboarding cuisines (`.adaptive(minimum: 104)` so it fits as many as the screen allows).

**Q: How do you present the recipe page?**
`.fullScreenCover(item:)` bound to the optional `environment.selectedRecipe`. Setting it to a recipe shows the page; dismissing sets it back to nil.

**Q: How do you avoid freezing the UI during import?**
Everything slow is `async`. Network goes through an `actor`, heavy encoding and decoding uses `Task.detached`, and the state object is `@MainActor`, so UI updates are always on the main thread.

**Q: Where's an actor? Why?**
`actor APIClient`: many parts of the app call the network at once, and the actor makes sure only one task at a time touches its internal state. That prevents data races.

**Q: Where's parallel work?**
`async let` for likes + saves in `SupabaseData`, and a `withTaskGroup` that races translation against a timeout.

**Q: How is the design consistent?**
Design tokens (`AppTheme`, `AppFont`, `AppSpacing`, `AppRadius`, `AppMotion`), a shared `PressableStyle` button style, custom view modifiers and reusable card components. Full light/dark and high-contrast support through `Color(light:dark:)`.

**Q: Why is Import a floating button and not a tab?**
It's an action, not a destination. A 4-icon glass tab bar stays clean, and the button changes with context: on Grocery it adds a grocery item instead.

**Q: What's private about the AI?**
Transcription (SpeechAnalyzer) and extraction (Foundation Models) both run on the device. The reel's words are never sent to a third-party AI.

---

### Honest notes (in case they ask "what would you improve?")
- `AppEnvironment.swift` is about 3,300 lines. Splitting it into smaller stores (GroceryStore, ImportStore, SocialStore) would make it easier to maintain.
- Moving from `ObservableObject` to `@Observable` would mean only the views that read a changed property redraw, instead of every view watching the object.
