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
        // Relay on Mac forwards 10.9.229.142:8009 -> homelab 100.70.151.71:8009 so iPhone needs no Tailscale.
        let defaultHost = "http://10.9.229.142:8009"
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

    // CraveCircle cloud Supabase project (ap-south-1). The anon key is public by design —
    // it only grants what Row-Level Security allows — so it's safe to ship in the client.
    // The service_role key is never placed here.
    private static let defaultSupabaseURL = "https://wcywvaifyrkqdvkezewm.supabase.co"
    private static let defaultAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjeXd2YWlmeXJrcWR2a2V6ZXdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3NDY2NTYsImV4cCI6MjEwNDMyMjY1Nn0.ox2X1rv81Vjkb5yl1uWzWmESE0dTQUK1xC-PfAJLU2w"

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
