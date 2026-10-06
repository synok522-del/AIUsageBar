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
    private static let service = "com.synok522.AIUsageBar"
    static let credentialAccessibility: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    static func queryAttributes(
        forKey key: String,
        useDataProtectionKeychain: Bool = true
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if useDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    static func credentialItemAttributes(for data: Data) -> [String: Any] {
        [
            kSecValueData as String: data,
            kSecAttrAccessible as String: credentialAccessibility
        ]
    }

    private let inMemory: Bool
    private var memory: [String: String] = [:]
    init(inMemory: Bool = false) { self.inMemory = inMemory }
    static var isTestProcess: Bool {
        NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: Save

    func save(_ value: String, forKey key: String) {

        if inMemory { memory[key] = value; return }

        guard let data = value.data(using: .utf8) else {
            return
        }

        let query = Self.queryAttributes(forKey: key)

        let attributes = Self.credentialItemAttributes(for: data)

        let status = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        if status == errSecItemNotFound {

            var newItem = query
            newItem.merge(attributes) { _, newValue in newValue }

            let addStatus = SecItemAdd(
                newItem as CFDictionary,
                nil
            )

            if addStatus != errSecSuccess {
                logger.error("Keychain add failed: \(addStatus)")
            } else {
                deleteLegacyKeychainItem(key)
            }

        } else if status != errSecSuccess {

            logger.error("Keychain update failed: \(status)")
        } else {
            deleteLegacyKeychainItem(key)
        }
    }

    // MARK: Read

    func read(_ key: String) -> String? {
        if inMemory { return memory[key] }

        let protectedRead = readValue(key, useDataProtectionKeychain: true)
        if protectedRead.status == errSecSuccess {
            return protectedRead.value
        }
        guard protectedRead.status == errSecItemNotFound else {
            return nil
        }

        // Existing releases stored items in the traditional macOS keychain.
        // Move a found item into the Data Protection Keychain before returning
        // it; save() removes the legacy copy only after the protected write.
        let legacyRead = readValue(key, useDataProtectionKeychain: false)
        guard legacyRead.status == errSecSuccess,
              let legacyValue = legacyRead.value else {
            return nil
        }
        save(legacyValue, forKey: key)
        return legacyValue
    }

    // MARK: Delete

    func delete(_ key: String) {
        if inMemory { memory[key] = nil; return }

        deleteItem(key, useDataProtectionKeychain: true)
        deleteLegacyKeychainItem(key)
    }

    private func readValue(
        _ key: String,
        useDataProtectionKeychain: Bool
    ) -> (status: OSStatus, value: String?) {
        var query = Self.queryAttributes(
            forKey: key,
            useDataProtectionKeychain: useDataProtectionKeychain
        )
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return (status, nil)
        }
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return (errSecDecode, nil)
        }
        return (errSecSuccess, value)
    }

    private func deleteLegacyKeychainItem(_ key: String) {
        deleteItem(key, useDataProtectionKeychain: false)
    }

    private func deleteItem(_ key: String, useDataProtectionKeychain: Bool) {
        let query = Self.queryAttributes(
            forKey: key,
            useDataProtectionKeychain: useDataProtectionKeychain
        )
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Keychain delete failed: \(status)")
        }
    }
}
