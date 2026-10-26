import Foundation

enum TextFileError: LocalizedError {
    case unsupportedEncoding
    case binaryFile

    var errorDescription: String? {
        switch self {
        case .unsupportedEncoding:
            return "This file is not UTF-8 or UTF-16 text."
        case .binaryFile:
            return "This appears to be a binary file. Choose a text file."
        }
    }
}

enum TextFileLoader {
    static func load(_ url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> String {
        let bytes = Array(data.prefix(3))
        let text: String?
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) {
            text = String(data: data, encoding: .utf16)
        } else {
            text = String(data: data, encoding: .utf8)
        }
        guard var text else { throw TextFileError.unsupportedEncoding }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        if text.unicodeScalars.contains(where: { $0.value == 0 }) {
            throw TextFileError.binaryFile
        }
        return text
    }
}
