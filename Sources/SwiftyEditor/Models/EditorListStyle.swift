import Foundation

/// List style supported by the editor. Named `EditorListStyle` to avoid conflict with `SwiftUI.ListStyle`.
public enum EditorListStyle: String, Hashable, Sendable, CaseIterable, Identifiable {
    case bullet
    case numbered
    case dash
    
    public var id: String { rawValue }
    
    /// Returns the text marker for a given index (1-based).
    /// - Parameter index: The 1-based position of the list item.
    /// - Returns: A string marker such as `• `, `1. `, or `- `.
    public func marker(forIndex index: Int) -> String {
        switch self {
        case .bullet:
            return "• "
        case .numbered:
            return "\(index). "
        case .dash:
            return "- "
        }
    }
    
    /// The SF Symbol name used in the toolbar.
    public var symbolName: String {
        switch self {
        case .bullet:
            return "list.bullet"
        case .numbered:
            return "list.number"
        case .dash:
            return "list.dash"
        }
    }
}
