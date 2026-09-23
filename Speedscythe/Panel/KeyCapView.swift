import SwiftUI

struct KeyCapView: View {
    enum Style {
        case column
        case tile
        case inverted
        case shortcut
    }

    let label: String
    let style: Style

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: style == .shortcut ? .regular : .semibold, design: .monospaced))
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .frame(minWidth: 24)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(background))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(border))
    }

    private var foreground: Color {
        switch style {
        case .column, .shortcut: .primary
        case .tile: .secondary
        case .inverted: Color(nsColor: .windowBackgroundColor)
        }
    }

    private var background: Color {
        switch style {
        case .column, .shortcut: Color(nsColor: .controlBackgroundColor)
        case .tile: .clear
        case .inverted: .primary
        }
    }

    private var border: Color {
        switch style {
        case .column: Color(nsColor: .tertiaryLabelColor)
        case .tile, .shortcut: Color(nsColor: .separatorColor)
        case .inverted: .primary
        }
    }
}
