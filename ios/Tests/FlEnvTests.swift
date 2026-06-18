import CryptoKit
import XCTest

@testable import fl_env

// MARK: - AesGcmDecryptor Tests

final class AesGcmDecryptorTests: XCTestCase {

    private let key = Array(repeating: UInt8(0xAB), count: 32)
    private let nonce = Array(0..<12).map { UInt8($0) }

    private func encrypt(plaintext: [UInt8]) throws -> [UInt8] {
        let symmetricKey = SymmetricKey(data: Data(key))
        let nonceData = try AES.GCM.Nonce(data: Data(nonce))
        let sealed = try AES.GCM.seal(Data(plaintext), using: symmetricKey, nonce: nonceData)
        // sealed.combined = nonce || ciphertext || tag
        // we return ciphertext || tag (drop leading 12 nonce bytes)
        return Array(sealed.combined!.dropFirst(12))
    }

    func testDecryptRoundTrip() throws {
        let plaintext = Array("hello fl_env".utf8)
        let cipherWithTag = try encrypt(plaintext: plaintext)
        let result = try AesGcmDecryptor.decrypt(key: key, nonce: nonce, cipherWithTag: cipherWithTag)
        XCTAssertEqual(result, plaintext)
    }

    func testDecryptFailsWithWrongKey() {
        let cipherWithTag = try! encrypt(plaintext: Array("secret".utf8))
        let wrongKey = Array(repeating: UInt8(0xCD), count: 32)
        XCTAssertThrowsError(try AesGcmDecryptor.decrypt(key: wrongKey, nonce: nonce, cipherWithTag: cipherWithTag))
    }

    func testDecryptFailsWithTamperedCiphertext() {
        var cipherWithTag = try! encrypt(plaintext: Array("secret".utf8))
        cipherWithTag[0] ^= 0xFF
        XCTAssertThrowsError(try AesGcmDecryptor.decrypt(key: key, nonce: nonce, cipherWithTag: cipherWithTag))
    }

    func testDecryptEmptyPlaintext() throws {
        let plaintext = [UInt8]()
        let cipherWithTag = try encrypt(plaintext: plaintext)
        let result = try AesGcmDecryptor.decrypt(key: key, nonce: nonce, cipherWithTag: cipherWithTag)
        XCTAssertEqual(result, plaintext)
    }

    func testDecryptUnicode() throws {
        let plaintext = Array("こんにちは世界".utf8)
        let cipherWithTag = try encrypt(plaintext: plaintext)
        let result = try AesGcmDecryptor.decrypt(key: key, nonce: nonce, cipherWithTag: cipherWithTag)
        XCTAssertEqual(result, plaintext)
    }
}

// MARK: - RegistryReader Tests

final class RegistryReaderTests: XCTestCase {

    private let key = Array(repeating: UInt8(0xAB), count: 32)

    private func encrypt(nonce: [UInt8], plaintext: [UInt8]) -> [UInt8] {
        let symmetricKey = SymmetricKey(data: Data(key))
        let nonceData = try! AES.GCM.Nonce(data: Data(nonce))
        let sealed = try! AES.GCM.seal(Data(plaintext), using: symmetricKey, nonce: nonceData)
        return Array(sealed.combined!.dropFirst(12)) // ciphertext || tag
    }

    private func buildRegistry(entries: [(String, String)]) -> Data {
        var data = Data()
        data.append(contentsOf: [0x46, 0x4C, 0x45, 0x4E]) // magic
        data.appendUInt32BE(1) // version
        data.appendUInt32BE(UInt32(entries.count)) // tier1Count
        data.appendUInt32BE(0) // tier2Count

        for (k, v) in entries {
            let keyBytes = Array(k.utf8)
            let nonce = Array(0..<12).map { UInt8($0) }
            let cipherWithTag = encrypt(nonce: nonce, plaintext: Array(v.utf8))
            data.appendUInt32BE(UInt32(keyBytes.count))
            data.append(contentsOf: keyBytes)
            data.append(contentsOf: nonce)
            data.appendUInt32BE(UInt32(cipherWithTag.count))
            data.append(contentsOf: cipherWithTag)
        }
        return data
    }

    func testReadSingleEntry() throws {
        let data = buildRegistry(entries: [("API_URL", "https://api.example.com")])
        let result = try RegistryReader.readAll(key: key, from: data)
        XCTAssertEqual(result["API_URL"], "https://api.example.com")
    }

    func testReadMultipleEntries() throws {
        let entries: [(String, String)] = [
            ("BASE_URL", "https://api.example.com"),
            ("TIMEOUT", "30"),
            ("DEBUG", "false"),
        ]
        let result = try RegistryReader.readAll(key: key, from: buildRegistry(entries: entries))
        XCTAssertEqual(result["BASE_URL"], "https://api.example.com")
        XCTAssertEqual(result["TIMEOUT"], "30")
        XCTAssertEqual(result["DEBUG"], "false")
    }

    func testReadEmptyRegistry() throws {
        let result = try RegistryReader.readAll(key: key, from: buildRegistry(entries: []))
        XCTAssertTrue(result.isEmpty)
    }

    func testReadEmptyValue() throws {
        let result = try RegistryReader.readAll(key: key, from: buildRegistry(entries: [("EMPTY", "")]))
        XCTAssertEqual(result["EMPTY"], "")
    }

    func testInvalidMagicThrows() {
        var data = buildRegistry(entries: [("K", "V")])
        data[0] = 0x00
        XCTAssertThrowsError(try RegistryReader.readAll(key: key, from: data)) { error in
            XCTAssertEqual(error as? RegistryReaderError, RegistryReaderError.invalidMagic)
        }
    }

    func testWrongKeyThrows() {
        let data = buildRegistry(entries: [("K", "V")])
        let wrongKey = Array(repeating: UInt8(0xCD), count: 32)
        XCTAssertThrowsError(try RegistryReader.readAll(key: wrongKey, from: data))
    }
}

// MARK: - Data helper

private extension Data {
    mutating func appendUInt32BE(_ value: UInt32) {
        self.append(UInt8((value >> 24) & 0xFF))
        self.append(UInt8((value >> 16) & 0xFF))
        self.append(UInt8((value >> 8) & 0xFF))
        self.append(UInt8(value & 0xFF))
    }
}
