import SwiftUI
import UIKit

/// `UIViewRepresentable` wrapper for `UITextView` that powers the rich text editing surface.
struct EditorTextView: UIViewRepresentable {

    @Environment(\.editorTheme) private var theme

    let context: EditorContext
    let configuration: EditorConfiguration

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> EditorCoordinator {
        EditorCoordinator(context: context, configuration: configuration)
    }

    func makeUIView(context representableContext: Context) -> UITextView {
        let textView = ScribeTextView()
        textView.context = context
        textView.configuration = configuration
        textView.delegate = representableContext.coordinator
        textView.isEditable = configuration.isEditable
        textView.isScrollEnabled = true
        textView.backgroundColor = UIColor(theme.editorBackgroundColor)
        textView.textColor = UIColor(theme.editorTextColor)
        textView.font = theme.editorFont
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)

        // RTL support: let auto layout and system locale drive text direction
        textView.semanticContentAttribute = .unspecified

        // Placeholder label (UITextView has no built-in placeholder)
        let placeholderLabel = UILabel()
        placeholderLabel.text = configuration.placeholder
        placeholderLabel.font = theme.editorFont
        placeholderLabel.textColor = UIColor.placeholderText
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)

        let insets = textView.textContainerInset
        let lineFragmentPadding = textView.textContainer.lineFragmentPadding
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: insets.top),
            placeholderLabel.leadingAnchor.constraint(
                equalTo: textView.leadingAnchor, constant: insets.left + lineFragmentPadding),
            placeholderLabel.trailingAnchor.constraint(
                equalTo: textView.trailingAnchor, constant: -(insets.right + lineFragmentPadding))
        ])

        placeholderLabel.isHidden = !textView.textStorage.string.isEmpty

        // Store references in context so programmatic edits can sync the placeholder directly
        context.textView = textView
        context.coordinator = representableContext.coordinator

        // Store coordinator reference so it can toggle the placeholder from delegate callbacks
        representableContext.coordinator.placeholderLabel = placeholderLabel

        return textView
    }

    func updateUIView(_ uiView: UITextView, context representableContext: Context) {
        // Sync config/theme changes at runtime
        (uiView as? ScribeTextView)?.configuration = configuration
        if uiView.isEditable != configuration.isEditable {
            uiView.isEditable = configuration.isEditable
        }
        let targetBg = UIColor(theme.editorBackgroundColor)
        if uiView.backgroundColor != targetBg {
            uiView.backgroundColor = targetBg
        }
        let targetText = UIColor(theme.editorTextColor)
        if uiView.textColor != targetText {
            uiView.textColor = targetText
        }
        if uiView.font != theme.editorFont {
            uiView.font = theme.editorFont
        }

        // Sync placeholder visibility.
        // We read context.characterCount to register it as a SwiftUI dependency:
        // any programmatic content change (setContent, commitLink, commitImage)
        // updates characterCount via syncState(), which triggers updateUIView here.
        // The actual isEmpty check uses the UITextView's storage directly for accuracy.
        _ = context.characterCount  // register dependency
        representableContext.coordinator.placeholderLabel?.isHidden = !uiView.textStorage.string.isEmpty
    }
}
