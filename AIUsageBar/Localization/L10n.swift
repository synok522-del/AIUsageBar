import Foundation

/// Thin wrapper around Apple's `Localizable` string catalog.
/// English is the development language and missing-key fallback.
enum L10n {
    static var bundle: Bundle {
        Bundle(for: LocalizationAnchor.self)
    }

    static func tr(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        let template = bundle.localizedString(
            forKey: key,
            value: defaultValue,
            table: "Localizable"
        )
        guard !arguments.isEmpty else {
            return template
        }
        return String(format: template, locale: .current, arguments: arguments)
    }

    // MARK: - App / chrome

    static var appName: String { "AIUsageBar" }
    static var settingsTitle: String { tr("settings.title", "Settings") }
    static var settingsWindowTitle: String { tr("settings.windowTitle", "AI Usage Settings") }
    static var refreshUsage: String { tr("panel.refresh", "Refresh usage") }
    static var refreshingUsage: String { tr("panel.refreshing", "Refreshing usage") }
    static var goToSettings: String { tr("panel.goToSettings", "Open Settings") }
    static var notConnected: String { tr("panel.notConnected", "No AI connected") }
    static var setupHint: String {
        tr(
            "panel.setupHint",
            "Sign in to ChatGPT, Claude, or Grok\nto start tracking usage."
        )
    }
    static var updating: String { tr("panel.updating", "Updating…") }
    static var notUpdatedYet: String { tr("panel.notUpdatedYet", "Not updated yet") }
    static var notLoaded: String { tr("a11y.notLoaded", "Not loaded yet") }
    static func updatedAt(_ time: String) -> String {
        tr("panel.updatedAt", "Updated at %@", time)
    }

    static var fiveHours: String { tr("meter.fiveHours", "5 hours") }
    static var weekly: String { tr("meter.weekly", "Weekly") }

    static var notSignedIn: String { tr("status.notSignedIn", "Not signed in") }
    static var signedIn: String { tr("status.signedIn", "Signed in") }
    static var unsignedIn: String { tr("status.unsignedIn", "Not signed in") }
    static var signIn: String { tr("action.signIn", "Sign In") }
    static var signInAgain: String { tr("action.signInAgain", "Sign In Again") }
    static var signOut: String { tr("action.signOut", "Sign Out") }
    static var updateFailed: String { tr("status.updateFailed", "Update failed") }
    static var timeout: String { tr("status.timeout", "Timed out. Try again later") }
    static var lastUpdatedPrefix: String { tr("status.lastUpdatedPrefix", "Last updated") }
    static func lastUpdated(_ relative: String) -> String {
        tr("status.lastUpdated", "Last updated %@", relative)
    }
    static func rateLimitedRetry(_ provider: String, _ seconds: Int) -> String {
        tr(
            "status.rateLimitedRetry",
            "%@ is rate limited. Try again in about %d seconds",
            provider,
            seconds
        )
    }
    static func rateLimitedPrefix(_ provider: String) -> String {
        tr("status.rateLimitedPrefix", "%@ is rate limited", provider)
    }

    static func loginSucceeded(_ provider: String) -> String {
        tr("status.loginSucceeded", "%@ signed in", provider)
    }

    static func providerError(_ provider: String, _ message: String) -> String {
        tr("status.providerError", "%@: %@", provider, message)
    }

    static var loginSuccessPrefixMarker: String {
        tr("status.loginSuccessMarker", "signed in")
    }

    // MARK: - Settings

    static var lowUsageNotifications: String {
        tr("settings.lowUsageNotifications", "Low Usage Notifications")
    }
    static var lowUsageNotificationsHelp: String {
        tr("settings.lowUsageNotificationsHelp", "Notify me when remaining usage drops below 20%")
    }
    static var launchAtLogin: String { tr("settings.launchAtLogin", "Launch at Login") }
    static var launchAtLoginHelp: String {
        tr("settings.launchAtLoginHelp", "Open AIUsageBar in the menu bar after you sign in to macOS")
    }
    static var quitApp: String { tr("settings.quit", "Quit AIUsageBar") }
    static func version(_ version: String, _ build: String) -> String {
        tr("settings.version", "Version %@ (%@)", version, build)
    }

    // MARK: - Welcome

    static var welcomeTitle: String { tr("welcome.title", "Welcome to AIUsageBar") }
    static var welcomeBody: String {
        tr(
            "welcome.body",
            "AIUsageBar stays in the macOS menu bar so you can quickly check remaining ChatGPT, Claude, and Grok usage."
        )
    }
    static var welcomeGetStarted: String { tr("welcome.getStarted", "Get started:") }
    static func signInTo(_ provider: String) -> String {
        tr("welcome.signInTo", "Sign In to %@", provider)
    }
    static var welcomeOptional: String {
        tr("welcome.optional", "You don’t need to sign in to every service. Use only the ones you want.")
    }
    static var later: String { tr("welcome.later", "Later") }
    static var laterHelp: String { tr("welcome.laterHelp", "Set up AIUsageBar later") }

    // MARK: - Login windows

    static func loginWindowTitle(_ provider: String) -> String {
        tr("login.windowTitle", "Sign In to %@", provider)
    }
    static func loginHeader(_ provider: String) -> String {
        tr("login.header", "Sign in to %@ below", provider)
    }

    // MARK: - Menu bar

    static func remainingUsageOne(_ name: String) -> String {
        tr("menubar.remaining.one", "%@ remaining", name)
    }
    static func remainingUsageTwo(_ first: String, _ second: String) -> String {
        tr("menubar.remaining.two", "%@ and %@ remaining", first, second)
    }
    static func remainingUsageThree(_ first: String, _ second: String, _ third: String) -> String {
        tr("menubar.remaining.three", "%@, %@, and %@ remaining", first, second, third)
    }
    static func remainingUsageA11y(_ name: String) -> String {
        tr("menubar.a11y.remaining", "%@ remaining usage", name)
    }

    // MARK: - Cards / accessibility

    static func remainingPercent(_ percent: Int) -> String {
        tr("a11y.remainingPercent", "%d%% remaining", percent)
    }

    // MARK: - Duration (Grok short-window label)

    static var shortWindow: String { tr("duration.shortWindow", "Short window") }

    static func hours(_ count: Int) -> String {
        if count == 1 {
            return tr("duration.hour.one", "1 hour")
        }
        return tr("duration.hours.other", "%d hours", count)
    }

    static func hoursMinutes(hours: Int, minutes: Int) -> String {
        tr("duration.compound", "%@ %@", Self.hours(hours), Self.minutes(minutes))
    }

    static func minutes(_ count: Int) -> String {
        if count == 1 {
            return tr("duration.minute.one", "1 minute")
        }
        return tr("duration.minutes.other", "%d minutes", count)
    }

    static func minutesSeconds(minutes: Int, seconds: Int) -> String {
        tr("duration.compound", "%@ %@", Self.minutes(minutes), Self.seconds(seconds))
    }

    static func seconds(_ count: Int) -> String {
        if count == 1 {
            return tr("duration.second.one", "1 second")
        }
        return tr("duration.seconds.other", "%d seconds", count)
    }

    // MARK: - Reset copy

    static var resetPrefix: String { tr("reset.prefix", "Resets") }

    static func resetsRelative(_ relative: String) -> String {
        tr("reset.relative", "Resets %@", relative)
    }

    static func resetsAbsolute(_ absolute: String) -> String {
        tr("reset.absolute", "Resets %@", absolute)
    }

    static func combinedReset(_ session: String, _ weekly: String) -> String {
        tr("reset.combined", "%@ · %@", session, weekly)
    }

    // MARK: - Notifications

    static func lowUsageTitle(_ provider: String) -> String {
        tr("notification.lowUsage.title", "%@ usage is running low", provider)
    }

    static func lowUsageBody(_ percent: Int) -> String {
        tr("notification.lowUsage.body", "Currently %d%% remaining", percent)
    }

    static func lowUsageBodyWithReset(_ percent: Int, _ reset: String) -> String {
        tr("notification.lowUsage.bodyWithReset", "Currently %d%% remaining, %@", percent, reset)
    }

    // MARK: - Errors

    static func invalidResponse(_ service: String) -> String {
        tr("error.invalidResponse", "%@ returned an invalid response", service)
    }
    static func sessionExpired(_ service: String) -> String {
        tr("error.sessionExpired", "%@ sign-in expired. Please sign in again", service)
    }
    static func forbidden(_ service: String) -> String {
        tr("error.forbidden", "%@ access denied. Please sign in again", service)
    }
    static func rateLimited(_ service: String) -> String {
        tr("error.rateLimited", "%@ is rate limited. Try again later", service)
    }
    static func temporarilyUnavailable(_ service: String) -> String {
        tr("error.unavailable", "%@ is temporarily unavailable", service)
    }
    static func httpError(_ service: String, _ status: Int) -> String {
        tr("error.http", "%@ error (HTTP %d)", service, status)
    }
    static func invalidPayload(_ service: String) -> String {
        tr("error.invalidPayload", "%@ returned invalid data", service)
    }
    static func wafBlocked(_ service: String) -> String {
        tr("error.wafBlocked", "%@ was blocked by site protection. Try again later", service)
    }
    static var missingChatGPTToken: String {
        tr("error.missingChatGPTToken", "Couldn’t get a ChatGPT access token")
    }
    static var missingClaudeOrganization: String {
        tr("error.missingClaudeOrganization", "Couldn’t find a Claude organization ID")
    }

    static var invalidPayloadMarker: String {
        tr("error.invalidPayloadMarker", "invalid data")
    }

    static var sessionExpiredMarker: String {
        tr("error.sessionExpiredMarker", "sign-in expired")
    }

    static func hasResetPrefix(_ text: String) -> Bool {
        text.hasPrefix(resetPrefix)
    }
}

private final class LocalizationAnchor: NSObject {}
