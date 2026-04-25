import Foundation

/// Controls how pasted content is inserted into the editor.
public enum PasteMode: Sendable {
    /// Paste rich content preserving its original formatting (default).
    case rich
    /// Strip all formatting and paste as plain text using the current typing attributes.
    case plainText
    /// Show a context menu letting the user choose between rich and plain paste per tap.
    case userChoice
}

/// Configuration for the editor's allowed features, placeholder, and editing behaviour.
public struct EditorConfiguration: Sendable {
    /// Which toolbar actions are displayed. Defaults to all actions.
    public var allowedToolbarItems: Set<EditorToolbarAction>

    /// Placeholder text shown when the editor is empty.
    public var placeholder: String

    /// Maximum character count (0 = unlimited).
    public var maxLength: Int

    /// Whether the editor is editable. Set to `false` for read-only mode.
    public var isEditable: Bool

    /// When `true`, a word and character count bar is shown below the editing surface.
    public var showsWordCount: Bool

    /// Controls whether pasted content retains its formatting or is stripped to plain text.
    public var pasteMode: PasteMode

    public init(
        allowedToolbarItems: Set<EditorToolbarAction> = Set(EditorToolbarAction.allCases),
        placeholder: String = "Type something...",
        maxLength: Int = 0,
        isEditable: Bool = true,
        showsWordCount: Bool = false,
        pasteMode: PasteMode = .rich
    ) {
        self.allowedToolbarItems = allowedToolbarItems
        self.placeholder = placeholder
        self.maxLength = max(0, maxLength)  // Clamp: negative values are treated as 0 (unlimited)
        self.isEditable = isEditable
        self.showsWordCount = showsWordCount
        self.pasteMode = pasteMode
    }

    /// A default configuration with all toolbar items enabled.
    public static let `default` = EditorConfiguration()
}
