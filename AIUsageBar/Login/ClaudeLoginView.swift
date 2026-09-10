//
//  ClaudeLoginView.swift
//  AIUsageBar
//
//  Created by Kenny Hung on 2026/8/17.
//


import SwiftUI

struct ClaudeLoginView: View {
    let onSuccess: (WebCredential) -> Void
    @ObservedObject private var languageStore = AppLanguageStore.shared

    var body: some View {
        VStack(spacing: 0) {
            LoginHeaderView(title: L10n.t(.loginPrompt("Claude")))

            WebLoginView(provider: .claude, onCredentialFound: onSuccess)
        }
        .environment(\.locale, languageStore.resolved.locale)
    }
}
