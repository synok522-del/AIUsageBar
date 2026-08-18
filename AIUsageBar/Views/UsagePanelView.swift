import SwiftUI

struct UsagePanelView: View {

    @StateObject private var viewModel = UsageViewModel()
    @StateObject private var windowCoordinator = WindowCoordinator()

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                Text("AIUsageBar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if viewModel.isLoading {

                    ProgressView()
                        .scaleEffect(0.7)

                } else {

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
                }


                Button {

                    openSettings()

                } label: {

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("設定")

            }


            providerCard(
                title: "ChatGPT",
                info: viewModel.chatGPT
            )

            providerCard(
                title: "Claude",
                info: viewModel.claude
            )


            if !viewModel.statusMessage.isEmpty {

                Text(viewModel.statusMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
            }


            Text(lastUpdatedText)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary.opacity(0.75))

        }
        .padding(14)
        .frame(width: 300)

        .background {

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.background)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.32), radius: 24, y: 12)
        }

        .task {

            await viewModel.refreshAll()

        }
    }



    @ViewBuilder
    private func providerCard(
        title: String,
        info: UsageInfo
    ) -> some View {


        if info.isLoaded {

            ModernCard(
                title: title,
                session: info.sessionPercent,
                weekly: title == "Claude"
                ? info.weeklyPercent
                : nil,
                reset: info.resetText,
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
                    }
            }
            .shadow(color: Theme.pink.opacity(0.10), radius: 16, y: 7)

        } else {

            ModernCard(
                title: title,
                session: nil,
                weekly: nil,
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

                coordinator.showClaudeLogin { key in

                    model.setClaudeSessionKey(key)
                    model.statusMessage = "Claude 登入成功"

                    Task {
                        await model.refreshAll()
                    }
                }
            },


            onLoginChatGPT: {

                coordinator.showChatGPTLogin { token in

                    model.setChatGPTSessionToken(token)
                    model.statusMessage = "ChatGPT 登入成功"

                    Task {
                        await model.refreshAll()
                    }
                }
            }
        )
    }
}
