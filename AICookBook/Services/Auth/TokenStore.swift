//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: TokenStore.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Secure Keychain wrapper for storing sensitive authentication credentials.
//
// 2. ARCHITECTURAL ROLE:
//    Uses iOS Security framework (SecItemAdd, SecItemCopyMatching) to encrypt user tokens on hardware.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "TokenStore wraps the iOS Keychain API. We use it instead of UserDefaults for access and refresh tokens to ensure credentials remain encrypted and protected even if the device filesystem is inspected."
//
// ==============================================================================
//

import Foundation
import Security

final class TokenStore {
    private enum Keys {
        static let service = "com.aicookbook.session"
        static let accessToken = "access-token"
        static let refreshToken = "refresh-token"
    }

    func saveSession(accessToken: String, refreshToken: String) {
        save(accessToken, for: Keys.accessToken)
        save(refreshToken, for: Keys.refreshToken)
    }

    func readAccessToken() -> String? { read(for: Keys.accessToken) }
    func readRefreshToken() -> String? { read(for: Keys.refreshToken) }

    func clearSession() {
        delete(for: Keys.accessToken)
        delete(for: Keys.refreshToken)
    }

    private func save(_ value: String, for account: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(for: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
