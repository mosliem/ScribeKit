import SwiftUI

/// A single group of toolbar actions, separated by dividers.
/// Conforms to `Identifiable` for safe `ForEach` usage — avoids fragile `.offset` identity.
public struct ToolbarGroup: Identifiable, Sendable {
    public let id: String
    public let actions: [EditorToolbarAction]

    public init(id: String, actions: [EditorToolbarAction]) {
        self.id = id
        self.actions = actions
    }
}

/// Defines the layout of the editor toolbar.
public struct ToolbarConfiguration: Sendable {
    /// All groups in display order.
    public let groups: [ToolbarGroup]

    public init(groups: [ToolbarGroup]) {
        self.groups = groups
    }

    /// The default toolbar layout:
    /// Image | Heading | Lists | Alignment | Styles | FontSize | Color | Indent | Link
    public static let `default` = ToolbarConfiguration(groups: [
        ToolbarGroup(id: "image", actions: [.image]),

        ToolbarGroup(id: "heading", actions: [.headingMenu]),

        ToolbarGroup(id: "lists", actions: [.bulletList, .numberedList, .dashList]),

        ToolbarGroup(id: "alignment", actions: [.alignLeading, .alignCenter, .alignTrailing]),

        ToolbarGroup(id: "styles", actions: [.bold, .italic, .underline, .strikethrough]),

        ToolbarGroup(id: "fontSize", actions: [.decreaseFontSize, .increaseFontSize]),

        ToolbarGroup(id: "color", actions: [.textColor, .highlightColor]),

        ToolbarGroup(id: "indent", actions: [.decreaseIndent, .increaseIndent]),

        ToolbarGroup(id: "link", actions: [.link])
    ])

    /// Returns a new configuration filtered to only include actions in the given set.
    public func filtered(to allowedItems: Set<EditorToolbarAction>) -> ToolbarConfiguration {
        let filteredGroups = groups.compactMap { group -> ToolbarGroup? in
            let filtered = group.actions.filter { allowedItems.contains($0) }
            return filtered.isEmpty ? nil : ToolbarGroup(id: group.id, actions: filtered)
        }
        return ToolbarConfiguration(groups: filteredGroups)
    }
}
