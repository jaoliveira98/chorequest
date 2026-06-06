import Foundation
import Security

/// Minimal Keychain wrapper for the auth session (access/refresh tokens). Used
/// instead of UserDefaults because these are credentials.
enum Keychain {
    private static let service = "com.jaoliveira98.chorequest.supabase"

    private static func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    @discardableResult
    static func set(_ data: Data, for key: String) -> Bool {
        SecItemDelete(baseQuery(key) as CFDictionary)
        var attributes = baseQuery(key)
        attributes[kSecValueData as String] = data
        // ThisDeviceOnly: keep credentials off encrypted backups / device migration
        // (re-auth on a new device is harmless for anonymous sign-in).
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ key: String) -> Data? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(_ key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }
}
