//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: SupabaseAuthClient.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Authentication client managing user sessions, OAuth flows, and token persistence.
//
// 2. ARCHITECTURAL ROLE:
//    Communicates with Supabase Auth REST endpoints, exchanges Google OAuth tokens, and stores JWTs in the iOS Keychain.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "SupabaseAuthClient handles user identity. It supports Google Sign-In and anonymous guest accounts, securely persisting access and refresh tokens in the iOS Keychain using our TokenStore helper."
//
// ==============================================================================
//

// SupabaseAuthClient.swift
// CraveCircle (AICookBook)
//
// Handles all authentication flows against the Supabase Auth API: email/password sign-in,
// Google OAuth sign-in (via PKCE), sign-up, and silent token refresh. Every function sends
// HTTP requests directly to Supabase's REST auth endpoints — no third-party SDK needed.
// Tokens are saved/loaded via TokenStore (Keychain) so the session survives app restarts.

import Foundation

// MARK: - AuthSession
// Holds the two tokens Supabase gives us after a successful login.
// accessToken = proves who you are on every API call; refreshToken = get a new accessToken when it expires.
struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String

    // Map Swift camelCase property names to the snake_case keys Supabase actually sends in JSON.
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

// MARK: - APIError
// Describes every failure type the app can get from the network. Conforming to LocalizedError
// means SwiftUI can read .errorDescription to show a human-friendly message in an alert.
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
    enum SignUpOutcome {
        case ready
        case awaitingConfirmation
    }

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

    func signInWithGoogle() async throws -> AuthSession {
        guard !config.isServiceRoleKeyConfigured else {
            throw APIError.serverError("Service role key detected in app config. Use only SUPABASE_ANON_KEY on iOS.")
        }
        guard !config.supabaseAnonKey.isEmpty else {
            throw APIError.serverError("Missing Supabase anon key in app configuration.")
        }

        let idToken = try await GoogleAuthSession.shared.signInIDToken()
        let endpoint = config.supabaseURL.appending(path: "auth/v1/token")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        guard let url = components?.url else { throw APIError.serverError("Invalid auth URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "provider": "google",
            "id_token": idToken,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.serverError("Invalid response") }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(parseSupabaseAuthError(from: data, statusCode: http.statusCode))
        }
        let decoded = try JSONDecoder().decode(AuthSession.self, from: data)
        tokenStore.saveSession(accessToken: decoded.accessToken, refreshToken: decoded.refreshToken)
        return decoded
    }

    func signUp(email: String, password: String) async throws -> SignUpOutcome {
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
        if let session = try? JSONDecoder().decode(AuthSession.self, from: data) {
            tokenStore.saveSession(accessToken: session.accessToken, refreshToken: session.refreshToken)
            return .ready
        }
        return .awaitingConfirmation
    }

    /// Refresh after a 401. A network outage preserves the current credentials.
    func refreshSessionIfPossible() async -> Bool {
        guard let refreshToken = tokenStore.readRefreshToken(),
              !refreshToken.isEmpty,
              !config.supabaseAnonKey.isEmpty,
              !config.isServiceRoleKeyConfigured else { return false }

        let endpoint = config.supabaseURL.appending(path: "auth/v1/token")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components?.url else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 400 || http.statusCode == 401 { tokenStore.clearSession() }
            return false
        }
        guard let session = try? JSONDecoder().decode(AuthSession.self, from: data) else { return false }
        tokenStore.saveSession(accessToken: session.accessToken, refreshToken: session.refreshToken)
        return true
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
