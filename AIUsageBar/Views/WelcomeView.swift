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
    @ObservedObject private var languageStore = AppLanguageStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t(.welcomeTitle))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(L10n.t(.welcomeBody))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t(.getStarted))
                    .font(.headline)

                HStack(spacing: 10) {
                    Button(L10n.t(.signInProvider("ChatGPT")), action: onLoginChatGPT)
                        .buttonStyle(.borderedProminent)

                    Button(L10n.t(.signInProvider("Claude")), action: onLoginClaude)
                        .buttonStyle(.borderedProminent)

                    Button(L10n.t(.signInProvider("Grok")), action: onLoginGrok)
                        .buttonStyle(.borderedProminent)
                }
            }

            Text(L10n.t(.welcomeOptional))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()

                Button(L10n.t(.setUpLater), action: onLater)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(L10n.t(.setUpLaterHelp))
                    .accessibilityLabel(L10n.t(.setUpLater))
            }
        }
        .padding(28)
        .frame(width: 440)
        .environment(\.locale, languageStore.resolved.locale)
        .id(languageStore.preference)
    }
}
