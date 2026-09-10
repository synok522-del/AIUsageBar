//
//  GrokLoginView.swift
//  AIUsageBar
//

import SwiftUI

struct GrokLoginView: View {
    let onSuccess: (WebCredential) -> Void
    @ObservedObject private var languageStore = AppLanguageStore.shared

    var body: some View {
        VStack(spacing: 0) {
            LoginHeaderView(title: L10n.t(.loginPrompt("Grok")))

            WebLoginView(provider: .grok, onCredentialFound: onSuccess)
        }
        .environment(\.locale, languageStore.resolved.locale)
    }
}
