import XCTest
@testable import SharedFlagCore

final class SemanticVersionTests: XCTestCase {

    func testParsesFullVersion() {
        XCTAssertEqual(SemanticVersion("1.2.3"), SemanticVersion(major: 1, minor: 2, patch: 3))
    }

    func testPadsMissingComponents() {
        XCTAssertEqual(SemanticVersion("1.2"), SemanticVersion(major: 1, minor: 2, patch: 0))
        XCTAssertEqual(SemanticVersion("7"), SemanticVersion(major: 7, minor: 0, patch: 0))
    }

    func testRejectsMalformedInput() {
        XCTAssertNil(SemanticVersion(""))
        XCTAssertNil(SemanticVersion("1.2.3.4"))
        XCTAssertNil(SemanticVersion("a.b.c"))
        XCTAssertNil(SemanticVersion("1.2-beta"))
        XCTAssertNil(SemanticVersion("1..3"))
        XCTAssertNil(SemanticVersion("1.-2.0"))
        XCTAssertNil(SemanticVersion("not-a-version"))
    }

    func testOrdering() {
        // Compact form keeps each unwrap adjacent to the literal it parses.
        guard
            let v199 = SemanticVersion("1.9.9"),
            let v1100 = SemanticVersion("1.10.0"),
            let v200 = SemanticVersion("2.0.0")
        else {
            XCTFail("valid literals must parse")
            return
        }
        XCTAssertLessThan(v199, v1100)
        XCTAssertLessThan(v1100, v200)
        XCTAssertFalse(v200 < v199)
    }

    func testDescriptionRoundTrip() {
        XCTAssertEqual(SemanticVersion("2.1")?.description, "2.1.0")
    }
}
