import Observation
import SwiftUI
import UIKit

/// The central observable state object for the editor.
/// Mark `@MainActor` so all property mutations happen on the main thread and SwiftUI
/// observations never need `@Sendable` closures or explicit dispatch.
@Observable
@MainActor
public final class EditorContext {

    // MARK: - Public State (read by toolbar / SwiftUI)

    /// The currently active text styles at the cursor or in the selection.
    public private(set) var activeStyles: Set<TextStyle> = []

    /// The alignment of the current paragraph.
    public private(set) var currentAlignment: RichTextAlignment = .left

    /// The list style of the current paragraph, or `nil` if not in a list.
    public private(set) var currentListStyle: EditorListStyle?

    /// The heading style of the current paragraph, or `nil` if body text.
    public private(set) var currentHeadingStyle: EditorHeadingStyle?

    /// The URL string of the link at the cursor, or `nil`.
    public private(set) var currentLink: String?

    /// The font size at the cursor or start of selection.
    public private(set) var currentFontSize: CGFloat = 16

    /// The foreground (text) color at the cursor, or `nil` if default.
    /// `nil` when the cursor is inside a link (link color is not a user text-color choice).
    public private(set) var currentForegroundColor: Color?

    /// The background (highlight) color at the cursor, or `nil` if none.
    public private(set) var currentHighlightColor: Color?

    /// Current character count (Swift `Character` count, not UTF-16 units).
    public private(set) var characterCount: Int = 0

    /// Live word count.
    public private(set) var wordCount: Int = 0

    /// The editor's current content serialized as HTML.
    /// Refreshed on every content mutation (typing, paste, delete, programmatic
    /// `setContent`, and formatting) after a short debounce; NOT refreshed on
    /// cursor/selection movement. Observe it directly to receive the new value:
    /// ```swift
    /// .onChange(of: context.html) { _, newHTML in ... }
    /// ```
    /// For a synchronous, un-debounced snapshot use `exportHTML()` instead.
    public private(set) var html: String = ""

    /// The active sheet being presented (link input, image picker), or `nil`.
    public internal(set) var activeSheet: EditorSheet?

    // MARK: - Internal

    /// Weak reference set by the coordinator. Not stored as @Observable state.
    weak var textView: UITextView?

    /// Direct reference to the coordinator so we can sync the placeholder immediately
    /// after programmatic content changes.
    weak var coordinator: EditorCoordinator?

    /// Debounce delay for re-exporting `html`. Mirrors `EditorConfiguration.htmlDebounceInterval`;
    /// set by `EditorTextView` during wiring. `@ObservationIgnored` — changing it must not
    /// invalidate observers.
    @ObservationIgnored var htmlDebounceInterval: Duration = .milliseconds(300)

    /// Whether empty content is still wrapped in HTML tags on export. Mirrors
    /// `EditorConfiguration.wrapsEmptyContentInTags`; set by `EditorTextView` during wiring.
    /// `@ObservationIgnored` — changing it must not invalidate observers.
    @ObservationIgnored var wrapsEmptyContentInTags: Bool = true

    /// The in-flight debounced HTML export. Cancelled and restarted on each interactive edit.
    @ObservationIgnored private var htmlExportTask: Task<Void, Never>?

    // MARK: - Computed (on-demand, no copy on every keystroke)

    /// Returns the editor's attributed text directly from the UITextView.
    public var attributedText: NSAttributedString {
        textView?.attributedText ?? NSAttributedString()
    }

    // MARK: - Init

    public init() {}

    // MARK: - Content Loading

    /// Sets the editor content from an HTML string.
    public func setContent(html: String) {
        guard let textView else { return }
        // Use the text view's configured font so imported content matches the theme font.
        // Without this, HTMLImporter uses its hardcoded 16pt system font default, which
        // diverges from the theme font and causes exported content to carry the wrong
        // font size before the user types anything.
        let bodyFont = textView.font ?? UIFont.systemFont(ofSize: 16)
        let imported = HTMLImporter.import(html: html, defaultFont: bodyFont)
        textView.textStorage.beginEditing()
        textView.textStorage.setAttributedString(imported)
        textView.textStorage.endEditing()
        contentDidChange(immediate: true)
        coordinator?.syncPlaceholder(for: textView)
    }

    /// Sets the editor content from an attributed string.
    public func setContent(attributedString: NSAttributedString) {
        guard let textView else { return }
        textView.textStorage.beginEditing()
        textView.textStorage.setAttributedString(attributedString)
        textView.textStorage.endEditing()
        contentDidChange(immediate: true)
        coordinator?.syncPlaceholder(for: textView)
    }

    // MARK: - Content Export

    /// Exports the current editor content as HTML.
    public func exportHTML() -> String {
        HTMLExporter.export(attributedText, wrapEmptyContentInTags: wrapsEmptyContentInTags)
    }

    // MARK: - Style Actions

    /// Toggles a character-level text style on the current selection.
    public func toggleStyle(_ style: TextStyle) {
        guard let textView else { return }
        FormattingEngine.toggleStyle(style, in: textView)
        contentDidChange()
    }

    /// Sets the paragraph alignment.
    public func setAlignment(_ alignment: RichTextAlignment) {
        guard let textView else { return }
        FormattingEngine.setAlignment(alignment, in: textView)
        contentDidChange()
    }

    /// Toggles the given list style on the current selection.
    public func toggleList(_ style: EditorListStyle) {
        guard let textView else { return }
        ListFormatter.toggleList(style, in: textView)
        contentDidChange()
    }

    // MARK: - Heading Actions

    /// Sets the heading style for the current paragraph. Pass `nil` for body text.
    /// Toggling the active heading reverts to body.
    public func setHeading(_ style: EditorHeadingStyle?) {
        guard let textView else { return }
        let resolved = (style == currentHeadingStyle) ? nil : style
        HeadingFormatter.setHeading(resolved, in: textView)
        contentDidChange()
    }

    // MARK: - Font Size Actions

    /// Increases font size by 2pt.
    public func increaseFontSize() {
        guard let textView else { return }
        FormattingEngine.adjustFontSize(by: 2, in: textView)
        contentDidChange()
    }

    /// Decreases font size by 2pt.
    public func decreaseFontSize() {
        guard let textView else { return }
        FormattingEngine.adjustFontSize(by: -2, in: textView)
        contentDidChange()
    }

    // MARK: - Color Actions

    /// Sets the foreground (text) color at the current selection or typing position.
    public func setForegroundColor(_ color: Color) {
        guard let textView else { return }
        ColorFormatter.setForegroundColor(UIColor(color), in: textView)
        contentDidChange()
    }

    /// Removes the foreground (text) color, reverting to the default label color.
    public func resetForegroundColor() {
        guard let textView else { return }
        ColorFormatter.removeForegroundColor(in: textView)
        contentDidChange()
    }

    /// Sets or removes the background (highlight) color at the current selection.
    public func setHighlightColor(_ color: Color?) {
        guard let textView else { return }
        ColorFormatter.setBackgroundColor(color.map(UIColor.init), in: textView)
        contentDidChange()
    }

    // MARK: - Indent Actions

    /// Increases indentation by one step.
    public func increaseIndent() {
        guard let textView else { return }
        IndentFormatter.increaseIndent(in: textView)
        contentDidChange()
    }

    /// Decreases indentation by one step.
    public func decreaseIndent() {
        guard let textView else { return }
        IndentFormatter.decreaseIndent(in: textView)
        contentDidChange()
    }

    // MARK: - Link Actions

    /// Presents the link input sheet, pre-filling existing link data if the cursor is on a link.
    public func insertLink() {
        guard let textView else { return }
        let existingURL = LinkFormatter.currentLink(in: textView) ?? ""
        let existingText = LinkFormatter.currentLinkText(in: textView)
        activeSheet = .link(existingURL: existingURL, existingText: existingText)
    }

    /// Commits a link after the user fills in the link sheet.
    public func commitLink(url: String, displayText: String) {
        guard let textView else { return }
        LinkFormatter.insertLink(url: url, displayText: displayText, in: textView)
        contentDidChange()
        coordinator?.syncPlaceholder(for: textView)
    }

    /// Removes the link at the current cursor position.
    public func removeLink() {
        guard let textView else { return }
        LinkFormatter.removeLink(in: textView)
        contentDidChange()
    }

    // MARK: - Image Actions

    /// Presents the image picker sheet.
    public func insertImage() {
        activeSheet = .imagePicker
    }

    /// Dismisses the currently active sheet.
    public func dismissSheet() {
        activeSheet = nil
    }

    /// Inserts an image from raw data (called by the image picker after loading).
    public func commitImage(data: Data) {
        guard let textView else { return }
        ImageFormatter.insertImage(data: data, in: textView)
        contentDidChange()
        coordinator?.syncPlaceholder(for: textView)
    }

    // MARK: - Content Change Notification

    /// Signals that the attributed content was mutated: resyncs toolbar state immediately,
    /// then refreshes the observable `html` value.
    ///
    /// The `html` re-export is the only debounced work — `syncState()` (toolbar states,
    /// word/char counts, placeholder dependency) always runs synchronously, so the editor
    /// stays fully responsive. Pass `immediate: true` for programmatic content changes
    /// (e.g. `setContent`) so `html` is correct the instant the call returns.
    func contentDidChange(immediate: Bool = false) {
        syncState()
        if immediate {
            htmlExportTask?.cancel()
            htmlExportTask = nil
            update(\.html, to: HTMLExporter.export(attributedText, wrapEmptyContentInTags: wrapsEmptyContentInTags))
        } else {
            scheduleHTMLExport()
        }
    }

    /// Restarts the trailing-debounce timer for the `html` export. Each new edit cancels
    /// the pending export, so a burst of edits produces a single export once editing settles.
    private func scheduleHTMLExport() {
        htmlExportTask?.cancel()
        htmlExportTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.htmlDebounceInterval)
            guard !Task.isCancelled else { return }
            self.update(\.html, to: HTMLExporter.export(self.attributedText, wrapEmptyContentInTags: self.wrapsEmptyContentInTags))
        }
    }

    // MARK: - State Synchronization

    /// Reads the current state from the UITextView and updates `@Observable` properties.
    /// Uses value-change guards — only assigns when the value actually changed
    /// to prevent unnecessary SwiftUI view invalidation on every keystroke.
    func syncState() {
        guard let textView else { return }

        let textStorage = textView.textStorage
        let text = textStorage.string
        let location = textView.selectedRange.location

        update(\.activeStyles, to: FormattingEngine.activeStyles(in: textView))
        update(\.currentAlignment, to: FormattingEngine.currentAlignment(in: textView))

        update(
            \.currentListStyle,
            to: ListFormatter.detectListStyle(in: textStorage, at: location)
        )

        update(\.currentHeadingStyle, to: HeadingFormatter.detectHeadingStyle(in: textView))
        update(\.currentLink, to: LinkFormatter.currentLink(in: textView))
        update(\.currentFontSize, to: FormattingEngine.currentFontSize(in: textView))

        update(
            \.currentForegroundColor,
            to: ColorFormatter.currentForegroundColor(in: textView).map(Color.init)
        )

        update(
            \.currentHighlightColor,
            to: ColorFormatter.currentBackgroundColor(in: textView).map(Color.init)
        )

        update(\.characterCount, to: text.count)
        update(\.wordCount, to: wordCount(from: text))
    }

    private func update<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<EditorContext, T>, to newValue: T) {
        if self[keyPath: keyPath] != newValue {
            self[keyPath: keyPath] = newValue
        }
    }

    // MARK: - Private

    private func wordCount(from string: String) -> Int {
        string.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}
