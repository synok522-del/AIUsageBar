import Foundation

enum L10n {
    static func t(
        _ key: Key,
        language: ResolvedAppLanguage = AppLanguageSettings.resolved
    ) -> String {
        switch language {
        case .chineseTraditional:
            return key.zhHant
        case .english:
            return key.en
        }
    }

    enum Key: Equatable {
        case settings
        case language
        case languageSystem
        case languageChinese
        case languageEnglish
        case lowUsageNotifications
        case lowUsageNotificationsHelp
        case launchAtLogin
        case launchAtLoginHelp
        case openInWindow
        case openMainWindowAtLaunch
        case openMainWindowAtLaunchHelp
        case mainWindowTitle
        case quitApp
        case version(String, String)
        case signedIn
        case signedOut
        case signIn
        case signInAgain
        case signOut
        case refreshUsage
        case refreshingUsage
        case notConnected
        case setupPrompt
        case goToSettings
        case weekly
        case fiveHours
        case updating
        case notUpdatedYet
        case updatedAt(String)
        case remainingPercent(Int)
        case welcomeTitle
        case welcomeBody
        case getStarted
        case signInProvider(String)
        case welcomeOptional
        case setUpLater
        case setUpLaterHelp
        case loginPrompt(String)
        case settingsWindowTitle
        case loginWindowTitle(String)
        case notLoggedIn
        case updateFailed
        case loginSucceeded(String)
        case providerStatus(String, String)
        case remainingUsage(String)
        case remainingUsageTwo(String, String)
        case remainingUsageMany(String, String)
        case remainingUsageA11y(String)
        case notLoaded
        case lowUsageTitle(String)
        case lowUsageBody(Int)
        case lowUsageBodyWithReset(Int, String)
        case missingChatGPTAccessToken
        case missingClaudeOrganization
        case invalidResponse(String)
        case loginExpired(String)
        case noPermission(String)
        case rateLimited(String)
        case serviceUnavailable(String)
        case httpError(String, Int)
        case invalidPayload(String)
        case wafBlocked(String)
        case resetPrefix
        case shortWindow
        case hours(Int)
        case hoursMinutes(Int, Int)
        case minutes(Int)
        case minutesSeconds(Int, Int)
        case seconds(Int)

        var zhHant: String {
            switch self {
            case .settings: return "設定"
            case .language: return "介面語言"
            case .languageSystem: return "跟隨系統"
            case .languageChinese: return "繁體中文"
            case .languageEnglish: return "English"
            case .lowUsageNotifications: return "低用量通知"
            case .lowUsageNotificationsHelp: return "剩餘用量低於 20% 時提醒我"
            case .launchAtLogin: return "開機自動啟動"
            case .launchAtLoginHelp: return "登入 macOS 後自動在選單列啟動 AIUsageBar"
            case .openInWindow: return "在視窗中開啟"
            case .openMainWindowAtLaunch: return "啟動時開啟主視窗"
            case .openMainWindowAtLaunchHelp: return "啟動後在桌面顯示主視窗，用量會一直留在畫面上。選單列圖示仍會保留。"
            case .mainWindowTitle: return "AIUsageBar"
            case .quitApp: return "結束 AIUsageBar"
            case .version(let version, let build): return "版本 \(version) (\(build))"
            case .signedIn: return "已登入"
            case .signedOut: return "未登入"
            case .signIn: return "登入"
            case .signInAgain: return "重新登入"
            case .signOut: return "登出"
            case .refreshUsage: return "重新整理用量"
            case .refreshingUsage: return "正在重新整理用量"
            case .notConnected: return "尚未連接 AI"
            case .setupPrompt: return "登入 ChatGPT、Claude 或 Grok\n即可開始查看使用量。"
            case .goToSettings: return "前往設定"
            case .weekly: return "每週"
            case .fiveHours: return "5 小時"
            case .updating: return "更新中…"
            case .notUpdatedYet: return "尚未更新"
            case .updatedAt(let time): return "更新於 \(time)"
            case .remainingPercent(let percent): return "剩餘 \(percent)%"
            case .welcomeTitle: return "歡迎使用 AIUsageBar"
            case .welcomeBody:
                return "AIUsageBar 會常駐在 macOS 選單列，\n讓你快速查看 ChatGPT、Claude 與 Grok 的剩餘用量。"
            case .getStarted: return "開始使用："
            case .signInProvider(let name): return "登入 \(name)"
            case .welcomeOptional: return "你不需要同時登入全部服務，也可以只使用其中一個。"
            case .setUpLater: return "稍後設定"
            case .setUpLaterHelp: return "稍後設定 AIUsageBar"
            case .loginPrompt(let name): return "請在下方登入 \(name)"
            case .settingsWindowTitle: return "AI 用量設定"
            case .loginWindowTitle(let name): return "登入 \(name)"
            case .notLoggedIn: return "尚未登入"
            case .updateFailed: return "更新失敗"
            case .loginSucceeded(let name): return "\(name) 登入成功"
            case .providerStatus(let name, let message): return "\(name)：\(message)"
            case .remainingUsage(let name): return "\(name) 剩餘用量"
            case .remainingUsageTwo(let first, let second): return "\(first) 與 \(second) 剩餘用量"
            case .remainingUsageMany(let leading, let last): return "\(leading) 與 \(last) 剩餘用量"
            case .remainingUsageA11y(let label): return "\(label) 剩餘用量"
            case .notLoaded: return "尚未載入"
            case .lowUsageTitle(let name): return "\(name) 剩餘用量偏低"
            case .lowUsageBody(let percent): return "目前剩餘 \(percent)%"
            case .lowUsageBodyWithReset(let percent, let reset):
                return "目前剩餘 \(percent)%，\(reset)"
            case .missingChatGPTAccessToken: return "無法取得 ChatGPT Access Token"
            case .missingClaudeOrganization: return "找不到 Claude Organization ID"
            case .invalidResponse(let service): return "\(service) 回應格式錯誤"
            case .loginExpired(let service): return "\(service) 登入已失效，請重新登入"
            case .noPermission(let service): return "\(service) 沒有權限，請重新登入"
            case .rateLimited(let service): return "\(service) 請求過於頻繁，請稍後再試"
            case .serviceUnavailable(let service): return "\(service) 服務暫時無法使用"
            case .httpError(let service, let code): return "\(service) 發生錯誤（HTTP \(code)）"
            case .invalidPayload(let service): return "\(service) 回傳資料格式錯誤"
            case .wafBlocked(let service): return "\(service) 被網站防護擋下，請稍後再試"
            case .resetPrefix: return "重置於 "
            case .shortWindow: return "短窗"
            case .hours(let hours): return "\(hours) 小時"
            case .hoursMinutes(let hours, let minutes): return "\(hours) 小時 \(minutes) 分鐘"
            case .minutes(let minutes): return "\(minutes) 分鐘"
            case .minutesSeconds(let minutes, let seconds): return "\(minutes) 分鐘 \(seconds) 秒"
            case .seconds(let seconds): return "\(seconds) 秒"
            }
        }

        var en: String {
            switch self {
            case .settings: return "Settings"
            case .language: return "Language"
            case .languageSystem: return "System"
            case .languageChinese: return "繁體中文"
            case .languageEnglish: return "English"
            case .lowUsageNotifications: return "Low-usage notifications"
            case .lowUsageNotificationsHelp: return "Notify me when remaining usage drops below 20%"
            case .launchAtLogin: return "Launch at login"
            case .launchAtLoginHelp: return "Start AIUsageBar in the menu bar when you log in to macOS"
            case .openInWindow: return "Open in Window"
            case .openMainWindowAtLaunch: return "Open window at launch"
            case .openMainWindowAtLaunchHelp: return "Show a desktop window when AIUsageBar starts. The menu bar icon stays available."
            case .mainWindowTitle: return "AIUsageBar"
            case .quitApp: return "Quit AIUsageBar"
            case .version(let version, let build): return "Version \(version) (\(build))"
            case .signedIn: return "Signed in"
            case .signedOut: return "Signed out"
            case .signIn: return "Sign in"
            case .signInAgain: return "Sign in again"
            case .signOut: return "Sign out"
            case .refreshUsage: return "Refresh usage"
            case .refreshingUsage: return "Refreshing usage"
            case .notConnected: return "No AI connected"
            case .setupPrompt: return "Sign in to ChatGPT, Claude, or Grok\nto see remaining usage."
            case .goToSettings: return "Open Settings"
            case .weekly: return "Weekly"
            case .fiveHours: return "5h"
            case .updating: return "Updating…"
            case .notUpdatedYet: return "Not updated yet"
            case .updatedAt(let time): return "Updated \(time)"
            case .remainingPercent(let percent): return "\(percent)% remaining"
            case .welcomeTitle: return "Welcome to AIUsageBar"
            case .welcomeBody:
                return "AIUsageBar stays in the macOS menu bar\nso you can check remaining ChatGPT, Claude, and Grok usage."
            case .getStarted: return "Get started:"
            case .signInProvider(let name): return "Sign in to \(name)"
            case .welcomeOptional: return "You don’t need every service. Sign in to only the ones you use."
            case .setUpLater: return "Set up later"
            case .setUpLaterHelp: return "Set up AIUsageBar later"
            case .loginPrompt(let name): return "Sign in to \(name) below"
            case .settingsWindowTitle: return "AI usage settings"
            case .loginWindowTitle(let name): return "Sign in to \(name)"
            case .notLoggedIn: return "Not signed in"
            case .updateFailed: return "Update failed"
            case .loginSucceeded(let name): return "\(name) signed in"
            case .providerStatus(let name, let message): return "\(name): \(message)"
            case .remainingUsage(let name): return "\(name) remaining usage"
            case .remainingUsageTwo(let first, let second): return "\(first) and \(second) remaining usage"
            case .remainingUsageMany(let leading, let last): return "\(leading), and \(last) remaining usage"
            case .remainingUsageA11y(let label): return "\(label) remaining usage"
            case .notLoaded: return "Not loaded"
            case .lowUsageTitle(let name): return "\(name) usage is running low"
            case .lowUsageBody(let percent): return "\(percent)% remaining"
            case .lowUsageBodyWithReset(let percent, let reset):
                return "\(percent)% remaining. \(reset)"
            case .missingChatGPTAccessToken: return "Could not get a ChatGPT access token"
            case .missingClaudeOrganization: return "Could not find a Claude organization ID"
            case .invalidResponse(let service): return "\(service) returned an invalid response"
            case .loginExpired(let service): return "\(service) sign-in expired. Please sign in again"
            case .noPermission(let service): return "\(service) denied access. Please sign in again"
            case .rateLimited(let service): return "\(service) is rate limited. Try again later"
            case .serviceUnavailable(let service): return "\(service) is temporarily unavailable"
            case .httpError(let service, let code): return "\(service) error (HTTP \(code))"
            case .invalidPayload(let service): return "\(service) returned invalid data"
            case .wafBlocked(let service): return "\(service) was blocked by site protection. Try again later"
            case .resetPrefix: return "Resets "
            case .shortWindow: return "Short"
            case .hours(let hours): return "\(hours)h"
            case .hoursMinutes(let hours, let minutes): return "\(hours)h \(minutes)m"
            case .minutes(let minutes): return "\(minutes)m"
            case .minutesSeconds(let minutes, let seconds): return "\(minutes)m \(seconds)s"
            case .seconds(let seconds): return "\(seconds)s"
            }
        }
    }
}
