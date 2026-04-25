import UIKit

/// `UITextView` subclass that adds paste-mode control.
/// Also serves as the extension point for Feature 9 (keyboard shortcuts).
final class ScribeTextView: UITextView {

    weak var context: EditorContext?
    var configuration: EditorConfiguration = .default

    // MARK: - Paste overrides

    override func paste(_ sender: Any?) {
        switch configuration.pasteMode {
        case .rich, .userChoice:
            super.paste(sender)
        case .plainText:
            insertPlainTextFromPasteboard()
        }
    }

    /// System "Paste and Match Style" action — always strips formatting.
    override func pasteAndMatchStyle(_ sender: Any?) {
        insertPlainTextFromPasteboard()
    }

    // MARK: - canPerformAction

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if configuration.pasteMode == .userChoice {
            // Hide system Paste and Paste and Match Style;
            // EditorCoordinator injects "Paste" and "Paste as Plain Text" UIActions instead.
            if action == #selector(paste(_:)) || action == #selector(pasteAndMatchStyle(_:)) {
                return false
            }
        }
        return super.canPerformAction(action, withSender: sender)
    }

    // MARK: - Menu action targets (called by EditorCoordinator-injected UIActions)

    func pasteRich() {
        super.paste(nil)
    }

    func pastePlain() {
        insertPlainTextFromPasteboard()
    }

    // MARK: - Private

    private func insertPlainTextFromPasteboard() {
        guard let string = UIPasteboard.general.string else {
            super.paste(nil)
            return
        }
        let plain = NSAttributedString(string: string, attributes: typingAttributes)
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: selectedRange, with: plain)
        textStorage.endEditing()
        selectedRange = NSRange(location: selectedRange.location + plain.length, length: 0)
        context?.syncState()
    }
}
