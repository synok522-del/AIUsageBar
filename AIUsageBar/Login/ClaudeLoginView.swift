//
//  ClaudeLoginView.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import SwiftUI

struct ClaudeLoginView: View {
    let onSuccess: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            loginHeader(title: "請在下方登入 Claude")

            WebLoginView(provider: .claude, onCredentialFound: onSuccess)
        }
    }

    private func loginHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Button("關閉", action: onCancel)
        }
        .padding()
    }
}
