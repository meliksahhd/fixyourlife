import Foundation
import Security

/// Unsplash anahtarı yalnızca burada durur (repo herkese açık). AfterFirstUnlock: arka plan yenilemesi kilitliyken de okur.
enum Keychain {
    private static func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "fixyourlife", kSecAttrAccount as String: key]
    }

    static func get(_ key: String) -> String? {
        var q = query(key); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    /// nil siler.
    static func set(_ key: String, _ value: String?) {
        SecItemDelete(query(key) as CFDictionary)
        guard let v = value else { return }
        var q = query(key)
        q[kSecValueData as String] = Data(v.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }
}
