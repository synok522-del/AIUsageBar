import SwiftUI

struct WelcomePresentationPolicy {
    let isClaudeLoggedIn: Bool
    let isChatGPTLoggedIn: Bool
    let isGrokLoggedIn: Bool
    let isSuppressedForCurrentSession: Bool

    init(
        isClaudeLoggedIn: Bool,
        isChatGPTLoggedIn: Bool,
        isGrokLoggedIn: Bool = false,
        isSuppressedForCurrentSession: Bool
    ) {
        self.isClaudeLoggedIn = isClaudeLoggedIn
        self.isChatGPTLoggedIn = isChatGPTLoggedIn
        self.isGrokLoggedIn = isGrokLoggedIn
        self.isSuppressedForCurrentSession = isSuppressedForCurrentSession
    }

    var shouldShow: Bool {
        guard !isSuppressedForCurrentSession else {
            return false
        }

        return !isClaudeLoggedIn && !isChatGPTLoggedIn && !isGrokLoggedIn
    }
}

struct WelcomeView: View {
    let onLoginChatGPT: () -> Void
    let onLoginClaude: () -> Void
    let onLoginGrok: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("歡迎使用 AIUsageBar")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("AIUsageBar 會常駐在 macOS 選單列，\n讓你快速查看 ChatGPT、Claude 與 Grok 的剩餘用量。")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("開始使用：")
                    .font(.headline)

                HStack(spacing: 10) {
                    Button("登入 ChatGPT", action: onLoginChatGPT)
                        .buttonStyle(.borderedProminent)

                    Button("登入 Claude", action: onLoginClaude)
                        .buttonStyle(.borderedProminent)

                    Button("登入 Grok", action: onLoginGrok)
                        .buttonStyle(.borderedProminent)
                }
            }

            Text("你不需要同時登入全部服務，也可以只使用其中一個。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()

                Button("稍後設定", action: onLater)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("稍後設定 AIUsageBar")
                    .accessibilityLabel("稍後設定")
            }
        }
        .padding(28)
        .frame(width: 440)
    }
}
