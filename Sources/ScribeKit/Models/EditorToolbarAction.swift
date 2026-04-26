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

    /// A human-readable accessibility label, localized for the current locale.
    public var accessibilityLabel: String {
        switch self {
        case .bold:            return .localized("action.bold")
        case .italic:          return .localized("action.italic")
        case .underline:       return .localized("action.underline")
        case .strikethrough:   return .localized("action.strikethrough")
        case .alignLeading:    return .localized("action.align_leading")
        case .alignCenter:     return .localized("action.align_center")
        case .alignTrailing:   return .localized("action.align_trailing")
        case .bulletList:      return .localized("action.bullet_list")
        case .numberedList:    return .localized("action.numbered_list")
        case .dashList:        return .localized("action.dash_list")
        case .headingMenu:     return .localized("action.heading_style")
        case .decreaseFontSize: return .localized("action.decrease_font_size")
        case .increaseFontSize: return .localized("action.increase_font_size")
        case .textColor:       return .localized("action.text_color")
        case .highlightColor:  return .localized("action.highlight_color")
        case .increaseIndent:  return .localized("action.increase_indent")
        case .decreaseIndent:  return .localized("action.decrease_indent")
        case .link:            return .localized("action.insert_link")
        case .image:           return .localized("action.insert_image")
        }
    }
}
