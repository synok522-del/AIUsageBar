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
                Text(L10n.welcomeTitle)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(L10n.welcomeBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.welcomeGetStarted)
                    .font(.headline)

                HStack(spacing: 10) {
                    Button(L10n.signInTo("ChatGPT"), action: onLoginChatGPT)
                        .buttonStyle(.borderedProminent)

                    Button(L10n.signInTo("Claude"), action: onLoginClaude)
                        .buttonStyle(.borderedProminent)

                    Button(L10n.signInTo("Grok"), action: onLoginGrok)
                        .buttonStyle(.borderedProminent)
                }
            }

            Text(L10n.welcomeOptional)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()

                Button(L10n.later, action: onLater)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(L10n.laterHelp)
                    .accessibilityLabel(L10n.later)
            }
        }
        .padding(28)
        .frame(width: 520)
    }
}
