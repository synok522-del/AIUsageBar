import SwiftUI

struct LoginHeaderView: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()
        }
        .padding()
    }
}
