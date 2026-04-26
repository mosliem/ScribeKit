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
                Section {
                    TextField(String.localized("link.placeholder.url"), text: $urlText)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text(localized: "link.section.url")
                }

                Section {
                    TextField(String.localized("link.placeholder.display_text"), text: $displayText)
                } header: {
                    Text(localized: "link.section.display_text")
                }

                if onRemove != nil && !existingURL.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            onRemove?()
                            dismiss()
                        } label: {
                            Label(String.localized("link.button.remove"), systemImage: "link.badge.minus")
                        }
                    }
                }
            }
            .navigationTitle(
                existingURL.isEmpty
                    ? String.localized("link.title.insert")
                    : String.localized("link.title.edit")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // SwiftUI's ToolbarItem — no naming conflict since our enum is EditorToolbarAction
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.localized("button.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.localized("button.done")) {
                        onCommit(urlText, displayText)
                        dismiss()
                    }
                    .disabled(urlText.isEmpty)
                }
            }
        }
    }
}
