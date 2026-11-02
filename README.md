# Dif

![Dif app icon](Dif/Assets.xcassets/AppIcon.appiconset/icon_128.png)

**Fast text comparison, without the clutter.** Dif keeps things simple: two panes, clear highlights, and just the controls you need. Paste text or drop in files; the diff updates as you edit.

## What it does

- Aligns added, removed, and changed lines, with highlighting inside changed lines.
- Shows line numbers in the comparison view and a change count in the toolbar.
- Lets you name each side and switch between editing and the aligned comparison.
- Can ignore whitespace changes, including blank lines and line breaks.
- Can turn off line wrapping for long lines.
- Reads UTF-8 and BOM-marked UTF-16 files. Binary files and unsupported encodings are rejected.

## Use Dif

1. Paste text into the **Original** and **Modified** panes, or use **Open File** or drag a file into either pane.
2. Edit the text as needed. Dif updates the comparison automatically.
3. Click **View comparison** to inspect aligned lines. Click **Edit texts** to return to the editors.
4. Open the sidebar to toggle **Hide whitespace changes** or **Disable line wrap**.

Dif runs offline. It only reads files you select, never writes to them, and does not save your text or settings.

## Install

Dif requires macOS 14 or later. Check [GitHub Releases](https://github.com/dotzero/dif/releases) for a downloadable build, or build it from source.

## Build from source

Install Xcode, SwiftFormat, and SwiftLint. From the repository root:

```sh
make build
open build/DerivedData/Build/Products/Debug/Dif.app
```

To run formatting checks and the XCTest suite:

```sh
make check
```

You can also open `Dif.xcodeproj` in Xcode and run the `Dif` scheme. The Xcode project is generated from `project.yml`; after editing that file, run `xcodegen generate` (requires [XcodeGen](https://github.com/yonaskolb/XcodeGen)).

## License

[MIT](LICENSE)
