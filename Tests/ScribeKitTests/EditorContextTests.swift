import SwiftUI
import XCTest

@testable import ScribeKit

@MainActor
final class EditorContextTests: XCTestCase {

    func testInitialization() {
        let textView = UITextView()
        let context = EditorContext()
        context.textView = textView
        XCTAssertNotNil(context.textView)
    }

    func testToggleStyle() {
        let textView = UITextView()
        let context = EditorContext()
        context.textView = textView
        textView.text = "Hello"
        textView.selectedRange = NSRange(location: 0, length: 5)

        context.toggleStyle(.bold)
        XCTAssertTrue(context.activeStyles.contains(.bold))
    }

    func testSetAlignment() {
        let textView = UITextView()
        let context = EditorContext()
        context.textView = textView
        textView.text = "Hello"
        textView.selectedRange = NSRange(location: 0, length: 5)

        context.setAlignment(.center)
        XCTAssertEqual(context.currentAlignment, .center)
    }

    func testSetHeading() {
        let textView = UITextView()
        let context = EditorContext()
        context.textView = textView
        textView.text = "Hello"
        textView.selectedRange = NSRange(location: 0, length: 5)

        context.setHeading(.heading1)
        XCTAssertEqual(context.currentHeadingStyle, .heading1)
    }

    // MARK: - Observable `html` value

    /// Programmatic `setContent` flushes the `html` value synchronously (no debounce),
    /// so it is correct the instant the call returns.
    func testSetContentUpdatesHTMLImmediately() {
        let textView = UITextView()
        let context = EditorContext()
        context.textView = textView

        context.setContent(attributedString: NSAttributedString(string: "Hello world"))

        XCTAssertTrue(
            context.html.contains("Hello world"),
            "setContent should flush html immediately; got: \(context.html)"
        )
    }

    /// A formatting edit debounces the `html` re-export: `html` is stale immediately after
    /// the edit and only reflects the change once the debounce interval elapses.
    func testFormattingUpdatesHTMLAfterDebounce() async throws {
        let textView = UITextView()
        let context = EditorContext()
        context.textView = textView
        context.htmlDebounceInterval = .milliseconds(20)

        context.setContent(attributedString: NSAttributedString(string: "Hello"))
        textView.selectedRange = NSRange(location: 0, length: 5)

        context.toggleStyle(.bold)
        // Not yet reconciled: the immediate setContent export had no bold styling.
        XCTAssertNotEqual(context.html, context.exportHTML())

        try await Task.sleep(for: .milliseconds(120))

        // After the debounce fires, the stored html matches a live export.
        XCTAssertEqual(context.html, context.exportHTML())
    }

    /// Typing (via the coordinator delegate callback) debounces the `html` re-export.
    func testTypingUpdatesHTMLAfterDebounce() async throws {
        let textView = UITextView()
        let context = EditorContext()
        context.textView = textView
        context.htmlDebounceInterval = .milliseconds(20)
        let coordinator = EditorCoordinator(
            context: context,
            configuration: .default,
            isFocused: .constant(false),
            errorMessage: .constant("")
        )

        textView.text = "Typed text"
        coordinator.textViewDidChange(textView)
        // Debounced: nothing exported yet within the same synchronous turn.
        XCTAssertTrue(context.html.isEmpty)

        try await Task.sleep(for: .milliseconds(120))

        XCTAssertTrue(
            context.html.contains("Typed text"),
            "html should reflect typed content after debounce; got: \(context.html)"
        )
    }

    /// The coordinator must report focus into whatever binding it holds — in `ScribeEditor`
    /// that binding writes an internal `@State`, which is what drives the active border color.
    /// Regression: previously the active border read the external `isFocused` binding, which is
    /// `.constant(false)` for callers that don't track focus, so it never reflected focus.
    func testCoordinatorReportsFocusIntoBinding() {
        let context = EditorContext()
        let textView = UITextView()
        context.textView = textView
        var focused = false
        let coordinator = EditorCoordinator(
            context: context,
            configuration: .default,
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            errorMessage: .constant("")
        )

        coordinator.textViewDidBeginEditing(textView)
        XCTAssertTrue(focused, "Begin editing should report focus = true")

        coordinator.textViewDidEndEditing(textView)
        XCTAssertFalse(focused, "End editing should report focus = false")
    }

    /// A pure selection/cursor change must not re-export `html`.
    func testSelectionChangeDoesNotReexportHTML() async throws {
        let textView = UITextView()
        let context = EditorContext()
        context.textView = textView
        let coordinator = EditorCoordinator(
            context: context,
            configuration: .default,
            isFocused: .constant(false),
            errorMessage: .constant("")
        )

        context.setContent(attributedString: NSAttributedString(string: "Hello"))
        let htmlBefore = context.html

        textView.selectedRange = NSRange(location: 1, length: 0)
        coordinator.textViewDidChangeSelection(textView)

        try await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(context.html, htmlBefore)
    }
}
