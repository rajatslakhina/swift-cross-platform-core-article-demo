import XCTest
@testable import SharedFlagCore

final class DeterministicBucketerTests: XCTestCase {

    // Golden values computed with an independent FNV-1a reference
    // implementation (Python). If these ever change, cross-platform
    // bucket agreement is broken — that is the whole contract.
    func testGoldenBuckets() {
        XCTAssertEqual(DeterministicBucketer.bucket(flagKey: "new-checkout", subjectID: "user-42"), 4950)
        XCTAssertEqual(DeterministicBucketer.bucket(flagKey: "new-checkout", subjectID: "user-43"), 3161)
        XCTAssertEqual(DeterministicBucketer.bucket(flagKey: "dark-mode", subjectID: "user-42"), 5505)
    }

    func testGoldenHashes() {
        XCTAssertEqual(DeterministicBucketer.fnv1a("new-checkout:user-42"), 14_244_924_299_052_294_950)
        XCTAssertEqual(DeterministicBucketer.fnv1a("a:b"), 16_600_709_238_102_167_904)
    }

    func testEmptyInputsAreStableAndInRange() {
        let bucket = DeterministicBucketer.bucket(flagKey: "", subjectID: "")
        XCTAssertEqual(bucket, 8189) // fnv1a(":") % 10_000, verified externally
        XCTAssertTrue((0..<10_000).contains(bucket))
    }

    func testDeterminismAcrossRepeatedCalls() {
        let first = DeterministicBucketer.bucket(flagKey: "checkout", subjectID: "device-abc")
        for _ in 0..<1_000 {
            XCTAssertEqual(DeterministicBucketer.bucket(flagKey: "checkout", subjectID: "device-abc"), first)
        }
    }

    func testFlagKeySaltsTheBucket() {
        // The same subject should not share one fate across all flags.
        let buckets = Set((0..<50).map { i in
            DeterministicBucketer.bucket(flagKey: "flag-\(i)", subjectID: "user-42")
        })
        XCTAssertGreaterThan(buckets.count, 40, "buckets should vary by flag key")
    }

    func testAllBucketsInRange() {
        for i in 0..<5_000 {
            let bucket = DeterministicBucketer.bucket(flagKey: "range-check", subjectID: "user-\(i)")
            XCTAssertTrue((0..<10_000).contains(bucket))
        }
    }

    func testDistributionIsRoughlyUniform() {
        // 10,000 subjects into 10 decile buckets; a fair hash keeps every
        // decile within a generous band. This is a sanity check against
        // gross bias, not a statistical proof.
        var deciles = [Int](repeating: 0, count: 10)
        for i in 0..<10_000 {
            let bucket = DeterministicBucketer.bucket(flagKey: "distribution", subjectID: "subject-\(i)")
            deciles[bucket / 1_000] += 1
        }
        for count in deciles {
            XCTAssertGreaterThan(count, 700)
            XCTAssertLessThan(count, 1_300)
        }
    }
}
