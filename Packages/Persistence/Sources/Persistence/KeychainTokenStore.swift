import Core
import Foundation
import Security

public final class KeychainTokenStore: SecureTokenStore {
    private let service = "com.deploybar.token"
    private let account = "vercel-access-token"

    public init() {}

    public func saveToken(_ token: String) throws {
        let tokenData = Data(token.utf8)
        var query = baseQuery

        let attributes: [String: Any] = [
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw DeployBarError.persistence("Unable to update token in Keychain (\(updateStatus)).")
            }
            return
        }

        query.merge(attributes, uniquingKeysWith: { _, new in new })
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw DeployBarError.persistence("Unable to save token in Keychain (\(addStatus)).")
        }
    }

    public func readToken() throws -> String? {
        if let token = try readToken(dataProtection: true) {
            return token
        }

        // Migration path: pre-existing installs stored the token in the legacy
        // file-based keychain (no kSecUseDataProtectionKeychain). If found,
        // migrate it into the data-protection keychain and remove the legacy
        // copy. Never fail auth over a migration hiccup — fall back to the
        // legacy value so the next successful save migrates it.
        guard let legacyToken = try readToken(dataProtection: false) else {
            return nil
        }

        do {
            try saveToken(legacyToken)
            let legacyDeleteStatus = SecItemDelete(query(dataProtection: false) as CFDictionary)
            guard legacyDeleteStatus == errSecSuccess || legacyDeleteStatus == errSecItemNotFound else {
                return legacyToken
            }
        } catch {
            return legacyToken
        }

        return legacyToken
    }

    public func clearToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DeployBarError.persistence("Unable to clear token from Keychain (\(status)).")
        }

        let legacyStatus = SecItemDelete(query(dataProtection: false) as CFDictionary)
        guard legacyStatus == errSecSuccess || legacyStatus == errSecItemNotFound else {
            throw DeployBarError.persistence("Unable to clear legacy token from Keychain (\(legacyStatus)).")
        }
    }

    private func readToken(dataProtection: Bool) throws -> String? {
        var lookupQuery = query(dataProtection: dataProtection)
        lookupQuery[kSecReturnData as String] = kCFBooleanTrue
        lookupQuery[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookupQuery as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw DeployBarError.persistence("Unable to read token from Keychain (\(status)).")
        }

        guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
            throw DeployBarError.persistence("Stored token is corrupted.")
        }

        return token
    }

    private var baseQuery: [String: Any] {
        query(dataProtection: true)
    }

    private func query(dataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }

        return query
    }
}
