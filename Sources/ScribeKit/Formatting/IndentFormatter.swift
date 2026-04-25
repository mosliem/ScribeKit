import UIKit

/// Increases and decreases paragraph indentation in fixed steps.
/// Operates independently of list indentation managed by `ListFormatter`.
@MainActor
public struct IndentFormatter {
    
    public static let indentStep: CGFloat = 25
    public static let maxIndent: CGFloat = 250
    
    // MARK: - Public API
    
    /// Increases indentation by one step for all paragraphs in the selection.
    public static func increaseIndent(in textView: UITextView) {
        applyIndentDelta(indentStep, in: textView)
    }
    
    /// Decreases indentation by one step (floor: 0) for all paragraphs in the selection.
    public static func decreaseIndent(in textView: UITextView) {
        applyIndentDelta(-indentStep, in: textView)
    }
    
    /// Returns the current indent level (number of steps) at the cursor.
    public static func currentIndentLevel(in textView: UITextView) -> Int {
        let storage = textView.textStorage
        guard storage.length > 0 else { return 0 }
        let location = min(textView.selectedRange.location, storage.length - 1)
        let paraStyle =
        storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
        let indent = paraStyle?.headIndent ?? 0
        return Int(indent / indentStep)
    }
    
    // MARK: - Private
    
    private static func applyIndentDelta(_ delta: CGFloat, in textView: UITextView) {
        let storage = textView.textStorage
        let selectedRange = textView.selectedRange
        let paragraphRange = (storage.string as NSString).paragraphRange(for: selectedRange)
        
        storage.beginEditing()
        storage.enumerateAttribute(.paragraphStyle, in: paragraphRange, options: []) {
            value, range, _ in
            let existing =
            (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
            ?? NSMutableParagraphStyle()
            existing.headIndent = max(0, min(maxIndent, existing.headIndent + delta))
            existing.firstLineHeadIndent = max(0, min(maxIndent, existing.firstLineHeadIndent + delta))
            storage.addAttribute(.paragraphStyle, value: existing, range: range)
        }
        storage.endEditing()
    }
}
