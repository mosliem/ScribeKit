import SwiftUI

/// A single toolbar button that shows an SF Symbol icon with active/inactive tinting.
struct ToolbarButtonView: View {

    let action: EditorToolbarAction
    let isActive: Bool
    let onTap: () -> Void

    @Environment(\.editorTheme) private var theme

    var body: some View {
        Button {
            onTap()
        } label: {
            Image(systemName: action.symbolName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .foregroundStyle(isActive ? theme.toolbarActiveButtonColor : theme.toolbarButtonColor)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? theme.toolbarActiveButtonColor.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
