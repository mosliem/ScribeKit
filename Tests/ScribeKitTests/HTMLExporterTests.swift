// Import UIFont for UIKit types in tests
import UIKit
import XCTest

@testable import ScribeKit

@MainActor
final class HTMLExporterTests: XCTestCase {
    
    // MARK: - Basic
    
    func testExport_EmptyString_ReturnsEmpty() {
        let result = HTMLExporter.export(NSAttributedString())
        XCTAssertEqual(result, "")
    }
    
    func testExport_PlainText_WrapsInParagraph() {
        let result = HTMLExporter.export(NSAttributedString(string: "Hello"))
        XCTAssertTrue(result.contains("<p>") || result.contains("<p "))
        XCTAssertTrue(result.contains("Hello"))
    }
    
    func testExport_BoldText_WrapsInStrong() {
        let font = UIFont.boldSystemFont(ofSize: 16)
        let attrStr = NSAttributedString(string: "Bold", attributes: [.font: font])
        let result = HTMLExporter.export(attrStr)
        XCTAssertTrue(result.contains("<strong>Bold</strong>"))
    }
    
    func testExport_ItalicText_WrapsInEm() {
        let descriptor = UIFont.systemFont(ofSize: 16).fontDescriptor.withSymbolicTraits(.traitItalic)!
        let font = UIFont(descriptor: descriptor, size: 16)
        let attrStr = NSAttributedString(string: "Italic", attributes: [.font: font])
        let result = HTMLExporter.export(attrStr)
        XCTAssertTrue(result.contains("<em>Italic</em>"))
    }
    
    func testExport_UnderlineText_WrapsInU() {
        let attrStr = NSAttributedString(
            string: "Under", attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        let result = HTMLExporter.export(attrStr)
        XCTAssertTrue(result.contains("<u>Under</u>"))
    }
    
    func testExport_StrikethroughText_WrapsInS() {
        let attrStr = NSAttributedString(
            string: "Strike", attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue])
        let result = HTMLExporter.export(attrStr)
        XCTAssertTrue(result.contains("<s>Strike</s>"))
    }
    
    func testExport_LinkText() {
        let attrStr = NSAttributedString(string: "Apple", attributes: [.link: "https://apple.com"])
        let result = HTMLExporter.export(attrStr)
        XCTAssertTrue(result.contains("<a href=\"https://apple.com\">Apple</a>"))
    }
    
    func testExport_HTMLEscaping() {
        let attrStr = NSAttributedString(string: "a < b & c > d")
        let result = HTMLExporter.export(attrStr)
        XCTAssertTrue(result.contains("a &lt; b &amp; c &gt; d"))
    }
    
    // MARK: - Alignment
    
    func testExport_CenterAlignment() {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrStr = NSAttributedString(string: "Centered", attributes: [.paragraphStyle: style])
        let result = HTMLExporter.export(attrStr)
        XCTAssertTrue(result.contains("text-align:center"))
    }
    
    // MARK: - Lists
    
    func testExport_BulletList_WrapsInUL() {
        let attrs: [NSAttributedString.Key: Any] = [
            .scribeKitListStyle: EditorListStyle.bullet.rawValue
        ]
        let attrStr = NSAttributedString(string: "• Item", attributes: attrs)
        let result = HTMLExporter.export(attrStr)
        XCTAssertTrue(result.contains("<ul>"))
        XCTAssertTrue(result.contains("<li>"))
    }
    
    func testExport_NumberedList_WrapsInOL() {
        let attrs: [NSAttributedString.Key: Any] = [
            .scribeKitListStyle: EditorListStyle.numbered.rawValue
        ]
        let attrStr = NSAttributedString(string: "1. Item", attributes: attrs)
        let result = HTMLExporter.export(attrStr)
        XCTAssertTrue(result.contains("<ol>"))
        XCTAssertTrue(result.contains("<li>"))
    }
    
    // MARK: - R1: Double-quote escaping in href
    
    func testExport_LinkWithQuoteInURL_EscapesQuote() {
        let url = "https://example.com/path?a=\"quoted\""
        let attrStr = NSAttributedString(string: "Link", attributes: [.link: url])
        let result = HTMLExporter.export(attrStr)
        // The " inside the URL must be escaped to &quot; so the href attribute isn't broken
        XCTAssertTrue(result.contains("&quot;"), "Double-quote in URL was not escaped: \(result)")
        XCTAssertFalse(result.contains("\"quoted\""), "Raw double-quote found in href output")
    }
    
    func testExport_BodyText_DoesNotEscapeQuotes() {
        // N1: double-quotes in body text should NOT be escaped (only in attribute values)
        let attrStr = NSAttributedString(string: "She said \"hello\"")
        let result = HTMLExporter.export(attrStr)
        XCTAssertTrue(
            result.contains("She said \"hello\""), "Body text quotes should be preserved: \(result)")
        XCTAssertFalse(result.contains("&quot;"), "Body text should not contain &quot;: \(result)")
    }
    
    func testExport_AttributeValue_EscapesQuotes() {
        // href attribute values must still escape double-quotes
        let url = "https://example.com/\"test\""
        let attrStr = NSAttributedString(string: "Link", attributes: [.link: url])
        let result = HTMLExporter.export(attrStr)
        XCTAssertTrue(result.contains("&quot;"), "Attribute value should escape quotes: \(result)")
    }
    
    // MARK: - Round-trip fidelity
    
    func testRoundTrip_ExportImportReExport_ProducesSameHTML() {
        let font = UIFont.boldSystemFont(ofSize: 16)
        let attrStr = NSAttributedString(string: "Bold text", attributes: [.font: font])
        let html1 = HTMLExporter.export(attrStr)
        let imported = HTMLImporter.import(html: html1)
        let html2 = HTMLExporter.export(imported)
        // Both exports should contain the same structural tags
        XCTAssertTrue(html2.contains("<strong>"))
        XCTAssertTrue(html2.contains("Bold text"))
    }
    
    // MARK: - EditorContent re-export
    
    func testEditorContent_HTMLInit_ReExportsCorrectly() {
        let content = EditorContent(html: "<p><strong>Hello</strong></p>")
        // html property should be the re-export, not the original input
        XCTAssertTrue(content.html.contains("Hello"))
        XCTAssertTrue(content.attributedString.string.contains("Hello"))
    }
}
