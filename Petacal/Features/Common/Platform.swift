import SwiftUI

/// The few system colours the screens use, named once so iPhone, iPad and Mac share the same code.
extension Color {
    /// Cards on a grouped page.
    nonisolated static var cardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    /// The plain page behind everything.
    nonisolated static var pageBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    /// A quiet fill for chips and placeholders.
    nonisolated static var fillBackground: Color {
        #if os(macOS)
        Color(nsColor: .quaternaryLabelColor)
        #else
        Color(uiColor: .tertiarySystemFill)
        #endif
    }
}

/// A photo from stored data, on any platform.
enum PlatformImage {
    static func make(_ data: Data) -> Image? {
        #if os(macOS)
        NSImage(data: data).map { Image(nsImage: $0) }
        #else
        UIImage(data: data).map { Image(uiImage: $0) }
        #endif
    }
}
