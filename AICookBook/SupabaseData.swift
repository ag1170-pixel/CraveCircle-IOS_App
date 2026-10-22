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
        // Homelab PostgREST is multi-schema; CraveCircle tables live in `cravecircle`.
        req.setValue("cravecircle", forHTTPHeaderField: "Accept-Profile")
        req.setValue("cravecircle", forHTTPHeaderField: "Content-Profile")
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

    // MARK: - Current user

    /// The signed-in user's Supabase auth id (the JWT `sub` claim), or nil when not really signed in.
    func currentUserId() -> String? {
        guard let t = tokenStore.readAccessToken(), !t.isEmpty, t != "dev-preview-token" else { return nil }
        let parts = t.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var p = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while p.count % 4 != 0 { p += "=" }
        guard let d = Data(base64Encoded: p),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        return j["sub"] as? String
    }

    /// The signed-in user's own profile row (id = auth uid), so ownership + RLS writes line up.
    func fetchMyProfile() async -> UserProfile? {
        guard let uid = currentUserId(),
              let req = request(path: "rest/v1/profiles?select=*&id=eq.\(uid)&limit=1", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return (try? Self.decoder().decode([UserProfile].self, from: data))?.first
    }

    /// Update the signed-in user's own profile (RLS profiles_update_own allows id = auth.uid()).
    /// Only non-nil fields are sent. Returns true on success.
    func updateMyProfile(fullName: String?, username: String?, avatarUrl: String?) async -> Bool {
        guard let uid = currentUserId(),
              var req = request(path: "rest/v1/profiles?id=eq.\(uid)", method: "PATCH") else { return false }
        var body: [String: Any] = [:]
        if let fullName { body["full_name"] = fullName }
        if let username { body["username"] = username }
        if let avatarUrl { body["avatar_url"] = avatarUrl }
        guard !body.isEmpty else { return true }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    // MARK: - Creator requests

    /// Submit a request to become a creator (RLS: user_id must be me).
    func submitCreatorRequest(platform: String, handle: String, url: String?, note: String?) async -> Bool {
        guard hasSession, let uid = currentUserId(), var req = request(path: "rest/v1/creator_requests") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        var row: [String: Any] = ["user_id": uid, "social_platform": platform, "social_handle": handle]
        if let url, !url.isEmpty { row["social_url"] = url }
        if let note, !note.isEmpty { row["note"] = note }
        guard let body = try? JSONSerialization.data(withJSONObject: row) else { return false }
        req.httpBody = body
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    /// My own requests (RLS returns mine; an admin would get all, so callers filter as needed).
    func fetchMyCreatorRequests() async -> [CreatorRequest]? {
        guard hasSession,
              let req = request(path: "rest/v1/creator_requests?select=*&order=created_at.desc", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return try? Self.decoder().decode([CreatorRequest].self, from: data)
    }

    /// Pending requests for the admin queue (RLS: only an admin actually sees others' rows).
    func fetchPendingCreatorRequests() async -> [CreatorRequest]? {
        guard hasSession,
              let req = request(path: "rest/v1/creator_requests?select=*&status=eq.pending&order=created_at.asc", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return try? Self.decoder().decode([CreatorRequest].self, from: data)
    }

    func sendFriendRequest(fromUserId: String, toUserId: String) async -> Bool {
        guard hasSession, var req = request(path: "rest/v1/friendships") else { return false }
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        guard let body = try? JSONSerialization.data(withJSONObject: [
            "requester_id": fromUserId, "addressee_id": toUserId
        ]) else { return false }
        req.httpBody = body
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    func fetchFriendships() async -> [RemoteFriendship]? {
        guard hasSession,
              let req = request(path: "rest/v1/friendships?select=id,requester_id,addressee_id,status&order=created_at.desc", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return try? Self.decoder().decode([RemoteFriendship].self, from: data)
    }

    func profileNames(ids: [String]) async -> [String: (name: String, username: String)] {
        let unique = Array(Set(ids)).filter { !$0.isEmpty }
        guard hasSession, !unique.isEmpty,
              let req = request(path: "rest/v1/profiles?id=in.(\(unique.joined(separator: ",")))&select=id,username,full_name", method: "GET") else { return [:] }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let rows = try? Self.decoder().decode([RemoteProfileName].self, from: data) else { return [:] }
        var out: [String: (name: String, username: String)] = [:]
        for row in rows {
            let handle = row.username ?? "friend"
            out[row.id] = (row.fullName ?? handle, handle.hasPrefix("@") ? handle : "@\(handle)")
        }
        return out
    }

    func acceptFriendship(id: UUID) async -> Bool {
        guard hasSession, var req = request(path: "rest/v1/friendships?id=eq.\(id.uuidString.lowercased())", method: "PATCH") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["status": "accepted"])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    func deleteFriendship(id: UUID) async -> Bool {
        guard hasSession,
              let req = request(path: "rest/v1/friendships?id=eq.\(id.uuidString.lowercased())", method: "DELETE") else { return false }
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    /// A signed-in search that found no dish. The database counts distinct people.
    func noteSearchMiss(_ query: String) async {
        guard hasSession, var req = request(path: "rest/v1/rpc/note_search_miss") else { return }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_query": query])
        _ = try? await URLSession.shared.data(for: req)
    }

    /// Dishes that crossed the demand line. Empty for anyone who is not an admin.
    func fetchSearchDemands() async -> [SearchDemandAlert]? {
        guard hasSession,
              let req = request(path: "rest/v1/admin_alerts?kind=eq.search_demand&select=*&order=ask_count.desc", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return try? Self.decoder().decode([SearchDemandAlert].self, from: data)
    }

    /// Admin decision — approve promotes the requester to creator (RLS + is_admin() enforced server-side).
    func decideCreatorRequest(id: String, approve: Bool) async -> Bool {
        guard hasSession, var req = request(path: "rest/v1/rpc/decide_creator_request") else { return false }
        guard let body = try? JSONSerialization.data(withJSONObject: ["p_request_id": id, "p_approve": approve]) else { return false }
        req.httpBody = body
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    // MARK: - Recipe sync

    /// Pull recipes the current viewer is allowed to see. Works signed-out too — RLS still returns
    /// every `visibility = 'everyone'` recipe, which is how newly published creator/developer recipes
    /// show up in the app. Returns nil on failure so the caller keeps its local library untouched.
    func fetchRecipes(limit: Int = 50, offset: Int = 0) async -> [Recipe]? {
        guard let req = request(path: "rest/v1/recipes?select=*&order=updated_at.desc&limit=\(limit)&offset=\(offset)", method: "GET") else { return nil }
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
            // ponytail: multi-image gallery is local-only until the DB gains a `gallery_urls` column;
            // strip it so publishing doesn't 400. The cover (thumbnail_url) still syncs. Upgrade: add
            // the column (text[]), then remove this line to sync galleries cross-device.
            rows[i].removeValue(forKey: "gallery_urls")
        }
        guard let body = try? JSONSerialization.data(withJSONObject: rows) else { return false }
        req.httpBody = body
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }
    
    /// Upload a recipe cover to the public `recipe-thumbnails` Storage bucket and return its public
    /// https URL (nil on failure). Needed because imported covers are saved as device-local files —
    /// other users can't load those, so a published recipe must carry a shareable URL.
    func uploadThumbnail(data: Data, path: String, contentType: String) async -> String? {
        guard hasSession,
              var req = request(path: "storage/v1/object/recipe-thumbnails/\(path)") else { return nil }
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "x-upsert")   // overwrite if it already exists
        // Covers are content-addressed by recipe id, so they can cache hard (CDN + client).
        req.setValue("public, max-age=31536000, immutable", forHTTPHeaderField: "Cache-Control")
        req.httpBody = data
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return config.supabaseURL.absoluteString + "/storage/v1/object/public/recipe-thumbnails/\(path)"
    }

    /// Delete a recipe from the cloud. Requires a session — RLS only lets a user delete rows where owner_id = auth.uid().
    func deleteRecipe(id: String, ownerId: String) async -> Bool {
        guard hasSession,
              let req = request(path: "rest/v1/recipes?id=eq.\(id)&owner_id=eq.\(ownerId)", method: "DELETE") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) { return true }
        } catch {}
        return false
    }

    // MARK: - Social graph: profiles, follows, shares

    /// Resolve a @handle to its profile id so we can address follows/shares by the real user.
    func resolveProfileId(username: String) async -> String? {
        let handle = AppConfig.shareHandle(username)
        guard !handle.isEmpty,
              let enc = handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let req = request(path: "rest/v1/profiles?select=id&username=ilike.\(enc)&limit=1", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        return rows.first?["id"] as? String
    }

    /// Deliver a share: inserts a row the recipient can read (RLS: from_user_id must be me).
    func recordShare(recipeId: String, toUserId: String, channel: String, title: String?, thumbnail: String?) async -> Bool {
        guard hasSession, var req = request(path: "rest/v1/shares") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        var row: [String: Any] = ["recipe_id": recipeId, "to_user_id": toUserId, "channel": channel]
        if let title { row["recipe_title"] = title }
        if let thumbnail { row["recipe_thumbnail"] = thumbnail }
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

    /// Comments on one recipe, newest first. Nil when there is no session or the request fails,
    /// so the caller keeps whatever is already on the phone.
    func fetchComments(recipeId: String) async -> [RecipeComment]? {
        guard hasSession,
              let enc = recipeId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let req = request(
                path: "rest/v1/comments?recipe_id=eq.\(enc)&select=id,recipe_id,author_name,author_username,body,created_at&order=created_at.desc&limit=200",
                method: "GET"
              ) else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let rows = try? Self.decoder().decode([RemoteCommentRow].self, from: data) else { return nil }
        return rows.map { $0.comment }
    }

    /// Insert one comment as the signed-in user. The author id is the database default (`auth.uid()`).
    func postComment(_ comment: RecipeComment) async -> Bool {
        guard hasSession, !comment.text.isEmpty, var req = request(path: "rest/v1/comments") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let row: [String: Any] = [
            "id": comment.id.uuidString.lowercased(),
            "recipe_id": comment.recipeId,
            "author_name": comment.authorName,
            "author_username": comment.authorUsername,
            "body": comment.text
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: row) else { return false }
        req.httpBody = body
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
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

struct RemoteFriendship: Decodable {
    let id: UUID
    let requesterId: String
    let addresseeId: String
    let status: String
}

private struct RemoteProfileName: Decodable {
    let id: String
    let username: String?
    let fullName: String?
}

private struct RemoteCommentRow: Decodable {
    let id: UUID
    let recipeId: String
    let authorName: String
    let authorUsername: String
    let body: String
    let createdAt: Date
    var comment: RecipeComment {
        RecipeComment(
            id: id,
            recipeId: recipeId,
            authorName: authorName,
            authorUsername: authorUsername,
            text: body,
            timeAgo: "",
            createdAt: createdAt
        )
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
