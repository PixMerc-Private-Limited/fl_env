package com.pixmerc.fl_env.registry

import android.content.Context
import com.pixmerc.fl_env.crypto.AesGcmDecryptor
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Reads and decrypts the fl_env binary registry from `res/raw/fl_env_registry`.
 *
 * Binary format (all integers big-endian):
 *   Bytes  Field
 *   0-3    Magic: 0x464C454E ("FLEN")
 *   4-7    Version: UInt32 = 1
 *   8-11   Tier-1 entry count: UInt32
 *   12-15  Tier-2 entry count: UInt32 (Phase 1: always 0)
 *
 *   Per entry:
 *     key-length  UInt32
 *     key         UTF-8 bytes
 *     nonce       12 bytes
 *     cipher-len  UInt32  (ciphertext + 16-byte GCM tag)
 *     cipher+tag  bytes
 */
internal class RegistryReader(private val context: Context) {

    @Volatile
    private var cached: Map<String, String>? = null

    fun readAll(key: ByteArray): Map<String, String> {
        cached?.let { return it }

        val resId = context.resources.getIdentifier("fl_env_registry", "raw", context.packageName)
        check(resId != 0) { "fl_env_registry.bin not found in res/raw — run 'fl_env build' first." }

        val bytes = context.resources.openRawResource(resId).use { it.readBytes() }
        val result = parse(key, bytes)
        cached = result
        return result
    }

    /** Parse from raw bytes — used in unit tests without a real [Context]. */
    internal fun readFrom(key: ByteArray, bytes: ByteArray): Map<String, String> = parse(key, bytes)

    private fun parse(key: ByteArray, bytes: ByteArray): Map<String, String> {
        val buf = ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN)

        // Validate magic "FLEN"
        val magic = ByteArray(4).also { buf.get(it) }
        check(magic.contentEquals(byteArrayOf(0x46, 0x4C, 0x45, 0x4E))) {
            "fl_env registry has invalid magic header — file may be corrupt."
        }

        val version = buf.int
        check(version == 1) { "fl_env registry version $version is not supported." }

        val tier1Count = buf.int
        buf.int // skip tier2Count (Phase 1: always 0)

        val result = HashMap<String, String>(tier1Count)
        repeat(tier1Count) {
            val keyLen = buf.int
            val keyBytes = ByteArray(keyLen).also { buf.get(it) }
            val entryKey = String(keyBytes, Charsets.UTF_8)

            val nonce = ByteArray(12).also { buf.get(it) }

            val cipherLen = buf.int
            val cipherWithTag = ByteArray(cipherLen).also { buf.get(it) }

            val plaintext = AesGcmDecryptor.decrypt(key, nonce, cipherWithTag)
                ?: error("fl_env: decryption failed for key '$entryKey' — key mismatch or tampered data.")

            result[entryKey] = String(plaintext, Charsets.UTF_8)
        }

        return result
    }
}
