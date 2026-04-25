import SwiftUI

/// Sheet for inserting or editing a hyperlink.
/// Pre-fills from existing link data (edit mode) or from the selected text.
public struct LinkInputSheet: View {
    
    let existingURL: String
    let existingText: String
    
    let onCommit: (String, String) -> Void
    let onRemove: (() -> Void)?
    
    @State private var urlText: String
    @State private var displayText: String
    
    @Environment(\.dismiss) private var dismiss
    
    public init(
        existingURL: String = "",
        existingText: String = "",
        onCommit: @escaping (String, String) -> Void,
        onRemove: (() -> Void)? = nil
    ) {
        self.existingURL = existingURL
        self.existingText = existingText
        self.onCommit = onCommit
        self.onRemove = onRemove
        _urlText = State(initialValue: existingURL)
        _displayText = State(initialValue: existingText)
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("URL") {
                    TextField("https://example.com", text: $urlText)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                Section("Display Text") {
                    TextField("Link text", text: $displayText)
                }
                
                if onRemove != nil && !existingURL.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            onRemove?()
                            dismiss()
                        } label: {
                            Label("Remove Link", systemImage: "link.badge.minus")
                        }
                    }
                }
            }
            .navigationTitle(existingURL.isEmpty ? "Insert Link" : "Edit Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // SwiftUI's ToolbarItem — no naming conflict since our enum is EditorToolbarAction
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onCommit(urlText, displayText)
                        dismiss()
                    }
                    .disabled(urlText.isEmpty)
                }
            }
        }
    }
}
