import UIKit

/// Converts an HTML string into an `NSAttributedString` compatible with the editor.
@MainActor
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

        // Convert <ul>/<ol>/<li> to <p>-with-prefix paragraphs BEFORE handing to the system
        // HTML parser. The system parser converts list markup into NSTextList-based paragraph
        // styles, which conflict with ScribeKit's text-prefix model and cause two failure modes:
        //   1. Double bullets — NSTextList renders a bullet AND the text starts with "• "
        //   2. Silent list loss — no text prefix means postProcessListMarkers misses the item,
        //      the exporter emits <p> instead of <li>, and bullets vanish on the next reload.
        let preprocessed = preprocessLists(in: html)

        guard let data = preprocessed.data(using: .utf8) else { return NSAttributedString() }

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

    // MARK: - List Pre-Process

    /// Converts `<ul>`, `<ol>`, and `<li>` markup into plain `<p>` paragraphs with
    /// inline text-prefix markers before the string is handed to the system HTML parser.
    private static func preprocessLists(in html: String) -> String {
        var result = html
        // Order matters: process more-specific patterns before generic <ul>.
        result = replaceList(result, style: .numbered)
        result = replaceList(result, style: .dash)    // <ul data-style="dash">
        result = replaceList(result, style: .bullet)  // plain <ul>
        return result
    }

    /// Finds all list blocks matching `style` and replaces each with `<p>marker content</p>` lines.
    private static func replaceList(_ html: String, style: EditorListStyle) -> String {
        // Build a pattern for the opening tag that is specific to each list style.
        let openPattern: String
        let closeTag: String
        switch style {
        case .numbered:
            openPattern = #"<ol\b[^>]*>"#
            closeTag = "</ol>"
        case .dash:
            // Only match <ul> that carries data-style="dash" (written by our exporter).
            openPattern = #"<ul\b[^>]*\bdata-style="dash"[^>]*>"#
            closeTag = "</ul>"
        case .bullet:
            // Match any <ul> that does NOT carry data-style (dash was already handled above).
            openPattern = #"<ul\b(?![^>]*data-style)[^>]*>"#
            closeTag = "</ul>"
        }

        let escapedClose = NSRegularExpression.escapedPattern(for: closeTag)
        // Capture the opening tag in group 1 so we can inspect its attributes (e.g. arabic-indic).
        // For <li>, capture its attribute span (group 1) and its content (group 2) so style
        // and dir attributes survive the round-trip through the system HTML parser.
        guard
            let listRegex = try? NSRegularExpression(
                pattern: "(\(openPattern))([\\s\\S]*?)\(escapedClose)",
                options: .caseInsensitive),
            let liRegex = try? NSRegularExpression(
                pattern: #"<li\b([^>]*)>([\s\S]*?)</li>"#,
                options: .caseInsensitive)
        else { return html }

        var result = html

        // Replace one block per iteration; re-scan after each mutation so NSRange offsets stay valid.
        while true {
            let ns = result as NSString
            guard
                let match = listRegex.firstMatch(
                    in: result, range: NSRange(location: 0, length: ns.length)),
                match.range(at: 2).location != NSNotFound
            else { break }

            // Group 1 = opening tag, group 2 = inner content
            let openTagText = match.range(at: 1).location != NSNotFound
                ? ns.substring(with: match.range(at: 1)) : ""
            let innerContent = ns.substring(with: match.range(at: 2))
            let nsInner = innerContent as NSString
            let liMatches = liRegex.matches(
                in: innerContent, range: NSRange(location: 0, length: nsInner.length))

            // For numbered lists, use Arabic-Indic markers when the opening tag declares that style.
            let useArabicNumerals = style == .numbered && openTagText.contains("arabic-indic")

            let paragraphs: [String] = liMatches.enumerated().compactMap { index, m in
                guard
                    m.numberOfRanges >= 3,
                    m.range(at: 1).location != NSNotFound,
                    m.range(at: 2).location != NSNotFound
                else { return nil }
                // Forward the <li>'s style/dir attributes onto the surrogate <p> so the
                // system HTML parser keeps text-align and writing direction after import.
                let liAttrs = nsInner.substring(with: m.range(at: 1))
                let content = nsInner.substring(with: m.range(at: 2))
                let marker = style.marker(forIndex: index + 1, useArabicNumerals: useArabicNumerals)
                return "<p\(liAttrs)>\(marker)\(content)</p>"
            }

            result = ns.replacingCharacters(in: match.range, with: paragraphs.joined(separator: "\n"))
        }

        return result
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
            } else if paraText.range(of: #"^\d+\. "#, options: .regularExpression) != nil
                || paraText.range(of: "^[٠-٩]+\\. ", options: .regularExpression) != nil {
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
