//
//  ModernCard.swift
//  AIUsageBar
//

import SwiftUI

struct ModernCard: View {

    let title: String
    let session: Int?
    let weekly: Int?
    let reset: String

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            if let session {

                ProgressLine(
                    label: weekly == nil ? "" : "5 小時",
                    value: session
                )
            }

            if let weekly {

                ProgressLine(
                    label: "每週",
                    value: weekly
                )
            }

            if !reset.isEmpty {

                Text(reset)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)

        .background {

            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(

                LinearGradient(

                    colors: [

                        Color.white.opacity(0.07),

                        Color.white.opacity(0.03)

                    ],

                    startPoint: .topLeading,

                    endPoint: .bottomTrailing
                )
            )

            .overlay {

                RoundedRectangle(
                    cornerRadius: 18
                )

                .stroke(
                    Color.white.opacity(0.08),
                    lineWidth: 1
                )

            }

        }
    }
}



private struct ProgressLine: View {

    let label: String
    let value: Int

    private var percent: Int {

        min(max(value, 0), 100)
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 6) {

            if !label.isEmpty {

                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 10) {

                GeometryReader { geo in

                    ZStack(alignment: .leading) {

                        Capsule()
                            .fill(
                                Color.white.opacity(0.08)
                            )

                        Capsule()

                            .fill(

                                LinearGradient(

                                    colors: [

                                        Color(
                                            red: 109/255,
                                            green: 61/255,
                                            blue: 255/255
                                        ),

                                        Color(
                                            red: 255/255,
                                            green: 97/255,
                                            blue: 182/255
                                        )

                                    ],

                                    startPoint: .leading,

                                    endPoint: .trailing
                                )
                            )

                            .frame(
                                width: max(
                                    10,
                                    geo.size.width *
                                    CGFloat(percent) /
                                    100
                                )
                            )

                            .shadow(

                                color: Color(
                                    red: 109/255,
                                    green: 61/255,
                                    blue: 255/255
                                )
                                .opacity(0.55),

                                radius: 10
                            )

                    }

                }

                .frame(height: 8)

                Text("\(percent)%")
                    .font(
                        .system(
                            size: 13,
                            weight: .bold
                        )
                        .monospacedDigit()
                    )
                    .foregroundStyle(.white)
                    .frame(width: 42, alignment: .trailing)

            }

        }

    }

}
