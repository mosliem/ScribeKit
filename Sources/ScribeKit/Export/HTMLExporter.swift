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
                    // Detect Arabic-Indic numerals from the first character of the paragraph text
                    let isArabicIndic = next == .numbered &&
                        (paraText.unicodeScalars.first.map { $0.value >= 0x0660 && $0.value <= 0x0669 } == true)
                    html += openingTag(for: next, isArabicIndic: isArabicIndic)
                }
                currentListStyle = editorListStyle
            }

            let alignment = (paraAttrs[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? .natural
            let alignCSS = cssAlignment(for: alignment)

            // Build a content range that excludes:
            // 1. The trailing newline — paragraphRange(for:) always includes it, but if the
            //    paragraph carries a foreground color the \n produces a spurious empty span
            //    (e.g. <span style="color:#000000">\n</span>) at the end of every element.
            // 2. For list items, the leading marker text ("• ", "- ", "1. " …) — if the marker
            //    characters carry any attribute (e.g. color) they get wrapped in a <span>,
            //    causing stripListMarker's plain-text hasPrefix check to silently fail and
            //    the marker to leak into <li> content.  On the next import preprocessLists
            //    prepends a second marker, doubling every bullet on each round-trip.
            let markerUTF16 = editorListStyle.map { markerUTF16Length(for: $0, in: paraText) } ?? 0
            let contentRange = NSRange(
                location: paraRange.location + markerUTF16,
                length: max(0, (paraText as NSString).length - markerUTF16)
            )

            let innerHTML = buildInlineHTML(
                for: paraText,
                in: attributedString,
                paragraphRange: contentRange,
                isHeadingParagraph: editorHeadingStyle != nil
            )

            if editorListStyle != nil {
                // Carry alignment onto the <li> itself so the round-trip preserves what the
                // user set in the editor (previously dropped, leaving list items unaligned
                // after reload). Add dir="rtl" for RTL content so the bullet/number marker
                // renders on the correct visual edge regardless of the host page direction.
                let styleAttr = alignCSS.isEmpty ? "" : " style=\"text-align:\(alignCSS);\""
                let dirAttr = TextDirection.detect(in: paraText) == .rightToLeft ? " dir=\"rtl\"" : ""
                html += "<li\(dirAttr)\(styleAttr)>\(innerHTML)</li>\n"
            } else if let heading = editorHeadingStyle {
                html += "<\(heading.htmlTag)>\(innerHTML)</\(heading.htmlTag)>\n"
            } else {
                let styleAttr = alignCSS.isEmpty ? "" : " style=\"text-align:\(alignCSS);\""
                html += "<p\(styleAttr)>\(innerHTML)</p>\n"
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

    /// Returns the number of UTF-16 code units occupied by the list-marker prefix in `text`.
    /// Returns 0 if `text` does not begin with the expected marker for `style`.
    /// Handles both ASCII digits (`1. `) and Arabic-Indic digits (`١. `, U+0660–U+0669).
    private static func markerUTF16Length(for style: EditorListStyle, in text: String) -> Int {
        let ns = text as NSString
        switch style {
        case .bullet:
            // "• " — U+2022 BULLET (BMP, 1 UTF-16 code unit) + SPACE
            return text.hasPrefix("• ") ? 2 : 0
        case .dash:
            // "- " — HYPHEN-MINUS + SPACE
            return text.hasPrefix("- ") ? 2 : 0
        case .numbered:
            // "N. " where N is one or more ASCII (48–57) or Arabic-Indic (U+0660–U+0669) decimal digits.
            // Both code point ranges fit in the BMP so each digit occupies exactly 1 UTF-16 code unit.
            var i = 0
            while i < ns.length {
                let c = ns.character(at: i)
                if (c >= 48 && c <= 57) || (c >= 0x0660 && c <= 0x0669) {
                    i += 1
                } else {
                    break
                }
            }
            guard i > 0, i + 1 < ns.length, ns.character(at: i) == 46, ns.character(at: i + 1) == 32
            else { return 0 }
            return i + 2
        }
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

    private static func openingTag(for style: EditorListStyle, isArabicIndic: Bool = false) -> String {
        switch style {
        case .bullet:
            return "<ul>\n"
        case .dash:
            // data-style attribute lets the importer distinguish dash from bullet on round-trip.
            // Both map to <ul> in HTML but need separate treatment on re-import.
            return "<ul data-style=\"dash\">\n"
        case .numbered:
            // arabic-indic style attribute lets the importer restore the correct numeral script.
            return isArabicIndic ? "<ol style=\"list-style-type: arabic-indic\">\n" : "<ol>\n"
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
