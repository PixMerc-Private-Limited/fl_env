import Flutter
import UIKit

public class FlEnvPlugin: NSObject, FlutterPlugin {

    private var registry: [String: String] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.pixmerc.fl_env/channel",
            binaryMessenger: registrar.messenger(),
        )
        let instance = FlEnvPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.initialize()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getValue":
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "Argument 'key' is required", details: nil))
                return
            }
            result(registry[key])

        case "getAll":
            result(registry)

        case "getActiveTier":
            result(RuntimeStorage.shared.getActiveTier() ?? "development")

        case "switchTier":
            result(FlutterError(
                code: "PHASE_RESTRICTION",
                message: "switchEnvironment is not supported in Phase 1.",
                details: nil,
            ))

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize() {
        do {
            let key = try KeychainManager.getKey()
            guard let url = Bundle.main.url(forResource: "FlEnvRegistry", withExtension: "bin"),
                  let data = try? Data(contentsOf: url) else {
                NSLog("[FlEnv] FlEnvRegistry.bin not found in bundle — run 'fl_env build' first.")
                return
            }
            registry = try RegistryReader.readAll(key: key, from: data)
        } catch {
            NSLog("[FlEnv] initialization failed: %@", error.localizedDescription)
        }
    }
}
