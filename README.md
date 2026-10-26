# Dif

A small, offline macOS 14+ app for comparing two text inputs side by side. Paste text, choose a file, or drop a file from Finder into either side; edit the labels and text, and the comparison updates automatically. Nothing is saved.

## Build

Open `Dif.xcodeproj` in Xcode and run the `Dif` scheme. The project is generated from `project.yml` with XcodeGen.

For a ready-to-run local build, open `dist/Dif.app` or unpack `dist/Dif.zip`.

To build and test from Terminal:

```sh
xcodebuild -project Dif.xcodeproj -scheme Dif -configuration Debug build
xcodebuild -project Dif.xcodeproj -scheme Dif -configuration Debug test
```

The app reads UTF-8 and BOM-marked UTF-16 text files. It does not write to the files you open. Use **View comparison** to switch to the aligned result, then **Edit texts** to return to the inputs. The left sidebar contains **Hide whitespace changes** (ignore spaces, blank lines, and line breaks when comparing) and **Disable line wrap** (scroll long lines horizontally). Both settings last until the window closes.
