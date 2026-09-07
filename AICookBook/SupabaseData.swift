//
//  SupabaseData.swift
//  CraveCircle (AICookBook)
//
//  Thin authenticated client for the CraveCircle Supabase project — calls PostgREST RPCs and
//  tables using the signed-in user's JWT (from TokenStore), so Row-Level Security applies.
//  Used for telemetry ingest and the cross-user suggestion feed. Every call fails soft: callers
//  fall back to the on-device path when there's no session or the network is down.
//

import Foundation

struct SupabaseData {
    let config: AppConfig
    let tokenStore: TokenStore

    /// True only when we have a real Supabase session token to authenticate with. Without one the
    /// RLS-protected RPCs would 401, so callers should skip the network and use the on-device path.
    var hasSession: Bool {
        guard let t = tokenStore.readAccessToken(), !t.isEmpty else { return false }
        return t != "dev-preview-token"   // the DEBUG dev-bypass placeholder is not a real JWT
    }

    private func request(path: String) -> URLRequest? {
        guard !config.supabaseAnonKey.isEmpty else { return nil }
        let url = config.supabaseURL.appending(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        let bearer = tokenStore.readAccessToken() ?? config.supabaseAnonKey
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        return req
    }

    /// Batch-ingest interaction events. Returns true only on a 2xx so the caller can safely clear
    /// the queue; any failure leaves the events queued for a later flush.
    func logInteractions(_ events: [AppEnvironment.InteractionEvent]) async -> Bool {
        guard hasSession, !events.isEmpty, var req = request(path: "rest/v1/rpc/log_interactions") else { return false }
        let payload = events.map { e -> [String: Any] in
            var d: [String: Any] = [
                "recipeId": e.recipeId,
                "eventType": e.eventType,
                "timestamp": ISO8601DateFormatter().string(from: e.timestamp)
            ]
            if let s = e.durationSeconds { d["durationSeconds"] = s }
            return d
        }
        guard let body = try? JSONSerialization.data(withJSONObject: ["p_events": payload]) else { return false }
        req.httpBody = body
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    /// Cross-user personalized feed from the server RPC. Returns nil (not empty) on any failure so
    /// the caller can tell "server said no recipes" from "couldn't reach server" and fall back.
    func suggestedRecipes(limit: Int) async -> [Recipe]? {
        guard hasSession, var req = request(path: "rest/v1/rpc/get_suggested_recipes") else { return nil }
        guard let body = try? JSONSerialization.data(withJSONObject: ["p_limit": limit]) else { return nil }
        req.httpBody = body
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return try? SupabaseRecipeDecoder.decode(data)
    }
}

/// Decodes the snake_case recipe rows the RPC returns into the app's `Recipe` model.
enum SupabaseRecipeDecoder {
    static func decode(_ data: Data) throws -> [Recipe] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Recipe].self, from: data)
    }
}
