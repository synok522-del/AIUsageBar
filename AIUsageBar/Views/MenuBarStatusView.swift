import SwiftUI

struct MenuBarStatusView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        HStack(spacing: 4) {
            Text("GPT \(displayValue(for: viewModel.chatGPT))")
            Text("·")
            Text("C \(displayValue(for: viewModel.claude))")
        }
        .font(.system(size: 12, weight: .medium))
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
        .help("GPT 與 Claude 剩餘用量")
        .task {
            await viewModel.refreshAll()
        }
    }

    private func displayValue(for info: UsageInfo) -> String {
        info.isLoaded ? "\(info.sessionPercent)%" : "—"
    }
}
