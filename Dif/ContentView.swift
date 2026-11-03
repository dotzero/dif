import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum Side { case left, right }

struct ContentView: View {
    @State private var leftTitle = "Original"
    @State private var rightTitle = "Modified"
    @State private var leftText = ""
    @State private var rightText = ""
    @State private var result = DiffResult.empty
    @State private var showsComparison = false
    @State private var showsSettings = false
    @State private var hideWhitespaceChanges = false
    @State private var disableLineWrap = false
    @State private var compareTask: Task<Void, Never>?
    @State private var errorMessage: String?

    var body: some View {
        content
    }

    private var content: some View {
        VStack(spacing: 0) {
            if showsComparison {
                comparison
            } else {
                HSplitView {
                    editorPane(
                        title: $leftTitle,
                        text: $leftText,
                        changedLines: result.leftChangedLines,
                        changedRanges: result.leftChangedRanges,
                        side: .left
                    )
                    editorPane(
                        title: $rightTitle,
                        text: $rightText,
                        changedLines: result.rightChangedLines,
                        changedRanges: result.rightChangedRanges,
                        side: .right
                    )
                }
            }
            Divider()
            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $showsComparison) {
                    Text("Edit").tag(false)
                    Text("Compare").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showsSettings.toggle()
                } label: {
                    Label("Comparison Options", systemImage: "slider.horizontal.3")
                }
                .help(showsSettings ? "Hide comparison options" : "Show comparison options")
            }
        }
        .inspector(isPresented: $showsSettings) {
            settingsPanel
                .inspectorColumnWidth(min: 220, ideal: 260, max: 300)
        }
        .onChange(of: leftText) { _, _ in scheduleComparison() }
        .onChange(of: rightText) { _, _ in scheduleComparison() }
        .onChange(of: hideWhitespaceChanges) { _, _ in scheduleComparison() }
        .alert("Could not open file", isPresented: Binding(
            get: { errorMessage != nil },
            set: {
                if !$0 {
                    errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: result.changeCount == 0 ? "checkmark.circle" : "circle.lefthalf.filled")
                .foregroundStyle(result.changeCount == 0 ? Color.secondary : Color.accentColor)
            Text(leftText.isEmpty && rightText.isEmpty ? "Ready to compare" :
                result.changeCount == 0 ? "No differences" :
                "\(result.changeCount) \(result.changeCount == 1 ? "change" : "changes")")
            Spacer()
            if hideWhitespaceChanges {
                Text("Whitespace ignored")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(.bar)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Comparison Options")
                .font(.headline)
            Toggle("Hide whitespace changes", isOn: $hideWhitespaceChanges)
            Divider()
            Toggle("Disable line wrap", isOn: $disableLineWrap)
            Spacer()
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func editorPane(
        title: Binding<String>,
        text: Binding<String>,
        changedLines: Set<Int>,
        changedRanges: [Int: [Range<Int>]],
        side: Side
    ) -> some View {
        VStack(spacing: 0) {
            editorHeader(title: title, hasText: !text.wrappedValue.isEmpty, side: side)
            Divider()
            HighlightedTextEditor(
                text: text,
                changedLines: changedLines,
                changedRanges: changedRanges,
                disableLineWrap: disableLineWrap,
                lineColor: (side == .left ? NSColor.systemRed : NSColor.systemGreen)
                    .withAlphaComponent(0.10),
                changeColor: (side == .left ? NSColor.systemRed : NSColor.systemGreen)
                    .withAlphaComponent(0.35),
                onFileDrop: { loadFile($0, into: side) },
                focusesOnFirstAppearance: side == .left
            )
            .accessibilityLabel(side == .left ? "Left text" : "Right text")
            .overlay {
                if text.wrappedValue.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 28, weight: .light))
                        Text("Paste text or drop a file")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL? = if let item = item as? URL {
                    item
                } else if let data = item as? Data {
                    NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL
                } else {
                    nil
                }
                if let url {
                    DispatchQueue.main.async { loadFile(url, into: side) }
                }
            }
            return true
        }
    }

    private func editorHeader(title: Binding<String>, hasText: Bool, side: Side) -> some View {
        HStack(spacing: 12) {
            Image(systemName: side == .left ? "minus.circle.fill" : "plus.circle.fill")
                .foregroundStyle(side == .left ? .red : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(side == .left ? "ORIGINAL" : "MODIFIED")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                TextField("Label", text: title)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .accessibilityLabel(side == .left ? "Left label" : "Right label")
            }
            Spacer()
            Button {
                chooseFile(for: side)
            } label: {
                Label("Open", systemImage: "folder")
            }
            .accessibilityLabel(side == .left ? "Open left file" : "Open right file")
            Button {
                clearPane(side)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .disabled(!hasText)
            .accessibilityLabel(side == .left ? "Clear left pane" : "Clear right pane")
            .help("Clear text")
        }
        .padding(.horizontal, 16)
        .frame(height: 62)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private extension ContentView {
    var comparison: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Label(leftTitle, systemImage: "minus")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Label(rightTitle, systemImage: "plus")
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.headline)
            .lineLimit(1)
            .padding(.horizontal, 18)
            .frame(height: 62)
            .background(Color(nsColor: .controlBackgroundColor))
            Divider()
            if leftText.isEmpty, rightText.isEmpty {
                ContentUnavailableView(
                    "Ready to compare",
                    systemImage: "square.split.2x1",
                    description: Text("Paste text or drop a file into each side.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    if disableLineWrap {
                        ScrollView(.vertical) {
                            VStack(spacing: 0) {
                                if result.changeCount == 0 {
                                    Text("No differences")
                                        .foregroundStyle(.secondary)
                                        .padding(12)
                                }
                                HStack(alignment: .top, spacing: 0) {
                                    comparisonColumn(.left, viewportWidth: geometry.size.width / 2)
                                    comparisonColumn(.right, viewportWidth: geometry.size.width / 2)
                                }
                            }
                        }
                    } else {
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                if result.changeCount == 0 {
                                    Text("No differences")
                                        .foregroundStyle(.secondary)
                                        .padding(12)
                                }
                                ForEach(result.rows) { row in
                                    HStack(alignment: .top, spacing: 0) {
                                        comparisonCell(
                                            number: row.leftNumber,
                                            text: row.leftText,
                                            ranges: row.leftRanges,
                                            color: row.kind == .unchanged || row.leftText == nil
                                                ? .clear : .red,
                                            width: geometry.size.width / 2
                                        )
                                        comparisonCell(
                                            number: row.rightNumber,
                                            text: row.rightText,
                                            ranges: row.rightRanges,
                                            color: row.kind == .unchanged || row.rightText == nil
                                                ? .clear : .green,
                                            width: geometry.size.width / 2
                                        )
                                    }
                                    Divider()
                                }
                            }
                            .frame(width: geometry.size.width)
                        }
                    }
                }
            }
        }
    }

    private func comparisonColumn(_ side: Side, viewportWidth: CGFloat) -> some View {
        let width = max(viewportWidth, unwrappedColumnWidth(for: side))
        return ScrollView(.horizontal) {
            LazyVStack(spacing: 0) {
                ForEach(result.rows) { row in
                    comparisonCell(
                        number: side == .left ? row.leftNumber : row.rightNumber,
                        text: side == .left ? row.leftText : row.rightText,
                        ranges: side == .left ? row.leftRanges : row.rightRanges,
                        color: row.kind == .unchanged ||
                            (side == .left ? row.leftText : row.rightText) == nil
                            ? .clear : (side == .left ? .red : .green),
                        width: width
                    )
                    Divider()
                }
            }
            .frame(width: width)
        }
        .frame(width: viewportWidth)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func unwrappedColumnWidth(for side: Side) -> CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let textWidth = result.rows.map { side == .left ? $0.leftText : $0.rightText }
            .compactMap(\.self)
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return textWidth + 70
    }

    private func comparisonCell(
        number: Int?,
        text: String?,
        ranges: [Range<Int>],
        color: Color,
        width: CGFloat
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number.map(String.init) ?? "")
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)
            highlightedText(text ?? " ", ranges: ranges, color: color.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(disableLineWrap ? 1 : nil)
                .textSelection(.enabled)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 3)
        .padding(.horizontal, 7)
        .frame(width: width, alignment: .topLeading)
        .background(color.opacity(0.10))
    }

    private func highlightedText(_ text: String, ranges: [Range<Int>], color: Color) -> Text {
        let source = text as NSString
        var highlighted = AttributedString()
        var position = 0
        for range in ranges {
            if position < range.lowerBound {
                highlighted += AttributedString(source.substring(with: NSRange(
                    location: position,
                    length: range.lowerBound - position
                )))
            }
            var changed = AttributedString(source.substring(with: NSRange(
                location: range.lowerBound,
                length: range.upperBound - range.lowerBound
            )))
            changed.backgroundColor = color
            highlighted += changed
            position = range.upperBound
        }
        if position < source.length {
            highlighted += AttributedString(source.substring(from: position))
        }
        return Text(highlighted)
    }

    private func chooseFile(for side: Side) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            loadFile(url, into: side)
        }
    }

    private func loadFile(_ url: URL, into side: Side) {
        do {
            let loaded = try TextFileLoader.load(url)
            switch side {
            case .left:
                leftText = loaded
                leftTitle = url.lastPathComponent
            case .right:
                rightText = loaded
                rightTitle = url.lastPathComponent
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearPane(_ side: Side) {
        switch side {
        case .left:
            leftText = ""
            leftTitle = "Original"
        case .right:
            rightText = ""
            rightTitle = "Modified"
        }
    }

    private func scheduleComparison() {
        compareTask?.cancel()
        let left = leftText
        let right = rightText
        let ignoringWhitespace = hideWhitespaceChanges
        compareTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let updated = await Task.detached(priority: .userInitiated) {
                DiffEngine.compare(left, right, ignoringWhitespace: ignoringWhitespace)
            }.value
            guard !Task.isCancelled else { return }
            result = updated
        }
    }
}
