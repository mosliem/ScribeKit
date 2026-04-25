import UIKit

/// Handles link insertion, detection, editing, and removal.
@MainActor
public struct LinkFormatter {
    
    // MARK: - Insert / Edit
    
    /// Inserts (or replaces) a hyperlink at the current selection.
    /// - Parameters:
    ///   - url: The URL string for the link.
    ///   - displayText: The text to display. If empty, the URL itself is used.
    ///   - textView: The target text view.
    public static func insertLink(url: String, displayText: String, in textView: UITextView) {
        guard !url.isEmpty else { return }
        let text = displayText.isEmpty ? url : displayText
        let selectedRange = textView.selectedRange
        
        let attrs: [NSAttributedString.Key: Any] = [
            .link: url,
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let linked = NSAttributedString(string: text, attributes: attrs)
        
        textView.textStorage.beginEditing()
        if selectedRange.length > 0 {
            textView.textStorage.replaceCharacters(in: selectedRange, with: linked)
        } else {
            textView.textStorage.insert(linked, at: selectedRange.location)
        }
        textView.textStorage.endEditing()
        
        // Move cursor past the inserted link
        textView.selectedRange = NSRange(location: selectedRange.location + text.utf16.count, length: 0)
    }
    
    // MARK: - Detect
    
    /// Returns the URL string of the link at the cursor position, or `nil` if not on a link.
    public static func currentLink(in textView: UITextView) -> String? {
        let storage = textView.textStorage
        guard storage.length > 0 else { return nil }
        let location = min(textView.selectedRange.location, storage.length - 1)
        let value = storage.attribute(.link, at: location, effectiveRange: nil)
        if let url = value as? URL { return url.absoluteString }
        if let str = value as? String { return str }
        return nil
    }
    
    /// Returns the display text of the link at the cursor position.
    public static func currentLinkText(in textView: UITextView) -> String {
        let storage = textView.textStorage
        guard storage.length > 0 else { return "" }
        let location = min(textView.selectedRange.location, storage.length - 1)
        var effectiveRange = NSRange()
        let value = storage.attribute(.link, at: location, effectiveRange: &effectiveRange)
        guard value != nil else { return "" }
        return (storage.string as NSString).substring(with: effectiveRange)
    }
    
    // MARK: - Remove
    
    /// Removes the hyperlink attribute from the effective range at the cursor.
    public static func removeLink(in textView: UITextView) {
        let storage = textView.textStorage
        guard storage.length > 0 else { return }
        let location = min(textView.selectedRange.location, storage.length - 1)
        var effectiveRange = NSRange(location: location, length: 0)
        guard storage.attribute(.link, at: location, effectiveRange: &effectiveRange) != nil else {
            return
        }
        
        storage.beginEditing()
        storage.removeAttribute(.link, range: effectiveRange)
        storage.removeAttribute(.underlineStyle, range: effectiveRange)
        // Restore default text colour
        storage.removeAttribute(.foregroundColor, range: effectiveRange)
        storage.endEditing()
    }
}
