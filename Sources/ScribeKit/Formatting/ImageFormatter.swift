import UIKit

/// Handles image insertion into the editor via downsampled `NSTextAttachment`.
@MainActor
public struct ImageFormatter {
    
    // MARK: - Insert
    
    /// Inserts a downsampled image attachment at the current cursor position.
    /// - Parameters:
    ///   - imageData: Raw image data (JPEG / PNG / HEIF, etc.).
    ///   - textView: The target text view.
    public static func insertImage(data imageData: Data, in textView: UITextView) {
        let targetWidth =
        textView.bounds.width - textView.textContainerInset.left - textView.textContainerInset.right - 10
        
        guard let image = downsample(data: imageData, toFit: targetWidth) else { return }
        guard image.size.width > 0 else { return }
        
        let attachment = NSTextAttachment()
        attachment.image = image
        // Scale to editor width
        let aspectRatio = image.size.height / image.size.width
        attachment.bounds = CGRect(x: 0, y: 0, width: targetWidth, height: targetWidth * aspectRatio)
        
        let attachmentString = NSMutableAttributedString(attachment: attachment)
        // Surround with newlines for editing comfort
        attachmentString.insert(NSAttributedString(string: "\n"), at: 0)
        attachmentString.append(NSAttributedString(string: "\n"))
        
        let selectedRange = textView.selectedRange
        textView.textStorage.beginEditing()
        textView.textStorage.insert(attachmentString, at: selectedRange.location)
        textView.textStorage.endEditing()
        
        textView.selectedRange = NSRange(
            location: selectedRange.location + attachmentString.length, length: 0)
    }
    
    // MARK: - Downsampling
    
    /// Downsamples image data to a target display width using `CGImageSource` for memory efficiency.
    /// Avoids decoding the full-resolution image into `UIImage` first.
    public static func downsample(data: Data, toFit maxWidth: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        
        let scale = UIScreen.main.scale
        let thumbnailMaxDimension = maxWidth * scale
        
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxDimension
        ]
        
        guard
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
        else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
