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

    /// The border color shown while the editor is focused. Return `nil` to fall back to
    /// `borderColor` (no distinct focus highlight). Defaults to a light grey.
    var activeBorderColor: Color? { get }

    var cornerRadius: CGFloat { get }
}

// MARK: - Defaults

public extension EditorTheme {
    /// Default active (focused) border color — a light grey. Themes may override or return `nil`.
    var activeBorderColor: Color? { Color(.lightGray) }
}

// MARK: - Environment Key

extension EnvironmentValues {
    /// Access the active `EditorTheme` from any SwiftUI subview.
    @Entry public var editorTheme: any EditorTheme = DefaultTheme()
}
