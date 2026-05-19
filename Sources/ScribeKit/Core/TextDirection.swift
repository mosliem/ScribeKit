import Foundation

/// Detects the dominant writing direction of a string using the Unicode bidi rule of
/// first-strong-character. Used by the HTML exporter to emit `dir="rtl"` so list bullets,
/// numbered markers, and Arabic/Hebrew content render on the correct visual edge after
/// the document is round-tripped.
enum TextDirection {

    enum Direction {
        case leftToRight
        case rightToLeft
    }

    /// Returns the direction of the first strong directional character, or `nil` if the
    /// string contains only weak characters (digits, punctuation, whitespace, etc.).
    static func detect(in text: String) -> Direction? {
        for scalar in text.unicodeScalars {
            let value = scalar.value

            // Strong RTL: Hebrew, Arabic, Syriac, Thaana, NKo, Samaritan, Mandaic,
            // Arabic Extended, and the Hebrew/Arabic presentation-forms blocks.
            if (0x0590...0x08FF).contains(value)
                || (0xFB1D...0xFDFF).contains(value)
                || (0xFE70...0xFEFF).contains(value) {
                return .rightToLeft
            }

            // Strong LTR: Latin, Latin Extended, Greek, Cyrillic, Armenian, and CJK.
            if (0x0041...0x005A).contains(value)
                || (0x0061...0x007A).contains(value)
                || (0x00C0...0x024F).contains(value)
                || (0x0370...0x058F).contains(value)
                || (0x4E00...0x9FFF).contains(value) {
                return .leftToRight
            }
        }
        return nil
    }
}
