import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum GoogleAuthError: LocalizedError {
    case canceled
    case missingTokens
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .canceled: return "Google sign-in was cancelled."
        case .missingTokens: return "Google did not return a session."
        case .failed(let message): return message
        }
    }
}

/// Native Google OAuth (PKCE) against accounts.google.com — never loads Tailscale MagicDNS in Safari.
/// iOS Simulator cannot resolve `*.ts.net`, which is why the old GoTrue authorize URL failed.
enum GoogleOAuthConfig {
    static let iosClientID = "752209970913-4lptajjg9djnasfhs5qhjg060bhe4s9l.apps.googleusercontent.com"
    static let reversedClientID = "com.googleusercontent.apps.752209970913-4lptajjg9djnasfhs5qhjg060bhe4s9l"
    static let redirectURI = "\(reversedClientID):/oauth2redirect"
}

@MainActor
final class GoogleAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleAuthSession()
    private var session: ASWebAuthenticationSession?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
    }

    func signInIDToken() async throws -> String {
        let verifier = PKCE.makeVerifier()
        let challenge = PKCE.challenge(for: verifier)
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleOAuthConfig.iosClientID),
            URLQueryItem(name: "redirect_uri", value: GoogleOAuthConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authorizeURL = components.url else {
            throw GoogleAuthError.failed("Invalid Google authorize URL")
        }

        let callback = try await start(authorizeURL: authorizeURL, scheme: GoogleOAuthConfig.reversedClientID)
        let code = try Self.authorizationCode(from: callback)
        return try await Self.exchangeCodeForIDToken(code: code, verifier: verifier)
    }

    private func start(authorizeURL: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authorizeURL, callbackURLScheme: scheme) { url, error in
                self.session = nil
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: GoogleAuthError.canceled)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: GoogleAuthError.missingTokens)
                    return
                }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                self.session = nil
                continuation.resume(throwing: GoogleAuthError.failed("Could not open Google sign-in."))
            }
        }
    }

    private static func authorizationCode(from url: URL) throws -> String {
        let blob = url.query ?? url.fragment ?? ""
        var items: [String: String] = [:]
        for pair in blob.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            items[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
        }
        if let error = items["error"] {
            throw GoogleAuthError.failed(items["error_description"] ?? error)
        }
        guard let code = items["code"], !code.isEmpty else {
            throw GoogleAuthError.missingTokens
        }
        return code
    }

    private static func exchangeCodeForIDToken(code: String, verifier: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code": code,
            "client_id": GoogleOAuthConfig.iosClientID,
            "redirect_uri": GoogleOAuthConfig.redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier,
        ]
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        request.httpBody = body
            .map { key, value in
                let enc = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(key)=\(enc)"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? "token exchange failed"
            throw GoogleAuthError.failed(raw)
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let idToken = json["id_token"] as? String,
            !idToken.isEmpty
        else {
            throw GoogleAuthError.missingTokens
        }
        return idToken
    }
}

private enum PKCE {
    static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    static func challenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncoded()
    }
}

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
