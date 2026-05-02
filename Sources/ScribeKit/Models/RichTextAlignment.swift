import UIKit

/// RTL-aware text alignment for the editor.
public enum RichTextAlignment: String, Hashable, Sendable, CaseIterable {
    case leading
    case center
    case trailing

    /// Maps to `NSTextAlignment` using the provided layout direction for RTL awareness.
    /// - Parameter layoutDirection: The effective layout direction of the text view.
    /// - Returns: The corresponding `NSTextAlignment`.
    public func toNSTextAlignment(layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight)
    -> NSTextAlignment {
        switch self {
        case .leading:
            // Use an explicit alignment so the paragraph always snaps to the UI leading edge,
            // regardless of the text's own writing direction.
            // `.natural` would instead follow the *content's* base direction — so English text in
            // an Arabic (RTL) app aligns LEFT (its natural direction) rather than RIGHT (the actual
            // leading edge), and Arabic text in an English (LTR) app aligns RIGHT instead of LEFT.
            return layoutDirection == .rightToLeft ? .right : .left
        case .center:
            return .center
        case .trailing:
            // In RTL, "trailing" visually means left; in LTR, it means right.
            return layoutDirection == .rightToLeft ? .left : .right
        }
    }

    /// Initialises from an `NSTextAlignment`, using layout direction for trailing disambiguation.
    ///
    /// **Important**: Always supply the correct `layoutDirection` when round-tripping in RTL locales.
    /// Without layout direction context, `.left` is ambiguous (could mean trailing in RTL or explicit-left).
    /// - Parameters:
    ///   - nsAlignment: The raw `NSTextAlignment` value.
    ///   - layoutDirection: The effective layout direction of the text view.
    public init(
        nsAlignment: NSTextAlignment,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    ) {
        switch nsAlignment {
        case .center:
            self = .center
        case .right:
            self = layoutDirection == .rightToLeft ? .leading : .trailing
        case .left:
            self = layoutDirection == .rightToLeft ? .trailing : .leading
        case .natural:
            self = .leading
        case .justified:
            // Note: `RichTextAlignment` has no `.justified` case by design.
            // Content with `text-align: justify` will be imported as `.leading`.
            // Re-exporting such content will lose justification alignment.
            self = .leading
        @unknown default:
            self = .leading
        }
    }
}
