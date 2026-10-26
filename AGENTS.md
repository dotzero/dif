# Repository Guidelines

## Project Structure & Module Organization

`Dif/` contains the macOS app. `ContentView.swift` builds the interface, `DiffEngine.swift` calculates aligned changes, `TextFileLoader.swift` reads text files, and `HighlightedTextEditor.swift` wraps AppKit's editor. Icon assets live in `Dif/Assets.xcassets/`; the source artwork is in `artwork/`. XCTest cases are in `DifTests/`. Edit `project.yml` for target or build setting changes, then run `xcodegen generate` to refresh `Dif.xcodeproj`. `build/` and `dist/` are ignored local outputs.

## Build, Test, and Development Commands

- `make build`: clean and build the Debug app. Run it with `open build/DerivedData/Build/Products/Debug/Dif.app`.
- `make test`: run the macOS XCTest suite.
- `make lint`: check SwiftFormat and SwiftLint rules.
- `make check`: run linting and tests together.
- `make release VERSION=1.0.0`: clean and build a Release app with an explicit marketing version.

Open `Dif.xcodeproj` in Xcode and select the `Dif` scheme for interactive development.

## Coding Style & Naming Conventions

Use four spaces for Swift indentation and keep lines within the 120-character formatter limit. Name types with `UpperCamelCase`, properties and functions with `lowerCamelCase`, and test methods with a `test` prefix. Follow `.swiftformat` and `.swiftlint.yml`; apply formatting with `swiftformat Dif DifTests --cache ignore` before running `make lint`. Keep comparison logic in `DiffEngine` and file decoding in `TextFileLoader` rather than adding it to the view.

## Testing Guidelines

Use XCTest in `DifTests/`. Add focused cases for changed, inserted, and deleted lines, whitespace handling, empty inputs, supported encodings, and rejected binary data when those behaviors change. There is no formal coverage threshold. Run `make check` before a pull request.

## Agent Verification

After every repository change, run `make check` before reporting completion. It runs SwiftFormat, SwiftLint, and the unit tests. If either linting or tests fail or cannot run, report the exact result and fix the cause before finishing.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects, such as `Add lint configuration and format Swift sources`. Keep each commit focused. In pull requests, describe the user-visible change, link an issue when one exists, report `make check` results, and include screenshots for interface changes.

## Security & Configuration

Dif is offline and sandboxed. File access is read-only and user selected; preserve that behavior when changing file loading. Do not add persistence or network access without an explicit product requirement.
