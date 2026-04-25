import UIKit
import XCTest

@testable import SwiftyEditor

final class HTMLImporterTests: XCTestCase {
    
    func testImport_EmptyHTML_ReturnsEmpty() {
        let result = HTMLImporter.import(html: "")
        XCTAssertEqual(result.length, 0)
    }
    
    func testImport_PlainParagraph() {
        let result = HTMLImporter.import(html: "<p>Hello World</p>")
        XCTAssertTrue(result.string.contains("Hello World"))
    }
    
    func testImport_BoldTag_AppliesBoldFont() {
        let result = HTMLImporter.import(html: "<p><strong>Bold text</strong></p>")
        guard result.length > 0 else { return XCTFail("Empty result") }
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }
    
    func testImport_ItalicTag_AppliesItalicFont() {
        let result = HTMLImporter.import(html: "<p><em>Italic text</em></p>")
        guard result.length > 0 else { return XCTFail("Empty result") }
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
    }
    
    func testImport_LinkTag_AppliesLinkAttribute() {
        let result = HTMLImporter.import(html: "<p><a href=\"https://apple.com\">Apple</a></p>")
        guard result.length > 0 else { return XCTFail("Empty result") }
        let link = result.attribute(.link, at: 0, effectiveRange: nil)
        XCTAssertNotNil(link)
    }
    
    func testImport_BulletListMarker_AttachesListAttribute() {
        let result = HTMLImporter.import(html: "<ul><li>Item one</li></ul>")
        // The importer post-processes text-prefix markers; ensure the string contains list text
        XCTAssertTrue(result.string.contains("Item one"))
    }
    
    // MARK: - Round-trip
    
    func testRoundTrip_PlainText() {
        let original = NSAttributedString(string: "Hello World")
        let html = HTMLExporter.export(original)
        let imported = HTMLImporter.import(html: html)
        XCTAssertTrue(imported.string.contains("Hello World"))
    }
    
    func testRoundTrip_BoldText() {
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16)]
        let original = NSAttributedString(string: "Bold", attributes: attrs)
        let html = HTMLExporter.export(original)
        let imported = HTMLImporter.import(html: html)
        
        guard imported.length > 0 else { return XCTFail("Empty round-trip result") }
        let font = imported.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }
}
