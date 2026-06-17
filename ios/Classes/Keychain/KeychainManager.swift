import Foundation

enum KeychainError: Error {
    case keyNotFound
}

enum KeychainManager {

    /// Returns the AES-256 key written by `fl_env build` as a binary resource.
    ///
    /// The key is stored as `FlEnvKey.bin` (raw 32 bytes) in the consumer's app
    /// bundle (default: `ios/Runner/`). Using a binary resource instead of a
    /// generated Swift source file lets the key live in the consumer's project
    /// rather than in the plugin's own CocoaPods framework, which is the only
    /// approach that works for a published package.
    ///
    /// Phase 2 will provision this key into the iOS Keychain (Secure
    /// Enclave-backed) on first access, eliminating it from the app bundle.
    static func getKey() throws -> [UInt8] {
        guard let url = Bundle.main.url(forResource: "FlEnvKey", withExtension: "bin"),
              let data = try? Data(contentsOf: url) else {
            throw KeychainError.keyNotFound
        }
        return [UInt8](data)
    }
}
