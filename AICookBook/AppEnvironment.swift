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
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var selectedRecipe: Recipe?
    @Published private(set) var importState: ImportFlowState = .idle
    @Published var errorMessage: String?

    let config: AppConfig
    private let tokenStore: TokenStore
    private let authClient: SupabaseAuthClient
    private let apiClient: APIClient
    private var importTask: Task<Void, Never>?

    init(
        config: AppConfig = .current,
        tokenStore: TokenStore = TokenStore()
    ) {
        self.config = config
        self.tokenStore = tokenStore
        self.authClient = SupabaseAuthClient(config: config, tokenStore: tokenStore)
        self.apiClient = APIClient(config: config, tokenStore: tokenStore)
    }

    func bootstrap() async {
        guard tokenStore.readAccessToken() != nil else {
            appState = .signedOut
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

    func startImport(from instagramURL: String) async {
        do {
            importState = .submitting
            let response = try await apiClient.submitImport(url: instagramURL)
            importState = .polling(jobId: response.jobId, status: response.status ?? .queued)
            beginPolling(jobId: response.jobId)
        } catch {
            importState = .failed(message: error.localizedDescription)
        }
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
                        let recipe = try await self.apiClient.fetchRecipe(id: recipeId)
                        await MainActor.run {
                            if let index = self.recipes.firstIndex(where: { $0.id == recipe.id }) {
                                self.recipes[index] = recipe
                            } else {
                                self.recipes.insert(recipe, at: 0)
                            }
                            self.selectedRecipe = recipe
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
