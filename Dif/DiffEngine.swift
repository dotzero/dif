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
}

struct DiffResult: Sendable {
    let rows: [DiffRow]
    let leftChangedLines: Set<Int>
    let rightChangedLines: Set<Int>
    let changeCount: Int

    static let empty = DiffResult(rows: [], leftChangedLines: [], rightChangedLines: [], changeCount: 0)
}

enum DiffEngine {
    private typealias IndexedLine = (number: Int, text: String)

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
            removed: removed,
            added: added,
            sameIgnoringWhitespace: sameIgnoringWhitespace
        )
    }

    private static func alignedResult(
        leftLines: [IndexedLine],
        rightLines: [IndexedLine],
        removed: Set<Int>,
        added: Set<Int>,
        sameIgnoringWhitespace: Bool
    ) -> DiffResult {
        var rows: [DiffRow] = []
        var leftChanged: Set<Int> = []
        var rightChanged: Set<Int> = []
        var leftIndex = 0
        var rightIndex = 0

        func append(_ leftIndex: Int?, _ rightIndex: Int?, _ kind: DiffKind) {
            let effectiveKind: DiffKind = sameIgnoringWhitespace ? .unchanged : kind
            rows.append(DiffRow(
                id: rows.count,
                leftNumber: leftIndex.map { leftLines[$0].number + 1 },
                leftText: leftIndex.map { leftLines[$0].text },
                rightNumber: rightIndex.map { rightLines[$0].number + 1 },
                rightText: rightIndex.map { rightLines[$0].text },
                kind: effectiveKind
            ))
            if effectiveKind != .unchanged {
                if let leftIndex {
                    leftChanged.insert(leftLines[leftIndex].number)
                }
                if let rightIndex {
                    rightChanged.insert(rightLines[rightIndex].number)
                }
            }
        }

        while leftIndex < leftLines.count || rightIndex < rightLines.count {
            let commonLine = leftIndex < leftLines.count && rightIndex < rightLines.count &&
                !removed.contains(leftIndex) && !added.contains(rightIndex)
            if commonLine {
                append(leftIndex, rightIndex, .unchanged)
                leftIndex += 1
                rightIndex += 1
                continue
            }

            var removedLines: [Int] = []
            var addedLines: [Int] = []
            while leftIndex < leftLines.count, removed.contains(leftIndex) {
                removedLines.append(leftIndex)
                leftIndex += 1
            }
            while rightIndex < rightLines.count, added.contains(rightIndex) {
                addedLines.append(rightIndex)
                rightIndex += 1
            }
            for offset in 0 ..< max(removedLines.count, addedLines.count) {
                let old = offset < removedLines.count ? removedLines[offset] : nil
                let new = offset < addedLines.count ? addedLines[offset] : nil
                let kind: DiffKind = old != nil && new != nil ? .modified : (old != nil ? .removed : .added)
                append(old, new, kind)
            }
        }

        return DiffResult(
            rows: rows,
            leftChangedLines: leftChanged,
            rightChangedLines: rightChanged,
            changeCount: rows.filter { $0.kind != .unchanged }.count
        )
    }

    private static func lines(in text: String) -> [String] {
        text.isEmpty ? [] : text.components(separatedBy: "\n")
    }
}
