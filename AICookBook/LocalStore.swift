//
//  LocalStore.swift
//  CraveCircle (AICookBook)
//
//  Tiny on-disk persistence (JSON in Application Support) so the user's library survives app
//  restarts with no backend: imported/created recipes, edits, collections, and the grocery list.
//  When real accounts land (Supabase), this stays as the offline cache.
//

import Foundation

enum LocalStore {
    private static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("CraveCircle", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func url(_ name: String) -> URL { folder.appendingPathComponent(name) }

    private static let ioQueue = DispatchQueue(label: "com.cravecircle.localstore.io", qos: .utility)

    static func save<T: Encodable>(_ value: T, to name: String) {
        // Encode + write off the main thread so @Published didSet persistence NEVER blocks the UI.
        // AppEnvironment is @MainActor, so without this every state change stalls the main thread on
        // a synchronous disk write — the cause of the freeze. `value` is a value type (arrays/structs),
        // so capturing it snapshots via copy-on-write; the serial queue keeps writes ordered.
        let target = url(name)
        ioQueue.async {
            do {
                let data = try JSONEncoder().encode(value)
                try data.write(to: target, options: .atomic)
            } catch {
                #if DEBUG
                print("[LocalStore] save \(name) failed: \(error)")
                #endif
            }
        }
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }

    /// Alias of `delete(_:)` — easier to read at call sites that are talking about an on-disk
    /// cache rather than a user-facing object.
    static func remove(_ name: String) { delete(name) }

    /// Move a scoped file to a new scoped name, but only if the destination doesn't already
    /// exist. Used by the guest → signed-in migration: if the user has nothing of their own
    /// yet, inherit the guest file; if they do, leave their file alone and the caller is
    /// responsible for whatever merge policy fits the data type.
    static func moveIfTargetMissing(from: String, to: String) {
        let fm = FileManager.default
        let src = url(from)
        let dst = url(to)
        guard fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dst.path) else { return }
        try? fm.moveItem(at: src, to: dst)
    }

    /// Write raw bytes (e.g. a JPEG thumbnail) and return the file URL to reference it by.
    @discardableResult
    static func saveData(_ data: Data, to name: String) -> URL? {
        let target = url(name)
        do {
            try data.write(to: target, options: .atomic)
            return target
        } catch {
            return nil
        }
    }
}

/// On-device personal files are named by the signed-in user id. Two accounts never share a path.
enum AccountScope {
    static let ownerKey = "library_owner_id"
    static let personalFiles = [
        "recipes.json", "avatar.json", "grocery.json", "followed_creators.json",
        "owned_collections.json", "shared_collections.json", "studio_drafts.json",
        "unsynced_recipes.json", "shared_log.json", "pending_interactions.json",
        "interaction_history.json", "preferred_cuisines.json",
        "comments.json", "notifications.json", "circle_friends.json",
        "friend_requests_in.json", "friend_requests_out.json"
    ]
    static let personalDefaultsKeys = ["saved_recipe_ids", "liked_recipe_ids", "deleted_recipe_ids"]

    static func fileName(userId: String, file: String) -> String {
        "\(sanitize(userId))-\(file)"
    }

    static func defaultsKey(userId: String, key: String) -> String {
        "\(sanitize(userId))-\(key)"
    }

    /// Unscoped files from before this split belong to the first real signed-in user.
    /// A later account, a guest, and the local fallback do not inherit them.
    static func mayReadLegacy(userId: String, recordedOwner: String?) -> Bool {
        if userId.hasPrefix("guest_") || userId.hasPrefix("local-") { return false }
        return recordedOwner == nil || recordedOwner == userId
    }

    private static func sanitize(_ id: String) -> String {
        let ok = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(id.unicodeScalars.map { ok.contains($0) ? Character($0) : "_" })
    }
}
