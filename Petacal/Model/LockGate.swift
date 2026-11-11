import LocalAuthentication
import Observation
import SwiftUI

/// 記録のロック: when it is on, records, amounts and charts stay hidden until Face ID / Touch ID / the passcode passes.
/// Events are never locked. Closing the app locks again.
@Observable
final class LockGate {
    private(set) var isEnabled: Bool
    private(set) var isUnlocked = false
    private let defaults: UserDefaults
    private static let key = "lock.enabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: LockGate.key)
    }

    /// True when records must be hidden right now.
    var isLocked: Bool { isEnabled && !isUnlocked }

    func lock() {
        isUnlocked = false
    }

    /// Asks for Face ID / Touch ID / the passcode. Returns whether it passed.
    @discardableResult
    func unlock() async -> Bool {
        let passed = await LockGate.authenticate(reason: String(localized: "記録のロックを解除します。"))
        if passed { isUnlocked = true }
        return passed
    }

    /// Turning the lock on or off always asks first, so nobody else can switch it off.
    /// False when the iPhone has no passcode, Face ID or Touch ID to check against.
    static var canAuthenticate: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled else { return }
        let reason = enabled ? String(localized: "記録のロックをオンにします。") : String(localized: "記録のロックをオフにします。")
        guard await LockGate.authenticate(reason: reason) else { return }
        isEnabled = enabled
        isUnlocked = true
        defaults.set(enabled, forKey: LockGate.key)
    }

    private static func authenticate(reason: String) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                continuation.resume(returning: false)
                return
            }
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { @Sendable passed, _ in
                continuation.resume(returning: passed)
            }
        }
    }
}

/// Shown in place of records while the lock is on.
struct LockedView: View {
    @Environment(LockGate.self) private var lock

    var body: some View {
        ContentUnavailableView {
            Label("記録はロックされています", systemImage: "lock")
        } description: {
            Text("予定はそのまま見られます。")
        } actions: {
            Button("ロックを解除") { Task { await lock.unlock() } }
                .buttonStyle(.borderedProminent)
        }
    }
}
