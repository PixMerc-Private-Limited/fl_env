import Foundation

/// Persists fl_env runtime state using UserDefaults.
///
/// Phase 1 stores only the active tier name. Phase 2 will migrate to
/// Keychain-backed storage for sensitive runtime state.
final class RuntimeStorage {

    static let shared = RuntimeStorage()
    private init() {}

    private let defaults = UserDefaults.standard
    private let activeTierKey = "fl_env_active_tier"

    func getActiveTier() -> String? {
        return defaults.string(forKey: activeTierKey)
    }

    func setActiveTier(_ tier: String) {
        defaults.set(tier, forKey: activeTierKey)
    }
}
