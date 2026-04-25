import SwiftUI
import ScribeKit

/// Main content view demonstrating all ScribeKit capabilities.
struct ContentView: View {
    
    @State private var context = EditorContext()
    @State private var showHTMLPreview = false
    @State private var exportedHTML = ""
    @State private var selectedExample: ExamplePage = .basicEditor
    
    enum ExamplePage: String, CaseIterable, Identifiable {
        case basicEditor = "Basic Editor"
        case customToolbar = "Custom Toolbar"
        case readOnly = "Read-Only"
        case customTheme = "Custom Theme"
        case htmlRoundTrip = "HTML Import/Export"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            List(ExamplePage.allCases) { page in
                NavigationLink(page.rawValue, value: page)
            }
            .navigationTitle("ScribeKit Examples")
            .navigationDestination(for: ExamplePage.self) { page in
                switch page {
                case .basicEditor:
                    BasicEditorView()
                case .customToolbar:
                    CustomToolbarView()
                case .readOnly:
                    ReadOnlyView()
                case .customTheme:
                    CustomThemeView()
                case .htmlRoundTrip:
                    HTMLRoundTripView()
                }
            }
        }
    }
}

// MARK: - 1. Basic Editor

/// The simplest possible integration — just an `EditorContext` and a `ScribeEditor`.
struct BasicEditorView: View {
    
    @State private var context = EditorContext()
    @State private var showHTML = false
    @State private var exportedHTML = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScribeEditor(context: context)
                    .frame(minHeight: 300)
                    .padding(.horizontal)
                
                Button {
                    exportedHTML = context.exportHTML()
                    showHTML = true
                } label: {
                    Label("Export HTML", systemImage: "doc.richtext")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Basic Editor")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showHTML) {
                HTMLPreviewSheet(html: exportedHTML)
            }
        }
    }
}

// MARK: - 2. Custom Toolbar

/// Shows how to restrict toolbar actions and set a character limit.
struct CustomToolbarView: View {
    
    @State private var context = EditorContext()
    
    /// Only show bold, italic, and link — no lists, alignment, images, or strikethrough.
    private let config = EditorConfiguration(
        allowedToolbarItems: [.bold, .italic, .underline, .link],
        placeholder: "Write a comment…",
        maxLength: 280
    )
    
    var body: some View {
        VStack(spacing: 16) {
            ScribeEditor(context: context, configuration: config)
                .frame(minHeight: 250)
                .padding(.horizontal)
            
            // Live character count
            HStack {
                let count = context.attributedText.string.count
                Text("\(count) / 280")
                    .foregroundStyle(count > 260 ? .red : .secondary)
                    .monospacedDigit()
                Spacer()
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Custom Toolbar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 3. Read-Only

/// Demonstrates loading HTML content and displaying it in read-only mode.
struct ReadOnlyView: View {
    
    @State private var context = EditorContext()
    
    private let config = EditorConfiguration(isEditable: false)
    
    private let sampleHTML = """
    <p><strong>ScribeKit</strong> is a modular rich text editor for SwiftUI.</p>
    <p>It supports <em>italic</em>, <u>underline</u>, <s>strikethrough</s>, and <strong>bold</strong> formatting.</p>
    <ul>
    <li>Bullet lists</li>
    <li>Numbered lists</li>
    <li>Dash lists</li>
    </ul>
    <p>Links work too: <a href="https://github.com">GitHub</a></p>
    <p style="text-align:center;">This paragraph is centered.</p>
    """
    
    var body: some View {
        VStack(spacing: 16) {
            ScribeEditor(context: context, configuration: config)
                .frame(minHeight: 350)
                .padding(.horizontal)
            
            Text("The editor above is read-only. Try the basic editor to edit content.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Read-Only")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            context.setContent(html: sampleHTML)
        }
    }
}

// MARK: - 4. Custom Theme

/// Demonstrates creating and applying a custom `EditorTheme`.
struct OceanTheme: EditorTheme {
    var toolbarBackgroundColor: Color { Color(red: 0.05, green: 0.1, blue: 0.2) }
    var toolbarButtonColor: Color { Color(red: 0.6, green: 0.8, blue: 0.9) }
    var toolbarActiveButtonColor: Color { Color(red: 0.3, green: 0.9, blue: 0.7) }
    var editorBackgroundColor: Color { Color(red: 0.06, green: 0.12, blue: 0.22) }
    var editorTextColor: Color { Color(red: 0.85, green: 0.92, blue: 0.97) }
    var editorFont: UIFont { UIFont(name: "Georgia", size: 17) ?? .systemFont(ofSize: 17) }
    var borderColor: Color { Color(red: 0.2, green: 0.4, blue: 0.5) }
    var cornerRadius: CGFloat { 16 }
}

struct CustomThemeView: View {
    
    @State private var context = EditorContext()
    @State private var useOceanTheme = true
    
    private var currentTheme: any EditorTheme {
        useOceanTheme ? OceanTheme() : DefaultTheme()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ScribeEditor(context: context)
                .environment(\.editorTheme, currentTheme)
                .frame(minHeight: 300)
                .padding(.horizontal)
            
            Toggle("Ocean Theme", isOn: $useOceanTheme)
                .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Custom Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 5. HTML Import / Export Round-Trip

/// Shows importing HTML, editing it, then exporting back to HTML.
struct HTMLRoundTripView: View {
    
    @State private var context = EditorContext()
    @State private var htmlInput =
    "<p><strong>Hello</strong> <em>World</em></p>\n<ul>\n<li>Item one</li>\n<li>Item two</li>\n</ul>"
    @State private var htmlOutput = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Input
                Text("HTML Input")
                    .font(.headline)
                    .padding(.horizontal)
                
                TextEditor(text: $htmlInput)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                    .padding(.horizontal)
                
                Button("Load into Editor") {
                    context.setContent(html: htmlInput)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                
                // Editor
                Text("Editor")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScribeEditor(context: context)
                    .frame(minHeight: 250)
                    .padding(.horizontal)
                
                Button("Export HTML") {
                    htmlOutput = context.exportHTML()
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                
                // Output
                if !htmlOutput.isEmpty {
                    Text("HTML Output")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal) {
                        Text(htmlOutput)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("HTML Round-Trip")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - HTML Preview Sheet

struct HTMLPreviewSheet: View {
    
    let html: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(html)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Exported HTML")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = html
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}
