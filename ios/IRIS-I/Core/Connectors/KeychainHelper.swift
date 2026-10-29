//
//  KeychainHelper.swift
//  IRIS-I
//
//  Secure enclave and Keychain wrapper for storing sensitive authentication tokens,
//  refresh tokens, and device credentials with strict device-only accessibility.
//

import Foundation
#if canImport(Security)
import Security
#endif

public final class KeychainHelper: @unchecked Sendable {
    public static let shared = KeychainHelper()
    private let service: String
    private let lock = NSLock()
    private var inMemoryStore: [String: Data] = [:]

    public init(service: String = "com.iris.assistant.keychain") {
        self.service = service
    }

    public func set(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return set(data, forKey: key)
    }

    public func get(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func set(_ data: Data, forKey key: String) -> Bool {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
        #else
        lock.lock()
        defer { lock.unlock() }
        inMemoryStore[key] = data
        return true
        #endif
    }

    public func getData(forKey key: String) -> Data? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
        #else
        lock.lock()
        defer { lock.unlock() }
        return inMemoryStore[key]
        #endif
    }

    public func remove(forKey key: String) -> Bool {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
        #else
        lock.lock()
        defer { lock.unlock() }
        inMemoryStore.removeValue(forKey: key)
        return true
        #endif
    }

    public func clearAll() {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
        #else
        lock.lock()
        defer { lock.unlock() }
        inMemoryStore.removeAll()
        #endif
    }
}
