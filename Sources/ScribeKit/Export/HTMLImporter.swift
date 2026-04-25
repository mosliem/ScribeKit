import UIKit

/// Converts an HTML string into an `NSAttributedString` compatible with the editor.
public struct HTMLImporter {

    /// Font sizes from the system HTML parser at or below this threshold are considered
    /// "browser default body" (≈ 12pt from the 16px browser default) and overridden
    /// to `defaultFont.pointSize`. Sizes above this are considered explicitly set
    /// (headings, user-specified sizes) and are preserved.
    private static let browserDefaultSizeThreshold: CGFloat = 13

    // MARK: - Public API

    /// Imports an HTML string and returns a styled `NSMutableAttributedString`.
    public static func `import`(
        html: String,
        defaultFont: UIFont = UIFont.systemFont(ofSize: 16)
    ) -> NSAttributedString {
        guard !html.isEmpty else { return NSAttributedString() }

        guard let data = html.data(using: .utf8) else { return NSAttributedString() }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard
            let attributed = try? NSMutableAttributedString(
                data: data, options: options, documentAttributes: nil)
        else {
            return NSAttributedString(string: html)
        }

        // Pre-scan: collect heading positions from the raw HTML before the system parser normalises it.
        let headings = extractHeadings(from: html)

        // Override system-parser fonts (Times New Roman default → system font).
        // Preserve font size when it was explicitly set above the browser-default threshold.
        attributed.enumerateAttribute(
            .font, in: NSRange(location: 0, length: attributed.length), options: []
        ) { value, range, _ in
            guard let htmlFont = value as? UIFont else {
                attributed.addAttribute(.font, value: defaultFont, range: range)
                return
            }
            let htmlTraits = htmlFont.fontDescriptor.symbolicTraits
            var descriptor = defaultFont.fontDescriptor
            // Union traits so existing traits on defaultFont aren't lost (Issue #11)
            let mergedTraits = descriptor.symbolicTraits.union(htmlTraits)
            if let merged = descriptor.withSymbolicTraits(mergedTraits) {
                descriptor = merged
            }
            // Preserve font size if above browser-default threshold (heading or explicit size)
            let preservedSize =
            htmlFont.pointSize > browserDefaultSizeThreshold
            ? htmlFont.pointSize
            : defaultFont.pointSize
            let newFont = UIFont(descriptor: descriptor, size: preservedSize)
            attributed.addAttribute(.font, value: newFont, range: range)
        }

        // Post-process: detect text-prefix list markers
        postProcessListMarkers(in: attributed)

        // Post-process: apply heading attributes using the pre-scanned heading positions
        if !headings.isEmpty {
            postProcessHeadings(in: attributed, headings: headings, defaultFont: defaultFont)
        }

        return attributed
    }

    // MARK: - Heading Pre-Scan

    private static func extractHeadings(from html: String) -> [(level: Int, text: String)] {
        var results: [(Int, String)] = []
        let nsHtml = html as NSString
        // Match <h1>...</h1>, <h2>...</h2>, <h3>...</h3> (case-insensitive, attributes on tag allowed)
        guard
            let regex = try? NSRegularExpression(
                pattern: #"<h([1-3])(?:\s[^>]*)?>([^<]*(?:<(?!/?h[1-3](?:\s|>))[^>]*>[^<]*)*)<\/h\1>"#,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            )
        else { return results }
        
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let levelStr = nsHtml.substring(with: match.range(at: 1))
            let rawContent = nsHtml.substring(with: match.range(at: 2))
            // Strip inner HTML tags to get the plain text
            let plainText = rawContent
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let level = Int(levelStr), !plainText.isEmpty {
                results.append((level, plainText))
            }
        }
        
        return results
    }

    // MARK: - Heading Post-Process

    private static func postProcessHeadings(
        in attrStr: NSMutableAttributedString,
        headings: [(level: Int, text: String)],
        defaultFont: UIFont
    ) {
        let nsString = attrStr.string as NSString
        var location = 0
        var headingIterator = headings.makeIterator()
        var nextHeading = headingIterator.next()

        while location < attrStr.length, nextHeading != nil {
            let paraRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paraRange.length > 0 else { break }

            if let (level, headingText) = nextHeading {
                let paraText = nsString.substring(with: paraRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if paraText == headingText, let style = EditorHeadingStyle(rawValue: "h\(level)") {
                    attrStr.addAttribute(.scribeKitHeadingStyle, value: style.rawValue, range: paraRange)
                    // Ensure the heading font is applied (system parser may have used a slightly
                    // different size; our fixed sizes keep round-trips consistent)
                    HeadingFormatter.applyHeadingFont(style, to: attrStr, in: paraRange)
                    nextHeading = headingIterator.next()
                }
            }

            location = paraRange.location + paraRange.length
        }
    }

    // MARK: - List Post-Process

    private static func postProcessListMarkers(in attrStr: NSMutableAttributedString) {
        let nsString = attrStr.string as NSString
        var location = 0

        while location < attrStr.length {
            let paraRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paraRange.length > 0 else { break }
            let paraText = nsString.substring(with: paraRange)

            if paraText.hasPrefix("• ") {
                attrStr.addAttribute(
                    .scribeKitListStyle,
                    value: EditorListStyle.bullet.rawValue,
                    range: paraRange
                )
            } else if paraText.hasPrefix("- ") {
                attrStr.addAttribute(
                    .scribeKitListStyle,
                    value: EditorListStyle.dash.rawValue,
                    range: paraRange
                )
            } else if paraText.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                attrStr.addAttribute(
                    .scribeKitListStyle,
                    value: EditorListStyle.numbered.rawValue,
                    range: paraRange
                )
            }

            location = paraRange.location + paraRange.length
        }
    }
}
