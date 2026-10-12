//
//  KeychainManager.swift
//  AIUsageBar
//

import Foundation
import Security
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "AIUsageBar",
    category: "Keychain"
)

final class KeychainManager {

    static let shared = KeychainManager()

    private let inMemory: Bool
    private var memory: [String: String] = [:]
    init(inMemory: Bool = false) { self.inMemory = inMemory }
    static var isTestProcess: Bool {
        NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private let service = "com.synok522.AIUsageBar"

    // MARK: Save

    func save(_ value: String, forKey key: String) {

        if inMemory { memory[key] = value; return }

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
                logger.error("Keychain add failed: \(addStatus)")
            }

        } else if status != errSecSuccess {

            logger.error("Keychain update failed: \(status)")
        }
    }

    // MARK: Read

    func read(_ key: String) -> String? {
        if inMemory { return memory[key] }

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
        if inMemory { memory[key] = nil; return }

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

            logger.error("Keychain delete failed: \(status)")
        }
    }
}
