import UIKit

/// Converts `NSAttributedString` to a semantic HTML string.
public struct HTMLExporter {

    /// The body font size used as the baseline — runs at this size are not wrapped in a font-size span.
    private static let defaultBodySize: CGFloat = 16

    // MARK: - Public API

    /// Exports an `NSAttributedString` to an HTML string.
    /// Call this explicitly — do not use as a computed property — to avoid triggering
    /// expensive HTML generation during SwiftUI view-body evaluation.
    public static func export(_ attributedString: NSAttributedString) -> String {
        guard attributedString.length > 0 else { return "" }

        var html = ""
        var currentListStyle: EditorListStyle?

        let paragraphs = splitIntoParagraphs(attributedString)

        for paragraph in paragraphs {
            let (paraText, paraAttrs, paraRange) = paragraph
            let listStyle =
            attributedString.attribute(
                .scribeKitListStyle, at: paraRange.location, effectiveRange: nil) as? String
            let editorListStyle = listStyle.flatMap { EditorListStyle(rawValue: $0) }
            let headingStyle =
            attributedString.attribute(
                .scribeKitHeadingStyle, at: paraRange.location, effectiveRange: nil) as? String
            let editorHeadingStyle = headingStyle.flatMap { EditorHeadingStyle(rawValue: $0) }

            // Open/close list tags
            if editorListStyle != currentListStyle {
                if let current = currentListStyle {
                    html += closingTag(for: current)
                }
                if let next = editorListStyle {
                    html += openingTag(for: next)
                }
                currentListStyle = editorListStyle
            }

            let alignment = (paraAttrs[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? .natural
            let alignCSS = cssAlignment(for: alignment)

            let innerHTML = buildInlineHTML(
                for: paraText,
                in: attributedString,
                paragraphRange: paraRange,
                isHeadingParagraph: editorHeadingStyle != nil
            )
            let cleanText = stripListMarker(from: innerHTML)

            if editorListStyle != nil {
                html += "<li>\(cleanText)</li>\n"
            } else if let heading = editorHeadingStyle {
                html += "<\(heading.htmlTag)>\(cleanText)</\(heading.htmlTag)>\n"
            } else {
                let styleAttr = alignCSS.isEmpty ? "" : " style=\"text-align:\(alignCSS);\""
                html += "<p\(styleAttr)>\(cleanText)</p>\n"
            }
        }

        // Close any open list
        if let current = currentListStyle {
            html += closingTag(for: current)
        }

        return html
    }

    // MARK: - Private Helpers

    private typealias ParagraphTuple = (
        text: String, attributes: [NSAttributedString.Key: Any], range: NSRange
    )

    private static func splitIntoParagraphs(_ attrStr: NSAttributedString) -> [ParagraphTuple] {
        var results: [ParagraphTuple] = []
        let nsString = attrStr.string as NSString
        var location = 0

        while location < attrStr.length {
            let paraRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paraRange.length > 0 else { break }
            var text = nsString.substring(with: paraRange)
            if text.hasSuffix("\n") { text = String(text.dropLast()) }
            let attrs = attrStr.attributes(at: paraRange.location, effectiveRange: nil)
            results.append((text, attrs, paraRange))
            location = paraRange.location + paraRange.length
        }

        return results
    }

    private static func buildInlineHTML(
        for text: String,
        in attrStr: NSAttributedString,
        paragraphRange: NSRange,
        isHeadingParagraph: Bool
    ) -> String {
        var result = ""

        attrStr.enumerateAttributes(in: paragraphRange, options: []) { attrs, range, _ in
            let substring = (attrStr.string as NSString).substring(with: range)

            // Image attachment
            if substring == "\u{FFFC}" {
                if let attachment = attrs[.attachment] as? NSTextAttachment,
                   let image = attachment.image {
                    let imageData = image.jpegData(compressionQuality: 0.8)
                    let data = imageData ?? image.pngData()
                    let mime = imageData != nil ? "image/jpeg" : "image/png"
                    if let data {
                        let base64 = data.base64EncodedString()
                        result += "<img src=\"data:\(mime);base64,\(base64)\" />"
                    }
                }
                return
            }

            let escaped = htmlEscapeText(substring)
            var wrapped = escaped

            // Inline styles: bold, italic, underline, strikethrough
            let font = attrs[.font] as? UIFont
            let isBold = font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
            let isItalic = font?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
            let isUnderline = (attrs[.underlineStyle] as? Int ?? 0) != 0
            let isStrikethrough = (attrs[.strikethroughStyle] as? Int ?? 0) != 0

            if isStrikethrough { wrapped = "<s>\(wrapped)</s>" }
            if isUnderline { wrapped = "<u>\(wrapped)</u>" }
            if isItalic { wrapped = "<em>\(wrapped)</em>" }
            if isBold { wrapped = "<strong>\(wrapped)</strong>" }

            // Link
            if let linkValue = attrs[.link] {
                let urlStr: String
                if let url = linkValue as? URL {
                    urlStr = url.absoluteString
                } else {
                    urlStr = linkValue as? String ?? ""
                }
                wrapped = "<a href=\"\(htmlEscapeAttribute(urlStr))\">\(wrapped)</a>"
            }

            // Background / highlight color
            if let bgColor = attrs[.backgroundColor] as? UIColor,
               let hex = hexString(from: bgColor) {
                wrapped = "<span style=\"background-color:\(hex)\">\(wrapped)</span>"
            }

            // Foreground color — skip for links (their color is implied by <a>)
            if attrs[.link] == nil,
               let fgColor = attrs[.foregroundColor] as? UIColor,
               let hex = hexString(from: fgColor) {
                wrapped = "<span style=\"color:\(hex)\">\(wrapped)</span>"
            }

            // Font size — skip for heading paragraphs (the h1/h2/h3 tag implies the size)
            if !isHeadingParagraph,
               let runFont = font,
               runFont.pointSize != defaultBodySize {
                wrapped = "<span style=\"font-size:\(Int(runFont.pointSize))pt\">\(wrapped)</span>"
            }

            result += wrapped
        }

        return result
    }

    private static func stripListMarker(from html: String) -> String {
        var result = html
        for style in EditorListStyle.allCases {
            switch style {
            case .bullet:
                if result.hasPrefix("• ") { result = String(result.dropFirst(2)) }
            case .dash:
                if result.hasPrefix("- ") { result = String(result.dropFirst(2)) }
            case .numbered:
                if let range = result.range(of: #"^\d+\. "#, options: .regularExpression) {
                    result = String(result[range.upperBound...])
                }
            }
        }
        return result
    }

    // MARK: - Color Helpers

    private static func hexString(from color: UIColor) -> String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        // Skip exporting default/system colors that aren't user-applied
        // (system colors like .label return variable RGB; only export fixed RGB colors)
        guard alpha > 0 else { return nil }
        return String(format: "#%02x%02x%02x", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    // MARK: - Escape Helpers

    /// Escapes characters for HTML body text. Only `&`, `<`, `>` need escaping in text nodes.
    private static func htmlEscapeText(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Escapes characters for HTML attribute values. Additionally escapes `"` to prevent
    /// breaking quoted attribute syntax (e.g. `href="..."`).
    private static func htmlEscapeAttribute(_ string: String) -> String {
        htmlEscapeText(string)
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Tag Helpers

    private static func openingTag(for style: EditorListStyle) -> String {
        switch style {
        case .bullet, .dash:
            return "<ul>\n"
        case .numbered:
            return "<ol>\n"
        }
    }

    private static func closingTag(for style: EditorListStyle) -> String {
        switch style {
        case .bullet, .dash:
            return "</ul>\n"
        case .numbered:
            return "</ol>\n"
        }
    }

    private static func cssAlignment(for alignment: NSTextAlignment) -> String {
        switch alignment {
        case .left:
            return "left"
        case .right:
            return "right"
        case .center:
            return "center"
        case .justified:
            return "justify"
        case .natural:
            return ""
        @unknown default:
            return ""
        }
    }
}
