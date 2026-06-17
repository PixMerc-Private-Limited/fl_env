import CryptoKit
import Foundation

enum AesGcmDecryptorError: Error {
    case decryptionFailed(String)
}

enum AesGcmDecryptor {

    /// Decrypts [cipherWithTag] using [key] and [nonce].
    ///
    /// The registry stores nonce (12 bytes) and ciphertext+tag separately.
    /// CryptoKit's `AES.GCM.SealedBox(combined:)` expects `nonce || ciphertext || tag`,
    /// so we prepend the nonce to cipherWithTag before calling CryptoKit.
    static func decrypt(
        key: [UInt8],
        nonce nonceBytes: [UInt8],
        cipherWithTag: [UInt8]
    ) throws -> [UInt8] {
        let symmetricKey = SymmetricKey(data: Data(key))

        // Build combined: nonce (12 bytes) || ciphertext || tag (16 bytes)
        var combined = Data(nonceBytes)
        combined.append(contentsOf: cipherWithTag)

        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        let plaintext = try AES.GCM.open(sealedBox, using: symmetricKey)
        return Array(plaintext)
    }
}
