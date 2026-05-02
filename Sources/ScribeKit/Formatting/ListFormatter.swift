import UIKit

/// Custom `NSAttributedString.Key` for storing the list style at paragraph level.
extension NSAttributedString.Key {
    static let scribeKitListStyle: NSAttributedString.Key = NSAttributedString.Key(
        "ScribeKit.listStyle")
}

/// Handles all list toggling, detection, marker insertion, auto-continuation, and renumbering.
@MainActor
public struct ListFormatter {
    
    // MARK: - Constants
    
    private static let headIndent: CGFloat = 25
    
    // MARK: - Toggle
    
    /// Toggles the given list style on all paragraphs overlapping the current selection.
    /// - If all paragraphs already have this style → removes markers and exits list mode.
    /// - Otherwise → switches/applies the requested style and renumbers if needed.
    public static func toggleList(_ style: EditorListStyle, in textView: UITextView) {
        let storage = textView.textStorage
        let selectedRange = textView.selectedRange
        let paragraphRange = (storage.string as NSString).paragraphRange(for: selectedRange)

        let currentStyle = detectListStyle(in: storage, at: selectedRange.location)
        let shouldRemove = currentStyle == style

        // For numbered lists, use Arabic-Indic numerals when the active input language is Arabic
        // or when the paragraph content is predominantly Arabic.
        let useArabicNumerals = style == .numbered && isArabicInput(textView)

        storage.beginEditing()

        if shouldRemove {
            removeListing(from: storage, in: paragraphRange)
        } else {
            // If switching types, first remove existing markers
            if currentStyle != nil {
                removeListing(from: storage, in: paragraphRange)
            }
            applyListing(style, to: storage, in: paragraphRange, useArabicNumerals: useArabicNumerals)
        }

        storage.endEditing()

        if style == .numbered && !shouldRemove {
            renumberList(in: storage, around: paragraphRange)
        }
    }
    
    // MARK: - Detection
    
    /// Returns the list style at the given character location, or `nil` if not in a list.
    public static func detectListStyle(in storage: NSAttributedString, at location: Int)
    -> EditorListStyle? {
        guard storage.length > 0 else { return nil }
        let loc = min(location, storage.length - 1)

        // 1. Check custom attribute
        let value = storage.attribute(.scribeKitListStyle, at: loc, effectiveRange: nil) as? String
        if let rawValue = value, let style = EditorListStyle(rawValue: rawValue) {
            return style
        }

        // 2. Fall back to prefix detection
        let paraRange = (storage.string as NSString).paragraphRange(
            for: NSRange(location: loc, length: 0))
        let paraText = (storage.string as NSString).substring(with: paraRange)
        if paraText.hasPrefix("• ") { return .bullet }
        if paraText.hasPrefix("- ") { return .dash }
        let numberedPattern = try? NSRegularExpression(pattern: #"^\d+\. "#)
        if numberedPattern?.firstMatch(
            in: paraText, range: NSRange(paraText.startIndex..., in: paraText)) != nil {
            return .numbered
        }
        // Arabic-Indic digits (U+0660–U+0669)
        let arabicNumberedPattern = try? NSRegularExpression(pattern: "^[٠-٩]+\\. ")
        if arabicNumberedPattern?.firstMatch(
            in: paraText, range: NSRange(paraText.startIndex..., in: paraText)) != nil {
            return .numbered
        }
        return nil
    }
    
    // MARK: - Enter Key Handling
    
    /// Called from `shouldChangeTextIn` when the user presses Enter.
    /// Returns `true` if the event was handled (the caller should return `false` to suppress the default newline).
    @discardableResult
    public static func handleEnter(in textView: UITextView) -> Bool {
        let storage = textView.textStorage
        let selectedRange = textView.selectedRange
        guard selectedRange.location > 0 else { return false }

        let paraRange = (storage.string as NSString).paragraphRange(for: selectedRange)
        guard let style = detectListStyle(in: storage, at: selectedRange.location) else { return false }

        // Get the line text (strip trailing \n)
        let paraText = (storage.string as NSString).substring(with: paraRange).trimmingCharacters(
            in: .newlines)

        // Preserve the existing numeral style: if the current marker uses Arabic-Indic digits,
        // continue with Arabic-Indic on the new item.
        let useArabicNumerals = style == .numbered && isArabicIndicMarker(in: paraText)

        // Determine the current marker
        let itemIndex = currentItemIndex(in: storage, at: selectedRange.location, style: style)
        let currentMarker = style.marker(forIndex: max(1, itemIndex), useArabicNumerals: useArabicNumerals)

        // If the paragraph contains ONLY the marker → exit list mode
        if paraText == currentMarker.trimmingCharacters(in: .whitespaces) || paraText == currentMarker {
            // Remove the marker and exit list
            storage.beginEditing()
            let strippedRange = NSRange(location: paraRange.location, length: paraRange.length)
            storage.replaceCharacters(in: strippedRange, with: "\n")
            storage.removeAttribute(
                .scribeKitListStyle, range: NSRange(location: paraRange.location, length: 1))
            storage.endEditing()
            textView.selectedRange = NSRange(location: paraRange.location + 1, length: 0)
            return true
        }

        // Insert newline + next marker
        let nextIndex = itemIndex + 1
        let nextMarker = style.marker(forIndex: nextIndex, useArabicNumerals: useArabicNumerals)
        let insertionPoint = selectedRange.location
        let insertion = "\n" + nextMarker
        
        // Copy font from current position
        let refLoc = min(insertionPoint - 1, storage.length - 1)
        var insertAttrs: [NSAttributedString.Key: Any] = [:]
        if refLoc >= 0 {
            insertAttrs = storage.attributes(at: refLoc, effectiveRange: nil)
        }
        insertAttrs[.scribeKitListStyle] = style.rawValue
        
        let insertString = NSAttributedString(string: insertion, attributes: insertAttrs)
        storage.beginEditing()
        storage.insert(insertString, at: insertionPoint)
        storage.endEditing()
        
        textView.selectedRange = NSRange(location: insertionPoint + insertion.utf16.count, length: 0)
        
        if style == .numbered {
            let newParaRange = (storage.string as NSString).paragraphRange(for: textView.selectedRange)
            renumberList(in: storage, around: newParaRange)
        }
        
        return true
    }
    
    // MARK: - Renumbering
    
    /// Renumbers all consecutive numbered list items around the affected range.
    public static func renumberList(in storage: NSMutableAttributedString, around range: NSRange) {
        // Find the start of the numbered list block
        var blockStart = range.location
        while blockStart > 0 {
            let prev = blockStart - 1
            let prevParaRange = (storage.string as NSString).paragraphRange(
                for: NSRange(location: prev, length: 0))
            let style =
            storage.attribute(.scribeKitListStyle, at: prevParaRange.location, effectiveRange: nil)
            as? String
            if style == EditorListStyle.numbered.rawValue {
                // Guard against non-progress (Issue #2: infinite loop if prevParaRange.location >= blockStart)
                guard prevParaRange.location < blockStart else { break }
                blockStart = prevParaRange.location
            } else {
                break
            }
        }

        // Renumber from blockStart onward while items belong to the numbered list
        var index = 1
        var location = blockStart

        while location < storage.length {
            let nsString = storage.string as NSString  // re-fetch after mutations
            let paraRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paraRange.length > 0 else { break }  // safety: avoid zero-length infinite loop
            let style =
            storage.attribute(.scribeKitListStyle, at: paraRange.location, effectiveRange: nil)
            as? String
            guard style == EditorListStyle.numbered.rawValue else { break }

            // Replace existing number prefix — preserve the existing numeral script (ASCII or Arabic-Indic).
            let paraText = nsString.substring(with: paraRange)
            let useArabicNumerals = isArabicIndicMarker(in: paraText)
            let asciiMatch = paraText.range(of: #"^\d+\. "#, options: .regularExpression)
            let arabicMatch = useArabicNumerals
                ? paraText.range(of: "^[٠-٩]+\\. ", options: .regularExpression)
                : nil
            if let match = asciiMatch ?? arabicMatch {
                let markerLength = paraText.distance(from: match.lowerBound, to: match.upperBound)
                let adjustedRange = NSRange(location: paraRange.location, length: markerLength)
                let newMarker = EditorListStyle.numbered.marker(
                    forIndex: index, useArabicNumerals: useArabicNumerals)
                let existing = nsString.substring(with: adjustedRange)
                if existing != newMarker {
                    storage.replaceCharacters(in: adjustedRange, with: newMarker)
                }
            }

            index += 1
            // Re-fetch after potential mutation
            let updatedNSString = storage.string as NSString
            let updatedParaRange = updatedNSString.paragraphRange(
                for: NSRange(location: location, length: 0))
            location = updatedParaRange.location + updatedParaRange.length
        }
    }
    
    // MARK: - Private Helpers
    
    private static func applyListing(
        _ style: EditorListStyle, to storage: NSMutableAttributedString, in range: NSRange,
        useArabicNumerals: Bool = false
    ) {
        var index = 0
        var location = range.location
        let endLocation = range.location + range.length

        while location < endLocation && location < storage.length {
            let nsString = storage.string as NSString  // re-fetch after insertions
            let paraRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paraRange.length > 0 else { break }  // safety: avoid zero-length infinite loop
            index += 1
            let marker = style.marker(forIndex: index, useArabicNumerals: useArabicNumerals)

            // Issue #12: check if this paragraph already has a marker — skip if so
            let paraText = nsString.substring(with: paraRange)
            let alreadyHasMarker: Bool = {
                switch style {
                case .bullet: return paraText.hasPrefix("• ")
                case .dash: return paraText.hasPrefix("- ")
                case .numbered:
                    return paraText.range(of: #"^\d+\. "#, options: .regularExpression) != nil
                        || paraText.range(of: "^[٠-٩]+\\. ", options: .regularExpression) != nil
                }
            }()
            
            if !alreadyHasMarker {
                // Insert marker at the start of the paragraph
                let markerAttrs: [NSAttributedString.Key: Any] = [
                    .scribeKitListStyle: style.rawValue,
                    .paragraphStyle: indentedStyle()
                ]
                let markerString = NSAttributedString(string: marker, attributes: markerAttrs)
                storage.insert(markerString, at: paraRange.location)
            }
            
            // Mark the whole paragraph with the list attribute
            let updatedNSString = storage.string as NSString
            let updatedParaRange = updatedNSString.paragraphRange(
                for: NSRange(location: location, length: 0))
            storage.addAttribute(.scribeKitListStyle, value: style.rawValue, range: updatedParaRange)
            
            location = updatedParaRange.location + updatedParaRange.length
        }
    }
    
    private static func removeListing(from storage: NSMutableAttributedString, in range: NSRange) {
        var location = range.location
        let endLocation = range.location + range.length
        
        while location < endLocation && location < storage.length {
            let nsString = storage.string as NSString  // re-fetch after mutations
            let paraRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paraRange.length > 0 else { break }  // safety
            let paraText = nsString.substring(with: paraRange)
            
            // Remove known markers (Issue #4: compute marker length directly, not via substring NSRange conversion)
            for style in EditorListStyle.allCases {
                if style == .numbered {
                    // Try both ASCII and Arabic-Indic numbered patterns
                    let match = paraText.range(of: #"^\d+\. "#, options: .regularExpression)
                        ?? paraText.range(of: "^[٠-٩]+\\. ", options: .regularExpression)
                    if let match {
                        let markerLength = paraText.distance(from: match.lowerBound, to: match.upperBound)
                        storage.replaceCharacters(
                            in: NSRange(location: paraRange.location, length: markerLength), with: "")
                        break
                    }
                } else {
                    let marker = style.marker(forIndex: 1)
                    if paraText.hasPrefix(marker) {
                        storage.replaceCharacters(
                            in: NSRange(location: paraRange.location, length: marker.utf16.count), with: "")
                        break
                    }
                }
            }
            
            // Remove paragraph style indentation and list attribute (re-fetch after mutation)
            let updatedNSString = storage.string as NSString
            let updatedParaRange = updatedNSString.paragraphRange(
                for: NSRange(location: location, length: 0))
            storage.removeAttribute(.scribeKitListStyle, range: updatedParaRange)
            let defaultStyle = NSMutableParagraphStyle()
            storage.addAttribute(.paragraphStyle, value: defaultStyle, range: updatedParaRange)
            
            location = updatedParaRange.location + updatedParaRange.length
        }
    }
    
    private static func indentedStyle() -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.headIndent = headIndent
        style.firstLineHeadIndent = 0
        return style
    }

    /// Returns `true` when the paragraph text starts with an Arabic-Indic digit (U+0660–U+0669),
    /// indicating the numbered list uses Arabic-Indic numeral style.
    private static func isArabicIndicMarker(in text: String) -> Bool {
        guard let first = text.unicodeScalars.first else { return false }
        return first.value >= 0x0660 && first.value <= 0x0669
    }

    /// Returns `true` when the active keyboard language is Arabic or the paragraph content
    /// at `location` is predominantly Arabic script.
    private static func isArabicInput(_ textView: UITextView) -> Bool {
        // Primary signal: the active input language
        if let lang = textView.textInputMode?.primaryLanguage, lang.hasPrefix("ar") {
            return true
        }
        // Fallback: scan the current paragraph for Arabic-script characters (U+0600–U+06FF)
        let storage = textView.textStorage
        guard storage.length > 0 else { return false }
        let loc = min(textView.selectedRange.location, storage.length - 1)
        let paraRange = (storage.string as NSString).paragraphRange(
            for: NSRange(location: loc, length: 0))
        let paraText = (storage.string as NSString).substring(with: paraRange)
        for scalar in paraText.unicodeScalars {
            if scalar.value >= 0x0600 && scalar.value <= 0x06FF { return true }
            // Stop scanning at the first non-whitespace character
            if !CharacterSet.whitespacesAndNewlines.contains(scalar) { break }
        }
        return false
    }
    
    private static func currentItemIndex(
        in storage: NSAttributedString, at location: Int, style: EditorListStyle
    ) -> Int {
        guard style == .numbered else { return 1 }
        var count = 0
        var loc = 0
        let nsString = storage.string as NSString
        while loc <= location && loc < storage.length {
            let paraRange = nsString.paragraphRange(for: NSRange(location: loc, length: 0))
            // Issue #3: guard against zero-length paragraphs that would stall the loop
            guard paraRange.length > 0 else { break }
            let attr =
            storage.attribute(.scribeKitListStyle, at: paraRange.location, effectiveRange: nil)
            as? String
            if attr == EditorListStyle.numbered.rawValue {
                count += 1
            }
            let nextLoc = paraRange.location + paraRange.length
            guard nextLoc > loc else { break }  // double-safety
            loc = nextLoc
        }
        return count
    }
}
