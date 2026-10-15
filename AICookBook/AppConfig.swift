import Foundation

struct AppConfig {
    let apiBaseURL: URL
    let supabaseURL: URL
    let supabaseAnonKey: String
    let isServiceRoleKeyConfigured: Bool
    static let privacyPolicyURL = URL(string: "https://cravecircle.cc/privacy")!
    static let termsOfServiceURL = URL(string: "https://cravecircle.cc/terms")!
    static let supportURL = URL(string: "https://cravecircle.cc/support")!

    /// Page that opens the app. cravecircle.cc/recipe currently sends people to the marketing site.
    static func recipeWebLink(_ id: String) -> String {
        "https://import.cravecircle.cc/recipe/\(id)"
    }

    static func shareHandle(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let bare = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        return bare.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var current: AppConfig {
        let dict = Bundle.main.infoDictionary ?? [:]
        let env = ProcessInfo.processInfo.environment

        // Public Cloudflare tunnel to the import backend so users don't need Tailscale.
        let defaultHost = "https://import.cravecircle.cc"
        // A stale "Kitchen Server" pick (Homelab Tailscale IP, a LAN IP, or api.cravecircle.cc which
        // has no /reels endpoints) is unreachable for a normal phone and breaks imports with
        // "can't reach the recipe server". Ignore any such host and fall back to the public default.
        let rawCustom = UserDefaults.standard.string(forKey: "custom_api_url")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let customAPI: String? = {
            guard let c = rawCustom, !c.isEmpty, let host = URL(string: c)?.host else { return nil }
            return Self.isReachablePublicly(host) ? c : nil
        }()
        let apiBaseRaw = (customAPI != nil && !customAPI!.isEmpty) ? customAPI! : ((dict["API_BASE_URL"] as? String) ?? env["API_BASE_URL"] ?? defaultHost)
        let supabaseURLRaw = (dict["SUPABASE_URL"] as? String) ?? env["SUPABASE_URL"] ?? defaultSupabaseURL
        let anonRaw = ((dict["SUPABASE_ANON_KEY"] as? String) ?? env["SUPABASE_ANON_KEY"] ?? defaultAnonKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let apiURL = URL(string: apiBaseRaw) ?? URL(string: defaultHost)!
        let supabaseURL = URL(string: supabaseURLRaw) ?? URL(string: defaultSupabaseURL)!
        let serviceRoleDetected = jwtRole(from: anonRaw) == "service_role"
        let safeAnonKey = serviceRoleDetected ? "" : anonRaw

        return AppConfig(
            apiBaseURL: apiURL,
            supabaseURL: supabaseURL,
            supabaseAnonKey: safeAnonKey,
            isServiceRoleKeyConfigured: serviceRoleDetected
        )
    }

    // Homelab self-hosted Supabase, schema `cravecircle` (not GGSApple `public`), reached over public
    // HTTPS via the Cloudflare named tunnel `crave_circle_backend` → the isolated `cravecircle-gateway`
    // (a cravecircle-only PostgREST + shared GoTrue). No Tailscale required, and only the cravecircle
    // schema is exposed — the other schemas on the shared instance stay private.
    // Anon key is public by design (RLS-gated). Never ship service_role.
    private static let defaultSupabaseURL = "https://db.cravecircle.cc"
    private static let defaultAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzg0MzIzMjk1LCJleHAiOjIwOTk2ODMyOTV9.rfoxjE7PA4mov-tN7nebaT_BbdN5fLiiDCJDrE_kJeM"

    /// False for hosts a normal phone can't reach: loopback, LAN, Tailscale CGNAT (100.64–100.127),
    /// and api.cravecircle.cc (the go-api, which has no /reels import endpoints). Public hostnames pass.
    static func isReachablePublicly(_ host: String) -> Bool {
        if host == "localhost" || host == "api.cravecircle.cc" { return false }
        let o = host.split(separator: ".").compactMap { Int($0) }
        guard o.count == 4 else { return true }   // a real hostname (not a bare IP) → assume public
        switch (o[0], o[1]) {
        case (127, _), (10, _), (192, 168), (169, 254): return false
        case (172, 16...31): return false
        case (100, 64...127): return false         // Tailscale / CGNAT
        default: return true
        }
    }

    private static func jwtRole(from token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard
            let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json["role"] as? String
    }
}
