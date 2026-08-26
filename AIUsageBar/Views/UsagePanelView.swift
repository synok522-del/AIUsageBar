import SwiftUI

struct UsagePanelView: View {

    @ObservedObject var viewModel: UsageViewModel
    @StateObject private var windowCoordinator = WindowCoordinator()
    @State private var isPanelVisible = false

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                Text("AIUsageBar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                ZStack {
                    Button {

                        Task {
                            await viewModel.refreshAll()
                        }

                    } label: {

                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("重新整理用量")
                    .accessibilityLabel("重新整理用量")
                    .accessibilityHidden(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0 : 1)
                    .allowsHitTesting(!viewModel.isLoading)

                    ProgressView()
                        .scaleEffect(0.7)
                        .opacity(viewModel.isLoading ? 1 : 0)
                        .accessibilityLabel("正在重新整理用量")
                        .accessibilityHidden(!viewModel.isLoading)
                }
                .frame(width: 18, height: 18)
                .animation(.easeInOut(duration: 0.25), value: viewModel.isLoading)


                Button {

                    openSettings()

                } label: {

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("設定")
                .accessibilityLabel("設定")

            }


            ForEach(providerVisibility.visibleProviders, id: \.self) { provider in
                providerCard(for: provider)
            }

            if providerVisibility.shouldShowSetupState {
                setupState
            }


            if !viewModel.statusMessage.isEmpty {

                Text(viewModel.statusMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                    .transition(.opacity)
            }


            Text(lastUpdatedText)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary.opacity(0.75))
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: viewModel.lastUpdated)

        }
        .padding(14)
        .frame(width: 300)

        .background {

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.background)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .accessibilityHidden(true)
                }
                .accessibilityHidden(true)
                .shadow(color: .black.opacity(0.32), radius: 24, y: 12)
        }
        .opacity(isPanelVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: isPanelVisible)
        .animation(.easeInOut(duration: 0.25), value: viewModel.statusMessage)
        .onAppear {
            isPanelVisible = true
        }
        .onDisappear {
            isPanelVisible = false
        }

        .task {

            await viewModel.refreshAll()

        }
    }


    private var providerVisibility: ProviderVisibilityPolicy {
        // Authentication comes from the existing Keychain-backed session state.
        ProviderVisibilityPolicy(
            isChatGPTAuthenticated: !viewModel.chatGPTSessionToken.isEmpty,
            isClaudeAuthenticated: !viewModel.claudeSessionKey.isEmpty
        )
    }


    @ViewBuilder
    private func providerCard(for provider: UsageProvider) -> some View {
        switch provider {
        case .chatGPT:
            providerCard(
                title: "ChatGPT",
                info: viewModel.chatGPT,
                supportsWeeklyQuota: viewModel.chatGPT.weeklyAvailable,
                sessionRowLabel: "5 小時",
                sessionAccessibilityLabel: "5 小時"
            )

        case .claude:
            providerCard(
                title: "Claude",
                info: viewModel.claude,
                supportsWeeklyQuota: true,
                sessionRowLabel: "5 小時",
                sessionAccessibilityLabel: "5 小時"
            )
        }
    }


    private var setupState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("尚未連接 AI")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("登入 ChatGPT 或 Claude\n即可開始查看使用量。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("前往設定") {
                openSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("前往設定")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Theme.card.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .accessibilityHidden(true)
                }
                .accessibilityHidden(true)
        }
    }



    @ViewBuilder
    private func providerCard(
        title: String,
        info: UsageInfo,
        supportsWeeklyQuota: Bool,
        sessionRowLabel: String?,
        sessionAccessibilityLabel: String
    ) -> some View {


        if info.isLoaded {

            ModernCard(
                title: title,
                session: info.sessionPercent,
                sessionRowLabel: sessionRowLabel,
                sessionAccessibilityLabel: sessionAccessibilityLabel,
                weekly: supportsWeeklyQuota ? info.weeklyPercent : nil,
                weeklyRowLabel: "每週",
                weeklyAccessibilityLabel: "每週",
                reset: ServiceSupport.combinedResetText(
                    session: info.resetText,
                    weekly: info.weeklyResetText
                ),
            )

        } else if let error = info.errorMessage {

            VStack(alignment: .leading) {

                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.pink)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(Theme.card.opacity(0.96))
                    .overlay {
                        RoundedRectangle(cornerRadius: 21, style: .continuous)
                            .stroke(Theme.pink.opacity(0.28), lineWidth: 1)
                            .accessibilityHidden(true)
                    }
                    .accessibilityHidden(true)
            }
            .shadow(color: Theme.pink.opacity(0.10), radius: 16, y: 7)

        } else {

            ModernCard(
                title: title,
                session: nil,
                sessionRowLabel: sessionRowLabel,
                sessionAccessibilityLabel: sessionAccessibilityLabel,
                weekly: nil,
                weeklyRowLabel: "每週",
                weeklyAccessibilityLabel: "每週",
                reset: "請先登入",

            )
        }
    }



    private var lastUpdatedText: String {

        guard let date = viewModel.lastUpdated else {

            return "尚未更新"
        }

        let formatter = DateFormatter()

        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "HH:mm"

        return "更新於 \(formatter.string(from: date))"
    }



    private func openSettings() {

        let coordinator = windowCoordinator
        let model = viewModel


        coordinator.showSettings(

            viewModel: model,


            onLoginClaude: {

                coordinator.showClaudeLogin { credential in

                    model.setClaudeSessionKey(credential.value)
                    model.statusMessage = "Claude 登入成功"

                    Task {
                        await model.refreshAll()
                    }
                }
            },


            onLoginChatGPT: {

                coordinator.showChatGPTLogin { credential in

                    model.setChatGPTCredential(credential)
                    model.statusMessage = "ChatGPT 登入成功"

                    Task {
                        await model.refreshAll()
                    }
                }
            }
        )
    }
}
