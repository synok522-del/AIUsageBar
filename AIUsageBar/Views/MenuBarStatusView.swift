import SwiftUI
import AppKit

struct MenuBarStatusView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        ZStack {
            if providerVisibility.shouldShowSetupState {
                Image(nsImage: setupStatusImage)
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
                    .frame(width: 16, height: 16)
                    .fixedSize()
                    .accessibilityHidden(true)
            } else {
                Image(nsImage: statusImage)
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 10)
                    .fixedSize()
                    .accessibilityHidden(true)

                VStack(spacing: 2) {
                    ForEach(providerVisibility.visibleProviders, id: \.self) { provider in
                        accessibilityBar(for: provider)
                    }
                }
            }

            if providerVisibility.shouldShowSetupState {
                Rectangle()
                    .fill(.clear)
                    .frame(width: 16, height: 16)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(menuBarHelpText)
                    .accessibilityValue("尚未連接 AI")
            }
        }
        .frame(
            width: providerVisibility.shouldShowSetupState ? 16 : 24,
            height: providerVisibility.shouldShowSetupState ? 16 : 10
        )
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityElement(children: .contain)
        .help(menuBarHelpText)
        .task {
            await viewModel.refreshAll()
        }
    }

    private var providerVisibility: ProviderVisibilityPolicy {
        ProviderVisibilityPolicy(
            chatGPTSessionToken: viewModel.chatGPTSessionToken,
            claudeSessionKey: viewModel.claudeSessionKey
        )
    }

    private var menuBarHelpText: String {
        providerVisibility.shouldShowSetupState
            ? "尚未連接 AI"
            : providerVisibility.menuBarHelpText
    }

    private var setupStatusImage: NSImage {
        let imageSize = NSSize(width: 16, height: 16)
        let image = NSImage(size: imageSize)

        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        let barWidth: CGFloat = 13
        let barHeight: CGFloat = 2
        let barX = (imageSize.width - barWidth) / 2

        NSColor.black.setFill()
        for barY in [1, 13] {
            NSBezierPath(
                roundedRect: NSRect(
                    x: barX,
                    y: CGFloat(barY),
                    width: barWidth,
                    height: barHeight
                ),
                xRadius: barHeight / 2,
                yRadius: barHeight / 2
            ).fill()
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: NSColor.black
        ]
        let questionMark = "?"
        let questionMarkSize = questionMark.size(withAttributes: attributes)
        questionMark.draw(
            at: NSPoint(
                x: (imageSize.width - questionMarkSize.width) / 2,
                y: (imageSize.height - questionMarkSize.height) / 2
            ),
            withAttributes: attributes
        )

        image.isTemplate = true
        return image
    }

    private var statusImage: NSImage {
        let imageSize = NSSize(width: 24, height: 10)
        let image = NSImage(size: imageSize)

        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        let visibleProviders = providerVisibility.visibleProviders

        for (index, provider) in visibleProviders.enumerated() {
            drawBar(
                atY: barY(
                    for: index,
                    providerCount: visibleProviders.count,
                    imageHeight: imageSize.height
                ),
                info: usageInfo(for: provider),
                imageSize: imageSize
            )
        }

        image.isTemplate = true
        return image
    }

    private func barY(
        for index: Int,
        providerCount: Int,
        imageHeight: CGFloat
    ) -> CGFloat {
        guard providerCount > 1 else {
            return (imageHeight - 4) / 2
        }

        return index == 0 ? imageHeight - 4 : 0
    }

    private func usageInfo(for provider: UsageProvider) -> UsageInfo {
        switch provider {
        case .chatGPT:
            return viewModel.chatGPT
        case .claude:
            return viewModel.claude
        }
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

    @ViewBuilder
    private func accessibilityBar(for provider: UsageProvider) -> some View {
        switch provider {
        case .chatGPT:
            accessibilityBar(label: "ChatGPT", info: viewModel.chatGPT)
        case .claude:
            accessibilityBar(label: "Claude", info: viewModel.claude)
        }
    }

    private func accessibilityBar(label: String, info: UsageInfo) -> some View {
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
