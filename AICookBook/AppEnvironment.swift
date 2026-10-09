import SwiftUI
import Foundation
import Combine
import UserNotifications
import NaturalLanguage
import ActivityKit

@MainActor
final class AppEnvironment: ObservableObject {
    enum AppState {
        case loading
        case signedOut
        case signedIn
    }

    @Published private(set) var appState: AppState = .loading
    @Published private(set) var currentUser: UserProfile?

    /// APNs device token (hex), captured by the AppDelegate. Held until we have a signed-in user,
    /// then uploaded so the server can push "your recipe is ready" for background share-imports.
    private var apnsDeviceTokenHex: String?
    private var apnsEnvironment: String = "sandbox"
    /// The user's chosen profile photo, stored on-device (persisted). Shown as their avatar.
    @Published private(set) var avatarImageData: Data? { didSet { persist(avatarImageData, "avatar.json") } }
    @AppStorage("guest_user_id") private var guestUserId: String = ""
    @AppStorage("onboarded_user_ids") private var onboardedUserIdsRaw: String = ""
    @AppStorage("deleted_recipe_ids") private var deletedRecipeIdsRaw: String = ""
    @Published private(set) var recipes: [Recipe] = [] { didSet { persist(recipes, "recipes.json") } }
    @Published private(set) var selectedRecipe: Recipe?
    @Published private(set) var importState: ImportFlowState = .idle {
        didSet { reflectImportInLiveActivity() }
    }
    /// The running "recipe cooking" Live Activity (Dynamic Island + Lock Screen), if any.
    private var cookingActivity: Activity<CookingImportAttributes>?
    @Published private(set) var groceryItems: [GroceryItem] = [] { didSet { persist(groceryItems, "grocery.json") } }
    @Published var groceryError: String?
    @Published var errorMessage: String?

    // Infinite scroll (paged from the backend as the user scrolls; harmless offline/local-only).
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMoreRecipes = true
    private var recipePage = 0
    private let recipePageSize = 20

    // Social & Follows
    @Published private(set) var followedCreators: Set<String> = [] { didSet { persist(Array(followedCreators), "followed_creators.json") } }
    @Published private(set) var savedRecipeIds: Set<String> = []
    
    // Friends & Circle
    @Published private(set) var circleFriends: [FriendItem] = []
    @Published private(set) var incomingRequests: [FriendRequestItem] = []
    @Published private(set) var outgoingRequests: [FriendRequestItem] = []
    
    // Collections
    @Published private(set) var ownedCollections: [CollectionItem] = CollectionItem.ownedSamples { didSet { persist(ownedCollections, "owned_collections.json") } }
    @Published private(set) var sharedCollections: [CollectionItem] = CollectionItem.sharedSamples { didSet { persist(sharedCollections, "shared_collections.json") } }

    // Studio Drafts & Published
    @Published private(set) var studioDraftIds: Set<String> = ["recipe-hot-honey-chicken", "recipe-spicy-paneer-wrap"] { didSet { persist(Array(studioDraftIds), "studio_drafts.json") } }
    
    // Notifications & Activity
    @Published private(set) var circleNotifications: [CircleNotificationItem] = CircleNotificationItem.samples

    // Recipe Comments
    @Published private(set) var recipeComments: [String: [RecipeComment]] = RecipeComment.defaultSamples

    let config: AppConfig
    private let tokenStore: TokenStore
    private let authClient: SupabaseAuthClient
    private let apiClient: APIClient
    private var importTask: Task<Void, Never>?

    /// Guards on-disk autosave: property `didSet`s only persist AFTER `hydrateLocal()` has loaded
    /// the saved state, so loading doesn't immediately overwrite the files.
    private var hydrated = false
    private func persist<T: Encodable>(_ value: T, _ file: String) {
        if hydrated { LocalStore.save(value, to: file) }
    }

    init(
        config: AppConfig = .current,
        tokenStore: TokenStore = TokenStore()
    ) {
        self.config = config
        self.tokenStore = tokenStore
        self.authClient = SupabaseAuthClient(config: config, tokenStore: tokenStore)
        self.apiClient = APIClient(config: config, tokenStore: tokenStore)
        self.supabase = SupabaseData(config: config, tokenStore: tokenStore)
        AppEnvironment.shared = self
    }

    /// Weak handle so the UIApplicationDelegate (APNs token / push tap) can reach the live
    /// environment without threading it through the view tree.
    static weak var shared: AppEnvironment?

    private let supabase: SupabaseData

    /// Load the persisted library (recipes/collections/grocery/flags) from disk, merging any new
    /// bundled sample recipes by id so content updates still appear. Runs once, before autosave arms.
    private func hydrateLocal() {
        let saved = LocalStore.load([Recipe].self, from: "recipes.json") ?? []
        let localDeleted = deletedRecipeIds
        var merged = saved.filter { !localDeleted.contains($0.id) }
        for (i, r) in merged.enumerated() {
            if let fresh = Recipe.placeholderRecipes.first(where: { $0.id == r.id }) {
                merged[i] = fresh
            }
        }
        let savedIds = Set(merged.map(\.id))
        for sample in Recipe.placeholderRecipes where !savedIds.contains(sample.id) { merged.append(sample) }
        recipes = merged

        ownedCollections = LocalStore.load([CollectionItem].self, from: "owned_collections.json") ?? []
        sharedCollections = LocalStore.load([CollectionItem].self, from: "shared_collections.json") ?? []
        groceryItems = LocalStore.load([GroceryItem].self, from: "grocery.json") ?? []
        if let drafts = LocalStore.load([String].self, from: "studio_drafts.json") { studioDraftIds = Set(drafts) }
        if let follows = LocalStore.load([String].self, from: "followed_creators.json") { followedCreators = Set(follows) }
        sharedLog = LocalStore.load([SharedRecipeRecord].self, from: "shared_log.json") ?? []
        if let unsynced = LocalStore.load([String].self, from: "unsynced_recipes.json") { unsyncedRecipeIds = Set(unsynced) }
        if let cuisines = LocalStore.load([String].self, from: "preferred_cuisines.json") { preferredCuisines = Set(cuisines) }
        avatarImageData = LocalStore.load(Data.self, from: "avatar.json")
        pendingInteractions = LocalStore.load([InteractionEvent].self, from: "pending_interactions.json") ?? []
        interactionHistory = LocalStore.load([InteractionEvent].self, from: "interaction_history.json") ?? []

        // These were saved to UserDefaults but never read back — fix the round-trip here.
        let defaults = UserDefaults.standard
        if let s = defaults.array(forKey: "saved_recipe_ids") as? [String] { savedRecipeIds = Set(s) }
        if let l = defaults.array(forKey: "liked_recipe_ids") as? [String] { likedRecipeIds = Set(l) }

        hydrated = true
    }

    func bootstrap() async {
        #if DEBUG
        _ = CraveCircleInvariantChecks._runChecks
        #endif
        hydrateLocal()   // load the persisted library (recipes/collections/grocery) before anything else

        guard tokenStore.readAccessToken() != nil else {
            appState = .signedOut
            return
        }

        // Prefer the real Supabase profile (id = auth uid, correct role) so admin/creator persists
        // across launches; fall back to the homelab profile, then a generic user.
        if let profile = await supabase.fetchMyProfile() {
            currentUser = profile
            appState = .signedIn
            await refreshRecipes()
            await uploadDeviceTokenIfPossible()
            syncSharedUserId()
            return
        }
        do {
            currentUser = try await apiClient.fetchProfile()
            appState = .signedIn
            await refreshRecipes()
            await uploadDeviceTokenIfPossible()
            syncSharedUserId()
        } catch {
            if case APIError.unauthorized = error {
                tokenStore.clearSession()
                currentUser = nil
                appState = .signedOut
                return
            }
            currentUser = fallbackUser()
            appState = .signedIn
            await refreshRecipes()
        }
    }

    func signIn(email: String, password: String) async {
        do {
            _ = try await authClient.signIn(email: email, password: password)
            await finishAuthenticatedSession(email: email)
        } catch {
            appState = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    func signInWithGoogle() async {
        do {
            _ = try await authClient.signInWithGoogle()
            await finishAuthenticatedSession(email: nil)
        } catch GoogleAuthError.canceled {
            appState = .signedOut
        } catch {
            appState = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    private func finishAuthenticatedSession(email: String?) async {
        if let profile = await supabase.fetchMyProfile() {
            currentUser = profile
        } else {
            do { currentUser = try await apiClient.fetchProfile() }
            catch { currentUser = fallbackUser(email: email) }
        }
        if let user = currentUser {
            migrateGuestData(to: user.id)
        }
        resetPersonalizationIfUserChanged()
        appState = .signedIn
        if !hydrated { hydrateLocal() }
        await refreshRecipes()
        await uploadDeviceTokenIfPossible()   // token may have arrived before login
        syncSharedUserId()
    }

    func signUp(email: String, password: String) async throws {
        try await authClient.signUp(email: email, password: password)
    }

    /// Set the user's profile photo (stored on-device). Downscaled JPEG keeps it small.
    func setAvatar(_ data: Data) {
        avatarImageData = data
    }

    /// Edit display name / username. Updates locally right away and pushes to the profile row so it
    /// persists and is visible to others. Empty fields are ignored.
    func updateProfile(fullName: String?, username: String?) async {
        let name = fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        var handle = username?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let h = handle, h.hasPrefix("@") { handle = String(h.dropFirst()) }   // store without '@'
        if let cur = currentUser {
            currentUser = UserProfile(
                id: cur.id,
                username: (handle?.isEmpty == false) ? handle : cur.username,
                fullName: (name?.isEmpty == false) ? name : cur.fullName,
                avatarUrl: cur.avatarUrl,
                role: cur.role
            )
        }
        _ = await supabase.updateMyProfile(
            fullName: (name?.isEmpty == false) ? name : nil,
            username: (handle?.isEmpty == false) ? handle : nil,
            avatarUrl: nil
        )
    }

    func signOut() {
        hydrated = false          // don't let clearing state overwrite the on-disk library
        importTask?.cancel()
        tokenStore.clearSession()
        currentUser = nil
        recipes = []
        selectedRecipe = nil
        importState = .idle
        appState = .signedOut
        syncSharedUserId()   // clear the shared user id so shares aren't attributed to a signed-out user
    }

    // MARK: - Push notifications (background share-import "recipe ready")

    /// Called by the AppDelegate when APNs hands us a device token. Store it and upload if we already
    /// have a signed-in user (covers "token arrives after login"). DORMANT until APNs is configured
    /// on a paid Apple team — before that, registration fails and this is simply never called.
    func registerAPNSToken(_ tokenData: Data, environment: String) {
        apnsDeviceTokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
        apnsEnvironment = environment
        Task { await uploadDeviceTokenIfPossible() }
    }

    /// Upload the APNs token to the server, tied to the current (non-guest) user. Safe to call
    /// repeatedly; no-ops until we have both a token and a real signed-in user. Called on login and
    /// whenever a token arrives, so either ordering works.
    func uploadDeviceTokenIfPossible() async {
        guard let token = apnsDeviceTokenHex, !token.isEmpty,
              let user = currentUser, !isGuest, !user.id.isEmpty else { return }
        try? await apiClient.registerDevice(apnsToken: token, environment: apnsEnvironment)
    }

    /// Publish the signed-in user id to the Share Extension (via App Group) so a background
    /// share-import is attributed to this user and the "recipe ready" push targets only their
    /// devices. Cleared on sign-out / guest so we never push to the wrong person.
    func syncSharedUserId() {
        guard let d = UserDefaults(suiteName: Self.appGroupID) else { return }
        if let id = currentUser?.id, !isGuest, !id.isEmpty {
            d.set(id, forKey: "shared_user_id")
        } else {
            d.removeObject(forKey: "shared_user_id")
        }
        // Share Extension runs in a separate process and can't read the app's @AppStorage, so mirror
        // the chosen Recipe Language into the App Group — otherwise shared reels import in English.
        d.set(AppLanguage.preferred.rawValue, forKey: "shared_recipe_language")
    }

    /// A "recipe ready" push was tapped → open the finished recipe (already synced to the library),
    /// and refresh so it's present even if the sync hadn't landed yet.
    func handlePushOpen(_ userInfo: [AnyHashable: Any]) {
        Task {
            await refreshRecipes()
            if let id = userInfo["recipe_id"] as? String, !id.isEmpty {
                openRecipe(id: id)
            }
        }
    }

    func refreshRecipes() async {
        do {
            let fetched = try await apiClient.fetchRecipes(limit: 20, offset: 0)
            if !fetched.isEmpty {
                // MERGE, don't replace: keep every recipe already in the library (imports, on-device,
                // saved) and add any new ones from the feed. Replacing here was wiping freshly
                // imported reels out of the library on the next refresh/foreground.
                let localDeleted = deletedRecipeIds
                var merged = recipes
                for r in fetched where !merged.contains(where: { $0.id == r.id }) && !localDeleted.contains(r.id) {
                    merged.insert(r, at: 0)
                }
                recipes = merged
            } else if recipes.isEmpty {
                recipes = Recipe.placeholderRecipes
            }
        } catch {
            // The homelab feed is OPTIONAL (unreachable off-Tailscale / on cellular). Keep the local
            // library; seed samples only if we have nothing. Cloud recipes layer on via syncRecipes.
            // No modal error — this is an expected, recoverable miss, not something the user must act on.
            if recipes.isEmpty { recipes = Recipe.placeholderRecipes }
        }
        // Layer newly published cloud recipes on top + push any local edits.
        await syncRecipes()
    }

    /// Infinite scroll: append the next page of recipes as the user nears the end of the list.
    /// Pages from the backend when reachable; on error/empty it simply stops (local set stands),
    /// so there's no runaway loop offline. Recipe rows are tiny JSON; images are bounded by URLCache.
    func loadMoreRecipes() async {
        guard !isLoadingMore, hasMoreRecipes else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let next = try await apiClient.fetchRecipes(limit: recipePageSize, offset: recipePage * recipePageSize)
            if next.count < recipePageSize { hasMoreRecipes = false }
            let existing = Set(recipes.map(\.id))
            let fresh = next.filter { !existing.contains($0.id) }
            if !fresh.isEmpty { recipes.append(contentsOf: fresh) }
            recipePage += 1
        } catch {
            hasMoreRecipes = false   // no backend / offline → stop paging
        }
    }

    func addPreviewRecipe() {
        let next = Recipe(
            id: UUID().uuidString,
            ownerId: currentUser?.id ?? "local-user",
            title: "New Recipe Draft",
            description: "A local preview recipe while backend content is loading.",
            prepTime: "10 min",
            cookTime: "15 min",
            ingredients: [IngredientGroup(groupName: "Main", items: ["1 cup flour", "2 eggs"])],
            directions: [DirectionStep(stepIndex: 1, text: "Mix ingredients"), DirectionStep(stepIndex: 2, text: "Cook and serve")],
            thumbnailUrl: nil,
            ownerUsername: currentUser?.username ?? "@previewchef"
        )
        recipes.insert(next, at: 0)
    }

    /// The recipe list the detail pager should swipe through. Set alongside `selectedRecipe`
    /// whenever the caller has a narrower context (e.g. Library's Liked/Saved/Created tabs) so a
    /// left/right swipe stays inside what's actually on screen, not the full unfiltered library.
    
    @AppStorage("guest_recipes_viewed") private var guestRecipesViewed = 0
    @Published var showGuestPaywall = false

    /// ponytail: TEMPORARY testing bypass — set to false to restore the 10-recipe guest cap.
    private let guestPaywallDisabled = true

    func canViewRecipe() -> Bool {
        if isGuest && !guestPaywallDisabled {
            if guestRecipesViewed >= 10 {
                showGuestPaywall = true
                return false
            }
            guestRecipesViewed += 1
        }
        return true
    }

    @Published private(set) var recipeSwipeContext: [Recipe]?

    func selectRecipe(_ recipe: Recipe, in context: [Recipe]? = nil) {
        guard canViewRecipe() else { return }
        recipeSwipeContext = context
        selectedRecipe = recipe
        refreshAuthoritativeNutrition(for: recipe)
    }

    /// When a different account signs in on this device, start its on-device behavioral history
    /// fresh — interaction history is device-local, so without this a new user inherits the previous
    /// user's views and sees wrong "Because you viewed…" reasons. Their real behavior rebuilds it.
    private func resetPersonalizationIfUserChanged() {
        let key = "last_signed_in_user_id"
        let id = currentUser?.id ?? ""
        guard UserDefaults.standard.string(forKey: key) != id else { return }
        interactionHistory = []
        pendingInteractions = []
        suggestionReasons = [:]
        nutritionAttempted = []
        UserDefaults.standard.set(id, forKey: key)
    }

    private var nutritionAttempted = Set<String>()

    /// Compute nutrition once (off-main) for a recipe that has none yet — using the bundled offline
    /// USDA engine (no network, no API). Stores it (with the macro breakdown) so it persists and
    /// doesn't recompute every render. NEVER overwrites a recipe that already has nutrition (e.g. the
    /// accurate server value from a share import).
    func refreshAuthoritativeNutrition(for recipe: Recipe) {
        guard recipe.nutrition == nil, !nutritionAttempted.contains(recipe.id) else { return }
        nutritionAttempted.insert(recipe.id)
        Task.detached { [weak self] in
            let computed = NutritionEstimator.estimate(for: recipe)   // offline USDA-backed
            await MainActor.run {
                guard let self else { return }
                if let i = self.recipes.firstIndex(where: { $0.id == recipe.id }) {
                    self.recipes[i].nutrition = computed
                }
                if self.selectedRecipe?.id == recipe.id { self.selectedRecipe?.nutrition = computed }
            }
        }
    }

    /// Open a recipe by id — the target of a `cravecircle://recipe/<id>` deep link (Copy link / Share).
    /// Uses the local copy if present; otherwise pulls it from the cloud (RLS applies, so a
    /// followers-only recipe the viewer can't see simply won't open).
    func openRecipe(id: String) {
        if let local = recipes.first(where: { $0.id == id }) { selectRecipe(local); return }
        Task {
            guard let remote = await supabase.fetchRecipe(id: id) else { return }
            if !recipes.contains(where: { $0.id == id }) { recipes.insert(remote, at: 0) }
            selectRecipe(remote)
        }
    }

    /// Set by a pushed screen (e.g. Library, once it's cycled past its own last filter tab) to ask
    /// the root tab bar to switch main tabs. MainTabView observes this and clears it after acting.
    @Published var pendingTabSwitch: AppTab?

    /// Set by the "Search" Home-screen quick action: switch to Home AND focus the search field so the
    /// user lands straight on the keyboard-ready search box. HomeScreen observes and clears it.
    @Published var pendingSearchFocus = false

    func requestTabSwitch(_ tab: AppTab) {
        pendingTabSwitch = tab
    }


    func dismissRecipeDetail() {
        selectedRecipe = nil
        recipeSwipeContext = nil
    }

    /// Save edits to a recipe the user owns (updates the list + open detail).
    func updateRecipe(_ updated: Recipe) {
        // Upsert: edits update in place; a brand-new recipe (e.g. Studio "New") is inserted.
        if let i = recipes.firstIndex(where: { $0.id == updated.id }) { recipes[i] = updated }
        else { recipes.insert(updated, at: 0) }
        if selectedRecipe?.id == updated.id { selectedRecipe = updated }
        markRecipeDirty(updated.id)
        Task { await syncRecipes() }
    }

    // MARK: - Recipe cloud sync (offline-first)
    // Client-side "sync_status": ids of the user's own recipes changed locally but not yet pushed.
    // Persisted so an edit made offline still syncs after a restart. (Pattern from the DB study.)
    @Published private(set) var unsyncedRecipeIds: Set<String> = [] { didSet { persist(Array(unsyncedRecipeIds), "unsynced_recipes.json") } }

    func markRecipeDirty(_ id: String) { unsyncedRecipeIds.insert(id) }

    /// One-shot guard so the thumbnail backfill scan runs once per launch, not on every sync.
    private var didThumbnailBackfill = false

    /// Two-way sync with Supabase. PULL is additive — it brings in newly published recipes
    /// (creator/developer content) so the library shows updates, without clobbering local unsynced
    /// edits or removing local-only recipes. PUSH sends the user's own dirty recipes up (needs auth).
    func syncRecipes() async {
        // PULL — merge remote recipes in (add new, refresh existing that aren't locally dirty).
        if let remote = await supabase.fetchRecipes() {
            // Build the merged list locally, then assign ONCE — a per-iteration mutation would fire
            // the recipes didSet (persist) on every remote recipe.
            let localDeleted = deletedRecipeIds
            var merged = recipes
            var added = 0, changed = false
            for r in remote where !unsyncedRecipeIds.contains(r.id) && !localDeleted.contains(r.id) {
                if let i = merged.firstIndex(where: { $0.id == r.id }) {
                    if merged[i] != r { merged[i] = r; changed = true }
                } else {
                    merged.append(r); added += 1; changed = true
                }
            }
            if changed { recipes = merged }          // single assignment → one persist
            if added > 0 { hasMoreRecipes = true }   // new content available to scroll
        }
        // PUSH — send my own changed recipes up; clear the dirty flag only on success.
        if supabase.hasSession, let uid = currentUser?.id {
            // Backfill (once per session): recipes published before Storage upload still carry a
            // device-local cover in the cloud (unreachable to others → placeholder). Re-flag my own
            // local-cover recipes whose image file still exists so the upload path fixes them.
            if !didThumbnailBackfill {
                didThumbnailBackfill = true
                for r in recipes where r.ownerId == uid && !unsyncedRecipeIds.contains(r.id) {
                    guard let t = r.thumbnailUrl, !t.isEmpty, !t.hasPrefix("http") else { continue }
                    let fileURL = t.hasPrefix("file://") ? URL(string: t) : LocalStore.url(t)
                    if let fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
                        unsyncedRecipeIds.insert(r.id)
                    }
                }
            }
            // Personal use / legal: NEVER push a social-imported recipe to the shared cloud — those
            // stay private on the importer's device. Only a user's own original (non-social) recipes
            // sync up, and only creators' originals ever become public (see publishDraft).
            var dirty = recipes.filter {
                unsyncedRecipeIds.contains($0.id) && $0.ownerId == uid && !$0.isImportedFromSocial
            }
            if !dirty.isEmpty {
                // Make each cover shareable (device-local file -> public Storage URL) BEFORE it hits the
                // cloud, and mirror the rewritten URL locally so every surface uses the http cover.
                for i in dirty.indices {
                    if let publicURL = await uploadedThumbnailURL(for: dirty[i]) {
                        dirty[i].thumbnailUrl = publicURL
                        if let idx = recipes.firstIndex(where: { $0.id == dirty[i].id }) {
                            recipes[idx].thumbnailUrl = publicURL
                        }
                    }
                }
                if await supabase.upsertRecipes(dirty, ownerId: uid) {
                    unsyncedRecipeIds.subtract(dirty.map { $0.id })
                }
            }
        }
        // Pull shares (Sent + Received) so the "Shared with you" inbox stays current.
        await syncShares()
    }

    /// Upload a device-local cover (not http/https) to public Storage and return the public URL,
    /// or nil if there's nothing to upload. The heavy work — disk read + JPEG downscale — runs OFF
    /// the main actor (`Task.detached`) so a multi-recipe sync never blocks/hangs the UI.
    private func uploadedThumbnailURL(for recipe: Recipe) async -> String? {
        guard let s = recipe.thumbnailUrl, !s.isEmpty,
              !s.hasPrefix("http://"), !s.hasPrefix("https://") else { return nil }
        let fileURL = s.hasPrefix("file://") ? URL(string: s) : LocalStore.url(s)
        guard let fileURL else { return nil }
        let recipeId = recipe.id
        let payload: Data? = await Task.detached(priority: .utility) {
            guard let raw = try? Data(contentsOf: fileURL) else { return nil }
            // Shrink to a feed-sized JPEG so covers load fast for everyone (full frames are ~1–2 MB).
            return ImageDownscale.jpeg(from: raw, maxPixel: 720, quality: 0.6) ?? raw
        }.value
        guard let payload else { return nil }
        return await supabase.uploadThumbnail(data: payload, path: "\(recipeId).jpg", contentType: "image/jpeg")
    }

    /// True when the signed-in user owns this recipe (edit/delete are owner-only).
    func isOwner(of recipe: Recipe) -> Bool {
        currentUser?.id == recipe.ownerId
    }

    /// Instagram rule: you can delete your own library reel, never someone else's.
    /// Admin (the founder) can delete any recipe. Any reel imported onto this phone can be removed.
    func canDelete(_ recipe: Recipe) -> Bool {
        if currentUser?.role == .admin { return true }
        if isOwner(of: recipe) { return true }
        if recipe.isImportedFromSocial || recipe.sourceUrl != nil { return true }
        let isSample = Recipe.placeholderRecipes.contains(where: { $0.id == recipe.id })
        return !isSample
    }

    var canPublish: Bool { currentUser?.canPublish ?? false }

    // MARK: - Community MVP Logic Stubs
    
    @Published var sharedLog: [SharedRecipeRecord] = [] { didSet { persist(sharedLog, "shared_log.json") } }
    
    var communityFeed: [Recipe] {
        recipes.filter { isFollowing(creatorHandle: $0.ownerUsername ?? "") }
    }
    
    func canView(_ recipe: Recipe) -> Bool {
        if recipe.visibility == .everyone { return true }
        if isOwner(of: recipe) { return true }
        if let username = recipe.ownerUsername, isFollowing(creatorHandle: username) { return true }
        return false
    }
    
    func recordShare(recipeId: String, friend: FriendItem) {
        let recipe = recipes.first(where: { $0.id == recipeId })
        let record = SharedRecipeRecord(
            id: UUID().uuidString,
            recipeId: recipeId,
            fromUserId: currentUser?.id ?? "me",
            toUserId: friend.id.uuidString,
            createdAt: Date(),
            channel: "in-app",
            recipeTitle: recipe?.title,
            recipeThumbnail: recipe?.thumbnailUrl
        )
        sharedLog.insert(record, at: 0)
        // Deliver to the recipient in the cloud so it lands in their "Shared with you" inbox.
        // Best-effort: needs both to be real users (resolves the friend's @handle to a profile id).
        Task {
            if let toId = await supabase.resolveProfileId(username: friend.username) {
                _ = await supabase.recordShare(recipeId: recipeId, toUserId: toId, channel: "in-app",
                                               title: recipe?.title, thumbnail: recipe?.thumbnailUrl)
            }
        }
    }

    /// Share a recipe with any CraveCircle user by their @username — no creator role required.
    /// Delivers to their cloud "Shared with you" inbox. Returns false if the username can't be found.
    func shareRecipeToUsername(recipeId: String, username: String) async -> Bool {
        let handle = username.hasPrefix("@") ? String(username.dropFirst()) : username
        guard !handle.isEmpty, let toId = await supabase.resolveProfileId(username: handle) else { return false }
        let recipe = recipes.first(where: { $0.id == recipeId })
        let ok = await supabase.recordShare(recipeId: recipeId, toUserId: toId, channel: "in-app",
                                            title: recipe?.title, thumbnail: recipe?.thumbnailUrl)
        if ok {
            sharedLog.insert(SharedRecipeRecord(
                id: UUID().uuidString, recipeId: recipeId,
                fromUserId: currentUser?.id ?? "me", toUserId: toId,
                createdAt: Date(), channel: "in-app",
                recipeTitle: recipe?.title, recipeThumbnail: recipe?.thumbnailUrl), at: 0)
        }
        return ok
    }

    /// Mark a Circle notification read (clears its unread dot) — gives every tap visible feedback.
    func markNotificationRead(_ id: UUID) {
        if let i = circleNotifications.firstIndex(where: { $0.id == id }), !circleNotifications[i].isRead {
            circleNotifications[i].isRead = true
        }
    }

    /// Pull shares involving me (RLS-scoped) into the log and notify for anything newly received,
    /// so a reel someone shared with me surfaces in the "Shared with you" inbox + Circle activity.
    func syncShares() async {
        guard let remote = await supabase.fetchShares() else { return }
        let existingIds = Set(sharedLog.map { $0.id })
        let myId = currentUser?.id
        let newlyReceived = remote.filter { !existingIds.contains($0.id) && $0.toUserId == myId }
        var merged = sharedLog
        for rec in remote where !existingIds.contains(rec.id) { merged.append(rec) }
        sharedLog = merged.sorted { $0.createdAt > $1.createdAt }
        for rec in newlyReceived {
            let title = recipes.first(where: { $0.id == rec.recipeId })?.title ?? "a recipe"
            circleNotifications.insert(
                CircleNotificationItem(title: "Recipe shared with you",
                                       message: "Someone shared '\(title)' with you",
                                       timeAgo: "Just now", symbol: "tray.and.arrow.down.fill",
                                       isRead: false, recipeId: rec.recipeId),
                at: 0)
        }
    }

    func enrollInStudio() {
        guard var user = currentUser, user.role == .user else { return }
        user.role = .creator
        currentUser = user
    }

    // MARK: - Creator enrollment (request → admin approval)

    /// nil = never requested; else "pending" / "approved" / "rejected".
    @Published private(set) var myCreatorRequestStatus: String?
    /// The admin approval queue.
    @Published private(set) var pendingCreatorRequests: [CreatorRequest] = []

    var isAdmin: Bool { currentUser?.role == .admin }
    var isGuest: Bool { currentUser?.id.hasPrefix("guest_") == true || currentUser == nil }

    /// Cuisine onboarding is per signed-in account. Guests skip. Returning ids are stored on-device.
    var needsOnboarding: Bool {
        guard appState == .signedIn, let id = currentUser?.id, !isGuest else { return false }
        return !onboardedUserIds.contains(id)
    }

    private var onboardedUserIds: Set<String> {
        Set(onboardedUserIdsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }
    
    private var deletedRecipeIds: Set<String> {
        get { Set(deletedRecipeIdsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty }) }
        set { deletedRecipeIdsRaw = newValue.joined(separator: ",") }
    }

    func markOnboarded() {
        guard let id = currentUser?.id, !isGuest else { return }
        var ids = onboardedUserIds
        ids.insert(id)
        onboardedUserIdsRaw = ids.sorted().joined(separator: ",")
    }
    var hasPendingCreatorRequest: Bool { myCreatorRequestStatus == "pending" }
    /// True when a real Supabase session exists (so the request flow can run); false under the
    /// DEBUG dev-bypass, where we fall back to instant enroll for local testing.
    var hasRealSession: Bool { supabase.hasSession }

    /// Submit a creator request with the user's social handle (verified by an admin before enrollment).
    func submitCreatorRequest(platform: String, handle: String, url: String?, note: String?) async -> Bool {
        let ok = await supabase.submitCreatorRequest(platform: platform, handle: handle, url: url, note: note)
        if ok { myCreatorRequestStatus = "pending" }
        return ok
    }

    /// Refresh whether the signed-in user has a pending/decided request (drives the Studio state).
    func loadMyCreatorRequestStatus() async {
        guard let reqs = await supabase.fetchMyCreatorRequests() else { return }
        let mine = reqs.filter { $0.userId == currentUser?.id }
        myCreatorRequestStatus = (mine.first { $0.status == "pending" } ?? mine.first)?.status
        // If approved, make sure our role reflects it.
        if mine.contains(where: { $0.status == "approved" }) { await refreshMyRole() }
    }

    /// Admin: load the pending queue.
    func loadPendingCreatorRequests() async {
        guard isAdmin, let reqs = await supabase.fetchPendingCreatorRequests() else { return }
        pendingCreatorRequests = reqs
    }

    /// Admin: approve/reject a request; approval promotes the requester to creator server-side.
    func decideCreatorRequest(_ request: CreatorRequest, approve: Bool) async {
        if await supabase.decideCreatorRequest(id: request.id, approve: approve) {
            pendingCreatorRequests.removeAll { $0.id == request.id }
        }
    }

    /// Re-fetch the signed-in user's Supabase profile (e.g. after an approval flips role → creator).
    func refreshMyRole() async {
        if let profile = await supabase.fetchMyProfile() { currentUser = profile }
    }

    func continueAsGuest() {
        if guestUserId.isEmpty {
            guestUserId = "guest_\(Int.random(in: 1000...9999))"
        }
        currentUser = UserProfile(id: guestUserId, username: "Guest", fullName: "Guest User", avatarUrl: nil, role: .user)
        appState = .signedIn
    }
    
    func migrateGuestData(to newUserId: String) {
        // Find any recipes created by the guest and update their ownerId
        let oldGuestId = guestUserId
        guard !oldGuestId.isEmpty else { return }
        
        for i in recipes.indices {
            if recipes[i].ownerId == oldGuestId {
                recipes[i].ownerId = newUserId
            }
        }
        
        guestUserId = "" // Clear the guest id now that they are signed in
    }

    func deleteOwnedRecipe(id: String) {
        guard let recipe = recipes.first(where: { $0.id == id }), canDelete(recipe) else { return }
        recipes.removeAll { $0.id == id }
        savedRecipeIds.remove(id)
        likedRecipeIds.remove(id)
        studioDraftIds.remove(id)
        
        var deletedSet = deletedRecipeIds
        deletedSet.insert(id)
        deletedRecipeIds = deletedSet
        
        if selectedRecipe?.id == id { selectedRecipe = nil }
        
        let ownerId = currentUser?.id ?? "me"
        Task {
            // Tell the real Supabase backend to delete it
            _ = await supabase.deleteRecipe(id: id, ownerId: ownerId)
            // Also notify the local python server if we're in dev mode
            try? await apiClient.deleteRecipe(id: id)
        }
    }

    // MARK: - Owner-aware recipe collections (single source of truth for "your" recipes)
    /// Recipes the signed-in user created or imported.
    var ownedRecipes: [Recipe] { recipes.filter { isOwner(of: $0) } }
    /// The user's own recipes still in Studio draft.
    var myDrafts: [Recipe] { ownedRecipes.filter { isDraft(recipeId: $0.id) } }
    /// The user's own recipes that are published.
    var myPublished: [Recipe] { ownedRecipes.filter { !isDraft(recipeId: $0.id) } }

    /// Your Library = recipes you created/imported (owner) or explicitly saved. NOT `canDelete`,
    /// which is a moderation check that's true for any imported/published recipe (so it leaked
    /// other creators' published recipes into your library — they belong only in Discover/Circle).
    var myLibraryRecipes: [Recipe] {
        recipes.filter { isOwner(of: $0) || isSaved(recipeId: $0.id) }
    }


    // Shared with the Share Extension (same literal strings live in ShareViewController).
    static let appGroupID = "group.com.anassyed.AICookBook"
    static let pendingImportKey = "pending_import_url"

    /// Import a link shared into the app from the system Share sheet.
    /// `passedURL` is the link carried in the `cravecircle://import?url=…` deep link (the primary
    /// path, works with no App Group). When nil, falls back to the App-Group hand-off (paid team).
    /// No-op when there's nothing pending or an import is already running.
    func importFromSharedURL(_ passedURL: String? = nil) async {
        var urlString = passedURL?.trimmingCharacters(in: .whitespacesAndNewlines)

        if urlString?.isEmpty ?? true,
           let defaults = UserDefaults(suiteName: Self.appGroupID),
           let stored = defaults.string(forKey: Self.pendingImportKey) {
            urlString = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.removeObject(forKey: Self.pendingImportKey)   // consume once
        }

        guard let urlString, !urlString.isEmpty else { return }
        guard importState == .idle else { return }
        await startImport(from: urlString)
    }

    /// On launch/foreground, resume a share's server job if the extension left one in the App Group
    /// (paid-team builds). No-op on free teams (no App Group) — there the deep link or refresh covers it.
    func checkPendingSharedImport() {
        guard importState == .idle, let d = UserDefaults(suiteName: Self.appGroupID),
              let job = d.string(forKey: "pending_import_job"), !job.isEmpty else { return }
        d.removeObject(forKey: "pending_import_job")
        resumeSharedImport(jobId: job)
    }

    /// Resume watching a server-side import the Share Extension already started (it POSTs
    /// /reels/import and hands us the job id). Shows the live progress UI and, on completion,
    /// fetches the recipe, marks it as the user's, and files it in the library — same as an in-app
    /// import, but the heavy work ran on the server so it worked even while the app was closed.
    func resumeSharedImport(jobId: String) {
        guard importState == .idle else { return }   // don't stomp an import already in progress
        importState = .polling(jobId: jobId, status: .transcribing)
        beginPolling(jobId: jobId)
    }

    /// Public entry — runs the whole import inside the cancellable `importTask` so the Cancel button
    /// actually terminates it: it cancels the in-flight server/download requests AND stops the
    /// on-device transcription/OCR/extraction, and no late state write can revive the banner.
    func startImport(from instagramURL: String) async {
        importTask?.cancel()
        importState = .submitting
        let task = Task { [weak self] in
            guard let self else { return }
            await self._startImport(from: instagramURL)
        }
        importTask = task
        await task.value
    }

    private func _startImport(from instagramURL: String) async {
        do {
            // 1) Fetch reel info and server-cached mp4 link
            let reel = try await apiClient.downloadReel(url: instagramURL)
            if Task.isCancelled { return }
            let downloadPath = reel.downloadUrl.starts(with: "http")
                ? reel.downloadUrl
                : config.apiBaseURL.appending(path: reel.downloadUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).absoluteString

            guard let downloadUrl = URL(string: downloadPath) else {
                throw URLError(.badURL)
            }

            // 2) Download video file to local temporary storage on iPhone
            importState = .polling(jobId: reel.mediaId, status: .downloading)
            let (tempFileUrl, _) = try await URLSession.shared.download(from: downloadUrl)
            if Task.isCancelled { try? FileManager.default.removeItem(at: tempFileUrl); return }

            let localMp4 = FileManager.default.temporaryDirectory.appendingPathComponent("\(reel.mediaId).mp4")
            if FileManager.default.fileExists(atPath: localMp4.path) {
                try? FileManager.default.removeItem(at: localMp4)
            }
            try FileManager.default.moveItem(at: tempFileUrl, to: localMp4)

            // 3) Hand off to the fast on-device pipeline (Apple Neural Engine + Vision).
            //    Resolve the thumbnail (the server returns a relative /reels/media/… path for its
            //    ffmpeg frame; the reel's own poster image comes as a full http URL).
            let resolvedThumb: String?
            if let t = reel.thumbnail, !t.isEmpty {
                resolvedThumb = t.starts(with: "http")
                    ? t
                    : config.apiBaseURL.appending(path: t.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).absoluteString
            } else {
                resolvedThumb = nil
            }
            // Same task → cancellation propagates into the on-device pipeline.
            await _importFromVideo(localMp4, caption: reel.caption, title: reel.title, thumbnailUrl: resolvedThumb)

            // Clean up
            try? FileManager.default.removeItem(at: localMp4)

        } catch {
            if Task.isCancelled { return }   // a cancelled request throws — don't show "failed"
            print("❌ startImport error: \(error)")
            importState = .failed(message: friendlyImportError(error))
        }
    }

    /// Turn raw network errors into something a cook understands — and always point at the on-device
    /// path (pick a video), which needs no server, as the fallback.
    private func friendlyImportError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "You're offline. Reconnect, or import a video from your phone instead — that works without a connection."
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .dnsLookupFailed:
                return "Can't reach the recipe server right now. Try again, or import a video from your phone instead."
            default: break
            }
        }
        return "That import didn't work. Try another link, or import a video from your phone instead."
    }

    /// On-device import: video → transcribe (Neural Engine) → structure (Foundation Models) → recipe.
    /// No backend, no auth, no download. Drives the same import-progress UI.
    /// Translate a recipe's text into the user's chosen language via the server translator.
    /// Best-effort: returns the original if anything fails or it's already in the target language.
    /// Best-guess speech-recognition locale for a reel, inferred from its caption/title language
    /// (captions usually match the spoken audio). Only returns a locale the on-device recognizer
    /// actually supports; otherwise en-US — the most common cooking-reel language and most robust
    /// recognizer. This picks the language to LISTEN in; the recipe's output language is separate.
    static func speechLocale(forHint hint: String) async -> String {
        let fallback = "en-US"
        let text = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 12 else { return fallback }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let code = recognizer.dominantLanguage?.rawValue else { return fallback }
        // NL language codes ("en","ta","hi"…) → a speech locale with a region.
        let map: [String: String] = [
            "en": "en-US", "ta": "ta-IN", "hi": "hi-IN", "te": "te-IN", "bn": "bn-IN",
            "mr": "mr-IN", "kn": "kn-IN", "ml": "ml-IN", "gu": "gu-IN", "pa": "pa-IN",
            "es": "es-ES", "fr": "fr-FR", "it": "it-IT", "pt": "pt-BR", "de": "de-DE",
            "ar": "ar-SA", "ja": "ja-JP", "ko": "ko-KR", "zh": "zh-CN", "ru": "ru-RU",
        ]
        let candidate = map[code] ?? fallback
        if candidate != fallback, await OnDeviceTranscriber.isSupported(localeID: candidate) {
            return candidate
        }
        return fallback
    }

    private func translateToPreferredLanguage(_ recipe: Recipe) async -> Recipe {
        let target = AppLanguage.preferred.rawValue
        var strings: [String] = [recipe.title, recipe.description ?? ""]
        for g in recipe.ingredients { strings.append(contentsOf: g.items) }
        for d in recipe.directions { strings.append(d.text) }
        // Best-effort, and time-boxed: translation is a nicety, not worth stalling the import on a
        // slow server. If it doesn't answer quickly, keep the recipe as-is and finish (reach .done).
        let translated: [String]? = await withTaskGroup(of: [String]?.self) { group in
            group.addTask { try? await self.apiClient.translateTexts(strings, target: target) }
            // A full recipe is many strings and the server translates them per-string, so allow time.
            group.addTask { try? await Task.sleep(for: .seconds(25)); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        guard let translated, translated.count == strings.count else { return recipe }
        var out = recipe
        var i = 0
        out.title = translated[i]; i += 1
        let desc = translated[i]; i += 1
        if !(recipe.description ?? "").isEmpty { out.description = desc }
        for gi in out.ingredients.indices {
            for ii in out.ingredients[gi].items.indices { out.ingredients[gi].items[ii] = translated[i]; i += 1 }
        }
        for di in out.directions.indices { out.directions[di].text = translated[i]; i += 1 }
        return out
    }

    /// Build a recipe from a photo of a written/printed recipe (Vision OCR → extractor). The photo
    /// becomes the cover (stored locally). It's the user's own content, so it syncs like any original.
    func importFromPhoto(_ image: UIImage) async {
        importTask?.cancel()
        importState = .submitting
        let task = Task { [weak self] in
            guard let self else { return }
            await self._importFromPhoto(image)
        }
        importTask = task
        await task.value
    }

    private func _importFromPhoto(_ image: UIImage) async {
        let ocr = await PhotoTextOCR.recognize(image)
        if Task.isCancelled { return }
        importState = .polling(jobId: "on-device", status: .extracting)
        guard ocr.trimmingCharacters(in: .whitespacesAndNewlines).count > 10 else {
            importState = .failed(message: "Couldn't read text from that photo. Try a clearer shot of the recipe.")
            return
        }
        var recipe = await RecipeExtractor.extract(
            transcript: "", caption: nil, ownerId: currentUser?.id ?? "you",
            sourceLanguage: nil, onScreenText: ocr, targetLanguage: AppLanguage.preferred
        )
        if Task.isCancelled { return }
        guard recipeHasContent(recipe) else {
            importState = .failed(message: "That photo didn't have enough to build a recipe — try a clearer shot of the ingredients and steps.")
            return
        }
        guard RecipeExtractor.looksLikeFood(recipe) else {
            importState = .failed(message: "Hmm, that doesn't look like a recipe. Try a photo of a dish's ingredients and steps.")
            return
        }
        recipe = await translateToPreferredLanguage(recipe)
        if Task.isCancelled { return }
        if let data = image.jpegData(compressionQuality: 0.8),
           let file = LocalStore.saveData(ImageDownscale.jpeg(from: data, maxPixel: 720, quality: 0.6) ?? data, to: "thumb-\(recipe.id).jpg") {
            recipe.thumbnailUrl = file.absoluteString
        }
        recipes.insert(recipe, at: 0)
        markRecipeDirty(recipe.id)
        Task { await syncRecipes() }
        importState = .done(recipeId: recipe.id)
        notifyImportDone(recipeTitle: recipe.title)
    }

    func importFromVideo(_ url: URL, caption: String? = nil, title: String? = nil, thumbnailUrl: String? = nil) async {
        importTask?.cancel()
        importState = .submitting
        let task = Task { [weak self] in
            guard let self else { return }
            await self._importFromVideo(url, caption: caption, title: title, thumbnailUrl: thumbnailUrl)
        }
        importTask = task
        await task.value
    }

    private func _importFromVideo(_ url: URL, caption: String? = nil, title: String? = nil, thumbnailUrl: String? = nil) async {
        guard await OnDeviceTranscriber.ensureAuthorized() else {
            if Task.isCancelled { return }
            importState = .failed(message: "Enable Speech Recognition in Settings to import on device.")
            return
        }
        if Task.isCancelled { return }
        importState = .polling(jobId: "on-device", status: .transcribing)

        // 1) Transcribe narration. A silent / music-only clip just yields an empty string here —
        //    that's expected, not a failure, so we fall through to on-screen text.
        //    Auto-detect the spoken language from the caption/title (captions usually match the
        //    audio) so an English reel isn't transcribed by a Tamil recognizer and vice-versa —
        //    the recipe's OUTPUT language is handled separately by translateToPreferredLanguage().
        var transcript = ""
        do {
            let locale = await Self.speechLocale(forHint: [title, caption].compactMap { $0 }.joined(separator: " "))
            let out = try await OnDeviceTranscriber.transcribe(url: url, localeID: locale)
            transcript = out.text
            print("🎙️ On-device transcription (\(locale)) succeeded. Characters: \(transcript.count)")
        } catch {
            print("⚠️ On-device transcription failed: \(error)")
        }
        if Task.isCancelled { return }

        // 2) Little or no narration => read the ON-SCREEN text with Vision OCR (many reels put the
        //    whole recipe on screen with no voiceover and no caption).
        var onScreen = ""
        if transcript.count < 40 {
            importState = .polling(jobId: "on-device", status: .extracting)
            onScreen = await VideoTextOCR.recognizeText(url: url)
            if Task.isCancelled { return }
        }

        // 3) MULTILINGUAL BRIDGE: the heuristic extractor and food gate only understand English
        //    units/verbs/food words. Translate ALL text sources to English before extraction so
        //    Portuguese/Italian/Arabic/etc. reels parse correctly. Best-effort, time-boxed to 8s.
        //    The LLM path (Foundation Models) handles multilingual natively, but the food gate
        //    still needs English tokens, so we always translate.
        importState = .polling(jobId: "on-device", status: .extracting)
        var fullCaption = [title, caption].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")

        let textsToTranslate = [fullCaption, onScreen, transcript].filter { !$0.isEmpty }
        if !textsToTranslate.isEmpty {
            let englishTexts: [String]? = await withTaskGroup(of: [String]?.self) { group in
                group.addTask { try? await self.apiClient.translateTexts(textsToTranslate, target: "en") }
                group.addTask { try? await Task.sleep(for: .seconds(8)); return nil }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
            if let en = englishTexts, en.count == textsToTranslate.count {
                var idx = 0
                if !fullCaption.isEmpty { fullCaption = en[idx]; idx += 1 }
                if !onScreen.isEmpty { onScreen = en[idx]; idx += 1 }
                if !transcript.isEmpty { transcript = en[idx]; idx += 1 }
            }
        }

        if Task.isCancelled { return }
        var recipe = await RecipeExtractor.extract(
            transcript: transcript, caption: fullCaption.isEmpty ? nil : fullCaption, ownerId: currentUser?.id ?? "you",
            sourceLanguage: nil, onScreenText: onScreen, targetLanguage: AppLanguage.preferred
        )
        if Task.isCancelled { return }

        // 4) Nothing readable anywhere (no audio, no caption, no on-screen text) => fail with a
        //    clear reason instead of saving an empty recipe.
        guard recipeHasContent(recipe) else {
            // Food reel, but nothing readable to build from — reassure, don't blame.
            importState = .failed(message: "This one didn't have quite enough for us to read — no spoken steps, caption, or on-screen text. If it's a recipe, try a reel where the creator lists or talks through the ingredients and steps, and we'll plate it up.")
            return
        }

        // 4.4) FOOD GATE: CraveCircle is for cooking. If the reel isn't a food recipe (a fashion/
        //      product clip can still parse into 'ingredients'), stop kindly instead of saving junk.
        //      Runs AFTER translation so English food words are present regardless of source language.
        guard RecipeExtractor.looksLikeFood(recipe) else {
            importState = .failed(message: "Hmm, this doesn't look like a cooking video. CraveCircle turns food & recipe reels into recipes — share one where someone's making a dish and we'll do the rest.")
            return
        }

        // 4.5) Deliver the recipe in the user's chosen Recipe Language. The on-device LLM already
        //      writes in the target language WHEN Apple Intelligence is available, but the heuristic
        //      fallback (and older devices) produce English — so translate the finished recipe
        //      server-side. No-op when it's already in the target language.
        recipe = await translateToPreferredLanguage(recipe)
        if Task.isCancelled { return }

        // 5) Give it a real cover: grab a representative frame from the video and store it locally,
        //    so the imported recipe looks like a real recipe instead of the generic fallback.
        //    (We avoid using the external Instagram thumbnail URL because those CDN links expire 
        //    and block hotlinking, causing them to fail to load).
        if let thumb = await VideoThumbnail.frame(from: url),
           let file = LocalStore.saveData(thumb.data, to: "thumb-\(recipe.id).\(thumb.ext)") {
            recipe.thumbnailUrl = file.absoluteString
        } else if let remote = thumbnailUrl, let rurl = URL(string: remote),
                  rurl.scheme?.hasPrefix("http") == true,
                  let (data, _) = try? await URLSession.shared.data(from: rurl),
                  let file = LocalStore.saveData(data, to: "thumb-\(recipe.id).jpg") {
            // Frame grab failed (e.g. a VP9 clip iOS can't decode) — fall back to the reel's own
            // thumbnail, downloaded now while the CDN link is fresh and stored locally so it persists.
            recipe.thumbnailUrl = file.absoluteString
        }
        if Task.isCancelled { return }

        recipes.insert(recipe, at: 0)
        markRecipeDirty(recipe.id)
        Task { await syncRecipes() }
        // Do NOT auto-set selectedRecipe here.
        importState = .done(recipeId: recipe.id)
        notifyImportDone(recipeTitle: recipe.title)
    }

    /// True when an extracted recipe actually has ingredients or steps.
    private func recipeHasContent(_ r: Recipe) -> Bool {
        r.ingredients.contains { !$0.items.isEmpty } || !r.directions.isEmpty
    }
    
    func loadGroceryList() async {
        // Grocery is local-first in this build (items carry client-side UUIDs). Only adopt the
        // backend list when it actually has items — an empty response must not wipe the
        // locally-added / demo items the user is looking at.
        do {
            let remote = try await apiClient.fetchGroceryList()
            if !remote.isEmpty { groceryItems = remote }
            groceryError = nil
        } catch {
            // Backend unreachable or no grocery endpoint — keep the local list, stay silent.
            groceryError = nil
        }
    }

    func toggleGroceryItem(id: String, checked: Bool) async {
        // Local toggle is the source of truth here; the remote sync is best-effort. A missing
        // backend row must not surface an error banner over a checkbox that already flipped.
        do {
            let updated = try await apiClient.toggleGroceryItem(id: id, checked: checked)
            if let idx = groceryItems.firstIndex(where: { $0.id == updated.id }) {
                groceryItems[idx] = updated
            }
        } catch {
            // best-effort; local state already reflects the toggle
        }
        groceryError = nil
    }

    // MARK: - Follow Actions
    func toggleFollow(creatorHandle: String) {
        let willFollow = !followedCreators.contains(creatorHandle)
        if willFollow { followedCreators.insert(creatorHandle) } else { followedCreators.remove(creatorHandle) }
        // Mirror to the cloud follow graph, then re-sync so a creator's followers-only recipes
        // (RLS-gated) appear right after you follow.
        Task {
            if let cid = await supabase.resolveProfileId(username: creatorHandle) {
                _ = await supabase.setFollow(creatorId: cid, following: willFollow)
            }
            await syncRecipes()
        }
    }
    
    func isFollowing(creatorHandle: String) -> Bool {
        followedCreators.contains(creatorHandle)
    }

    // MARK: - Saved / Bookmark Actions
    func toggleSaveRecipe(id: String) {
        if savedRecipeIds.contains(id) {
            savedRecipeIds.remove(id)
            cancelCookNudge(recipeId: id)   // no longer saved → drop the reminder
        } else {
            savedRecipeIds.insert(id)
            logInteraction(recipeId: id, eventType: "save")
            if let title = recipes.first(where: { $0.id == id })?.title {
                scheduleCookNudge(recipeId: id, title: title)
            }
        }
        UserDefaults.standard.set(Array(savedRecipeIds), forKey: "saved_recipe_ids")
    }

    // MARK: - Cook-nudge (gentle "you saved this — cook it?" reminder)

    /// Remind the user, a couple of days after they save a recipe, to actually cook it — the habit
    /// loop the app was missing. One reminder per saved recipe; cancelled if they cook it or unsave.
    private func scheduleCookNudge(recipeId: String, title: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Still craving this?"
            content.body = "You saved '\(title)' a couple of days ago — cook it tonight?"
            content.sound = .default
            content.userInfo = ["recipeId": recipeId]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2 * 24 * 60 * 60, repeats: false)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "cook-nudge-\(recipeId)", content: content, trigger: trigger))
        }
    }

    private func cancelCookNudge(recipeId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["cook-nudge-\(recipeId)"])
    }
    
    func isSaved(recipeId: String) -> Bool {
        savedRecipeIds.contains(recipeId)
    }

    // MARK: - Liked / Heart Actions
    @Published private(set) var likedRecipeIds: Set<String> = []

    var likedRecipes: [Recipe] {
        recipes.filter { likedRecipeIds.contains($0.id) }
    }

    func isLiked(recipeId: String) -> Bool {
        likedRecipeIds.contains(recipeId)
    }

    func toggleLikeRecipe(id: String) {
        if likedRecipeIds.contains(id) {
            likedRecipeIds.remove(id)
            Haptics.tap()
        } else {
            likedRecipeIds.insert(id)
            logInteraction(recipeId: id, eventType: "like")
            Haptics.success()
            if let r = recipes.first(where: { $0.id == id }) {
                let notif = CircleNotificationItem(
                    title: "Liked Recipe",
                    message: "You liked '\(r.title)'",
                    timeAgo: "Just now",
                    symbol: "heart.fill",
                    isRead: false
                )
                circleNotifications.insert(notif, at: 0)
            }
        }
        UserDefaults.standard.set(Array(likedRecipeIds), forKey: "liked_recipe_ids")
    }

    // MARK: - Friend Actions
    func sendFriendRequest(usernameOrEmail: String) {
        let clean = usernameOrEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let handle = clean.hasPrefix("@") ? clean : "@\(clean)"
        let name = clean.replacingOccurrences(of: "@", with: "").capitalized
        let newRequest = FriendRequestItem(name: name, username: handle)
        outgoingRequests.insert(newRequest, at: 0)
    }
    
    func acceptFriendRequest(id: UUID) {
        guard let index = incomingRequests.firstIndex(where: { $0.id == id }) else { return }
        let req = incomingRequests.remove(at: index)
        let friend = FriendItem(id: UUID(), name: req.name, username: req.username, bio: "Food enthusiast & Circle member", recipesCount: 4, avatarAsset: nil)
        circleFriends.insert(friend, at: 0)
        followedCreators.insert(req.username)
        
        let notif = CircleNotificationItem(title: "New Circle Friend", message: "You and \(req.name) are now connected!", timeAgo: "Just now", symbol: "person.2.fill", isRead: false)
        circleNotifications.insert(notif, at: 0)
    }
    
    func declineFriendRequest(id: UUID) {
        incomingRequests.removeAll { $0.id == id }
    }
    
    func cancelOutgoingRequest(id: UUID) {
        outgoingRequests.removeAll { $0.id == id }
    }

    // MARK: - Share Recipe With Friend
    func shareRecipeWithFriend(recipeId: String, friend: FriendItem) {
        guard let recipe = recipes.first(where: { $0.id == recipeId }) else { return }
        // Record the share (local log + cloud delivery to the recipient's inbox), then notify.
        recordShare(recipeId: recipeId, friend: friend)
        let notif = CircleNotificationItem(title: "Recipe Shared", message: "Shared '\(recipe.title)' with \(friend.name)", timeAgo: "Just now", symbol: "paperplane.fill", isRead: false, recipeId: recipeId)
        circleNotifications.insert(notif, at: 0)
    }

    // MARK: - Collections Actions
    func createCollection(name: String, isShared: Bool, imageName: String? = nil) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        let img = imageName ?? (recipes.first?.thumbnailUrl ?? "chickenRecipe")
        let item = CollectionItem(id: UUID(), name: clean, count: 0, shared: isShared, imageName: img, recipeIds: [])
        if isShared {
            sharedCollections.insert(item, at: 0)
        } else {
            ownedCollections.insert(item, at: 0)
        }
    }
    
    func deleteCollection(id: UUID) {
        ownedCollections.removeAll { $0.id == id }
        sharedCollections.removeAll { $0.id == id }
    }
    
    func addRecipeToCollection(recipeId: String, collectionId: UUID) {
        if let idx = ownedCollections.firstIndex(where: { $0.id == collectionId }) {
            if !ownedCollections[idx].recipeIds.contains(recipeId) {
                ownedCollections[idx].recipeIds.append(recipeId)
                ownedCollections[idx].count = ownedCollections[idx].recipeIds.count
            }
        } else if let idx = sharedCollections.firstIndex(where: { $0.id == collectionId }) {
            if !sharedCollections[idx].recipeIds.contains(recipeId) {
                sharedCollections[idx].recipeIds.append(recipeId)
                sharedCollections[idx].count = sharedCollections[idx].recipeIds.count
            }
        }
    }

    // MARK: - Studio Publishing Actions
    func isDraft(recipeId: String) -> Bool {
        studioDraftIds.contains(recipeId)
    }
    
    func publishDraft(recipeId: String) {
        guard canPublish,
              let recipe = recipes.first(where: { $0.id == recipeId }),
              isOwner(of: recipe),
              // Never publish a recipe imported from someone else's social post — creators may only
              // publish their OWN original recipes. Social imports stay private to the importer.
              !recipe.isImportedFromSocial
        else { return }
        studioDraftIds.remove(recipeId)
        // Publishing must actually push the recipe to the cloud so followers/everyone can see it —
        // not just flip a local draft flag. Mark it dirty and sync now, then refresh the feed.
        markRecipeDirty(recipeId)
        let notif = CircleNotificationItem(title: "Recipe Published", message: "Your recipe '\(recipe.title)' is now live on your profile.", timeAgo: "Just now", symbol: "sparkles", isRead: false, recipeId: recipeId)
        circleNotifications.insert(notif, at: 0)
        Task { await syncRecipes() }
    }
    
    func unpublishRecipe(recipeId: String) {
        guard canPublish,
              let recipe = recipes.first(where: { $0.id == recipeId }),
              isOwner(of: recipe)
        else { return }
        studioDraftIds.insert(recipeId)
    }
    
    func promoteToStudio(recipe: Recipe) {
        guard canPublish, isOwner(of: recipe) else { return }
        studioDraftIds.insert(recipe.id)
    }

    // MARK: - Grocery Batch Add & Local Toggle
    @discardableResult
    func addIngredientsToGrocery(recipe: Recipe, servings: Int? = nil) -> Int {
        var added = 0
        let baseServings = recipe.servings ?? 2
        let targetServings = servings ?? baseServings

        // De-dupe within THIS dish only (re-adding the same recipe won't double it), but keep dishes
        // separate so filtering to one dish shows its full ingredient list — even shared staples.
        let dish = recipe.title
        var seen = Set(groceryItems.filter { $0.recipeName == dish }.map { GrocerySort.coreName($0.ingredientName) })
        for group in recipe.ingredients {
            for item in group.items {
                let trimmed = item.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                let core = GrocerySort.coreName(trimmed)
                if !core.isEmpty, seen.contains(core) { continue }   // de-dupe within this dish
                if !core.isEmpty { seen.insert(core) }
                let scaledText = IngredientScaler.scale(text: trimmed, from: baseServings, to: targetServings)
                groceryItems.append(GroceryItem(id: UUID().uuidString, ingredientName: scaledText, checked: false, recipeName: dish))
                added += 1
            }
        }
        if added > 0 {
            logInteraction(recipeId: recipe.id, eventType: "grocery")
        }
        return added
    }

    func addCustomGroceryItem(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newItem = GroceryItem(id: UUID().uuidString, ingredientName: trimmed, checked: false)
        groceryItems.insert(newItem, at: 0)
    }

    func toggleGroceryItemLocal(id: String) {
        if let idx = groceryItems.firstIndex(where: { $0.id == id }) {
            groceryItems[idx].checked.toggle()
        }
    }

    func removeGroceryItem(id: String) {
        groceryItems.removeAll { $0.id == id }
    }

    func clearCheckedGroceryItems() {
        groceryItems.removeAll { $0.checked }
    }

    func markAllGroceryComplete() {
        for i in groceryItems.indices where !groceryItems[i].checked { groceryItems[i].checked = true }
    }

    // MARK: - Recipe Comments
    func comments(for recipeId: String) -> [RecipeComment] {
        recipeComments[recipeId] ?? []
    }

    func addComment(recipeId: String, text: String, image: UIImage? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A comment needs text OR a photo (people can share just a picture of how it turned out).
        var imageData: Data? = nil
        if let image, let raw = image.jpegData(compressionQuality: 0.8) {
            imageData = ImageDownscale.jpeg(from: raw, maxPixel: 1200, quality: 0.7) ?? raw
        }
        guard !trimmed.isEmpty || imageData != nil else { return }
        let user = currentUser?.fullName ?? "You"
        let handle = currentUser?.username ?? "@cravecircle"
        let newComment = RecipeComment(
            recipeId: recipeId,
            authorName: user,
            authorUsername: handle,
            text: trimmed,
            timeAgo: "Just now",
            likesCount: 0,
            isLiked: false,
            imageData: imageData
        )
        var list = recipeComments[recipeId] ?? []
        list.insert(newComment, at: 0)
        recipeComments[recipeId] = list
        logInteraction(recipeId: recipeId, eventType: "comment")

        let notif = CircleNotificationItem(
            title: "Comment Posted",
            message: "You commented on '\(recipes.first(where: { $0.id == recipeId })?.title ?? "Recipe")'",
            timeAgo: "Just now",
            symbol: "bubble.left.fill",
            isRead: false,
            recipeId: recipeId
        )
        circleNotifications.insert(notif, at: 0)
    }

    func toggleCommentLike(recipeId: String, commentId: UUID) {
        guard var list = recipeComments[recipeId],
              let idx = list.firstIndex(where: { $0.id == commentId }) else { return }
        if list[idx].isLiked {
            list[idx].isLiked = false
            list[idx].likesCount = max(0, list[idx].likesCount - 1)
        } else {
            list[idx].isLiked = true
            list[idx].likesCount += 1
        }
        recipeComments[recipeId] = list
    }

    // MARK: - Telemetry / Recommendation Engine
    
    struct InteractionEvent: Codable {
        let id: String
        let recipeId: String
        let eventType: String
        let durationSeconds: Int?
        let timestamp: Date
    }
    
    // Network queue — events waiting to be sent to the backend. Persisted so a batch that hasn't
    // reached the size threshold isn't lost when the app is killed. Capped so it can't grow forever
    // while the backend RPC doesn't exist yet.
    @Published private(set) var pendingInteractions: [InteractionEvent] = [] { didSet { persist(pendingInteractions, "pending_interactions.json") } }
    // Durable local record used by the on-device recommender. Independent of the network flush, so
    // suggestions personalize immediately and keep working with no server. Capped to stay light.
    @Published private(set) var interactionHistory: [InteractionEvent] = [] { didSet { persist(interactionHistory, "interaction_history.json") } }
    @Published private(set) var suggestedRecipes: [Recipe] = []
    /// recipeId → short "why you're seeing this" reason, when there's a real personalized signal.
    @Published private(set) var suggestionReasons: [String: String] = [:]
    /// Cuisine ids picked at onboarding — seed the feed so it's personal before any behavior exists.
    @Published private(set) var preferredCuisines: Set<String> = [] { didSet { persist(Array(preferredCuisines), "preferred_cuisines.json") } }

    /// Set by onboarding when the user chooses to import their first reel; MainTabView opens the
    /// import sheet in response, then clears it.
    @Published var pendingImportRequest = false
    /// Set by the "Write from scratch" home-screen widget tile (cravecircle://new) → open a blank editor.
    @Published var pendingNewRecipe = false
    /// Set by the "Write to CEO" app-icon quick action → open the feedback form.
    @Published var pendingFeedback = false

    /// Finish onboarding: store the taste picks and refresh the feed against them.
    func completeOnboarding(cuisines: Set<String>) {
        preferredCuisines = cuisines
        markOnboarded()
        Task { await fetchSuggestedFeed() }
    }

    private let maxPendingInteractions = 200
    private let maxInteractionHistory = 500

    func logInteraction(recipeId: String, eventType: String, durationSeconds: Int? = nil) {
        let event = InteractionEvent(
            id: UUID().uuidString,
            recipeId: recipeId,
            eventType: eventType,
            durationSeconds: durationSeconds,
            timestamp: Date()
        )
        pendingInteractions.append(event)
        if pendingInteractions.count > maxPendingInteractions {
            pendingInteractions.removeFirst(pendingInteractions.count - maxPendingInteractions)
        }
        interactionHistory.append(event)
        if interactionHistory.count > maxInteractionHistory {
            interactionHistory.removeFirst(interactionHistory.count - maxInteractionHistory)
        }

        // They cooked it — no need to nudge them to.
        if eventType == "cook" { cancelCookNudge(recipeId: recipeId) }

        if pendingInteractions.count >= 10 {
            flushTelemetry()
        }
    }

    func flushTelemetry() {
        guard !pendingInteractions.isEmpty else { return }
        let toSend = pendingInteractions

        Task {
            // POST to Supabase; only clear the queue on a confirmed success so a failed or
            // unauthenticated send never drops data — events stay queued (capped above) for later.
            let didSend = await supabase.logInteractions(toSend)
            if didSend {
                await MainActor.run {
                    self.pendingInteractions.removeAll { sent in toSend.contains { $0.id == sent.id } }
                }
            }
        }
    }

    /// The Discovery reel: personalized (same recommender as "Suggested for you"), with recipes the
    /// user has already VIEWED removed, returned in RANDOM order. Falls back to all discoverable
    /// recipes (still shuffled) once everything's been seen, so the reel is never empty.
    func discoveryReel() -> [Recipe] {
        let seen = Set(interactionHistory.filter { $0.eventType == "view" }.map(\.recipeId))
        let own = Set(recipes.filter { isOwner(of: $0) }.map(\.id))
        let excluded = seen.union(own)
        var picks = RecommendationEngine.suggestions(
            from: recipes,
            history: interactionHistory,
            excluding: excluded,
            preferredCuisines: preferredCuisines,
            limit: 60
        )
        if picks.isEmpty {
            // Seen everything the recommender would pick — show the rest (unseen first), still shuffled.
            let unseen = recipes.filter { !own.contains($0.id) && !seen.contains($0.id) }
            picks = unseen.isEmpty ? recipes.filter { !own.contains($0.id) } : unseen
        }
        return picks.shuffled()
    }

    /// Personalized suggestions. Prefers the server RPC (cross-user, dwell-weighted) when signed in;
    /// falls back to the on-device recommender when there's no session, the server is unreachable,
    /// or the server has nothing yet (e.g. recipes not synced) — so the feed is never empty.
    func fetchSuggestedFeed() async {
        let excluded = Set(recipes.filter { isOwner(of: $0) || isSaved(recipeId: $0.id) }.map { $0.id })
        let local = RecommendationEngine.suggestions(
            from: recipes,
            history: interactionHistory,
            excluding: excluded,
            preferredCuisines: preferredCuisines,
            limit: 8
        )
        if let remote = await supabase.suggestedRecipes(limit: 8), !remote.isEmpty {
            suggestedRecipes = remote
        } else {
            suggestedRecipes = local
        }
        // Explain each suggestion: behavior first, else the cuisine picked at onboarding.
        var reasons: [String: String] = [:]
        for r in suggestedRecipes {
            if let why = RecommendationEngine.reason(for: r, history: interactionHistory, allRecipes: recipes) {
                reasons[r.id] = why
            } else if let why = RecommendationEngine.cuisineReason(for: r, preferredCuisines: preferredCuisines) {
                reasons[r.id] = why
            }
        }
        suggestionReasons = reasons
    }

    func cancelImport() {
        importTask?.cancel()
        importState = .idle
    }

    // MARK: - Live Activity (Dynamic Island + Lock Screen) for the import

    /// Start / update / end the "recipe cooking" Live Activity to mirror the import state. Driven by
    /// importState's didSet, so there's one source of truth.
    private func reflectImportInLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Map ImportFlowState → the Live Activity stage.
        let stage: CookingImportAttributes.ContentState.Stage
        var recipeId: String? = nil
        var message: String? = nil
        switch importState {
        case .idle:
            endCookingActivity(); return
        case .submitting:
            stage = .downloading
        case .polling(_, let status):
            switch status {
            case .queued, .downloading: stage = .downloading
            case .transcribing:         stage = .transcribing
            case .extracting:           stage = .extracting
            case .done:                 stage = .done
            case .error:                stage = .failed
            }
        case .done(let id):
            stage = .done; recipeId = id
        case .failed(let msg):
            stage = .failed; message = msg
        }

        let title = recipeId.flatMap { id in recipes.first { $0.id == id }?.title } ?? "New recipe"
        let content = CookingImportAttributes.ContentState(
            stage: stage, recipeTitle: title, recipeId: recipeId,
            estimatedEnd: Date().addingTimeInterval(45), message: message)

        // Adopt an existing activity started by the Share Extension if we don't have one yet.
        if cookingActivity == nil {
            cookingActivity = Activity<CookingImportAttributes>.activities.first
        }

        if let activity = cookingActivity {
            if stage == .done || stage == .failed {
                // Keep the final card up briefly so the user can tap it, then auto-dismiss.
                let after = Date().addingTimeInterval(stage == .done ? 180 : 8)
                Task { await activity.end(ActivityContent(state: content, staleDate: nil), dismissalPolicy: .after(after)) }
                cookingActivity = nil
            } else {
                Task { await activity.update(ActivityContent(state: content, staleDate: nil)) }
            }
        } else if stage != .done && stage != .failed {
            let attrs = CookingImportAttributes(startedAt: Date())
            cookingActivity = try? Activity.request(
                attributes: attrs,
                content: ActivityContent(state: content, staleDate: nil))
        }
    }

    private func endCookingActivity() {
        cookingActivity = nil
        for activity in Activity<CookingImportAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
    
    private func beginPolling(jobId: String) {
        importTask?.cancel()
        importTask = Task { [weak self] in
            guard let self else { return }
            var attempts = 0
            var consecutiveErrors = 0
            // ~6 min at 3s. Hindi / long reels transcribe slowly (60s chunks, CPU whisper), so the
            // old 2-min cap quit while the server was still working. A truly stuck job still fails.
            let maxAttempts = 120
            // Don't kill the whole import on one flaky poll — network blips are common over a 6-min
            // job. Only give up after several poll requests fail in a row.
            let maxConsecutiveErrors = 6
            while !Task.isCancelled {
                if attempts >= maxAttempts {
                    await MainActor.run {
                        self.importState = .failed(message: "This import is taking too long. Try again, or import a video from your phone instead.")
                    }
                    return
                }
                attempts += 1
                do {
                    let job = try await self.apiClient.fetchImportJob(jobId: jobId)
                    
                    await MainActor.run {
                        self.importState = .polling(jobId: jobId, status: job.status)
                    }
                    if job.status == .done, let recipeId = job.recipeId {
                        var recipe = try await self.apiClient.fetchRecipe(id: recipeId)
                        if let myId = self.currentUser?.id, !myId.isEmpty {
                            recipe = Recipe(
                                id: recipe.id,
                                ownerId: myId,
                                title: recipe.title,
                                description: recipe.description,
                                prepTime: recipe.prepTime,
                                cookTime: recipe.cookTime,
                                servings: recipe.servings,
                                ingredients: recipe.ingredients,
                                directions: recipe.directions,
                                thumbnailUrl: recipe.thumbnailUrl,
                                ownerUsername: recipe.ownerUsername,
                                sourceLanguage: recipe.sourceLanguage,
                                nutrition: recipe.nutrition,
                                sourceUrl: recipe.sourceUrl
                            )
                        }
                        // Server-imported recipes can come back in the source language (its own
                        // translation is best-effort). Ensure the user's chosen Recipe Language on the
                        // app side too — no-op if the server already delivered it in the target.
                        recipe = await self.translateToPreferredLanguage(recipe)
                        await MainActor.run {
                            if let index = self.recipes.firstIndex(where: { $0.id == recipe.id }) {
                                self.recipes[index] = recipe
                            } else {
                                self.recipes.insert(recipe, at: 0)
                            }
                            self.markRecipeDirty(recipe.id)
                            Task { await self.syncRecipes() }
                            
                            // Do NOT auto-set selectedRecipe here. It causes a presentation conflict
                            // if the ImportProgressScreen sheet is currently active. Let the user
                            // explicitly tap "View" or "Open recipe" to select it.
                            self.importState = .done(recipeId: recipeId)
                            self.notifyImportDone(recipeTitle: recipe.title)
                        }
                        return
                    } else if job.status == .error {
                        await MainActor.run {
                            self.importState = .failed(message: job.errorMessage ?? "Import failed. Try another link.")
                        }
                        return
                    }
                    
                    // Reset errors since we successfully polled a non-terminal status
                    consecutiveErrors = 0
                } catch {
                    consecutiveErrors += 1
                    // Tolerate transient blips; only fail after several in a row.
                    if consecutiveErrors >= maxConsecutiveErrors {
                        await MainActor.run {
                            self.importState = .failed(message: self.friendlyImportError(error))
                        }
                        return
                    }
                }

                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func fallbackUser(email: String? = nil) -> UserProfile {
        let base = email?.split(separator: "@").first.map(String.init) ?? "chef"
        return UserProfile(id: "local-\(base)", username: "@\(base)", fullName: "Local Profile", avatarUrl: nil)
    }

    private func notifyImportDone(recipeTitle: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "Recipe Ready!"
                content.body = "Your recipe '\(recipeTitle)' has been successfully extracted and is ready to cook."
                content.sound = .default
                
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    // MARK: - Feedback / Admin
    
    func submitFeedback(type: String, content: String, email: String? = nil, handle: String? = nil) async throws {
        try await apiClient.submitFeedback(type: type, content: content, email: email, handle: handle)
    }
}

enum ImportFlowState: Equatable {
    case idle
    case submitting
    case polling(jobId: String, status: ImportStatus)
    case done(recipeId: String)
    case failed(message: String)
}
