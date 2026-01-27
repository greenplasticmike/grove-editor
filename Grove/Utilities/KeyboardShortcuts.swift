import AppKit
import SwiftUI

// MARK: - Markdown Formatting Actions

/// Helper methods for markdown text manipulation
enum MarkdownFormatter {

    // MARK: - Wrap Selection

    /// Wraps the selection with the given marker (e.g., `**` for bold, `*` for italic)
    /// If no selection, inserts markers and places cursor between them
    static func wrapSelection(in textView: NSTextView, with marker: String) {
        guard let textStorage = textView.textStorage else { return }

        let selectedRange = textView.selectedRange()
        let text = textStorage.string

        if selectedRange.length > 0 {
            // Has selection - wrap it
            let selectedText = (text as NSString).substring(with: selectedRange)
            let wrappedText = "\(marker)\(selectedText)\(marker)"

            textView.undoManager?.beginUndoGrouping()
            textView.insertText(wrappedText, replacementRange: selectedRange)
            textView.undoManager?.endUndoGrouping()

            // Select the wrapped text (without markers)
            let newSelectionStart = selectedRange.location + marker.count
            textView.setSelectedRange(NSRange(location: newSelectionStart, length: selectedText.count))
        } else {
            // No selection - insert markers and place cursor between
            let insertion = "\(marker)\(marker)"

            textView.undoManager?.beginUndoGrouping()
            textView.insertText(insertion, replacementRange: selectedRange)
            textView.undoManager?.endUndoGrouping()

            // Place cursor between markers
            let cursorPosition = selectedRange.location + marker.count
            textView.setSelectedRange(NSRange(location: cursorPosition, length: 0))
        }
    }

    /// Wraps selection as a link: [selection](url) or inserts [](url) if no selection
    static func insertLink(in textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let selectedRange = textView.selectedRange()
        let text = textStorage.string

        if selectedRange.length > 0 {
            // Has selection - wrap it as link text
            let selectedText = (text as NSString).substring(with: selectedRange)
            let linkText = "[\(selectedText)](url)"

            textView.undoManager?.beginUndoGrouping()
            textView.insertText(linkText, replacementRange: selectedRange)
            textView.undoManager?.endUndoGrouping()

            // Select "url" so user can type the actual URL
            let urlStart = selectedRange.location + selectedText.count + 3 // [text](
            textView.setSelectedRange(NSRange(location: urlStart, length: 3))
        } else {
            // No selection - insert empty link and place cursor in text area
            let linkText = "[](url)"

            textView.undoManager?.beginUndoGrouping()
            textView.insertText(linkText, replacementRange: selectedRange)
            textView.undoManager?.endUndoGrouping()

            // Place cursor between brackets for link text
            let cursorPosition = selectedRange.location + 1 // After [
            textView.setSelectedRange(NSRange(location: cursorPosition, length: 0))
        }
    }

    // MARK: - Line Prefix Operations

    /// Gets the range of the current line(s) containing the selection
    static func getCurrentLineRange(in textView: NSTextView) -> NSRange {
        let text = textView.string as NSString
        let selectedRange = textView.selectedRange()

        // Find start of first line in selection
        var lineStart = selectedRange.location
        while lineStart > 0 && text.character(at: lineStart - 1) != 0x0A { // 0x0A = \n
            lineStart -= 1
        }

        // Find end of last line in selection
        var lineEnd = selectedRange.location + selectedRange.length
        while lineEnd < text.length && text.character(at: lineEnd) != 0x0A {
            lineEnd += 1
        }

        return NSRange(location: lineStart, length: lineEnd - lineStart)
    }

    /// Toggles a heading level on the current line
    /// If line already has the target heading, removes it
    /// If line has a different heading, replaces it
    /// If line has no heading, adds the target heading
    static func toggleHeading(in textView: NSTextView, level: Int) {
        guard level >= 1 && level <= 6 else { return }
        guard let textStorage = textView.textStorage else { return }

        let lineRange = getCurrentLineRange(in: textView)
        let text = textStorage.string as NSString
        let lineText = text.substring(with: lineRange)

        // Check for existing heading prefix
        let headingPattern = "^(#{1,6})\\s"
        guard let regex = try? NSRegularExpression(pattern: headingPattern) else { return }

        let targetPrefix = String(repeating: "#", count: level) + " "
        var newLineText: String
        var cursorAdjustment: Int = 0

        if let match = regex.firstMatch(in: lineText, range: NSRange(location: 0, length: lineText.count)) {
            let existingHashes = (lineText as NSString).substring(with: match.range(at: 1))
            let existingPrefix = existingHashes + " "

            if existingHashes.count == level {
                // Same level - toggle off (remove heading)
                newLineText = String(lineText.dropFirst(existingPrefix.count))
                cursorAdjustment = -existingPrefix.count
            } else {
                // Different level - replace
                newLineText = targetPrefix + String(lineText.dropFirst(existingPrefix.count))
                cursorAdjustment = targetPrefix.count - existingPrefix.count
            }
        } else {
            // No heading - add one
            newLineText = targetPrefix + lineText
            cursorAdjustment = targetPrefix.count
        }

        let selectedRange = textView.selectedRange()

        textView.undoManager?.beginUndoGrouping()
        textView.insertText(newLineText, replacementRange: lineRange)
        textView.undoManager?.endUndoGrouping()

        // Adjust cursor position
        let newCursorLocation = max(lineRange.location, selectedRange.location + cursorAdjustment)
        textView.setSelectedRange(NSRange(location: newCursorLocation, length: 0))
    }

    // MARK: - Indentation

    /// Indents the current line(s) by adding a tab at the start
    static func indentLines(in textView: NSTextView) {
        modifyLinePrefix(in: textView, modification: .indent)
    }

    /// Outdents the current line(s) by removing a tab (or spaces) from the start
    static func outdentLines(in textView: NSTextView) {
        modifyLinePrefix(in: textView, modification: .outdent)
    }

    private enum LineModification {
        case indent
        case outdent
    }

    private static func modifyLinePrefix(in textView: NSTextView, modification: LineModification) {
        guard let textStorage = textView.textStorage else { return }

        let text = textStorage.string as NSString
        let selectedRange = textView.selectedRange()

        // Find all lines in selection
        var lineRanges: [NSRange] = []
        var searchStart = selectedRange.location

        // Find start of first line
        while searchStart > 0 && text.character(at: searchStart - 1) != 0x0A {
            searchStart -= 1
        }

        let selectionEnd = selectedRange.location + selectedRange.length
        var currentLineStart = searchStart

        // Collect all line ranges
        while currentLineStart <= selectionEnd && currentLineStart < text.length {
            var lineEnd = currentLineStart
            while lineEnd < text.length && text.character(at: lineEnd) != 0x0A {
                lineEnd += 1
            }

            lineRanges.append(NSRange(location: currentLineStart, length: lineEnd - currentLineStart))
            currentLineStart = lineEnd + 1 // Skip the newline
        }

        guard !lineRanges.isEmpty else { return }

        textView.undoManager?.beginUndoGrouping()

        // Process lines in reverse order to maintain correct ranges
        var totalAdjustment = 0
        var firstLineAdjustment = 0

        for (index, lineRange) in lineRanges.enumerated().reversed() {
            let lineText = text.substring(with: lineRange)
            var newLineText: String
            var adjustment: Int

            switch modification {
            case .indent:
                newLineText = "\t" + lineText
                adjustment = 1
            case .outdent:
                if lineText.hasPrefix("\t") {
                    newLineText = String(lineText.dropFirst())
                    adjustment = -1
                } else if lineText.hasPrefix("    ") {
                    newLineText = String(lineText.dropFirst(4))
                    adjustment = -4
                } else if lineText.hasPrefix("  ") {
                    newLineText = String(lineText.dropFirst(2))
                    adjustment = -2
                } else if lineText.hasPrefix(" ") {
                    newLineText = String(lineText.dropFirst())
                    adjustment = -1
                } else {
                    continue // Nothing to outdent
                }
            }

            // Replace using insertText for proper undo support
            if let adjustedRange = NSRange(location: lineRange.location, length: lineRange.length) as NSRange? {
                textView.insertText(newLineText, replacementRange: adjustedRange)
            }

            totalAdjustment += adjustment
            if index == 0 {
                firstLineAdjustment = adjustment
            }
        }

        textView.undoManager?.endUndoGrouping()

        // Adjust selection
        if selectedRange.length > 0 {
            // Adjust selection to cover modified lines
            let newStart = max(0, selectedRange.location + firstLineAdjustment)
            let newLength = max(0, selectedRange.length + totalAdjustment - firstLineAdjustment)
            textView.setSelectedRange(NSRange(location: newStart, length: newLength))
        } else {
            // Just adjust cursor position
            let newLocation = max(0, selectedRange.location + firstLineAdjustment)
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))
        }
    }
}

// MARK: - Shortcut Definitions (for reference and SwiftUI integration)

struct KeyboardShortcuts {
    // Formatting shortcuts
    static let bold = KeyboardShortcut("b", modifiers: .command)
    static let italic = KeyboardShortcut("i", modifiers: .command)
    static let link = KeyboardShortcut("k", modifiers: .command)
    static let code = KeyboardShortcut("k", modifiers: [.command, .shift])

    // Heading shortcuts
    static let heading1 = KeyboardShortcut("1", modifiers: .command)
    static let heading2 = KeyboardShortcut("2", modifiers: .command)
    static let heading3 = KeyboardShortcut("3", modifiers: .command)
    static let heading4 = KeyboardShortcut("4", modifiers: .command)

    // Indentation shortcuts
    static let indent = KeyboardShortcut("]", modifiers: .command)
    static let outdent = KeyboardShortcut("[", modifiers: .command)

    // View shortcuts
    static let togglePreview = KeyboardShortcut("p", modifiers: .command)
    static let toggleFocusMode = KeyboardShortcut("d", modifiers: .command)

    // Git shortcuts
    static let saveVersion = KeyboardShortcut("s", modifiers: [.command, .shift])
}
