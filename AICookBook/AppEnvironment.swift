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
    /// Device-wide flag so guests also see the first-run flow once. Flipped by `markOnboarded()`.
    @AppStorage("device_onboarded") private var deviceOnboarded: Bool = false
    // Picks captured by the first-run onboarding flow. Stored for future personalization
    // (goals → suggestion ranking, decisionTime → when the daily nudge fires, etc.).
    @AppStorage("onboarding.goals") private var onboardingGoalsRaw: String = ""
    @AppStorage("onboarding.decisionTime") private var onboardingDecisionTimeRaw: String = ""
    @AppStorage("onboarding.sources") private var onboardingSourcesRaw: String = ""
    @AppStorage("onboarding.hearAbout") private var onboardingHearAboutRaw: String = ""
    /// Per signed-in user. Not @AppStorage — that key was one list for the whole phone.
    private var deletedRecipeIdsRaw: String = ""
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
    @Published private(set) var circleFriends: [FriendItem] = [] { didSet { persist(circleFriends, "circle_friends.json") } }
    @Published private(set) var incomingRequests: [FriendRequestItem] = [] { didSet { persist(incomingRequests, "friend_requests_in.json") } }
    @Published private(set) var outgoingRequests: [FriendRequestItem] = [] { didSet { persist(outgoingRequests, "friend_requests_out.json") } }
    
    // Collections
    // New installs start with zero collections. The sample "Weeknight Dinners · 8" collections
    // used to seed here but they looked like real content the user had created — a lie on first
    // launch. Collections now appear only after the user actually makes one.
    @Published private(set) var ownedCollections: [CollectionItem] = [] { didSet { persist(ownedCollections, "owned_collections.json") } }
    @Published private(set) var sharedCollections: [CollectionItem] = [] { didSet { persist(sharedCollections, "shared_collections.json") } }

    // Studio Drafts & Published
    // No preseeded drafts. A new creator sees "0 Drafts" in Studio until they actually write one.
    @Published private(set) var studioDraftIds: Set<String> = [] { didSet { persist(Array(studioDraftIds), "studio_drafts.json") } }
    
    // Notifications & Activity
    @Published private(set) var circleNotifications: [CircleNotificationItem] = [] { didSet { persist(circleNotifications, "notifications.json") } }

    // Recipe Comments
    // Comments start empty. Server-synced comments populate per recipe on first open. The sample
    // comments shipped as a default made every recipe look busier than it was.
    @Published private(set) var recipeComments: [String: [RecipeComment]] = [:] { didSet { persist(recipeComments, "comments.json") } }

    let config: AppConfig
    private let tokenStore: TokenStore
    private let authClient: SupabaseAuthClient
    private let apiClient: APIClient
    private var importTask: Task<Void, Never>?

    /// Guards on-disk autosave: property `didSet`s only persist AFTER `hydrateLocal()` has loaded
    /// the saved state, so loading doesn't immediately overwrite the files. Writes go to the
    /// signed-in user's file, never the shared unscoped name.
    private var hydrated = false
    private func persist<T: Encodable>(_ value: T, _ file: String) {
        guard hydrated, let id = currentUser?.id, !id.isEmpty else { return }
        LocalStore.save(value, to: AccountScope.fileName(userId: id, file: file))
    }

    private func loadScoped<T: Decodable>(_ type: T.Type, _ file: String, userId: String) -> T? {
        LocalStore.load(type, from: AccountScope.fileName(userId: userId, file: file))
    }

    private func storeRecipeIdSet(_ ids: Set<String>, key: String) {
        guard hydrated, let id = currentUser?.id, !id.isEmpty else { return }
        UserDefaults.standard.set(Array(ids), forKey: AccountScope.defaultsKey(userId: id, key: key))
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

    /// Copy the old unscoped files onto this user once, then never again.
    /// The owner id is recorded before the copy so a second account cannot claim the same files.
    private func claimLegacyFilesIfNeeded(userId: String) {
        let defaults = UserDefaults.standard
        let recorded = defaults.string(forKey: AccountScope.ownerKey)
        guard AccountScope.mayReadLegacy(userId: userId, recordedOwner: recorded) else { return }
        if recorded == nil {
            defaults.set(userId, forKey: AccountScope.ownerKey)
        }
        let fm = FileManager.default
        for file in AccountScope.personalFiles {
            let scopedURL = LocalStore.url(AccountScope.fileName(userId: userId, file: file))
            let legacyURL = LocalStore.url(file)
            if !fm.fileExists(atPath: scopedURL.path), fm.fileExists(atPath: legacyURL.path) {
                try? fm.copyItem(at: legacyURL, to: scopedURL)
            }
        }
        for key in AccountScope.personalDefaultsKeys {
            let scoped = AccountScope.defaultsKey(userId: userId, key: key)
            if defaults.object(forKey: scoped) == nil, let legacy = defaults.object(forKey: key) {
                defaults.set(legacy, forKey: scoped)
            }
        }
    }

    /// Load this user's library, photo, grocery, and the rest of their on-device setup.
    /// Sample recipes are still merged in so Discover works offline; they are not owned.
    private func hydrateLocal() {
        guard let userId = currentUser?.id, !userId.isEmpty else { return }
        hydrated = false
        claimLegacyFilesIfNeeded(userId: userId)
        let defaults = UserDefaults.standard
        deletedRecipeIdsRaw = defaults.string(forKey: AccountScope.defaultsKey(userId: userId, key: "deleted_recipe_ids")) ?? ""
        let localDeleted = deletedRecipeIds

        let saved = loadScoped([Recipe].self, "recipes.json", userId: userId) ?? []
        var merged = saved.filter { !localDeleted.contains($0.id) }
        for i in merged.indices {
            if let t = merged[i].thumbnailUrl, t.hasPrefix("file://"), let name = URL(string: t)?.lastPathComponent {
                merged[i].thumbnailUrl = name
            }
        }
        for (i, r) in merged.enumerated() {
            if let fresh = Recipe.placeholderRecipes.first(where: { $0.id == r.id }) {
                merged[i] = fresh
            }
        }
        let savedIds = Set(merged.map(\.id))
        for sample in Recipe.placeholderRecipes where !savedIds.contains(sample.id) { merged.append(sample) }
        var stamped = false
        for i in merged.indices where merged[i].ownerId == "you" || merged[i].ownerId == "local-user" || merged[i].ownerId == "local-chef" {
            merged[i].ownerId = userId
            stamped = true
        }
        recipes = merged.map(NutritionEstimator.replacingCalorieHeadline)

        ownedCollections = loadScoped([CollectionItem].self, "owned_collections.json", userId: userId) ?? []
        sharedCollections = loadScoped([CollectionItem].self, "shared_collections.json", userId: userId) ?? []
        groceryItems = loadScoped([GroceryItem].self, "grocery.json", userId: userId) ?? []
        studioDraftIds = Set(loadScoped([String].self, "studio_drafts.json", userId: userId) ?? [])
        followedCreators = Set(loadScoped([String].self, "followed_creators.json", userId: userId) ?? [])
        sharedLog = loadScoped([SharedRecipeRecord].self, "shared_log.json", userId: userId) ?? []
        unsyncedRecipeIds = Set(loadScoped([String].self, "unsynced_recipes.json", userId: userId) ?? [])
        preferredCuisines = Set(loadScoped([String].self, "preferred_cuisines.json", userId: userId) ?? [])
        avatarImageData = loadScoped(Data.self, "avatar.json", userId: userId)
        pendingInteractions = loadScoped([InteractionEvent].self, "pending_interactions.json", userId: userId) ?? []
        interactionHistory = loadScoped([InteractionEvent].self, "interaction_history.json", userId: userId) ?? []
        recipeComments = loadScoped([String: [RecipeComment]].self, "comments.json", userId: userId) ?? [:]
        circleNotifications = CircleNotificationItem.withoutSamples(
            loadScoped([CircleNotificationItem].self, "notifications.json", userId: userId) ?? []
        )
        circleFriends = loadScoped([FriendItem].self, "circle_friends.json", userId: userId) ?? []
        incomingRequests = loadScoped([FriendRequestItem].self, "friend_requests_in.json", userId: userId) ?? []
        outgoingRequests = loadScoped([FriendRequestItem].self, "friend_requests_out.json", userId: userId) ?? []

        savedRecipeIds = Set(defaults.array(forKey: AccountScope.defaultsKey(userId: userId, key: "saved_recipe_ids")) as? [String] ?? [])
        likedRecipeIds = Set(defaults.array(forKey: AccountScope.defaultsKey(userId: userId, key: "liked_recipe_ids")) as? [String] ?? [])

        suggestionReasons = [:]
        suggestedRecipes = []
        selectedRecipe = nil
        myCreatorRequestStatus = nil
        pendingCreatorRequests = []
        searchDemands = []
        nutritionAttempted = []
        didThumbnailBackfill = false

        hydrated = true
        if stamped { persist(recipes, "recipes.json") }
    }

    /// Drop the previous account's in-memory setup without writing empty files over their store.
    private func clearPersonalState() {
        recipes = []
        savedRecipeIds = []
        likedRecipeIds = []
        groceryItems = []
        ownedCollections = []
        sharedCollections = []
        studioDraftIds = []
        followedCreators = []
        unsyncedRecipeIds = []
        sharedLog = []
        pendingInteractions = []
        interactionHistory = []
        preferredCuisines = []
        avatarImageData = nil
        recipeComments = [:]
        circleNotifications = []
        circleFriends = []
        incomingRequests = []
        outgoingRequests = []
        suggestionReasons = [:]
        suggestedRecipes = []
        selectedRecipe = nil
        deletedRecipeIdsRaw = ""
        myCreatorRequestStatus = nil
        pendingCreatorRequests = []
        searchDemands = []
        nutritionAttempted = []
        recipeSwipeContext = nil
    }

    func bootstrap() async {
        #if DEBUG
        _ = CraveCircleInvariantChecks._runChecks
        #endif
        guard tokenStore.readAccessToken() != nil else {
            if !guestUserId.isEmpty {
                continueAsGuest()
                Task { await refreshRecipes() }
                return
            }
            #if DEBUG
            continueAsGuest()
            Task { await refreshRecipes() }
            return
            #else
            appState = .signedOut
            return
            #endif
        }

        // Prefer the real Supabase profile (id = auth uid, correct role) so admin/creator persists
        // across launches; fall back to the homelab profile, then a generic user.
        if let profile = await supabase.fetchMyProfile() {
            currentUser = profile
            elevateFounderIfMatches(email: profile.username)
            appState = .signedIn
            showGuestPaywall = false
            hydrateLocal()
            await refreshRecipes()
            await hydrateLikesAndSavesFromServer()
            await uploadDeviceTokenIfPossible()
            syncSharedUserId()
            return
        }
        do {
            currentUser = try await apiClient.fetchProfile()
            appState = .signedIn
            hydrateLocal()
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
            hydrateLocal()
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

    /// Founder gets admin automatically — needed to approve creator requests from day one.
    /// Keyed to the exact email so a random account can't elevate itself. We check three sources
    /// so the Google sign-in path (which never carries a typed email) still works:
    ///   1. the email the caller typed into the sign-in form,
    ///   2. the authenticated JWT's `email` claim (Supabase populates this for OAuth too),
    ///   3. the profile's username, as a last-resort fallback.
    /// On a match we also PATCH the role on Supabase so RLS-gated writes line up with the local
    /// `role = .admin`; without that server-side truth every publish would still be rejected.
    private func elevateFounderIfMatches(email: String?) {
        let founderEmail = "adityagupta2646@gmail.com"
        guard let cur = currentUser else { return }
        let typed = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let authEmail = (supabase.currentUserEmail() ?? "").lowercased()
        let handle = (cur.username ?? "").lowercased()
        guard typed == founderEmail || authEmail == founderEmail || handle == founderEmail else { return }
        if cur.role == .admin { return }
        currentUser = UserProfile(
            id: cur.id, username: cur.username, fullName: cur.fullName, avatarUrl: cur.avatarUrl,
            role: .admin, bio: cur.bio,
            instagramUrl: cur.instagramUrl, tiktokUrl: cur.tiktokUrl,
            youtubeUrl: cur.youtubeUrl, facebookUrl: cur.facebookUrl
        )
        // Mirror the role to Supabase. Fire-and-forget: if it fails, the local admin role still
        // works for client UI, but server writes may be rejected until the next launch retries.
        Task { _ = await supabase.updateMyRole(.admin) }
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
        let guestId = guestUserId
        let carried: [Recipe] = guestId.isEmpty ? [] : recipes.filter { $0.ownerId == guestId }
        hydrated = false
        if let profile = await supabase.fetchMyProfile() {
            currentUser = profile
        } else {
            do { currentUser = try await apiClient.fetchProfile() }
            catch { currentUser = fallbackUser(email: email) }
        }
        elevateFounderIfMatches(email: email)
        // Fresh sign-in → clear the guest free-view counter so the previous session's taps don't
        // follow them in. The user's own likes/follows/saves are user-id-scoped elsewhere, so they
        // naturally start empty for a brand-new account.
        resetGuestViewCounter()
        // Move everything the guest did on this device over to the signed-in account BEFORE we
        // hydrate — likes, saves, follows, comments, notifications, drafts, grocery list, picked
        // cuisines, interaction history. Nothing of theirs should get stranded on the guest id.
        if let userId = currentUser?.id, !guestId.isEmpty, userId != guestId {
            migrateGuestDataIfNeeded(fromGuestId: guestId, toUserId: userId)
        }
        hydrateLocal()
        if let userId = currentUser?.id, !carried.isEmpty {
            for var recipe in carried {
                recipe.ownerId = userId
                if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
                    recipes[index] = recipe
                } else {
                    recipes.insert(recipe, at: 0)
                }
            }
        }
        if !guestId.isEmpty { guestUserId = "" }
        appState = .signedIn
        // The user is now a real signed-in account — if any guest-era paywall was still raised
        // the sheet would re-present on MainTabView. Drop it unconditionally.
        showGuestPaywall = false
        await refreshRecipes()
        await hydrateLikesAndSavesFromServer()
        await uploadDeviceTokenIfPossible()   // token may have arrived before login
        syncSharedUserId()
    }

    /// Pull the signed-in user's likes + saves from Supabase and union them with whatever's on
    /// device. The server wins for the aggregate set — a like made on another device appears
    /// here on next sign-in; a like only on this device also stays because we union, not replace.
    func hydrateLikesAndSavesFromServer() async {
        guard hasRealSession else { return }
        guard let (serverLikes, serverSaves) = await supabase.fetchMyLikesAndSaves() else { return }
        let mergedLikes = likedRecipeIds.union(serverLikes)
        let mergedSaves = savedRecipeIds.union(serverSaves)
        await MainActor.run {
            likedRecipeIds = mergedLikes
            savedRecipeIds = mergedSaves
        }
        storeRecipeIdSet(mergedLikes, key: "liked_recipe_ids")
        storeRecipeIdSet(mergedSaves, key: "saved_recipe_ids")
    }

    /// Carry the guest's on-device state into the signed-in account, then wipe the guest's
    /// scoped files + defaults so nothing is left behind. Union-merge where the new account
    /// already has data from a previous sign-in on this device; wholesale-move otherwise.
    private func migrateGuestDataIfNeeded(fromGuestId guestId: String, toUserId userId: String) {
        let defaults = UserDefaults.standard
        // 1. UserDefaults sets (likes / saves / deleted ids) — union.
        for key in AccountScope.personalDefaultsKeys {
            let gKey = AccountScope.defaultsKey(userId: guestId, key: key)
            let uKey = AccountScope.defaultsKey(userId: userId, key: key)
            let guestVals = Set(defaults.array(forKey: gKey) as? [String] ?? [])
            if guestVals.isEmpty { continue }
            let existing = Set(defaults.array(forKey: uKey) as? [String] ?? [])
            let merged = existing.union(guestVals)
            defaults.set(Array(merged), forKey: uKey)
            defaults.removeObject(forKey: gKey)
        }
        // 2. Scoped files — if target doesn't exist, move the guest file over; otherwise leave
        //    the target in place (the new account's own data wins for anything decoded here).
        //    This keeps the merge simple: guests rarely have overlapping state on first sign-in.
        for file in AccountScope.personalFiles {
            let gName = AccountScope.fileName(userId: guestId, file: file)
            let uName = AccountScope.fileName(userId: userId, file: file)
            LocalStore.moveIfTargetMissing(from: gName, to: uName)
            LocalStore.remove(gName)
        }
        // 3. Deleted-recipe-ids key is a scoped String, not an array — carry it too.
        let gDel = AccountScope.defaultsKey(userId: guestId, key: "deleted_recipe_ids")
        if let s = defaults.string(forKey: gDel), !s.isEmpty {
            let uDel = AccountScope.defaultsKey(userId: userId, key: "deleted_recipe_ids")
            let existing = defaults.string(forKey: uDel) ?? ""
            let union = Set(existing.split(separator: ",").map(String.init))
                .union(Set(s.split(separator: ",").map(String.init)))
                .filter { !$0.isEmpty }
            defaults.set(union.sorted().joined(separator: ","), forKey: uDel)
            defaults.removeObject(forKey: gDel)
        }
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
                role: cur.role,
                bio: cur.bio,
                instagramUrl: cur.instagramUrl,
                tiktokUrl: cur.tiktokUrl,
                youtubeUrl: cur.youtubeUrl,
                facebookUrl: cur.facebookUrl
            )
        }
        _ = await supabase.updateMyProfile(
            fullName: (name?.isEmpty == false) ? name : nil,
            username: (handle?.isEmpty == false) ? handle : nil,
            avatarUrl: nil
        )
    }

    /// Save the user-written bio + social links. Stored on the local currentUser copy — the
    /// backend table doesn't carry these columns yet, so this is per-device for now and will
    /// mirror once the cloud schema catches up.
    func updateProfileSocials(bio: String?, instagram: String?, tiktok: String?, youtube: String?, facebook: String?) {
        guard let cur = currentUser else { return }
        func clean(_ v: String?) -> String? {
            let t = v?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? nil : t
        }
        currentUser = UserProfile(
            id: cur.id,
            username: cur.username,
            fullName: cur.fullName,
            avatarUrl: cur.avatarUrl,
            role: cur.role,
            bio: clean(bio),
            instagramUrl: clean(instagram),
            tiktokUrl: clean(tiktok),
            youtubeUrl: clean(youtube),
            facebookUrl: clean(facebook)
        )
    }

    func signOut() {
        hydrated = false          // don't let clearing state overwrite the previous user's files
        importTask?.cancel()
        tokenStore.clearSession()
        clearPersonalState()
        currentUser = nil
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

    

    /// True when this recipe belongs to the user's personal on-device library (imported reels or user-created recipes).
    /// These are protected from being overwritten or clobbered by remote public feed syncs.
    func isUserLibraryRecipe(_ recipe: Recipe) -> Bool {
        isOwner(of: recipe) || unsyncedRecipeIds.contains(recipe.id)
    }

    func refreshRecipes() async {
        // Instant day-0 fallback: seed with static samples if local store is empty
        if recipes.isEmpty {
            recipes = Recipe.placeholderRecipes
        }

        // Fast cloud sync from Supabase (sub-250ms via Cloudflare edge)
        if let remote = await supabase.fetchRecipes(limit: 50, offset: 0) {
            let localDeleted = deletedRecipeIds
            let remoteIds = Set(remote.map(\.id))
            let sampleIds = Set(Recipe.placeholderRecipes.map(\.id))
            // Prune deleted remote recipes while strictly protecting user library & static samples
            var merged = recipes.filter { isUserLibraryRecipe($0) || remoteIds.contains($0.id) || sampleIds.contains($0.id) }
            var changed = (merged.count != recipes.count)
            for r in remote where !unsyncedRecipeIds.contains(r.id) && !localDeleted.contains(r.id) {
                if let i = merged.firstIndex(where: { $0.id == r.id }) {
                    // PROTECT: Do not overwrite user-imported or personal recipes with remote rows
                    if isUserLibraryRecipe(merged[i]) {
                        continue
                    }
                    if merged[i] != r { merged[i] = r; changed = true }
                } else {
                    merged.append(r)
                    changed = true
                }
            }
            if changed { recipes = merged }
            recipePage = 1
            hasMoreRecipes = remote.count >= 50
        }

        // Layer newly published cloud recipes on top + push any local edits.
        await syncRecipes()
    }

    /// Infinite scroll: append the next page of recipes from Supabase cloud as the user nears the end.
    /// Pages from Supabase; on error/empty it simply stops gracefully without UI freezes.
    func loadMoreRecipes() async {
        guard !isLoadingMore, hasMoreRecipes else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        if let next = await supabase.fetchRecipes(limit: recipePageSize, offset: recipePage * recipePageSize) {
            if next.count < recipePageSize { hasMoreRecipes = false }
            let existing = Set(recipes.map(\.id))
            let localDeleted = deletedRecipeIds
            let fresh = next.filter { !existing.contains($0.id) && !localDeleted.contains($0.id) }
            if !fresh.isEmpty { recipes.append(contentsOf: fresh) }
            recipePage += 1
        } else {
            hasMoreRecipes = false
        }
    }

    func addPreviewRecipe() {
        let next = Recipe(
            id: UUID().uuidString,
            ownerId: currentUser?.id ?? "",
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

    /// Owner call (2026-10-25): a guest can browse the entire app — Discover, Home, recipes,
    /// creators, grocery, cook mode — but cannot IMPORT, PUBLISH, FOLLOW, LIKE, SAVE or COMMENT.
    /// The sign-in wall is now action-triggered rather than view-triggered. This mirrors the
    /// Instagram pattern of "look all you want, log in to participate".
    func canViewRecipe() -> Bool { true }

    /// Any write path (import, publish, follow, like, save, comment) calls into
    /// `requireRealSessionOrPrompt()` which raises `showGuestPaywall`. This method is kept so
    /// a sign-in / sign-up transition clears whatever counter state might have accrued from an
    /// older build that enforced a view cap.
    func resetGuestViewCounter() {
        guestRecipesViewed = 0
    }

    /// Legacy UI hook — always returns a non-blocking "unlimited". Kept so any screen that was
    /// reading this to show "N free recipes left" doesn't need a conditional removal.
    var guestViewsRemaining: Int { Int.max }

    /// Guest tried to import, publish, share, or do anything that writes to our catalog. Raises
    /// the paywall with a message that invites them in rather than scolding them.
    func promptGuestToSignIn(reason: GuestPromptReason) {
        guestPaywallMessage = reason.copy
        showGuestPaywall = true
        Haptics.warning()
    }

    /// Copy for the paywall sheet. Changes based on what the guest tried to do.
    @Published var guestPaywallMessage: String = GuestPromptReason.generic.copy

    enum GuestPromptReason {
        case generic, importRecipe, publishRecipe, follow, like, save, comment, share
        var copy: String {
            switch self {
            case .generic:
                return "You're exploring as a guest — sign in to use the full app."
            case .importRecipe:
                return "You're a guest. Sign in to import this recipe into your library."
            case .publishRecipe:
                return "You're a guest. Sign in to publish a recipe on CraveCircle."
            case .follow:
                return "You're a guest. Sign in to follow creators and build your feed."
            case .like, .save:
                return "You're a guest. Sign in to save recipes you love."
            case .comment:
                return "You're a guest. Sign in to join the conversation."
            case .share:
                return "You shared a recipe with us — we'd love you to keep it. Sign in to add it to your library."
            }
        }
    }

    @Published private(set) var recipeSwipeContext: [Recipe]?

    func selectRecipe(_ recipe: Recipe, in context: [Recipe]? = nil) {
        guard canViewRecipe() else { return }
        recipeSwipeContext = context
        selectedRecipe = recipe
        refreshAuthoritativeNutrition(for: recipe)
    }

    private var nutritionAttempted = Set<String>()

    /// Compute nutrition once (off-main) for a recipe that has none yet — using the bundled offline
    /// USDA engine (no network, no API). Stores it (with the macro breakdown) so it persists and
    /// doesn't recompute every render. NEVER overwrites a recipe that already has nutrition (e.g. the
    /// accurate server value from a share import).
    func refreshAuthoritativeNutrition(for recipe: Recipe) {
        let estimated = recipe.nutrition?.estimated == true
        guard recipe.nutrition == nil || estimated, !nutritionAttempted.contains(recipe.id) else { return }
        nutritionAttempted.insert(recipe.id)
        Task.detached { [weak self] in
            let computed = NutritionEstimator.estimate(for: recipe)   // offline USDA-backed
            await MainActor.run {
                guard let self else { return }
                let keep = computed.calories > 0
                if let i = self.recipes.firstIndex(where: { $0.id == recipe.id }),
                   self.recipes[i].nutrition == nil || (self.recipes[i].nutrition?.estimated == true && keep) {
                    self.recipes[i].nutrition = computed
                }
                if self.selectedRecipe?.id == recipe.id,
                   self.selectedRecipe?.nutrition == nil || (self.selectedRecipe?.nutrition?.estimated == true && keep) {
                    self.selectedRecipe?.nutrition = computed
                }
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
            let localDeleted = deletedRecipeIds
            let remoteIds = Set(remote.map(\.id))
            let sampleIds = Set(Recipe.placeholderRecipes.map(\.id))
            // Prune deleted remote recipes while strictly protecting user personal library recipes
            var merged = recipes.filter { isUserLibraryRecipe($0) || remoteIds.contains($0.id) || sampleIds.contains($0.id) }
            var changed = (merged.count != recipes.count)
            var added = 0
            for r in remote where !unsyncedRecipeIds.contains(r.id) && !localDeleted.contains(r.id) {
                if let i = merged.firstIndex(where: { $0.id == r.id }) {
                    if isUserLibraryRecipe(merged[i]) {
                        continue
                    }
                    if merged[i] != r { merged[i] = r; changed = true }
                } else {
                    merged.append(r); added += 1; changed = true
                }
            }
            if changed { recipes = merged }          // single assignment → one persist
            if added > 0 { hasMoreRecipes = true }   // new content available to scroll
        }
        // PUSH — send my own changed recipes up; clear the dirty flag only on success.
        // Only an admin push reaches the public catalog. Everyone else's recipes stay on this phone.
        if canPublish, supabase.hasSession, let uid = currentUser?.id {
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
            // stay private on the importer's device. Only an admin's own original recipes sync up
            // (see publishDraft).
            var dirty = recipes.filter {
                unsyncedRecipeIds.contains($0.id) && $0.ownerId == uid && !$0.staysOnThisPhone
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

    /// True only when this recipe was imported or created by the signed-in account.
    /// A social import is theirs because its owner id was stored at import time, not because it has a source URL.
    func isOwner(of recipe: Recipe) -> Bool {
        guard let id = currentUser?.id, !id.isEmpty else { return false }
        return recipe.ownerId == id
    }

    /// Delete your own library reel. An admin can delete any recipe.
    func canDelete(_ recipe: Recipe) -> Bool {
        if currentUser?.role == .admin { return true }
        return isOwner(of: recipe)
    }

    var canPublish: Bool { currentUser?.role == .admin }

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
    
    /// Share a recipe with any CraveCircle user by their @username — no creator role required.
    /// Delivers to their cloud "Shared with you" inbox. Returns false if the username can't be found.
    func shareRecipeToUsername(recipeId: String, username: String) async -> Bool {
        let handle = AppConfig.shareHandle(username)
        guard !handle.isEmpty, let toId = await supabase.resolveProfileId(username: handle) else { return false }
        let recipe = recipes.first(where: { $0.id == recipeId })
        // A private import is not in the public catalog. Upload it as followers-only so the
        // recipient can open it (shares_select policy) without it showing up for everyone.
        if var recipe, let uid = currentUser?.id, isOwner(of: recipe) {
            if !canPublish || recipe.isImportedFromSocial { recipe.visibility = .followers }
            _ = await supabase.upsertRecipes([recipe], ownerId: uid)
        }
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
    /// Likes don't push a fresh row every tap — they merge into a single "You liked X and N others"
    /// row within a 30-minute window. One like → "You liked 'Pasta'". A second like → "You liked
    /// 'Pasta' and 1 other". After 30 min a new bundle starts. Keeps the bell quiet; still shows
    /// the user what they've been saving.
    private func bundleLikeNotification(for recipe: Recipe) {
        let window: TimeInterval = 30 * 60
        let now = Date()

        // Find the most recent like notification; merge if it's inside the window.
        if let idx = circleNotifications.firstIndex(where: { $0.title == "Liked Recipe" }),
           let when = circleNotifications[idx].createdAt,
           now.timeIntervalSince(when) < window {
            var merged = circleNotifications[idx]
            // Walk the recipe ids out of the message so repeat likes don't double-count.
            let seen = merged.bundledRecipeIds.union([recipe.id])
            let others = seen.count - 1
            merged.message = others > 0
                ? "You liked '\(recipe.title)' and \(others) other\(others == 1 ? "" : "s")"
                : "You liked '\(recipe.title)'"
            merged.recipeId = recipe.id   // tapping opens the one you most recently liked
            merged.timeAgo = "Just now"
            merged.isRead = false
            merged.bundledRecipeIdsCSV = seen.sorted().joined(separator: ",")
            circleNotifications.remove(at: idx)
            circleNotifications.insert(merged, at: 0)
        } else {
            var fresh = CircleNotificationItem(
                title: "Liked Recipe",
                message: "You liked '\(recipe.title)'",
                timeAgo: "Just now",
                symbol: "heart.fill",
                isRead: false,
                recipeId: recipe.id,
                createdAt: now
            )
            fresh.bundledRecipeIdsCSV = recipe.id
            circleNotifications.insert(fresh, at: 0)
        }
    }

    /// Opening the bell is proof the person has seen the activity — clear every unread flag so
    /// the little dot on the home-screen icon goes away. Called when the sheet is presented.
    func markAllNotificationsRead() {
        var changed = false
        for i in circleNotifications.indices where !circleNotifications[i].isRead {
            circleNotifications[i].isRead = true
            changed = true
        }
        if changed { persist(circleNotifications, "notifications.json") }
    }

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
            let title = rec.recipeTitle ?? recipes.first(where: { $0.id == rec.recipeId })?.title ?? "a recipe"
            circleNotifications.insert(
                CircleNotificationItem(title: "Recipe shared with you",
                                       message: "Someone shared '\(title)' with you",
                                       timeAgo: "Just now", symbol: "tray.and.arrow.down.fill",
                                       isRead: false, recipeId: rec.recipeId,
                                       createdAt: Date()),
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
    /// Missing dishes enough people have searched for. Only filled for the admin account.
    @Published private(set) var searchDemands: [SearchDemandAlert] = []

    var isAdmin: Bool { currentUser?.role == .admin }
    var isGuest: Bool { currentUser?.id.hasPrefix("guest_") == true || currentUser == nil }

    /// Shown once per device on first launch (guest and signed-in). After someone signs in and
    /// finishes it, their user id is also recorded so switching accounts doesn't re-trigger it.
    var needsOnboarding: Bool {
        guard appState == .signedIn else { return false }
        if !deviceOnboarded { return true }
        guard let id = currentUser?.id, !isGuest else { return false }
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
        // Device-wide flag so the first-run flow never re-shows on this install (guest or not).
        deviceOnboarded = true
        // Also record this user id so if they sign in later we don't re-trigger it on another device.
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

    /// Record one person's search for a dish we do not have. The server counts people and tells the admin at 10.
    func noteSearchMiss(_ query: String) async {
        guard SearchDemand.key(query) != nil else { return }
        await supabase.noteSearchMiss(query)
    }

    /// Admin bell + list. One ping per dish, even if more people search it later.
    func loadSearchDemands() async {
        guard isAdmin, let rows = await supabase.fetchSearchDemands() else { return }
        searchDemands = rows
        for row in rows where !circleNotifications.contains(where: { $0.message.localizedCaseInsensitiveContains(row.queryKey) }) {
            circleNotifications.insert(
                CircleNotificationItem(
                    title: "Recipe people are asking for",
                    message: row.message,
                    timeAgo: "Just now",
                    symbol: "magnifyingglass",
                    isRead: false,
                    createdAt: Date()
                ),
                at: 0
            )
        }
    }

    /// Admin: approve/reject a request; approval promotes the requester to creator server-side.
    /// Permanent, real account deletion. Required by App Store Guideline 5.1.1(v) — the old
    /// "wait 1s + sign out" would have been a rejection. Wipes the server (delete_me RPC),
    /// then clears every local scope on this device so no cached state survives.
    func deleteAccountEverywhere() async -> Bool {
        guard await supabase.deleteMyAccount() else { return false }
        // Clear every per-user file + defaults on this device for the account that just died.
        if let id = currentUser?.id { eraseAllLocalState(forUserId: id) }
        return true
    }

    private func eraseAllLocalState(forUserId id: String) {
        let defaults = UserDefaults.standard
        for key in AccountScope.personalDefaultsKeys {
            defaults.removeObject(forKey: AccountScope.defaultsKey(userId: id, key: key))
        }
        defaults.removeObject(forKey: AccountScope.defaultsKey(userId: id, key: "deleted_recipe_ids"))
        for file in AccountScope.personalFiles {
            LocalStore.remove(AccountScope.fileName(userId: id, file: file))
        }
    }

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
        hydrateLocal()
        appState = .signedIn
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
    /// Recipes this account wrote. Imports stay in All.
    var createdRecipes: [Recipe] { ownedRecipes.filter { $0.wasWrittenHere(by: currentUser?.username) } }
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
        // A share from outside the app is a write — gate it the same way the + button is gated,
        // but with the share-specific copy that reads less punitive ("we'd love you to keep it").
        guard await MainActor.run(body: { requireRealSessionOrPrompt(reason: .share) }) else { return }
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
        guard importState == .idle, let d = UserDefaults(suiteName: Self.appGroupID) else { return }
        if let job = d.string(forKey: "pending_import_job"), !job.isEmpty {
            d.removeObject(forKey: "pending_import_job")
            resumeSharedImport(jobId: job)
            return
        }
        consumePendingSharedPhoto(defaults: d)
    }

    /// A share that was a photo (recipe written on the picture) rather than a reel link.
    /// Caption and, when the post has one, the audio are folded into the same recipe.
    private func consumePendingSharedPhoto(defaults: UserDefaults) {
        guard let name = defaults.string(forKey: "pending_import_image"), !name.isEmpty,
              let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
        else { return }
        let file = folder.appendingPathComponent(name)
        guard let image = UIImage(contentsOfFile: file.path) else {
            defaults.removeObject(forKey: "pending_import_image")
            return
        }
        let caption = defaults.string(forKey: "pending_import_caption")
        let page = defaults.string(forKey: "pending_import_page_url")
        defaults.removeObject(forKey: "pending_import_image")
        defaults.removeObject(forKey: "pending_import_caption")
        defaults.removeObject(forKey: "pending_import_page_url")
        try? FileManager.default.removeItem(at: file)
        Task { await importSharedPicture(image, caption: caption, pageURL: page) }
    }

    private func importSharedPicture(_ image: UIImage, caption: String?, pageURL: String?) async {
        let ocr = await PhotoTextOCR.recognize(image)
        if Task.isCancelled { return }
        if let pageURL, !pageURL.isEmpty {
            await startImport(from: pageURL, extraOnScreen: ocr, extraCaption: caption)
            if case .failed = importState {
                await importFromPhoto(image, caption: caption, recognized: ocr)
            }
            return
        }
        await importFromPhoto(image, caption: caption, recognized: ocr)
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
    func startImport(from instagramURL: String, extraOnScreen: String? = nil, extraCaption: String? = nil) async {
        // Guests browse everything, but importing is a write — route them to sign-in instead.
        guard await MainActor.run(body: { requireRealSessionOrPrompt(reason: .importRecipe) }) else { return }
        importTask?.cancel()
        importState = .submitting
        let task = Task { [weak self] in
            guard let self else { return }
            await self._startImport(from: instagramURL, extraOnScreen: extraOnScreen, extraCaption: extraCaption)
        }
        importTask = task
        await task.value
    }

    private func _startImport(from instagramURL: String, extraOnScreen: String? = nil, extraCaption: String? = nil) async {
        do {
            // Audio only, so listening starts without a 720p file. One frame is downloaded after.
            importState = .polling(jobId: "link", status: .downloading)
            let (localAudio, reel) = try await downloadServerMedia(from: instagramURL, audioOnly: true)
            if Task.isCancelled { try? FileManager.default.removeItem(at: localAudio); return }

            let resolvedThumb = Self.absoluteMediaURL(reel.thumbnail, apiBase: config.apiBaseURL)
            // Start the poster download now, while the CDN link is fresh, overlapping the listen.
            let coverTask = Task { await Self.fetchCover(resolvedThumb) }
            let caption = [reel.caption, extraCaption].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            await _importFromVideo(
                localAudio, caption: caption.isEmpty ? nil : caption, title: reel.title, thumbnailUrl: resolvedThumb,
                reelLink: instagramURL, coverTask: coverTask, extraOnScreen: extraOnScreen)
            try? FileManager.default.removeItem(at: localAudio)
        } catch {
            if Task.isCancelled { return }   // a cancelled request throws — don't show "failed"
            print("❌ startImport error: \(error)")
            importState = .failed(message: friendlyImportError(error))
        }
    }

    /// Server file for a reel link. `audioOnly` is the listen step; video is the later picture step.
    private func downloadServerMedia(from instagramURL: String, audioOnly: Bool) async throws -> (file: URL, reel: APIClient.ReelDownloadResult) {
        let reel = try await apiClient.downloadReel(url: instagramURL, audioOnly: audioOnly)
        if Task.isCancelled { throw CancellationError() }
        guard let downloadUrl = Self.absoluteMediaURL(reel.downloadUrl, apiBase: config.apiBaseURL).flatMap(URL.init(string:)) else {
            throw URLError(.badURL)
        }
        let (tempFileUrl, _) = try await URLSession.shared.download(from: downloadUrl)
        if Task.isCancelled {
            try? FileManager.default.removeItem(at: tempFileUrl)
            throw CancellationError()
        }
        let ext = downloadUrl.pathExtension.lowercased()
        let fileExt = ext.isEmpty ? (audioOnly ? "m4a" : "mp4") : ext
        let local = FileManager.default.temporaryDirectory.appendingPathComponent("\(reel.mediaId).\(fileExt)")
        if FileManager.default.fileExists(atPath: local.path) {
            try? FileManager.default.removeItem(at: local)
        }
        try FileManager.default.moveItem(at: tempFileUrl, to: local)
        return (local, reel)
    }

    private static func absoluteMediaURL(_ path: String?, apiBase: URL) -> String? {
        guard let path, !path.isEmpty else { return nil }
        if path.starts(with: "http") { return path }
        return apiBase.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).absoluteString
    }

    /// Reel poster, saved while the link still works. Nil when the CDN refuses or the body isn't an image.
    private static func fetchCover(_ urlString: String?) async -> Data? {
        guard let urlString, let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              !data.isEmpty, UIImage(data: data) != nil else { return nil }
        return data
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
    func importFromPhoto(_ image: UIImage, caption: String? = nil, recognized: String? = nil) async {
        await importFromPhotos([image], caption: caption, recognized: recognized)
    }

    /// Same import, with every selected photo kept. The first is the cover; the rest page on the
    /// recipe the same way a recipe written here does. Capped at 6, matching the editor.
    func importFromPhotos(_ images: [UIImage], caption: String? = nil, recognized: String? = nil) async {
        guard await MainActor.run(body: { requireRealSessionOrPrompt(reason: .importRecipe) }) else { return }
        importTask?.cancel()
        importState = .submitting
        let task = Task { [weak self] in
            guard let self else { return }
            await self._importFromPhotos(images, caption: caption, recognized: recognized)
        }
        importTask = task
        await task.value
    }

    /// One photo keeps `thumb-<id>.jpg`. Extra photos are `thumb-<id>-0.jpg` … so the detail page can page them.
    nonisolated static func photoImportFilenames(recipeId: String, count: Int) -> [String] {
        let n = min(max(count, 0), 6)
        guard n > 0 else { return [] }
        if n == 1 { return ["thumb-\(recipeId).jpg"] }
        return (0..<n).map { "thumb-\(recipeId)-\($0).jpg" }
    }

    private func _importFromPhotos(_ images: [UIImage], caption: String? = nil, recognized: String? = nil) async {
        let shots = Array(images.prefix(6))
        guard !shots.isEmpty else {
            importState = .failed(message: "Couldn't read that photo.")
            return
        }
        let ocr: String
        if let recognized {
            ocr = recognized
        } else {
            var parts: [String] = []
            for image in shots {
                if Task.isCancelled { return }
                let text = await PhotoTextOCR.recognize(image)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count > 10 { parts.append(trimmed) }
            }
            ocr = parts.joined(separator: "\n")
        }
        if Task.isCancelled { return }
        importState = .polling(jobId: "on-device", status: .extracting)
        let note = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard ocr.trimmingCharacters(in: .whitespacesAndNewlines).count > 10 || note.count > 10 else {
            importState = .failed(message: "Couldn't read text from that photo. Try a clearer shot of the recipe.")
            return
        }
        var recipe = await RecipeExtractor.extract(
            transcript: "", caption: note.isEmpty ? nil : note, ownerId: currentUser?.id ?? "",
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
        let names = Self.photoImportFilenames(recipeId: recipe.id, count: shots.count)
        var saved: [String] = []
        for (image, name) in zip(shots, names) {
            guard let data = image.jpegData(compressionQuality: 0.8),
                  LocalStore.saveData(ImageDownscale.jpeg(from: data, maxPixel: 720, quality: 0.6) ?? data, to: name) != nil
            else { continue }
            saved.append(name)
        }
        recipe.thumbnailUrl = saved.first
        recipe.galleryUrls = saved.count > 1 ? saved : nil
        recipes.insert(recipe, at: 0)
        markRecipeDirty(recipe.id)
        Task { await syncRecipes() }
        importState = .done(recipeId: recipe.id)
        notifyImportDone(recipeTitle: recipe.title)
    }

    /// A food page the person opened in the in-app browser. Parsed on the phone.
    /// Nothing is sent to our server. The photo downloads after the screen has closed.
    func saveWebRecipe(_ recipe: Recipe) {
        var saved = recipe
        saved.visibility = .followers
        saved.ownerId = currentUser?.id ?? saved.ownerId
        let remote = saved.thumbnailUrl
        let referer = saved.sourceUrl
        recipes.insert(saved, at: 0)
        let id = saved.id
        if let remote, remote.hasPrefix("http") {
            Task.detached { [weak self] in
                guard let data = await Self.fetchWebCover(remote, referer: referer),
                      let jpeg = ImageDownscale.jpeg(from: data, maxPixel: 720, quality: 0.6),
                      LocalStore.saveData(jpeg, to: "thumb-\(id).jpg") != nil else { return }
                await MainActor.run { [weak self] in
                    guard let self, let i = self.recipes.firstIndex(where: { $0.id == id }) else { return }
                    let name = "thumb-\(id).jpg"
                    RecipeCoverImage.noteCoverReady(name)
                    self.recipes[i].thumbnailUrl = name
                    if self.selectedRecipe?.id == id { self.selectedRecipe?.thumbnailUrl = name }
                }
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard let current = self.recipes.first(where: { $0.id == id }) else { return }
            self.selectRecipe(current)
        }
    }

    /// Cover from the food site, not from our server. Short timeout so a slow host cannot stall the save.
    private static func fetchWebCover(_ urlString: String, referer: String?) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("image/avif,image/webp,image/*,*/*", forHTTPHeaderField: "Accept")
        if let referer, referer.hasPrefix("http") {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              (1..<8_000_000).contains(data.count) else { return nil }
        return data
    }

    func importFromVideo(_ url: URL, caption: String? = nil, title: String? = nil, thumbnailUrl: String? = nil) async {
        guard await MainActor.run(body: { requireRealSessionOrPrompt(reason: .importRecipe) }) else { return }
        importTask?.cancel()
        importState = .submitting
        let task = Task { [weak self] in
            guard let self else { return }
            await self._importFromVideo(url, caption: caption, title: title, thumbnailUrl: thumbnailUrl)
        }
        importTask = task
        await task.value
    }

    private func _importFromVideo(
        _ url: URL, caption: String? = nil, title: String? = nil, thumbnailUrl: String? = nil,
        reelLink: String? = nil, coverTask: Task<Data?, Never>? = nil, extraOnScreen: String? = nil
    ) async {
        guard await OnDeviceTranscriber.ensureAuthorized() else {
            if Task.isCancelled { return }
            importState = .failed(message: "Enable Speech Recognition in Settings to import on device.")
            return
        }
        if Task.isCancelled { return }

        // A link import passes audio. A picked video passes the file itself (export + frame stay here).
        var videoFile: URL? = reelLink == nil ? url : nil
        var ownedVideo: URL?
        var serverFrame: String?
        defer { if let ownedVideo { try? FileManager.default.removeItem(at: ownedVideo) } }

        // 1) Transcribe narration. A silent / music-only clip just yields an empty string here —
        //    that's expected, not a failure, so we fall through to on-screen text.
        //    Auto-detect the spoken language from the caption/title (captions usually match the
        //    audio) so an English reel isn't transcribed by a Tamil recognizer and vice-versa —
        //    the recipe's OUTPUT language is handled separately by translateToPreferredLanguage().
        //    The speech model should already be on the phone from language selection. If it isn't,
        //    install it under its own status so that wait isn't labeled as the listen.
        var transcript = ""
        do {
            let locale = await Self.speechLocale(forHint: [title, caption].compactMap { $0 }.joined(separator: " "))
            if await OnDeviceTranscriber.isAssetInstalled(localeID: locale) {
                importState = .polling(jobId: "on-device", status: .transcribing)
            } else {
                importState = .polling(jobId: "on-device", status: .preparing)
                try await OnDeviceTranscriber.installAssetIfNeeded(localeID: locale)
                if Task.isCancelled { return }
                importState = .polling(jobId: "on-device", status: .transcribing)
            }
            let out = try await OnDeviceTranscriber.transcribe(url: url, localeID: locale)
            transcript = out.text
            print("🎙️ On-device transcription (\(locale)) succeeded. Characters: \(transcript.count)")
        } catch {
            print("⚠️ On-device transcription failed: \(error)")
        }
        if Task.isCancelled { return }

        let coverBytes = await coverTask?.value
        let hasCover = coverBytes?.isEmpty == false

        // 2) Little or no narration => read the ON-SCREEN text with Vision OCR (many reels put the
        //    whole recipe on screen with no voiceover and no caption). A complete caption skips
        //    this download. The cover frame is fetched afterwards either way.
        var onScreen = ""
        let context = [title, caption, transcript].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        let skipVideo = reelLink != nil && !TranscriptListen.needsVideoDownload(
            transcriptCount: transcript.count, context: context, hasCover: hasCover)
        if transcript.count < 40 && !skipVideo {
            if videoFile == nil, let reelLink {
                importState = .polling(jobId: "on-device", status: .downloading)
                if let got = try? await downloadServerMedia(from: reelLink, audioOnly: false) {
                    videoFile = got.file
                    ownedVideo = got.file
                    if let t = got.reel.thumbnail, t.hasPrefix("/") { serverFrame = t }
                }
            }
            if let videoFile {
                importState = .polling(jobId: "on-device", status: .extracting)
                onScreen = await VideoTextOCR.recognizeText(url: videoFile)
                if Task.isCancelled { return }
            }
        }
        if let extraOnScreen, !extraOnScreen.isEmpty {
            onScreen = [extraOnScreen, onScreen].filter { !$0.isEmpty }.joined(separator: "\n")
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
            transcript: transcript, caption: fullCaption.isEmpty ? nil : fullCaption, ownerId: currentUser?.id ?? "",
            sourceLanguage: nil, onScreenText: onScreen, targetLanguage: AppLanguage.preferred
        )
        // Caption is still in hand here. A stated per-serving line must not be replaced by the USDA fill-in.
        let captionSource = [fullCaption, onScreen].filter { !$0.isEmpty }.joined(separator: "\n")
        if let stated = NutritionEstimator.statedPerServing(in: captionSource) {
            recipe.nutrition = stated
        }
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

        // 5) Cover is one frame of this reel, after listening. Poster only if that grab fails.
        var covered = false
        if videoFile == nil, let reelLink {
            importState = .polling(jobId: "on-device", status: .downloading)
            if let got = try? await downloadServerMedia(from: reelLink, audioOnly: false) {
                videoFile = got.file
                ownedVideo = got.file
                if let t = got.reel.thumbnail, t.hasPrefix("/") { serverFrame = t }
            }
            if Task.isCancelled { return }
        }
        if let frameURL = videoFile,
           let thumb = await VideoThumbnail.frame(from: frameURL),
           LocalStore.saveData(thumb.data, to: "thumb-\(recipe.id).\(thumb.ext)") != nil {
            recipe.thumbnailUrl = "thumb-\(recipe.id).\(thumb.ext)"
            covered = true
        }
        if !covered, let serverFrame,
           let data = await Self.fetchCover(Self.absoluteMediaURL(serverFrame, apiBase: config.apiBaseURL)),
           LocalStore.saveData(data, to: "thumb-\(recipe.id).jpg") != nil {
            recipe.thumbnailUrl = "thumb-\(recipe.id).jpg"
            covered = true
        }
        if !covered, let data = coverBytes, !data.isEmpty,
           LocalStore.saveData(data, to: "thumb-\(recipe.id).jpg") != nil {
            recipe.thumbnailUrl = "thumb-\(recipe.id).jpg"
            covered = true
        }
        if !covered, let remote = thumbnailUrl, let rurl = URL(string: remote),
           rurl.scheme?.hasPrefix("http") == true,
           let (data, _) = try? await URLSession.shared.data(from: rurl),
           LocalStore.saveData(data, to: "thumb-\(recipe.id).jpg") != nil {
            recipe.thumbnailUrl = "thumb-\(recipe.id).jpg"
            covered = true
        }
        if Task.isCancelled { return }

        if let reelLink { recipe.sourceUrl = reelLink }
        recipes.insert(recipe, at: 0)
        markRecipeDirty(recipe.id)
        Task { await syncRecipes() }
        // Do NOT auto-set selectedRecipe here.
        importState = .done(recipeId: recipe.id)
        notifyImportDone(recipeTitle: recipe.title)
    }

    /// Copy the server cover onto this phone. That file is a frame of the reel; Instagram's
    /// poster only if the frame grab failed. A CDN link expires and was being replaced by a
    /// bundled dish photo. A local `thumb-<id>.jpg` does not, and the card shows it first.
    private func storeCoverLocally(_ recipe: Recipe) async -> Recipe {
        guard let raw = recipe.thumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return recipe }
        if !raw.contains("://") && !raw.hasPrefix("/") { return recipe }
        let absolute = raw.hasPrefix("/")
            ? config.apiBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + raw
            : raw
        guard let remote = URL(string: absolute) else { return recipe }
        var request = URLRequest(url: remote)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              UIImage(data: data) != nil else { return recipe }
        let name = "thumb-\(recipe.id).jpg"
        guard LocalStore.saveData(data, to: name) != nil else { return recipe }
        var copy = recipe
        copy.thumbnailUrl = name
        return copy
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
        // Guests have no server identity — the Follow would be local-only and lie to the user.
        // Route them to the sign-in prompt instead of flipping an unauthoritative pill.
        guard requireRealSessionOrPrompt(reason: .follow) else { return }
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

    /// Shared guest gate for any write (follow, like, save, comment, import, publish, share).
    /// Returns true when the caller can proceed; false when the paywall was shown and the action
    /// was blocked. `reason` picks the paywall copy so the user sees context for what they tried.
    @discardableResult
    func requireRealSessionOrPrompt(reason: GuestPromptReason = .generic) -> Bool {
        if isGuest || !hasRealSession {
            promptGuestToSignIn(reason: reason)
            return false
        }
        return true
    }
    
    func isFollowing(creatorHandle: String) -> Bool {
        followedCreators.contains(creatorHandle)
    }

    // MARK: - Saved / Bookmark Actions
    /// Bookmark. The recipe is kept in `recipes` so Library's Saved folder and Home's library
    /// can show the card, not only the id.
    func toggleSaveRecipe(id: String, recipe: Recipe? = nil) {
        guard requireRealSessionOrPrompt(reason: .save) else { return }
        let willSave = !savedRecipeIds.contains(id)
        Task { _ = await supabase.setSave(recipeId: id, saved: willSave) }
        if savedRecipeIds.contains(id) {
            savedRecipeIds.remove(id)
            cancelCookNudge(recipeId: id)
        } else {
            if let card = recipe ?? recipes.first(where: { $0.id == id }),
               !recipes.contains(where: { $0.id == id }) {
                recipes.insert(card, at: 0)
            }
            savedRecipeIds.insert(id)
            logInteraction(recipeId: id, eventType: "save")
            if let title = (recipe ?? recipes.first(where: { $0.id == id }))?.title {
                scheduleCookNudge(recipeId: id, title: title)
            }
        }
        storeRecipeIdSet(savedRecipeIds, key: "saved_recipe_ids")
    }

    var savedRecipes: [Recipe] {
        recipes.filter { savedRecipeIds.contains($0.id) }
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
        guard requireRealSessionOrPrompt(reason: .like) else { return }
        // Mirror to the server so the like follows the user across devices. Fire-and-forget:
        // the local set still updates immediately so the heart's optimistic.
        let willLike = !likedRecipeIds.contains(id)
        Task { _ = await supabase.setLike(recipeId: id, liked: willLike) }
        if likedRecipeIds.contains(id) {
            likedRecipeIds.remove(id)
            Haptics.tap()
        } else {
            likedRecipeIds.insert(id)
            logInteraction(recipeId: id, eventType: "like")
            Haptics.success()
            if let r = recipes.first(where: { $0.id == id }) {
                bundleLikeNotification(for: r)
            }
        }
        storeRecipeIdSet(likedRecipeIds, key: "liked_recipe_ids")
    }

    // MARK: - Friend Actions
    /// Nil when the request is on the server. A message means it was not sent.
    func sendFriendRequest(usernameOrEmail: String) async -> String? {
        guard supabase.hasSession else { return "Sign in to add a friend." }
        let handle = AppConfig.shareHandle(usernameOrEmail)
        guard !handle.isEmpty else { return "Enter a username." }
        guard let otherId = await supabase.resolveProfileId(username: handle) else {
            return "No account with that username."
        }
        if otherId == currentUser?.id { return "That's your own account." }
        guard let me = currentUser?.id, await supabase.sendFriendRequest(fromUserId: me, toUserId: otherId) else {
            return "Couldn't send that request."
        }
        await loadFriendships()
        return nil
    }

    func loadFriendships() async {
        guard let rows = await supabase.fetchFriendships(), let me = currentUser?.id else { return }
        let others = rows.map { $0.requesterId == me ? $0.addresseeId : $0.requesterId }
        let names = await supabase.profileNames(ids: others)
        var friends: [FriendItem] = []
        var incoming: [FriendRequestItem] = []
        var outgoing: [FriendRequestItem] = []
        for row in rows {
            let otherId = row.requesterId == me ? row.addresseeId : row.requesterId
            let known = names[otherId]
            let username = known?.username ?? "@friend"
            let name = known?.name ?? username
            if row.status == "accepted" {
                let count = recipes.filter { ($0.ownerUsername ?? "").replacingOccurrences(of: "@", with: "").lowercased() == username.replacingOccurrences(of: "@", with: "").lowercased() }.count
                friends.append(FriendItem(id: row.id, name: name, username: username, bio: nil, recipesCount: count, avatarAsset: nil))
            } else if row.addresseeId == me {
                incoming.append(FriendRequestItem(id: row.id, name: name, username: username))
            } else {
                outgoing.append(FriendRequestItem(id: row.id, name: name, username: username))
            }
        }
        circleFriends = friends
        incomingRequests = incoming
        outgoingRequests = outgoing
    }

    func acceptFriendRequest(id: UUID) {
        Task {
            guard await supabase.acceptFriendship(id: id) else { return }
            await loadFriendships()
            let notif = CircleNotificationItem(title: "New friend", message: "You are now connected.", timeAgo: "Just now", symbol: "person.2.fill", isRead: false, createdAt: Date())
            circleNotifications.insert(notif, at: 0)
        }
    }

    func declineFriendRequest(id: UUID) {
        Task {
            guard await supabase.deleteFriendship(id: id) else { return }
            await loadFriendships()
        }
    }

    func cancelOutgoingRequest(id: UUID) {
        Task {
            guard await supabase.deleteFriendship(id: id) else { return }
            await loadFriendships()
        }
    }

    // MARK: - Share Recipe With Friend
    func shareRecipeWithFriend(recipeId: String, friend: FriendItem) async -> Bool {
        let ok = await shareRecipeToUsername(recipeId: recipeId, username: friend.username)
        guard ok, let recipe = recipes.first(where: { $0.id == recipeId }) else { return ok }
        let notif = CircleNotificationItem(title: "Recipe Shared", message: "Shared '\(recipe.title)' with \(friend.name)", timeAgo: "Just now", symbol: "paperplane.fill", isRead: false, recipeId: recipeId, createdAt: Date())
        circleNotifications.insert(notif, at: 0)
        return true
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
        guard requireRealSessionOrPrompt(reason: .publishRecipe) else { return }
        guard canPublish,
              let recipe = recipes.first(where: { $0.id == recipeId }),
              isOwner(of: recipe),
              // Never publish a recipe imported from someone else's social post — creators may only
              // publish their OWN original recipes. Social imports stay private to the importer.
              !recipe.staysOnThisPhone
        else { return }
        studioDraftIds.remove(recipeId)
        // Publishing must actually push the recipe to the cloud so followers/everyone can see it —
        // not just flip a local draft flag. Mark it dirty and sync now, then refresh the feed.
        markRecipeDirty(recipeId)
        let notif = CircleNotificationItem(title: "Recipe Published", message: "Your recipe '\(recipe.title)' is now live on your profile.", timeAgo: "Just now", symbol: "sparkles", isRead: false, recipeId: recipeId, createdAt: Date())
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
                let scaledText = IngredientListFormat.scaledLine(trimmed, from: baseServings, to: targetServings)
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

    func markAllGroceryComplete(dish: String? = nil) {
        for i in groceryItems.indices where !groceryItems[i].checked {
            if dish == nil || GrocerySort.dishName(groceryItems[i]) == dish {
                groceryItems[i].checked = true
            }
        }
    }

    /// Done shopping. No dish means the whole list. A dish name removes only that recipe.
    func finishGrocery(dish: String?) {
        groceryItems = GrocerySort.removingFinished(groceryItems, dish: dish)
    }

    // MARK: - Recipe Comments
    func comments(for recipeId: String) -> [RecipeComment] {
        recipeComments[recipeId] ?? []
    }

    /// Nil when the comment is shared. A message means it was not posted.
    func addComment(recipeId: String, text: String, image: UIImage? = nil) async -> String? {
        // Guests can't post — the comment would never leave the device.
        if isGuest || !hasRealSession {
            await MainActor.run { promptGuestToSignIn(reason: .comment) }
            return "Sign in to post a comment."
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if CommentModeration.isBlocked(trimmed) {
            return "That comment isn't allowed."
        }
        // A comment needs text OR a photo (people can share just a picture of how it turned out).
        var imageData: Data? = nil
        if let image, let raw = image.jpegData(compressionQuality: 0.8) {
            imageData = ImageDownscale.jpeg(from: raw, maxPixel: 1200, quality: 0.7) ?? raw
        }
        guard !trimmed.isEmpty || imageData != nil else { return nil }
        guard supabase.hasSession else {
            return "Sign in to comment so other people can see it."
        }
        let user = currentUser?.fullName ?? "You"
        let handle = currentUser?.username ?? "@cravecircle"
        let newComment = RecipeComment(
            recipeId: recipeId,
            authorName: user,
            authorUsername: handle.hasPrefix("@") ? handle : "@\(handle)",
            text: trimmed,
            timeAgo: "Just now",
            likesCount: 0,
            isLiked: false,
            imageData: imageData,
            createdAt: Date()
        )
        if !trimmed.isEmpty {
            let posted = await supabase.postComment(newComment)
            if !posted { return "Couldn't share that comment. Try again." }
        }
        var list = recipeComments[recipeId] ?? []
        list.insert(newComment, at: 0)
        recipeComments[recipeId] = list
        if !trimmed.isEmpty {
            await refreshComments(for: recipeId)
        }
        logInteraction(recipeId: recipeId, eventType: "comment")

        let notif = CircleNotificationItem(
            title: "Comment Posted",
            message: "You commented on '\(recipes.first(where: { $0.id == recipeId })?.title ?? "Recipe")'",
            timeAgo: "Just now",
            symbol: "bubble.left.fill",
            isRead: false,
            recipeId: recipeId,
            createdAt: Date()
        )
        circleNotifications.insert(notif, at: 0)
        return nil
    }

    /// Pull the shared thread for this recipe. Both phones read the same rows.
    func refreshComments(for recipeId: String) async {
        guard let remote = await supabase.fetchComments(recipeId: recipeId) else { return }
        let local = (recipeComments[recipeId] ?? []).filter { !CommentModeration.isBlocked($0.text) }
        recipeComments[recipeId] = RecipeComment.synced(remote: remote, local: local)
            .filter { !CommentModeration.isBlocked($0.text) }
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
        completeOnboarding(cuisines: cuisines, goals: [], decisionTime: nil, sources: [], hearAbout: nil)
    }

    /// Full onboarding completion — the Osta-style flow calls this with every pick it collected.
    /// Extras (goals / decisionTime / sources / hearAbout) are stored for future personalization
    /// hooks; today only `cuisines` feeds the recommender.
    func completeOnboarding(cuisines: Set<String>,
                            goals: Set<String>,
                            decisionTime: String?,
                            sources: Set<String>,
                            hearAbout: String?) {
        preferredCuisines = cuisines
        onboardingGoalsRaw = goals.sorted().joined(separator: ",")
        onboardingDecisionTimeRaw = decisionTime ?? ""
        onboardingSourcesRaw = sources.sorted().joined(separator: ",")
        onboardingHearAboutRaw = hearAbout ?? ""
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

    /// The Discovery reel: personalized suggestions (viewed and owned ids excluded, same as before)
    /// mixed with Home's library — owned or saved — then shuffled. Owned library cards stay in
    /// the mix after a view so that exclusion can't empty Discover of recipes the user already has.
    func discoveryReel() -> [Recipe] {
        let seen = Set(interactionHistory.filter { $0.eventType == "view" }.map(\.recipeId))
        let rejected = Set(interactionHistory.filter { $0.eventType == "not_interested" }.map(\.recipeId))
        let own = Set(recipes.filter { isOwner(of: $0) }.map(\.id))
        let excluded = seen.union(own).union(rejected)
        var picks = RecommendationEngine.suggestions(
            from: recipes,
            history: interactionHistory,
            excluding: excluded,
            preferredCuisines: preferredCuisines,
            limit: 60
        )
        if picks.isEmpty {
            // Seen everything the recommender would pick — show the rest (unseen first).
            let unseen = recipes.filter { !own.contains($0.id) && !seen.contains($0.id) }
            picks = unseen.isEmpty ? recipes.filter { !own.contains($0.id) } : unseen
        }
        let library = recipes.filter { (isOwner(of: $0) || isSaved(recipeId: $0.id)) && !rejected.contains($0.id) }
        return DiscoveryReelRefresh.mixedReel(
            library: library,
            suggestions: picks,
            ownedIDs: own,
            viewedIDs: seen
        )
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
        // Show on-device picks INSTANTLY (never wait on a slow/offline backend for first content)…
        if suggestedRecipes.isEmpty { setSuggestions(local) }
        // …then upgrade to the cross-user server feed if/when it responds.
        if let remote = await supabase.suggestedRecipes(limit: 8), !remote.isEmpty {
            setSuggestions(remote)
        } else if suggestedRecipes.isEmpty {
            setSuggestions(local)
        }
    }

    /// Publish a suggestions list + its per-item "why" reasons (behavior first, else onboarding cuisine).
    private func setSuggestions(_ list: [Recipe]) {
        suggestedRecipes = list
        var reasons: [String: String] = [:]
        for r in list {
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
            case .queued, .downloading, .preparing: stage = .downloading
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
                        recipe = await self.storeCoverLocally(recipe)
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

    /// Recipe-issue reports, newest first.
    func fetchRecipeReports() async throws -> [AdminFeedback] {
        guard isAdmin else { return [] }
        let rows = try await apiClient.fetchFeedback()
        return rows.filter { $0.type == "recipe_report" }
    }
}

enum ImportFlowState: Equatable {
    case idle
    case submitting
    case polling(jobId: String, status: ImportStatus)
    case done(recipeId: String)
    case failed(message: String)
}
