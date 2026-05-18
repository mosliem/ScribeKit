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
        FormattingEngine.setAlignment(.trailing, in: textView)
        XCTAssertEqual(FormattingEngine.currentAlignment(in: textView), .trailing)
    }

    /// Alignment must follow the paragraph's content direction so editing an Arabic paragraph
    /// in an LTR app (or English in an RTL app) aligns relative to the content, not the UI.
    func testSetAlignment_FollowsContentDirection_ArabicInLTRView() {
        let textView = makeTextView(text: "مرحبا بالعالم")

        FormattingEngine.setAlignment(.leading, in: textView)
        let storage = textView.textStorage
        let style = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.alignment, .right, "Arabic content's leading edge is the right side")
        XCTAssertEqual(FormattingEngine.currentAlignment(in: textView), .leading)

        FormattingEngine.setAlignment(.trailing, in: textView)
        let trailingStyle = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(trailingStyle?.alignment, .left, "Arabic content's trailing edge is the left side")
        XCTAssertEqual(FormattingEngine.currentAlignment(in: textView), .trailing)
    }

    func testSetAlignment_FollowsContentDirection_EnglishContent() {
        let textView = makeTextView(text: "Hello World")

        FormattingEngine.setAlignment(.leading, in: textView)
        let storage = textView.textStorage
        let style = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.alignment, .left, "English content's leading edge is the left side")
    }

    func testSetAlignment_EmptyParagraph_FallsBackToViewDirection() {
        let textView = makeTextView(text: "")
        // No strong characters → falls back to the view's UI direction (LTR by default).
        FormattingEngine.setAlignment(.leading, in: textView)
        XCTAssertEqual(FormattingEngine.currentAlignment(in: textView), .leading)
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
