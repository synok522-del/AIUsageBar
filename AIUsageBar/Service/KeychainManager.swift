//
//  KeychainManager.swift
//  AIUsageBar
//

import Foundation
import Security

final class KeychainManager {

    static let shared = KeychainManager()

    private init() {}

    private let service = "com.synok522.AIUsageBar"

    // MARK: Save

    func save(_ value: String, forKey key: String) {

        guard let data = value.data(using: .utf8) else {
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        if status == errSecItemNotFound {

            var newItem = query
            newItem[kSecValueData as String] = data

            let addStatus = SecItemAdd(
                newItem as CFDictionary,
                nil
            )

            if addStatus != errSecSuccess {
                print("❌ Keychain add failed:", addStatus)
            }

        } else if status != errSecSuccess {

            print("❌ Keychain update failed:", status)
        }
    }

    // MARK: Read

    func read(_ key: String) -> String? {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?

        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        guard
            status == errSecSuccess,
            let data = result as? Data
        else {
            return nil
        }

        return String(
            data: data,
            encoding: .utf8
        )
    }

    // MARK: Delete

    func delete(_ key: String) {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(
            query as CFDictionary
        )

        if status != errSecSuccess &&
            status != errSecItemNotFound {

            print("❌ Keychain delete failed:", status)
        }
    }
}
