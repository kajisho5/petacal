import PetaCore
import SwiftUI

/// The 50 colour presets: 10 families x 5 tones (design-spec B-2 色分け).
/// `selection == nil` means "use the original colour".
struct ColorPickerView: View {
    let title: LocalizedStringKey
    let sample: String
    /// Shown in the sample bar while nothing is picked.
    let fallback: Color
    let resetLabel: LocalizedStringKey
    @Binding var selection: Int?

    @Environment(\.colorScheme) private var scheme

    private var current: ColorPreset? { selection.flatMap(ColorPalette.preset) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Grid(horizontalSpacing: 4, verticalSpacing: 6) {
                    GridRow {
                        Color.clear.frame(width: 1, height: 1)
                        ForEach(Array(ColorPalette.toneNames.enumerated()), id: \.offset) { _, tone in
                            Text(verbatim: tone)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityHidden(true)
                    ForEach(0..<ColorPalette.familyNames.count, id: \.self) { family in
                        GridRow {
                            Text(verbatim: ColorPalette.familyNames[family])
                                .font(.subheadline)
                                .gridColumnAlignment(.leading)
                                .accessibilityHidden(true)
                            ForEach(0..<ColorPalette.toneNames.count, id: \.self) { tone in
                                swatch(ColorPalette.presets[family * 5 + tone])
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Text("見本").font(.footnote).foregroundStyle(.secondary)
                    EventBar(title: sample, color: current.map { Color($0, scheme: scheme) } ?? fallback)
                        .frame(height: 26)
                    Text(verbatim: current?.name ?? "")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button(resetLabel) { selection = nil }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.fillBackground, in: Capsule())
                    .disabled(selection == nil)
            }
            .padding()
        }
        .navigationTitle(title)
        .inlineTitle()
    }

    private func swatch(_ preset: ColorPreset) -> some View {
        let isOn = selection == preset.id
        let rgb = scheme == .dark ? preset.dark : preset.light
        return Button { selection = preset.id } label: {
            Circle()
                .fill(Color(rgb))
                .frame(width: 34, height: 34)
                .overlay {
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(rgb.luminance > 0.36 ? Color.black : Color.white)
                    }
                }
                .padding(4)
                .overlay {
                    if isOn { Circle().strokeBorder(Color.primary, lineWidth: 2) }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: preset.name))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
