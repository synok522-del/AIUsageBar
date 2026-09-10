import Combine
import Foundation

enum ResolvedAppLanguage: String, Equatable, Sendable {
    case chineseTraditional
    case english

    var locale: Locale {
        switch self {
        case .chineseTraditional:
            return Locale(identifier: "zh_TW")
        case .english:
            return Locale(identifier: "en_US")
        }
    }
}

enum AppLanguagePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case chineseTraditional = "zh-Hant"
    case english = "en"

    var id: String { rawValue }

    func resolve(
        systemLanguageCode: String? = Locale.current.language.languageCode?.identifier
    ) -> ResolvedAppLanguage {
        switch self {
        case .chineseTraditional:
            return .chineseTraditional
        case .english:
            return .english
        case .system:
            if Self.isChineseLanguageCode(systemLanguageCode) {
                return .chineseTraditional
            }
            return .english
        }
    }

    private static func isChineseLanguageCode(_ code: String?) -> Bool {
        guard let code, !code.isEmpty else {
            return false
        }
        let normalized = code.lowercased()
        return normalized == "zh" || normalized.hasPrefix("zh-")
    }
}

enum AppLanguageSettings {
    static let defaultsKey = "appLanguage"

    /// Tests pin Traditional Chinese so existing assertions stay stable on English CI hosts.
    static var testingOverride: ResolvedAppLanguage?

    static var preference: AppLanguagePreference {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
                  let value = AppLanguagePreference(rawValue: raw) else {
                return .system
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    static var resolved: ResolvedAppLanguage {
        if let testingOverride {
            return testingOverride
        }
        return preference.resolve()
    }
}

@MainActor
final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()

    @Published var preference: AppLanguagePreference {
        didSet {
            AppLanguageSettings.preference = preference
        }
    }

    var resolved: ResolvedAppLanguage {
        AppLanguageSettings.testingOverride ?? preference.resolve()
    }

    private init() {
        _preference = Published(initialValue: AppLanguageSettings.preference)
    }
}
