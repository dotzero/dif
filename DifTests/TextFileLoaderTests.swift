import Foundation
import XCTest
@testable import Dif

final class TextFileLoaderTests: XCTestCase {
    func testUTF8BOM() throws {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("hello".utf8)
        XCTAssertEqual(try TextFileLoader.decode(data), "hello")
    }

    func testUTF16BOM() throws {
        let data = "hello".data(using: .utf16)!
        XCTAssertEqual(try TextFileLoader.decode(data), "hello")
    }

    func testBinaryFileRejected() {
        XCTAssertThrowsError(try TextFileLoader.decode(Data([0, 1, 2])))
    }

    func testInvalidUTF8Rejected() {
        XCTAssertThrowsError(try TextFileLoader.decode(Data([0xFF])))
    }
}
