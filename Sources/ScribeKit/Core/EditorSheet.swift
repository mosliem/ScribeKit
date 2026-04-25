import Foundation

/// Identifies which sheet is currently being presented by the editor.
/// Using a single enum + `.sheet(item:)` avoids multiple boolean flags.
public enum EditorSheet: Identifiable, Sendable {
    case link(existingURL: String, existingText: String)
    case imagePicker

    public var id: String {
        switch self {
        case .link: 
            return "link"
        case .imagePicker:
            return "imagePicker"
        }
    }
}
