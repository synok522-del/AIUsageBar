//
//  GrokLoginView.swift
//  AIUsageBar
//

import SwiftUI

struct GrokLoginView: View {
    let onSuccess: (WebCredential) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LoginHeaderView(title: "請在下方登入 Grok")

            WebLoginView(provider: .grok, onCredentialFound: onSuccess)
        }
    }
}
