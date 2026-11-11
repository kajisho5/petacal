import Observation
import SwiftUI
import UIKit

/// The "追加しました — 取り消す" bar shown for a few seconds after something is added.
/// After it goes away, the item can still be deleted from its own screen.
@Observable
final class UndoCenter {
    private(set) var message: String?
    private var action: (() -> Void)?
    private var token = 0

    func show(_ message: String, undo: @escaping () -> Void) {
        token += 1
        let mine = token
        self.message = message
        action = undo
        UIAccessibility.post(notification: .announcement, argument: message)
        Task {
            try? await Task.sleep(for: .seconds(6))
            if token == mine { clear() }
        }
    }

    func undo() {
        action?()
        clear()
    }

    func clear() {
        message = nil
        action = nil
    }
}

struct UndoBanner: View {
    @Environment(UndoCenter.self) private var center

    var body: some View {
        if let message = center.message {
            HStack(spacing: 12) {
                Text(verbatim: message).font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                Button("取り消す") { center.undo() }
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
