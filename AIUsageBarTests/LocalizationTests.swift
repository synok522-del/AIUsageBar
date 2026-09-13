import Foundation
import Testing
@testable import AIUsageBar

struct LocalizationTests {
    @Test("String catalog exists with English source and Traditional Chinese")
    func catalogDeclaresEnglishSourceAndTraditionalChinese() throws {
        let catalog = try CatalogFile.load()
        #expect(catalog.sourceLanguage == "en")
        #expect(catalog.languages.contains("en"))
        #expect(catalog.languages.contains("zh-Hant"))
        #expect(!catalog.keys.isEmpty)
    }

    @Test("Important production keys have English and Traditional Chinese translations")
    func importantKeysHaveBothTranslations() throws {
        let catalog = try CatalogFile.load()
        let required: [String] = [
            "settings.title",
            "settings.windowTitle",
            "meter.fiveHours",
            "meter.weekly",
            "action.signIn",
            "action.signInAgain",
            "action.signOut",
            "status.signedIn",
            "status.unsignedIn",
            "status.notSignedIn",
            "reset.prefix",
            "reset.relative",
            "reset.absolute",
            "notification.lowUsage.title",
            "notification.lowUsage.body",
            "error.sessionExpired",
            "error.wafBlocked",
            "welcome.title",
            "panel.setupHint"
        ]

        for key in required {
            let entry = try #require(catalog.strings[key])
            #expect(entry.en != nil, Comment(rawValue: "missing English for \(key)"))
            #expect(entry.zhHant != nil, Comment(rawValue: "missing zh-Hant for \(key)"))
            #expect(!(entry.en ?? "").isEmpty, Comment(rawValue: "empty English for \(key)"))
            #expect(!(entry.zhHant ?? "").isEmpty, Comment(rawValue: "missing zh-Hant value for \(key)"))
        }
    }

    @Test("Every catalog key has matching format placeholders in English and zh-Hant")
    func formatPlaceholdersMatchAcrossLanguages() throws {
        let catalog = try CatalogFile.load()
        for key in catalog.keys {
            let entry = try #require(catalog.strings[key])
            let english = try #require(entry.en)
            let chinese = try #require(entry.zhHant)
            #expect(
                FormatSpecifiers.tokens(in: english) == FormatSpecifiers.tokens(in: chinese),
                Comment(rawValue: "placeholder mismatch for \(key): \(english) vs \(chinese)")
            )
        }
    }

    @Test("Dynamic localized formatting does not crash")
    func dynamicStringsDoNotCrashFormatting() {
        #expect(!L10n.updatedAt("10:00").isEmpty)
        #expect(!L10n.hours(0).isEmpty)
        #expect(!L10n.hours(1).isEmpty)
        #expect(!L10n.hours(5).isEmpty)
        #expect(!L10n.hoursMinutes(hours: 1, minutes: 30).isEmpty)
        #expect(!L10n.hoursMinutes(hours: 2, minutes: 5).isEmpty)
        #expect(!L10n.minutes(1).isEmpty)
        #expect(!L10n.minutesSeconds(minutes: 1, seconds: 30).isEmpty)
        #expect(!L10n.seconds(45).isEmpty)
        #expect(!L10n.resetsRelative("in 5 hours").isEmpty)
        #expect(!L10n.resetsAbsolute("Sep 10, 10:00 AM").isEmpty)
        #expect(L10n.loginSucceeded("Claude").contains("Claude"))
        #expect(L10n.providerError("Grok", "unavailable").contains("Grok"))
        #expect(L10n.lowUsageTitle("ChatGPT").contains("ChatGPT"))
        #expect(!L10n.lowUsageBody(19).isEmpty)
        #expect(!L10n.lowUsageBodyWithReset(19, L10n.resetsRelative("in 2 hours")).isEmpty)
        #expect(!L10n.httpError("Grok", 503).isEmpty)
        #expect(!L10n.version("1.0.0", "4").isEmpty)
        #expect(!L10n.remainingPercent(20).isEmpty)
    }

    @Test("Rate-limit retry copy starts with its prefix in every supported locale")
    func rateLimitedRetryPreservesPrefixAcrossLocalesAndProviders() throws {
        let catalog = try CatalogFile.load()
        let prefixTemplate = try #require(catalog.strings["status.rateLimitedPrefix"])
        let retryTemplate = try #require(catalog.strings["status.rateLimitedRetry"])
        let providers = ["ChatGPT", "Claude", "Grok"]

        for locale in SupportedCatalogLocale.allCases {
            let prefix = try #require(prefixTemplate.value(for: locale))
            let retry = try #require(retryTemplate.value(for: locale))

            for provider in providers {
                let renderedPrefix = prefix.replacingOccurrences(of: "%@", with: provider)
                let renderedRetry = retry
                    .replacingOccurrences(of: "%@", with: provider)
                    .replacingOccurrences(of: "%d", with: "60")

                #expect(!renderedPrefix.isEmpty)
                #expect(
                    renderedRetry.hasPrefix(renderedPrefix),
                    Comment(rawValue: "rate-limit prefix mismatch for \(locale.rawValue)/\(provider)")
                )
            }
        }
    }

    @Test("Provider and product names stay untranslated")
    func providerNamesRemainCorrect() throws {
        #expect(L10n.appName == "AIUsageBar")
        #expect(UsageProvider.chatGPT.displayName == "ChatGPT")
        #expect(UsageProvider.claude.displayName == "Claude")
        #expect(UsageProvider.grok.displayName == "Grok")

        let catalog = try CatalogFile.load()
        for key in [
            "welcome.body",
            "panel.setupHint",
            "settings.quit",
            "welcome.title",
            "error.missingChatGPTToken",
            "error.missingClaudeOrganization"
        ] {
            let entry = try #require(catalog.strings[key])
            if key.contains("ChatGPT") || (entry.en?.contains("ChatGPT") == true) {
                #expect(entry.zhHant?.contains("ChatGPT") == true, Comment(rawValue: "ChatGPT translated in \(key)"))
            }
            if entry.en?.contains("Claude") == true {
                #expect(entry.zhHant?.contains("Claude") == true, Comment(rawValue: "Claude translated in \(key)"))
            }
            if entry.en?.contains("Grok") == true {
                #expect(entry.zhHant?.contains("Grok") == true, Comment(rawValue: "Grok translated in \(key)"))
            }
            if entry.en?.contains("AIUsageBar") == true {
                #expect(entry.zhHant?.contains("AIUsageBar") == true, Comment(rawValue: "AIUsageBar translated in \(key)"))
            }
        }
    }

    @Test("Missing localization falls back to English instead of exposing the key")
    func missingLocalizationDoesNotExposeRawKeys() {
        let fallback = L10n.tr("localization.missing.test.key", "English fallback")
        #expect(fallback == "English fallback")
        #expect(fallback != "localization.missing.test.key")
        #expect(L10n.settingsTitle != "settings.title")
        #expect(L10n.signIn != "action.signIn")
        #expect(L10n.resetPrefix != "reset.prefix")
    }

    @Test("Reset timestamp parsing semantics are unchanged by localization")
    func resetSemanticsRemainTimestampBased() {
        let timestamp = 1_700_000_000.0
        #expect(ServiceSupport.resetDate(timestamp) == Date(timeIntervalSince1970: timestamp))
        #expect(ServiceSupport.resetDate("1700000000000") == Date(timeIntervalSince1970: timestamp))
        #expect(!ServiceSupport.resetText(timestamp).isEmpty)
        #expect(L10n.hasResetPrefix(ServiceSupport.resetText(timestamp)))
        #expect(ServiceSupport.resetText(nil).isEmpty)
        #expect(ServiceSupport.absoluteResetText(timestamp).isEmpty == false)

        let weeklyOnly = ServiceSupport.combinedResetText(session: "", weekly: "Sep 2")
        #expect(weeklyOnly == L10n.resetsAbsolute("Sep 2"))
        #expect(
            ServiceSupport.combinedResetText(session: "A", weekly: "B")
                == L10n.combinedReset("A", "B")
        )
    }

    @Test("Low-usage notification copy localizes without changing identifiers")
    func notificationLocalizationKeepsProviderIdentity() {
        let title = L10n.lowUsageTitle("Claude")
        let body = L10n.lowUsageBody(19)
        let bodyWithReset = L10n.lowUsageBodyWithReset(19, "Resets soon")

        #expect(title.contains("Claude"))
        #expect(body.contains("19"))
        #expect(bodyWithReset.contains("19"))
        #expect(bodyWithReset.contains("Resets soon"))
        #expect(title != "notification.lowUsage.title")
    }

    @Test("Production Swift sources do not hard-code user-facing Chinese literals")
    func productionSwiftHasNoUserFacingChineseLiterals() throws {
        let leftovers = try ChineseLiteralScanner.scanProductionSources()
        #expect(
            leftovers.isEmpty,
            Comment(rawValue: leftovers.map { "\($0.file):\($0.line): \($0.literal)" }.joined(separator: "\n"))
        )
    }

    @Test("Format specifier parser detects %%, %@, %d, and %s in order")
    func formatSpecifierParserDetectsPercentTokensInOrder() {
        #expect(
            FormatSpecifiers.tokens(in: "%@ used %d of %s %% done")
                == ["%@", "%d", "%s", "%%"]
        )
        #expect(FormatSpecifiers.tokens(in: "%d%% remaining") == ["%d", "%%"])
        #expect(FormatSpecifiers.tokens(in: "no specifiers") == [])
        #expect(FormatSpecifiers.tokens(in: "%%") == ["%%"])
    }

    @Test("English duration catalog values use singular and plural forms")
    func englishDurationCatalogUsesSingularAndPlural() throws {
        let catalog = try CatalogFile.load()
        #expect(catalog.strings["duration.hour.one"]?.en == "1 hour")
        #expect(catalog.strings["duration.hours.other"]?.en == "%d hours")
        #expect(catalog.strings["duration.minute.one"]?.en == "1 minute")
        #expect(catalog.strings["duration.minutes.other"]?.en == "%d minutes")
        #expect(catalog.strings["duration.second.one"]?.en == "1 second")
        #expect(catalog.strings["duration.seconds.other"]?.en == "%d seconds")
        #expect(catalog.strings["duration.compound"]?.en == "%@ %@")
        #expect(catalog.strings["duration.compound"]?.zhHant == "%@ %@")
        #expect(catalog.strings["reset.combined"]?.en == "%@ · %@")
        #expect(catalog.strings["reset.combined"]?.zhHant == "%@｜%@")

        #expect(L10n.hoursMinutes(hours: 1, minutes: 1) == L10n.tr("duration.compound", "%@ %@", L10n.hours(1), L10n.minutes(1)))
        #expect(L10n.hoursMinutes(hours: 1, minutes: 2) == L10n.tr("duration.compound", "%@ %@", L10n.hours(1), L10n.minutes(2)))
        #expect(L10n.hoursMinutes(hours: 2, minutes: 1) == L10n.tr("duration.compound", "%@ %@", L10n.hours(2), L10n.minutes(1)))
        #expect(L10n.hoursMinutes(hours: 2, minutes: 2) == L10n.tr("duration.compound", "%@ %@", L10n.hours(2), L10n.minutes(2)))
        #expect(L10n.minutesSeconds(minutes: 1, seconds: 1) == L10n.tr("duration.compound", "%@ %@", L10n.minutes(1), L10n.seconds(1)))
        #expect(L10n.minutesSeconds(minutes: 2, seconds: 1) == L10n.tr("duration.compound", "%@ %@", L10n.minutes(2), L10n.seconds(1)))
        #expect(L10n.minutesSeconds(minutes: 2, seconds: 2) == L10n.tr("duration.compound", "%@ %@", L10n.minutes(2), L10n.seconds(2)))
    }
}

private struct CatalogFile {
    let sourceLanguage: String
    let strings: [String: CatalogEntry]

    var keys: [String] { Array(strings.keys) }
    var languages: Set<String> {
        var values: Set<String> = []
        for entry in strings.values {
            if entry.en != nil { values.insert("en") }
            if entry.zhHant != nil { values.insert("zh-Hant") }
        }
        return values
    }

    static func load() throws -> CatalogFile {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AIUsageBar")
            .appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let source = object?["sourceLanguage"] as? String ?? ""
        let stringsObject = object?["strings"] as? [String: Any] ?? [:]
        var parsed: [String: CatalogEntry] = [:]
        for (key, value) in stringsObject {
            guard let dictionary = value as? [String: Any],
                  let localizations = dictionary["localizations"] as? [String: Any] else {
                continue
            }
            parsed[key] = CatalogEntry(
                en: stringValue(in: localizations, locale: "en"),
                zhHant: stringValue(in: localizations, locale: "zh-Hant")
            )
        }
        return CatalogFile(sourceLanguage: source, strings: parsed)
    }

    private static func stringValue(in localizations: [String: Any], locale: String) -> String? {
        guard let localeObject = localizations[locale] as? [String: Any],
              let unit = localeObject["stringUnit"] as? [String: Any],
              let value = unit["value"] as? String else {
            return nil
        }
        return value
    }
}

private struct CatalogEntry {
    let en: String?
    let zhHant: String?

    func value(for locale: SupportedCatalogLocale) -> String? {
        switch locale {
        case .en:
            return en
        case .zhHant:
            return zhHant
        }
    }
}

private enum SupportedCatalogLocale: String, CaseIterable {
    case en
    case zhHant = "zh-Hant"
}

private enum FormatSpecifiers {
    static func tokens(in value: String) -> [String] {
        var tokens: [String] = []
        let characters = Array(value)
        var index = 0
        while index < characters.count {
            if characters[index] == "%", index + 1 < characters.count {
                let next = characters[index + 1]
                switch next {
                case "%":
                    tokens.append("%%")
                    index += 2
                    continue
                case "@", "d", "s":
                    tokens.append("%\(next)")
                    index += 2
                    continue
                default:
                    break
                }
            }
            index += 1
        }
        return tokens
    }
}

private struct ChineseLiteralScanner {
    struct Finding {
        let file: String
        let line: Int
        let literal: String
    }

    static func scanProductionSources() throws -> [Finding] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AIUsageBar")
        var findings: [Finding] = []
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            findings.append(contentsOf: scanSource(source, file: url.lastPathComponent))
        }
        return findings
    }

    private static func scanSource(_ source: String, file: String) -> [Finding] {
        var findings: [Finding] = []
        var index = source.startIndex
        var line = 1
        var inLineComment = false
        var inBlockComment = false

        while index < source.endIndex {
            let character = source[index]
            let next = source.index(after: index)
            let lookahead = next < source.endIndex ? source[next] : nil

            if character == "\n" {
                line += 1
                inLineComment = false
                index = next
                continue
            }

            if inLineComment {
                index = next
                continue
            }

            if inBlockComment {
                if character == "*", lookahead == "/" {
                    inBlockComment = false
                    index = source.index(after: next)
                    continue
                }
                index = next
                continue
            }

            if character == "/", lookahead == "/" {
                inLineComment = true
                index = source.index(after: next)
                continue
            }
            if character == "/", lookahead == "*" {
                inBlockComment = true
                index = source.index(after: next)
                continue
            }
            if character == "\"" {
                let (literal, endIndex, extraLines) = readStringLiteral(
                    source,
                    startingAt: next
                )
                if containsCJK(literal) {
                    findings.append(Finding(file: file, line: line, literal: literal))
                }
                line += extraLines
                index = endIndex
                continue
            }

            index = next
        }

        return findings
    }

    private static func readStringLiteral(
        _ source: String,
        startingAt start: String.Index
    ) -> (String, String.Index, Int) {
        var index = start
        var extraLines = 0
        var literal = ""
        var escaped = false
        while index < source.endIndex {
            let character = source[index]
            if character == "\n" {
                extraLines += 1
            }
            if escaped {
                literal.append(character)
                escaped = false
                index = source.index(after: index)
                continue
            }
            if character == "\\" {
                escaped = true
                index = source.index(after: index)
                continue
            }
            if character == "\"" {
                return (literal, source.index(after: index), extraLines)
            }
            literal.append(character)
            index = source.index(after: index)
        }
        return (literal, index, extraLines)
    }

    private static func containsCJK(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }
}
