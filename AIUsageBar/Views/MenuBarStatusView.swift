import SwiftUI

struct MenuBarStatusView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        VStack(spacing: 2) {
            usageBar(label: "ChatGPT", info: viewModel.chatGPT)
            usageBar(label: "Claude", info: viewModel.claude)
        }
        .frame(width: 24, height: 10)
        .help("ChatGPT 與 Claude 剩餘用量")
        .task {
            await viewModel.refreshAll()
        }
    }

    private func usageBar(label: String, info: UsageInfo) -> some View {
        let percent = min(max(info.sessionPercent, 0), 100)
        let fillWidth = max(2, 24 * CGFloat(percent) / 100)

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Theme.track.opacity(info.isLoaded ? 1 : 0.5))
                .accessibilityHidden(true)

            if info.isLoaded {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.purple, Theme.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 24, height: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) 剩餘用量")
        .accessibilityValue(
            info.isLoaded
            ? "\(percent)%"
            : "尚未載入"
        )
    }
}
