import UIKit

/// `@MainActor` UITextViewDelegate for the editor.
/// Marked `@MainActor` so delegate methods call `context.syncState()` directly,
/// without a `Task { @MainActor in }` wrapper that would introduce a one-frame lag.
@MainActor
final class EditorCoordinator: NSObject, UITextViewDelegate {
    
    let context: EditorContext
    let configuration: EditorConfiguration
    
    /// Placeholder label managed by EditorTextView; toggled on content changes.
    weak var placeholderLabel: UILabel?
    
    init(context: EditorContext, configuration: EditorConfiguration) {
        self.context = context
        self.configuration = configuration
    }
    
    // MARK: - UITextViewDelegate
    
    func textViewDidChange(_ textView: UITextView) {
        context.syncState()
        syncPlaceholder(for: textView)
    }
    
    // Called when cursor appears (tap into editor) — syncs placeholder without waiting for typing
    func textViewDidBeginEditing(_ textView: UITextView) {
        syncPlaceholder(for: textView)
    }
    
    // Called when keyboard is dismissed — ensures placeholder is visible if content was cleared
    func textViewDidEndEditing(_ textView: UITextView) {
        syncPlaceholder(for: textView)
    }
    
    func syncPlaceholder(for textView: UITextView) {
        placeholderLabel?.isHidden = !textView.textStorage.string.isEmpty
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        context.syncState()
    }

    func textView(
        _ textView: UITextView,
        editMenuForTextIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        guard let scribeView = textView as? ScribeTextView,
              scribeView.configuration.pasteMode == .userChoice else {
            return UIMenu(children: suggestedActions)
        }
        let pasteRich = UIAction(title: "Paste") { _ in scribeView.pasteRich() }
        let pastePlain = UIAction(title: "Paste as Plain Text") { _ in scribeView.pastePlain() }
        return UIMenu(children: suggestedActions + [pasteRich, pastePlain])
    }
    
    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        // Max length enforcement (uses Swift Character count, not UTF-16 units,
        // so emoji and extended scripts count as 1 character each)
        if configuration.maxLength > 0 {
            let currentText = textView.textStorage.string
            let currentCount = currentText.count
            let replacementCount = text.count
            // If NSRange can't map to Swift Range (crosses a character cluster boundary), reject
            guard let replacedRange = Range(range, in: currentText) else { return false }
            let replacedCount = currentText[replacedRange].count
            let delta = replacementCount - replacedCount
            if currentCount + delta > configuration.maxLength { return false }
        }
        
        // List auto-continuation / exit on Enter
        if text == "\n" {
            if ListFormatter.handleEnter(in: textView) {
                return false  // ListFormatter handled the newline
            }
        }
        
        return true
    }
}
