package com.pixmerc.fl_env.registry

import android.content.Context
import com.pixmerc.fl_env.crypto.AesGcmDecryptor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.mockito.Mockito.mock
import java.nio.ByteBuffer
import java.nio.ByteOrder
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class RegistryReaderTest {

    // A fixed 32-byte key for deterministic tests
    private val key = ByteArray(32) { it.toByte() }

    private fun encrypt(nonce: ByteArray, plaintext: ByteArray): ByteArray {
        val secretKey = SecretKeySpec(key, "AES")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey, GCMParameterSpec(128, nonce))
        return cipher.doFinal(plaintext)
    }

    private fun buildRegistry(entries: Map<String, String>): ByteArray {
        val out = ByteBuffer.allocate(65536).order(ByteOrder.BIG_ENDIAN)
        // Magic "FLEN"
        out.put(byteArrayOf(0x46, 0x4C, 0x45, 0x4E))
        out.putInt(1) // version
        out.putInt(entries.size) // tier1 count
        out.putInt(0) // tier2 count

        entries.forEach { (k, v) ->
            val keyBytes = k.toByteArray(Charsets.UTF_8)
            out.putInt(keyBytes.size)
            out.put(keyBytes)

            val nonce = ByteArray(12) { it.toByte() }
            val cipherWithTag = encrypt(nonce, v.toByteArray(Charsets.UTF_8))
            out.put(nonce)
            out.putInt(cipherWithTag.size)
            out.put(cipherWithTag)
        }

        val result = ByteArray(out.position())
        out.flip()
        out.get(result)
        return result
    }

    private fun reader() = RegistryReader(mock(Context::class.java))

    @Test
    fun `readFrom parses single entry`() {
        val bytes = buildRegistry(mapOf("API_URL" to "https://api.example.com"))
        val result = reader().readFrom(key, bytes)
        assertEquals(mapOf("API_URL" to "https://api.example.com"), result)
    }

    @Test
    fun `readFrom parses multiple entries`() {
        val input = mapOf(
            "BASE_URL" to "https://api.example.com",
            "TIMEOUT" to "30",
            "DEBUG" to "false",
        )
        val result = reader().readFrom(key, buildRegistry(input))
        assertEquals(input, result)
    }

    @Test
    fun `readFrom handles empty registry`() {
        val result = reader().readFrom(key, buildRegistry(emptyMap()))
        assertEquals(emptyMap<String, String>(), result)
    }

    @Test
    fun `readFrom handles empty value`() {
        val result = reader().readFrom(key, buildRegistry(mapOf("EMPTY" to "")))
        assertEquals(mapOf("EMPTY" to ""), result)
    }

    @Test
    fun `readFrom handles unicode value`() {
        val result = reader().readFrom(key, buildRegistry(mapOf("MSG" to "こんにちは世界")))
        assertEquals(mapOf("MSG" to "こんにちは世界"), result)
    }

    @Test
    fun `readFrom throws on invalid magic`() {
        val bytes = buildRegistry(mapOf("K" to "V"))
        bytes[0] = 0x00 // corrupt magic
        assertThrows(IllegalStateException::class.java) {
            reader().readFrom(key, bytes)
        }
    }

    @Test
    fun `readFrom throws on wrong key`() {
        val bytes = buildRegistry(mapOf("K" to "V"))
        val wrongKey = ByteArray(32) { (it + 1).toByte() }
        assertThrows(IllegalStateException::class.java) {
            reader().readFrom(wrongKey, bytes)
        }
    }
}
