import Foundation

public enum Language: String, Codable, CaseIterable {
    case english = "en", gujarati = "gu"
    public var displayName: String { self == .english ? "English" : "ગુજરાતી" }
}

public enum ThemeMode: String, Codable, CaseIterable {
    case system, light, dark

    /// System follows the OS appearance that the caller passes in.
    public func isDark(systemIsDark: Bool) -> Bool {
        switch self { case .system: return systemIsDark; case .light: return false; case .dark: return true }
    }
}

public struct AutoOptions: Codable, Equatable {
    public var enabled = false
    public var customRules = true
    public var sortByType = true
    public var sortByExtension = false
    public var sortByDate = false
    public var oldFiles = false
    public var oldDays = 90
    public var duplicates = false
    public var intervalMinutes = 15
    public var notify = true
    public init() {}

    enum CodingKeys: String, CodingKey { case enabled, customRules, sortByType, sortByExtension, sortByDate, oldFiles, oldDays, duplicates, intervalMinutes, notify }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let def = AutoOptions()
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? def.enabled
        customRules = try c.decodeIfPresent(Bool.self, forKey: .customRules) ?? def.customRules
        sortByType = try c.decodeIfPresent(Bool.self, forKey: .sortByType) ?? def.sortByType
        sortByExtension = try c.decodeIfPresent(Bool.self, forKey: .sortByExtension) ?? def.sortByExtension
        sortByDate = try c.decodeIfPresent(Bool.self, forKey: .sortByDate) ?? def.sortByDate
        oldFiles = try c.decodeIfPresent(Bool.self, forKey: .oldFiles) ?? def.oldFiles
        oldDays = try c.decodeIfPresent(Int.self, forKey: .oldDays) ?? def.oldDays
        duplicates = try c.decodeIfPresent(Bool.self, forKey: .duplicates) ?? def.duplicates
        intervalMinutes = try c.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? def.intervalMinutes
        notify = try c.decodeIfPresent(Bool.self, forKey: .notify) ?? def.notify
    }
}

public struct AppSettings: Codable, Equatable {
    public var language: Language = .english
    public var theme: ThemeMode = .system
    public var accent: Accent = .maroon
    public var rules: [Rule] = []
    public var oldDays = 90
    public var includeSubfolders = false
    public var auto = AutoOptions()
    public init() {}

    enum CodingKeys: String, CodingKey { case language, theme, accent, rules, oldDays, includeSubfolders, auto }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let def = AppSettings()
        language = try c.decodeIfPresent(Language.self, forKey: .language) ?? def.language
        theme = try c.decodeIfPresent(ThemeMode.self, forKey: .theme) ?? def.theme
        accent = try c.decodeIfPresent(Accent.self, forKey: .accent) ?? def.accent
        rules = try c.decodeIfPresent([Rule].self, forKey: .rules) ?? def.rules
        oldDays = try c.decodeIfPresent(Int.self, forKey: .oldDays) ?? def.oldDays
        includeSubfolders = try c.decodeIfPresent(Bool.self, forKey: .includeSubfolders) ?? def.includeSubfolders
        auto = try c.decodeIfPresent(AutoOptions.self, forKey: .auto) ?? def.auto
    }
}

/// Persists AppSettings as JSON in UserDefaults (inject a private suite in tests).
public final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "darshan.settings.v1"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: key), let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return s
    }
    public func save(_ s: AppSettings) {
        if let data = try? JSONEncoder().encode(s) { defaults.set(data, forKey: key) }
    }
}
