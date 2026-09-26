import Combine
import Foundation

enum IgnoredApps {
    static let defaults: [String] = [
        "com.1password.1password",
        "com.1password.1password-launcher",
        "com.1password.safari",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.lastpass.LastPass",
        "com.bitwarden.desktop",
        "com.bitwarden.macos",
        "com.dashlane.dashlane",
        "com.keepassx.keepassxc",
        "org.keepassx.keepassxc",
        "com.macpass.MacPass",
        "app.strongbox.osx"
    ]
}

final class AppSettings: ObservableObject {
    static let defaultMaxItems = 100
    static let minMaxItems = 50
    static let maxMaxItems = 500

    @Published var maxItems: Int {
        didSet { defaults.set(maxItems, forKey: Keys.maxItems) }
    }

    @Published var hotkey: KeyCombo {
        didSet {
            defaults.set(Int(hotkey.keyCode), forKey: Keys.hotkeyKeyCode)
            defaults.set(hotkey.storedModifiers, forKey: Keys.hotkeyModifiers)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var monitoringEnabled: Bool {
        didSet { defaults.set(monitoringEnabled, forKey: Keys.monitoringEnabled) }
    }

    @Published var ignoredBundleIDs: [String] {
        didSet { defaults.set(ignoredBundleIDs, forKey: Keys.ignoredBundleIDs) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let maxItems = "klipp.maxItems"
        static let hotkeyKeyCode = "klipp.hotkeyKeyCode"
        static let hotkeyModifiers = "klipp.hotkeyModifiers"
        static let launchAtLogin = "klipp.launchAtLogin"
        static let monitoringEnabled = "klipp.monitoringEnabled"
        static let ignoredBundleIDs = "klipp.ignoredBundleIDs"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedMax = defaults.object(forKey: Keys.maxItems) as? Int
        maxItems = min(Self.maxMaxItems, max(Self.minMaxItems, storedMax ?? Self.defaultMaxItems))

        if defaults.object(forKey: Keys.hotkeyKeyCode) != nil {
            hotkey = KeyCombo.fromStored(
                keyCode: defaults.integer(forKey: Keys.hotkeyKeyCode),
                modifiers: defaults.integer(forKey: Keys.hotkeyModifiers)
            )
        } else {
            hotkey = .default
        }

        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        monitoringEnabled = defaults.object(forKey: Keys.monitoringEnabled) as? Bool ?? true

        if let stored = defaults.array(forKey: Keys.ignoredBundleIDs) as? [String] {
            ignoredBundleIDs = stored
        } else {
            ignoredBundleIDs = IgnoredApps.defaults
        }
    }
}
