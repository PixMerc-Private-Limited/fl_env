package com.pixmerc.fl_env.storage

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Persists fl_env runtime state using EncryptedSharedPreferences.
 *
 * Phase 1 stores only the active tier name. Phase 2 will add per-tier
 * caching and keychain-backed key rotation state.
 */
internal class RuntimeStorage(context: Context) {

    private val prefs by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        EncryptedSharedPreferences.create(
            context,
            "fl_env_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    fun getActiveTier(): String? = prefs.getString(KEY_ACTIVE_TIER, null)

    fun setActiveTier(tier: String) {
        prefs.edit().putString(KEY_ACTIVE_TIER, tier).apply()
    }

    private companion object {
        const val KEY_ACTIVE_TIER = "active_tier"
    }
}
