import Foundation

enum RegistryReaderError: Error {
    case invalidMagic
    case unsupportedVersion(UInt32)
    case decryptionFailed(String)
    case malformedData
}

enum RegistryReader {

    /// Reads and decrypts the fl_env binary registry.
    ///
    /// Binary format (all integers big-endian):
    ///   Bytes  Field
    ///   0-3    Magic: 0x464C454E ("FLEN")
    ///   4-7    Version: UInt32 = 1
    ///   8-11   Tier-1 entry count: UInt32
    ///   12-15  Tier-2 entry count: UInt32 (Phase 1: always 0)
    ///
    ///   Per entry:
    ///     key-length  UInt32
    ///     key         UTF-8 bytes
    ///     nonce       12 bytes
    ///     cipher-len  UInt32  (ciphertext + 16-byte GCM tag)
    ///     cipher+tag  bytes
    static func readAll(key: [UInt8], from data: Data) throws -> [String: String] {
        var offset = data.startIndex

        func readUInt32() throws -> UInt32 {
            guard offset + 4 <= data.endIndex else { throw RegistryReaderError.malformedData }
            let value = data[offset..<(offset + 4)].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            offset += 4
            return value
        }

        func readBytes(_ count: Int) throws -> [UInt8] {
            guard offset + count <= data.endIndex else { throw RegistryReaderError.malformedData }
            let bytes = Array(data[offset..<(offset + count)])
            offset += count
            return bytes
        }

        // Validate magic "FLEN"
        let magic = try readBytes(4)
        guard magic == [0x46, 0x4C, 0x45, 0x4E] else {
            throw RegistryReaderError.invalidMagic
        }

        let version = try readUInt32()
        guard version == 1 else {
            throw RegistryReaderError.unsupportedVersion(version)
        }

        let tier1Count = try readUInt32()
        _ = try readUInt32() // skip tier2Count (Phase 1: always 0)

        var result: [String: String] = [:]
        result.reserveCapacity(Int(tier1Count))

        for _ in 0..<tier1Count {
            let keyLen = Int(try readUInt32())
            let keyBytes = try readBytes(keyLen)
            guard let entryKey = String(bytes: keyBytes, encoding: .utf8) else {
                throw RegistryReaderError.malformedData
            }

            let nonce = try readBytes(12)
            let cipherLen = Int(try readUInt32())
            let cipherWithTag = try readBytes(cipherLen)

            let plaintext: [UInt8]
            do {
                plaintext = try AesGcmDecryptor.decrypt(key: key, nonce: nonce, cipherWithTag: cipherWithTag)
            } catch {
                throw RegistryReaderError.decryptionFailed(
                    "Decryption failed for key '\(entryKey)': \(error.localizedDescription)"
                )
            }

            guard let value = String(bytes: plaintext, encoding: .utf8) else {
                throw RegistryReaderError.malformedData
            }
            result[entryKey] = value
        }

        return result
    }
}
