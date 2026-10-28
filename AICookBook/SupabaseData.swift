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
        jwtClaims()?["sub"] as? String
    }

    /// The signed-in user's email as stored on the Supabase auth row. Returned by Google / email
    /// providers in the JWT's `email` claim — needed for things like the founder-admin check that
    /// must work after a Google sign-in (where the caller never typed an email).
    func currentUserEmail() -> String? {
        if let s = jwtClaims()?["email"] as? String, !s.isEmpty { return s }
        return nil
    }

    private func jwtClaims() -> [String: Any]? {
        guard let t = tokenStore.readAccessToken(), !t.isEmpty, t != "dev-preview-token" else { return nil }
        let parts = t.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var p = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while p.count % 4 != 0 { p += "=" }
        guard let d = Data(base64Encoded: p),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        return j
    }

    /// The signed-in user's own profile row (id = auth uid), so ownership + RLS writes line up.
    func fetchMyProfile() async -> UserProfile? {
        guard let uid = currentUserId(),
              let req = request(path: "rest/v1/profiles?select=*&id=eq.\(uid)&limit=1", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return (try? Self.decoder().decode([UserProfile].self, from: data))?.first
    }

    /// Patch the signed-in user's role (RLS must permit the caller; founder self-elevate relies
    /// on a policy that lets `id = auth.uid()` set role in {.user, .creator, .admin}). Nil-safe:
    /// returns false if the write failed so the caller doesn't claim an elevation that didn't land.
    func updateMyRole(_ role: AccountRole) async -> Bool {
        guard let uid = currentUserId(),
              var req = request(path: "rest/v1/profiles?id=eq.\(uid)", method: "PATCH") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["role": role.rawValue])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    /// Stamp `profiles.onboarded_at = now()` so this id skips the first-run flow on any device.
    /// Idempotent — a repeat call just rewrites the timestamp.
    func markProfileOnboarded() async -> Bool {
        guard let uid = currentUserId(),
              var req = request(path: "rest/v1/profiles?id=eq.\(uid)", method: "PATCH") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["onboarded_at": ISO8601DateFormatter().string(from: Date())])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    /// Update the signed-in user's own profile (RLS profiles_update_own allows id = auth.uid()).
    /// Only non-nil fields are sent. Returns .ok on success, .usernameTaken on 23505 unique
    /// violation for the username column, .failed on anything else. Callers surface the specific
    /// case so the user can rename.
    enum ProfileUpdateResult { case ok, usernameTaken, failed }
    func updateMyProfile(fullName: String? = nil,
                         username: String? = nil,
                         avatarUrl: String? = nil,
                         bio: String? = nil,
                         instagramUrl: String? = nil,
                         tiktokUrl: String? = nil,
                         youtubeUrl: String? = nil,
                         facebookUrl: String? = nil,
                         pinterestUrl: String? = nil) async -> ProfileUpdateResult {
        guard let uid = currentUserId(),
              var req = request(path: "rest/v1/profiles?id=eq.\(uid)", method: "PATCH") else { return .failed }
        var body: [String: Any] = [:]
        if let fullName { body["full_name"] = fullName }
        if let username { body["username"] = username }
        if let avatarUrl { body["avatar_url"] = avatarUrl }
        // Empty string clears the field server-side; nil leaves it untouched.
        if let bio { body["bio"] = bio.isEmpty ? NSNull() : bio }
        if let instagramUrl { body["instagram_url"] = instagramUrl.isEmpty ? NSNull() : instagramUrl }
        if let tiktokUrl    { body["tiktok_url"]    = tiktokUrl.isEmpty ? NSNull() : tiktokUrl }
        if let youtubeUrl   { body["youtube_url"]   = youtubeUrl.isEmpty ? NSNull() : youtubeUrl }
        if let facebookUrl  { body["facebook_url"]  = facebookUrl.isEmpty ? NSNull() : facebookUrl }
        if let pinterestUrl { body["pinterest_url"] = pinterestUrl.isEmpty ? NSNull() : pinterestUrl }
        guard !body.isEmpty else { return .ok }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return .failed }
        if (200..<300).contains(http.statusCode) { return .ok }
        // Postgres unique-violation (SQLSTATE 23505). Supabase surfaces it as {code: "23505", …}.
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = json["code"] as? String, code == "23505" { return .usernameTaken }
        return .failed
    }

    /// Admin-only: toggle another user's blue tick. Protected by the `verified_admin_only` RLS
    /// policy so a non-admin's PATCH is rejected server-side even if the UI slips through.
    func setUserVerified(userId: String, verified: Bool) async -> Bool {
        guard var req = request(path: "rest/v1/profiles?id=eq.\(userId)", method: "PATCH") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["verified": verified])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    /// Fetch any user's public profile by id — used by CreatorProfileSheet to show bio, socials
    /// and verified status for a creator the viewer hasn't signed in as.
    func fetchProfile(id: String) async -> UserProfile? {
        guard let req = request(path: "rest/v1/profiles?select=*&id=eq.\(id)&limit=1", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return (try? Self.decoder().decode([UserProfile].self, from: data))?.first
    }

    /// Fetch a public profile by username (CreatorProfileSheet reads this when it only has
    /// the handle). Case-insensitive match against profiles.username.
    func fetchProfile(username: String) async -> UserProfile? {
        let clean = username.hasPrefix("@") ? String(username.dropFirst()) : username
        let enc = clean.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? clean
        guard let req = request(path: "rest/v1/profiles?select=*&username=ilike.\(enc)&limit=1", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return (try? Self.decoder().decode([UserProfile].self, from: data))?.first
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
    // MARK: - Likes + Saves (server-mirrored so a user's state follows them across devices)

    /// Toggle a like on a recipe. Does an INSERT on true, DELETE on false. Returns false silently
    /// on no-session so the client falls back to its device-local set.
    func setLike(recipeId: String, liked: Bool) async -> Bool {
        guard hasSession, let uid = currentUserId() else { return false }
        if liked {
            guard var req = request(path: "rest/v1/recipe_likes", method: "POST") else { return false }
            req.setValue("resolution=ignore-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["user_id": uid, "recipe_id": recipeId])
            guard let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
            return true
        } else {
            let path = "rest/v1/recipe_likes?user_id=eq.\(uid)&recipe_id=eq.\(recipeId)"
            guard let req = request(path: path, method: "DELETE") else { return false }
            guard let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
            return true
        }
    }

    /// Toggle a save (bookmark) — same shape as `setLike`, different table.
    func setSave(recipeId: String, saved: Bool) async -> Bool {
        guard hasSession, let uid = currentUserId() else { return false }
        if saved {
            guard var req = request(path: "rest/v1/recipe_saves", method: "POST") else { return false }
            req.setValue("resolution=ignore-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["user_id": uid, "recipe_id": recipeId])
            guard let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
            return true
        } else {
            let path = "rest/v1/recipe_saves?user_id=eq.\(uid)&recipe_id=eq.\(recipeId)"
            guard let req = request(path: path, method: "DELETE") else { return false }
            guard let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
            return true
        }
    }

    /// Pull the signed-in user's most-recent likes + saves so the client can hydrate the local
    /// sets at launch. Nil on failure so the caller keeps whatever's on device.
    func fetchMyLikesAndSaves(limit: Int = 500) async -> (likes: Set<String>, saves: Set<String>)? {
        guard hasSession else { return nil }
        struct Row: Decodable { let recipe_id: String }
        async let likesData: [Row]? = fetchRecent(table: "recipe_likes", limit: limit)
        async let savesData: [Row]? = fetchRecent(table: "recipe_saves", limit: limit)
        let (l, s) = await (likesData, savesData)
        guard let l, let s else { return nil }
        return (Set(l.map(\.recipe_id)), Set(s.map(\.recipe_id)))
    }

    private func fetchRecent<T: Decodable>(table: String, limit: Int) async -> [T]? {
        guard let uid = currentUserId(),
              let req = request(path: "rest/v1/\(table)?select=recipe_id&user_id=eq.\(uid)&order=created_at.desc&limit=\(limit)", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return try? JSONDecoder().decode([T].self, from: data)
    }

    /// Permanently delete the caller's account: wipes every `cravecircle.*` row they own and
    /// deletes the `auth.users` row so sign-in no longer works. Backed by the `delete_me()`
    /// SECURITY DEFINER RPC. Returns true on 2xx.
    func deleteMyAccount() async -> Bool {
        guard hasSession, let req = request(path: "rest/v1/rpc/delete_me", method: "POST") else { return false }
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

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
        // Comments are a public thread — a signed-out viewer should see them, same as Instagram.
        // The anon key in `request()` is enough: the SELECT policy allows the anon role.
        guard let enc = recipeId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
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

    // MARK: - Meal Plan (owner-only read/write)

    func insertPlannedMeal(_ meal: PlannedMeal) async -> Bool {
        guard hasSession, let uid = currentUserId(), var req = request(path: "rest/v1/meal_plan") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let row: [String: Any] = [
            "id": meal.id.uuidString.lowercased(),
            "user_id": uid,
            "recipe_id": meal.recipeId,
            "when_ts": iso.string(from: meal.when),
            "slot": meal.slot.rawValue
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: row)
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    func deletePlannedMeal(id: UUID) async -> Bool {
        guard hasSession,
              let enc = id.uuidString.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let req = request(path: "rest/v1/meal_plan?id=eq.\(enc)", method: "DELETE") else { return false }
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    /// Pull every planned meal for the signed-in user. Returns nil on failure so the caller
    /// keeps whatever is on-device.
    func fetchMyMealPlan() async -> [PlannedMeal]? {
        guard hasSession, let uid = currentUserId(),
              let req = request(path: "rest/v1/meal_plan?select=id,recipe_id,when_ts,slot,created_at&user_id=eq.\(uid)&order=when_ts.asc", method: "GET") else { return nil }
        struct Row: Decodable {
            let id: UUID
            let recipe_id: String
            let when_ts: Date
            let slot: String
            let created_at: Date?
        }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        let rows = (try? Self.decoder().decode([Row].self, from: data)) ?? []
        return rows.compactMap { r in
            guard let slot = MealSlot(rawValue: r.slot) else { return nil }
            return PlannedMeal(id: r.id, recipeId: r.recipe_id, when: r.when_ts, slot: slot,
                               reminderIdentifier: nil, createdAt: r.created_at ?? Date())
        }
    }

    /// Bulk-delete every row the caller owns in one of the simple user-scoped tables. Returns
    /// true on 2xx. Used by the "Delete my likes / saves / comments" controls so a user can
    /// erase their footprint without closing the account.
    func deleteAllMine(from table: String) async -> Bool {
        guard hasSession, let uid = currentUserId() else { return false }
        // Column name differs per table: comments uses `author_id`, everyone else `user_id`.
        let col = (table == "comments") ? "author_id" : "user_id"
        guard let req = request(path: "rest/v1/\(table)?\(col)=eq.\(uid)", method: "DELETE") else { return false }
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    /// Delete a single comment by id. RLS enforces who can call this: author of the comment,
    /// owner of the recipe the comment lives on, or an admin. Anyone else gets 0 rows affected
    /// (which Postgres still returns as a 2xx; the UI already re-fetches so a no-op is harmless).
    func deleteComment(id: UUID) async -> Bool {
        guard hasSession,
              let enc = id.uuidString.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let req = request(path: "rest/v1/comments?id=eq.\(enc)", method: "DELETE") else { return false }
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    /// Admin-only nuclear remove-a-user. Fires the `admin_delete_user` RPC which checks the role
    /// server-side before deleting the auth.users row (everything else cascades off profiles.id).
    func adminDeleteUser(id: UUID) async -> Bool {
        guard hasSession, var req = request(path: "rest/v1/rpc/admin_delete_user", method: "POST") else { return false }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_user_id": id.uuidString.lowercased()])
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
