//
//  ClaudeLoginView.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import SwiftUI

struct ClaudeLoginView: View {
    let onSuccess: (WebCredential) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LoginHeaderView(title: L10n.loginHeader("Claude"))

            WebLoginView(provider: .claude, onCredentialFound: onSuccess)
        }
    }
}
