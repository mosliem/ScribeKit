import Foundation

/// Semantic heading level for a paragraph. Named `EditorHeadingStyle` to avoid conflicts.
public enum EditorHeadingStyle: String, Hashable, Sendable, CaseIterable, Identifiable {
    case heading1 = "h1"
    case heading2 = "h2"
    case heading3 = "h3"
    
    public var id: String { rawValue }
    
    /// The font size used when this heading style is applied.
    public var fontSize: CGFloat {
        switch self {
        case .heading1:
            return 28
        case .heading2:
            return 22
        case .heading3:
            return 18
        }
    }
    
    /// Human-readable name shown in menus.
    public var displayName: String {
        switch self {
        case .heading1: 
            return "Heading 1"
        case .heading2:
            return "Heading 2"
        case .heading3:
            return "Heading 3"
        }
    }
    
    /// The HTML tag used on export.
    public var htmlTag: String { rawValue }
}

// MARK: - Custom NSAttributedString Key

extension NSAttributedString.Key {
    /// Paragraph-level attribute storing the raw value of `EditorHeadingStyle`.
    static let swiftyEditorHeadingStyle: NSAttributedString.Key = NSAttributedString.Key("SwiftyEditor.headingStyle")
}
