import SwiftUI
import AppKit

struct SettingsView: View {

    @ObservedObject var viewModel: UsageViewModel

    @State private var launchAtLogin =
        LaunchAtLoginManager.shared.isEnabled

    @AppStorage(UsageNotificationSettings.isEnabledKey)
    private var lowUsageNotificationsEnabled =
        UsageNotificationSettings.defaultEnabled

    var onLoginClaude: () -> Void
    var onLoginChatGPT: () -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 18) {

            Text("設定")
                .font(.title3)
                .bold()

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
                title: "ChatGPT",
                isLoggedIn: !viewModel.chatGPTSessionToken.isEmpty,
                loginAction: onLoginChatGPT,
                logoutAction: {
                    viewModel.setChatGPTSessionToken("")
                    WebSessionManager.shared.clearCookies(for: .chatGPT)
                }
            )

            Divider()

            VStack(alignment: .leading, spacing: 6) {

                Toggle(
                    "低用量通知",
                    isOn: $lowUsageNotificationsEnabled
                )

                Text("剩餘用量低於 20% 時提醒我")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {

                Toggle(
                    "開機自動啟動",
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            launchAtLogin = newValue
                            LaunchAtLoginManager.shared.setEnabled(newValue)
                        }
                    )
                )

                Text("登入 macOS 後自動在選單列啟動 AIUsageBar")
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

                Button("結束 AIUsageBar") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.secondary)
                .help("結束 AIUsageBar")
                .accessibilityLabel("結束 AIUsageBar")
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 20)
        .frame(width: 460)
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

        var text = "版本 \(version) (\(build))"
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

    // MARK: Claude / ChatGPT

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
                    "已登入",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)

                Button("重新登入") {
                    loginAction()
                }
                .buttonStyle(.borderedProminent)

                Button("登出") {
                    logoutAction()
                }
                .buttonStyle(.bordered)

            } else {

                Label(
                    "未登入",
                    systemImage: "xmark.circle.fill"
                )
                .foregroundStyle(.red)

                Button("登入") {
                    loginAction()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
