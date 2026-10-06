import SwiftUI

struct ModernCard: View {
    let title: String
    let session: Int?
    let sessionRowLabel: String?
    let sessionAccessibilityLabel: String
    let weekly: Int?
    let weeklyRowLabel: String
    let weeklyAccessibilityLabel: String
    let weeklyUnavailableText: String?
    let sessionResetText: String?
    let weeklyResetText: String?
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            if let session {
                ProgressLine(
                    rowLabel: sessionRowLabel,
                    accessibilityLabel: sessionAccessibilityLabel,
                    value: session,
                    unavailableText: nil,
                    resetText: sessionResetText
                )
            }

            if let weekly {
                ProgressLine(
                    rowLabel: weeklyRowLabel,
                    accessibilityLabel: weeklyAccessibilityLabel,
                    value: weekly,
                    unavailableText: nil,
                    resetText: weeklyResetText
                )
            }
            else if let weeklyUnavailableText {
                ProgressLine(
                    rowLabel: weeklyRowLabel,
                    accessibilityLabel: weeklyAccessibilityLabel,
                    value: nil,
                    unavailableText: weeklyUnavailableText,
                    resetText: weeklyResetText
                )
            }

            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
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
    let value: Int?
    let unavailableText: String?
    let resetText: String?

    private var percent: Int {
        min(max(value ?? 0, 0), 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                if let rowLabel {
                    Text(rowLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.leading)
                        .frame(width: 64, alignment: .leading)
                        .accessibilityHidden(true)
                } else {
                    Color.clear
                        .frame(width: 64)
                        .accessibilityHidden(true)
                }

                if value != nil {
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
                } else {
                    Text(unavailableText ?? L10n.windowDataUnavailable)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }
            }

            if let resetText, !resetText.isEmpty {
                Text(resetText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 74)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let meterValue = value.map(L10n.remainingPercent) ?? (unavailableText ?? L10n.windowDataUnavailable)
        guard let resetText, !resetText.isEmpty else { return meterValue }
        return "\(meterValue), \(resetText)"
    }
}
