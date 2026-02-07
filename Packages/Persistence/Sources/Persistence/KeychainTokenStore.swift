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
        var query = baseQuery
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

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

    public func clearToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DeployBarError.persistence("Unable to clear token from Keychain (\(status)).")
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
