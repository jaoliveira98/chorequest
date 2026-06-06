import XCTest
import SwiftUI
@testable import ChoreQuest

final class ColorHexTests: XCTestCase {
    private func rgba(_ color: Color) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    func testParsesSixDigitHex() {
        let (r, g, b, a) = rgba(Color(hex: "#7C5CFF"))
        XCTAssertEqual(r, 0x7C / 255, accuracy: 0.01)
        XCTAssertEqual(g, 0x5C / 255, accuracy: 0.01)
        XCTAssertEqual(b, 0xFF / 255, accuracy: 0.01)
        XCTAssertEqual(a, 1.0, accuracy: 0.01)
    }

    func testThreeDigitHexExpands() {
        let (r, g, b, _) = rgba(Color(hex: "#FFF"))
        XCTAssertEqual(r, 1, accuracy: 0.01)
        XCTAssertEqual(g, 1, accuracy: 0.01)
        XCTAssertEqual(b, 1, accuracy: 0.01)
    }

    func testIgnoresMissingHashPrefix() {
        let withHash = rgba(Color(hex: "#4FC3F7"))
        let without = rgba(Color(hex: "4FC3F7"))
        XCTAssertEqual(withHash.0, without.0, accuracy: 0.01)
        XCTAssertEqual(withHash.1, without.1, accuracy: 0.01)
        XCTAssertEqual(withHash.2, without.2, accuracy: 0.01)
    }

    func testInvalidLengthFallsBackToBrandViolet() {
        // 5 hex chars after cleaning matches none of the 3/6/8 cases → fallback.
        let (r, g, b, _) = rgba(Color(hex: "#12345"))
        XCTAssertEqual(r, 124 / 255, accuracy: 0.02)
        XCTAssertEqual(g, 92 / 255, accuracy: 0.02)
        XCTAssertEqual(b, 255 / 255, accuracy: 0.02)
    }
}
