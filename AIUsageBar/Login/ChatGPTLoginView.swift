//
//  ChatGPTLoginView.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import SwiftUI

struct ChatGPTLoginView: View {
    let onSuccess: (WebCredential) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LoginHeaderView(title: L10n.loginHeader("ChatGPT"))

            WebLoginView(provider: .chatGPT, onCredentialFound: onSuccess)
        }
    }
}
