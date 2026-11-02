import Foundation

enum DiffKind: Sendable {
    case unchanged
    case modified
    case removed
    case added
}

struct DiffRow: Identifiable, Sendable {
    let id: Int
    let leftNumber: Int?
    let leftText: String?
    let rightNumber: Int?
    let rightText: String?
    let kind: DiffKind
    let leftRanges: [Range<Int>]
    let rightRanges: [Range<Int>]
}

struct DiffResult: Sendable {
    let rows: [DiffRow]
    let leftChangedLines: Set<Int>
    let rightChangedLines: Set<Int>
    let leftChangedRanges: [Int: [Range<Int>]]
    let rightChangedRanges: [Int: [Range<Int>]]
    let changeCount: Int

    static let empty = DiffResult(
        rows: [],
        leftChangedLines: [],
        rightChangedLines: [],
        leftChangedRanges: [:],
        rightChangedRanges: [:],
        changeCount: 0
    )
}

enum DiffEngine {
    private typealias IndexedLine = (number: Int, text: String)
    private typealias IndexedCharacter = (value: Character, range: Range<Int>)

    private struct AlignmentState {
        let leftLines: [IndexedLine]
        let rightLines: [IndexedLine]
        let ignoringWhitespace: Bool
        let sameIgnoringWhitespace: Bool
        var rows: [DiffRow] = []
        var leftChanged: Set<Int> = []
        var rightChanged: Set<Int> = []
        var leftChangedRanges: [Int: [Range<Int>]] = [:]
        var rightChangedRanges: [Int: [Range<Int>]] = [:]

        mutating func append(_ leftIndex: Int?, _ rightIndex: Int?, _ kind: DiffKind) {
            let effectiveKind: DiffKind = sameIgnoringWhitespace ? .unchanged : kind
            let leftText = leftIndex.map { leftLines[$0].text }
            let rightText = rightIndex.map { rightLines[$0].text }
            let ranges: (left: [Range<Int>], right: [Range<Int>]) = switch effectiveKind {
            case .unchanged:
                ([], [])
            case .modified:
                DiffEngine.changedRanges(leftText ?? "", rightText ?? "", ignoringWhitespace: ignoringWhitespace)
            case .removed:
                (DiffEngine.fullRange(of: leftText), [])
            case .added:
                ([], DiffEngine.fullRange(of: rightText))
            }
            rows.append(DiffRow(
                id: rows.count,
                leftNumber: leftIndex.map { leftLines[$0].number + 1 },
                leftText: leftText,
                rightNumber: rightIndex.map { rightLines[$0].number + 1 },
                rightText: rightText,
                kind: effectiveKind,
                leftRanges: ranges.left,
                rightRanges: ranges.right
            ))
            if effectiveKind != .unchanged {
                if let leftIndex {
                    let number = leftLines[leftIndex].number
                    leftChanged.insert(number)
                    leftChangedRanges[number] = ranges.left
                }
                if let rightIndex {
                    let number = rightLines[rightIndex].number
                    rightChanged.insert(number)
                    rightChangedRanges[number] = ranges.right
                }
            }
        }

        var result: DiffResult {
            DiffResult(
                rows: rows,
                leftChangedLines: leftChanged,
                rightChangedLines: rightChanged,
                leftChangedRanges: leftChangedRanges,
                rightChangedRanges: rightChangedRanges,
                changeCount: rows.filter { $0.kind != .unchanged }.count
            )
        }
    }

    static func compare(_ left: String, _ right: String, ignoringWhitespace: Bool = false) -> DiffResult {
        let indexedLeft = lines(in: left).enumerated().map { (number: $0.offset, text: $0.element) }
        let indexedRight = lines(in: right).enumerated().map { (number: $0.offset, text: $0.element) }
        let leftLines = ignoringWhitespace
            ? indexedLeft.filter { !$0.text.allSatisfy(\.isWhitespace) } : indexedLeft
        let rightLines = ignoringWhitespace
            ? indexedRight.filter { !$0.text.allSatisfy(\.isWhitespace) } : indexedRight
        let comparedLeft = leftLines.map { ignoringWhitespace ? $0.text.filter { !$0.isWhitespace } : $0.text }
        let comparedRight = rightLines.map { ignoringWhitespace ? $0.text.filter { !$0.isWhitespace } : $0.text }
        let sameIgnoringWhitespace = ignoringWhitespace &&
            left.filter { !$0.isWhitespace } == right.filter { !$0.isWhitespace }
        let changes = comparedRight.difference(from: comparedLeft)

        let removed = Set(changes.removals.compactMap { change -> Int? in
            if case let .remove(offset, _, _) = change {
                return offset
            }
            return nil
        })
        let added = Set(changes.insertions.compactMap { change -> Int? in
            if case let .insert(offset, _, _) = change {
                return offset
            }
            return nil
        })

        return alignedResult(
            leftLines: leftLines,
            rightLines: rightLines,
            changes: (removed: removed, added: added),
            ignoringWhitespace: ignoringWhitespace,
            sameIgnoringWhitespace: sameIgnoringWhitespace
        )
    }

    private static func alignedResult(
        leftLines: [IndexedLine],
        rightLines: [IndexedLine],
        changes: (removed: Set<Int>, added: Set<Int>),
        ignoringWhitespace: Bool,
        sameIgnoringWhitespace: Bool
    ) -> DiffResult {
        var alignment = AlignmentState(
            leftLines: leftLines,
            rightLines: rightLines,
            ignoringWhitespace: ignoringWhitespace,
            sameIgnoringWhitespace: sameIgnoringWhitespace
        )
        var leftIndex = 0
        var rightIndex = 0

        while leftIndex < leftLines.count || rightIndex < rightLines.count {
            let commonLine = leftIndex < leftLines.count && rightIndex < rightLines.count &&
                !changes.removed.contains(leftIndex) && !changes.added.contains(rightIndex)
            if commonLine {
                alignment.append(leftIndex, rightIndex, .unchanged)
                leftIndex += 1
                rightIndex += 1
                continue
            }

            var removedLines: [Int] = []
            var addedLines: [Int] = []
            while leftIndex < leftLines.count, changes.removed.contains(leftIndex) {
                removedLines.append(leftIndex)
                leftIndex += 1
            }
            while rightIndex < rightLines.count, changes.added.contains(rightIndex) {
                addedLines.append(rightIndex)
                rightIndex += 1
            }
            for offset in 0 ..< max(removedLines.count, addedLines.count) {
                let old = offset < removedLines.count ? removedLines[offset] : nil
                let new = offset < addedLines.count ? addedLines[offset] : nil
                let kind: DiffKind = old != nil && new != nil ? .modified : (old != nil ? .removed : .added)
                alignment.append(old, new, kind)
            }
        }

        return alignment.result
    }

    private static func changedRanges(
        _ left: String,
        _ right: String,
        ignoringWhitespace: Bool
    ) -> (left: [Range<Int>], right: [Range<Int>]) {
        let leftCharacters = indexedCharacters(in: left, ignoringWhitespace: ignoringWhitespace)
        let rightCharacters = indexedCharacters(in: right, ignoringWhitespace: ignoringWhitespace)
        let commonLength = min(leftCharacters.count, rightCharacters.count)
        var prefix = 0
        while prefix < commonLength, leftCharacters[prefix].value == rightCharacters[prefix].value {
            prefix += 1
        }
        var suffix = 0
        while suffix < commonLength - prefix {
            let leftIndex = leftCharacters.count - suffix - 1
            let rightIndex = rightCharacters.count - suffix - 1
            guard leftCharacters[leftIndex].value == rightCharacters[rightIndex].value else { break }
            suffix += 1
        }
        let leftMiddle = Array(leftCharacters[prefix ..< leftCharacters.count - suffix])
        let rightMiddle = Array(rightCharacters[prefix ..< rightCharacters.count - suffix])

        // Avoid an expensive character diff for a line with a very large changed section.
        if leftMiddle.count + rightMiddle.count > 2048 {
            return (coveringRange(leftMiddle), coveringRange(rightMiddle))
        }

        let changes = rightMiddle.map(\.value).difference(from: leftMiddle.map(\.value))
        let removed = changes.removals.compactMap { change -> Int? in
            if case let .remove(offset, _, _) = change {
                return offset
            }
            return nil
        }
        let added = changes.insertions.compactMap { change -> Int? in
            if case let .insert(offset, _, _) = change {
                return offset
            }
            return nil
        }
        return (mergedRanges(for: removed, in: leftMiddle), mergedRanges(for: added, in: rightMiddle))
    }

    private static func indexedCharacters(in text: String, ignoringWhitespace: Bool) -> [IndexedCharacter] {
        var characters: [IndexedCharacter] = []
        var offset = 0
        for character in text {
            let range = offset ..< offset + character.utf16.count
            if !ignoringWhitespace || !character.isWhitespace {
                characters.append((character, range))
            }
            offset = range.upperBound
        }
        return characters
    }

    private static func mergedRanges(for offsets: [Int], in characters: [IndexedCharacter]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        for offset in offsets.sorted() {
            let range = characters[offset].range
            if let last = ranges.last, last.upperBound == range.lowerBound {
                ranges[ranges.count - 1] = last.lowerBound ..< range.upperBound
            } else {
                ranges.append(range)
            }
        }
        return ranges
    }

    private static func coveringRange(_ characters: [IndexedCharacter]) -> [Range<Int>] {
        guard let first = characters.first, let last = characters.last else { return [] }
        return [first.range.lowerBound ..< last.range.upperBound]
    }

    private static func fullRange(of text: String?) -> [Range<Int>] {
        guard let length = text?.utf16.count, length > 0 else { return [] }
        return [0 ..< length]
    }

    private static func lines(in text: String) -> [String] {
        text.isEmpty ? [] : text.components(separatedBy: "\n")
    }
}
