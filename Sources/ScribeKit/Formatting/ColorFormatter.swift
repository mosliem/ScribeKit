import UIKit

/// Applies and detects foreground (text) and background (highlight) colors.
@MainActor
public struct ColorFormatter {
    
    // MARK: - Foreground Color
    
    /// Sets the foreground (text) color at the current selection or typing position.
    public static func setForegroundColor(_ color: UIColor, in textView: UITextView) {
        let selectedRange = textView.selectedRange
        if selectedRange.length == 0 {
            textView.typingAttributes[.foregroundColor] = color
        } else {
            textView.textStorage.beginEditing()
            textView.textStorage.addAttribute(.foregroundColor, value: color, range: selectedRange)
            textView.textStorage.endEditing()
        }
    }

    /// Removes the foreground (text) color at the current selection or typing position,
    /// reverting to the default label color.
    public static func removeForegroundColor(in textView: UITextView) {
        let selectedRange = textView.selectedRange
        if selectedRange.length == 0 {
            textView.typingAttributes.removeValue(forKey: .foregroundColor)
        } else {
            textView.textStorage.beginEditing()
            textView.textStorage.removeAttribute(.foregroundColor, range: selectedRange)
            textView.textStorage.endEditing()
        }
    }
    
    /// Returns the foreground color at the cursor or start of selection, or `nil` if none is set.
    /// Returns `nil` when the run's color comes from a link (avoids reporting link blue as text color).
    public static func currentForegroundColor(in textView: UITextView) -> UIColor? {
        let storage = textView.textStorage
        if textView.selectedRange.length == 0 {
            // Check for link in typing attributes — link color is not a user-chosen text color
            guard textView.typingAttributes[.link] == nil else { return nil }
            return textView.typingAttributes[.foregroundColor] as? UIColor
        }
        guard storage.length > 0 else { return nil }
        let location = min(textView.selectedRange.location, storage.length - 1)
        guard storage.attribute(.link, at: location, effectiveRange: nil) == nil else { return nil }
        return storage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? UIColor
    }
    
    // MARK: - Background / Highlight Color
    
    /// Sets the background (highlight) color at the current selection or typing position.
    /// Pass `nil` to remove the highlight.
    public static func setBackgroundColor(_ color: UIColor?, in textView: UITextView) {
        let selectedRange = textView.selectedRange
        if selectedRange.length == 0 {
            if let color {
                textView.typingAttributes[.backgroundColor] = color
            } else {
                textView.typingAttributes.removeValue(forKey: .backgroundColor)
            }
        } else {
            textView.textStorage.beginEditing()
            if let color {
                textView.textStorage.addAttribute(.backgroundColor, value: color, range: selectedRange)
            } else {
                textView.textStorage.removeAttribute(.backgroundColor, range: selectedRange)
            }
            textView.textStorage.endEditing()
        }
    }
    
    /// Returns the background/highlight color at the cursor or start of selection, or `nil` if none.
    public static func currentBackgroundColor(in textView: UITextView) -> UIColor? {
        let storage = textView.textStorage
        if textView.selectedRange.length == 0 {
            return textView.typingAttributes[.backgroundColor] as? UIColor
        }
        guard storage.length > 0 else { return nil }
        let location = min(textView.selectedRange.location, storage.length - 1)
        return storage.attribute(.backgroundColor, at: location, effectiveRange: nil) as? UIColor
    }
}
