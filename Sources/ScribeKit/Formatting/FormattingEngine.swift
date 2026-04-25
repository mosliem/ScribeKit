import UIKit

/// Stateless struct providing pure formatting operations on `NSTextStorage` / `NSMutableAttributedString`.
/// All methods are static so this type is fully unit-testable without a UITextView.
@MainActor
public struct FormattingEngine {
    
    // MARK: - Style Toggle
    
    /// Toggles a `TextStyle` on the given text view.
    /// - If the selection is empty, toggles `typingAttributes` so the next character inherits the style.
    /// - If text is selected, applies or removes the attribute over the entire selection.
    public static func toggleStyle(_ style: TextStyle, in textView: UITextView) {
        let storage = textView.textStorage
        let selectedRange = textView.selectedRange
        
        if selectedRange.length == 0 {
            // No selection — toggle typingAttributes for next character
            var attrs = textView.typingAttributes
            applyToggle(style: style, to: &attrs, storage: storage, at: selectedRange.location)
            textView.typingAttributes = attrs
        } else {
            storage.beginEditing()
            let isActive = isStyleActive(style, in: storage, range: selectedRange)
            applyStyle(style, isRemoving: isActive, to: storage, range: selectedRange)
            storage.endEditing()
        }
    }
    
    /// Checks whether a style is consistently active across the entire range.
    public static func isStyleActive(
        _ style: TextStyle, in storage: NSAttributedString, range: NSRange
    ) -> Bool {
        if range.length == 0 {
            let location = max(0, min(range.location, storage.length - 1))
            guard storage.length > 0 else { return false }
            return checkStyle(style, in: storage.attributes(at: location, effectiveRange: nil))
        }
        
        var isActive = true
        storage.enumerateAttributes(in: range, options: []) { attrs, _, stop in
            if !checkStyle(style, in: attrs) {
                isActive = false
                stop.pointee = true
            }
        }
        return isActive
    }
    
    // MARK: - Alignment
    
    /// Sets the paragraph alignment for all paragraphs overlapping `range`.
    public static func setAlignment(_ alignment: RichTextAlignment, in textView: UITextView) {
        let storage = textView.textStorage
        let selectedRange = textView.selectedRange
        let nsAlignment = alignment.toNSTextAlignment(
            layoutDirection: textView.effectiveUserInterfaceLayoutDirection)
        
        storage.beginEditing()
        let paragraphRange = (storage.string as NSString).paragraphRange(for: selectedRange)
        storage.enumerateAttribute(.paragraphStyle, in: paragraphRange, options: []) {
            value, range, _ in
            let style =
            (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
            ?? NSMutableParagraphStyle()
            style.alignment = nsAlignment
            storage.addAttribute(.paragraphStyle, value: style, range: range)
        }
        storage.endEditing()
    }
    
    /// Detects the alignment at the cursor / start of the selection.
    public static func currentAlignment(in textView: UITextView) -> RichTextAlignment {
        let storage = textView.textStorage
        guard storage.length > 0 else { return .leading }
        let location = min(textView.selectedRange.location, storage.length - 1)
        let attrs = storage.attributes(at: location, effectiveRange: nil)
        let nsAlignment = (attrs[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? .natural
        return RichTextAlignment(nsAlignment: nsAlignment, layoutDirection: textView.effectiveUserInterfaceLayoutDirection)
    }
    
    /// Returns the active text styles at the cursor / in the selection.
    public static func activeStyles(in textView: UITextView) -> Set<TextStyle> {
        let storage = textView.textStorage
        let range = textView.selectedRange
        
        if range.length == 0 {
            // Use typingAttributes when cursor is placed
            let attrs = textView.typingAttributes
            return Set(TextStyle.allCases.filter { checkStyle($0, in: attrs) })
        }
        
        var styles = Set(TextStyle.allCases)
        storage.enumerateAttributes(in: range, options: []) { attrs, _, _ in
            styles = styles.filter { checkStyle($0, in: attrs) }
        }
        return styles
    }
    
    // MARK: - Font Size
    
    private static let minFontSize: CGFloat = 8
    private static let maxFontSize: CGFloat = 96
    
    /// Adjusts font size by `delta` points, clamped to [8, 96].
    /// Affects `typingAttributes` when there is no selection, or all runs in the selection.
    public static func adjustFontSize(by delta: CGFloat, in textView: UITextView) {
        let selectedRange = textView.selectedRange
        if selectedRange.length == 0 {
            var attrs = textView.typingAttributes
            let font = attrs[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
            let newSize = max(minFontSize, min(maxFontSize, font.pointSize + delta))
            attrs[.font] = UIFont(descriptor: font.fontDescriptor, size: newSize)
            textView.typingAttributes = attrs
        } else {
            textView.textStorage.beginEditing()
            textView.textStorage.enumerateAttribute(.font, in: selectedRange, options: []) {
                value, range, _ in
                let font = value as? UIFont ?? UIFont.systemFont(ofSize: 16)
                let newSize = max(minFontSize, min(maxFontSize, font.pointSize + delta))
                textView.textStorage.addAttribute(
                    .font,
                    value: UIFont(descriptor: font.fontDescriptor, size: newSize),
                    range: range
                )
            }
            textView.textStorage.endEditing()
        }
    }
    
    /// Returns the font size at the cursor or start of the selection.
    public static func currentFontSize(in textView: UITextView) -> CGFloat {
        if textView.selectedRange.length == 0 {
            return (textView.typingAttributes[.font] as? UIFont)?.pointSize ?? 16
        }
        let storage = textView.textStorage
        guard storage.length > 0 else { return 16 }
        let location = min(textView.selectedRange.location, storage.length - 1)
        return (storage.attribute(.font, at: location, effectiveRange: nil) as? UIFont)?.pointSize ?? 16
    }
    
    // MARK: - Private Helpers
    
    private static func checkStyle(_ style: TextStyle, in attrs: [NSAttributedString.Key: Any])
    -> Bool {
        switch style {
        case .bold:
            guard let font = attrs[.font] as? UIFont else { return false }
            return font.fontDescriptor.symbolicTraits.contains(.traitBold)
        case .italic:
            guard let font = attrs[.font] as? UIFont else { return false }
            return font.fontDescriptor.symbolicTraits.contains(.traitItalic)
        case .underline:
            let value = attrs[.underlineStyle] as? Int ?? 0
            return value != 0
        case .strikethrough:
            let value = attrs[.strikethroughStyle] as? Int ?? 0
            return value != 0
        }
    }
    
    private static func applyToggle(
        style: TextStyle,
        to attrs: inout [NSAttributedString.Key: Any],
        storage: NSAttributedString,
        at location: Int
    ) {
        let isActive = checkStyle(style, in: attrs)
        switch style {
        case .bold, .italic:
            let currentFont = attrs[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
            attrs[.font] = toggleFontTrait(for: style, font: currentFont, removing: isActive)
        case .underline:
            attrs[.underlineStyle] = isActive ? 0 : NSUnderlineStyle.single.rawValue
        case .strikethrough:
            // Note: iOS uses NSUnderlineStyle for both underline and strikethrough values.
            // The attribute *key* (.strikethroughStyle vs .underlineStyle) differentiates them.
            attrs[.strikethroughStyle] = isActive ? 0 : NSUnderlineStyle.single.rawValue
        }
    }
    
    private static func applyStyle(
        _ style: TextStyle,
        isRemoving: Bool,
        to storage: NSMutableAttributedString,
        range: NSRange
    ) {
        switch style {
        case .bold, .italic:
            storage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                let font = value as? UIFont ?? UIFont.systemFont(ofSize: 16)
                let newFont = toggleFontTrait(for: style, font: font, removing: isRemoving)
                storage.addAttribute(.font, value: newFont, range: subRange)
            }
        case .underline:
            if isRemoving {
                storage.removeAttribute(.underlineStyle, range: range)
            } else {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        case .strikethrough:
            if isRemoving {
                storage.removeAttribute(.strikethroughStyle, range: range)
            } else {
                // Note: iOS uses NSUnderlineStyle for both underline and strikethrough values.
                storage.addAttribute(
                    .strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
    }
    
    private static func toggleFontTrait(for style: TextStyle, font: UIFont, removing: Bool) -> UIFont {
        let trait: UIFontDescriptor.SymbolicTraits = style == .bold ? .traitBold : .traitItalic
        var traits = font.fontDescriptor.symbolicTraits
        if removing { traits.remove(trait) } else { traits.insert(trait) }
        let descriptor = font.fontDescriptor.withSymbolicTraits(traits) ?? font.fontDescriptor
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}
