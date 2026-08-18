import SwiftUI

struct MenuBarStatusView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        HStack(spacing: 4) {
            usageBar(label: "GPT", info: viewModel.chatGPT)
            usageBar(label: "Claude", info: viewModel.claude)
        }
        .fixedSize()
        .help("GPT 與 Claude 剩餘用量")
        .task {
            await viewModel.refreshAll()
        }
    }

    private func usageBar(label: String, info: UsageInfo) -> some View {
        let percent = min(max(info.sessionPercent, 0), 100)

        return ProgressView(
            value: info.isLoaded ? Double(percent) : 0,
            total: 100
        )
        .progressViewStyle(.linear)
        .frame(width: 24)
        .accessibilityLabel(label)
        .accessibilityValue(
            info.isLoaded
            ? "\(percent)% remaining"
            : "Unavailable"
        )
    }
}
