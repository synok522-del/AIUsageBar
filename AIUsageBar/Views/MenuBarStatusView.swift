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
                    .frame(width: menuBarImageSize.width, height: menuBarImageSize.height)
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
            width: providerVisibility.shouldShowSetupState ? 16 : menuBarImageSize.width,
            height: providerVisibility.shouldShowSetupState ? 16 : menuBarImageSize.height
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
            claudeSessionKey: viewModel.claudeSessionKey,
            grokSessionToken: viewModel.grokSessionToken
        )
    }

    private var menuBarImageSize: (width: CGFloat, height: CGFloat) {
        MenuBarStatusLayout.imageSize(
            providerCount: providerVisibility.visibleProviders.count
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
        let visibleProviders = providerVisibility.visibleProviders
        let providerCount = visibleProviders.count
        let layoutSize = MenuBarStatusLayout.imageSize(providerCount: providerCount)
        let barHeight = MenuBarStatusLayout.barHeight(providerCount: providerCount)
        let imageSize = NSSize(width: layoutSize.width, height: layoutSize.height)
        let image = NSImage(size: imageSize)

        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        for (index, provider) in visibleProviders.enumerated() {
            drawBar(
                atY: MenuBarStatusLayout.barY(
                    index: index,
                    providerCount: providerCount,
                    imageHeight: imageSize.height,
                    barHeight: barHeight
                ),
                info: usageInfo(for: provider),
                imageSize: imageSize,
                barHeight: barHeight
            )
        }

        image.isTemplate = true
        return image
    }

    private func usageInfo(for provider: UsageProvider) -> UsageInfo {
        switch provider {
        case .chatGPT:
            return viewModel.chatGPT
        case .claude:
            return viewModel.claude
        case .grok:
            return viewModel.grok
        }
    }

    private func drawBar(
        atY y: CGFloat,
        info: UsageInfo,
        imageSize: NSSize,
        barHeight: CGFloat
    ) {
        let percent = min(max(info.sessionPercent, 0), 100)
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
        case .grok:
            accessibilityBar(label: "Grok", info: viewModel.grok)
        }
    }

    private func accessibilityBar(label: String, info: UsageInfo) -> some View {
        let barHeight = MenuBarStatusLayout.barHeight(
            providerCount: providerVisibility.visibleProviders.count
        )

        return Rectangle()
            .fill(.clear)
            .frame(width: menuBarImageSize.width, height: barHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label) 剩餘用量")
            .accessibilityValue(
                info.isLoaded
                ? "\(min(max(info.sessionPercent, 0), 100))%"
                : "尚未載入"
            )
    }
}
