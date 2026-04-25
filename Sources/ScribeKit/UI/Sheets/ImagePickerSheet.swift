import PhotosUI
import SwiftUI

/// Sheet for picking a photo from the library.
/// Loads the image data asynchronously then delivers it to `EditorContext` on the MainActor.
///
/// Design note: `.photosPickerStyle(.inline)` renders its own full navigation chrome
/// (Cancel, Photos/Collections tabs, search bar). No custom header is added here to
/// avoid a duplicate title bar. The sheet is dismissed by swiping down (default iOS
/// sheet behaviour) or automatically after a successful image selection.
public struct ImagePickerSheet: View {
    
    let onImagePicked: (Data) -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Environment(\.dismiss) private var dismiss
    
    public init(onImagePicked: @escaping (Data) -> Void) {
        self.onImagePicked = onImagePicked
    }
    
    public var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading image…")
                    Spacer()
                }
            } else {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    EmptyView()
                }
                .photosPickerStyle(.inline)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .alert("Image Load Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            isLoading = true
            Task {
                await loadImage(from: newItem)
            }
        }
    }
    
    // MARK: - Private
    
    private func loadImage(from item: PhotosPickerItem) async {
        defer { isLoading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "The selected image could not be loaded. Please try another photo."
                showError = true
                return
            }
            await MainActor.run {
                onImagePicked(data)
                dismiss()
            }
        } catch {
            errorMessage = "Failed to load image: \(error.localizedDescription)"
            showError = true
        }
    }
}
