import SwiftUI

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
    
    @Environment(\.editorTheme) private var theme
    
    public init(
        context: EditorContext,
        configuration: EditorConfiguration = .default
    ) {
        self.context = context
        self.configuration = configuration
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(context: context, configuration: configuration)
            
            Divider()
            
            EditorTextView(context: context, configuration: configuration)
            
            if configuration.showsWordCount {
                Divider()
                WordCountBar(context: context)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.borderColor, lineWidth: 1)
        )
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
