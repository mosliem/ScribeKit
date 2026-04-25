import SwiftUI
import UIKit

/// The default system-adaptive theme for the editor.
public struct DefaultTheme: EditorTheme {
    public var toolbarBackgroundColor: Color { Color(.secondarySystemBackground) }
    
    public var toolbarButtonColor: Color { Color(.label) }

    public var toolbarActiveButtonColor: Color { Color.accentColor }

    public var editorBackgroundColor: Color { Color(.systemBackground) }

    public var editorTextColor: Color { Color(.label) }

    public var editorFont: UIFont { UIFont.systemFont(ofSize: 16) }

    public var borderColor: Color { Color(.separator) }

    public var cornerRadius: CGFloat { 12 }

    public init() {}
}
