import Foundation

actor APIClient {
    private let config: AppConfig
    private let tokenStore: TokenStore

    init(config: AppConfig, tokenStore: TokenStore) {
        self.config = config
        self.tokenStore = tokenStore
    }
    
    func fetchGroceryList() async throws -> [GroceryItem] {
        return try await request(path: "grocery-list")
    }

    func toggleGroceryItem(id: String, checked: Bool) async throws -> GroceryItem {
        let payload = ["checked": checked]
        return try await request(path: "grocery-list/\(id)", method: "PATCH", body: payload)
    }

    func fetchProfile() async throws -> UserProfile {
        try await request(path: "profile")
    }
    
    func addRecipeToGroceryList(recipeId: String) async throws -> [GroceryItem] {
        let url = config.apiBaseURL.appending(path: "grocery-list/\(recipeId)")
        return try await request(url: url, method: "POST")
    }

    func fetchRecipes(limit: Int, offset: Int) async throws -> [Recipe] {
        var components = URLComponents(url: config.apiBaseURL.appending(path: "recipes"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        guard let url = components?.url else { throw APIError.serverError("Invalid recipes URL") }
        return try await request(url: url)
    }

    func fetchRecipe(id: String) async throws -> Recipe {
        let url = config.apiBaseURL.appending(path: "recipes/\(id)")
        return try await requestSingle(url: url)
    }

    func submitImport(url: String) async throws -> ImportSubmitResponse {
        let payload = ["url": url]
        return try await request(path: "reels/import", method: "POST", body: payload)
    }

    func fetchImportJob(jobId: String) async throws -> ImportJob {
        let url = config.apiBaseURL.appending(path: "reels/import/\(jobId)")
        return try await requestSingle(url: url)
    }

    private func request<T: Decodable>(path: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        let url = config.apiBaseURL.appending(path: path)
        return try await request(url: url, method: method, body: body)
    }

    private func requestSingle<T: Decodable>(url: URL) async throws -> T {
        let data = try await requestData(url: url, method: "GET", body: nil)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decodeSingle(data, decoder: decoder)
    }

    private func request<T: Decodable>(url: URL, method: String = "GET", body: Encodable? = nil) async throws -> T {
        let data = try await requestData(url: url, method: method, body: body)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func requestData(url: URL, method: String, body: Encodable?, didRetryAfterRefresh: Bool = false) async throws -> Data {
        guard let token = tokenStore.readAccessToken(), !token.isEmpty else { throw APIError.unauthorized }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.serverError("Invalid response") }
            guard (200..<300).contains(http.statusCode) else {
                switch http.statusCode {
                case 401:
                    guard !didRetryAfterRefresh else { throw APIError.unauthorized }
                    let refreshed = try await refreshAccessTokenIfNeeded()
                    guard refreshed else { throw APIError.unauthorized }
                    return try await requestData(url: url, method: method, body: body, didRetryAfterRefresh: true)
                case 403: throw APIError.forbidden
                case 404: throw APIError.notFound
                default: throw APIError.serverError("Server error (\(http.statusCode))")
                }
            }
            return data
        } catch let api as APIError {
            throw api
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func refreshAccessTokenIfNeeded() async throws -> Bool {
        guard
            let refreshToken = tokenStore.readRefreshToken(),
            !refreshToken.isEmpty,
            !config.supabaseAnonKey.isEmpty,
            !config.isServiceRoleKeyConfigured
        else {
            tokenStore.clearSession()
            return false
        }

        let endpoint = config.supabaseURL.appending(path: "auth/v1/token")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components?.url else {
            tokenStore.clearSession()
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                tokenStore.clearSession()
                return false
            }
            let decoder = JSONDecoder()
            let session = try decoder.decode(AuthSession.self, from: data)
            tokenStore.saveSession(accessToken: session.accessToken, refreshToken: session.refreshToken)
            return true
        } catch {
            tokenStore.clearSession()
            return false
        }
    }
}

private struct AnyEncodable: Encodable {
    private let encodeImpl: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encodeImpl = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeImpl(encoder)
    }
}

private func decodeSingle<T: Decodable>(_ data: Data, decoder: JSONDecoder) throws -> T {
    if let obj = try? decoder.decode(T.self, from: data) {
        return obj
    }
    let arr = try decoder.decode([T].self, from: data)
    guard let first = arr.first else {
        throw APIError.serverError("Expected non-empty response array")
    }
    return first
}
