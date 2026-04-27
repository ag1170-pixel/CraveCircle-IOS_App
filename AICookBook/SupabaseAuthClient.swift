import Foundation

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

enum APIError: LocalizedError {
    case unauthorized
    case notFound
    case forbidden
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please log in again."
        case .notFound: return "Not found."
        case .forbidden: return "You don't have access to this."
        case .serverError(let message): return message
        case .networkError: return "Check your connection and retry."
        case .decodingError: return "Could not parse response from server."
        }
    }
}

struct SupabaseAuthClient {
    let config: AppConfig
    let tokenStore: TokenStore

    func signIn(email: String, password: String) async throws -> AuthSession {
        guard !config.isServiceRoleKeyConfigured else {
            throw APIError.serverError("Service role key detected in app config. Use only SUPABASE_ANON_KEY on iOS.")
        }
        guard !config.supabaseAnonKey.isEmpty else {
            throw APIError.serverError("Missing Supabase anon key in app configuration.")
        }
        let endpoint = config.supabaseURL.appending(path: "auth/v1/token")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        guard let url = components?.url else { throw APIError.serverError("Invalid auth URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.serverError("Invalid response") }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            throw APIError.serverError(parseSupabaseAuthError(from: data, statusCode: http.statusCode))
        }

        do {
            let decoded = try JSONDecoder().decode(AuthSession.self, from: data)
            tokenStore.saveSession(accessToken: decoded.accessToken, refreshToken: decoded.refreshToken)
            return decoded
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func signUp(email: String, password: String) async throws {
        guard !config.isServiceRoleKeyConfigured else {
            throw APIError.serverError("Service role key detected in app config. Use only SUPABASE_ANON_KEY on iOS.")
        }
        guard !config.supabaseAnonKey.isEmpty else {
            throw APIError.serverError("Missing Supabase anon key in app configuration.")
        }

        let endpoint = config.supabaseURL.appending(path: "auth/v1/signup")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.serverError("Invalid response") }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(parseSupabaseAuthError(from: data, statusCode: http.statusCode))
        }
    }
}

private func parseSupabaseAuthError(from data: Data, statusCode: Int) -> String {
    guard
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        return "Login failed (\(statusCode))"
    }

    let message = (json["msg"] as? String)
        ?? (json["message"] as? String)
        ?? (json["error_description"] as? String)
        ?? (json["error"] as? String)

    return message ?? "Login failed (\(statusCode))"
}
