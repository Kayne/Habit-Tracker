//
//  KeychainStore.swift
//  HabitTrackerApp
//
//  Minimalny wrapper na iOS Keychain do trzymania JWT.
//  Trzy operacje: save / load / delete. Wystarczające pod token sesji.
//

import Foundation
import Security

struct KeychainStore {

    /// Service + account identyfikują konkretną pozycję w Keychainie.
    /// Używamy bundle identifiera jako service dla pewności że nie zderzymy
    /// się z żadną inną apką na symulatorze.
    private static let service: String = Bundle.main.bundleIdentifier ?? "kayne.HabitTrackerApp"
    private static let account: String = "access_token"

    // MARK: - Public API

    static func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        // Najpierw usuwamy ewentualny poprzedni wpis — Keychain nie nadpisuje "z automatu".
        deleteToken()

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String:   data,
            // Token jest potrzebny tylko gdy urządzenie jest odblokowane.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
