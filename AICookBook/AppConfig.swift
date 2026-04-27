import Foundation

struct AppConfig {
    let apiBaseURL: URL
    let supabaseURL: URL
    let supabaseAnonKey: String
    let isServiceRoleKeyConfigured: Bool

    static var current: AppConfig {
        let dict = Bundle.main.infoDictionary ?? [:]
        let env = ProcessInfo.processInfo.environment

        let apiBaseRaw = (dict["API_BASE_URL"] as? String) ?? env["API_BASE_URL"] ?? "http://localhost:8000"
        let supabaseURLRaw = (dict["SUPABASE_URL"] as? String) ?? env["SUPABASE_URL"] ?? "https://vaxuvotnzufwxcvsktke.supabase.co"
        let anonRaw = ((dict["SUPABASE_ANON_KEY"] as? String) ?? env["SUPABASE_ANON_KEY"] ?? defaultAnonKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let apiURL = URL(string: apiBaseRaw) ?? URL(string: "http://localhost:8000")!
        let supabaseURL = URL(string: supabaseURLRaw) ?? URL(string: "https://vaxuvotnzufwxcvsktke.supabase.co")!
        let serviceRoleDetected = jwtRole(from: anonRaw) == "service_role"
        let safeAnonKey = serviceRoleDetected ? "" : anonRaw

        return AppConfig(
            apiBaseURL: apiURL,
            supabaseURL: supabaseURL,
            supabaseAnonKey: safeAnonKey,
            isServiceRoleKeyConfigured: serviceRoleDetected
        )
    }

    // Safe fallback for local development when Info.plist mapping is missing.
    // This is the public anon key, never the service role key.
    private static let defaultAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZheHV2b3RuenVmd3hjdnNrdGtlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxODUyNjgsImV4cCI6MjA5Mjc2MTI2OH0.tPFP1jW276X6uG5fQeCsOsiK-h64YQ8S4LpDvwtaaoU"

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
