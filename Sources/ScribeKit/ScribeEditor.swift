import SwiftUI
import UIKit

/// The main public rich text editor view.
/// Compose this into your app and supply an `EditorContext` instance.
///
/// ```swift
/// @State private var context = EditorContext()
///
/// var body: some View {
///     ScribeEditor(context: context)
///         .environment(\.editorTheme, MyCustomTheme())
/// }
/// ```
public struct ScribeEditor: View {

    // @Bindable enables $context.activeSheet binding for .sheet(item:)
    @Bindable var context: EditorContext
    let configuration: EditorConfiguration
    /// Two-way binding reflecting whether the editor is currently focused (first responder).
    /// Set to `true` to programmatically open the keyboard; the binding is updated automatically
    /// when the user taps in or dismisses the keyboard.
    @Binding var isFocused: Bool
    /// Optional validation error message. When non-nil the border turns red and the message
    /// is displayed below the editor. Set to `""` to clear the error.
    @Binding var errorMessage: String

    @Environment(\.editorTheme) private var theme

    /// Internal, always-live focus state. The public `isFocused` binding may be
    /// `.constant(false)` (when the caller doesn't track focus), which would discard the
    /// coordinator's focus updates — so the active border must read this instead.
    @State private var isFocusedInternal = false

    /// Bridges the coordinator's focus reporting to both the internal state (which drives the
    /// active border) and the external binding (for callers that track focus).
    private var focusBinding: Binding<Bool> {
        Binding(
            get: { isFocused || isFocusedInternal },
            set: { newValue in
                if isFocusedInternal != newValue { isFocusedInternal = newValue }
                if isFocused != newValue { isFocused = newValue }
            }
        )
    }

    /// Use when focus is tracked with a plain `@State var isFocused: Bool`.
    public init(
        context: EditorContext,
        configuration: EditorConfiguration = .default,
        isFocused: Binding<Bool> = .constant(false),
        errorMessage: Binding<String> = .constant("")
    ) {
        self.context = context
        self.configuration = configuration
        self._isFocused = isFocused
        self._errorMessage = errorMessage
    }

    /// Use when focus is tracked with `@FocusState var isFocused: Bool`.
    ///
    /// `FocusState<Bool>.Binding` is a different type from `Binding<Bool>` and cannot be passed
    /// to the other initialiser directly. This overload bridges it so both property wrappers work:
    /// ```swift
    /// @FocusState private var isFocused: Bool
    /// ScribeEditor(context: context, isFocused: $isFocused)
    /// ```
    public init(
        context: EditorContext,
        configuration: EditorConfiguration = .default,
        isFocused: FocusState<Bool>.Binding,
        errorMessage: Binding<String> = .constant("")
    ) {
        self.context = context
        self.configuration = configuration
        // Bridge FocusState.Binding → Binding<Bool> so the rest of the implementation
        // (coordinator, EditorTextView) stays uniform with a single Binding<Bool>.
        self._isFocused = Binding(
            get: { isFocused.wrappedValue },
            set: { isFocused.wrappedValue = $0 }
        )
        self._errorMessage = errorMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(spacing: 0) {
                EditorToolbar(context: context, configuration: configuration)

                Divider()

                EditorTextView(context: context, configuration: configuration, isFocused: focusBinding, errorMessage: $errorMessage)

                if configuration.showsWordCount {
                    Divider()
                    WordCountBar(context: context)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(activeBorderColor, lineWidth: 1)
            )

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(Font(theme.editorFont.withSize(UIFont.preferredFont(forTextStyle: .caption1).pointSize)))
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 4)
            }
        }
        // Single sheet managed by the EditorSheet enum — no multiple boolean flags
        .sheet(item: $context.activeSheet) { sheet in
            switch sheet {
            case .link(let existingURL, let existingText):
                LinkInputSheet(
                    existingURL: existingURL,
                    existingText: existingText,
                    onCommit: { url, text in
                        context.commitLink(url: url, displayText: text)
                    },
                    onRemove: existingURL.isEmpty ? nil : {
                        context.removeLink()
                    }
                )

            case .imagePicker:
                ImagePickerSheet { data in
                    context.commitImage(data: data)
                }
            }
        }
    }

    /// Resolves the border color based on validation and focus state.
    /// Error takes priority over focus so a red border is never hidden by the focus ring.
    private var activeBorderColor: Color {
        if !errorMessage.isEmpty {
            return .red
        }

        if isFocusedInternal {
            return theme.activeBorderColor ?? theme.borderColor
        }

        return theme.borderColor
    }
}

// MARK: - Word Count Bar

private struct WordCountBar: View {
    
    let context: EditorContext
    
    @Environment(\.editorTheme) private var theme
    
    var body: some View {
        HStack {
            Spacer()
            Text(String(format: .localized("wordcount.format"), context.wordCount, context.characterCount))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(theme.toolbarBackgroundColor)
    }
}
