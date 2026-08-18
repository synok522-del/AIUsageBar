import SwiftUI

struct UsagePanelView: View {

    @StateObject private var viewModel = UsageViewModel()
    @StateObject private var windowCoordinator = WindowCoordinator()

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {

                Text("AI 用量")
                    .font(.system(size: 17, weight: .semibold))

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
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }


                Button {

                    openSettings()

                } label: {

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)

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
                    .foregroundStyle(.secondary)
            }


            Text(lastUpdatedText)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

        }
        .padding(14)
        .frame(width: 280)

        .background {

            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
            .shadow(
                color: .black.opacity(0.15),
                radius: 20,
                y: 8
            )
        }

        .task {

            await viewModel.refreshAll()

        }
    }



    @ViewBuilder
    private func providerCard(
        title: String,
        info: UsageInfo,
        color: Color
    ) -> some View {


        if info.isLoaded {

            ModernCard(
                title: title,
                session: info.sessionPercent,
                weekly: info.weeklyPercent > 0
                ? info.weeklyPercent
                : nil,
                reset: info.resetText,
            )

        } else if let error = info.errorMessage {

            VStack(alignment: .leading) {

                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))

                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

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
