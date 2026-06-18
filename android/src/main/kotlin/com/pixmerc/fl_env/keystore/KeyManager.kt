package com.pixmerc.fl_env.keystore

import android.content.Context

/**
 * Provides the AES-256 key written by `fl_env build` as a raw resource.
 *
 * The key is stored as `fl_env_key.bin` in `res/raw/` of the consumer's app
 * module. Using a binary resource (instead of a generated Kotlin source file)
 * lets the key live in the consumer's project rather than in the plugin's own
 * Gradle module, which is the only approach that works with a published package.
 *
 * Phase 2 will migrate the key from this binary resource into Android Keystore
 * (hardware-backed) on first access, eliminating it from the APK thereafter.
 */
internal object KeyManager {
    fun getKey(context: Context): ByteArray {
        val resId = context.resources.getIdentifier(
            "fl_env_key", "raw", context.packageName,
        )
        check(resId != 0) {
            "fl_env_key.bin not found in res/raw — run 'dart run fl_env build' first."
        }
        return context.resources.openRawResource(resId).use { it.readBytes() }
    }
}
