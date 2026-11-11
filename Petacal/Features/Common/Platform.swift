import SwiftUI
#if os(macOS)
import AppKit
typealias NativeImage = NSImage
#else
import UIKit
typealias NativeImage = UIImage
#endif

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

extension Image {
    init(native image: NativeImage) {
        #if os(macOS)
        self.init(nsImage: image)
        #else
        self.init(uiImage: image)
        #endif
    }
}

extension Color {
    /// A colour with its own value for the dark appearance (red, green, blue from 0 to 1).
    nonisolated static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        #if os(macOS)
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: value.0, green: value.1, blue: value.2, alpha: 1)
        })
        #else
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
        #endif
    }
}

extension ToolbarItemPlacement {
    /// The leading end of the bar at the top (iPhone, iPad) or of the window's toolbar (Mac).
    static var barLeading: ToolbarItemPlacement {
        #if os(macOS)
        .navigation
        #else
        .topBarLeading
        #endif
    }

    static var barTrailing: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .topBarTrailing
        #endif
    }
}

extension View {
    /// A small title in the bar (iPhone, iPad). The Mac's window title is always small.
    func inlineTitle() -> some View {
        #if os(macOS)
        self
        #else
        navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// The number keyboard where there is an on-screen keyboard.
    func numberPad() -> some View {
        #if os(macOS)
        self
        #else
        keyboardType(.numberPad)
        #endif
    }

    /// Sheets on the Mac have no size of their own and their forms need the grouped look.
    func sheetSize() -> some View {
        #if os(macOS)
        frame(minWidth: 480, idealWidth: 540, minHeight: 520, idealHeight: 640)
            .formStyle(.grouped)
        #else
        self
        #endif
    }
}

enum Clipboard {
    static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

enum SystemSettings {
    /// Opens the place where calendar access is granted.
    static func openPrivacy() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
