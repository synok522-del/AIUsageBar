//
//  ChatGPTLoginView.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import SwiftUI

struct ChatGPTLoginView: View {
    let onSuccess: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("請在下方登入 ChatGPT")
                    .font(.headline)
                Spacer()
                Button("關閉", action: onCancel)
            }
            .padding()

            WebLoginView(provider: .chatGPT, onCredentialFound: onSuccess)
        }
    }
}
