import Foundation

struct AppConfig {
    let apiBaseURL: URL
    let supabaseURL: URL
    let supabaseAnonKey: String
    let isServiceRoleKeyConfigured: Bool
    /// USDA FoodData Central key for authoritative nutrition. Free key: fdc.nal.usda.gov/api-key-signup.
    /// DEMO_KEY works but is rate-limited (~30/hr) — replace via SUPABASE-style Info.plist/env override.
    let usdaApiKey: String

    static let privacyPolicyURL = URL(string: "https://cravecircle.cc/privacy")!
    static let termsOfServiceURL = URL(string: "https://cravecircle.cc/terms")!
    static let supportURL = URL(string: "https://cravecircle.cc/support")!

    static var current: AppConfig {
        let dict = Bundle.main.infoDictionary ?? [:]
        let env = ProcessInfo.processInfo.environment

        let customAPI = UserDefaults.standard.string(forKey: "custom_api_url")?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Public Cloudflare tunnel to go-api backend so users don't need Tailscale.
        let defaultHost = "https://import.cravecircle.cc"
        let apiBaseRaw = (customAPI != nil && !customAPI!.isEmpty) ? customAPI! : ((dict["API_BASE_URL"] as? String) ?? env["API_BASE_URL"] ?? defaultHost)
        let supabaseURLRaw = (dict["SUPABASE_URL"] as? String) ?? env["SUPABASE_URL"] ?? defaultSupabaseURL
        let anonRaw = ((dict["SUPABASE_ANON_KEY"] as? String) ?? env["SUPABASE_ANON_KEY"] ?? defaultAnonKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let apiURL = URL(string: apiBaseRaw) ?? URL(string: defaultHost)!
        let supabaseURL = URL(string: supabaseURLRaw) ?? URL(string: defaultSupabaseURL)!
        let serviceRoleDetected = jwtRole(from: anonRaw) == "service_role"
        let safeAnonKey = serviceRoleDetected ? "" : anonRaw

        let usdaKey = ((dict["USDA_API_KEY"] as? String) ?? env["USDA_API_KEY"] ?? "DEMO_KEY")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return AppConfig(
            apiBaseURL: apiURL,
            supabaseURL: supabaseURL,
            supabaseAnonKey: safeAnonKey,
            isServiceRoleKeyConfigured: serviceRoleDetected,
            usdaApiKey: usdaKey.isEmpty ? "DEMO_KEY" : usdaKey
        )
    }

    // Homelab self-hosted Supabase, schema `cravecircle` (not GGSApple `public`), reached over public
    // HTTPS via the Cloudflare named tunnel `crave_circle_backend` → the isolated `cravecircle-gateway`
    // (a cravecircle-only PostgREST + shared GoTrue). No Tailscale required, and only the cravecircle
    // schema is exposed — the other schemas on the shared instance stay private.
    // Anon key is public by design (RLS-gated). Never ship service_role.
    private static let defaultSupabaseURL = "https://db.cravecircle.cc"
    private static let defaultAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzg0MzIzMjk1LCJleHAiOjIwOTk2ODMyOTV9.rfoxjE7PA4mov-tN7nebaT_BbdN5fLiiDCJDrE_kJeM"

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
