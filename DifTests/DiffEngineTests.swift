@testable import Dif
import XCTest

final class DiffEngineTests: XCTestCase {
    func testInsertionAndDeletion() {
        let result = DiffEngine.compare("a\nb\nc", "a\nc\nd")
        XCTAssertEqual(result.rows.map(\.kind), [.unchanged, .removed, .unchanged, .added])
        XCTAssertEqual(result.rows.map(\.leftNumber), [1, 2, 3, nil])
        XCTAssertEqual(result.rows.map(\.rightNumber), [1, nil, 2, 3])
        XCTAssertEqual(result.rows[1].leftRanges, [0 ..< 1])
        XCTAssertEqual(result.rows[3].rightRanges, [0 ..< 1])
    }

    func testChangedLineIsPaired() {
        let result = DiffEngine.compare("a\nold\nz", "a\nnew\nz")
        XCTAssertEqual(result.rows.map(\.kind), [.unchanged, .modified, .unchanged])
        XCTAssertEqual(result.leftChangedLines, [1])
        XCTAssertEqual(result.rightChangedLines, [1])
    }

    func testModifiedLineHighlightsSeparateChanges() {
        let result = DiffEngine.compare("cat and dog", "bat and dig")
        XCTAssertEqual(result.rows[0].leftRanges, [0 ..< 1, 9 ..< 10])
        XCTAssertEqual(result.rows[0].rightRanges, [0 ..< 1, 9 ..< 10])
        XCTAssertEqual(result.leftChangedRanges[0], [0 ..< 1, 9 ..< 10])
        XCTAssertEqual(result.rightChangedRanges[0], [0 ..< 1, 9 ..< 10])
    }

    func testInsertedCharacterHighlightsOnlyNewSide() {
        let result = DiffEngine.compare("color", "colour")
        XCTAssertEqual(result.rows[0].leftRanges, [])
        XCTAssertEqual(result.rows[0].rightRanges, [4 ..< 5])
        XCTAssertEqual(result.leftChangedLines, [0])
        XCTAssertEqual(result.rightChangedLines, [0])
    }

    func testHighlightRangesUseUTF16OffsetsAndIgnoreWhitespace() {
        let emoji = DiffEngine.compare("a😀b", "a😎b")
        XCTAssertEqual(emoji.rows[0].leftRanges, [1 ..< 3])
        XCTAssertEqual(emoji.rows[0].rightRanges, [1 ..< 3])

        let whitespace = DiffEngine.compare("x 1", "x\t2", ignoringWhitespace: true)
        XCTAssertEqual(whitespace.rows[0].leftRanges, [2 ..< 3])
        XCTAssertEqual(whitespace.rows[0].rightRanges, [2 ..< 3])
    }

    func testEmptyAndRepeatedLines() {
        XCTAssertEqual(DiffEngine.compare("", "new").rows.map(\.kind), [.added])
        XCTAssertEqual(DiffEngine.compare("same\nsame", "same\nsame").changeCount, 0)
    }

    func testTrailingNewlineIsVisible() {
        let result = DiffEngine.compare("a", "a\n")
        XCTAssertEqual(result.rows.map(\.kind), [.unchanged, .added])
    }

    func testIgnoringWhitespacePreservesOriginalTextAndRealChanges() {
        let left = "a b\nvalue\t = 1"
        let right = "ab\nvalue = 2"
        XCTAssertEqual(DiffEngine.compare(left, right).changeCount, 2)

        let result = DiffEngine.compare(left, right, ignoringWhitespace: true)
        XCTAssertEqual(result.rows.map(\.kind), [.unchanged, .modified])
        XCTAssertEqual(result.rows.first?.leftText, "a b")
        XCTAssertEqual(result.rows.first?.rightText, "ab")
        XCTAssertEqual(result.changeCount, 1)
    }

    func testIgnoringWhitespaceSkipsExtraBlankLinesAndKeepsOriginalLineNumbers() {
        let left = "start\n\n\nold\nend"
        let right = "start\n\nnew\nend"
        let result = DiffEngine.compare(left, right, ignoringWhitespace: true)

        XCTAssertEqual(result.rows.map(\.leftNumber), [1, 4, 5])
        XCTAssertEqual(result.rows.map(\.rightNumber), [1, 3, 4])
        XCTAssertEqual(result.rows.map(\.kind), [.unchanged, .modified, .unchanged])
        XCTAssertEqual(result.leftChangedLines, [3])
        XCTAssertEqual(result.rightChangedLines, [2])
        XCTAssertEqual(DiffEngine.compare("a\n\n\nb", "a\n\nb", ignoringWhitespace: true).changeCount, 0)
    }

    func testIgnoringWhitespaceTreatsLineBreakReflowAsEqual() {
        let result = DiffEngine.compare("foo\nbar", "foobar", ignoringWhitespace: true)
        XCTAssertEqual(result.changeCount, 0)
        XCTAssertTrue(result.leftChangedLines.isEmpty)
        XCTAssertTrue(result.rightChangedLines.isEmpty)
        XCTAssertEqual(result.rows.compactMap(\.leftText).joined(separator: "\n"), "foo\nbar")
        XCTAssertEqual(result.rows.compactMap(\.rightText).joined(separator: "\n"), "foobar")
        XCTAssertEqual(DiffEngine.compare("foo\nbar", "fooz\nbar", ignoringWhitespace: true).changeCount, 1)
    }

    func testAlignedRowsPreserveBothInputs() {
        let examples = [
            ("a\nb\nc", "a\nx\ny\nc"),
            ("x\nx\ny", "x\ny\nx"),
            ("a\nb", ""),
            ("", "a\nb"),
            ("same\nleft\nsame", "same\nright\nsame")
        ]
        for (left, right) in examples {
            let rows = DiffEngine.compare(left, right).rows
            XCTAssertEqual(rows.compactMap(\.leftText).joined(separator: "\n"), left)
            XCTAssertEqual(rows.compactMap(\.rightText).joined(separator: "\n"), right)
        }
    }
}
