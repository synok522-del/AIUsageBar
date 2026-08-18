import SwiftUI

struct SettingsView: View {

    @ObservedObject var viewModel: UsageViewModel

    @State private var launchAtLogin =
        LaunchAtLoginManager.shared.isEnabled

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
                    WebSessionManager.shared.clearCookies()
                }
            )

            Divider()

            providerRow(
                title: "ChatGPT",
                isLoggedIn: !viewModel.chatGPTSessionToken.isEmpty,
                loginAction: onLoginChatGPT,
                logoutAction: {
                    viewModel.setChatGPTSessionToken("")
                    WebSessionManager.shared.clearCookies()
                }
            )

            Divider()

            VStack(alignment: .leading, spacing: 6) {

                Toggle(
                    "開機自動啟動",
                    isOn: $launchAtLogin
                )
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLoginManager.shared.setEnabled(newValue)
                }

                Text("登入 macOS 後自動在選單列啟動 AIUsageBar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 20)
        .frame(width: 460, height: 280)
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
