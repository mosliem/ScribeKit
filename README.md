# SwiftyEditor

A modular, RTL-aware rich text editor for SwiftUI. Built as a Swift Package targeting **iOS 18+** and **Swift 6.0**.

SwiftyEditor wraps `UITextView` in a `UIViewRepresentable` to deliver rich text editing with a configurable toolbar, theme system, and full HTML import/export — all driven by `@Observable` state management for zero-lag SwiftUI integration.

## Features

- **Text Formatting** — Bold, italic, underline, strikethrough
- **Paragraph Alignment** — Leading, center, trailing (RTL-aware)
- **Lists** — Bullet, numbered, and dash lists with auto-continuation and renumbering
- **Links** — Insert, edit, detect, and remove hyperlinks
- **Images** — Memory-efficient insertion via `CGImageSource` downsampling
- **HTML Export/Import** — Semantic HTML with round-trip fidelity
- **Theming** — Protocol-based theme system injected via SwiftUI Environment
- **Configurable Toolbar** — Choose which actions to display
- **Placeholder Text** — Shows when the editor is empty
- **Character Limit** — Optional `maxLength` enforcement (counts Swift Characters, not UTF-16)
- **Read-Only Mode** — Set `isEditable: false` for display-only

## Requirements

| Requirement | Minimum |
|-------------|---------|
| iOS         | 18.0    |
| Swift       | 6.0     |
| Xcode       | 16.0    |

## Installation

### Swift Package Manager

Add SwiftyEditor to your project via Xcode:

1. **File → Add Package Dependencies…**
2. Enter the repository URL
3. Select your version rule and add to your target

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/SwiftyEditor.git", from: "1.0.0")
]
```

Then add `"SwiftyEditor"` to your target's dependencies:

```swift
.target(
    name: "MyApp",
    dependencies: ["SwiftyEditor"]
)
```

## Quick Start

```swift
import SwiftUI
import SwiftyEditor

struct MyView: View {
    @State private var context = EditorContext()

    var body: some View {
        SwiftyEditor(context: context)
    }
}
```

That's it. You get a full rich text editor with toolbar, placeholder, and all formatting actions enabled by default.

## Usage Guide

### Basic Editor

```swift
import SwiftyEditor

struct NoteEditorView: View {
    @State private var context = EditorContext()

    var body: some View {
        VStack {
            SwiftyEditor(context: context)
                .frame(minHeight: 300)

            Button("Save") {
                let html = context.exportHTML()
                // Save html to your backend
            }
        }
    }
}
```

### Custom Toolbar

Restrict which toolbar actions are available using `EditorConfiguration`:

```swift
let config = EditorConfiguration(
    allowedToolbarItems: [.bold, .italic, .underline, .link],
    placeholder: "Write a comment…",
    maxLength: 280
)

SwiftyEditor(context: context, configuration: config)
```

**Available toolbar actions:**

| Action | Description |
|--------|-------------|
| `.bold` | Toggle bold |
| `.italic` | Toggle italic |
| `.underline` | Toggle underline |
| `.strikethrough` | Toggle strikethrough |
| `.alignLeading` | Align text leading |
| `.alignCenter` | Align text center |
| `.alignTrailing` | Align text trailing |
| `.bulletList` | Toggle bullet list |
| `.numberedList` | Toggle numbered list |
| `.dashList` | Toggle dash list |
| `.link` | Insert/edit hyperlink |
| `.image` | Insert image from photo library |

### Read-Only Mode

```swift
let config = EditorConfiguration(isEditable: false)

SwiftyEditor(context: context, configuration: config)
    .onAppear {
        context.setContent(html: "<p><strong>Hello</strong> World</p>")
    }
```

### HTML Import & Export

```swift
// Import HTML into the editor
context.setContent(html: "<p><em>Welcome</em> to SwiftyEditor</p>")

// Export the current content as HTML
let html = context.exportHTML()
// → "<p><em>Welcome</em> to SwiftyEditor</p>"

// Snapshot content (attributed string + HTML + plain text)
let content = EditorContent(attributedString: context.attributedText)
print(content.html)       // HTML string
print(content.plainText)  // Plain text without formatting
```

### Programmatic Formatting

You can drive all formatting actions through `EditorContext`:

```swift
// Toggle styles
context.toggleStyle(.bold)
context.toggleStyle(.italic)

// Set alignment
context.setAlignment(.center)

// Toggle lists
context.toggleList(.bullet)
context.toggleList(.numbered)

// Links
context.insertLink()                    // Opens link sheet
context.commitLink(url: "https://example.com", displayText: "Example")
context.removeLink()

// Images
context.insertImage()                   // Opens photo picker
```

### Custom Theme

Create a struct conforming to `EditorTheme` and inject it via the environment:

```swift
struct DarkOceanTheme: EditorTheme {
    var toolbarBackgroundColor: Color { Color(red: 0.05, green: 0.1, blue: 0.2) }
    var toolbarButtonColor: Color     { Color(red: 0.6, green: 0.8, blue: 0.9) }
    var toolbarActiveButtonColor: Color { Color(red: 0.3, green: 0.9, blue: 0.7) }
    var editorBackgroundColor: Color  { Color(red: 0.06, green: 0.12, blue: 0.22) }
    var editorTextColor: Color        { Color(red: 0.85, green: 0.92, blue: 0.97) }
    var editorFont: UIFont            { UIFont(name: "Georgia", size: 17)! }
    var borderColor: Color            { Color(red: 0.2, green: 0.4, blue: 0.5) }
    var cornerRadius: CGFloat         { 16 }
}

// Apply the theme
SwiftyEditor(context: context)
    .environment(\.editorTheme, DarkOceanTheme())
```

**Theme properties:**

| Property | Type | Description |
|----------|------|-------------|
| `toolbarBackgroundColor` | `Color` | Background of the toolbar |
| `toolbarButtonColor` | `Color` | Default button tint |
| `toolbarActiveButtonColor` | `Color` | Tint for active/toggled buttons |
| `editorBackgroundColor` | `Color` | Text view background |
| `editorTextColor` | `Color` | Default text color |
| `editorFont` | `UIFont` | Base font for the editor |
| `borderColor` | `Color` | Border around the editor |
| `cornerRadius` | `CGFloat` | Corner radius for the editor container |

Theme changes are applied at runtime — toggle between themes without recreating the editor.

### Content Loading

```swift
// From HTML
context.setContent(html: "<p>Hello <strong>World</strong></p>")

// From NSAttributedString
let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16)]
let attrStr = NSAttributedString(string: "Bold text", attributes: attrs)
context.setContent(attributedString: attrStr)
```

### Observing State

`EditorContext` is `@Observable`, so you can reactively observe all editor state:

```swift
struct StatusBar: View {
    let context: EditorContext

    var body: some View {
        HStack {
            if context.activeStyles.contains(.bold) {
                Image(systemName: "bold")
            }
            if let link = context.currentLink {
                Text("Link: \(link)")
            }
            Text("\(context.attributedText.string.count) chars")
        }
    }
}
```

**Observable properties:**

| Property | Type | Description |
|----------|------|-------------|
| `activeStyles` | `Set<TextStyle>` | Currently active styles at cursor |
| `currentAlignment` | `RichTextAlignment` | Alignment of current paragraph |
| `currentListStyle` | `EditorListStyle?` | List style at cursor, or `nil` |
| `currentLink` | `String?` | URL of link at cursor, or `nil` |
| `activeSheet` | `EditorSheet?` | Currently presented sheet |
| `attributedText` | `NSAttributedString` | Current content (computed, O(1)) |

## Architecture

```
SwiftyEditor (View)
├── EditorToolbar (View)
│   └── ToolbarButtonView × N
├── EditorTextView (UIViewRepresentable)
│   ├── UITextView
│   └── EditorCoordinator (UITextViewDelegate)
└── Sheet (LinkInputSheet | ImagePickerSheet)

EditorContext (@Observable, @MainActor)
├── activeStyles, currentAlignment, currentListStyle, currentLink
├── toggleStyle(), setAlignment(), toggleList(), insertLink(), ...
├── setContent(html:), exportHTML()
└── syncState() — called by coordinator on every text/selection change

FormattingEngine (stateless struct)
├── toggleStyle(), isStyleActive()
├── setAlignment(), currentAlignment()
└── activeStyles()

ListFormatter (stateless struct)
├── toggleList(), detectListStyle()
├── handleEnter() — auto-continuation / exit
└── renumberList()

LinkFormatter (stateless struct)
├── insertLink(), currentLink(), currentLinkText()
└── removeLink()

ImageFormatter (stateless struct)
├── insertImage(data:in:)
└── downsample(data:toFit:) — CGImageSource

HTMLExporter → export(NSAttributedString) → String
HTMLImporter → import(html:) → NSAttributedString
```

### Key Design Decisions

- **`@Observable` + `@MainActor`** — All state lives on `EditorContext`, which is `@MainActor`-isolated. The coordinator calls `syncState()` directly (no `Task` wrapper) for zero-frame-lag toolbar updates.
- **Stateless formatters** — `FormattingEngine`, `ListFormatter`, `LinkFormatter`, and `ImageFormatter` are pure `struct`s with `static` methods. Fully unit-testable without a `UITextView`.
- **Value-change guards** — `syncState()` only assigns properties when values actually change, preventing unnecessary SwiftUI invalidation on every keystroke.
- **`exportHTML()` is a method, not a computed property** — Avoids triggering expensive HTML generation during SwiftUI body evaluation.
- **Sheet management via enum** — A single `EditorSheet` enum + `.sheet(item:)` replaces multiple boolean flags.

## Example Project

A complete example app is included in the [`Example/`](Example/) directory. Open it in Xcode and run on a simulator to see all features in action:

1. **Basic Editor** — Minimal setup with HTML export
2. **Custom Toolbar** — Restricted actions + character limit
3. **Read-Only** — HTML import in non-editable mode
4. **Custom Theme** — Live theme switching with a toggle
5. **HTML Round-Trip** — Import HTML → edit → export HTML

To run:

```bash
cd Example/
open Package.swift  # Opens in Xcode
# Select an iOS 18+ simulator and press ⌘R
```

## License

MIT
