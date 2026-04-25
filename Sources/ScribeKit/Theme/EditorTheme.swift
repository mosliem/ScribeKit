import SwiftUI
import UIKit

/// Protocol that every editor theme must conform to.
/// Themes are passed via the SwiftUI Environment using the `@Entry` macro.
public protocol EditorTheme {
    var toolbarBackgroundColor: Color { get }

    var toolbarButtonColor: Color { get }

    var toolbarActiveButtonColor: Color { get }

    var editorBackgroundColor: Color { get }

    var editorTextColor: Color { get }

    var editorFont: UIFont { get }

    var borderColor: Color { get }

    var cornerRadius: CGFloat { get }
}

// MARK: - Environment Key

extension EnvironmentValues {
    /// Access the active `EditorTheme` from any SwiftUI subview.
    @Entry public var editorTheme: any EditorTheme = DefaultTheme()
}
