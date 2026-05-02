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

    /// Returns the text marker for a given index, optionally using Arabic-Indic numerals (U+0660–U+0669).
    /// For `.bullet` and `.dash`, `useArabicNumerals` is ignored.
    /// - Parameters:
    ///   - index: The 1-based position of the list item.
    ///   - useArabicNumerals: When `true` and the style is `.numbered`, returns e.g. `"١. "`.
    public func marker(forIndex index: Int, useArabicNumerals: Bool) -> String {
        guard case .numbered = self, useArabicNumerals else {
            return marker(forIndex: index)
        }
        return "\(EditorListStyle.toArabicIndicDigits(index)). "
    }

    /// Converts a positive integer to its Arabic-Indic numeral representation (U+0660–U+0669).
    private static func toArabicIndicDigits(_ number: Int) -> String {
        String(number).map { ch -> Character in
            let d = ch.wholeNumberValue ?? 0
            return Character(UnicodeScalar(0x0660 + UInt32(d))!)
        }.map(String.init).joined()
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
