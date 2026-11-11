import SwiftUI

/// Shown for sections that are not built yet, so the navigation can be checked on a real device first.
struct ComingSoonScreen: View {
    let title: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey

    var body: some View {
        ContentUnavailableView {
            Label("準備中です", systemImage: systemImage)
        } description: {
            Text(message)
        }
        .navigationTitle(title)
    }
}
