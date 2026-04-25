import UIKit

/// An on-demand content snapshot of the editor.
/// Create when you need the content — do not store on `EditorContext` to avoid continuous re-export.
@MainActor
public struct EditorContent {
    /// The raw attributed string.
    public let attributedString: NSAttributedString

    /// The exported HTML representation. Computed once at construction time.
    public let html: String

    /// Plain text without any formatting.
    public var plainText: String { attributedString.string }

    /// Initialise from an attributed string (exports HTML immediately).
    public init(attributedString: NSAttributedString) {
        self.attributedString = attributedString
        self.html = HTMLExporter.export(attributedString)
    }

    /// Initialise from an HTML string (imports and stores attributed string).
    /// Re-exports to HTML after import so `html` reflects the actual parsed content.
    public init(html: String, font: UIFont = UIFont.systemFont(ofSize: 16)) {
        let imported = HTMLImporter.import(html: html, defaultFont: font)
        self.attributedString = imported
        // Re-export instead of storing original, so html matches the imported content (Issue #14)
        self.html = HTMLExporter.export(imported)
    }
}
