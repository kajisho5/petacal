import Foundation

/// Settings that follow the person to their other devices through iCloud (key-value storage).
/// Only what means the same everywhere: calendar ids, for example, differ per device and stay local.
final class SettingsSync {
    static let keys = ["calendar.pattern", "budget.oshi", "colors.kind"]
    /// Off until the iCloud capability is in the app (the container needs registering on Apple's site first).
    static let isEnabled = true

    private let cloud = NSUbiquitousKeyValueStore.default
    private let defaults: UserDefaults
    private var observers: [NSObjectProtocol] = []
    private var applying = false
    private var started = false
    /// Called after values from another device were copied in.
    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func start() {
        guard SettingsSync.isEnabled, !started else { return }
        started = true
        observers.append(NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud, queue: .main) { [weak self] note in
            let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            MainActor.assumeIsolated { self?.pull(keys) }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.push() }
        })
        cloud.synchronize()
        // What iCloud already has wins (it came from another device); then send what only this device has.
        pull(nil)
        push()
    }

    private func pull(_ changed: [String]?) {
        var any = false
        applying = true
        for key in SettingsSync.keys where changed?.contains(key) ?? true {
            guard let value = cloud.object(forKey: key), !same(value, defaults.object(forKey: key)) else { continue }
            defaults.set(value, forKey: key)
            any = true
        }
        applying = false
        if any { onChange?() }
    }

    private func push() {
        guard !applying else { return }
        for key in SettingsSync.keys {
            guard let value = defaults.object(forKey: key), !same(value, cloud.object(forKey: key)) else { continue }
            cloud.set(value, forKey: key)
        }
    }

    private func same(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case (let a?, let b?): (a as AnyObject).isEqual(b)
        default: false
        }
    }
}
