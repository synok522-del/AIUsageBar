//
//  GrokLoginView.swift
//  AIUsageBar
//

import SwiftUI

struct GrokLoginView: View {
    let onSuccess: (WebCredential) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LoginHeaderView(title: L10n.loginHeader("Grok"))

            WebLoginView(provider: .grok, onCredentialFound: onSuccess)
        }
    }
}
