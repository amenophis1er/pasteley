import CryptoKit
import Foundation
import Security

/// AES-GCM at rest with a 256-bit key kept in the login keychain.
enum Crypto {
    private static let service = "com.amenophis.pasteley"
    private static let account = "history-key"

    nonisolated(unsafe) private static var cached: SymmetricKey?

    static func seal(_ data: Data) -> Data {
        guard let sealed = try? AES.GCM.seal(data, using: key()), let combined = sealed.combined else { return data }
        return combined
    }

    static func open(_ data: Data) -> Data? {
        guard let box = try? AES.GCM.SealedBox(combined: data) else { return nil }
        return try? AES.GCM.open(box, using: key())
    }

    private static func key() -> SymmetricKey {
        if let cached { return cached }
        if let stored = readKeychain() {
            cached = SymmetricKey(data: stored)
        } else {
            let fresh = SymmetricKey(size: .bits256)
            writeKeychain(fresh.withUnsafeBytes { Data($0) })
            cached = fresh
        }
        return cached!
    }

    private static func readKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    private static func writeKeychain(_ data: Data) {
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }
}
