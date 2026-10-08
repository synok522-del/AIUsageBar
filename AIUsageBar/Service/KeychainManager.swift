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

enum KeychainReadResult {
    case found(String)
    case notFound
    case failure(OSStatus)
}

protocol KeychainStorageBackend {
    func read(_ key: String, useDataProtectionKeychain: Bool) -> KeychainReadResult
    func saveProtected(_ value: String, forKey key: String) -> Bool
    func delete(_ key: String, useDataProtectionKeychain: Bool)
}

/// A fault-injectable storage backend used by credential migration tests.
final class InMemoryKeychainStorageBackend: KeychainStorageBackend {
    private var protectedItems: [String: String]
    private var legacyItems: [String: String]
    private var protectedSaveOutcomes: [Bool] = []
    private(set) var protectedSaveAttemptCount = 0

    init(
        protectedItems: [String: String] = [:],
        legacyItems: [String: String] = [:]
    ) {
        self.protectedItems = protectedItems
        self.legacyItems = legacyItems
    }

    func queueProtectedSaveOutcomes(_ outcomes: [Bool]) {
        protectedSaveOutcomes.append(contentsOf: outcomes)
    }

    var queuedProtectedSaveOutcomeCount: Int {
        protectedSaveOutcomes.count
    }

    func hasProtectedItem(forKey key: String) -> Bool {
        protectedItems[key] != nil
    }

    func hasLegacyItem(forKey key: String) -> Bool {
        legacyItems[key] != nil
    }

    func read(_ key: String, useDataProtectionKeychain: Bool) -> KeychainReadResult {
        let items = useDataProtectionKeychain ? protectedItems : legacyItems
        guard let value = items[key] else { return .notFound }
        return .found(value)
    }

    func saveProtected(_ value: String, forKey key: String) -> Bool {
        protectedSaveAttemptCount += 1
        if !protectedSaveOutcomes.isEmpty, !protectedSaveOutcomes.removeFirst() {
            return false
        }
        protectedItems[key] = value
        return true
    }

    func delete(_ key: String, useDataProtectionKeychain: Bool) {
        if useDataProtectionKeychain {
            protectedItems[key] = nil
        } else {
            legacyItems[key] = nil
        }
    }
}

final class KeychainManager {

    static let shared = KeychainManager()
    private static let service = AppBuildIdentity.keychainService
    static let credentialAccessibility: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    static var isTestProcess: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

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

    private let backend: any KeychainStorageBackend

    init(inMemory: Bool = false, backend: (any KeychainStorageBackend)? = nil) {
        if let backend {
            self.backend = backend
        } else if inMemory {
            self.backend = InMemoryKeychainStorageBackend()
        } else {
            self.backend = SystemKeychainStorageBackend()
        }
    }

    // MARK: Save

    @discardableResult
    func save(_ value: String, forKey key: String) -> Bool {
        guard backend.saveProtected(value, forKey: key) else { return false }
        backend.delete(key, useDataProtectionKeychain: false)
        return true
    }

    // MARK: Read

    func read(_ key: String) -> String? {
        switch backend.read(key, useDataProtectionKeychain: true) {
        case .found(let value):
            return value
        case .failure(let status) where status != errSecItemNotFound:
            return nil
        case .notFound, .failure:
            break
        }

        // Existing releases stored items in the traditional macOS keychain.
        // Return a legacy value only after its Data Protection copy is saved.
        guard case .found(let legacyValue) = backend.read(
            key,
            useDataProtectionKeychain: false
        ), save(legacyValue, forKey: key) else {
            return nil
        }
        return legacyValue
    }

    // MARK: Delete

    func delete(_ key: String) {
        backend.delete(key, useDataProtectionKeychain: true)
        backend.delete(key, useDataProtectionKeychain: false)
    }
}

private struct SystemKeychainStorageBackend: KeychainStorageBackend {
    func read(_ key: String, useDataProtectionKeychain: Bool) -> KeychainReadResult {
        var query = KeychainManager.queryAttributes(
            forKey: key,
            useDataProtectionKeychain: useDataProtectionKeychain
        )
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return status == errSecItemNotFound ? .notFound : .failure(status)
        }
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return .failure(errSecDecode)
        }
        return .found(value)
    }

    func saveProtected(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query = KeychainManager.queryAttributes(forKey: key)
        let attributes = KeychainManager.credentialItemAttributes(for: data)
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            var newItem = query
            newItem.merge(attributes) { _, newValue in newValue }
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                logger.error("Keychain add failed: \(addStatus)")
                return false
            }
            return true
        }

        guard status == errSecSuccess else {
            logger.error("Keychain update failed: \(status)")
            return false
        }
        return true
    }

    func delete(_ key: String, useDataProtectionKeychain: Bool) {
        let query = KeychainManager.queryAttributes(
            forKey: key,
            useDataProtectionKeychain: useDataProtectionKeychain
        )
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Keychain delete failed: \(status)")
        }
    }
}
