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

    private static func url(_ name: String) -> URL { folder.appendingPathComponent(name) }

    static func save<T: Encodable>(_ value: T, to name: String) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url(name), options: .atomic)
        } catch {
            #if DEBUG
            print("[LocalStore] save \(name) failed: \(error)")
            #endif
        }
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
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
