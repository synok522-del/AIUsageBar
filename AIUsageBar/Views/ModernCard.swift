import SwiftUI

struct ModernCard: View {
    let title: String
    let session: Int?
    let sessionRowLabel: String?
    let sessionAccessibilityLabel: String
    let weekly: Int?
    let weeklyRowLabel: String
    let weeklyAccessibilityLabel: String
    let reset: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            if let session {
                ProgressLine(
                    rowLabel: sessionRowLabel,
                    accessibilityLabel: sessionAccessibilityLabel,
                    value: session
                )
            }

            if let weekly {
                ProgressLine(
                    rowLabel: weeklyRowLabel,
                    accessibilityLabel: weeklyAccessibilityLabel,
                    value: weekly
                )
            }

            if !reset.isEmpty {
                Text(reset)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Theme.card.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Theme.purple.opacity(0.28),
                                    Theme.pink.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .accessibilityHidden(true)
                }
                .accessibilityHidden(true)
        }
        .shadow(color: Theme.purple.opacity(0.16), radius: 18, y: 8)
    }
}

private struct ProgressLine: View {
    let rowLabel: String?
    let accessibilityLabel: String
    let value: Int

    private var percent: Int {
        min(max(value, 0), 100)
    }

    var body: some View {
        HStack(spacing: 10) {
            if let rowLabel {
                Text(rowLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 42, alignment: .leading)
                    .accessibilityHidden(true)
            } else {
                Color.clear
                    .frame(width: 42)
                    .accessibilityHidden(true)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.track)
                        .accessibilityHidden(true)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.purple, Theme.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(percent) / 100)
                        .shadow(color: Theme.pink.opacity(0.35), radius: 6)
                        .animation(.easeInOut(duration: 0.5), value: percent)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 7)
            .accessibilityHidden(true)

            Text("\(percent)%")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 38, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.5), value: percent)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("剩餘 \(percent)%")
    }
}
