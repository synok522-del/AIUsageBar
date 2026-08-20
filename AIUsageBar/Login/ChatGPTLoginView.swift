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
            LoginHeaderView(title: "請在下方登入 ChatGPT")

            WebLoginView(provider: .chatGPT, onCredentialFound: onSuccess)
        }
    }
}
