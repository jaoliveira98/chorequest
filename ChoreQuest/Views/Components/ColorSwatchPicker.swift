import SwiftUI

/// A row/grid of preset color swatches. Stores its selection as a hex string so
/// it maps directly onto the model fields.
struct ColorSwatchPicker: View {
    @Binding var selection: String
    var options: [String] = Palette.colors

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(options, id: \.self) { hex in
                Button {
                    selection = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().strokeBorder(.primary.opacity(isSelected(hex) ? 0.9 : 0), lineWidth: 3)
                        )
                        .overlay {
                            if isSelected(hex) {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Color \(hex)"))
                .accessibilityAddTraits(isSelected(hex) ? [.isSelected] : [])
            }
        }
    }

    private func isSelected(_ hex: String) -> Bool {
        selection.caseInsensitiveCompare(hex) == .orderedSame
    }
}

#Preview {
    struct Wrapper: View {
        @State private var sel = Palette.colors[0]
        var body: some View { ColorSwatchPicker(selection: $sel).padding() }
    }
    return Wrapper()
}
