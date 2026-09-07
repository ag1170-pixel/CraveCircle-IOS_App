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

    private func request(path: String, method: String = "POST") -> URLRequest? {
        guard !config.supabaseAnonKey.isEmpty,
              let url = URL(string: config.supabaseURL.absoluteString + "/" + path) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
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

    // MARK: - Recipe sync

    /// Pull recipes the current viewer is allowed to see. Works signed-out too — RLS still returns
    /// every `visibility = 'everyone'` recipe, which is how newly published creator/developer recipes
    /// show up in the app. Returns nil on failure so the caller keeps its local library untouched.
    func fetchRecipes(limit: Int = 200) async -> [Recipe]? {
        guard let req = request(path: "rest/v1/recipes?select=*&order=updated_at.desc&limit=\(limit)", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return try? SupabaseRecipeDecoder.decode(data)
    }

    /// Fetch a single recipe by id (for deep links). Returns nil if it doesn't exist or RLS hides
    /// it (e.g. a followers-only recipe the viewer can't see).
    func fetchRecipe(id: String) async -> Recipe? {
        guard let enc = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let req = request(path: "rest/v1/recipes?select=*&id=eq.\(enc)&limit=1", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return (try? SupabaseRecipeDecoder.decode(data))?.first
    }

    /// Upsert the user's own recipes (insert or merge by id). Requires a session — RLS only lets a
    /// user write rows where owner_id = auth.uid(). `ownerId` is forced onto every row for safety.
    func upsertRecipes(_ recipes: [Recipe], ownerId: String) async -> Bool {
        guard hasSession, !recipes.isEmpty,
              var req = request(path: "rest/v1/recipes?on_conflict=id") else { return false }
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        guard let encoded = try? enc.encode(recipes),
              var rows = (try? JSONSerialization.jsonObject(with: encoded)) as? [[String: Any]] else { return false }
        for i in rows.indices {
            rows[i]["owner_id"] = ownerId
            rows[i].removeValue(forKey: "reel_url")   // computed on the client; not a column
        }
        guard let body = try? JSONSerialization.data(withJSONObject: rows) else { return false }
        req.httpBody = body
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    // MARK: - Social graph: profiles, follows, shares

    /// Resolve a @handle to its profile id so we can address follows/shares by the real user.
    func resolveProfileId(username: String) async -> String? {
        let handle = username.hasPrefix("@") ? String(username.dropFirst()) : username
        guard !handle.isEmpty,
              let enc = handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let req = request(path: "rest/v1/profiles?select=id&username=eq.\(enc)&limit=1", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        return rows.first?["id"] as? String
    }

    /// Deliver a share: inserts a row the recipient can read (RLS: from_user_id must be me).
    func recordShare(recipeId: String, toUserId: String, channel: String) async -> Bool {
        guard hasSession, var req = request(path: "rest/v1/shares") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let row: [String: Any] = ["recipe_id": recipeId, "to_user_id": toUserId, "channel": channel]
        guard let body = try? JSONSerialization.data(withJSONObject: row) else { return false }
        req.httpBody = body
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    /// Pull every share involving me (RLS returns only rows where I'm sender or recipient).
    func fetchShares() async -> [SharedRecipeRecord]? {
        guard hasSession,
              let req = request(path: "rest/v1/shares?select=*&order=created_at.desc&limit=200", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return try? Self.decoder().decode([SharedRecipeRecord].self, from: data)
    }

    /// Follow / unfollow a creator by profile id (RLS: follower_id must be me).
    func setFollow(creatorId: String, following: Bool) async -> Bool {
        guard hasSession else { return false }
        if following {
            guard var req = request(path: "rest/v1/follows") else { return false }
            req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
            guard let body = try? JSONSerialization.data(withJSONObject: ["creator_id": creatorId]) else { return false }
            req.httpBody = body
            guard let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
            return true
        } else {
            guard let req = request(path: "rest/v1/follows?creator_id=eq.\(creatorId)", method: "DELETE") else { return false }
            guard let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
            return true
        }
    }

    /// Decoder that maps snake_case columns and parses Postgres ISO-8601 timestamps (with fractional seconds).
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter(); isoPlain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let date = iso.date(from: s) ?? isoPlain.date(from: s) { return date }
            return Date()
        }
        return d
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
