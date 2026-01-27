import Foundation
import AppKit

/// Errors that can occur during image operations
enum ImageError: LocalizedError {
    case noSecurityAccess(URL)
    case failedToCreateAssetsFolder(Error)
    case failedToCopyImage(Error)
    case failedToSaveImageData(Error)
    case unsupportedImageFormat
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .noSecurityAccess(let url):
            return "No security-scoped access to \(url.path)"
        case .failedToCreateAssetsFolder(let error):
            return "Failed to create assets folder: \(error.localizedDescription)"
        case .failedToCopyImage(let error):
            return "Failed to copy image: \(error.localizedDescription)"
        case .failedToSaveImageData(let error):
            return "Failed to save image data: \(error.localizedDescription)"
        case .unsupportedImageFormat:
            return "Unsupported image format"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}

class FileService {

    /// Supported image file extensions
    static let supportedImageExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "tif", "webp", "heic"]

    func watchFile(_ url: URL, onChange: @escaping () -> Void) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: .main
        )
        
        source.setEventHandler {
            onChange()
        }
        
        source.resume()
    }
    
    func save(content: String, to url: URL) throws {
        // Ensure we have security-scoped access to the parent directory
        guard SecurityScopeManager.shared.ensureAccess(for: url) else {
            throw NSError(
                domain: "FileServiceError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No security-scoped access to save file at \(url.path)"]
            )
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func read(from url: URL) throws -> String {
        // Ensure we have security-scoped access to the parent directory
        guard SecurityScopeManager.shared.ensureAccess(for: url) else {
            throw NSError(
                domain: "FileServiceError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No security-scoped access to read file at \(url.path)"]
            )
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Image Handling

    /// Copy an image file to the assets folder relative to a document.
    /// - Parameters:
    ///   - sourceURL: The URL of the source image file
    ///   - documentURL: The URL of the document (used to find the parent folder for assets)
    /// - Returns: The relative path for use in Markdown (e.g., "assets/image-1234567890.png")
    func copyImageToAssets(from sourceURL: URL, relativeTo documentURL: URL) throws -> String {
        let documentFolder = documentURL.deletingLastPathComponent()
        let assetsFolder = documentFolder.appendingPathComponent("assets")

        // Ensure we have security-scoped access
        guard SecurityScopeManager.shared.ensureAccess(for: assetsFolder) else {
            throw ImageError.noSecurityAccess(assetsFolder)
        }

        // Create assets folder if needed
        try createAssetsFolderIfNeeded(at: assetsFolder)

        // Get the file extension
        let originalExtension = sourceURL.pathExtension.lowercased()
        guard FileService.supportedImageExtensions.contains(originalExtension) else {
            throw ImageError.unsupportedImageFormat
        }

        // Generate unique filename
        let filename = generateUniqueFilename(
            baseName: sourceURL.deletingPathExtension().lastPathComponent,
            extension: originalExtension,
            in: assetsFolder
        )

        let destinationURL = assetsFolder.appendingPathComponent(filename)

        // Copy the file
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw ImageError.failedToCopyImage(error)
        }

        return "assets/\(filename)"
    }

    /// Save image data (e.g., from a screenshot paste) to the assets folder.
    /// - Parameters:
    ///   - image: The NSImage to save
    ///   - documentURL: The URL of the document (used to find the parent folder for assets)
    ///   - preferredFormat: The preferred image format (default: png)
    /// - Returns: The relative path for use in Markdown (e.g., "assets/image-1234567890.png")
    func copyImageToAssets(image: NSImage, relativeTo documentURL: URL, preferredFormat: String = "png") throws -> String {
        let documentFolder = documentURL.deletingLastPathComponent()
        let assetsFolder = documentFolder.appendingPathComponent("assets")

        // Ensure we have security-scoped access
        guard SecurityScopeManager.shared.ensureAccess(for: assetsFolder) else {
            throw ImageError.noSecurityAccess(assetsFolder)
        }

        // Create assets folder if needed
        try createAssetsFolderIfNeeded(at: assetsFolder)

        // Convert NSImage to data
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            throw ImageError.invalidImageData
        }

        let imageData: Data?
        let fileExtension: String

        switch preferredFormat.lowercased() {
        case "jpg", "jpeg":
            imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
            fileExtension = "jpg"
        case "gif":
            imageData = bitmapRep.representation(using: .gif, properties: [:])
            fileExtension = "gif"
        case "tiff", "tif":
            imageData = bitmapRep.representation(using: .tiff, properties: [:])
            fileExtension = "tiff"
        default:
            imageData = bitmapRep.representation(using: .png, properties: [:])
            fileExtension = "png"
        }

        guard let data = imageData else {
            throw ImageError.invalidImageData
        }

        // Generate unique filename with timestamp
        let filename = generateUniqueFilename(
            baseName: "image-\(Int(Date().timeIntervalSince1970 * 1000))",
            extension: fileExtension,
            in: assetsFolder
        )

        let destinationURL = assetsFolder.appendingPathComponent(filename)

        // Write the data
        do {
            try data.write(to: destinationURL)
        } catch {
            throw ImageError.failedToSaveImageData(error)
        }

        return "assets/\(filename)"
    }

    // MARK: - Private Helpers

    /// Create the assets folder if it doesn't exist.
    private func createAssetsFolderIfNeeded(at assetsFolder: URL) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: assetsFolder.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                // A file exists with the name "assets", which is a problem
                throw ImageError.failedToCreateAssetsFolder(
                    NSError(
                        domain: "FileServiceError",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "A file named 'assets' already exists and is not a directory"]
                    )
                )
            }
            // Directory already exists
            return
        }

        do {
            try fileManager.createDirectory(at: assetsFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw ImageError.failedToCreateAssetsFolder(error)
        }
    }

    /// Generate a unique filename in the given folder.
    /// If the base name already exists, appends a number (e.g., "image-2.png").
    private func generateUniqueFilename(baseName: String, extension ext: String, in folder: URL) -> String {
        let fileManager = FileManager.default
        var filename = "\(baseName).\(ext)"
        var counter = 1

        while fileManager.fileExists(atPath: folder.appendingPathComponent(filename).path) {
            filename = "\(baseName)-\(counter).\(ext)"
            counter += 1
        }

        return filename
    }
}
