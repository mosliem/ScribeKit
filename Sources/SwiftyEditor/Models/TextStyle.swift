import Foundation

/// Text formatting styles supported by the editor.
public enum TextStyle: String, Hashable, Sendable, CaseIterable {
    case bold
    case italic
    case underline
    case strikethrough
}
