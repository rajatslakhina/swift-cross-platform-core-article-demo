import XCTest
@testable import SharedFlagCore

final class FlagEvaluatorTests: XCTestCase {

    // user-42 lands in bucket 4950 for "new-checkout" (golden value).
    private let user42 = EvaluationContext(subjectID: "user-42", appVersion: "2.0.0", region: "US")

    private func flag(_ rules: [FlagRule], defaultEnabled: Bool = false) -> FeatureFlag {
        FeatureFlag(key: "new-checkout", defaultEnabled: defaultEnabled, rules: rules)
    }

    func testZeroRolloutDisables() {
        let result = FlagEvaluator.evaluate(flag([FlagRule(rolloutBasisPoints: 0)]), in: user42)
        XCTAssertFalse(result.isEnabled)
        XCTAssertEqual(result.reason, .ruleDecided(ruleIndex: 0, thresholdBasisPoints: 0, rolledIn: false))
    }

    func testFullRolloutEnables() {
        let result = FlagEvaluator.evaluate(flag([FlagRule(rolloutBasisPoints: 10_000)]), in: user42)
        XCTAssertTrue(result.isEnabled)
    }

    func testExactThresholdBoundary() {
        // bucket 4950: threshold 4950 must exclude (strict <), 4951 must include.
        XCTAssertFalse(FlagEvaluator.evaluate(flag([FlagRule(rolloutBasisPoints: 4_950)]), in: user42).isEnabled)
        XCTAssertTrue(FlagEvaluator.evaluate(flag([FlagRule(rolloutBasisPoints: 4_951)]), in: user42).isEnabled)
    }

    func testBucketIsReportedEvenWhenDefaultApplies() {
        let result = FlagEvaluator.evaluate(flag([], defaultEnabled: true), in: user42)
        XCTAssertTrue(result.isEnabled)
        XCTAssertEqual(result.bucket, 4950)
        XCTAssertEqual(result.reason, .noApplicableRule(defaultEnabled: true))
    }

    func testRegionAllowlistBlocksAndMatches() {
        let euOnly = flag([FlagRule(rolloutBasisPoints: 10_000, regions: ["EU"])])
        XCTAssertFalse(FlagEvaluator.evaluate(euOnly, in: user42).isEnabled) // US context
        let usOnly = flag([FlagRule(rolloutBasisPoints: 10_000, regions: ["US", "CA"])])
        XCTAssertTrue(FlagEvaluator.evaluate(usOnly, in: user42).isEnabled)
    }

    func testEmptyRegionSetMeansAllRegions() {
        let anywhere = flag([FlagRule(rolloutBasisPoints: 10_000, regions: [])])
        XCTAssertTrue(FlagEvaluator.evaluate(anywhere, in: user42).isEnabled)
    }

    func testMinVersionGate() {
        let needs2 = flag(
            [FlagRule(rolloutBasisPoints: 10_000, minVersion: SemanticVersion(major: 2, minor: 0, patch: 0))],
            defaultEnabled: false
        )
        let oldApp = EvaluationContext(subjectID: "user-42", appVersion: "1.9.9", region: "US")
        XCTAssertFalse(FlagEvaluator.evaluate(needs2, in: oldApp).isEnabled)
        XCTAssertEqual(FlagEvaluator.evaluate(needs2, in: oldApp).reason, .noApplicableRule(defaultEnabled: false))
        XCTAssertTrue(FlagEvaluator.evaluate(needs2, in: user42).isEnabled) // 2.0.0
    }

    func testMaxVersionIsExclusive() {
        let below3 = flag(
            [FlagRule(rolloutBasisPoints: 10_000, maxVersionExclusive: SemanticVersion(major: 3, minor: 0, patch: 0))]
        )
        XCTAssertTrue(FlagEvaluator.evaluate(below3, in: user42).isEnabled) // 2.0.0 < 3.0.0
        let at3 = EvaluationContext(subjectID: "user-42", appVersion: "3.0.0", region: "US")
        XCTAssertFalse(FlagEvaluator.evaluate(below3, in: at3).isEnabled)
    }

    func testMalformedContextVersionFailsSafeButOnlyForVersionGatedRules() {
        let garbageVersion = EvaluationContext(subjectID: "user-42", appVersion: "not-a-version", region: "US")
        // Version-gated rule: skipped, default applies.
        let gated = flag(
            [FlagRule(rolloutBasisPoints: 10_000, minVersion: SemanticVersion(major: 1, minor: 0, patch: 0))]
        )
        XCTAssertFalse(FlagEvaluator.evaluate(gated, in: garbageVersion).isEnabled)
        // Unconstrained rule: still applies normally.
        let open = flag([FlagRule(rolloutBasisPoints: 10_000)])
        XCTAssertTrue(FlagEvaluator.evaluate(open, in: garbageVersion).isEnabled)
    }

    func testFirstMatchWins() {
        // First rule matches with 0% rollout; the 100% rule behind it must never run.
        let shadowed = flag([
            FlagRule(rolloutBasisPoints: 0),
            FlagRule(rolloutBasisPoints: 10_000)
        ])
        let result = FlagEvaluator.evaluate(shadowed, in: user42)
        XCTAssertFalse(result.isEnabled)
        XCTAssertEqual(result.reason, .ruleDecided(ruleIndex: 0, thresholdBasisPoints: 0, rolledIn: false))
    }

    func testNonMatchingFirstRuleFallsThroughToSecond() {
        let fallthrough_ = flag([
            FlagRule(rolloutBasisPoints: 10_000, regions: ["EU"]),   // skipped for US
            FlagRule(rolloutBasisPoints: 10_000)                     // decides
        ])
        let result = FlagEvaluator.evaluate(fallthrough_, in: user42)
        XCTAssertTrue(result.isEnabled)
        XCTAssertEqual(result.reason, .ruleDecided(ruleIndex: 1, thresholdBasisPoints: 10_000, rolledIn: true))
    }

    func testRolloutClamping() {
        XCTAssertEqual(FlagRule(rolloutBasisPoints: -5).rolloutBasisPoints, 0)
        XCTAssertEqual(FlagRule(rolloutBasisPoints: 99_999).rolloutBasisPoints, 10_000)
    }

    func testEvaluateAllPreservesOrder() {
        let flags = [
            FeatureFlag(key: "a", defaultEnabled: true),
            FeatureFlag(key: "b", defaultEnabled: false)
        ]
        let results = FlagEvaluator.evaluateAll(flags, in: user42)
        XCTAssertEqual(results.map(\.flagKey), ["a", "b"])
        XCTAssertEqual(results.map(\.isEnabled), [true, false])
    }

    func testSameInputsSameDecisionManyTimes() {
        let canary = flag([FlagRule(rolloutBasisPoints: 4_951)])
        let first = FlagEvaluator.evaluate(canary, in: user42)
        for _ in 0..<500 {
            XCTAssertEqual(FlagEvaluator.evaluate(canary, in: user42), first)
        }
    }
}
