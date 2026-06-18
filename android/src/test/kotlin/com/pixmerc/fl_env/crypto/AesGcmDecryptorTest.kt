package com.pixmerc.fl_env.crypto

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNull
import org.junit.Test
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class AesGcmDecryptorTest {

    private val key = ByteArray(32) { it.toByte() } // 0x00..0x1F
    private val nonce = ByteArray(12) { (it + 1).toByte() }

    private fun encrypt(key: ByteArray, nonce: ByteArray, plaintext: ByteArray): ByteArray {
        val secretKey = SecretKeySpec(key, "AES")
        val spec = GCMParameterSpec(128, nonce)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey, spec)
        return cipher.doFinal(plaintext)
    }

    @Test
    fun `decrypt returns original plaintext`() {
        val plaintext = "hello fl_env".toByteArray()
        val cipherWithTag = encrypt(key, nonce, plaintext)
        val result = AesGcmDecryptor.decrypt(key, nonce, cipherWithTag)
        assertArrayEquals(plaintext, result)
    }

    @Test
    fun `decrypt returns null on wrong key`() {
        val plaintext = "secret".toByteArray()
        val cipherWithTag = encrypt(key, nonce, plaintext)
        val wrongKey = ByteArray(32) { (it + 1).toByte() }
        assertNull(AesGcmDecryptor.decrypt(wrongKey, nonce, cipherWithTag))
    }

    @Test
    fun `decrypt returns null on tampered ciphertext`() {
        val cipherWithTag = encrypt(key, nonce, "secret".toByteArray())
        cipherWithTag[0] = cipherWithTag[0].xor(0xFF.toByte())
        assertNull(AesGcmDecryptor.decrypt(key, nonce, cipherWithTag))
    }

    @Test
    fun `decrypt returns null on wrong nonce`() {
        val cipherWithTag = encrypt(key, nonce, "secret".toByteArray())
        val wrongNonce = ByteArray(12)
        assertNull(AesGcmDecryptor.decrypt(key, wrongNonce, cipherWithTag))
    }

    @Test
    fun `decrypt handles empty plaintext`() {
        val plaintext = ByteArray(0)
        val cipherWithTag = encrypt(key, nonce, plaintext)
        val result = AesGcmDecryptor.decrypt(key, nonce, cipherWithTag)
        assertArrayEquals(plaintext, result)
    }

    @Test
    fun `decrypt handles unicode plaintext`() {
        val plaintext = "こんにちは世界".toByteArray(Charsets.UTF_8)
        val cipherWithTag = encrypt(key, nonce, plaintext)
        val result = AesGcmDecryptor.decrypt(key, nonce, cipherWithTag)
        assertArrayEquals(plaintext, result)
    }
}
