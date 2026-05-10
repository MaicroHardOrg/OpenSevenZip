import Foundation

struct AppLanguage: Equatable, Sendable {
    var code: String
    var englishName: String
    var nativeName: String

    var displayName: String {
        englishName == nativeName ? englishName : "\(englishName) : \(nativeName)"
    }
}

enum L10n {
    static let languageDidChange = Notification.Name("OpenSevenZipLanguageDidChange")
    private static let selectedLanguageDefaultsKey = "OpenSevenZipSelectedLanguage"

    static let supportedLanguages: [AppLanguage] = [
        AppLanguage(code: "en", englishName: "English", nativeName: "English"),
        AppLanguage(code: "zh-Hans", englishName: "Chinese Simplified", nativeName: "简体中文"),
        AppLanguage(code: "ja", englishName: "Japanese", nativeName: "日本語"),
        AppLanguage(code: "ko", englishName: "Korean", nativeName: "한국어"),
        AppLanguage(code: "fr", englishName: "French", nativeName: "Français"),
        AppLanguage(code: "de", englishName: "German", nativeName: "Deutsch"),
        AppLanguage(code: "es", englishName: "Spanish", nativeName: "Español"),
        AppLanguage(code: "ru", englishName: "Russian", nativeName: "Русский")
    ]

    static var selectedLanguageCode: String? {
        let value = UserDefaults.standard.string(forKey: selectedLanguageDefaultsKey) ?? ""
        return value.isEmpty ? nil : value
    }

    static var currentLanguage: AppLanguage {
        language(for: resolvedLanguageCode())
    }

    static func setSelectedLanguageCode(_ code: String?) {
        if let code, supportedLanguages.contains(where: { $0.code == code }) {
            UserDefaults.standard.set(code, forKey: selectedLanguageDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedLanguageDefaultsKey)
        }
        NotificationCenter.default.post(name: languageDidChange, object: nil)
    }

    static func string(_ key: String) -> String {
        let code = resolvedLanguageCode()
        if let value = table(for: code)[key] {
            return value
        }
        return table(for: "en")[key] ?? key
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        var value = string(key)
        for (index, argument) in arguments.enumerated() {
            value = value.replacingOccurrences(of: "{\(index)}", with: String(describing: argument))
        }
        return value
    }

    static func language(for code: String) -> AppLanguage {
        supportedLanguages.first { $0.code == code } ?? supportedLanguages[0]
    }

    static func resolvedLanguageCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if let selectedLanguageCode {
            return selectedLanguageCode
        }
        for preferred in preferredLanguages {
            if let code = normalizedSupportedCode(for: preferred) {
                return code
            }
        }
        return "en"
    }

    static func validateLocalizationTables() throws {
        let englishKeys = Set(table(for: "en").keys)
        for language in supportedLanguages {
            let keys = Set(table(for: language.code).keys)
            let missing = englishKeys.subtracting(keys).filter { !$0.hasPrefix("_") }.sorted()
            if !missing.isEmpty {
                throw NSError(
                    domain: "OpenSevenZipLocalization",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "\(language.code) missing keys: \(missing.joined(separator: ", "))"]
                )
            }
        }
    }

    private static func normalizedSupportedCode(for rawCode: String) -> String? {
        let lower = rawCode.lowercased().replacingOccurrences(of: "_", with: "-")
        if lower == "zh-hans" || lower == "zh-cn" || lower.hasPrefix("zh-hans-") {
            return "zh-Hans"
        }
        if lower.hasPrefix("ja") { return "ja" }
        if lower.hasPrefix("ko") { return "ko" }
        if lower.hasPrefix("fr") { return "fr" }
        if lower.hasPrefix("de") { return "de" }
        if lower.hasPrefix("es") { return "es" }
        if lower.hasPrefix("ru") { return "ru" }
        if lower.hasPrefix("en") { return "en" }
        return nil
    }

    private static func table(for code: String) -> [String: String] {
        loadTable(for: code)
    }

    private static func loadTable(for code: String) -> [String: String] {
        let decoder = JSONDecoder()
        for url in candidateURLs(for: code) {
            if let data = try? Data(contentsOf: url),
               let values = try? decoder.decode([String: String].self, from: data) {
                return values
            }
        }
        return code == "en" ? [:] : table(for: "en")
    }

    private static func candidateURLs(for code: String) -> [URL] {
        let fileName = "\(code).json"
        var urls: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent("Localizations", isDirectory: true).appendingPathComponent(fileName))
        }
        urls.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("Localizations", isDirectory: true)
            .appendingPathComponent(fileName))
        return urls
    }
}
