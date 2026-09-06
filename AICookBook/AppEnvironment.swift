import Foundation
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    enum AppState {
        case loading
        case signedOut
        case signedIn
    }

    @Published private(set) var appState: AppState = .loading
    @Published private(set) var currentUser: UserProfile?
    @Published private(set) var recipes: [Recipe] = [] { didSet { persist(recipes, "recipes.json") } }
    @Published private(set) var selectedRecipe: Recipe?
    @Published private(set) var importState: ImportFlowState = .idle
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
    @Published private(set) var savedRecipeIds: Set<String> = ["recipe-spicy-paneer-wrap", "recipe-butter-chicken"]
    
    // Friends & Circle
    @Published private(set) var circleFriends: [FriendItem] = FriendItem.samples
    @Published private(set) var incomingRequests: [FriendRequestItem] = FriendRequestItem.incomingSamples
    @Published private(set) var outgoingRequests: [FriendRequestItem] = FriendRequestItem.outgoingSamples
    
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
    }

    /// Load the persisted library (recipes/collections/grocery/flags) from disk, merging any new
    /// bundled sample recipes by id so content updates still appear. Runs once, before autosave arms.
    private func hydrateLocal() {
        let saved = LocalStore.load([Recipe].self, from: "recipes.json") ?? []
        var merged = saved
        for (i, r) in merged.enumerated() {
            if let fresh = Recipe.placeholderRecipes.first(where: { $0.id == r.id }) {
                merged[i] = fresh
            }
        }
        let savedIds = Set(merged.map(\.id))
        for sample in Recipe.placeholderRecipes where !savedIds.contains(sample.id) { merged.append(sample) }
        recipes = merged

        ownedCollections = LocalStore.load([CollectionItem].self, from: "owned_collections.json") ?? CollectionItem.ownedSamples
        sharedCollections = LocalStore.load([CollectionItem].self, from: "shared_collections.json") ?? CollectionItem.sharedSamples
        groceryItems = LocalStore.load([GroceryItem].self, from: "grocery.json") ?? GroceryItem.demo
        if let drafts = LocalStore.load([String].self, from: "studio_drafts.json") { studioDraftIds = Set(drafts) }
        if let follows = LocalStore.load([String].self, from: "followed_creators.json") { followedCreators = Set(follows) }

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
            #if DEBUG
            // Dev preview: backend auth is down (deleted Supabase), so open the app signed-in with
            // the local library (hydrated above) instead of the login wall. DEBUG only.
            currentUser = UserProfile(id: "preview-user", username: "@aicookbook", fullName: "You", avatarUrl: nil, role: .admin)
            appState = .signedIn
            #else
            appState = .signedOut
            #endif
            return
        }

        do {
            currentUser = try await apiClient.fetchProfile()
            appState = .signedIn
            await refreshRecipes()
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
            do {
                currentUser = try await apiClient.fetchProfile()
            } catch {
                currentUser = fallbackUser(email: email)
            }
            appState = .signedIn
            await refreshRecipes()
        } catch {
            appState = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async throws {
        try await authClient.signUp(email: email, password: password)
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
    }

    func refreshRecipes() async {
        do {
            recipes = try await apiClient.fetchRecipes(limit: 20, offset: 0)
            if recipes.isEmpty {
                recipes = Recipe.placeholderRecipes
            }
        } catch {
            recipes = Recipe.placeholderRecipes
            errorMessage = "Could not load recipes from backend. Showing preview data."
        }
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

    func selectRecipe(_ recipe: Recipe) {
        selectedRecipe = recipe
    }

    func dismissRecipeDetail() {
        selectedRecipe = nil
    }

    /// Save edits to a recipe the user owns (updates the list + open detail).
    func updateRecipe(_ updated: Recipe) {
        if let i = recipes.firstIndex(where: { $0.id == updated.id }) { recipes[i] = updated }
        if selectedRecipe?.id == updated.id { selectedRecipe = updated }
        // TODO: PATCH /recipes/{id} once the backend is reachable.
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

    func enrollInStudio() {
        guard var user = currentUser, user.role == .user else { return }
        user.role = .creator
        currentUser = user
    }

    func deleteOwnedRecipe(id: String) {
        guard let recipe = recipes.first(where: { $0.id == id }), canDelete(recipe) else { return }
        recipes.removeAll { $0.id == id }
        savedRecipeIds.remove(id)
        likedRecipeIds.remove(id)
        studioDraftIds.remove(id)
        if selectedRecipe?.id == id { selectedRecipe = nil }
    }

    // MARK: - Owner-aware recipe collections (single source of truth for "your" recipes)
    /// Recipes the signed-in user created or imported.
    var ownedRecipes: [Recipe] { recipes.filter { isOwner(of: $0) } }
    /// The user's own recipes still in Studio draft.
    var myDrafts: [Recipe] { ownedRecipes.filter { isDraft(recipeId: $0.id) } }
    /// The user's own recipes that are published.
    var myPublished: [Recipe] { ownedRecipes.filter { !isDraft(recipeId: $0.id) } }

    // Shared with the Share Extension (same literal strings live in ShareViewController).
    static let appGroupID = "group.com.anassyed.AICookBook"
    static let pendingImportKey = "pending_import_url"

    /// Pull a link shared into the app from the system Share sheet and import it.
    /// No-op when there's nothing pending or an import is already running.
    func importFromSharedURL() async {
        guard
            let defaults = UserDefaults(suiteName: Self.appGroupID),
            let urlString = defaults.string(forKey: Self.pendingImportKey),
            !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        defaults.removeObject(forKey: Self.pendingImportKey)   // consume once

        guard importState == .idle else { return }
        await startImport(from: urlString)
    }

    func startImport(from instagramURL: String) async {
        do {
            importState = .submitting
            let targetLanguage = UserDefaults.standard.string(forKey: LanguagePrefs.key) ?? LanguagePrefs.default.rawValue
            let response = try await apiClient.submitImport(url: instagramURL, targetLanguage: targetLanguage)
            importState = .polling(jobId: response.jobId, status: response.status ?? .queued)
            beginPolling(jobId: response.jobId)
        } catch {
            importState = .failed(message: error.localizedDescription)
        }
    }

    /// On-device import: video → transcribe (Neural Engine) → structure (Foundation Models) → recipe.
    /// No backend, no auth, no download. Drives the same import-progress UI.
    func importFromVideo(_ url: URL) async {
        importState = .submitting
        guard await OnDeviceTranscriber.ensureAuthorized() else {
            importState = .failed(message: "Enable Speech Recognition in Settings to import on device.")
            return
        }
        importState = .polling(jobId: "on-device", status: .transcribing)

        // 1) Transcribe narration. A silent / music-only clip just yields an empty string here —
        //    that's expected, not a failure, so we fall through to on-screen text.
        var transcript = ""
        if let out = try? await OnDeviceTranscriber.transcribe(url: url, localeID: AppLanguage.preferred.localeID) {
            transcript = out.text
        }

        // 2) Little or no narration => read the ON-SCREEN text with Vision OCR (many reels put the
        //    whole recipe on screen with no voiceover and no caption).
        var onScreen = ""
        if transcript.count < 40 {
            importState = .polling(jobId: "on-device", status: .extracting)
            onScreen = await VideoTextOCR.recognizeText(url: url)
        }

        // 3) Structure it (Foundation Models when available, else heuristic).
        importState = .polling(jobId: "on-device", status: .extracting)
        var recipe = await RecipeExtractor.extract(
            transcript: transcript, caption: nil, ownerId: currentUser?.id ?? "you",
            sourceLanguage: nil, onScreenText: onScreen
        )

        // 4) Nothing readable anywhere (no audio, no caption, no on-screen text) => fail with a
        //    clear reason instead of saving an empty recipe.
        guard recipeHasContent(recipe) else {
            importState = .failed(message: "We couldn't find a recipe in that video — no spoken steps and no on-screen text we could read. Try a clip where the creator narrates or lists the recipe.")
            return
        }

        // 5) Give it a real cover: grab a representative frame from the video and store it locally,
        //    so the imported recipe looks like a real recipe instead of the generic fallback.
        if let data = await VideoThumbnail.jpeg(from: url),
           let file = LocalStore.saveData(data, to: "thumb-\(recipe.id).jpg") {
            recipe.thumbnailUrl = file.absoluteString
        }

        recipes.insert(recipe, at: 0)
        // Do NOT auto-set selectedRecipe here.
        importState = .done(recipeId: recipe.id)
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
        if followedCreators.contains(creatorHandle) {
            followedCreators.remove(creatorHandle)
        } else {
            followedCreators.insert(creatorHandle)
        }
    }
    
    func isFollowing(creatorHandle: String) -> Bool {
        followedCreators.contains(creatorHandle)
    }

    // MARK: - Saved / Bookmark Actions
    func toggleSaveRecipe(id: String) {
        if savedRecipeIds.contains(id) {
            savedRecipeIds.remove(id)
        } else {
            savedRecipeIds.insert(id)
        }
        UserDefaults.standard.set(Array(savedRecipeIds), forKey: "saved_recipe_ids")
    }
    
    func isSaved(recipeId: String) -> Bool {
        savedRecipeIds.contains(recipeId)
    }

    // MARK: - Liked / Heart Actions
    @Published private(set) var likedRecipeIds: Set<String> = ["recipe_butter_chicken", "recipe_hot_honey_chicken"]

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
              isOwner(of: recipe)
        else { return }
        studioDraftIds.remove(recipeId)
        if let recipe = recipes.first(where: { $0.id == recipeId }) {
            let notif = CircleNotificationItem(title: "Recipe Published", message: "Your recipe '\(recipe.title)' is now live on your profile.", timeAgo: "Just now", symbol: "sparkles", isRead: false, recipeId: recipeId)
            circleNotifications.insert(notif, at: 0)
        }
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

        for group in recipe.ingredients {
            for item in group.items {
                let trimmed = item.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                let scaledText = IngredientScaler.scale(text: trimmed, from: baseServings, to: targetServings)
                let newItem = GroceryItem(id: UUID().uuidString, ingredientName: scaledText, checked: false)
                groceryItems.append(newItem)
                added += 1
            }
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

    // MARK: - Recipe Comments
    func comments(for recipeId: String) -> [RecipeComment] {
        recipeComments[recipeId] ?? []
    }

    func addComment(recipeId: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let user = currentUser?.fullName ?? "You"
        let handle = currentUser?.username ?? "@cravecircle"
        let newComment = RecipeComment(
            recipeId: recipeId,
            authorName: user,
            authorUsername: handle,
            text: trimmed,
            timeAgo: "Just now",
            likesCount: 0,
            isLiked: false
        )
        var list = recipeComments[recipeId] ?? []
        list.insert(newComment, at: 0)
        recipeComments[recipeId] = list

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

    func cancelImport() {
        importTask?.cancel()
        importState = .idle
    }
    
    private func beginPolling(jobId: String) {
        importTask?.cancel()
        importTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
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
                        await MainActor.run {
                            if let index = self.recipes.firstIndex(where: { $0.id == recipe.id }) {
                                self.recipes[index] = recipe
                            } else {
                                self.recipes.insert(recipe, at: 0)
                            }
                            // Do NOT auto-set selectedRecipe here. It causes a presentation conflict
                            // if the ImportProgressScreen sheet is currently active. Let the user
                            // explicitly tap "View" or "Open recipe" to select it.
                            self.importState = .done(recipeId: recipeId)
                        }
                        return
                    }
                    if job.status == .error {
                        await MainActor.run {
                            self.importState = .failed(message: job.errorMessage ?? "Import failed. Try another link.")
                        }
                        return
                    }
                } catch {
                    await MainActor.run {
                        self.importState = .failed(message: error.localizedDescription)
                    }
                    return
                }

                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func fallbackUser(email: String? = nil) -> UserProfile {
        let base = email?.split(separator: "@").first.map(String.init) ?? "chef"
        return UserProfile(id: "local-\(base)", username: "@\(base)", fullName: "Local Profile", avatarUrl: nil)
    }
}

enum ImportFlowState: Equatable {
    case idle
    case submitting
    case polling(jobId: String, status: ImportStatus)
    case done(recipeId: String)
    case failed(message: String)
}
