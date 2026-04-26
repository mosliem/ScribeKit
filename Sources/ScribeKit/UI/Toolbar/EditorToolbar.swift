import SwiftUI

/// The horizontal formatting toolbar. Reads `EditorContext` for active button states.
/// Toolbar config is filtered once in `init` to avoid recomputation on every body render.
struct EditorToolbar: View {

    let context: EditorContext

    @Environment(\.editorTheme) private var theme

    /// Cached filtered configuration — computed once per EditorConfiguration, not on every render.
    private let filteredConfig: ToolbarConfiguration

    init(context: EditorContext, configuration: EditorConfiguration) {
        self.context = context
        self.filteredConfig = ToolbarConfiguration.default.filtered(
            to: configuration.allowedToolbarItems)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(filteredConfig.groups) { group in
                    HStack(spacing: 2) {
                        ForEach(group.actions) { action in
                            toolbarControl(for: action)
                        }
                    }

                    // Divider between groups (not after the last)
                    if group.id != filteredConfig.groups.last?.id {
                        Divider()
                            .frame(height: 24)
                            .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(theme.toolbarBackgroundColor)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(localized: "toolbar.accessibility_label"))
    }

    // MARK: - Control Builder

    @ViewBuilder
    private func toolbarControl(for action: EditorToolbarAction) -> some View {
        switch action {

        case .headingMenu:
            headingMenuButton

        case .textColor:
            ColorPicker(selection: foregroundColorBinding, supportsOpacity: true) {
                Text(localized: "toolbar.text_color")
            }
            .labelsHidden()
            .frame(width: 36, height: 36)
            .accessibilityLabel(action.accessibilityLabel)

        case .highlightColor:
            ColorPicker(selection: highlightColorBinding, supportsOpacity: true) {
                Text(localized: "toolbar.highlight_color")
            }
            .labelsHidden()
            .frame(width: 36, height: 36)
            .accessibilityLabel(action.accessibilityLabel)

        default:
            ToolbarButtonView(
                action: action,
                isActive: isActive(action),
                onTap: { handleTap(action) }
            )
        }
    }

    // MARK: - Heading Menu

    private var headingMenuButton: some View {
        Menu {
            ForEach(EditorHeadingStyle.allCases) { style in
                Button {
                    context.setHeading(style)
                } label: {
                    Label(style.displayName, systemImage: headingSymbol(for: style))
                }
            }
            Divider()
            Button {
                context.setHeading(nil)
            } label: {
                Label(String.localized("heading.body"), systemImage: "text.alignleft")
            }
        } label: {
            Image(systemName: EditorToolbarAction.headingMenu.symbolName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .foregroundStyle(
                    context.currentHeadingStyle != nil
                    ? theme.toolbarActiveButtonColor
                    : theme.toolbarButtonColor
                )
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            context.currentHeadingStyle != nil
                            ? theme.toolbarActiveButtonColor.opacity(0.15)
                            : Color.clear
                        )
                )
        }
        .accessibilityLabel(EditorToolbarAction.headingMenu.accessibilityLabel)
    }

    private func headingSymbol(for style: EditorHeadingStyle) -> String {
        switch style {
        case .heading1:
            return "1.square"
        case .heading2:
            return "2.square"
        case .heading3:
            return "3.square"
        }
    }

    // MARK: - Color Bindings

    private var foregroundColorBinding: Binding<Color> {
        Binding(
            get: { context.currentForegroundColor ?? Color(.label) },
            set: { color in
                if UIColor(color).cgColor.alpha < 0.01 {
                    context.resetForegroundColor()
                } else {
                    context.setForegroundColor(color)
                }
            }
        )
    }

    private var highlightColorBinding: Binding<Color> {
        Binding(
            get: { context.currentHighlightColor ?? Color(.clear) },
            set: { color in
                context.setHighlightColor(UIColor(color).cgColor.alpha < 0.01 ? nil : color)
            }
        )
    }

    // MARK: - Active State

    private func isActive(_ action: EditorToolbarAction) -> Bool {
        switch action {
        case .bold:
            return context.activeStyles.contains(.bold)
        case .italic:
            return context.activeStyles.contains(.italic)
        case .underline:
            return context.activeStyles.contains(.underline)
        case .strikethrough:
            return context.activeStyles.contains(.strikethrough)
        case .alignLeading:
            return context.currentAlignment == .leading
        case .alignCenter:
            return context.currentAlignment == .center
        case .alignTrailing:
            return context.currentAlignment == .trailing
        case .bulletList:
            return context.currentListStyle == .bullet
        case .numberedList:
            return context.currentListStyle == .numbered
        case .dashList:
            return context.currentListStyle == .dash
        case .link:
            return context.currentLink != nil
            // Active state handled by their custom rendering, not ToolbarButtonView
        case .headingMenu, .textColor, .highlightColor:
            return false
            // No persistent active state for these actions
        case .decreaseFontSize, .increaseFontSize,
                .increaseIndent, .decreaseIndent,
                .image:
            return false
        }
    }

    // MARK: - Tap Handling

    private func handleTap(_ action: EditorToolbarAction) {
        switch action {
        case .bold:
            context.toggleStyle(.bold)
        case .italic:
            context.toggleStyle(.italic)
        case .underline:
            context.toggleStyle(.underline)
        case .strikethrough:
            context.toggleStyle(.strikethrough)
        case .alignLeading:
            context.setAlignment(.leading)
        case .alignCenter:
            context.setAlignment(context.currentAlignment == .center ? .leading : .center)
        case .alignTrailing:
            context.setAlignment(context.currentAlignment == .trailing ? .leading : .trailing)
        case .bulletList:
            context.toggleList(.bullet)
        case .numberedList:
            context.toggleList(.numbered)
        case .dashList:
            context.toggleList(.dash)
        case .link:
            context.insertLink()
        case .image:
            context.insertImage()
        case .decreaseFontSize:
            context.decreaseFontSize()
        case .increaseFontSize:
            context.increaseFontSize()
        case .increaseIndent:
            context.increaseIndent()
        case .decreaseIndent:
            context.decreaseIndent()
            // headingMenu, textColor, highlightColor use their own SwiftUI controls
        case .headingMenu, .textColor, .highlightColor:
            break
        }
    }
}
