import CryptoKit
import Foundation
import Security

enum CryptoError: Error, Equatable {
    case keychain(OSStatus)
    case invalidKey
    case sealFailed
}

/// AES-GCM at rest with a 256-bit key kept in the login keychain.
///
/// Fails closed: if the key cannot be loaded or persisted, or sealing fails, callers get an
/// error and must not write. Plaintext never reaches the database by accident.
enum Crypto {
    private static let service = Bundle.main.bundleIdentifier ?? "com.amenophis.pastely"
    private static let account = "history-key"

    /// Where the key comes from. Tests swap this for an ephemeral key so they never touch the real keychain.
    nonisolated(unsafe) static var keyProvider: () throws -> SymmetricKey = loadOrCreateKey
    nonisolated(unsafe) private static var cached: SymmetricKey?

    static func seal(_ data: Data) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: try key())
        guard let combined = sealed.combined else { throw CryptoError.sealFailed }
        return combined
    }

    static func open(_ data: Data) -> Data? {
        guard let key = try? key(), let box = try? AES.GCM.SealedBox(combined: data) else { return nil }
        return try? AES.GCM.open(box, using: key)
    }

    /// Forget the cached key so the next call goes back to `keyProvider`.
    static func resetCache() { cached = nil }

    private static func key() throws -> SymmetricKey {
        if let cached { return cached }
        let key = try keyProvider()
        guard key.bitCount == 256 else { throw CryptoError.invalidKey }
        cached = key
        return key
    }

    // MARK: Keychain

    static func loadOrCreateKey() throws -> SymmetricKey {
        switch readKeychain() {
        case .success(let data):
            guard data.count == 32 else { throw CryptoError.invalidKey }
            return SymmetricKey(data: data)
        case .failure(let status) where status == errSecItemNotFound:
            let fresh = SymmetricKey(size: .bits256)
            let status = writeKeychain(fresh.withUnsafeBytes { Data($0) })
            if status == errSecDuplicateItem {
                // Lost a race with another instance; use what it stored.
                return try loadOrCreateKey()
            }
            guard status == errSecSuccess else { throw CryptoError.keychain(status) }
            return fresh
        case .failure(let status):
            // Access denied, keychain locked, etc. Never mint a replacement key over an existing one.
            throw CryptoError.keychain(status)
        }
    }

    private static func readKeychain() -> Result<Data, OSStatus> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess else { return .failure(status) }
        guard let data = out as? Data else { return .failure(errSecDecode) }
        return .success(data)
    }

    private static func writeKeychain(_ data: Data) -> OSStatus {
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        return SecItemAdd(attrs as CFDictionary, nil)
    }
}

extension OSStatus: @retroactive Error {}
