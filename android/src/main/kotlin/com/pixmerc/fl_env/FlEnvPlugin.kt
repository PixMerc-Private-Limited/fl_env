package com.pixmerc.fl_env

import android.content.Context
import com.pixmerc.fl_env.keystore.KeyManager
import com.pixmerc.fl_env.registry.RegistryReader
import com.pixmerc.fl_env.storage.RuntimeStorage
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class FlEnvPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var storage: RuntimeStorage

    private var registry: Map<String, String> = emptyMap()
    private var initialized = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.pixmerc.fl_env/channel")
        channel.setMethodCallHandler(this)
        storage = RuntimeStorage(context)
        initialize()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getValue" -> {
                val key = call.argument<String>("key")
                if (key == null) {
                    result.error("INVALID_ARG", "Argument 'key' is required", null)
                } else {
                    result.success(registry[key])
                }
            }
            "getAll" -> result.success(registry)
            "getActiveTier" -> result.success(storage.getActiveTier() ?: "development")
            "switchTier" -> result.error(
                "PHASE_RESTRICTION",
                "switchEnvironment is not supported in Phase 1.",
                null,
            )
            else -> result.notImplemented()
        }
    }

    private fun initialize() {
        try {
            val key = KeyManager.getKey()
            registry = RegistryReader(context).readAll(key)
            initialized = true
        } catch (e: Exception) {
            // Log but do not crash — FlEnvService.init() will surface the error
            android.util.Log.e("FlEnv", "fl_env initialization failed: ${e.message}", e)
        }
    }
}
