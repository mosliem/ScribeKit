import UIKit
import XCTest

@testable import ScribeKit

@MainActor
final class LinkFormatterTests: XCTestCase {
    
    private func makeTextView(text: String = "Visit our website") -> UITextView {
        let textView = UITextView()
        textView.frame = CGRect(x: 0, y: 0, width: 375, height: 300)
        textView.text = text
        textView.selectedRange = NSRange(location: 0, length: 5)
        return textView
    }
    
    func testInsertLink() {
        let textView = makeTextView()
        let url = "https://apple.com"
        LinkFormatter.insertLink(url: url, displayText: "Apple", in: textView)
        textView.selectedRange = NSRange(location: 0, length: 0)
        let link = LinkFormatter.currentLink(in: textView)
        XCTAssertEqual(link, url)
    }
    
    func testRemoveLink() {
        let textView = makeTextView()
        let url = "https://apple.com"
        LinkFormatter.insertLink(url: url, displayText: "Apple", in: textView)
        textView.selectedRange = NSRange(location: 0, length: 0)
        LinkFormatter.removeLink(in: textView)
        let link = LinkFormatter.currentLink(in: textView)
        XCTAssertNil(link)
    }
    
    func testDetectLinkWhenNoLinkPresent() {
        let textView = makeTextView()
        let link = LinkFormatter.currentLink(in: textView)
        XCTAssertNil(link)
    }
}
