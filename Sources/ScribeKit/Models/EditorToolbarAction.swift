import Foundation

/// All toolbar actions supported by the editor.
/// Named `EditorToolbarAction` to avoid conflict with `SwiftUI.ToolbarItem`.
public enum EditorToolbarAction: String, Hashable, Sendable, CaseIterable, Identifiable {
    // Text styles
    case bold
    case italic
    case underline
    case strikethrough

    // Alignment
    case alignLeading
    case alignCenter
    case alignTrailing

    // Lists
    case bulletList
    case numberedList
    case dashList

    // Heading (renders as a Menu in the toolbar)
    case headingMenu

    // Font size
    case decreaseFontSize
    case increaseFontSize

    // Color (renders as ColorPicker inline in the toolbar)
    case textColor
    case highlightColor

    // Indentation
    case increaseIndent
    case decreaseIndent

    // Extras
    case link
    case image

    public var id: String { rawValue }

    /// The SF Symbol name for this action.
    public var symbolName: String {
        switch self {
        case .bold: 
            return "bold"
        case .italic:
            return "italic"
        case .underline: 
            return "underline"
        case .strikethrough:
            return "strikethrough"
        case .alignLeading: 
            return "text.alignleft"
        case .alignCenter: 
            return "text.aligncenter"
        case .alignTrailing:
            return "text.alignright"
        case .bulletList: 
            return "list.bullet"
        case .numberedList: 
            return "list.number"
        case .dashList: 
            return "list.dash"
        case .headingMenu: 
            return "textformat.size"
        case .decreaseFontSize:
            return "textformat.size.smaller"
        case .increaseFontSize: 
            return "textformat.size.larger"
        case .textColor: 
            return "paintbrush.fill"
        case .highlightColor: 
            return "highlighter"
        case .increaseIndent:
            return "increase.indent"
        case .decreaseIndent:
            return "decrease.indent"
        case .link:
            return "link"
        case .image: 
            return "photo"
        }
    }

    /// A human-readable accessibility label.
    public var accessibilityLabel: String {
        switch self {
        case .bold: 
            return "Bold"
        case .italic: 
            return "Italic"
        case .underline: 
            return "Underline"
        case .strikethrough:
            return "Strikethrough"
        case .alignLeading:
            return "Align leading"
        case .alignCenter:
            return "Align center"
        case .alignTrailing: 
            return "Align trailing"
        case .bulletList: 
            return "Bullet list"
        case .numberedList: 
            return "Numbered list"
        case .dashList: 
            return "Dash list"
        case .headingMenu: 
            return "Heading style"
        case .decreaseFontSize: 
            return "Decrease font size"
        case .increaseFontSize:
            return "Increase font size"
        case .textColor: 
            return "Text color"
        case .highlightColor: 
            return "Highlight color"
        case .increaseIndent:
            return "Increase indent"
        case .decreaseIndent:
            return "Decrease indent"
        case .link:
            return "Insert link"
        case .image: 
            return "Insert image"
        }
    }
}
