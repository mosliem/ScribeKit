import UIKit
import XCTest

@testable import ScribeKit

@MainActor
final class ListFormatterTests: XCTestCase {

    private func makeTextView(text: String) -> UITextView {
        let textView = UITextView()
        textView.frame = CGRect(x: 0, y: 0, width: 375, height: 300)
        textView.text = text
        textView.selectedRange = NSRange(location: 0, length: 0)
        return textView
    }

    // MARK: - Toggle On

    func testToggleBulletList_AddsMarker() {
        let textView = makeTextView(text: "Hello")
        ListFormatter.toggleList(.bullet, in: textView)
        XCTAssertTrue(textView.textStorage.string.hasPrefix("• "))
    }

    func testToggleNumberedList_AddsMarker() {
        let textView = makeTextView(text: "Hello")
        ListFormatter.toggleList(.numbered, in: textView)
        XCTAssertTrue(textView.textStorage.string.hasPrefix("1. "))
    }

    func testToggleDashList_AddsMarker() {
        let textView = makeTextView(text: "Hello")
        ListFormatter.toggleList(.dash, in: textView)
        XCTAssertTrue(textView.textStorage.string.hasPrefix("- "))
    }

    /// Tapping a list button on an empty editor must insert the marker (previously the
    /// internal loop short-circuited on a zero-length paragraph and nothing happened).
    func testToggleBulletList_EmptyEditor_InsertsMarker() {
        let textView = makeTextView(text: "")
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.typingAttributes = [.font: UIFont.systemFont(ofSize: 18)]

        ListFormatter.toggleList(.bullet, in: textView)

        XCTAssertEqual(textView.textStorage.string, "• ")
        // The marker must inherit the editor's font, not fall back to the system 12pt default.
        let markerFont = textView.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(markerFont?.pointSize, 18, "Marker should use the textView's font, not the system default")
    }

    /// Regression for the "first item is tiny, second item is fine" report. The first
    /// marker used to be inserted without any font attribute, so the system rendered it
    /// at 12pt while the typed text used the editor's 18pt font.
    func testToggleBulletList_FirstMarker_InheritsParagraphFont() {
        let textView = makeTextView(text: "Hello")
        // Give the existing paragraph an explicit font so we can assert it's copied onto the marker.
        let para = NSRange(location: 0, length: 5)
        textView.textStorage.addAttribute(.font, value: UIFont.systemFont(ofSize: 20), range: para)

        ListFormatter.toggleList(.bullet, in: textView)

        let markerFont = textView.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(markerFont?.pointSize, 20, "First marker font must match the paragraph's existing font")
    }

    // MARK: - Toggle Off

    func testToggleBullet_Twice_RemovesMarker() {
        let textView = makeTextView(text: "Hello")
        ListFormatter.toggleList(.bullet, in: textView)
        ListFormatter.toggleList(.bullet, in: textView)
        XCTAssertFalse(textView.textStorage.string.hasPrefix("• "))
    }

    func testToggleNumbered_Twice_RemovesMarker() {
        let textView = makeTextView(text: "Hello")
        ListFormatter.toggleList(.numbered, in: textView)
        ListFormatter.toggleList(.numbered, in: textView)
        XCTAssertFalse(textView.textStorage.string.hasPrefix("1. "))
    }

    // MARK: - Switch Type

    func testSwitchFromBulletToNumbered() {
        let textView = makeTextView(text: "Hello")
        ListFormatter.toggleList(.bullet, in: textView)
        ListFormatter.toggleList(.numbered, in: textView)

        XCTAssertFalse(textView.textStorage.string.hasPrefix("• "))
        XCTAssertTrue(textView.textStorage.string.hasPrefix("1. "))
    }

    // MARK: - Detection

    func testDetectBulletStyle() {
        let textView = makeTextView(text: "Hello")
        ListFormatter.toggleList(.bullet, in: textView)

        let detected = ListFormatter.detectListStyle(in: textView.textStorage, at: 0)
        XCTAssertEqual(detected, .bullet)
    }

    func testDetectNoStyle_WithoutList() {
        let textView = makeTextView(text: "Hello")
        let detected = ListFormatter.detectListStyle(in: textView.textStorage, at: 0)
        XCTAssertNil(detected)
    }

    // MARK: - Marker Generation

    func testMarkerForBullet() {
        XCTAssertEqual(EditorListStyle.bullet.marker(forIndex: 1), "• ")
        XCTAssertEqual(EditorListStyle.bullet.marker(forIndex: 5), "• ")
    }

    func testMarkerForNumbered() {
        XCTAssertEqual(EditorListStyle.numbered.marker(forIndex: 1), "1. ")
        XCTAssertEqual(EditorListStyle.numbered.marker(forIndex: 3), "3. ")
    }

    func testMarkerForDash() {
        XCTAssertEqual(EditorListStyle.dash.marker(forIndex: 1), "- ")
    }

    // MARK: - Edge Cases

    func testNumberedList_AtDocumentStart_DoesNotInfiniteLoop() {
        let textView = makeTextView(text: "First\nSecond\nThird")
        textView.selectedRange = NSRange(location: 0, length: textView.textStorage.length)
        // This should not infinite loop (Issue #2 regression test)
        ListFormatter.toggleList(.numbered, in: textView)
        XCTAssertTrue(textView.textStorage.string.hasPrefix("1. "))
    }

    func testDetectListStyle_EmptyString_ReturnsNil() {
        let textView = makeTextView(text: "")
        let detected = ListFormatter.detectListStyle(in: textView.textStorage, at: 0)
        XCTAssertNil(detected)
    }

    func testDoubleApply_DoesNotDoubleMarker() {
        let textView = makeTextView(text: "Hello")
        ListFormatter.toggleList(.bullet, in: textView)
        // Apply again without toggling off first — should not produce "• • Hello"
        let text = textView.textStorage.string
        XCTAssertFalse(text.hasPrefix("• • "), "Double marker detected: \(text)")
    }
}
