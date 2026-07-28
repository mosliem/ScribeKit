import SwiftUI
import UIKit

/// `UIViewRepresentable` wrapper for `UITextView` that powers the rich text editing surface.
struct EditorTextView: UIViewRepresentable {

    @Environment(\.editorTheme) private var theme
    /// SwiftUI's layout direction. Note: this is not reliably propagated into a
    /// `UIViewRepresentable`, so it's only a fallback — `resolvedIsRTL(for:)` primarily uses
    /// the text view's own `effectiveUserInterfaceLayoutDirection`.
    @Environment(\.layoutDirection) private var layoutDirection

    let context: EditorContext

    /// Resolves whether the editor should lay out right-to-left. The text view sets
    /// `semanticContentAttribute = .unspecified`, so its `effectiveUserInterfaceLayoutDirection`
    /// resolves against the real (UIKit) RTL context — reliable where SwiftUI's `layoutDirection`
    /// environment is not inside a representable. The SwiftUI value is kept as a fallback for
    /// apps that force RTL purely via `.environment(\.layoutDirection, .rightToLeft)`.
    private func resolvedIsRTL(for view: UIView) -> Bool {
        view.effectiveUserInterfaceLayoutDirection == .rightToLeft
            || layoutDirection == .rightToLeft
            || UIView.userInterfaceLayoutDirection(for: .unspecified) == .rightToLeft
    }
    let configuration: EditorConfiguration
    /// Two-way binding kept in sync with the text view's first-responder state.
    @Binding var isFocused: Bool
    /// Cleared to `""` when the user makes any text change.
    @Binding var errorMessage: String

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> EditorCoordinator {
        EditorCoordinator(
            context: context,
            configuration: configuration,
            isFocused: $isFocused,
            errorMessage: $errorMessage
        )
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
        // Align the placeholder to match the host app's writing direction (see resolvedIsRTL).
        placeholderLabel.textAlignment = resolvedIsRTL(for: textView) ? .right : .left
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)

        let insets = textView.textContainerInset
        let lineFragmentPadding = textView.textContainer.lineFragmentPadding
        // Pin to the scroll view's frameLayoutGuide with ABSOLUTE left/right anchors so the label
        // is always full width and stays put under RTL. Leading/trailing anchors flip with
        // semanticContentAttribute — which SwiftUI mutates to forceRightToLeft AFTER makeUIView —
        // which previously left the label content-width-sized on the wrong (left) edge. The text
        // direction itself is handled by textAlignment (see resolvedIsRTL).
        let guide = textView.frameLayoutGuide
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: insets.top),
            placeholderLabel.leftAnchor.constraint(
                equalTo: guide.leftAnchor, constant: insets.left + lineFragmentPadding),
            placeholderLabel.rightAnchor.constraint(
                equalTo: guide.rightAnchor, constant: -(insets.right + lineFragmentPadding))
        ])

        placeholderLabel.isHidden = !textView.textStorage.string.isEmpty

        // Store references in context so programmatic edits can sync the placeholder directly
        context.textView = textView
        context.coordinator = representableContext.coordinator
        context.htmlDebounceInterval = configuration.htmlDebounceInterval
        context.wrapsEmptyContentInTags = configuration.wrapsEmptyContentInTags

        // Store coordinator reference so it can toggle the placeholder from delegate callbacks
        representableContext.coordinator.placeholderLabel = placeholderLabel

        syncKeyboardDoneButton(on: textView, coordinator: representableContext.coordinator)

        return textView
    }

    func updateUIView(_ uiView: UITextView, context representableContext: Context) {
        // Sync config/theme changes at runtime
        (uiView as? ScribeTextView)?.configuration = configuration
        context.htmlDebounceInterval = configuration.htmlDebounceInterval
        context.wrapsEmptyContentInTags = configuration.wrapsEmptyContentInTags
        syncKeyboardDoneButton(on: uiView, coordinator: representableContext.coordinator)
        if uiView.isEditable != configuration.isEditable {
            uiView.isEditable = configuration.isEditable
        }
        let targetBg = UIColor(theme.editorBackgroundColor)
        if uiView.backgroundColor != targetBg {
            uiView.backgroundColor = targetBg
        }

        // Font and textColor: only set when the editor is empty. Per Apple docs both
        // properties "apply to the entire text string", so setting them when there is
        // attributed content (from setContent or typing) would override per-character
        // font/color attributes, causing imported HTML to lose its formatting until
        // the user types (which uses typingAttributes from the text storage instead).
        let hasContent = uiView.textStorage.length > 0
        if !hasContent {
            let targetText = UIColor(theme.editorTextColor)
            if uiView.textColor != targetText {
                uiView.textColor = targetText
            }
            if uiView.font != theme.editorFont {
                uiView.font = theme.editorFont
            }
        }

        // Placeholder font always follows the theme (it's a separate UILabel)
        let coordinator = representableContext.coordinator
        if coordinator.placeholderLabel?.font != theme.editorFont {
            coordinator.placeholderLabel?.font = theme.editorFont
        }

        // Keep the placeholder alignment in sync with the host app's writing direction.
        let placeholderAlignment: NSTextAlignment = resolvedIsRTL(for: uiView) ? .right : .left
        if coordinator.placeholderLabel?.textAlignment != placeholderAlignment {
            coordinator.placeholderLabel?.textAlignment = placeholderAlignment
        }

        // Only dispatch a first-responder change when the desired focus state actually changes.
        // Without this guard, every typing keystroke triggers updateUIView (via syncState()),
        // and if isFocused is false (e.g. .constant(false)), each call would dispatch
        // resignFirstResponder() — dismissing the keyboard after the first character typed.
        let wantsFocus = isFocused
        if coordinator.lastRequestedFocus != wantsFocus {
            coordinator.lastRequestedFocus = wantsFocus
            DispatchQueue.main.async {
                if wantsFocus {
                    if !uiView.isFirstResponder { uiView.becomeFirstResponder() }
                } else {
                    if uiView.isFirstResponder { uiView.resignFirstResponder() }
                }
            }
        }

        // Sync placeholder visibility.
        // We read context.characterCount to register it as a SwiftUI dependency:
        // any programmatic content change (setContent, commitLink, commitImage)
        // updates characterCount via syncState(), which triggers updateUIView here.
        // The actual isEmpty check uses the UITextView's storage directly for accuracy.
        _ = context.characterCount  // register dependency
        representableContext.coordinator.placeholderLabel?.isHidden = !uiView.textStorage.string.isEmpty
    }

    // MARK: - Keyboard "Done" accessory

    /// Adds or removes the keyboard input-accessory toolbar to match
    /// `configuration.showsKeyboardDoneButton`. Only mutates when the desired presence differs
    /// from the current one, so it's safe to call on every `updateUIView` (i.e. every keystroke)
    /// without rebuilding the toolbar or flickering the keyboard.
    private func syncKeyboardDoneButton(on textView: UITextView, coordinator: EditorCoordinator) {
        let wantsButton = configuration.showsKeyboardDoneButton
        let hasButton = textView.inputAccessoryView != nil
        guard wantsButton != hasButton else { return }

        textView.inputAccessoryView = wantsButton ? Self.makeDoneToolbar(target: coordinator) : nil
        // Reload the input views so a live keyboard picks up the change immediately.
        if textView.isFirstResponder {
            textView.reloadInputViews()
        }
    }

    /// Builds a keyboard toolbar with a trailing localized "Done" button wired to the coordinator.
    private static func makeDoneToolbar(target: EditorCoordinator) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(
                title: .localized("button.done"),
                style: .done,
                target: target,
                action: #selector(EditorCoordinator.dismissKeyboard)
            )
        ]
        return toolbar
    }
}
