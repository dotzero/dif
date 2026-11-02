import AppKit
@testable import Dif
import SwiftUI
import XCTest

final class HighlightedTextEditorTests: XCTestCase {
    func testReenablingWrapRestoresEditorWidth() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        scrollView.documentView = textView

        editor(disableLineWrap: true).configureLineWrap(scrollView, textView)
        textView.setFrameSize(NSSize(width: 1200, height: 200))
        editor(disableLineWrap: false).configureLineWrap(scrollView, textView)

        XCTAssertFalse(scrollView.hasHorizontalScroller)
        XCTAssertFalse(textView.isHorizontallyResizable)
        XCTAssertTrue(textView.textContainer?.widthTracksTextView == true)
        XCTAssertEqual(textView.frame.width, scrollView.contentSize.width, accuracy: 0.5)
    }

    private func editor(disableLineWrap: Bool) -> HighlightedTextEditor {
        HighlightedTextEditor(
            text: .constant(""),
            changedLines: [],
            changedRanges: [:],
            disableLineWrap: disableLineWrap,
            lineColor: .systemRed,
            changeColor: .systemRed,
            onFileDrop: { _ in }
        )
    }
}
