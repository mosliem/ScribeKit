import UIKit
import XCTest

@testable import ScribeKit

@MainActor
final class FormattingEngineTests: XCTestCase {

    private func makeTextView(text: String = "Hello World") -> UITextView {
        let textView = UITextView()
        textView.frame = CGRect(x: 0, y: 0, width: 375, height: 300)
        textView.text = text
        textView.selectedRange = NSRange(location: 0, length: text.count)
        return textView
    }

    func testToggleBold() {
        let textView = makeTextView()
        FormattingEngine.toggleStyle(.bold, in: textView)
        XCTAssertTrue(
            FormattingEngine.isStyleActive(.bold, in: textView.textStorage, range: textView.selectedRange)
        )
        FormattingEngine.toggleStyle(.bold, in: textView)
        XCTAssertFalse(
            FormattingEngine.isStyleActive(.bold, in: textView.textStorage, range: textView.selectedRange)
        )
    }

    func testToggleItalic() {
        let textView = makeTextView()
        FormattingEngine.toggleStyle(.italic, in: textView)
        XCTAssertTrue(
            FormattingEngine.isStyleActive(
                .italic, in: textView.textStorage, range: textView.selectedRange))
    }

    func testToggleUnderline() {
        let textView = makeTextView()
        FormattingEngine.toggleStyle(.underline, in: textView)
        XCTAssertTrue(
            FormattingEngine.isStyleActive(
                .underline, in: textView.textStorage, range: textView.selectedRange))
    }

    func testToggleStrikethrough() {
        let textView = makeTextView()
        FormattingEngine.toggleStyle(.strikethrough, in: textView)
        XCTAssertTrue(
            FormattingEngine.isStyleActive(
                .strikethrough, in: textView.textStorage, range: textView.selectedRange))
    }

    func testSetAlignment() {
        let textView = makeTextView()
        FormattingEngine.setAlignment(.center, in: textView)
        XCTAssertEqual(FormattingEngine.currentAlignment(in: textView), .center)
        FormattingEngine.setAlignment(.right, in: textView)
        XCTAssertEqual(FormattingEngine.currentAlignment(in: textView), .right)
        FormattingEngine.setAlignment(.left, in: textView)
        XCTAssertEqual(FormattingEngine.currentAlignment(in: textView), .left)
    }

    /// Alignment is absolute — tapping "left" always produces `.left` regardless of whether the
    /// paragraph contains Arabic, English, or anything else.
    func testSetAlignment_IsAbsolute_ArabicContent() {
        let textView = makeTextView(text: "مرحبا بالعالم")

        FormattingEngine.setAlignment(.left, in: textView)
        let storage = textView.textStorage
        let leftStyle = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(leftStyle?.alignment, .left)
        XCTAssertEqual(FormattingEngine.currentAlignment(in: textView), .left)

        FormattingEngine.setAlignment(.right, in: textView)
        let rightStyle = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(rightStyle?.alignment, .right)
        XCTAssertEqual(FormattingEngine.currentAlignment(in: textView), .right)
    }

    func testSetAlignment_IsAbsolute_EnglishContent() {
        let textView = makeTextView(text: "Hello World")

        FormattingEngine.setAlignment(.right, in: textView)
        let storage = textView.textStorage
        let style = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.alignment, .right, "Absolute alignment ignores content direction")
    }

    /// On an empty editor, alignment must still land somewhere the next typed character
    /// will pick up. Without writing into typingAttributes, the toolbar tap silently
    /// no-ops because there are no paragraph-style runs to enumerate.
    func testSetAlignment_EmptyEditor_WritesTypingAttributes() {
        let textView = makeTextView(text: "")
        FormattingEngine.setAlignment(.center, in: textView)
        let style = textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(style?.alignment, .center)
    }

    /// The toolbar's active-button highlight reads `currentAlignment`. On an empty editor
    /// it has to surface what the user just chose via typing attributes — otherwise the
    /// button visibly stays on "left" even after tapping "center" / "right".
    func testCurrentAlignment_EmptyEditor_ReflectsTypingAttributes() {
        let textView = makeTextView(text: "")
        FormattingEngine.setAlignment(.right, in: textView)
        XCTAssertEqual(FormattingEngine.currentAlignment(in: textView), .right)

        FormattingEngine.setAlignment(.center, in: textView)
        XCTAssertEqual(FormattingEngine.currentAlignment(in: textView), .center)
    }

    func testAdjustFontSize() {
        let textView = makeTextView()
        let initialSize = FormattingEngine.currentFontSize(in: textView)
        FormattingEngine.adjustFontSize(by: 2, in: textView)
        XCTAssertEqual(FormattingEngine.currentFontSize(in: textView), initialSize + 2)
    }

    func testActiveStyles() {
        let textView = makeTextView()
        FormattingEngine.toggleStyle(.bold, in: textView)
        FormattingEngine.toggleStyle(.italic, in: textView)
        let active = FormattingEngine.activeStyles(in: textView)
        XCTAssertTrue(active.contains(.bold))
        XCTAssertTrue(active.contains(.italic))
        XCTAssertFalse(active.contains(.underline))
    }
}
