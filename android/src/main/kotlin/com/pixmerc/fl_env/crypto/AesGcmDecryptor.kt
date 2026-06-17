package com.pixmerc.fl_env.crypto

import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

internal object AesGcmDecryptor {

    /**
     * Decrypts [cipherWithTag] (ciphertext + 16-byte GCM tag) using [key] and [nonce].
     *
     * Returns null on any decryption failure (bad key, tampered ciphertext, etc.)
     * rather than throwing, so the plugin can distinguish "key not found" from
     * "decryption error" at the call site.
     */
    fun decrypt(key: ByteArray, nonce: ByteArray, cipherWithTag: ByteArray): ByteArray? {
        return try {
            val secretKey = SecretKeySpec(key, "AES")
            val spec = GCMParameterSpec(128, nonce)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, secretKey, spec)
            cipher.doFinal(cipherWithTag)
        } catch (e: Exception) {
            null
        }
    }
}
