import AppKit
import SwiftUI

struct HighlightedTextEditor: NSViewRepresentable {
    @Binding var text: String
    let changedLines: Set<Int>
    let changedRanges: [Int: [Range<Int>]]
    let disableLineWrap: Bool
    let lineColor: NSColor
    let changeColor: NSColor
    let onFileDrop: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = FileDropTextView(frame: .zero)
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        textView.onFileDrop = onFileDrop
        textView.registerForDraggedTypes([.fileURL])
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 10)
        textView.string = text
        scrollView.documentView = textView
        configureLineWrap(scrollView, textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        (textView as? FileDropTextView)?.onFileDrop = onFileDrop
        let textChanged = textView.string != text
        if textChanged {
            textView.string = text
        }
        let wrapChanged = textView.isHorizontallyResizable != disableLineWrap
        if wrapChanged {
            configureLineWrap(scrollView, textView)
        }
        if disableLineWrap, textChanged, !wrapChanged {
            textView.sizeToFit()
        }
        guard let layoutManager = textView.layoutManager else { return }
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
        let nsText = textView.string as NSString
        var position = 0
        var line = 0
        while position < nsText.length {
            var start = 0
            var end = 0
            var contentsEnd = 0
            nsText.getLineStart(
                &start,
                end: &end,
                contentsEnd: &contentsEnd,
                for: NSRange(location: position, length: 0)
            )
            if changedLines.contains(line) {
                layoutManager.addTemporaryAttribute(
                    .backgroundColor,
                    value: lineColor,
                    forCharacterRange: NSRange(location: start, length: end - start)
                )
            }
            for range in changedRanges[line] ?? [] where range.upperBound <= contentsEnd - start {
                layoutManager.addTemporaryAttribute(
                    .backgroundColor,
                    value: changeColor,
                    forCharacterRange: NSRange(
                        location: start + range.lowerBound,
                        length: range.upperBound - range.lowerBound
                    )
                )
            }
            position = end
            line += 1
        }
    }

    func configureLineWrap(_ scrollView: NSScrollView, _ textView: NSTextView) {
        scrollView.hasHorizontalScroller = disableLineWrap
        textView.isHorizontallyResizable = disableLineWrap
        textView.autoresizingMask = disableLineWrap ? [] : [.width]
        textView.textContainer?.widthTracksTextView = !disableLineWrap
        textView.textContainer?.containerSize = NSSize(
            width: disableLineWrap ? CGFloat.greatestFiniteMagnitude : scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        if disableLineWrap {
            textView.sizeToFit()
        } else {
            let width = scrollView.contentSize.width
            textView.setFrameSize(NSSize(width: width, height: textView.frame.height))
            textView.sizeToFit()
            textView.setFrameSize(NSSize(width: width, height: textView.frame.height))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedTextEditor

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

private final class FileDropTextView: NSTextView {
    var onFileDrop: ((URL) -> Void)?

    private func droppedFile(_ sender: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options)
            as? [NSURL])?.first.map { $0 as URL }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFile(sender) == nil ? super.draggingEntered(sender) : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFile(sender) == nil ? super.draggingUpdated(sender) : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = droppedFile(sender) else { return super.performDragOperation(sender) }
        onFileDrop?(url)
        return true
    }
}
