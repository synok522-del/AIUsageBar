import SwiftUI
import AppKit

struct SettingsView: View {

    @ObservedObject var viewModel: UsageViewModel

    @State private var launchAtLogin =
        LaunchAtLoginManager.shared.isEnabled

    @AppStorage(UsageNotificationSettings.isEnabledKey)
    private var lowUsageNotificationsEnabled =
        UsageNotificationSettings.defaultEnabled

    var onLoginChatGPT: () -> Void
    var onLoginClaude: () -> Void
    var onLoginGrok: () -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 18) {

            Text(L10n.settingsTitle)
                .font(.title3)
                .bold()

            providerRow(
                title: "ChatGPT",
                isLoggedIn: !viewModel.chatGPTSessionToken.isEmpty,
                loginAction: onLoginChatGPT,
                logoutAction: {
                    viewModel.setChatGPTSessionToken("")
                    WebSessionManager.shared.clearCookies(for: .chatGPT)
                }
            )

            Divider()

            providerRow(
                title: "Claude",
                isLoggedIn: !viewModel.claudeSessionKey.isEmpty,
                loginAction: onLoginClaude,
                logoutAction: {
                    viewModel.setClaudeSessionKey("")
                    WebSessionManager.shared.clearCookies(for: .claude)
                }
            )

            Divider()

            providerRow(
                title: "Grok",
                isLoggedIn: !viewModel.grokSessionToken.isEmpty,
                loginAction: onLoginGrok,
                logoutAction: {
                    viewModel.setGrokSessionToken("")
                    WebSessionManager.shared.clearCookies(for: .grok)
                }
            )

            Divider()

            VStack(alignment: .leading, spacing: 6) {

                Toggle(
                    L10n.lowUsageNotifications,
                    isOn: $lowUsageNotificationsEnabled
                )

                Text(L10n.lowUsageNotificationsHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {

                Toggle(
                    L10n.launchAtLogin,
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            launchAtLogin = newValue
                            LaunchAtLoginManager.shared.setEnabled(newValue)
                        }
                    )
                )

                Text(L10n.launchAtLoginHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {

                Text(appVersionText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button(L10n.quitApp) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.secondary)
                .help(L10n.quitApp)
                .accessibilityLabel(L10n.quitApp)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 20)
        .frame(width: 500)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String

        guard let version, !version.isEmpty,
              let build, !build.isEmpty else {
            return ""
        }

        var text = L10n.version(version, build)
        if let gitCommit {
            text += " · \(gitCommit)"
        }

        return text
    }

    private var gitCommit: String? {
        guard let url = Bundle.main.url(
            forResource: "GitCommit",
            withExtension: "plist"
        ),
        let data = try? Data(contentsOf: url),
        let object = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ),
        let dictionary = object as? [String: Any],
        let commit = dictionary["GitCommit"] as? String,
        commit.count == 7 else {
            return nil
        }

        return commit
    }

    // MARK: ChatGPT / Claude / Grok

    @ViewBuilder
    private func providerRow(
        title: String,
        isLoggedIn: Bool,
        loginAction: @escaping () -> Void,
        logoutAction: @escaping () -> Void
    ) -> some View {

        HStack {

            Text(title)
                .font(.headline)

            Spacer()

            if isLoggedIn {

                Label(
                    L10n.signedIn,
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)

                Button(L10n.signInAgain) {
                    loginAction()
                }
                .buttonStyle(.borderedProminent)

                Button(L10n.signOut) {
                    logoutAction()
                }
                .buttonStyle(.bordered)

            } else {

                Label(
                    L10n.unsignedIn,
                    systemImage: "xmark.circle.fill"
                )
                .foregroundStyle(.red)

                Button(L10n.signIn) {
                    loginAction()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
