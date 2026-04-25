# ScribeKit

A modular, RTL-aware rich text editor for SwiftUI. Built as a Swift Package targeting **iOS 18+** and **Swift 6.0**.

ScribeKit wraps `UITextView` in a `UIViewRepresentable` to deliver rich text editing with a configurable toolbar, theme system, and full HTML import/export — all driven by `@Observable` state management for zero-lag SwiftUI integration.

## Features

- **Text Formatting** — Bold, italic, underline, strikethrough
- **Headings** — H1, H2, H3 with automatic font sizing
- **Paragraph Alignment** — Leading, center, trailing (RTL-aware)
- **Lists** — Bullet, numbered, and dash lists with auto-continuation and renumbering
- **Font Size** — Increase/decrease in 2pt steps, clamped to 8–96pt
- **Text & Highlight Color** — Inline color picker for foreground and background
- **Indentation** — Increase/decrease in 25pt steps, up to 250pt
- **Links** — Insert, edit, detect, and remove hyperlinks
- **Images** — Memory-efficient insertion via `CGImageSource` downsampling
- **HTML Export/Import** — Semantic HTML with round-trip fidelity
- **Theming** — Protocol-based theme system injected via SwiftUI Environment
- **Configurable Toolbar** — Choose which actions to display
- **Placeholder Text** — Shows when the editor is empty
- **Character Limit** — Optional `maxLength` enforcement
- **Paste Mode** — Control paste behaviour: rich, plain text, or user-choice menu per paste
- **Word Count Bar** — Optional live word and character count
- **Read-Only Mode** — Set `isEditable: false` for display-only

## Requirements

| Requirement | Minimum |
|-------------|---------|
| iOS         | 18.0    |
| Swift       | 6.0     |
| Xcode       | 16.0    |

## Installation

### Swift Package Manager

Add ScribeKit to your project via Xcode:

1. **File → Add Package Dependencies…**
2. Enter the repository URL
3. Select your version rule and add to your target

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/ScribeKit.git", from: "0.2.0")
]
```

Then add `"ScribeKit"` to your target's dependencies:

```swift
.target(
    name: "MyApp",
    dependencies: ["ScribeKit"]
)
```

## Quick Start

```swift
import SwiftUI
import ScribeKit

struct MyView: View {
    @State private var context = EditorContext()

    var body: some View {
        ScribeEditor(context: context)
    }
}
```

That's it. You get a full rich text editor with toolbar, placeholder, and all formatting actions enabled by default.

## Usage Guide

### Basic Editor

```swift
import ScribeKit

struct NoteEditorView: View {
    @State private var context = EditorContext()

    var body: some View {
        VStack {
            ScribeEditor(context: context)
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

ScribeEditor(context: context, configuration: config)
```

**Available toolbar actions:**

| Action | Description |
|--------|-------------|
| `.bold` | Toggle bold |
| `.italic` | Toggle italic |
| `.underline` | Toggle underline |
| `.strikethrough` | Toggle strikethrough |
| `.headingMenu` | H1 / H2 / H3 / Body picker |
| `.alignLeading` | Align text leading |
| `.alignCenter` | Align text center |
| `.alignTrailing` | Align text trailing |
| `.bulletList` | Toggle bullet list |
| `.numberedList` | Toggle numbered list |
| `.dashList` | Toggle dash list |
| `.decreaseFontSize` | Decrease font size by 2pt |
| `.increaseFontSize` | Increase font size by 2pt |
| `.textColor` | Set foreground color |
| `.highlightColor` | Set highlight/background color |
| `.decreaseIndent` | Decrease indentation |
| `.increaseIndent` | Increase indentation |
| `.link` | Insert/edit hyperlink |
| `.image` | Insert image from photo library |

### Word Count Bar

```swift
let config = EditorConfiguration(showsWordCount: true)

ScribeEditor(context: context, configuration: config)
```

### Read-Only Mode

```swift
let config = EditorConfiguration(isEditable: false)

ScribeEditor(context: context, configuration: config)
    .onAppear {
        context.setContent(html: "<p><strong>Hello</strong> World</p>")
    }
```

### HTML Import & Export

```swift
// Import HTML into the editor
context.setContent(html: "<p><em>Welcome</em> to ScribeKit</p>")

// Export the current content as HTML
let html = context.exportHTML()
// → "<p><em>Welcome</em> to ScribeKit</p>"

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

// Headings
context.setHeading(.heading1)   // apply H1 (calling again toggles back to body)
context.setHeading(nil)         // revert to body

// Font size
context.increaseFontSize()      // +2pt
context.decreaseFontSize()      // -2pt

// Colors
context.setForegroundColor(.red)
context.setHighlightColor(.yellow)
context.setHighlightColor(nil)  // remove highlight

// Indentation
context.increaseIndent()
context.decreaseIndent()

// Set alignment
context.setAlignment(.center)

// Toggle lists
context.toggleList(.bullet)
context.toggleList(.numbered)

// Links
context.insertLink()            // Opens link sheet
context.commitLink(url: "https://example.com", displayText: "Example")
context.removeLink()

// Images
context.insertImage()           // Opens photo picker
```

### Paste Mode

Control how pasted content is inserted via the `pasteMode` property on `EditorConfiguration`:

```swift
// Always paste rich (default)
let config = EditorConfiguration(pasteMode: .rich)

// Always strip formatting — pastes using the current typing attributes
let config = EditorConfiguration(pasteMode: .plainText)

// Let the user decide per paste via a context menu
let config = EditorConfiguration(pasteMode: .userChoice)

ScribeEditor(context: context, configuration: config)
```

| Mode | Behaviour |
|------|-----------|
| `.rich` | Preserves all formatting from the pasteboard (default) |
| `.plainText` | Strips formatting; inserts plain text with current typing attributes |
| `.userChoice` | Long-press paste shows **"Paste"** and **"Paste as Plain Text"** menu items |

The system **"Paste and Match Style"** action always strips formatting regardless of `pasteMode`.

### Custom Theme

Create a struct conforming to `EditorTheme` and inject it via the environment:

```swift
struct DarkOceanTheme: EditorTheme {
    var toolbarBackgroundColor: Color   { Color(red: 0.05, green: 0.1, blue: 0.2) }
    var toolbarButtonColor: Color       { Color(red: 0.6, green: 0.8, blue: 0.9) }
    var toolbarActiveButtonColor: Color { Color(red: 0.3, green: 0.9, blue: 0.7) }
    var editorBackgroundColor: Color    { Color(red: 0.06, green: 0.12, blue: 0.22) }
    var editorTextColor: Color          { Color(red: 0.85, green: 0.92, blue: 0.97) }
    var editorFont: UIFont              { UIFont(name: "Georgia", size: 17) ?? .systemFont(ofSize: 17) }
    var borderColor: Color              { Color(red: 0.2, green: 0.4, blue: 0.5) }
    var cornerRadius: CGFloat           { 16 }
}

// Apply the theme
ScribeEditor(context: context)
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
            if let heading = context.currentHeadingStyle {
                Text(heading.displayName)
            }
            Text("\(context.wordCount) words")
        }
    }
}
```

**Observable properties:**

| Property | Type | Description |
|----------|------|-------------|
| `activeStyles` | `Set<TextStyle>` | Active styles at cursor |
| `currentAlignment` | `RichTextAlignment` | Alignment of current paragraph |
| `currentListStyle` | `EditorListStyle?` | List style at cursor, or `nil` |
| `currentHeadingStyle` | `EditorHeadingStyle?` | Heading level at cursor, or `nil` |
| `currentFontSize` | `CGFloat` | Font size at cursor |
| `currentForegroundColor` | `Color?` | Text color at cursor, or `nil` |
| `currentHighlightColor` | `Color?` | Highlight color at cursor, or `nil` |
| `currentLink` | `String?` | URL of link at cursor, or `nil` |
| `wordCount` | `Int` | Live word count |
| `characterCount` | `Int` | Live character count |
| `attributedText` | `NSAttributedString` | Current content (computed, O(1)) |


## License

MIT
