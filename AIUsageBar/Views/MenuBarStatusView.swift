import SwiftUI
import AppKit

struct MenuBarStatusView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        ZStack {
            Image(nsImage: statusImage)
                .renderingMode(.template)
                .foregroundStyle(.primary)
                .frame(width: 24, height: 10)
                .fixedSize()
                .accessibilityHidden(true)

            VStack(spacing: 2) {
                accessibilityBar(label: "ChatGPT", info: viewModel.chatGPT)
                accessibilityBar(label: "Claude", info: viewModel.claude)
            }
        }
        .frame(width: 24, height: 10)
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityElement(children: .contain)
        .help("ChatGPT 與 Claude 剩餘用量")
        .task {
            await viewModel.refreshAll()
        }
    }

    private var statusImage: NSImage {
        let imageSize = NSSize(width: 24, height: 10)
        let image = NSImage(size: imageSize)

        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        drawBar(
            atY: imageSize.height - 4,
            info: viewModel.chatGPT,
            imageSize: imageSize
        )
        drawBar(
            atY: 0,
            info: viewModel.claude,
            imageSize: imageSize
        )

        image.isTemplate = true
        return image
    }

    private func drawBar(
        atY y: CGFloat,
        info: UsageInfo,
        imageSize: NSSize
    ) {
        let percent = min(max(info.sessionPercent, 0), 100)
        let barHeight: CGFloat = 4
        let barWidth = imageSize.width

        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(
            roundedRect: NSRect(
                x: 0,
                y: y,
                width: barWidth,
                height: barHeight
            ),
            xRadius: barHeight / 2,
            yRadius: barHeight / 2
        ).fill()

        guard info.isLoaded else {
            return
        }

        let fillWidth = max(2, barWidth * CGFloat(percent) / 100)
        NSColor.black.setFill()
        NSBezierPath(
            roundedRect: NSRect(
                x: 0,
                y: y,
                width: fillWidth,
                height: barHeight
            ),
            xRadius: barHeight / 2,
            yRadius: barHeight / 2
        ).fill()
    }

    private func accessibilityBar(
        label: String,
        info: UsageInfo
    ) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 24, height: 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label) 剩餘用量")
            .accessibilityValue(
                info.isLoaded
                ? "\(min(max(info.sessionPercent, 0), 100))%"
                : "尚未載入"
            )
    }
}
