import SwiftUI
import XCTest

@testable import SwiftyEditor

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
}
