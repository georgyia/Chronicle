import Foundation
import Security

/// Stores AI provider secrets in the macOS Keychain (never in config or the DB).
public struct KeychainStore: Sendable {
    private let service: String

    /// Creates a Keychain store scoped to a service identifier.
    public init(service: String = "dev.chronicle.ai") {
        self.service = service
    }

    /// Reads a secret for an account, or `nil` if absent.
    public func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(bytes: data, encoding: .utf8)
    }

    /// Stores or replaces a secret for an account.
    @discardableResult
    public func write(_ secret: String, account: String) -> Bool {
        let data = Data(secret.utf8)
        var query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// Deletes a stored secret.
    @discardableResult
    public func delete(account: String) -> Bool {
        SecItemDelete(baseQuery(account: account) as CFDictionary) == errSecSuccess
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
