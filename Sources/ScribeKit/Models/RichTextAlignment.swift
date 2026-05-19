import UIKit

/// Absolute paragraph alignment.
///
/// Buttons map to fixed visual positions (left/center/right) regardless of the
/// app's UI direction or the paragraph's writing direction. Mirroring is the
/// caller's responsibility — the editor never silently swaps sides.
public enum RichTextAlignment: String, Hashable, Sendable, CaseIterable {
    case left
    case center
    case right

    /// Maps to the matching `NSTextAlignment`.
    public func toNSTextAlignment() -> NSTextAlignment {
        switch self {
        case .left:   return .left
        case .center: return .center
        case .right:  return .right
        }
    }

    /// Initialises from an `NSTextAlignment`. `.natural` and `.justified` collapse to `.left`
    /// because the toolbar only exposes three absolute buttons.
    public init(nsAlignment: NSTextAlignment) {
        switch nsAlignment {
        case .center:    self = .center
        case .right:     self = .right
        case .left:      self = .left
        case .natural:   self = .left
        case .justified: self = .left
        @unknown default: self = .left
        }
    }
}
