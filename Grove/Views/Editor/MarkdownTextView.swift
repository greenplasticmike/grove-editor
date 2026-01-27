import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var lineSpacing: CGFloat
    @Binding var scrollFraction: CGFloat
    var documentURL: URL?
    @Binding var isFocusMode: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = ImageDropTextView.scrollableTextView()

        // Disable horizontal scrolling on the scroll view
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? ImageDropTextView else {
            return scrollView
        }

        // Set up image drop handling
        textView.imageDropCoordinator = context.coordinator

        // Configure text view for proper wrapping
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Critical: Configure text container for word wrapping
        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
            textContainer.lineFragmentPadding = 5
        }

        // Critical: Text view must not be horizontally resizable for wrapping to work
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        // Frame must match scroll view's content width
        textView.frame.size.width = scrollView.contentSize.width

        // Set min/max size
        textView.minSize = NSSize(width: scrollView.contentSize.width, height: 0)
        textView.maxSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)

        // Appearance
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor

        // Insets for padding
        textView.textContainerInset = NSSize(width: 20, height: 20)

        // Set delegate
        textView.delegate = context.coordinator

        // Apply font and paragraph style
        applyTextAttributes(to: textView)

        // Observe scroll changes
        context.coordinator.scrollView = scrollView
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: scrollView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSScrollView.didEndLiveScrollNotification,
            object: scrollView
        )

        // Restore scroll position after a brief delay to let layout complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.restoreScrollPosition()
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // Keep text view width in sync with scroll view
        let contentWidth = nsView.contentSize.width
        if textView.frame.size.width != contentWidth {
            textView.frame.size.width = contentWidth
            textView.minSize = NSSize(width: contentWidth, height: 0)
            textView.maxSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.containerSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
        }

        // Avoid unnecessary updates that would reset cursor position
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            applyTextAttributes(to: textView)
            textView.selectedRanges = selectedRanges
        }

        // Update font if changed
        if textView.font != font {
            applyTextAttributes(to: textView)
        }

        // Apply or clear focus mode when toggled
        context.coordinator.updateFocusMode(in: textView)
    }

    private func applyTextAttributes(to textView: NSTextView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ]

        textView.typingAttributes = attributes

        // Apply to existing text
        if !textView.string.isEmpty {
            textView.textStorage?.setAttributes(
                attributes,
                range: NSRange(location: 0, length: textView.string.count)
            )
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var scrollView: NSScrollView?
        private var isRestoringScroll = false
        private var currentParagraphRange: NSRange?

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            if parent.isFocusMode {
                currentParagraphRange = nil  // Force re-evaluation since text changed
                updateFocusMode(in: textView)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateFocusMode(in: textView)
        }

        func updateFocusMode(in textView: NSTextView) {
            guard parent.isFocusMode else {
                clearFocusDimming(in: textView)
                return
            }

            let nsString = textView.string as NSString
            guard nsString.length > 0 else { return }

            let cursorLocation = textView.selectedRange().location
            guard cursorLocation <= nsString.length else { return }

            let safeLoc = min(cursorLocation, nsString.length - 1)
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: safeLoc, length: 0))

            // Avoid redundant work if cursor is still in same paragraph
            if let current = currentParagraphRange, current == paragraphRange {
                return
            }
            currentParagraphRange = paragraphRange

            guard let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: nsString.length)

            textStorage.beginEditing()
            // Dim all text
            textStorage.addAttribute(
                .foregroundColor,
                value: NSColor.textColor.withAlphaComponent(0.3),
                range: fullRange
            )
            // Restore current paragraph to full opacity
            textStorage.addAttribute(
                .foregroundColor,
                value: NSColor.textColor.withAlphaComponent(1.0),
                range: paragraphRange
            )
            textStorage.endEditing()

            // Ensure typing attributes have full opacity
            var typingAttrs = textView.typingAttributes
            typingAttrs[.foregroundColor] = NSColor.textColor.withAlphaComponent(1.0)
            textView.typingAttributes = typingAttrs
        }

        func clearFocusDimming(in textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            guard fullRange.length > 0 else { return }
            textStorage.beginEditing()
            textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
            textStorage.endEditing()
            currentParagraphRange = nil
        }

        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard !isRestoringScroll,
                  let scrollView = scrollView,
                  let clipView = scrollView.contentView as? NSClipView,
                  let documentView = scrollView.documentView else { return }

            let documentHeight = documentView.frame.height
            let visibleHeight = clipView.bounds.height
            let scrollableHeight = documentHeight - visibleHeight

            if scrollableHeight > 0 {
                let currentScroll = clipView.bounds.origin.y
                let fraction = currentScroll / scrollableHeight
                DispatchQueue.main.async {
                    self.parent.scrollFraction = min(max(fraction, 0), 1)
                }
            }
        }

        func restoreScrollPosition() {
            guard let scrollView = scrollView,
                  let clipView = scrollView.contentView as? NSClipView,
                  let documentView = scrollView.documentView else { return }

            let documentHeight = documentView.frame.height
            let visibleHeight = clipView.bounds.height
            let scrollableHeight = documentHeight - visibleHeight

            if scrollableHeight > 0 {
                isRestoringScroll = true
                let targetY = parent.scrollFraction * scrollableHeight
                clipView.scroll(to: NSPoint(x: 0, y: targetY))
                scrollView.reflectScrolledClipView(clipView)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isRestoringScroll = false
                }
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // MARK: - Image Drop Handling

        /// Handle an image drop from a file URL
        func handleImageDrop(from url: URL, at insertionPoint: Int, in textView: NSTextView) {
            guard let documentURL = parent.documentURL else {
                print("Cannot handle image drop: no document URL available")
                return
            }

            let fileService = FileService()

            do {
                let relativePath = try fileService.copyImageToAssets(from: url, relativeTo: documentURL)
                insertMarkdownImage(relativePath: relativePath, at: insertionPoint, in: textView)
            } catch {
                print("Failed to copy image: \(error.localizedDescription)")
                showErrorAlert(message: "Failed to import image: \(error.localizedDescription)")
            }
        }

        /// Handle an image drop from raw image data (e.g., screenshot)
        func handleImageDrop(image: NSImage, at insertionPoint: Int, in textView: NSTextView) {
            guard let documentURL = parent.documentURL else {
                print("Cannot handle image drop: no document URL available")
                return
            }

            let fileService = FileService()

            do {
                let relativePath = try fileService.copyImageToAssets(image: image, relativeTo: documentURL)
                insertMarkdownImage(relativePath: relativePath, at: insertionPoint, in: textView)
            } catch {
                print("Failed to save image: \(error.localizedDescription)")
                showErrorAlert(message: "Failed to import image: \(error.localizedDescription)")
            }
        }

        /// Insert Markdown image syntax at the specified location
        private func insertMarkdownImage(relativePath: String, at insertionPoint: Int, in textView: NSTextView) {
            // Use angle brackets for paths with spaces (Markdown standard for URLs with special chars)
            let markdownImage = relativePath.contains(" ") ? "![](<\(relativePath)>)" : "![](\(relativePath))"

            // Insert at the specified position
            let range = NSRange(location: insertionPoint, length: 0)
            if textView.shouldChangeText(in: range, replacementString: markdownImage) {
                textView.replaceCharacters(in: range, with: markdownImage)
                textView.didChangeText()

                // Update the binding
                parent.text = textView.string

                // Move cursor to after the inserted text
                let newPosition = insertionPoint + markdownImage.count
                textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            }
        }

        /// Show an error alert
        private func showErrorAlert(message: String) {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Image Import Error"
                alert.informativeText = message
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}

// MARK: - ImageDropTextView

/// Custom NSTextView subclass that handles image drag and drop
class ImageDropTextView: NSTextView {

    /// Reference to the coordinator for handling image drops
    weak var imageDropCoordinator: MarkdownTextView.Coordinator?

    /// Supported image types for drag and drop
    private static let supportedImageTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .png,
        .tiff,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.gif"),
        NSPasteboard.PasteboardType("public.heic")
    ]

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupDragAndDrop()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }

    private func setupDragAndDrop() {
        // Register for all supported image types
        registerForDraggedTypes(ImageDropTextView.supportedImageTypes)
    }

    /// Create a scrollable text view with our custom ImageDropTextView
    override class func scrollableTextView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let contentSize = scrollView.contentSize
        let textContainer = NSTextContainer(size: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = ImageDropTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        return scrollView
    }

    // MARK: - Keyboard Shortcuts

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Only handle key down events
        guard event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let characters = event.charactersIgnoringModifiers ?? ""

        // Command key shortcuts
        if flags == .command {
            switch characters.lowercased() {
            case "v":
                // Paste: Cmd+V - intercept to handle image paste
                let pasteboard = NSPasteboard.general
                let insertionPoint = selectedRange().location
                if handleImagePasteboard(pasteboard, at: insertionPoint) {
                    return true
                }
                // Fall through to normal paste
                return super.performKeyEquivalent(with: event)

            case "b":
                // Bold: Cmd+B
                MarkdownFormatter.wrapSelection(in: self, with: "**")
                return true

            case "i":
                // Italic: Cmd+I
                MarkdownFormatter.wrapSelection(in: self, with: "*")
                return true

            case "k":
                // Link: Cmd+K
                MarkdownFormatter.insertLink(in: self)
                return true

            case "1":
                // Heading 1: Cmd+1
                MarkdownFormatter.toggleHeading(in: self, level: 1)
                return true

            case "2":
                // Heading 2: Cmd+2
                MarkdownFormatter.toggleHeading(in: self, level: 2)
                return true

            case "3":
                // Heading 3: Cmd+3
                MarkdownFormatter.toggleHeading(in: self, level: 3)
                return true

            case "4":
                // Heading 4: Cmd+4
                MarkdownFormatter.toggleHeading(in: self, level: 4)
                return true

            case "]":
                // Indent: Cmd+]
                MarkdownFormatter.indentLines(in: self)
                return true

            case "[":
                // Outdent: Cmd+[
                MarkdownFormatter.outdentLines(in: self)
                return true

            default:
                break
            }
        }

        // Command+Shift key shortcuts
        if flags == [.command, .shift] {
            switch characters.lowercased() {
            case "k":
                // Code: Cmd+Shift+K
                MarkdownFormatter.wrapSelection(in: self, with: "`")
                return true

            default:
                break
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Drag and Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if containsImageData(sender.draggingPasteboard) {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if containsImageData(sender.draggingPasteboard) {
            return .copy
        }
        return super.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        // Calculate insertion point based on drop location
        let dropPoint = convert(sender.draggingLocation, from: nil)
        let insertionPoint = characterIndexForInsertion(at: dropPoint)

        // Try to handle as image
        if handleImagePasteboard(pasteboard, at: insertionPoint) {
            return true
        }

        // Fall back to default behavior (e.g., text drops)
        return super.performDragOperation(sender)
    }

    // MARK: - Paste Handling

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        // Get the current insertion point
        let insertionPoint = selectedRange().location

        // Try to handle as image
        if handleImagePasteboard(pasteboard, at: insertionPoint) {
            return
        }

        // Fall back to default paste behavior
        super.paste(sender)
    }

    // MARK: - Private Helpers

    /// Check if the pasteboard contains image data we can handle
    private func containsImageData(_ pasteboard: NSPasteboard) -> Bool {
        // Check for file URLs that are images
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                if isImageFile(url) {
                    return true
                }
            }
        }

        // Check for raw image data
        if pasteboard.data(forType: .png) != nil ||
           pasteboard.data(forType: .tiff) != nil {
            return true
        }

        return false
    }

    /// Check if a URL points to an image file
    private func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return FileService.supportedImageExtensions.contains(ext)
    }

    /// Handle an image from the pasteboard
    /// - Returns: true if an image was handled, false otherwise
    private func handleImagePasteboard(_ pasteboard: NSPasteboard, at insertionPoint: Int) -> Bool {
        guard let coordinator = imageDropCoordinator else {
            return false
        }

        // First, try to get file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                if isImageFile(url) {
                    coordinator.handleImageDrop(from: url, at: insertionPoint, in: self)
                    return true
                }
            }
        }

        // Try to get raw image data (e.g., from screenshots)
        // Check multiple possible types for PNG data
        let pngTypes: [NSPasteboard.PasteboardType] = [
            .png,
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("Apple PNG pastance only")
        ]

        for pngType in pngTypes {
            if let imageData = pasteboard.data(forType: pngType),
               let image = NSImage(data: imageData) {
                coordinator.handleImageDrop(image: image, at: insertionPoint, in: self)
                return true
            }
        }

        // Try TIFF (common for screenshots)
        if let imageData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: imageData) {
            coordinator.handleImageDrop(image: image, at: insertionPoint, in: self)
            return true
        }

        // Try to get NSImage directly (works with many image types)
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            coordinator.handleImageDrop(image: image, at: insertionPoint, in: self)
            return true
        }

        return false
    }
}
