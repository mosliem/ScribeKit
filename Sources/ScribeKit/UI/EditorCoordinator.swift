import UIKit
import SwiftUI

/// `@MainActor` UITextViewDelegate for the editor.
/// Marked `@MainActor` so delegate methods call `context.syncState()` directly,
/// without a `Task { @MainActor in }` wrapper that would introduce a one-frame lag.
@MainActor
final class EditorCoordinator: NSObject, UITextViewDelegate {
    
    let context: EditorContext
    let configuration: EditorConfiguration

    /// Reflects whether the text view is currently the first responder.
    /// Updated on every begin/end editing delegate callback.
    @Binding var isFocused: Bool

    /// Cleared to `""` as soon as the user makes any text change.
    @Binding var errorMessage: String

    /// Placeholder label managed by EditorTextView; toggled on content changes.
    weak var placeholderLabel: UILabel?

    /// Tracks the last `isFocused` value we acted on so `updateUIView` only dispatches a
    /// first-responder change when the desired focus state actually changes — not on every
    /// SwiftUI re-render triggered by typing.
    var lastRequestedFocus: Bool = false

    init(
        context: EditorContext,
        configuration: EditorConfiguration,
        isFocused: Binding<Bool>,
        errorMessage: Binding<String>
    ) {
        self.context = context
        self.configuration = configuration
        self._isFocused = isFocused
        self._errorMessage = errorMessage
    }
    
    // MARK: - UITextViewDelegate
    
    func textViewDidChange(_ textView: UITextView) {
        if !errorMessage.isEmpty {
            errorMessage = ""
        }
        context.syncState()
        syncPlaceholder(for: textView)
    }
    
    // Called when cursor appears (tap into editor) — syncs placeholder without waiting for typing
    func textViewDidBeginEditing(_ textView: UITextView) {
        isFocused = true
        syncPlaceholder(for: textView)
    }

    // Called when keyboard is dismissed — ensures placeholder is visible if content was cleared
    func textViewDidEndEditing(_ textView: UITextView) {
        isFocused = false
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
        let pasteRich = UIAction(title: .localized("paste.rich")) { _ in scribeView.pasteRich() }
        let pastePlain = UIAction(title: .localized("paste.plain")) { _ in scribeView.pastePlain() }
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
