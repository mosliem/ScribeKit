import UIKit

/// Applies, detects, and removes heading styles on paragraphs.
/// Mirrors the list-style pattern: stores the style via a custom `NSAttributedString.Key`
/// at paragraph level and adjusts the font size + bold trait.
@MainActor
public struct HeadingFormatter {
    
    /// The default body font size used when reverting a heading to body text.
    public static let defaultBodySize: CGFloat = 16
    
    // MARK: - Apply / Remove
    
    /// Sets the heading style for all paragraphs overlapping the current selection.
    /// Pass `nil` to revert to body text.
    public static func setHeading(_ style: EditorHeadingStyle?, in textView: UITextView) {
        let storage = textView.textStorage
        let selectedRange = textView.selectedRange
        let paragraphRange = (storage.string as NSString).paragraphRange(for: selectedRange)
        
        storage.beginEditing()
        
        if let style {
            // Apply heading: bold + heading font size + custom attribute
            storage.enumerateAttribute(.font, in: paragraphRange, options: []) { value, range, _ in
                let base = value as? UIFont ?? UIFont.systemFont(ofSize: defaultBodySize)
                let headingFont = fontByApplyingHeadingSize(style.fontSize, to: base, addingBold: true)
                storage.addAttribute(.font, value: headingFont, range: range)
            }
            storage.addAttribute(.swiftyEditorHeadingStyle, value: style.rawValue, range: paragraphRange)
        } else {
            // Revert to body: restore default size, remove heading attribute.
            // Bold trait applied by the user remains; only the size is reset.
            storage.enumerateAttribute(.font, in: paragraphRange, options: []) { value, range, _ in
                let base = value as? UIFont ?? UIFont.systemFont(ofSize: defaultBodySize)
                let bodyFont = UIFont(descriptor: base.fontDescriptor, size: defaultBodySize)
                storage.addAttribute(.font, value: bodyFont, range: range)
            }
            storage.removeAttribute(.swiftyEditorHeadingStyle, range: paragraphRange)
        }
        
        storage.endEditing()
    }
    
    // MARK: - Detection
    
    /// Returns the heading style of the paragraph at the cursor, or `nil` if body text.
    public static func detectHeadingStyle(in textView: UITextView) -> EditorHeadingStyle? {
        let storage = textView.textStorage
        guard storage.length > 0 else { return nil }
        let location = min(textView.selectedRange.location, storage.length - 1)
        let value =
        storage.attribute(.swiftyEditorHeadingStyle, at: location, effectiveRange: nil) as? String
        return value.flatMap { EditorHeadingStyle(rawValue: $0) }
    }
    
    // MARK: - Internal Helper (used by HTMLImporter)
    
    /// Applies heading font size + bold to all runs in `range` within the given attributed string.
    static func applyHeadingFont(
        _ style: EditorHeadingStyle, to attrStr: NSMutableAttributedString, in range: NSRange
    ) {
        attrStr.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let base = value as? UIFont ?? UIFont.systemFont(ofSize: defaultBodySize)
            let headingFont = fontByApplyingHeadingSize(style.fontSize, to: base, addingBold: true)
            attrStr.addAttribute(.font, value: headingFont, range: subRange)
        }
    }
    
    // MARK: - Private
    
    private static func fontByApplyingHeadingSize(_ size: CGFloat, to font: UIFont, addingBold: Bool)
    -> UIFont {
        var traits = font.fontDescriptor.symbolicTraits
        if addingBold { traits.insert(.traitBold) }
        let descriptor = font.fontDescriptor.withSymbolicTraits(traits) ?? font.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }
}
